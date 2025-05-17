#!/bin/bash

# Colors for better output
GREEN='\033[0;32m'
CYAN="\033[0;36m"
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${CYAN}====================================${NC}"
echo -e "${CYAN}Metrics Monitoring Infrastructure Installation${NC}"
echo -e "${CYAN}====================================${NC}"

# Save script path for potential restart
SCRIPT_PATH="$0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_URL="https://github.com/ait88/metrics.git"

# Function to check if a command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Function to detect OS
detect_os() {
  if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$NAME
    VERSION=$VERSION_ID
  elif type lsb_release >/dev/null 2>&1; then
    OS=$(lsb_release -si)
    VERSION=$(lsb_release -sr)
  elif [ -f /etc/lsb-release ]; then
    . /etc/lsb-release
    OS=$DISTRIB_ID
    VERSION=$DISTRIB_RELEASE
  elif [ -f /etc/debian_version ]; then
    OS="Debian"
    VERSION=$(cat /etc/debian_version)
  else
    OS=$(uname -s)
    VERSION=$(uname -r)
  fi
}

# Check and install dependencies
echo -e "\n${CYAN}Checking dependencies...${NC}"
detect_os

MISSING_DEPS=()

# Check for Git
if ! command_exists git; then
  MISSING_DEPS+=("git")
  echo -e "${YELLOW}Git is not installed.${NC}"
fi

# Check for Terraform
if ! command_exists terraform; then
  MISSING_DEPS+=("terraform")
  echo -e "${YELLOW}Terraform is not installed.${NC}"
fi

# Check for Ansible
if ! command_exists ansible; then
  MISSING_DEPS+=("ansible")
  echo -e "${YELLOW}Ansible is not installed.${NC}"
fi

# Check for Docker
if ! command_exists docker; then
  MISSING_DEPS+=("docker")
  echo -e "${YELLOW}Docker is not installed.${NC}"
fi

# Check for Docker Compose
if ! command_exists docker-compose; then
  MISSING_DEPS+=("docker-compose")
  echo -e "${YELLOW}Docker Compose is not installed.${NC}"
fi

# Check for SSH utilities
if ! command_exists ssh || ! command_exists ssh-keygen; then
  MISSING_DEPS+=("ssh")
  echo -e "${YELLOW}SSH utilities are not installed.${NC}"
fi

# Check for curl
if ! command_exists curl; then
  MISSING_DEPS+=("curl")
  echo -e "${YELLOW}curl is not installed.${NC}"
fi

