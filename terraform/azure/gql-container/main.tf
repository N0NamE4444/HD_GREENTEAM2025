resource "azurerm_container_app" "gql" {
  name                          = var.name
  container_apps_environment_id = var.environment_id
  resource_group_name           = var.resource_group_name

  # -------------------------------
  # Networking Configuration
  # -------------------------------
  configuration {
    ingress {
      external_enabled = false   # gql services are internal; they do not expose public endpoints
      target_port      = var.target_port # The port where the GraphQL service listens (e.g., 8000)
    }
  }

  template {
    container {
      name  = var.name
      image = var.image # The container image for the GraphQL service

      # -------------------------------
      # Resource Allocation
      # -------------------------------
      resources {
        cpu    = var.cpu    # Number of CPU cores allocated
        memory = var.memory # Amount of memory allocated (e.g., "1.5Gi")
      }

      # -------------------------------
      # Database Connectivity
      # -------------------------------
      env {
        name  = "POSTGRES_HOST"
        value = var.postgres_host
      }
      env {
        name  = "POSTGRES_USER"
        value = var.postgres_user
      }
      env {
        name  = "POSTGRES_PASSWORD"
        value = var.postgres_password
      }
      env {
        name  = "POSTGRES_DB"
        value = var.postgres_db
      }

      # -------------------------------
      # Application Environment Variables
      # -------------------------------
      env {
        name  = "DEMO"
        value = "False"
      }
      env {
        name  = "DEMODATA"
        value = "True"
      }

      # -------------------------------
      # Special Configuration for gql_ug Container
      # -------------------------------
      # If this is the gql_ug service, set its own JWT-related environment variables.
      dynamic "env" {
        for_each = var.is_ug ? [1] : []
        content {
          name  = "JWTPUBLICKEYURL"
          value = "http://${var.frontend_fqdn}/oauth/publickey"
        }
      }
      dynamic "env" {
        for_each = var.is_ug ? [1] : []
        content {
          name  = "JWTRESOLVEUSERPATHURL"
          value = "http://${var.frontend_fqdn}/oauth/userinfo"
        }
      }

      # -------------------------------
      # All Other gql Containers
      # -------------------------------
      # If this is not the gql_ug service, set the gql_ug endpoint so other gql services can connect to it.
      dynamic "env" {
        for_each = var.is_ug ? [] : [1]
        content {
          name  = "GQLUG_ENDPOINT_URL"
          value = "http://gql-ug.${var.environment_name}.${var.resource_group_location}.azurecontainerapps.io/gql"
        }
      }
    }

    # -------------------------------
    # Autoscaling Configuration
    # -------------------------------
    scale {
      min_replicas = var.min_replicas # Minimum number of container instances (default: 2)
      max_replicas = var.max_replicas # Maximum number of container instances (default: 10)

      # Autoscale based on HTTP request rate (if requests exceed 50 per container)
      rule {
        name     = "http-scaling"
        type     = "http"
        metadata = {
          concurrentRequests = "50" # Triggers scaling when requests exceed 50 per instance
        }
      }

      # Autoscale based on CPU usage (if CPU exceeds 75%)
      rule {
        name     = "cpu-scaling"
        type     = "cpu"
        metadata = {
          "cpu" = "75" # Scale when CPU usage goes above 75%
        }
      }

      # Autoscale based on memory usage (if memory exceeds 512MiB per instance)
      rule {
        name     = "memory-scaling"
        type     = "memory"
        metadata = {
          "memory" = "512Mi" # Scale when memory exceeds 512MiB per instance
        }
      }
    }
  }
}
