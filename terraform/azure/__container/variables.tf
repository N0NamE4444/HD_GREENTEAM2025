variable "name" {
  description = "The name of the container instance"
  type        = string
}

variable "image" {
  description = "The Docker image to use"
  type        = string
}

variable "resource_group_name" {
  description = "The name of the resource group"
  type        = string
}

variable "location" {
  description = "The location of the container instance"
  type        = string
}

variable "cpu" {
  description = "The number of CPU cores to allocate"
  type        = number
  default     = 1
}

variable "memory" {
  description = "The amount of memory (in GB) to allocate"
  type        = number
  default     = 1.5
}

variable "environment_variables" {
  description = "Environment variables for the container"
  type        = map(string)
  default     = {}
}

variable "ports" {
  description = "List of ports to expose"
  type        = list(number)
  default     = []
}

variable "ip_type" {
  description = "The type of IP address (Public or Private)"
  type        = string
  default     = "Private"
}

variable "network_profile_id" {
  description = "The ID of the network profile"
  type        = string
}
