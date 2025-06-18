variable "postgres_user" {
  description = "PostgreSQL username"
  type        = string
  default     = "postgres"
}

variable "postgres_password" {
  description = "PostgreSQL password"
  type        = string
  default     = "example"
}

variable "postgres_db" {
  description = "PostgreSQL database name"
  type        = string
  default     = "data"
}

variable "pgadmin_email" {
  description = "pgAdmin default email"
  type        = string
  default     = "anoyne@anywhere.com"
}

variable "pgadmin_password" {
  description = "pgAdmin default password"
  type        = string
  default     = "example"
}
