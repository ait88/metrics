variable "cloudflare_api_token" {
  description = "CloudFlare API token with Zone:DNS permissions"
  type        = string
  sensitive   = true
}

variable "cloudflare_zone_id" {
  description = "CloudFlare Zone ID for your domain"
  type        = string
}

variable "domain_name" {
  description = "Base domain name (e.g., example.com)"
  type        = string
}

variable "frontend_ip" {
  description = "IP address of the frontend server"
  type        = string
}

variable "subdomain_prefix" {
  description = "Prefix for subdomains (default: metrics)"
  type        = string
  default     = "metrics"
}
