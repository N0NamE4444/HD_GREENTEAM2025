terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
  required_version = ">= 1.0.0"
}

provider "azurerm" {
  features {}
}

#############################
# Resource Group & Logging
#############################

resource "azurerm_resource_group" "rg" {
  name     = "uois-rg"
  location = "westeurope"
}

# Create an Azure Log Analytics Workspace.
# This workspace is used to collect and analyze monitoring data,
# logs, and metrics from various Azure resources (such as Container Apps).
resource "azurerm_log_analytics_workspace" "law" {
  # The name assigned to the Log Analytics Workspace.
  name = "example-law"
  
  # The location where the workspace is deployed.
  # This is set to use the same region as the resource group.
  location = azurerm_resource_group.rg.location
  
  # The name of the resource group in which the workspace will be created.
  resource_group_name = azurerm_resource_group.rg.name
  
  # The pricing tier for the workspace.
  # "PerGB2018" indicates a pay-as-you-go model, charging per GB of data ingested.
  sku = "PerGB2018"
  # the cost is roughly around $2.30 per GB of data ingested per month
  
  # The number of days that the collected log data will be retained.
  # In this case, data is retained for 30 days.
  retention_in_days = 30
}

########################################
# Container Apps Environment
########################################

resource "azurerm_container_apps_environment" "env" {
  name                = "uois-env"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  log_analytics {
    workspace_id = azurerm_log_analytics_workspace.law.id
  }
}
########################################
# PostgreSQL Module: Frontend Database
########################################
module "postgres_frontend" {
  source              = "./postgres"                                      # Path to your PostgreSQL module
  server_name         = "frontendpostgres"                                # Must be globally unique
  location            = azurerm_resource_group.rg.location              # Use the same location as the resource group
  resource_group_name = azurerm_resource_group.rg.name                  # The resource group where this server is deployed
  administrator_login = var.postgres_admin_user                         # Administrator username for PostgreSQL
  administrator_login_password = var.postgres_admin_password          # Administrator password (sensitive)
  
  # sku_name Explanation:
  # "B_Gen5_1" configures the PostgreSQL server to use the Basic (B) tier,
  # running on Generation 5 hardware with 1 virtual core (vCore).
  #
  # - Basic Tier (B): Designed for development, testing, or low-traffic production workloads.
  #   It provides lower performance compared to General Purpose or Memory Optimized tiers.
  #
  # - Gen5: Indicates the use of Generation 5 hardware which offers a balance of performance and cost.
  #
  # - 1 (vCore): Allocates one virtual core. This is the minimum configuration for Basic tier.
  #
  # Estimated Cost:
  # - Approximate hourly rate: ~\$0.022 per hour.
  # - Monthly compute cost (730 hours/month): ~\$16/month (730 x \$0.022).
  # - Additional costs include storage (here, 5120 MB or 5 GB) and backup retention (7 days).
  #
  # Note:
  # For a workload with roughly 2000 university users, a B_Gen5_1 instance may suffice if the database load is light.
  # However, if query volume or concurrent connections increase significantly, consider a higher performance tier.
  sku_name = "B_Gen5_1"
  
  # Estimated Cost:
  # - The hourly rate for a GP_Gen5_2 instance is roughly estimated at ~$0.10 per hour (this rate can vary by region).
  # - Monthly compute cost (730 hours/month) would be approximately: 730 x $0.10 ≈ $73/month.
  # - Additional costs include storage (5 GB in this case) and backup retention.
  #
  # sku_name = "GP_Gen5_2"

  # Note on Autoscaling:
  # Currently, Azure Database for PostgreSQL does not support built-in compute autoscaling.
  # The 'auto_grow_enabled' setting only applies to storage capacity.
  # If you need to scale compute resources (vCores), you must update the SKU manually
  # or implement custom automation to adjust the compute tier based on performance metrics.
  # For example, while the "GP_Gen5_2" SKU is used here for better performance,
  # if you expect variable workload patterns, consider using Azure Monitor to trigger SKU changes via automation.

  storage_mb          = 5120                                            # Allocated storage in MB (5 GB)
  version             = "11"                                            # PostgreSQL version
  backup_retention_days = 7                                             # Number of days to retain backups
  geo_redundant_backup_enabled = false                                # Disable geo-redundant backups
  auto_grow_enabled   = true                                            # Allow storage auto-growth if needed
  public_network_access_enabled = true                                # Public network access is enabled
  ssl_enforcement_enabled = true                                       # Enforce SSL connections
  tags                = { environment = "frontend" }                    # Tag to identify this server's purpose
  
  database_name       = var.frontend_db_name                            # Name of the database for the frontend service
  charset             = "UTF8"                                          # Database charset
  collation           = "English_United States.1252"                    # Database collation

