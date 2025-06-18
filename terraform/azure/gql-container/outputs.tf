output "fqdn" {
  description = "The internal FQDN of the deployed gql container app."
  value       = azurerm_container_app.gql.default_hostname
}