# Install missing dependencies if any
if [ ${#MISSING_DEPS[@]} -gt 0 ]; then
  echo -e "\n${YELLOW}Missing dependencies: ${MISSING_DEPS[*]}${NC}"
  read -p "Do you want to install these dependencies? [y/N] " -n 1 -r
  echo
  
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    # Install dependencies based on OS (same as before)
    # ...
    
    # Verify installed dependencies
    echo -e "\n${CYAN}Verifying installed dependencies...${NC}"
    STILL_MISSING=()
    
    for dep in "${MISSING_DEPS[@]}"; do
      if ! command_exists "$dep"; then
        STILL_MISSING+=("$dep")
      fi
    done
    
    if [ ${#STILL_MISSING[@]} -gt 0 ]; then
      echo -e "${YELLOW}Some dependencies could not be installed automatically:${NC}"
      for dep in "${STILL_MISSING[@]}"; do
        echo "- $dep"
      done
      echo -e "${YELLOW}Please install them manually and run this script again.${NC}"
      exit 1
    else
      echo -e "${GREEN}All dependencies installed successfully!${NC}"
    fi
  else
    echo -e "${YELLOW}Please install the dependencies manually and run this script again.${NC}"
    exit 1
  fi
else
  echo -e "${GREEN}All required dependencies are already installed.${NC}"
fi

# Now handle the Git repository

# Check if in git repository
IS_GIT_REPO=false
if [ -d ".git" ]; then
  IS_GIT_REPO=true
  REPO_ROOT="$PWD"
  echo -e "\n${GREEN}Current directory is already a Git repository.${NC}"
elif git rev-parse --git-dir > /dev/null 2>&1; then
  IS_GIT_REPO=true
  REPO_ROOT="$(git rev-parse --show-toplevel)"
  echo -e "\n${GREEN}Found Git repository at $REPO_ROOT.${NC}"
else
  echo -e "\n${YELLOW}No Git repository found in current directory.${NC}"
  
  # Check if we're in an empty directory
  if [ "$(ls -A | grep -v '^install.sh$')" ]; then
    echo -e "${YELLOW}Current directory is not empty. Creating a clean directory is recommended.${NC}"
    read -p "Create a new directory for the repository? [Y/n] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
      METRICS_DIR="metrics"
      # Make sure we create a unique directory
      if [ -d "$METRICS_DIR" ]; then
        METRICS_DIR="metrics-$(date +%Y%m%d-%H%M%S)"
      fi
      mkdir -p "$METRICS_DIR"
      echo -e "${GREEN}Created directory: $METRICS_DIR${NC}"
      
      # Copy install script to new directory
      cp "$SCRIPT_PATH" "$METRICS_DIR/"
      
      echo -e "${YELLOW}Please run the script in the new directory:${NC}"
      echo -e "cd $METRICS_DIR && bash install.sh"
      exit 0
    fi
  fi
  
  # Prompt to clone repository
  read -p "Clone the metrics repository? [Y/n] " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Nn]$ ]]; then
    git clone "$REPO_URL" .
    if [ $? -ne 0 ]; then
      echo -e "${RED}Failed to clone repository.${NC}"
      exit 1
    fi
    echo -e "${GREEN}Repository cloned successfully.${NC}"
    IS_GIT_REPO=true
    REPO_ROOT="$PWD"
  else
    echo -e "${YELLOW}Will initialize a new Git repository locally.${NC}"
    git init
    if [ $? -ne 0 ]; then
      echo -e "${RED}Failed to initialize repository.${NC}"
      exit 1
    fi
    echo -e "${GREEN}Git repository initialized.${NC}"
    IS_GIT_REPO=true
    REPO_ROOT="$PWD"
  fi
fi

# If it's a git repo, check if it's up to date
if [ "$IS_GIT_REPO" = true ]; then
  # Check if the repo has a remote origin
  REMOTE_EXISTS=false
  if git remote -v | grep origin > /dev/null 2>&1; then
    REMOTE_EXISTS=true
    
    # Check for updates
    echo -e "\n${YELLOW}Checking for updates...${NC}"
    git fetch origin --quiet
    
    LOCAL=$(git rev-parse @)
    REMOTE=$(git rev-parse @{u} 2>/dev/null || echo "no-upstream")
    
    if [ "$REMOTE" != "no-upstream" ] && [ "$LOCAL" != "$REMOTE" ]; then
      echo -e "${YELLOW}Repository is not up to date.${NC}"
      read -p "Pull latest changes? [Y/n] " -n 1 -r
      echo
      if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        git pull
        if [ $? -eq 0 ]; then
          echo -e "${GREEN}Repository updated successfully.${NC}"
          
          # Check if install.sh has changed
          if ! cmp -s "$SCRIPT_PATH" "${REPO_ROOT}/install.sh"; then
            echo -e "${YELLOW}install.sh has been updated.${NC}"
            read -p "Restart script with the updated version? [Y/n] " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Nn]$ ]]; then
              exec "${REPO_ROOT}/install.sh"
              exit 0
            fi
          fi
        else
          echo -e "${RED}Failed to update repository.${NC}"
          read -p "Continue anyway? [y/N] " -n 1 -r
          echo
          if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
          fi
        fi
      fi
    else
      echo -e "${GREEN}Repository is up to date.${NC}"
    fi
  else
    echo -e "${YELLOW}Repository does not have a remote origin.${NC}"
    
    # Optionally add remote
    read -p "Add metrics repository as remote? [y/N] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      git remote add origin "$REPO_URL"
      if [ $? -eq 0 ]; then
        echo -e "${GREEN}Remote added successfully.${NC}"
        git fetch origin --quiet
        echo -e "${YELLOW}You may want to pull changes after setup.${NC}"
      else
        echo -e "${RED}Failed to add remote.${NC}"
      fi
    fi
  fi
