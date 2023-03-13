Terraform 简介与示例

Terraform 是一种安全有效地构建、更改和版本控制基础设施的工具(基础架构自动化的编排工具)。它的目标是 "Write, Plan, and create Infrastructure as Code", 基础架构即代码。

Terraform 几乎可以支持所有市面上能见到的云服务。具体的说就是可以用代码（其实就是配置文件定义）来管理维护 IT 资源，把之前需要手动操作的一部分任务通过程序来自动化的完成，这样的做的结果非常明显：高效、不易出错。

用法与k8s容器平台的helm有点类似，都是声明式资源管理，并对版本有较好的管理，配合git食用更佳。

下文将练习通过Terraform在Azure云上创建资源组、vnet、虚拟机。

其实Azure本身提供了ARM模板配合变量配置文件，也是以声明式创建和管理资源。
但我更好奇Terraform到底有什么魔力，让各大云厂商在官方文档里进行推介，容我一探究竟。

### 安装 terraform
支持 MAC，Win，Linux  
https://developer.hashicorp.com/terraform/tutorials/azure-get-started/install-cli

Centos/RHEL  
```bash
sudo yum install -y yum-utils
sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo
sudo yum -y install terraform
```

检查版本
```bash
[root@centos8 azure-terraform]# terraform version
Terraform v1.3.9
on linux_amd64
+ provider registry.terraform.io/hashicorp/azurerm v3.44.1
```

开启命令自动补全，执行完重新进入下bas窗口

```bash
 touch ~/.bashrc
terraform -install-autocomplete
```

### 安装 Azure CLI 及登录认证
https://learn.microsoft.com/zh-cn/cli/azure/install-azure-cli

Azure CLI 的 RPM 包依赖于 python3 包。Centos7 可能会遇到些问题，Centos8没问题。我此处用的Centos8.5

```bash
sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
sudo dnf install -y https://packages.microsoft.com/config/rhel/8/packages-microsoft-prod.rpm
sudo dnf install azure-cli

# 查看版本
[root@centos8 azure-terraform]# az version
{
  "azure-cli": "2.45.0",
  "azure-cli-core": "2.45.0",
  "azure-cli-telemetry": "1.0.8",
  "extensions": {}
}
```

### 使用Terraform创建资源组
先尝试实现一个最简单场景，了解下大概的使用流程。

#### 创建配置文件
新建一个空目录，并在其中创建一个 main.tf 文件

```bash
mkdir azure-terraform
cd azure-terraform/
```

编辑 main.tf 配置文件  
```bash
[root@centos8 azure-terraform]# cat main.tf
# We strongly recommend using the required_providers block to set the
# Azure Provider source and version being used
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.44.1"
    }
  }
}

# Configure the Microsoft Azure Provider
provider "azurerm" {
  features {}
}

# Create a resource group
resource "azurerm_resource_group" "example" {
  name     = "example-resources"
  location = "West Europe"
}

```

文件的上半部分 terraform/provider 定义了将要使用什么云，及插件的版本，在以下连接的右上角“USE PROVIDER”查看。 resource 部分表示要创建的资源，此处是创建一个资源组，在以下连接的右上角“Documentation”，有所有支持的资源定义解读。
https://registry.terraform.io/providers/hashicorp/azurerm/latest

#### Azure 权限认证
在通过 Terraform 创建之前，需要先配置权限认证，才能去创建或配置资源。

https://learn.microsoft.com/zh-cn/azure/developer/terraform/authenticate-to-azure?tabs=bash

主要两种方式：
1. 通过powershell 或者 az cli 进行认证
2. 通过服务主体。服务主体创建后，可以在环境变量指定ID和密码。也可以配置在main.tf（明文，不安全）

此处就通过最简单的方式，执行 az login  
注意如果是国内azure云，也就是21世纪互联运营的那个，需要切到中国区 az cloud set --name AzureCloud 

```bash
az login
# 查看订阅
az account show
# 切换订阅
az account set --subscription "<subscription_id_or_subscription_name>"
```

