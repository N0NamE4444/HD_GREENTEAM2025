variable "name" {
  description = "The name for the gql container app (e.g. 'gql-ug' or 'gql-externalids')."
  type        = string
}

variable "image" {
  description = "Container image for the gql service."
  type        = string
}

variable "environment_id" {
  description = "The ID of the Container Apps Environment."
  type        = string
}

variable "environment_name" {
  description = "The name of the Azure Container Apps Environment"
  type        = string
}

variable "resource_group_location" {
  description = "The location of the resource group"
  type        = string
}

variable "target_port" {
  description = "The container port to listen on."
  type        = number
  default     = 8000
}

variable "cpu" {
  description = "Number of CPU cores to allocate."
  type        = number
  default     = 1.0
}

variable "memory" {
  description = "Memory to allocate (e.g. '1.5Gi')."
  type        = string
  default     = "1.5Gi"
}

variable "is_ug" {
  description = "Flag indicating if this container is the gql_ug service. If true, adds extra env variables."
  type        = bool
  default     = false
}

# Managed PostgreSQL connection settings.
variable "postgres_host" {
  description = "The hostname (and port) for the managed PostgreSQL database."
  type        = string
}

variable "postgres_user" {
  description = "The PostgreSQL user."
  type        = string
}

variable "postgres_password" {
  description = "The PostgreSQL password."
  type        = string
}

variable "postgres_db" {
  description = "The PostgreSQL database name."
  type        = string
}

# Optionally, you might pass in the FQDN for the frontend service for use in JWT environment variables.
variable "frontend_fqdn" {
  description = "The FQDN of the frontend container app (e.g. 'frontend.example-env.eastus.azurecontainerapps.io')."
  type        = string
  default     = "frontend.example-env.eastus.azurecontainerapps.io"
}

variable "min_replicas" {
  description = "Minimum number of GraphQL container replicas"
  type        = number
  default     = 2  # Ensures at least 2 replicas are always running
}

variable "max_replicas" {
  description = "Maximum number of GraphQL container replicas"
  type        = number
  default     = 10  # Allows scaling up to 10 replicas
}