# Create scripts directory if it doesn't exist
mkdir -p scripts

# Make update_cloudflare.sh executable if it exists
if [ -f "scripts/update_cloudflare.sh" ]; then
  chmod +x scripts/update_cloudflare.sh
fi# Configure CloudFlare (if selected)
if [ "$USE_CLOUDFLARE" = true ]; then
  echo -e "\n${YELLOW}Setting up CloudFlare configuration...${NC}"
  
  CLOUDFLARE_TFVARS_FILE="terraform/cloudflare/terraform.tfvars"
  if create_file_if_not_exists "$CLOUDFLARE_TFVARS_FILE"; then
    cat > "$CLOUDFLARE_TFVARS_FILE" << EOF
cloudflare_api_token = "${CLOUDFLARE_API_TOKEN}"
cloudflare_zone_id = "${CLOUDFLARE_ZONE_ID}"
domain_name = "${DOMAIN_NAME}"
frontend_ip = "FRONTEND_IP_PLACEHOLDER" # Will be updated after frontend deployment
subdomain_prefix = "${SUBDOMAIN_PREFIX}"
EOF
    echo -e "${GREEN}Created CloudFlare configuration: $CLOUDFLARE_TFVARS_FILE${NC}"
  fi
fi#!/bin/bash

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

# Create necessary directories (idempotent)
echo -e "\n${YELLOW}Creating directory structure...${NC}"
for dir in \
  terraform/{frontend,backend,cloudflare} \
  ansible/roles/{frontend,backend,wireguard}/templates \
  ansible/inventories/{development,production} \
  ansible/vars \
  docker/{frontend,backend}/{prometheus,grafana,alertmanager,loki} \
  exporters/{node_exporter,cadvisor,blackbox_exporter,hypervisor_exporters,windows_exporter} \
  dashboards
do
  if [ ! -d "$dir" ]; then
    mkdir -p "$dir"
    echo -e "Created directory: ${GREEN}$dir${NC}"
  else
    echo -e "Directory already exists: ${YELLOW}$dir${NC}"
  fi
done

echo -e "${GREEN}Directory structure checked and created where needed.${NC}"

# Function to safely create a file without overwriting existing ones
create_file_if_not_exists() {
  if [ -f "$1" ]; then
    echo -e "${YELLOW}File already exists: $1${NC}"
    read -p "Do you want to overwrite it? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      echo -e "${YELLOW}Skipping file: $1${NC}"
      return 1
    fi
  fi
  return 0
}

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
read -p "Domain Name for the monitoring services (e.g., example.com): " DOMAIN_NAME
read -p "Email for Let's Encrypt certificates: " ACME_EMAIL
read -p "Subdomain prefix for monitoring services (default: metrics): " SUBDOMAIN_PREFIX
SUBDOMAIN_PREFIX=${SUBDOMAIN_PREFIX:-metrics}

# CloudFlare configuration (optional)
read -p "Do you want to configure CloudFlare DNS? (y/n): " CONFIGURE_CLOUDFLARE
if [[ "$CONFIGURE_CLOUDFLARE" =~ ^[Yy]$ ]]; then
  read -p "CloudFlare API Token (with Zone:DNS permissions): " CLOUDFLARE_API_TOKEN
  read -p "CloudFlare Zone ID (found in domain dashboard): " CLOUDFLARE_ZONE_ID
  USE_CLOUDFLARE=true
else
  USE_CLOUDFLARE=false
fi

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
TFVARS_FILE="terraform/frontend/terraform.tfvars"
if create_file_if_not_exists "$TFVARS_FILE"; then
  cat > "$TFVARS_FILE" << EOF
vultr_api_key = "${VULTR_API_KEY}"
region = "${REGION}"
plan_id = "${PLAN_ID}"
ssh_key_name = "${SSH_KEY_NAME}"

# List of IP addresses allowed to SSH into the instance
# The default allows SSH from anywhere (not recommended for production)
allowed_ssh_ips = ["0.0.0.0/0"]
EOF
  echo -e "${GREEN}Created Terraform configuration: $TFVARS_FILE${NC}"
fi

# Configure Ansible variables
echo -e "\n${YELLOW}Setting up Ansible configuration...${NC}"

# Create ansible/vars/main.yml
ANSIBLE_MAIN_FILE="ansible/vars/main.yml"
if create_file_if_not_exists "$ANSIBLE_MAIN_FILE"; then
  cat > "$ANSIBLE_MAIN_FILE" << EOF
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
  echo -e "${GREEN}Created Ansible configuration: $ANSIBLE_MAIN_FILE${NC}"
