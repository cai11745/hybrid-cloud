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