fi

# Check if .gitignore file is needed
if [ ! -f ".gitignore" ]; then
  echo -e "\n${CYAN}Creating .gitignore file...${NC}"
  cat > .gitignore << EOF
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
  echo -e "${GREEN}.gitignore file created.${NC}"
fi

# Ensure we're in the repository root
if [ "$IS_GIT_REPO" = true ] && [ "$PWD" != "$REPO_ROOT" ]; then
  echo -e "\n${YELLOW}Changing to repository root: $REPO_ROOT${NC}"
  cd "$REPO_ROOT"
fi

# Continue with the rest of the install script...

# Step 0: SSH Key Setup
echo -e "\n${CYAN}Step 0: SSH Key Setup${NC}"
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
    
    # Generate unique identifier from existing key fingerprint
    KEY_FINGERPRINT=$(ssh-keygen -lf "$SSH_KEY_PATH" | awk '{print $2}' | cut -d':' -f2-)
    DEPLOYMENT_ID=$(echo "$KEY_FINGERPRINT" | tail -c 6)
    DEPLOYMENT_NAME="metrics_deployment_${DEPLOYMENT_ID}"
    echo -e "${GREEN}Generated deployment ID: $DEPLOYMENT_NAME${NC}"
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
  # Generate a temporary key without comment first
  ssh-keygen -t rsa -b 4096 -f "$SSH_KEY_PATH" -N "" -C "temporary"
  
  # Get the fingerprint for the new key
  KEY_FINGERPRINT=$(ssh-keygen -lf "$SSH_KEY_PATH" | awk '{print $2}' | cut -d':' -f2-)
  DEPLOYMENT_ID=$(echo "$KEY_FINGERPRINT" | tail -c 6)
  DEPLOYMENT_NAME="metrics_deployment_${DEPLOYMENT_ID}"
  
  # Update the key with the proper comment containing the unique ID
  ssh-keygen -f "$SSH_KEY_PATH" -c -C "$DEPLOYMENT_NAME"
  
  echo -e "${GREEN}SSH key generated at $SSH_KEY_PATH${NC}"
  echo -e "${GREEN}Generated deployment ID: $DEPLOYMENT_NAME${NC}"
fi

# Store deployment name for other scripts to use
echo "export METRICS_DEPLOYMENT_NAME=\"$DEPLOYMENT_NAME\"" > "$SSH_KEY_DIR/deployment_env"

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
# Export SSH key path and deployment name for setup.sh to use
export SSH_KEY_PATH
export METRICS_DEPLOYMENT_NAME="$DEPLOYMENT_NAME"
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
  # Export SSH key path and deployment name for deploy.sh to use
  export SSH_KEY_PATH
  export METRICS_DEPLOYMENT_NAME="$DEPLOYMENT_NAME"
  ./scripts/deploy.sh
  
  if [ $? -ne 0 ]; then
    echo -e "${RED}Deployment failed. Please check the errors above.${NC}"
    exit 1
  fi
  
  echo -e "\n${GREEN}Installation completed successfully!${NC}"
else
  echo -e "\n${YELLOW}You can deploy the infrastructure later by running:${NC}"
  echo -e "  SSH_KEY_PATH=\"$SSH_KEY_PATH\" METRICS_DEPLOYMENT_NAME=\"$DEPLOYMENT_NAME\" ./scripts/deploy.sh"
fi

echo -e "\n${CYAN}Happy monitoring!${NC}"