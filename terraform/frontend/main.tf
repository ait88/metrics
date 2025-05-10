# Frontend infrastructure configuration

terraform {
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
  }
}

provider "digitalocean" {
  token = var.do_token
}

# Create a new VPS for the frontend component
resource "digitalocean_droplet" "frontend" {
  image    = "ubuntu-22-04-x64"
  name     = "metrics-frontend"
  region   = var.region
  size     = "s-1vcpu-1gb"  # Adjust based on your needs
  ssh_keys = [var.ssh_key_id]

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

    # Configure firewall
    ufw default deny incoming
    ufw default allow outgoing
    ufw allow 22/tcp
    ufw allow 80/tcp
    ufw allow 443/tcp
    ufw allow 51820/udp  # WireGuard
    ufw enable
  EOF

  tags = ["metrics", "frontend"]
}

# Create a firewall
resource "digitalocean_firewall" "frontend" {
  name = "metrics-frontend-firewall"

  droplet_ids = [digitalocean_droplet.frontend.id]

  # SSH
  inbound_rule {
    protocol         = "tcp"
    port_range       = "22"
    source_addresses = var.allowed_ssh_ips
  }

  # HTTP
  inbound_rule {
    protocol         = "tcp"
    port_range       = "80"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  # HTTPS
  inbound_rule {
    protocol         = "tcp"
    port_range       = "443"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  # WireGuard
  inbound_rule {
    protocol         = "udp"
    port_range       = "51820"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  # Allow all outbound traffic
  outbound_rule {
    protocol              = "tcp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "udp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "icmp"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }
}

# Create a reserved IP
resource "digitalocean_reserved_ip" "frontend" {
  droplet_id = digitalocean_droplet.frontend.id
  region     = var.region
}

# Output the IP address
output "frontend_ip" {
  value = digitalocean_reserved_ip.frontend.ip_address
}