  # Firewall configuration:
  # The following settings allow connections from any IP address (0.0.0.0 to 255.255.255.255).
  # Although this is not best practice for production, this instance is intended to be used
  # exclusively by the frontend container service, and its connection string is provided only to that service.
  firewall_rule_name  = "AllowAll"
  start_ip_address    = "0.0.0.0"
  end_ip_address      = "255.255.255.255"
}


########################################
# PostgreSQL Module: gql Database
########################################

module "postgres_gql" {
  source              = "./azure-postgres"
  server_name         = "gqlpostgres"            # Must be globally unique
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  administrator_login = var.postgres_admin_user
  administrator_login_password = var.postgres_admin_password
  sku_name            = "B_Gen5_1"
  storage_mb          = 5120
  version             = "11"
  backup_retention_days = 7
  geo_redundant_backup_enabled = false
  auto_grow_enabled   = true
  public_network_access_enabled = true
  ssl_enforcement_enabled = true
  tags                = { environment = "gql" }
  database_name       = var.gql_db_name
  charset             = "UTF8"
  collation           = "English_United States.1252"
  firewall_rule_name  = "AllowAll"
  start_ip_address    = "0.0.0.0"
  end_ip_address      = "255.255.255.255"
}

########################################
# Frontend Container App (External)
########################################

# Module call for deploying the Frontend Container App
module "frontend" {
  source = "./frontend" 
  # The "source" parameter points to the local frontend module directory,
  # which encapsulates the configuration for deploying the frontend container app.

  # -------------------------------
  # Basic Identification & Image
  # -------------------------------
  name  = "frontend"
  # The name of the container app. This identifier is used within the Container Apps Environment.
  
  image = "hrbolek/frontend"
  # The container image for the frontend service that will be deployed.

  # -------------------------------
  # Environment & Networking Settings
  # -------------------------------
  environment_id      = azurerm_container_apps_environment.env.id
  # The ID of the Container Apps Environment where this container app will be deployed.
  
  resource_group_name = azurerm_resource_group.rg.name
  # The resource group in which the Container Apps Environment and associated resources reside.
  
  target_port         = 8000
  # The port on which the frontend container listens. This port is exposed externally via ingress.

  # -------------------------------
  # Resource Allocation
  # -------------------------------
  cpu    = 1.0
  # The number of CPU cores allocated for the container app.
  
  memory = "1.5Gi"
  # The amount of memory allocated for the container app (in GiB).

  # -------------------------------
  # PostgreSQL Database Connectivity
  # -------------------------------
  # The frontend service uses a dedicated PostgreSQL server whose FQDN is obtained from the postgres_frontend module.
  postgres_host     = module.postgres_frontend.postgres_fqdn
  # The fully qualified domain name of the PostgreSQL server deployed via the postgres_frontend module.
  
  postgres_user     = var.postgres_admin_user
  # The PostgreSQL administrator username (supplied via a variable).
  
  postgres_password = var.postgres_admin_password
  # The PostgreSQL administrator password (supplied via a variable). Marked as sensitive.
  
  postgres_db       = var.frontend_db_name
  # The name of the database that the frontend service will use.

  # -------------------------------
  # Application-Specific Configuration
  # -------------------------------
  gql_proxy = "http://apollo.${azurerm_container_apps_environment.env.name}.${azurerm_resource_group.rg.location}.azurecontainerapps.io/api/gql/"
  # The GQL_PROXY environment variable provides the URL endpoint for the Apollo service.
  # This endpoint is constructed dynamically using the Container Apps Environment name and resource group location,
  # ensuring the frontend service can communicate with the internal Apollo service.

  salt = "fe1c71b2-74c0-41e5-978f-eecbffac7418"
  # A predefined salt value used by the frontend application for cryptographic purposes or hashing.

  admin_default_email    = "john.newbie@world.com"
  # The default administrator email for the frontend service, used for initial setup or testing.

  admin_default_password = "john.newbie@world.com"
  # The default administrator password for the frontend service.

  # -------------------------------
  # Additional Environment Variables
  # -------------------------------
  extra_env = {}
  # This map can be used to pass any additional environment variables required by the frontend container.
  # Currently left empty.
}

#############################
# Apollo Container App (Internal)
#############################

