# Variables for the frontend infrastructure

variable "vultr_api_key" {
  description = "Vultr API key"
  type        = string
  sensitive   = true
}

variable "region" {
  description = "Vultr region"
  type        = string
  default     = "syd"  # Sydney Australia
}

variable "plan_id" {
  description = "Vultr plan ID"
  type        = string
  default     = "vhf-1c-1gb"  # High Frequency 1 CPU, 1 GB RAM
}

variable "ssh_key_name" {
  description = "Name of the SSH key to add to the instance"
  type        = string
}

variable "use_reserved_ip" {
  description = "Whether to create and use a reserved IP address"
  type        = bool
  default     = false
}

variable "allowed_ssh_ips" {
  description = "List of IP addresses allowed to SSH into the instance"
  type        = list(string)
  default     = ["0.0.0.0/0"]  # Not recommended for production
}