fi

# Create ansible/vars/secrets.yml
ANSIBLE_SECRETS_FILE="ansible/vars/secrets.yml"
if create_file_if_not_exists "$ANSIBLE_SECRETS_FILE"; then
  cat > "$ANSIBLE_SECRETS_FILE" << EOF
---
# Frontend authentication
basic_auth: "${BASIC_AUTH_USER}:${HASHED_PASSWORD}"

# Backend authentication
remote_write_username: "prometheus"
remote_write_password: "$(openssl rand -hex 16)"
EOF
  echo -e "${GREEN}Created Ansible secrets: $ANSIBLE_SECRETS_FILE${NC}"
fi

# Create an example inventory file
INVENTORY_EXAMPLE_FILE="ansible/inventories/production/hosts.example.yml"
if create_file_if_not_exists "$INVENTORY_EXAMPLE_FILE"; then
  cat > "$INVENTORY_EXAMPLE_FILE" << EOF
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
  echo -e "${GREEN}Created Ansible inventory example: $INVENTORY_EXAMPLE_FILE${NC}"
fi

# Configure Docker environment for frontend
echo -e "\n${YELLOW}Setting up Docker configuration...${NC}"

DOCKER_ENV_FILE="docker/frontend/.env.example"
if create_file_if_not_exists "$DOCKER_ENV_FILE"; then
  cat > "$DOCKER_ENV_FILE" << EOF
DOMAIN_NAME=${DOMAIN_NAME}
ACME_EMAIL=${ACME_EMAIL}
BASIC_AUTH=${BASIC_AUTH_USER}:${HASHED_PASSWORD}
BACKEND_PROMETHEUS_URL=http://10.8.0.2:9090/api/v1/write
REMOTE_WRITE_USERNAME=prometheus
REMOTE_WRITE_PASSWORD=change_me_in_production
EOF
  echo -e "${GREEN}Created Docker environment example: $DOCKER_ENV_FILE${NC}"
fi

# Create or check .gitignore
GITIGNORE_FILE=".gitignore"
if [ ! -f "$GITIGNORE_FILE" ]; then
  echo -e "\n${YELLOW}Creating .gitignore file...${NC}"
  cat > "$GITIGNORE_FILE" << EOF
# Terraform
.terraform/
.terraform.lock.hcl
terraform.tfstate
terraform.tfstate.backup
terraform.tfvars
*.tfplan
override.tf
override.tf.json
*_override.tf
*_override.tf.json

# Ansible
ansible/inventories/*/hosts.yml
ansible/vars/secrets.yml
*.retry

# SSH Keys
*.pem
*.key
id_rsa*
*.ppk

# Environment variables
.env
.env.*
!.env.example

# Docker
docker-compose.override.yml

# Certificates
*.crt
*.csr
*.key
*.p12
*.pem

# OS specific
.DS_Store
Thumbs.db

# Editor specific
.vscode/
.idea/
*.swp
*~

# Wireguard
wg*.conf

# Other sensitive data
**/credentials.yml
**/passwords.yml
**/tokens.yml
EOF
  echo -e "${GREEN}Created .gitignore file${NC}"
else
  echo -e "${YELLOW}.gitignore file already exists${NC}"
fi

# Initialize Git repository if not already initialized
if [ ! -d .git ]; then
  echo -e "\n${YELLOW}Initializing Git repository...${NC}"
  git init
  echo -e "${GREEN}Git repository initialized.${NC}"
else
  echo -e "\n${YELLOW}Git repository already initialized${NC}"
fi

echo -e "\n${GREEN}Setup completed successfully!${NC}"
echo -e "${YELLOW}Next steps:${NC}"
echo -e "1. Review the generated configuration files"
echo -e "2. Deploy the frontend infrastructure with:"
echo -e "   cd terraform/frontend && terraform init && terraform plan -out=tfplan && terraform apply tfplan"
echo -e "3. Update the Ansible inventory with the actual frontend IP"
if [ "$USE_CLOUDFLARE" = true ]; then
  echo -e "4. Update CloudFlare DNS records with the frontend IP:"
  echo -e "   ./scripts/update_cloudflare.sh \$(terraform -chdir=terraform/frontend output -raw frontend_ip)"
  echo -e "5. Deploy the configuration with Ansible"
else
  echo -e "4. Deploy the configuration with Ansible"
fi
echo -e "\n${BLUE}Happy monitoring!${NC}"