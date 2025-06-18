

# Set the provider based on the selected environment
variable "environment" {
  description = "Deployment environment: 'docker' or 'azure'"
  type        = string
  default     = "docker"
}

module "deployment" {
  # source = "./${var.environment}" # Dynamically selects Docker or Azure
  # source =  var.environment == "docker"? "./docker": "./azure" # Dynamically selects Docker or Azure
  source =  "./docker"

  postgres_user     = var.postgres_user
  postgres_password = var.postgres_password
  postgres_db       = var.postgres_db
  pgadmin_email     = var.pgadmin_email
  pgadmin_password  = var.pgadmin_password
}
