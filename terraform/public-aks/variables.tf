variable "resource_group_name" {
  default     = "rg_ea_aks_pub01"
  description = "ResourceGroup_Location_Application_EnvironmentNumber."
}

variable "resource_group_location" {
  default     = "eastasia"
  description = "Location of the resource group."
}

variable "resource_group_costcenter" {
  default     = "mobile public aks"
  description = "CostCenter of the resource group."
}

variable "resource_group_owner" {
  default     = "caifeng"
  description = "Owner of the resource group."
}

variable "vnet_name" {
  default = "vneaakspub01"
}

variable "vnet_range" {
  type        = list(string)
  default     = ["10.4.0.0/16"]
  description = "Address range for deployment VNet"
}

variable "subnet_name" {
  default = "sneakspub01"
}

variable "subnet_range" {
  type        = list(string)
  default     = ["10.4.1.0/24"]
  description = "Address range for session host subnet"
}

variable "cluster_name" {
  default = "eaakspub01"
}

variable "dns_prefix" {
  default = "eaakspub01"
}

variable "agent_vm_size" {
  default = "Standard_B2s"
}

variable "agent_count" {
  default = 1
}

variable "ssh_public_key" {
  default = "~/.ssh/id_rsa.pub"
}

