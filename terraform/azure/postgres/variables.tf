variable "server_name" {
  description = "The name of the PostgreSQL server. Must be globally unique."
  type        = string
}

variable "location" {
  description = "The Azure location (region) where the PostgreSQL server will be deployed."
  type        = string
}

variable "resource_group_name" {
  description = "The name of the resource group in which to deploy the PostgreSQL server."
  type        = string
}

variable "administrator_login" {
  description = "The PostgreSQL administrator login name."
  type        = string
}

variable "administrator_login_password" {
  description = "The PostgreSQL administrator login password."
  type        = string
  sensitive   = true
}

variable "sku_name" {
  description = "The SKU for the PostgreSQL server (for example, 'B_Gen5_1')."
  type        = string
  default     = "B_Gen5_1"
}

variable "storage_mb" {
  description = "The amount of storage (in MB) for the PostgreSQL server."
  type        = number
  default     = 5120  # 5 GB
}

variable "version" {
  description = "The PostgreSQL version to use."
  type        = string
  default     = "11"
}

variable "backup_retention_days" {
  description = "Number of days to retain backups."
  type        = number
  default     = 7
}

variable "geo_redundant_backup_enabled" {
  description = "Whether geo-redundant backups are enabled."
  type        = bool
  default     = false
}

variable "auto_grow_enabled" {
  description = "Whether auto grow is enabled for storage."
  type        = bool
  default     = true
}

variable "public_network_access_enabled" {
  description = "Whether public network access is enabled for the PostgreSQL server."
  type        = bool
  default     = true
}

variable "ssl_enforcement_enabled" {
  description = "Whether SSL is enforced for connections."
  type        = bool
  default     = true
}

variable "tags" {
  description = "A map of tags to assign to the PostgreSQL server."
  type        = map(string)
  default     = {}
}

variable "database_name" {
  description = "The name of the database to create on the PostgreSQL server."
  type        = string
}

variable "charset" {
  description = "The character set for the PostgreSQL database."
  type        = string
  default     = "UTF8"
}

variable "collation" {
  description = "The collation for the PostgreSQL database."
  type        = string
  default     = "English_United States.1252"
}

variable "firewall_rule_name" {
  description = "The name of the firewall rule."
  type        = string
  default     = "AllowAll"
}

variable "start_ip_address" {
  description = "The starting IP address for the firewall rule."
  type        = string
  default     = "0.0.0.0"
}

variable "end_ip_address" {
  description = "The ending IP address for the firewall rule."
  type        = string
  default     = "255.255.255.255"
}
