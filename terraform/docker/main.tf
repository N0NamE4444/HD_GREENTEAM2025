terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      # version = "~> 2.22.0" # Use the latest compatible version
    }
  }
}

provider "docker" {
  host = "npipe:////./pipe/docker_engine" # For Windows
}

variable "postgres_user" {
  description = "Postgres username"
  type        = string
}

variable "postgres_password" {
  description = "Postgres password"
  type        = string
}

variable "postgres_db" {
  description = "Postgres database name"
  type        = string
}

variable "pgadmin_email" {
  description = "pgAdmin default email"
  type        = string
}

variable "pgadmin_password" {
  description = "pgAdmin default password"
  type        = string
}

# Create a custom network
resource "docker_network" "custom_network" {
  name = "custom_network"
}

resource "docker_image" "postgres" {
  name = "postgres:latest"
}

resource "docker_container" "postgres" {
  name  = "postgres_container"
  image = docker_image.postgres.name
  ports {
    internal = 5432
    external = 5555
  }
  env = [
    "POSTGRES_USER=${var.postgres_user}",
    "POSTGRES_PASSWORD=${var.postgres_password}",
    "POSTGRES_DB=${var.postgres_db}"
  ]
  labels {
    label = "com.docker.compose.project"
    value = "project_name"
  }  
  volumes {
    # host_path      = "${path.module}/data/postgres"
    container_path = "/var/lib/postgresql/data"
  }
  networks_advanced {
    name = docker_network.custom_network.name
  }  
}

resource "docker_image" "pgadmin" {
  name = "dpage/pgadmin4:latest"
}

resource "docker_container" "pgadmin" {
  name  = "pgadmin_container"
  image = docker_image.pgadmin.name
  ports {
    internal = 80
    external = 9999
  }
  env = [
    "PGADMIN_DEFAULT_EMAIL=${var.pgadmin_email}",
    "PGADMIN_DEFAULT_PASSWORD=${var.pgadmin_password}"
  ]
  labels {
    label = "com.docker.compose.project"
    value = "project_name"
  }  
  networks_advanced {
    name = docker_network.custom_network.name
  }
}

output "connection_info" {
  value = {
    postgres = {
      host     = "localhost"
      port     = 5555
      user     = var.postgres_user
      password = var.postgres_password
      database = var.postgres_db
    }
    pgadmin = {
      url      = "http://localhost:8080"
      email    = var.pgadmin_email
      password = var.pgadmin_password
    }
  }
}
