variable "name" {
  description = "The name of the frontend container app"
  type        = string
}

variable "image" {
  description = "The container image for the frontend service"
  type        = string
}

variable "environment_id" {
  description = "The ID of the Container Apps Environment"
  type        = string
}

variable "resource_group_name" {
  description = "The resource group name"
  type        = string
}

variable "target_port" {
  description = "The port on which the container listens (and the external ingress is mapped)"
  type        = number
  default     = 8000
}

variable "cpu" {
  description = "The number of CPU cores to allocate"
  type        = number
  default     = 1.0
}

variable "memory" {
  description = "The amount of memory to allocate (for example, '1.5Gi')"
  type        = string
  default     = "1.5Gi"
}

# Managed PostgreSQL connection details (instead of deploying PostgreSQL as a container)
variable "postgres_host" {
  description = "Hostname and port for the managed PostgreSQL database (e.g. 'mydbserver.postgres.database.azure.com:5432')"
  type        = string
}

variable "postgres_user" {
  description = "PostgreSQL username"
  type        = string
}

variable "postgres_password" {
  description = "PostgreSQL password"
  type        = string
}

variable "postgres_db" {
  description = "PostgreSQL database name"
  type        = string
}

# Other environment variables
variable "gql_proxy" {
  description = "URL for the Apollo service (for example, 'http://apollo.<env>.<region>.azurecontainerapps.io/api/gql/')"
  type        = string
}

variable "salt" {
  description = "The salt used by the frontend service"
  type        = string
}

variable "admin_default_email" {
  description = "The default administrator email"
  type        = string
}

variable "admin_default_password" {
  description = "The default administrator password"
  type        = string
}

# Optional: Additional environment variables can be passed as a map.
variable "extra_env" {
  description = "A map of additional environment variables for the frontend container"
  type        = map(string)
  default     = {}
}
