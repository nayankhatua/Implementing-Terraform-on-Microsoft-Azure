#############################################################################
# VARIABLES
#############################################################################

variable "sec_resource_group_name" {
  type    = string
  default = "security"
}

variable "location" {
  type    = string
  default = "eastus"
}

variable "vnet_cidr_range" {
  type    = list(string)
  default = ["10.1.0.0/16"]
}

variable "sec_subnet_prefixes" {
  type    = list(string)
  default = ["10.1.0.0/24", "10.1.1.0/24"]
}

variable "sec_subnet_names" {
  type    = list(string)
  default = ["siem", "inspect"]
}

variable "use_for_each" {
  type    = bool
  default = true
}

#############################################################################
# DATA
#############################################################################

data "azurerm_subscription" "current" {}

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

provider "azuread" {

}

#############################################################################
# RESOURCES
#############################################################################

## NETWORKING ##

resource "azurerm_resource_group" "sec" {
  name     = var.sec_resource_group_name
  location = var.location

  tags = {
    environment = "security"
  }
}

module "vnet-sec" {
  source              = "Azure/vnet/azurerm"
  resource_group_name = azurerm_resource_group.sec.name
  vnet_location       = var.location
  vnet_name           = azurerm_resource_group.sec.name
  address_space       = var.vnet_cidr_range
  subnet_prefixes     = var.sec_subnet_prefixes
  subnet_names        = var.sec_subnet_names
  nsg_ids             = {}
  use_for_each        = var.use_for_each

  tags = {
    environment = "security"
    costcenter  = "security"

  }
}

## AZURE AD SP ##

resource "azuread_application" "vnet_peering" {
  display_name = "vnet-peer"
}

resource "azuread_service_principal" "vnet_peering" {
  application_id = azuread_application.vnet_peering.application_id
}

resource "azuread_service_principal_password" "vnet_peering" {
  service_principal_id = azuread_service_principal.vnet_peering.id
  end_date_relative    = "17520h"
}

resource "azurerm_role_definition" "vnet-peering" {
  name  = "allow-vnet-peering"
  scope = data.azurerm_subscription.current.id

  permissions {
    actions     = ["Microsoft.Network/virtualNetworks/virtualNetworkPeerings/write", "Microsoft.Network/virtualNetworks/peer/action", "Microsoft.Network/virtualNetworks/virtualNetworkPeerings/read", "Microsoft.Network/virtualNetworks/virtualNetworkPeerings/delete", "Microsoft.Network/virtualNetworks/peer/action"]
    not_actions = []
  }

  assignable_scopes = [
    data.azurerm_subscription.current.id,
  ]
}

resource "azurerm_role_assignment" "vnet" {
  scope              = module.vnet-sec.vnet_id
  role_definition_id = azurerm_role_definition.vnet-peering.role_definition_resource_id
  principal_id       = azuread_service_principal.vnet_peering.id
}

#############################################################################
# PROVISIONERS
#############################################################################

resource "null_resource" "post-config" {

  depends_on = [azurerm_role_assignment.vnet]

  provisioner "local-exec" {
    command = <<EOT
echo "export TF_VAR_sec_vnet_id=${module.vnet-sec.vnet_id}" >> next-step.txt
echo "export TF_VAR_sec_vnet_name=${module.vnet-sec.vnet_name}" >> next-step.txt
echo "export TF_VAR_sec_sub_id=${data.azurerm_subscription.current.subscription_id}" >> next-step.txt
echo "export TF_VAR_sec_client_id=${azuread_service_principal.vnet_peering.application_id}" >> next-step.txt
echo "export TF_VAR_sec_principal_id=${azuread_service_principal.vnet_peering.id}" >> next-step.txt
echo "export TF_VAR_sec_client_secret='${azuread_service_principal_password.vnet_peering.value}'" >> next-step.txt
echo "export TF_VAR_sec_resource_group=${azurerm_resource_group.sec.name}" >> next-step.txt
EOT
  }
}

#############################################################################
# OUTPUTS
#############################################################################

output "vnet_id" {
  value = module.vnet-sec.vnet_id
}

output "vnet_name" {
  value = module.vnet-sec.vnet_name
}

output "service_principal_client_id" {
  value = azuread_service_principal.vnet_peering.id
}

output "service_principal_client_secret" {
  value     = azuread_service_principal_password.vnet_peering.value
  sensitive = true
}

output "resource_group_name" {
  value = azurerm_resource_group.sec.name
}