provider "azurerm" {
  features {}
}

locals {
  subscription_name = "defaultServiceCallbackSubscription"
  
  # retry_queue = "serviceCallbackRetryQueue"
  # local_tags_ccpay = {
  #   "Deployment Environment" = var.env
  #   "Team Name" = var.team_name
  #   "Team Contact" = var.team_contact
  # }

  # tags = merge(var.common_tags, local.local_tags_ccpay)
}

data "azurerm_resource_group" "ccpay_rg" {
  name     = join("-", [var.product, var.env])
}

data "azurerm_key_vault" "ccpay_key_vault" {
  name                = join("-", [var.product, var.env])
  resource_group_name = data.azurerm_resource_group.ccpay_rg.name
}

data "azurerm_servicebus_namespace" "ccpay_servicebus_namespce" {
  name                = join("-", [var.product, "servicebus", var.env])
  resource_group_name = data.azurerm_resource_group.ccpay_rg.name
}

module "topic_payment_status" {
  source                = "git@github.com:hmcts/terraform-module-servicebus-topic?ref=master"
  name                  = "ccpay-payment-status-topic"
  namespace_name        = data.azurerm_servicebus_namespace.ccpay_servicebus_namespce.name
  resource_group_name   = data.azurerm_resource_group.ccpay_rg.name
}

module "subscription_payment_status" {
  source                = "git@github.com:hmcts/terraform-module-servicebus-subscription?ref=master"
  name                  = local.subscription_name
  namespace_name        = data.azurerm_servicebus_namespace.ccpay_servicebus_namespce.name
  topic_name            = module.topic_payment_status.name
  resource_group_name   = data.azurerm_resource_group.ccpay_rg.name
  max_delivery_count    = "10"
  # forward_dead_lettered_messages_to =  module.queue.name 
}

resource "azurerm_key_vault_secret" "ccpay-payment-status-connection-string" {
  name         = "ccpay-payment-status-connection-string"
  value        = module.topic_payment_status.primary_send_and_listen_shared_access_key
  key_vault_id = data.azurerm_key_vault.ccpay_key_vault.id
}