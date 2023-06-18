#############################################################################
# VARIABLES
#############################################################################

variable "resource_group_name" {
  type = string
}

variable "location" {
  type    = string
  default = "eastus"
}


variable "vnet_cidr_range" {
  type = map(string)
  default = {
    development = "10.2.0.0/16"
    uat         = "10.3.0.0/16"
    production        = "10.4.0.0/16"
  }
}

variable "subnet_names" {
  type    = list(string)
  default = ["web", "database", "app"]
}

variable "use_for_each" {
  type    = bool
  default = true
}

locals {
  full_rg_name = "${terraform.workspace}-${var.resource_group_name}"
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
    azuread = {
      source = "hashicorp/azuread"
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

data "template_file" "subnet_prefixes" {
  count = length(var.subnet_names)

  template = "$${cidrsubnet(vnet_cidr,8,current_count)}"

  vars = {
    vnet_cidr     = var.vnet_cidr_range[terraform.workspace]
    current_count = count.index
  }
}

resource "azurerm_resource_group" "main" {
  name     = local.full_rg_name
  location = var.location

  tags = {
    environment = terraform.workspace
  }
}

module "vnet-main" {
  source              = "Azure/vnet/azurerm"
  resource_group_name = azurerm_resource_group.main.name
  vnet_location            = var.location
  vnet_name           = azurerm_resource_group.main.name
  address_space       = [var.vnet_cidr_range[terraform.workspace]]
  subnet_prefixes     = data.template_file.subnet_prefixes[*].rendered
  subnet_names        = var.subnet_names
  nsg_ids             = {}
  use_for_each = var.use_for_each

  tags = {
    environment = terraform.workspace
    costcenter  = "it"

  }
}

#############################################################################
# OUTPUTS
#############################################################################

output "vnet_id" {
  value = module.vnet-main.vnet_id
}

output "vnet_name" {
  value = module.vnet-main.vnet_name
}

output "resource_group_name" {
  value = azurerm_resource_group.main.name
}


