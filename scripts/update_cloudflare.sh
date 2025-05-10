#!/bin/bash

# Colors for better output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}====================================${NC}"
echo -e "${BLUE}Update CloudFlare DNS Records${NC}"
echo -e "${BLUE}====================================${NC}"

# Check if frontend IP is provided
if [ -z "$1" ]; then
  # Try to get it from Terraform
  FRONTEND_IP=$(cd terraform/frontend && terraform output -raw frontend_ip 2>/dev/null)
  
  if [ -z "$FRONTEND_IP" ]; then
    echo -e "${RED}Error: Frontend IP not provided and could not be retrieved from Terraform.${NC}"
    echo -e "${YELLOW}Usage: $0 <frontend_ip>${NC}"
    exit 1
  fi
else
  FRONTEND_IP="$1"
fi

echo -e "${YELLOW}Using Frontend IP: ${FRONTEND_IP}${NC}"

# Update the CloudFlare terraform.tfvars file with the frontend IP
sed -i "s/FRONTEND_IP_PLACEHOLDER/${FRONTEND_IP}/" terraform/cloudflare/terraform.tfvars || {
  echo -e "${RED}Error: Failed to update CloudFlare terraform.tfvars with frontend IP.${NC}"
  exit 1
}

# Initialize and apply CloudFlare configuration
cd terraform/cloudflare || {
  echo -e "${RED}Error: CloudFlare Terraform directory not found.${NC}"
  exit 1
}

echo -e "${YELLOW}Initializing Terraform...${NC}"
terraform init || {
  echo -e "${RED}Error: Failed to initialize Terraform.${NC}"
  exit 1
}

echo -e "${YELLOW}Applying CloudFlare configuration...${NC}"
terraform apply -auto-approve || {
  echo -e "${RED}Error: Failed to apply CloudFlare configuration.${NC}"
  exit 1
}

echo -e "${GREEN}CloudFlare DNS records updated successfully!${NC}"

# Display the URLs
echo -e "\n${YELLOW}Monitoring URLs:${NC}"
terraform output | sed 's/^/  /'

cd ../..