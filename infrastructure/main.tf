locals {
  subscription_name = "defaultServiceCallbackSubscription"
  retry_queue = "serviceCallbackRetryQueue"
}

module "servicebus-namespace" {
  source              = "git@github.com:hmcts/terraform-module-servicebus-namespace"
  name                = "${var.product}-servicebus-${var.env}"
  location            = var.location
  env                 = var.env
  common_tags         = local.tags
  resource_group_name = azurerm_resource_group.rg.name
}

module "topic_payment_status" {
  source                = "git@github.com:hmcts/terraform-module-servicebus-topic"
  name                  = "ccpay-payment-status-topic"
  namespace_name        = module.servicebus-namespace.name
  resource_group_name   = azurerm_resource_group.rg.name
}

module "subscription_payment_status" {
  source                = "git@github.com:hmcts/terraform-module-servicebus-subscription"
  name                  = local.subscription_name
  namespace_name        = module.servicebus-namespace.name
  topic_name            = module.topic_payment_status.name
  resource_group_name   = azurerm_resource_group.rg.name
  max_delivery_count    = "10"
  # forward_dead_lettered_messages_to = module.queue.name
}

resource "azurerm_key_vault_secret" "ccpay-payment-status-connection-string" {
  name         = "ccpay-payment-status-connection-string"
  value        = module.topic_payment_status.primary_send_and_listen_shared_access_key
  key_vault_id = data.azurerm_key_vault.ccpay_key_vault.id
}

