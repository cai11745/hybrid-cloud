Terraform 踩坑记1

最近在使用 Terraform 部署 Azure AKS 集群，遇到了一些问题，把问题的根因和排查过程做个记录。

关于什么是 Terraform 请参照前文。  
https://github.com/cai11745/hybrid-cloud/blob/master/terraform/2023-02-24-terraform-install-and-simple-demo.md  
简单说就是以编码文件的方式，定义你所有创建的资源，而不需要通过页面或者命令行去操作，便于快速创建与销毁，配合git还可以做好版本管理。

关于本次问题排查，先上总结，再细细道来：  
1. 通过Azure CLI或者Azure Portal创建出来的资源，与通过 Terraform 创建时，有些参数的默认值不同的。比如这次遇到的 
subnet 的 privateEndpointNetworkPolicies 属性，通过 portal 创建默认是 disabled。而通过 terraform 创建的 subnet 这个参数默认是 enabled。
2. 资源属性的对比，除了在 portal 上对比参数配置。还可以借助命令行或者查看资源的JSON文件获取更多信息。因为有些参数在 portal 是不显示的。这次的 subnet 就是这样，在 portal 上和之前创建的 subnet 对比了几次没发现异常。
3. 资源创建或者操作失败的时候，如何追踪到更多的报错信息。查看 Activity log，包括你创建的资源、资源所在资源组、资源关联的vnet/路由表等、资源衍生出来的资源组（比如AKS创建时会自动衍生出一个新的资源组）

### 环境信息

已有 vnet 为 net001，已经通过 portal 创建了 subnet1 子网，通过 azure cli 命令创建了一个 AKS 集群 aks1 部署在 subnet1 ，运行正常。

本次目标是创建 aks2 主要流程和资源如下，与 aks1 无异：
1. 创建aks 所在资源组
2. 创建subnet2 子网，定义网段
3. 创建自定义路由表
4. 创建自定义aks master托管标识
5. 对路由表授予托管标识 "Network Contributor" 权限
6. 创建aks：开启 private cluster，使用自定义托管标识，定义节点池的规格、数量、子网，定义网络插件、网络出口采用自定义路由

本次的最大差异是 aks1 及相关资源通过 azure portal 和azure cli 创建。 而本次 aks2 将采用 terraform 创建，将通过 terraform 定义上述的所有资源和role分配。

### 排障过程

#### 报错内容

当我执行 terraform apply 之后，aks 之前的资源都创建成功，但 aks 这部分报错了，而且这个报错内容有点难以理解，网上也没有查到有用信息。

```bash
azurerm_kubernetes_cluster.k8s: Still creating... [1m10s elapsed]
azurerm_kubernetes_cluster.k8s: Still creating... [1m20s elapsed]
azurerm_kubernetes_cluster.k8s: Still creating... [1m30s elapsed]
azurerm_kubernetes_cluster.k8s: Still creating... [1m40s elapsed]
azurerm_kubernetes_cluster.k8s: Still creating... [1m50s elapsed]
azurerm_kubernetes_cluster.k8s: Still creating... [2m0s elapsed]
╷
│ Error: waiting for creation of Managed Cluster (Subscription: "xxxxxx-xxxxxx-xxxxxx"
│ Resource Group Name: "xxxxxx"
│ Managed Cluster Name: "aks2-xxxxx"): Code="InternalOperationError" Message="Internal server error"
│
│   with azurerm_kubernetes_cluster.k8s,
│   on main.tf line 59, in resource "azurerm_kubernetes_cluster" "k8s":
│   59: resource "azurerm_kubernetes_cluster" "k8s" {
│
```

#### 排查过程

首先做的是把资源删了 terraform destroy，再 apply 来一次，结果还是一样的报错。

