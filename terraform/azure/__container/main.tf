resource "azurerm_container_group" "container" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name
  os_type             = "Linux"

  container {
    name   = var.name
    image  = var.image
    cpu    = var.cpu
    memory = var.memory

    dynamic "environment_variables" {
      for_each = var.environment_variables
      content {
        name  = environment_variables.key
        value = environment_variables.value
      }
    }

    dynamic "ports" {
      for_each = var.ports
      content {
        port     = ports.value
        protocol = "TCP"
      }
    }
  }

  ip_address {
    type = var.ip_type

    dynamic "ports" {
      for_each = var.ports
      content {
        protocol = "TCP"
        port     = ports.value
      }
    }
  }

  network_profile {
    id = var.network_profile_id
  }
}
