#!/bin/bash
# Colors for better output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

IP="$1"
echo -e "${BLUE}Updating CloudFlare DNS for IP: ${IP}${NC}"

# Go to cloudflare directory
cd terraform/cloudflare

# Update IP in terraform.tfvars
sed -i "s/FRONTEND_IP_PLACEHOLDER/${IP}/" terraform.tfvars

# Initialize and apply
terraform init
terraform apply -auto-approve

# Return to root directory
cd ../..
