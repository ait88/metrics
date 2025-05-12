# Frontend infrastructure configuration

terraform {
  required_providers {
    vultr = {
      source  = "vultr/vultr"
      version = "~> 2.12.0"
    }
  }
}

provider "vultr" {
  api_key = var.vultr_api_key
  rate_limit = 700
  retry_limit = 3
}

# Create a firewall group
resource "vultr_firewall_group" "frontend" {
  description = "Metrics Frontend Firewall"
}

# SSH rule
resource "vultr_firewall_rule" "ssh" {
  firewall_group_id = vultr_firewall_group.frontend.id
  protocol          = "tcp"
  ip_type           = "v4"
  subnet            = "0.0.0.0"
  subnet_size       = 0
  port              = "22"
  notes             = "Allow SSH"
}

# HTTP rule
resource "vultr_firewall_rule" "http" {
  firewall_group_id = vultr_firewall_group.frontend.id
  protocol          = "tcp"
  ip_type           = "v4"
  subnet            = "0.0.0.0"
  subnet_size       = 0
  port              = "80"
  notes             = "Allow HTTP"
}

# HTTPS rule
resource "vultr_firewall_rule" "https" {
  firewall_group_id = vultr_firewall_group.frontend.id
  protocol          = "tcp"
  ip_type           = "v4"
  subnet            = "0.0.0.0"
  subnet_size       = 0
  port              = "443"
  notes             = "Allow HTTPS"
}

# WireGuard rule
resource "vultr_firewall_rule" "wireguard" {
  firewall_group_id = vultr_firewall_group.frontend.id
  protocol          = "udp"
  ip_type           = "v4"
  subnet            = "0.0.0.0"
  subnet_size       = 0
  port              = "51820"
  notes             = "Allow WireGuard"
}

# Look up the SSH key by name
data "vultr_ssh_key" "metrics" {
  filter {
    name = "name"
    values = [var.ssh_key_name]
  }
}

# Create a new VPS for the frontend component
resource "vultr_instance" "frontend" {
  plan             = var.plan_id                # e.g., "vc2-1c-1gb"
  region           = var.region                 # e.g., "ewr" (New Jersey)
  os_id            = 1743                       # Ubuntu 22.04 LTS x64
  label            = "metrics-frontend"
  hostname         = "metrics-frontend"
  ssh_key_ids      = [data.vultr_ssh_key.metrics.id]
  enable_ipv6      = true
  backups          = "disabled"
  ddos_protection  = false
  activation_email = false
  firewall_group_id = vultr_firewall_group.frontend.id
  
  # User data for initial setup
  user_data = <<-EOF
    #!/bin/bash
    apt-get update
    apt-get install -y \
      apt-transport-https \
      ca-certificates \
      curl \
      gnupg-agent \
      software-properties-common \
      ufw

    # Install Docker
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
    add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io
    systemctl enable docker
    systemctl start docker

    # Install WireGuard
    apt-get install -y wireguard

    # Configure firewall - more restrictive approach
    ufw default deny incoming
    ufw default allow outgoing
    
    # Allow SSH only from specified IPs if provided
    if [ -n "${join(",", var.allowed_ssh_ips)}" ]; then
      for ip in ${join(" ", var.allowed_ssh_ips)}; do
        ufw allow from $ip to any port 22 proto tcp
      done
    else
      # Fallback to allowing SSH from anywhere (not recommended for production)
      ufw allow 22/tcp
    fi
    
    # Allow HTTP/HTTPS for web access
    ufw allow 80/tcp
    ufw allow 443/tcp
    
    # Allow WireGuard VPN
    ufw allow 51820/udp
    
    # Enable firewall
    echo "y" | ufw enable
    
    # Set SSH to prohibit password authentication
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
    systemctl restart sshd
  EOF

  tags = ["metrics", "frontend"]
}

# Create a reserved IP (equivalent to floating IP in Vultr) if enabled
resource "vultr_reserved_ip" "frontend" {
  count            = var.use_reserved_ip ? 1 : 0
  region           = var.region
  ip_type          = "v4"
  label            = "metrics-frontend-ip"
  instance_id      = vultr_instance.frontend.id
}

# Output the IP address
output "frontend_ip" {
  value = var.use_reserved_ip ? vultr_reserved_ip.frontend[0].ip : vultr_instance.frontend.main_ip
}

# Output the instance ID for API operations if needed
output "instance_id" {
  value = vultr_instance.frontend.id
}

# Output the IP address
output "frontend_ip" {
  value = vultr_instance.frontend.main_ip
}