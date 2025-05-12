#!/bin/bash

# Colors for better output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}====================================${NC}"
echo -e "${BLUE}Metrics Monitoring Infrastructure Installation${NC}"
echo -e "${BLUE}====================================${NC}"

# Step 0: SSH Key Setup
echo -e "\n${BLUE}Step 0: SSH Key Setup${NC}"
SSH_KEY_DIR="$HOME/.ssh/metrics"
SSH_KEY_PATH="$SSH_KEY_DIR/id_rsa"

# Create directory if it doesn't exist
mkdir -p "$SSH_KEY_DIR"
chmod 700 "$SSH_KEY_DIR"

# Check if SSH key already exists
if [ -f "$SSH_KEY_PATH" ]; then
  echo -e "${YELLOW}SSH key already exists at $SSH_KEY_PATH${NC}"
  read -p "Do you want to use this existing key? [Y/n] " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Nn]$ ]]; then
    echo -e "${GREEN}Using existing SSH key.${NC}"
    USE_EXISTING_KEY=true
  else
    echo -e "${YELLOW}Creating new SSH key...${NC}"
    USE_EXISTING_KEY=false
  fi
else
  echo -e "${YELLOW}No existing SSH key found. Creating new key...${NC}"
  USE_EXISTING_KEY=false
fi

# Generate new key if needed
if [ "$USE_EXISTING_KEY" = false ]; then
  ssh-keygen -t rsa -b 4096 -f "$SSH_KEY_PATH" -N "" -C "metrics_deployment"
  echo -e "${GREEN}SSH key generated at $SSH_KEY_PATH${NC}"
fi

# Display the public key
echo -e "${YELLOW}Your SSH public key (add this to Vultr when creating a new instance):${NC}"
cat "$SSH_KEY_PATH.pub"
echo -e "${YELLOW}------------------------------------------------${NC}"
echo -e "${YELLOW}Make sure to add this key to Vultr's SSH Keys section before running setup.sh${NC}"
echo -e "${YELLOW}or manually add it to your existing server if you're using one.${NC}"

# Ask if the user wants to continue
read -p "Have you added the SSH key to Vultr/your server? [y/N] " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo -e "${YELLOW}Please add the SSH key before continuing.${NC}"
  echo -e "${YELLOW}You can resume installation later by running this script again.${NC}"
  exit 0
fi

# Check if setup.sh exists
if [ ! -f "setup.sh" ]; then
  echo -e "${RED}Error: setup.sh not found. Make sure you're in the correct directory.${NC}"
  exit 1
fi

# Make files executable
chmod +x setup.sh

# Create scripts directory
mkdir -p scripts

# Run setup.sh
echo -e "\n${YELLOW}Step 1: Running setup.sh to configure the infrastructure...${NC}"
# Export SSH key path for setup.sh to use
export SSH_KEY_PATH
./setup.sh

if [ $? -ne 0 ]; then
  echo -e "${RED}Setup failed. Please check the errors above.${NC}"
  exit 1
fi

# Check if the user wants to deploy immediately
echo -e "\n${YELLOW}Setup completed successfully!${NC}"
read -p "Do you want to deploy the infrastructure now? [y/N] " -n 1 -r
echo

if [[ $REPLY =~ ^[Yy]$ ]]; then
  # Make deploy.sh executable
  chmod +x scripts/deploy.sh
  
  # Run deploy.sh
  echo -e "\n${YELLOW}Step 2: Running deploy.sh to deploy the infrastructure...${NC}"
  # Export SSH key path for deploy.sh to use
  export SSH_KEY_PATH
  ./scripts/deploy.sh
  
  if [ $? -ne 0 ]; then
    echo -e "${RED}Deployment failed. Please check the errors above.${NC}"
    exit 1
  fi
  
  echo -e "\n${GREEN}Installation completed successfully!${NC}"
else
  echo -e "\n${YELLOW}You can deploy the infrastructure later by running:${NC}"
  echo -e "  SSH_KEY_PATH=\"$SSH_KEY_PATH\" ./scripts/deploy.sh"
fi

echo -e "\n${BLUE}Happy monitoring!${NC}"