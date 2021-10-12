provider "azurerm" {
  features {}
}

locals {
  subscription_name = "defaultServiceCallbackSubscription"
  retry_queue = "serviceCallbackRetryQueue"
    local_tags_ccpay = {
    "Deployment Environment" = var.env
    "Team Name" = var.team_name
    "Team Contact" = var.team_contact
  }

  tags = merge(var.common_tags, local.local_tags_ccpay)
}

resource "azurerm_resource_group" "rg" {
  name     = join("-", [var.product, var.env])
  location = var.location
}


module "ccpay-vault" {
  source = "git@github.com:hmcts/cnp-module-key-vault?ref=master"
  name = join("-", [var.product, var.env])
  product = var.product
  env = var.env
  tenant_id = var.tenant_id
  object_id = var.jenkins_AAD_objectId
  resource_group_name = azurerm_resource_group.rg.name
  # group id of dcd_reform_dev_azure
  product_group_name = "dcd_group_fees&pay_v2"
  common_tags         = var.common_tags
  #aks migration
   #managed_identity_object_ids = ["${var.managed_identity_object_id}"]
   # create_managed_identity = true
}

data "azurerm_key_vault" "ccpay_key_vault" {
  name                = module.ccpay-vault.key_vault_name
  resource_group_name = azurerm_resource_group.rg.name
}

data "azurerm_resource_group" "ccpay-rg" {
  name = "ccpay-demo"
}

module "servicebus-namespace" {
  source              = "git@github.com:hmcts/terraform-module-servicebus-namespace"
  name                = "${var.product}-servicebus-${var.env}"
  location            = var.location
  env                 = var.env
  common_tags         = local.tags
  resource_group_name = data.azurerm_resource_group.ccpay-rg.name
}

module "topic_payment_status" {
  source                = "git@github.com:hmcts/terraform-module-servicebus-topic"
  name                  = "ccpay-payment-status-topic"
  namespace_name        = module.servicebus-namespace.name
  resource_group_name   = data.azurerm_resource_group.ccpay-rg.name
}

module "subscription_payment_status" {
  source                = "git@github.com:hmcts/terraform-module-servicebus-subscription"
  name                  = local.subscription_name
  namespace_name        = module.servicebus-namespace.name
  topic_name            = module.topic_payment_status.name
  resource_group_name   = data.azurerm_resource_group.ccpay-rg.name
  max_delivery_count    = "10"
  # forward_dead_lettered_messages_to = module.queue.name
}

resource "azurerm_key_vault_secret" "ccpay-payment-status-connection-string" {
  name         = "ccpay-payment-status-connection-string"
  value        = module.topic_payment_status.primary_send_and_listen_shared_access_key
  key_vault_id = data.azurerm_key_vault.ccpay_key_vault.id
}