#### 初始化插件
执行 terraform init。 terraform init 会分析 xxx.tf 代码中所使用到的Provider，并尝试下载Provider插件到本地  
如果网络连不上多执行几次，国内网络老大难。。。

成功后会看到提示 "Terraform has been successfully initialized!"

可以看到新增了两个隐藏文件，目录下就有 azure privider 的插件
```bash
[root@centos8 azure-terraform]# tree
.
└── main.tf

0 directories, 1 file
[root@centos8 azure-terraform]# tree -a
.
├── main.tf
├── .terraform
│   └── providers
│       └── registry.terraform.io
│           └── hashicorp
│               └── azurerm
│                   └── 3.44.1
│                       └── linux_amd64
│                           └── terraform-provider-azurerm_v3.44.1_x5
└── .terraform.lock.hcl

7 directories, 3 files

```

#### 格式化和校验配置文件（可选操作）
执行 terraform fmt 格式化配置文件，比如对齐。如果自动修改了文件，会列出修改的内容。同时对错误的格式也会指出，建议执行。

terraform validate 验证配置文件，和上面命令有点类似，但是不会去修改文件

#### terraform plan 预览变更
执行 terraform plan 可以预览一下代码即将产生的变更：

```bash
[root@centos8 azure-terraform]# terraform plan

Terraform used the selected providers to generate the following execution plan. Resource actions are
indicated with the following symbols:
  + create

Terraform will perform the following actions:

  # azurerm_resource_group.example will be created
  + resource "azurerm_resource_group" "example" {
      + id       = (known after apply)
      + location = "westeurope"
      + name     = "example-resources"
    }

Plan: 1 to add, 0 to change, 0 to destroy.

───────────────────────────────────────────────────────────────────────────────────────────────────────────

Note: You didn't use the -out option to save this plan, so Terraform can't guarantee to take exactly these
actions if you run "terraform apply" now.

```

#### terraform apply 执行变更
运行terraform apply 时，Terraform会首先重新计算一下变更计划，并且像刚才执行plan命令那样把变更计划打印给我们，要求我们人工确认。让我们输入yes，然后回车

```bash
[root@centos8 azure-terraform]# terraform apply

Terraform used the selected providers to generate the following execution plan. Resource actions are
indicated with the following symbols:
  + create

Terraform will perform the following actions:

  # azurerm_resource_group.example will be created
  + resource "azurerm_resource_group" "example" {
      + id       = (known after apply)
      + location = "westeurope"
      + name     = "example-resources"
    }

Plan: 1 to add, 0 to change, 0 to destroy.

Do you want to perform these actions?
  Terraform will perform the actions described above.
  Only 'yes' will be accepted to approve.

  Enter a value: yes

azurerm_resource_group.example: Creating...
azurerm_resource_group.example: Creation complete after 6s [id=/subscriptions/3c398848-b31e-427a-aa4e-3b87b2ae6064/resourceGroups/example-resources]

Apply complete! Resources: 1 added, 0 changed, 0 destroyed.

```

#### terraform show 查看当前部署

查看当前部署资源属性和元数据，可以用这些值来配置其他资源
```bash
[root@centos8 azure-terraform]# terraform show
# azurerm_resource_group.example:
resource "azurerm_resource_group" "example" {
    id       = "/subscriptions/3c398848-b31e-427a-aa4e-3b87b2ae6064/resourceGroups/example-resources"
    location = "westeurope"
    name     = "example-resources"
}

# terraform state list  命令可以列出创建的资源列表
[root@centos8 azure-terraform]# terraform state list
azurerm_resource_group.example
```

apply 完成后将变更操作时的状态信息保存在一个状态文件中，默认情况下会保存在当前工作目录下的terraform.tfstate文件里。不要手动修改这个文件。 再次执行 apply 的时候会检查 tfstate 文件，如果没有这个文件，会认为是第一次创建。 同时下一步 destroy 删除资源的时候也依赖这个文件。  
同时 tfstate 中的密码都是明文的，存储需注意安全。

