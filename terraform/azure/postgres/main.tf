resource "azurerm_postgresql_server" "this" {
  name                         = var.server_name
  location                     = var.location
  resource_group_name          = var.resource_group_name
  administrator_login          = var.administrator_login
  administrator_login_password = var.administrator_login_password
  sku_name                     = var.sku_name
  storage_mb                   = var.storage_mb
  version                      = var.version
  backup_retention_days        = var.backup_retention_days
  geo_redundant_backup_enabled = var.geo_redundant_backup_enabled
  auto_grow_enabled            = var.auto_grow_enabled
  public_network_access_enabled = var.public_network_access_enabled
  ssl_enforcement_enabled      = var.ssl_enforcement_enabled
  tags                         = var.tags
}

resource "azurerm_postgresql_database" "this_database" {
  name                = var.database_name
  resource_group_name = var.resource_group_name
  server_name         = azurerm_postgresql_server.this.name
  charset             = var.charset
  collation           = var.collation
}

resource "azurerm_postgresql_firewall_rule" "allow_all" {
  name                = var.firewall_rule_name
  resource_group_name = var.resource_group_name
  server_name         = azurerm_postgresql_server.this.name
  start_ip_address    = var.start_ip_address
  end_ip_address      = var.end_ip_address
}