resource "azurerm_container_app" "apollo" {
  name                          = "apollo"
  container_apps_environment_id = azurerm_container_apps_environment.env.id
  resource_group_name           = azurerm_resource_group.rg.name

  configuration {
    ingress {
      external_enabled = false
      target_port      = 3000
    }
  }

  template {
    container {
      name  = "apollo"
      image = "hrbolek/apollo_federation"
      resources {
        cpu    = 1.0
        memory = "1.5Gi"
      }
      env {
        name  = "PORT"
        value = "3000"
      }
      # The SERVICES variable tells Apollo how to reach each gql service.
      env {
        name  = "SERVICES"
        value = jsonencode([
          { "name": "ug",           "url": "http://gql-ug.${azurerm_container_apps_environment.env.name}.${azurerm_resource_group.rg.location}.azurecontainerapps.io/gql" },
          { "name": "forms",        "url": "http://gql-forms.${azurerm_container_apps_environment.env.name}.${azurerm_resource_group.rg.location}.azurecontainerapps.io/gql" },
          { "name": "granting",     "url": "http://gql-granting.${azurerm_container_apps_environment.env.name}.${azurerm_resource_group.rg.location}.azurecontainerapps.io/gql" },
          { "name": "facilities",   "url": "http://gql-facilities.${azurerm_container_apps_environment.env.name}.${azurerm_resource_group.rg.location}.azurecontainerapps.io/gql" },
          { "name": "events",       "url": "http://gql-events.${azurerm_container_apps_environment.env.name}.${azurerm_resource_group.rg.location}.azurecontainerapps.io/gql" },
          { "name": "publications", "url": "http://gql-publications.${azurerm_container_apps_environment.env.name}.${azurerm_resource_group.rg.location}.azurecontainerapps.io/gql" },
          { "name": "projects",     "url": "http://gql-projects.${azurerm_container_apps_environment.env.name}.${azurerm_resource_group.rg.location}.azurecontainerapps.io/gql" },
          { "name": "lessons",      "url": "http://gql-lessons.${azurerm_container_apps_environment.env.name}.${azurerm_resource_group.rg.location}.azurecontainerapps.io/gql" },
          { "name": "surveys",      "url": "http://gql-surveys.${azurerm_container_apps_environment.env.name}.${azurerm_resource_group.rg.location}.azurecontainerapps.io/gql" },
          { "name": "externalids",  "url": "http://gql-externalids.${azurerm_container_apps_environment.env.name}.${azurerm_resource_group.rg.location}.azurecontainerapps.io/gql" }
        ])
      }
    }
  }
}

#############################
# Module Calls for gql Container Apps
#############################
  
module "gql_ug" {
  source              = "./gql-container"
  name                = "gql-ug"
  image               = "hrbolek/gql_ug"
  environment_id      = azurerm_container_apps_environment.env.id
  resource_group_name = azurerm_resource_group.rg.name
  is_ug               = true
  postgres_host       = var.postgres_host
  postgres_user       = var.postgres_user
  postgres_password   = var.postgres_password
  postgres_db         = var.postgres_db
  frontend_fqdn       = azurerm_container_app.frontend.default_hostname
}

module "gql_externalids" {
  source              = "./gql-container"
  name                = "gql-externalids"
  image               = "hrbolek/gql_externalids"
  environment_id      = azurerm_container_apps_environment.env.id
  resource_group_name = azurerm_resource_group.rg.name
  is_ug               = false
  postgres_host       = var.postgres_host
  postgres_user       = var.postgres_user
  postgres_password   = var.postgres_password
  postgres_db         = var.postgres_db
  frontend_fqdn       = azurerm_container_app.frontend.default_hostname
}

module "gql_events" {
  source              = "./modules/gql-container"
  name                = "gql-events"
  image               = "hrbolek/gql_events"
  environment_id      = azurerm_container_apps_environment.env.id
  environment_name    = azurerm_container_apps_environment.env.name
  resource_group_name = azurerm_resource_group.rg.name
  resource_group_location = azurerm_resource_group.rg.location
  is_ug               = false
}
# (Repeat similar module calls for gql-events, gql-facilities, gql-granting, 
#  gql-forms, gql-projects, gql-publications, gql-lessons, and gql-surveys as needed.)

#############################
# Analytics Container App (Internal)
#############################

resource "azurerm_container_app" "analytics" {
  name                          = "analytics"
  container_apps_environment_id = azurerm_container_apps_environment.env.id
  resource_group_name           = azurerm_resource_group.rg.name

  configuration {
    ingress {
      external_enabled = false
      target_port      = 8000
    }
  }

  template {
    container {
      name  = "analytics"
      image = "hrbolek/analytics"
      resources {
        cpu    = 1.0
        memory = "1.5Gi"
      }
      env {
        name  = "GQL_PROXY"
        value = "http://apollo.${azurerm_container_apps_environment.env.name}.${azurerm_resource_group.rg.location}.azurecontainerapps.io/api/gql/"
      }
    }
  }
}
