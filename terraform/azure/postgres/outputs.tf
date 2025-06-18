output "postgres_fqdn" {
  description = "The fully qualified domain name (FQDN) of the PostgreSQL server."
  value       = azurerm_postgresql_server.this.fqdn
}

output "postgres_server_id" {
  description = "The resource ID of the PostgreSQL server."
  value       = azurerm_postgresql_server.this.id
}

output "database_name" {
  description = "The name of the deployed PostgreSQL database."
  value       = azurerm_postgresql_database.this_database.name
}
