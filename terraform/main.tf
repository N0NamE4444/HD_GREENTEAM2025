# main.tf

# 1. Configure the Azure Provider
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.33.0"
    }
  }
}

provider "azurerm" {
  subscription_id = var.subscription_id
  features {}
}

# 2. Define variables for naming and location
variable "subscription_id" {
  type    = string
  default = ""
}

variable "resource_group_name" {
  type    = string
  default = "rg-hk2025-app"
}

variable "location" {
  type    = string
  default = "North Europe"
}

variable "container_app_environment_name" {
  type    = string
  default = "cae-hk2025-environment"
}

variable "postgres_password" {
  type      = string
  default   = "example"
  sensitive = true
}

# 3. Create a Resource Group
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}

# 4. Create a Log Analytics Workspace (required for Container Apps Environment)
resource "azurerm_log_analytics_workspace" "logs" {
  name                = "log-${var.container_app_environment_name}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

# 5. Create the Container Apps Environment
resource "azurerm_container_app_environment" "cae" {
  name                       = var.container_app_environment_name
  location                   = azurerm_resource_group.rg.location
  resource_group_name        = azurerm_resource_group.rg.name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.logs.id
}

# 6. PostgreSQL Flexible Server for GQL services
resource "azurerm_postgresql_flexible_server" "postgres_gql" {
  name                   = "psql-gql-hk2025"
  resource_group_name    = azurerm_resource_group.rg.name
  location               = azurerm_resource_group.rg.location
  version                = "13"
  administrator_login    = "postgres"
  administrator_password = var.postgres_password
  zone                   = "1"

  # Cheapest tier for demo
  sku_name   = "B_Standard_B1ms"
  storage_mb = 32768 # 32GB minimum

  backup_retention_days = 7

  # Allow Azure services to access
  public_network_access_enabled = true
}

# Database for GQL services
resource "azurerm_postgresql_flexible_server_database" "gql_db" {
  name      = "data"
  server_id = azurerm_postgresql_flexible_server.postgres_gql.id
  collation = "en_US.utf8"
  charset   = "utf8"
}

# Firewall rule to allow Azure services
resource "azurerm_postgresql_flexible_server_firewall_rule" "allow_azure" {
  name             = "AllowAzureServices"
  server_id        = azurerm_postgresql_flexible_server.postgres_gql.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

# 7. PostgreSQL Flexible Server for credentials
resource "azurerm_postgresql_flexible_server" "postgres_credentials" {
  name                   = "psql-cred-hk2025"
  resource_group_name    = azurerm_resource_group.rg.name
  location               = azurerm_resource_group.rg.location
  version                = "13"
  administrator_login    = "postgres"
  administrator_password = var.postgres_password
  zone                   = "3"

  # Cheapest tier for demo
  sku_name   = "B_Standard_B1ms"
  storage_mb = 32768 # 32GB minimum

  backup_retention_days = 7

  # Allow Azure services to access
  public_network_access_enabled = true
}

# Database for credentials
resource "azurerm_postgresql_flexible_server_database" "credentials_db" {
  name      = "data"
  server_id = azurerm_postgresql_flexible_server.postgres_credentials.id
  collation = "en_US.utf8"
  charset   = "utf8"
}

# Firewall rule to allow Azure services
resource "azurerm_postgresql_flexible_server_firewall_rule" "allow_azure_cred" {
  name             = "AllowAzureServices"
  server_id        = azurerm_postgresql_flexible_server.postgres_credentials.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

# 8. Container App for GQL UG service
resource "azurerm_container_app" "gql_ug" {
  name                         = "gql-ug"
  container_app_environment_id = azurerm_container_app_environment.cae.id
  resource_group_name          = azurerm_resource_group.rg.name
  revision_mode                = "Single"

  template {
    min_replicas = 1
    max_replicas = 3

    volume {
      name         = "systemdata-volume"
      storage_name = azurerm_container_app_environment_storage.env_storage.name
      storage_type = "AzureFile"
    }

    container {
      name   = "gql-ug"
      image  = "hrbolek/gql_ug:0.8.6"
      cpu    = 0.25
      memory = "0.5Gi"

      volume_mounts {
        name     = "systemdata-volume"
        sub_path = "systemdata.json"
        path     = "/app/systemdata.json"
      }
      env {
        name  = "POSTGRES_HOST"
        value = "${azurerm_postgresql_flexible_server.postgres_gql.fqdn}:5432"
      }
      env {
        name  = "POSTGRES_USER"
        value = "postgres"
      }
      env {
        name        = "POSTGRES_PASSWORD"
        secret_name = "postgres-password"
      }
      env {
        name  = "POSTGRES_DB"
        value = "data"
      }
      env {
        name  = "JWTPUBLICKEYURL"
        value = "http://frontend:8000/oauth/publickey"
      }
      env {
        name  = "JWTRESOLVEUSERPATHURL"
        value = "http://frontend:8000/oauth/userinfo"
      }
      env {
        name  = "DEMO"
        value = "False"
      }
      env {
        name  = "DEMODATA"
        value = "True"
      }
    }
  }

  secret {
    name  = "postgres-password"
    value = var.postgres_password
  }

  ingress {
    external_enabled = false
    target_port      = 8000

    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }

  depends_on = [
    azurerm_postgresql_flexible_server_database.gql_db
  ]
}

# 9. Container App for GQL External IDs service
resource "azurerm_container_app" "gql_externalids" {
  name                         = "gql-externalids"
  container_app_environment_id = azurerm_container_app_environment.cae.id
  resource_group_name          = azurerm_resource_group.rg.name
  revision_mode                = "Single"

  template {
    min_replicas = 1
    max_replicas = 3

    volume {
      name         = "systemdata-volume"
      storage_name = azurerm_container_app_environment_storage.env_storage.name
      storage_type = "AzureFile"
    }

    container {
      name   = "gql-externalids"
      image  = "hrbolek/gql_externalids:0.8.7"
      cpu    = 0.25
      memory = "0.5Gi"

      volume_mounts {
        name     = "systemdata-volume"
        sub_path = "systemdata.json"
        path     = "/app/systemdata.json"
      }
      env {
        name  = "POSTGRES_HOST"
        value = "${azurerm_postgresql_flexible_server.postgres_gql.fqdn}:5432"
      }
      env {
        name  = "POSTGRES_USER"
        value = "postgres"
      }
      env {
        name        = "POSTGRES_PASSWORD"
        secret_name = "postgres-password"
      }
      env {
        name  = "POSTGRES_DB"
        value = "data"
      }
      env {
        name  = "GQLUG_ENDPOINT_URL"
        value = "http://gql-ug:8000/gql"
      }
      env {
        name  = "JWTPUBLICKEYURL"
        value = "http://frontend:8000/oauth/publickey"
      }
      env {
        name  = "JWTRESOLVEUSERPATHURL"
        value = "http://frontend:8000/oauth/userinfo"
      }
      env {
        name  = "DEMO"
        value = "False"
      }
      env {
        name  = "DEMODATA"
        value = "True"
      }
    }
  }

  secret {
    name  = "postgres-password"
    value = var.postgres_password
  }

  ingress {
    external_enabled = false
    target_port      = 8000

    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }
}

# 10. Container App for GQL Events service
resource "azurerm_container_app" "gql_events" {
  name                         = "gql-events"
  container_app_environment_id = azurerm_container_app_environment.cae.id
  resource_group_name          = azurerm_resource_group.rg.name
  revision_mode                = "Single"

  template {
    min_replicas = 1
    max_replicas = 2

    volume {
      name         = "systemdata-volume"
      storage_name = azurerm_container_app_environment_storage.env_storage.name
      storage_type = "AzureFile"
    }

    container {
      name   = "gql-events"
      image  = "hrbolek/gql_events:0.8.7"
      cpu    = 0.25
      memory = "0.5Gi"

      volume_mounts {
        name     = "systemdata-volume"
        sub_path = "systemdata.json"
        path     = "/app/systemdata.json"
      }
      env {
        name  = "POSTGRES_HOST"
        value = "${azurerm_postgresql_flexible_server.postgres_gql.fqdn}:5432"
      }
      env {
        name  = "POSTGRES_USER"
        value = "postgres"
      }
      env {
        name        = "POSTGRES_PASSWORD"
        secret_name = "postgres-password"
      }
      env {
        name  = "POSTGRES_DB"
        value = "data"
      }
      env {
        name  = "GQLUG_ENDPOINT_URL"
        value = "http://gql-ug:8000/gql"
      }
      env {
        name  = "JWTPUBLICKEYURL"
        value = "http://frontend:8000/oauth/publickey"
      }
      env {
        name  = "JWTRESOLVEUSERPATHURL"
        value = "http://frontend:8000/oauth/userinfo"
      }
      env {
        name  = "DEMO"
        value = "False"
      }
      env {
        name  = "DEMODATA"
        value = "True"
      }
    }
  }

  secret {
    name  = "postgres-password"
    value = var.postgres_password
  }

  ingress {
    external_enabled = false
    target_port      = 8000

    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }
}

# 11. Container App for GQL Facilities service
resource "azurerm_container_app" "gql_facilities" {
  name                         = "gql-facilities"
  container_app_environment_id = azurerm_container_app_environment.cae.id
  resource_group_name          = azurerm_resource_group.rg.name
  revision_mode                = "Single"

  template {
    min_replicas = 1
    max_replicas = 2

    volume {
      name         = "systemdata-volume"
      storage_name = azurerm_container_app_environment_storage.env_storage.name
      storage_type = "AzureFile"
    }

    container {
      name   = "gql-facilities"
      image  = "hrbolek/gql_facilities:0.8.5"
      cpu    = 0.25
      memory = "0.5Gi"

      volume_mounts {
        name     = "systemdata-volume"
        sub_path = "systemdata.json"
        path     = "/app/systemdata.json"
      }
      env {
        name  = "POSTGRES_HOST"
        value = "${azurerm_postgresql_flexible_server.postgres_gql.fqdn}:5432"
      }
      env {
        name  = "POSTGRES_USER"
        value = "postgres"
      }
      env {
        name        = "POSTGRES_PASSWORD"
        secret_name = "postgres-password"
      }
      env {
        name  = "POSTGRES_DB"
        value = "data"
      }
      env {
        name  = "GQLUG_ENDPOINT_URL"
        value = "http://gql-ug:8000/gql"
      }
      env {
        name  = "JWTPUBLICKEYURL"
        value = "http://frontend:8000/oauth/publickey"
      }
      env {
        name  = "JWTRESOLVEUSERPATHURL"
        value = "http://frontend:8000/oauth/userinfo"
      }
      env {
        name  = "DEMO"
        value = "False"
      }
      env {
        name  = "DEMODATA"
        value = "True"
      }
    }
  }

  secret {
    name  = "postgres-password"
    value = var.postgres_password
  }

  ingress {
    external_enabled = false
    target_port      = 8000

    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }
}

# 12. Container App for GQL Granting service
resource "azurerm_container_app" "gql_granting" {
  name                         = "gql-granting"
  container_app_environment_id = azurerm_container_app_environment.cae.id
  resource_group_name          = azurerm_resource_group.rg.name
  revision_mode                = "Single"

  template {
    min_replicas = 1
    max_replicas = 2

    volume {
      name         = "systemdata-volume"
      storage_name = azurerm_container_app_environment_storage.env_storage.name
      storage_type = "AzureFile"
    }

    container {
      name   = "gql-granting"
      image  = "hrbolek/gql_granting:0.8.6"
      cpu    = 0.25
      memory = "0.5Gi"

      volume_mounts {
        name     = "systemdata-volume"
        sub_path = "systemdata.json"
        path     = "/app/systemdata.json"
      }
      env {
        name  = "POSTGRES_HOST"
        value = "${azurerm_postgresql_flexible_server.postgres_gql.fqdn}:5432"
      }
      env {
        name  = "POSTGRES_USER"
        value = "postgres"
      }
      env {
        name        = "POSTGRES_PASSWORD"
        secret_name = "postgres-password"
      }
      env {
        name  = "POSTGRES_DB"
        value = "data"
      }
      env {
        name  = "GQLUG_ENDPOINT_URL"
        value = "http://gql-ug:8000/gql"
      }
      env {
        name  = "JWTPUBLICKEYURL"
        value = "http://frontend:8000/oauth/publickey"
      }
      env {
        name  = "JWTRESOLVEUSERPATHURL"
        value = "http://frontend:8000/oauth/userinfo"
      }
      env {
        name  = "DEMO"
        value = "False"
      }
      env {
        name  = "DEMODATA"
        value = "True"
      }
    }
  }

  secret {
    name  = "postgres-password"
    value = var.postgres_password
  }

  ingress {
    external_enabled = false
    target_port      = 8000

    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }
}

# 13. Container App for GQL Forms service
resource "azurerm_container_app" "gql_forms" {
  name                         = "gql-forms"
  container_app_environment_id = azurerm_container_app_environment.cae.id
  resource_group_name          = azurerm_resource_group.rg.name
  revision_mode                = "Single"

  template {
    min_replicas = 1
    max_replicas = 2

    volume {
      name         = "systemdata-volume"
      storage_name = azurerm_container_app_environment_storage.env_storage.name
      storage_type = "AzureFile"
    }

    container {
      name   = "gql-forms"
      image  = "hrbolek/gql_forms:0.8.5"
      cpu    = 0.25
      memory = "0.5Gi"

      volume_mounts {
        name     = "systemdata-volume"
        sub_path = "systemdata.json"
        path     = "/app/systemdata.json"
      }
      env {
        name  = "POSTGRES_HOST"
        value = "${azurerm_postgresql_flexible_server.postgres_gql.fqdn}:5432"
      }
      env {
        name  = "POSTGRES_USER"
        value = "postgres"
      }
      env {
        name        = "POSTGRES_PASSWORD"
        secret_name = "postgres-password"
      }
      env {
        name  = "POSTGRES_DB"
        value = "data"
      }
      env {
        name  = "GQLUG_ENDPOINT_URL"
        value = "http://gql-ug:8000/gql"
      }
      env {
        name  = "JWTPUBLICKEYURL"
        value = "http://frontend:8000/oauth/publickey"
      }
      env {
        name  = "JWTRESOLVEUSERPATHURL"
        value = "http://frontend:8000/oauth/userinfo"
      }
      env {
        name  = "DEMO"
        value = "False"
      }
      env {
        name  = "DEMODATA"
        value = "True"
      }
    }
  }

  secret {
    name  = "postgres-password"
    value = var.postgres_password
  }

  ingress {
    external_enabled = false
    target_port      = 8000

    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }
}

# 14. Container App for GQL Projects service
resource "azurerm_container_app" "gql_projects" {
  name                         = "gql-projects"
  container_app_environment_id = azurerm_container_app_environment.cae.id
  resource_group_name          = azurerm_resource_group.rg.name
  revision_mode                = "Single"

  template {
    min_replicas = 1
    max_replicas = 2

    volume {
      name         = "systemdata-volume"
      storage_name = azurerm_container_app_environment_storage.env_storage.name
      storage_type = "AzureFile"
    }

    container {
      name   = "gql-projects"
      image  = "hrbolek/gql_projects:0.8.7"
      cpu    = 0.25
      memory = "0.5Gi"

      volume_mounts {
        name     = "systemdata-volume"
        sub_path = "systemdata.json"
        path     = "/app/systemdata.json"
      }
      env {
        name  = "POSTGRES_HOST"
        value = "${azurerm_postgresql_flexible_server.postgres_gql.fqdn}:5432"
      }
      env {
        name  = "POSTGRES_USER"
        value = "postgres"
      }
      env {
        name        = "POSTGRES_PASSWORD"
        secret_name = "postgres-password"
      }
      env {
        name  = "POSTGRES_DB"
        value = "data"
      }
      env {
        name  = "GQLUG_ENDPOINT_URL"
        value = "http://gql-ug:8000/gql"
      }
      env {
        name  = "JWTPUBLICKEYURL"
        value = "http://frontend:8000/oauth/publickey"
      }
      env {
        name  = "JWTRESOLVEUSERPATHURL"
        value = "http://frontend:8000/oauth/userinfo"
      }
      env {
        name  = "DEMO"
        value = "False"
      }
      env {
        name  = "DEMODATA"
        value = "True"
      }
    }
  }

  secret {
    name  = "postgres-password"
    value = var.postgres_password
  }

  ingress {
    external_enabled = false
    target_port      = 8000

    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }
}

# 15. Container App for GQL Publications service
resource "azurerm_container_app" "gql_publications" {
  name                         = "gql-publications"
  container_app_environment_id = azurerm_container_app_environment.cae.id
  resource_group_name          = azurerm_resource_group.rg.name
  revision_mode                = "Single"

  template {
    min_replicas = 1
    max_replicas = 2

    volume {
      name         = "systemdata-volume"
      storage_name = azurerm_container_app_environment_storage.env_storage.name
      storage_type = "AzureFile"
    }

    container {
      name   = "gql-publications"
      image  = "hrbolek/gql_publications:0.8.6"
      cpu    = 0.25
      memory = "0.5Gi"

      volume_mounts {
        name     = "systemdata-volume"
        sub_path = "systemdata.json"
        path     = "/app/systemdata.json"
      }
      env {
        name  = "POSTGRES_HOST"
        value = "${azurerm_postgresql_flexible_server.postgres_gql.fqdn}:5432"
      }
      env {
        name  = "POSTGRES_USER"
        value = "postgres"
      }
      env {
        name        = "POSTGRES_PASSWORD"
        secret_name = "postgres-password"
      }
      env {
        name  = "POSTGRES_DB"
        value = "data"
      }
      env {
        name  = "GQLUG_ENDPOINT_URL"
        value = "http://gql-ug:8000/gql"
      }
      env {
        name  = "JWTPUBLICKEYURL"
        value = "http://frontend:8000/oauth/publickey"
      }
      env {
        name  = "JWTRESOLVEUSERPATHURL"
        value = "http://frontend:8000/oauth/userinfo"
      }
      env {
        name  = "DEMO"
        value = "False"
      }
      env {
        name  = "DEMODATA"
        value = "True"
      }
    }
  }

  secret {
    name  = "postgres-password"
    value = var.postgres_password
  }

  ingress {
    external_enabled = false
    target_port      = 8000

    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }
}

# 16. Container App for GQL Lessons service
resource "azurerm_container_app" "gql_lessons" {
  name                         = "gql-lessons"
  container_app_environment_id = azurerm_container_app_environment.cae.id
  resource_group_name          = azurerm_resource_group.rg.name
  revision_mode                = "Single"

  template {
    min_replicas = 1
    max_replicas = 2

    volume {
      name         = "systemdata-volume"
      storage_name = azurerm_container_app_environment_storage.env_storage.name
      storage_type = "AzureFile"
    }

    container {
      name   = "gql-lessons"
      image  = "hrbolek/gql_lessons:0.8.7"
      cpu    = 0.25
      memory = "0.5Gi"

      volume_mounts {
        name     = "systemdata-volume"
        sub_path = "systemdata.json"
        path     = "/app/systemdata.json"
      }
      env {
        name  = "POSTGRES_HOST"
        value = "${azurerm_postgresql_flexible_server.postgres_gql.fqdn}:5432"
      }
      env {
        name  = "POSTGRES_USER"
        value = "postgres"
      }
      env {
        name        = "POSTGRES_PASSWORD"
        secret_name = "postgres-password"
      }
      env {
        name  = "POSTGRES_DB"
        value = "data"
      }
      env {
        name  = "GQLUG_ENDPOINT_URL"
        value = "http://gql-ug:8000/gql"
      }
      env {
        name  = "JWTPUBLICKEYURL"
        value = "http://frontend:8000/oauth/publickey"
      }
      env {
        name  = "JWTRESOLVEUSERPATHURL"
        value = "http://frontend:8000/oauth/userinfo"
      }
      env {
        name  = "DEMO"
        value = "False"
      }
      env {
        name  = "DEMODATA"
        value = "True"
      }
    }
  }

  secret {
    name  = "postgres-password"
    value = var.postgres_password
  }

  ingress {
    external_enabled = false
    target_port      = 8000

    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }
}

# 17. Container App for GQL Surveys service
resource "azurerm_container_app" "gql_surveys" {
  name                         = "gql-surveys"
  container_app_environment_id = azurerm_container_app_environment.cae.id
  resource_group_name          = azurerm_resource_group.rg.name
  revision_mode                = "Single"

  template {
    min_replicas = 1
    max_replicas = 2

    volume {
      name         = "systemdata-volume"
      storage_name = azurerm_container_app_environment_storage.env_storage.name
      storage_type = "AzureFile"
    }

    container {
      name   = "gql-surveys"
      image  = "hrbolek/gql_surveys:0.8.6"
      cpu    = 0.25
      memory = "0.5Gi"

      volume_mounts {
        name     = "systemdata-volume"
        sub_path = "systemdata.json"
        path     = "/app/systemdata.json"
      }
      env {
        name  = "POSTGRES_HOST"
        value = "${azurerm_postgresql_flexible_server.postgres_gql.fqdn}:5432"
      }
      env {
        name  = "POSTGRES_USER"
        value = "postgres"
      }
      env {
        name        = "POSTGRES_PASSWORD"
        secret_name = "postgres-password"
      }
      env {
        name  = "POSTGRES_DB"
        value = "data"
      }
      env {
        name  = "GQLUG_ENDPOINT_URL"
        value = "http://gql-ug:8000/gql"
      }
      env {
        name  = "JWTPUBLICKEYURL"
        value = "http://frontend:8000/oauth/publickey"
      }
      env {
        name  = "JWTRESOLVEUSERPATHURL"
        value = "http://frontend:8000/oauth/userinfo"
      }
      env {
        name  = "DEMO"
        value = "False"
      }
      env {
        name  = "DEMODATA"
        value = "True"
      }
    }
  }

  secret {
    name  = "postgres-password"
    value = var.postgres_password
  }

  ingress {
    external_enabled = false
    target_port      = 8000

    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }
}

# 17. Container App for GQL Surveys service
resource "azurerm_container_app" "gql_admissions" {
  name                         = "gql-admissions"
  container_app_environment_id = azurerm_container_app_environment.cae.id
  resource_group_name          = azurerm_resource_group.rg.name
  revision_mode                = "Single"

  template {
    min_replicas = 1
    max_replicas = 2

    volume {
      name         = "systemdata-volume"
      storage_name = azurerm_container_app_environment_storage.env_storage.name
      storage_type = "AzureFile"
    }

    container {
      name   = "gql-admissions"
      image  = "hrbolek/gql_admissions:0.9.0"
      cpu    = 0.25
      memory = "0.5Gi"

      volume_mounts {
        name     = "systemdata-volume"
        sub_path = "systemdata.json"
        path     = "/app/systemdata.json"
      }
      env {
        name  = "POSTGRES_HOST"
        value = "${azurerm_postgresql_flexible_server.postgres_gql.fqdn}:5432"
      }
      env {
        name  = "POSTGRES_USER"
        value = "postgres"
      }
      env {
        name        = "POSTGRES_PASSWORD"
        secret_name = "postgres-password"
      }
      env {
        name  = "POSTGRES_DB"
        value = "data"
      }
      env {
        name  = "GQLUG_ENDPOINT_URL"
        value = "http://gql-ug:8000/gql"
      }
      env {
        name  = "JWTPUBLICKEYURL"
        value = "http://frontend:8000/oauth/publickey"
      }
      env {
        name  = "JWTRESOLVEUSERPATHURL"
        value = "http://frontend:8000/oauth/userinfo"
      }
      env {
        name  = "DEMO"
        value = "False"
      }
      env {
        name  = "DEMODATA"
        value = "True"
      }
    }
  }

  secret {
    name  = "postgres-password"
    value = var.postgres_password
  }

  ingress {
    external_enabled = false
    target_port      = 8000

    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }
}

# 18. Container App for Apollo Federation Gateway
resource "azurerm_container_app" "apollo" {
  name                         = "apollo"
  container_app_environment_id = azurerm_container_app_environment.cae.id
  resource_group_name          = azurerm_resource_group.rg.name
  revision_mode                = "Single"

  template {
    min_replicas = 1
    max_replicas = 3

    container {
      name   = "apollo"
      image  = "hrbolek/apollo_federation"
      cpu    = 0.5
      memory = "1Gi"

      env {
        name  = "PORT"
        value = "3000"
      }
      env {
        name = "SERVICES"
        value = jsonencode([
          { name = "ug", url = "http://${azurerm_container_app.gql_ug.latest_revision_fqdn}/gql" },
          # { name = "forms", url = "http://gql-forms:8000/gql" },
          # { name = "granting", url = "http://gql-granting:8000/gql" },
          # { name = "facilities", url = "http://gql-facilities:8000/gql" },
          # { name = "events", url = "http://gql-events:8000/gql" },
          # { name = "publications", url = "http://gql-publications:8000/gql" },
          # { name = "projects", url = "http://gql-projects:8000/gql" },
          # { name = "lessons", url = "http://gql-lessons:8000/gql" },
          # { name = "surveys", url = "http://gql-surveys:8000/gql" },
          # { name = "externalids", url = "http://gql-externalids:8000/gql" }
        ])
      }
    }
  }

  ingress {
    external_enabled = false
    target_port      = 3000

    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }

  depends_on = [
    azurerm_container_app.gql_ug,
    azurerm_container_app.gql_forms,
    azurerm_container_app.gql_granting,
    azurerm_container_app.gql_facilities,
    azurerm_container_app.gql_events,
    azurerm_container_app.gql_publications,
    azurerm_container_app.gql_projects,
    azurerm_container_app.gql_lessons,
    azurerm_container_app.gql_surveys,
    azurerm_container_app.gql_externalids
  ]
}

# 19. Container App for Frontend
resource "azurerm_container_app" "frontend" {
  name                         = "frontend"
  container_app_environment_id = azurerm_container_app_environment.cae.id
  resource_group_name          = azurerm_resource_group.rg.name
  revision_mode                = "Single"

  template {
    min_replicas = 1
    max_replicas = 2

    volume {
      name         = "systemdata-volume"
      storage_name = azurerm_container_app_environment_storage.env_storage.name
      storage_type = "AzureFile"
    }

    container {
      name   = "frontend"
      image  = "hrbolek/frontend:0.9.0"
      cpu    = 0.5
      memory = "1Gi"

      volume_mounts {
        name     = "systemdata-volume"
        sub_path = "systemdata.json"
        path     = "/app/systemdata.json"
      }
      env {
        name  = "DEMO"
        value = "True"
      }
      env {
        name  = "DEMODATA"
        value = "True"
      }
      env {
        name  = "POSTGRES_HOST"
        value = "${azurerm_postgresql_flexible_server.postgres_credentials.fqdn}:5432"
      }
      env {
        name  = "POSTGRES_USER"
        value = "postgres"
      }
      env {
        name        = "POSTGRES_PASSWORD"
        secret_name = "postgres-password-cred"
      }
      env {
        name  = "POSTGRES_DB"
        value = "data"
      }
      env {
        name  = "GQL_PROXY"
        value = "http://apollo:3000/api/gql/"
      }
      env {
        name  = "SALT"
        value = "fe1c71b2-74c0-41e5-978f-eecbffac7418"
      }
      env {
        name  = "ADMIN_DEFAULT_EMAIL"
        value = "john.newbie@world.com"
      }
      env {
        name  = "ADMIN_DEFAULT_PASSWORD"
        value = "john.newbie@world.com"
      }
    }
  }

  secret {
    name  = "postgres-password-cred"
    value = var.postgres_password
  }

  ingress {
    external_enabled = true
    target_port      = 8000

    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }

  depends_on = [
    azurerm_postgresql_flexible_server_database.credentials_db,
    azurerm_container_app.apollo
  ]
}

# 20. Container App for Analytics
resource "azurerm_container_app" "gql_analytics" {
  name                         = "gql-analytics"
  container_app_environment_id = azurerm_container_app_environment.cae.id
  resource_group_name          = azurerm_resource_group.rg.name
  revision_mode                = "Single"

  template {
    min_replicas = 1
    max_replicas = 1

    volume {
      name         = "systemdata-volume"
      storage_name = azurerm_container_app_environment_storage.env_storage.name
      storage_type = "AzureFile"
    }

    container {
      name   = "gql-analytics"
      image  = "hrbolek/analytics:0.9.0"
      cpu    = 0.25
      memory = "0.5Gi"

      volume_mounts {
        name     = "systemdata-volume"
        sub_path = "systemdata.json"
        path     = "/app/systemdata.json"
      }

      env {
        name  = "GQL_PROXY"
        value = "http://apollo:3000/api/gql/"
      }
    }
  }

  ingress {
    external_enabled = false
    target_port      = 8000

    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }

  depends_on = [
    azurerm_container_app.apollo
  ]
}

# Output the frontend URL
output "frontend_url" {
  value = "https://${azurerm_container_app.frontend.latest_revision_fqdn}"
}

output "postgres_gql_fqdn" {
  value = azurerm_postgresql_flexible_server.postgres_gql.fqdn
}

output "postgres_credentials_fqdn" {
  value = azurerm_postgresql_flexible_server.postgres_credentials.fqdn
}


variable "storage_account_name" {
  description = "A globally unique name for the storage account."
  type        = string
  # Storage account names must be 3-24 characters, lowercase letters and numbers only.
  default = "sthk2025appstorage"
}

# Creates the storage account
resource "azurerm_storage_account" "storage" {
  name                     = var.storage_account_name
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

# Creates the file share within the storage account
resource "azurerm_storage_share" "fileshare" {
  name               = "systemdata-share"
  storage_account_id = azurerm_storage_account.storage.id
  quota              = 1 # Minimum size in GB
}

resource "azurerm_storage_share_file" "systemdata_file" {
  name             = "systemdata.json"
  storage_share_id = azurerm_storage_share.fileshare.url
  source           = "./systemdata.json"
}

resource "azurerm_container_app_environment_storage" "env_storage" {
  name                         = "systemdata-storage" # A friendly name for the mount
  container_app_environment_id = azurerm_container_app_environment.cae.id
  account_name                 = azurerm_storage_account.storage.name
  access_key                   = azurerm_storage_account.storage.primary_access_key
  share_name                   = azurerm_storage_share.fileshare.name
  access_mode                  = "ReadOnly" # Use "ReadOnly" as it's a config file
}
