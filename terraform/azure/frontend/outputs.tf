output "fqdn" {
  description = "The externally accessible FQDN of the frontend container app"
  value       = azurerm_container_app.frontend.fqdn
}

output "id" {
  description = "The resource ID of the frontend container app"
  value       = azurerm_container_app.frontend.id
}
