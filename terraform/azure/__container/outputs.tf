output "container_group_id" {
  description = "The ID of the container group"
  value       = azurerm_container_group.container.id
}

output "container_group_ip" {
  description = "The IP address of the container group"
  value       = azurerm_container_group.container.ip_address[0].ip
}