```bash
[root@centos8 azure-terraform]# cat terraform.tfstate
{
  "version": 4,
  "terraform_version": "1.3.9",
  "serial": 1,
  "lineage": "27786e94-4a19-71cc-43e4-e2d1dfa1f851",
  "outputs": {},
  "resources": [
    {
      "mode": "managed",
      "type": "azurerm_resource_group",
      "name": "example",
      "provider": "provider[\"registry.terraform.io/hashicorp/azurerm\"]",
      "instances": [
        {
          "schema_version": 0,
          "attributes": {
            "id": "/subscriptions/3c398848-b31e-427a-aa4e-3b87b2ae6064/resourceGroups/example-resources",
            "location": "westeurope",
            "name": "example-resources",
            "tags": null,
            "timeouts": null
          },
          "sensitive_attributes": [],
          "private": "eyJlMmJmYjczMC1lY2FhLTExZTYtOGY4OC0zNDM2M2JjN2M0YzAiOnsiY3JlYXRlIjo1NDAwMDAwMDAwMDAwLCJkZWxldGUiOjU0MDAwMDAwMDAwMDAsInJlYWQiOjMwMDAwMDAwMDAwMCwidXBkYXRlIjo1NDAwMDAwMDAwMDAwfX0="
        }
      ]
    }
  ],
  "check_results": null
}
```

#### terraform destroy 清理资源
会列出要清理的对象进行确认，清理之后会自动把 tfstate 文件备份 terraform.tfstate.backup 。原文件 terraform.tfstate 中 resource 部分会被清空了。

### 创建 vnet 和虚拟机

main.tf 增加vnet，sub，vm 等配置文件。注意下变量的引用，vnet 会引用RG名称，网卡引用subnet id

```bash
[root@centos8 azure-terraform]# cat main.tf
# We strongly recommend using the required_providers block to set the
# Azure Provider source and version being used
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.44.1"
    }
  }
}

# Configure the Microsoft Azure Provider
provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "main" {
  name     = "${var.prefix}-resources"
  location = var.location
}

resource "azurerm_virtual_network" "main" {
  name                = "${var.prefix}-network"
  address_space       = ["10.0.0.0/22"]
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_subnet" "internal" {
  name                 = "internal"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_network_interface" "main" {
  name                = "${var.prefix}-nic"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.internal.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "main" {
  name                            = "${var.prefix}-vm"
  resource_group_name             = azurerm_resource_group.main.name
  location                        = azurerm_resource_group.main.location
  size                            = "Standard_D2s_v3"
  admin_username                  = "${var.username}"
  admin_password                  = "${var.password}"
  disable_password_authentication = false
  network_interface_ids = [
    azurerm_network_interface.main.id,
  ]

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  os_disk {
    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"
  }
}

```

variables.tf 定义资源名称前缀，地区，vm的用户名密码

```bash
[root@centos8 azure-terraform]# cat variables.tf
variable "prefix" {
  description = "The prefix which should be used for all resources in this example"
  type    = string
  default = "demo"
}

variable "location" {
  description = "The Azure Region in which all resources in this example should be created."
  type    = string
  default = "eastus"
}

variable "username" {
  description = "The virtual machine username."
  type    = string
  default = "caifeng"
}

variable "password" {
  description = "The virtual machine password."
  type    = string
  default = "abcdef@123"
}

```

terraform apply 更新变更，可以在portal 上查看RG,VM信息。 state list 查看资源列表。

```bash
[root@centos8 azure-terraform]# terraform apply

[root@centos8 azure-terraform]# terraform state list
azurerm_linux_virtual_machine.main
azurerm_network_interface.main
azurerm_resource_group.main
azurerm_subnet.internal
azurerm_virtual_network.main
```


### 参考文档
https://developer.hashicorp.com/terraform/cloud-docs/workspaces/dynamic-provider-credentials/azure-configuration  
https://registry.terraform.io/providers/hashicorp/azurerm/latest  
https://lonegunmanb.github.io/introduction-terraform/

关注我的github，后续更新会同步上去

https://github.com/cai11745/hybrid-cloud

