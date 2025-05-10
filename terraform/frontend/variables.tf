# Variables for the frontend infrastructure

variable "do_token" {
  description = "DigitalOcean API token"
  type        = string
  sensitive   = true
}

variable "region" {
  description = "DigitalOcean region"
  type        = string
  default     = "nyc1"
}

variable "ssh_key_id" {
  description = "ID of the SSH key to add to the droplet"
  type        = string
}

variable "allowed_ssh_ips" {
  description = "List of IP addresses allowed to SSH into the droplet"
  type        = list(string)
  default     = ["0.0.0.0/0"]  # Not recommended for production
}
