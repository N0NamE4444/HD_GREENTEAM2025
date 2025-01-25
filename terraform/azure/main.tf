provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "main" {
  name     = "postgres-pgadmin-rg"
  location = "East US"
}

resource "azurerm_postgresql_flexible_server" "postgres" {
  name                = "postgresqlserver"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  version             = "13"
  administrator_login = var.postgres_user
  administrator_password = var.postgres_password

  sku_name   = "Standard_B1ms"
  storage_mb = 32768

  database_name = var.postgres_db
}

resource "azurerm_container_group" "pgadmin" {
  name                = "pgadmin"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location

  container {
    name   = "pgadmin"
    image  = "dpage/pgadmin4:latest"
    cpu    = "0.5"
    memory = "1.5"
    ports {
      port     = 80
      protocol = "TCP"
    }
    environment_variables = {
      PGADMIN_DEFAULT_EMAIL    = var.pgadmin_email
      PGADMIN_DEFAULT_PASSWORD = var.pgadmin_password
    }
  }

  os_type = "Linux"
}

output "connection_info" {
  value = {
    postgres = {
      host     = azurerm_postgresql_flexible_server.postgres.fqdn
      port     = 5432
      user     = var.postgres_user
      password = var.postgres_password
      database = var.postgres_db
    }
    pgadmin = {
      url      = azurerm_container_group.pgadmin.ip_address
      email    = var.pgadmin_email
      password = var.pgadmin_password
    }
  }
}
