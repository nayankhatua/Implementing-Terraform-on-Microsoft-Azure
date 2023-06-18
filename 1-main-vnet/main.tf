#############################################################################
# VARIABLES
#############################################################################

variable "resource_group_name" {
  type = string
}

variable "vnet_location" {
  type    = string
  default = "eastus"
}


variable "vnet_cidr_range" {
  type    = list(string)
  default = ["10.0.0.0/16"]
}

variable "subnet_prefixes" {
  type    = list(string)
  default = ["10.0.0.0/24", "10.0.1.0/24"]
}

variable "subnet_names" {
  type    = list(string)
  default = ["web", "database"]
}

variable "use_for_each" {
  type    = bool
  default = true
}

#############################################################################
# PROVIDERS
#############################################################################

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"

    }
  }
}

provider "azurerm" {
  features {

  }
}

#############################################################################
# RESOURCES
#############################################################################

## note sure if resource groups were ever created by Vnet module, but they certainly aren't anymore.
resource "azurerm_resource_group" "vnet_1" {
  name     = var.resource_group_name
  location = var.vnet_location
}

module "vnet-main" {
  source              = "Azure/vnet/azurerm"
  resource_group_name = azurerm_resource_group.vnet_1.name
  vnet_location       = azurerm_resource_group.vnet_1.location
  vnet_name           = azurerm_resource_group.vnet_1.name
  address_space       = var.vnet_cidr_range
  subnet_prefixes     = var.subnet_prefixes
  subnet_names        = var.subnet_names
  nsg_ids             = {}
  use_for_each        = var.use_for_each


  tags = {
    environment = "dev"
    costcenter  = "it"

  }
}

#############################################################################
# OUTPUTS
#############################################################################

output "vnet_id" {
  value = module.vnet-main.vnet_id
}