aks 的 Activity log 上看到的报错和 terraform 返回的内容是一样的，就是 Code="InternalOperationError" Message="Internal server error"，所以 terraform 返回没有遗漏信息。  
且 aks 的状态显示异常，但是未给出更多信息。aks 每次创建时会自动创建一个新的资源组 node-resource-group，默认会叫 MC_rg_xxx ，用于放置 node 相关资源，比如 kubelet 托管标识、VirtualMachineScaleSets（node虚拟机集）、k8s loadbalance、network security group、private dns。通过 AKS 页面的 Properties -- Infrastructure resource group 进入，正常情况下 aks 创建完能看到6，7个资源，而此时只看到两个资源：node托管标识和NSG，所以判定 k8s的配置文件有问题，也就是下面这一段。

我先后尝试精简化配置，把 linux_profile 和其他能够移除的部分都拿掉了，还是创建依然没有成功。

```bash
resource "azurerm_kubernetes_cluster" "k8s" {
  depends_on = [azurerm_role_assignment.route_table_network_contributor, azurerm_subnet_route_table_association.rt1_sub1]

  location                = azurerm_resource_group.rg.location
  name                    = var.cluster_name
  resource_group_name     = azurerm_resource_group.rg.name
  dns_prefix              = var.dns_prefix
  private_cluster_enabled = true

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.uai_master.id]
  }

  #  kubelet_identity {
  #    client_id                 = azurerm_user_assigned_identity.uai_node.client_id
  #    object_id                 = azurerm_user_assigned_identity.uai_node.principal_id
  #    user_assigned_identity_id = azurerm_user_assigned_identity.uai_node.id
  #  }

  default_node_pool {
    name           = "agentpool"
    vm_size        = var.agent_vm_size
    node_count     = var.agent_count
    vnet_subnet_id = azurerm_subnet.sub1.id
    type           = "VirtualMachineScaleSets"
  }

  linux_profile {
    admin_username = "ubuntu"

    ssh_key {
      key_data = file(var.ssh_public_key)
    }
  }
  network_profile {
    network_plugin     = "kubenet"
    network_policy     = "calico"
    service_cidr       = "172.16.0.0/16"
    dns_service_ip     = "172.16.0.10"
    pod_cidr           = "172.18.0.0/16"
    docker_bridge_cidr = "172.17.0.1/16"
    outbound_type      = "userDefinedRouting"
    load_balancer_sku  = "standard"
  }
}

```

下一步，我把 terraform 文件拆成了两部分，aks 之前的 subnet，资源组，路由表作为一部分，先用 treaform 创建出来。然后 aks 的创建，回到以前的方式，使用 azure cli 方式，即 az aks create -n cftestAKS001 -g  test-group --location eastus --network-plugin kubenet -- 等等一堆参数，结果还是一样的报错。这直接推翻了之前的理解，问题不在 terraform 定义的 aks 配置文件部分。而在于 subnet 或者 路由表。

我把 aks2的 subnet 和 路由表及授权信息，与 aks1 的subnet及路由表，在 azure portal 上进行了反复多次对比，并没有发现问题。现在虽然定位到了范围，但并没有找到根因。

所以还是回到了 aks 的关联资源去查看 Activity log，最终在 aks 的 node-resource-group 也就是自动创建出来的 MC_rg_xxx 那个资源组 Activity log 找到了一条关键信息。也就是总结里说的第三条。如果早点发现这条 log 就会少走很多弯路，要去关注相关的资源/资源组，因为对azure的每一次操作，都会在Activity log中留下记录，这也算是这次学到的一个很重要的点吧。

Activity log 中有一个操作 "write PrivateEndpoint" 状态为 Fail，查看这条 Fail 的JSON，不要查看子操作，子操作是start 记录，没有报错信息。

private endpoint 创建失败是因为 it has private endpoint network policies enabled

```bash
  "responseBody": "{\"error\":{\"code\":\"PrivateEndpointCannotBeCreatedInSubnetThatHasNetworkPoliciesEnabled\",\"message\":\"Private endpoint /subscriptions/xxxxx-xxxx-xxx/resourceGroups/MC_RG_xxxxxxxx/providers/Microsoft.Network/privateEndpoints/kube-apiserver cannot be created in a subnet /subscriptions/xxxxx-xxxxxx/resourceGroups/rg_xxxxxx/providers/Microsoft.Network/virtualNetworks/vnet1/subnets/subnet2 since it has private endpoint network policies enabled.\",\"details\":[]}}",
```

