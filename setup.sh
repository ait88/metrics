#!/bin/bash

# Colors for better output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}====================================${NC}"
echo -e "${BLUE}Metrics Monitoring Infrastructure Setup${NC}"
echo -e "${BLUE}====================================${NC}"

# Check prerequisites
echo -e "\n${YELLOW}Checking prerequisites...${NC}"
command -v terraform >/dev/null 2>&1 || { echo -e "${RED}Terraform is required but not installed. Aborting.${NC}"; exit 1; }
command -v git >/dev/null 2>&1 || { echo -e "${RED}Git is required but not installed. Aborting.${NC}"; exit 1; }

# Create necessary directories
echo -e "\n${YELLOW}Creating directory structure...${NC}"
mkdir -p terraform/backend
mkdir -p ansible/roles/{frontend,backend,wireguard}/templates
mkdir -p ansible/inventories/{development,production}
mkdir -p ansible/vars
mkdir -p docker/{frontend,backend}/{prometheus,grafana,alertmanager,loki}
mkdir -p exporters/{node_exporter,cadvisor,blackbox_exporter,hypervisor_exporters,windows_exporter}
mkdir -p dashboards

echo -e "${GREEN}Directory structure created successfully.${NC}"

# Collect variables
echo -e "\n${YELLOW}Please provide the following information for configuration:${NC}"

# Vultr configuration
read -p "Vultr API Key: " VULTR_API_KEY
read -p "Vultr SSH Key Name (as shown in Vultr dashboard): " SSH_KEY_NAME
read -p "Vultr Region (default is 'ewr' for New Jersey): " REGION
REGION=${REGION:-ewr}
read -p "Vultr Plan ID (default is 'vc2-1c-1gb' for 1 CPU, 1GB RAM): " PLAN_ID
PLAN_ID=${PLAN_ID:-vc2-1c-1gb}

# Domain configuration
read -p "Domain Name for the monitoring services: " DOMAIN_NAME
read -p "Email for Let's Encrypt certificates: " ACME_EMAIL

# Basic authentication
read -p "Basic Auth Username for frontend services: " BASIC_AUTH_USER
read -s -p "Basic Auth Password for frontend services: " BASIC_AUTH_PASS
echo ""

# Generate hashed password for basic auth
if command -v htpasswd >/dev/null 2>&1; then
    HASHED_PASSWORD=$(htpasswd -nbB "${BASIC_AUTH_USER}" "${BASIC_AUTH_PASS}" | cut -d ":" -f 2)
else
    echo -e "${YELLOW}htpasswd not found. Using plain text password (not recommended for production).${NC}"
    HASHED_PASSWORD="${BASIC_AUTH_PASS}"
fi

# Configure Terraform
echo -e "\n${YELLOW}Setting up Terraform configuration...${NC}"

# Create terraform.tfvars file for frontend
cat > terraform/frontend/terraform.tfvars << EOF
vultr_api_key = "${VULTR_API_KEY}"
region = "${REGION}"
plan_id = "${PLAN_ID}"
ssh_key_name = "${SSH_KEY_NAME}"

# List of IP addresses allowed to SSH into the instance
# The default allows SSH from anywhere (not recommended for production)
allowed_ssh_ips = ["0.0.0.0/0"]
EOF

echo -e "${GREEN}Terraform configuration created successfully.${NC}"

# Configure Ansible variables
echo -e "\n${YELLOW}Setting up Ansible configuration...${NC}"

# Create ansible/vars/main.yml
cat > ansible/vars/main.yml << EOF
---
# General configuration
domain_name: "${DOMAIN_NAME}"
acme_email: "${ACME_EMAIL}"

# Wireguard configuration
wireguard_address: "10.8.0.1/24"
wireguard_port: 51820
wireguard_peers:
  - public_key: "TO_BE_GENERATED"
    allowed_ips: "10.8.0.2/32"

# Docker configuration
docker_compose_version: "2.18.1"
EOF

# Create ansible/vars/secrets.yml
cat > ansible/vars/secrets.yml << EOF
---
# Frontend authentication
basic_auth: "${BASIC_AUTH_USER}:${HASHED_PASSWORD}"

# Backend authentication
remote_write_username: "prometheus"
remote_write_password: "$(openssl rand -hex 16)"
EOF

echo -e "${GREEN}Ansible configuration created successfully.${NC}"

# Create an example inventory file
cat > ansible/inventories/production/hosts.example.yml << EOF
---
all:
  children:
    frontend:
      hosts:
        metrics-frontend:
          ansible_host: "FRONTEND_IP_HERE"  # Will be populated by terraform output
          ansible_user: root
          ansible_ssh_private_key_file: "~/.ssh/id_rsa"  # Update with your key path
    
    backend:
      children:
        prometheus:
          hosts:
            metrics-prometheus:
              ansible_host: 192.168.1.10  # Update with your actual IP
              ansible_user: ubuntu
              ansible_ssh_private_key_file: "~/.ssh/id_rsa"
EOF

# Configure Docker environment for frontend
echo -e "\n${YELLOW}Setting up Docker configuration...${NC}"

mkdir -p docker/frontend

# Create .env file for Docker Compose
cat > docker/frontend/.env.example << EOF
DOMAIN_NAME=${DOMAIN_NAME}
ACME_EMAIL=${ACME_EMAIL}
BASIC_AUTH=${BASIC_AUTH_USER}:${HASHED_PASSWORD}
BACKEND_PROMETHEUS_URL=http://10.8.0.2:9090/api/v1/write
REMOTE_WRITE_USERNAME=prometheus
REMOTE_WRITE_PASSWORD=change_me_in_production
EOF

echo -e "${GREEN}Docker configuration created successfully.${NC}"

# Initialize Git repository if not already initialized
if [ ! -d .git ]; then
    echo -e "\n${YELLOW}Initializing Git repository...${NC}"
    git init
    echo -e "${GREEN}Git repository initialized.${NC}"
fi

# Add files to .gitignore if not already there
if [ ! -f .gitignore ]; then
    cp .gitignore.example .gitignore
    echo -e "${GREEN}Created .gitignore file.${NC}"
fi

echo -e "\n${GREEN}Setup completed successfully!${NC}"
echo -e "${YELLOW}Next steps:${NC}"
echo -e "1. Review the generated configuration files"
echo -e "2. Deploy the frontend infrastructure with:"
echo -e "   cd terraform/frontend && terraform init && terraform plan -out=tfplan && terraform apply tfplan"
echo -e "3. Update the Ansible inventory with the actual frontend IP"
echo -e "4. Deploy the configuration with Ansible"
echo -e "\n${BLUE}Happy monitoring!${NC}"

# Make the script executable
chmod +x setup.sh
