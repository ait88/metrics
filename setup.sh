# Check if SSH_KEY_PATH is set
if [ -z "${SSH_KEY_PATH}" ]; then
  echo -e "${YELLOW}SSH_KEY_PATH not set. Using default ~/.ssh/id_rsa${NC}"
  SSH_KEY_PATH="$HOME/.ssh/id_rsa"
else
  echo -e "${GREEN}Using SSH key: ${SSH_KEY_PATH}${NC}"
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
echo -e "${YELLOW}Note: This script is typically called by install.sh${NC}"
echo -e "${YELLOW}but can be run separately if needed.${NC}"

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

# Detect current external IP for improved security
echo -e "\n${YELLOW}Detecting your current external IP address...${NC}"
CURRENT_IP=""
for IP_SERVICE in "ifconfig.me" "ipinfo.io/ip" "api.ipify.org"; do
  if CURRENT_IP=$(curl -s --max-time 5 "$IP_SERVICE"); then
    if [[ $CURRENT_IP =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
      echo -e "Detected external IP: ${GREEN}${CURRENT_IP}${NC}"
      break
    fi
  fi
done

if [ -z "$CURRENT_IP" ]; then
  echo -e "${YELLOW}Could not detect external IP. Will use 0.0.0.0/0 (allow from anywhere) as default.${NC}"
  DEFAULT_SSH_IPS="0.0.0.0/0"
else
  DEFAULT_SSH_IPS="${CURRENT_IP}/32"
fi

read -p "IP addresses allowed to SSH into the instance (default: ${DEFAULT_SSH_IPS}): " ALLOWED_SSH_IPS
ALLOWED_SSH_IPS=${ALLOWED_SSH_IPS:-$DEFAULT_SSH_IPS}

# Convert single IP to array format for Terraform
if [[ "$ALLOWED_SSH_IPS" != *","* ]]; then
  ALLOWED_SSH_IPS_TF="[\"${ALLOWED_SSH_IPS}\"]"
else
  # Convert comma-separated list to Terraform array format
  IPS=$(echo $ALLOWED_SSH_IPS | tr ',' ' ')
  ALLOWED_SSH_IPS_TF="["
  for IP in $IPS; do
    ALLOWED_SSH_IPS_TF="${ALLOWED_SSH_IPS_TF}\"${IP}\", "
  done
  ALLOWED_SSH_IPS_TF="${ALLOWED_SSH_IPS_TF%,*}]"
fi

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
allowed_ssh_ips = ${ALLOWED_SSH_IPS_TF}
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
          ansible_ssh_private_key_file: "${SSH_KEY_PATH}"
    
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

# Configure CloudFlare (if selected)
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
fi

# Remove .gitignore creation (moved to install.sh)


# Initialize Git repository if not already initialized (already included in install.sh, so remove from here)


# Make scripts executable if they exist
mkdir -p scripts
if [ -f "scripts/update_cloudflare.sh" ]; then
  chmod +x scripts/update_cloudflare.sh
fi
if [ -f "scripts/deploy.sh" ]; then
  chmod +x scripts/deploy.sh
fi

echo -e "\n${GREEN}Setup completed successfully!${NC}"
echo -e "${YELLOW}Next steps:${NC}"
echo -e "1. Review the generated configuration files"
echo -e "2. Run the deployment script to deploy the infrastructure:"
echo -e "   ./scripts/deploy.sh"
echo -e "   or follow the manual steps:"
echo -e "   a. Deploy the frontend infrastructure with Terraform"
echo -e "   b. Update the Ansible inventory with the actual frontend IP"
if [ "$USE_CLOUDFLARE" = true ]; then
  echo -e "   c. Update CloudFlare DNS records with the frontend IP"
  echo -e "   d. Deploy the configuration with Ansible"
else
  echo -e "   c. Deploy the configuration with Ansible"
fi
echo -e "\n${BLUE}Happy monitoring!${NC}"