resource "azurerm_resource_group" "rg" {
  location = var.resource_group_location
  name     = var.resource_group_name
  tags = {
    CostCenter = var.resource_group_costcenter
    owner      = var.resource_group_owner
    source     = "terraform"
  }
}

resource "azurerm_virtual_network" "vnet1" {
  name                = var.vnet_name
  address_space       = var.vnet_range
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "sub1" {
  name                 = var.subnet_name
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet1.name
  address_prefixes     = var.subnet_range
}

resource "azurerm_kubernetes_cluster" "k8s" {

  location            = azurerm_resource_group.rg.location
  name                = var.cluster_name
  resource_group_name = azurerm_resource_group.rg.name
  dns_prefix          = var.dns_prefix

  identity {
    type = "SystemAssigned"
  }

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
    service_cidr       = "172.28.0.0/16"
    dns_service_ip     = "172.28.0.10"
    pod_cidr           = "172.29.0.0/16"
    docker_bridge_cidr = "172.16.0.0/16"
    load_balancer_sku  = "standard"
  }
}
