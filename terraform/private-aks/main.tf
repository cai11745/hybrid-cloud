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

# Create NAT Gateway with a public IP. Associates NAT Gateway with sub1.
resource "azurerm_public_ip" "pubip1" {
  name                = "nat-gateway-publicIP"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1"]
}

#resource "azurerm_public_ip_prefix" "example" {
#  name                = "nat-gateway-publicIPPrefix"
#  location            = azurerm_resource_group.example.location
#  resource_group_name = azurerm_resource_group.example.name
#  prefix_length       = 30
#  zones               = ["1"]
#}

resource "azurerm_nat_gateway" "gw1" {
  name                    = "nat-Gateway"
  location                = azurerm_resource_group.rg.location
  resource_group_name     = azurerm_resource_group.rg.name
  sku_name                = "Standard"
  idle_timeout_in_minutes = 10
  zones                   = ["1"]
}

resource "azurerm_nat_gateway_public_ip_association" "gw1_pubip1" {
  nat_gateway_id       = azurerm_nat_gateway.gw1.id
  public_ip_address_id = azurerm_public_ip.pubip1.id
}

resource "azurerm_subnet_nat_gateway_association" "gw1_sub1" {
  subnet_id      = azurerm_subnet.sub1.id
  nat_gateway_id = azurerm_nat_gateway.gw1.id
}

# Create route table
resource "azurerm_route_table" "rt1" {
  name                          = "rt${var.subnet_name}"
  location                      = azurerm_resource_group.rg.location
  resource_group_name           = azurerm_resource_group.rg.name
  disable_bgp_route_propagation = false
}

resource "azurerm_subnet_route_table_association" "example" {
  subnet_id      = azurerm_subnet.sub1.id
  route_table_id = azurerm_route_table.rt1.id
}

# Create user assigned managed identity for AKS master and node
resource "azurerm_user_assigned_identity" "uai_master" {
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  name                = "${var.cluster_name}-aks-master-identity"
}

#resource "azurerm_user_assigned_identity" "uai_node" {
#  resource_group_name = azurerm_resource_group.rg.name
#  location            = azurerm_resource_group.rg.location
#  name                = "${var.cluster_name}-aks-node-identity"
#}

# Assign the "Network Contributor" role on route table to the AKS managed identity.
resource "azurerm_role_assignment" "route_table_network_contributor" {
  scope                = azurerm_route_table.rt1.id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_user_assigned_identity.uai_master.principal_id
}

resource "azurerm_kubernetes_cluster" "k8s" {
  depends_on = [azurerm_role_assignment.route_table_network_contributor, azurerm_nat_gateway_public_ip_association.gw1_pubip1, azurerm_subnet_nat_gateway_association.gw1_sub1]

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
    service_cidr       = "172.28.0.0/16"
    dns_service_ip     = "172.28.0.10"
    pod_cidr           = "172.29.0.0/16"
    docker_bridge_cidr = "172.16.0.0/16"
    outbound_type      = "userDefinedRouting"
    load_balancer_sku  = "standard"
  }
}