通过命令查询，这次通过terraform新建的subnet2，值是enabled  
```bash
~$ az network vnet subnet list --resource-group rg123--vnet-name vnet1 --query "[?name=='subnet2']" |grep -i privateEndpointNetworkPolicies
    "privateEndpointNetworkPolicies": "Enabled",
```

这是之前通过portal 创建的subnet1，值是disabled
```bash
~$ az network vnet subnet list --resource-group rg123 --vnet-name vnet1 --query "[?name=='subnet1']" |grep -i privateEndpointNetworkPolicies
    "privateEndpointNetworkPolicies": "Disabled",
```

在portal 再手动建一个subnet，确认下，确实如此
```bash
~$ az network vnet subnet list --resource-group rg123 --vnet-name vnet1 --query "[?name=='testsub']" |grep -i privateEndpointNetworkPolicies
    "privateEndpointNetworkPolicies": "Disabled",
```

修改 terraform main.tf 文件，在subnet加这一段  
  private_endpoint_network_policies_enabled = false

重新执行 terraform apply 成功创建aks

terraform 关于这个参数的说明： 
https://github.com/hashicorp/terraform-provider-azurerm/blob/main/website/docs/r/subnet.html.markdown

private_endpoint_network_policies_enabled - (Optional) Enable or Disable network policies for the private endpoint on the subnet. Setting this to true will Enable the policy and setting this to false will Disable the policy. Defaults to true.

-> NOTE: Network policies, like network security groups (NSG), are not supported for Private Link Endpoints or Private Link Services. In order to deploy a Private Link Endpoint on a given subnet, you must set the private_endpoint_network_policies_enabled attribute to false. This setting is only applicable for the Private Link Endpoint, for all other resources in the subnet access is controlled based via the Network Security Group which can be configured using the azurerm_subnet_network_security_group_association resource.

同时还发现了另外一个通过 terraform 部署的差异，就是 k8s api 的域名。当 enable Private cluster 时，terraform 创建 k8s api 域名是这样的，带有 privatelink，是私网域名，无法在公网解析。  
akseamobilesit02-hhjhanhy.75e5c9f7-ba13-4511-8a47-95b522e3fc38.privatelink.eastasia.azmk8s.io

而通过命令行创建 aks 时，enable Private cluster ，k8s 的api 地址是这样的 akseamobilesit02-mphslihq.hcp.eastasia.azmk8s.io ，不过也只是能解析到，是 vnet 内网地址，在公网是连不上的。也可以手动更新 aks 的配置 --enable-public-fqdn 来开启公网解析。

```bash
[root@centos8 private-aks]# nslookup akseamobilesit02-hhjhanhy.75e5c9f7-ba13-4511-8a47-95b522e3fc38.privatelink.eastasia.azmk8s.io
Server:         114.114.114.114
Address:        114.114.114.114#53

** server can't find akseamobilesit02-hhjhanhy.75e5c9f7-ba13-4511-8a47-95b522e3fc38.privatelink.eastasia.azmk8s.io: NXDOMAIN

[root@centos8 private-aks]# az aks update -g rg_ea_mobile_sit01 -n akseamobilesit02 --enable-public-fqdn

[root@centos8 private-aks]# nslookup akseamobilesit02-mphslihq.hcp.eastasia.azmk8s.io
Server:         114.114.114.114
Address:        114.114.114.114#53

Non-authoritative answer:
Name:   akseamobilesit02-mphslihq.hcp.eastasia.azmk8s.io
Address: 10.2.0.4
```

关于如何通过 terraform 创建一个专用 aks 集群提高安全性，可以参照之前的文章。  
https://github.com/cai11745/hybrid-cloud/blob/master/terraform/2023-03-10-terraform-create-private-aks.md

### 参考文档
https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs  
https://github.com/hashicorp/terraform-provider-azurerm/blob/main/website/docs/r/subnet.html.markdown

关注我的github，后续更新都会同步。  
https://github.com/cai11745/hybrid-cloud