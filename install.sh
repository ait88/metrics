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
  ./scripts/deploy.sh
  
  if [ $? -ne 0 ]; then
    echo -e "${RED}Deployment failed. Please check the errors above.${NC}"
    exit 1
  fi
  
  echo -e "\n${GREEN}Installation completed successfully!${NC}"
else
  echo -e "\n${YELLOW}You can deploy the infrastructure later by running:${NC}"
  echo -e "  ./scripts/deploy.sh"
fi

echo -e "\n${BLUE}Happy monitoring!${NC}"
