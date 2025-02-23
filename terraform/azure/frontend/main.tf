resource "azurerm_container_app" "frontend" {
  name                          = var.name
  container_apps_environment_id = var.environment_id
  resource_group_name           = var.resource_group_name

  # -------------------------------
  # Networking Configuration
  # -------------------------------
  configuration {
    ingress {
      external_enabled = true    # Enables external access to the frontend
      target_port      = var.target_port # The port where the frontend listens (e.g., 8000)
      transport        = "auto"  # Automatically selects between HTTP/HTTPS
    }
  }

  template {
    container {
      name  = var.name
      image = var.image # The container image for the frontend service

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
        value = "False"
      }
      env {
        name  = "GQL_PROXY"
        value = var.gql_proxy
      }
      env {
        name  = "SALT"
        value = var.salt
      }
      env {
        name  = "ADMIN_DEFAULT_EMAIL"
        value = var.admin_default_email
      }
      env {
        name  = "ADMIN_DEFAULT_PASSWORD"
        value = var.admin_default_password
      }

      # Dynamically add any extra environment variables.
      dynamic "env" {
        for_each = var.extra_env
        content {
          name  = env.key
          value = env.value
        }
      }
    }

    # -------------------------------
    # Autoscaling Configuration
    # -------------------------------
    scale {
      min_replicas = var.min_replicas # Minimum number of container instances (default: 2)
      max_replicas = var.max_replicas # Maximum number of container instances (default: 10)

      # Autoscale based on HTTP request rate (if requests exceed 100 per container)
      rule {
        name     = "http-scaling"
        type     = "http"
        metadata = {
          concurrentRequests = "100" # Triggers scaling when requests exceed 100 per instance
        }
      }

      # Autoscale based on CPU usage (if CPU exceeds 70%)
      rule {
        name     = "cpu-scaling"
        type     = "cpu"
        metadata = {
          "cpu" = "70" # Scale when CPU usage goes above 70%
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
