# Initialize Git repository if not already initialized
if [ ! -d .git ]; then
  echo -e "\n${YELLOW}Initializing Git repository...${NC}"
  git init
  echo -e "${GREEN}Git repository initialized.${NC}"
else
  echo -e "\n${YELLOW}Git repository already initialized${NC}"
fi#!/bin/bash

# Colors for better output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}====================================${NC}"
echo -e "${BLUE}Metrics Monitoring Infrastructure Installation${NC}"
echo -e "${BLUE}====================================${NC}"

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
echo -e "\n${BLUE}Checking dependencies...${NC}"
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
    case $OS in
      *Ubuntu*|*Debian*)
        echo -e "${BLUE}Installing dependencies with apt...${NC}"
        
        # Update package list
        sudo apt update
        
        # Install Git if needed
        if [[ " ${MISSING_DEPS[*]} " == *" git "* ]]; then
          sudo apt install -y git
        fi
        
        # Install Terraform if needed
        if [[ " ${MISSING_DEPS[*]} " == *" terraform "* ]]; then
          echo -e "${BLUE}Installing Terraform...${NC}"
          sudo apt install -y gnupg software-properties-common
          wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg
          echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
          sudo apt update
          sudo apt install -y terraform
        fi
        
        # Install Ansible if needed
        if [[ " ${MISSING_DEPS[*]} " == *" ansible "* ]]; then
          sudo apt install -y ansible
        fi
        
        # Install Docker if needed
        if [[ " ${MISSING_DEPS[*]} " == *" docker "* ]]; then
          echo -e "${BLUE}Installing Docker...${NC}"
          sudo apt install -y apt-transport-https ca-certificates curl gnupg-agent software-properties-common
          curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
          sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
          sudo apt update
          sudo apt install -y docker-ce docker-ce-cli containerd.io
          sudo usermod -aG docker $USER
          echo -e "${YELLOW}You may need to log out and back in for Docker permissions to take effect.${NC}"
        fi
        
        # Install Docker Compose if needed
        if [[ " ${MISSING_DEPS[*]} " == *" docker-compose "* ]]; then
          sudo apt install -y docker-compose
        fi
        
        # Install SSH utilities if needed
        if [[ " ${MISSING_DEPS[*]} " == *" ssh "* ]]; then
          sudo apt install -y openssh-client
        fi
        
        # Install curl if needed
        if [[ " ${MISSING_DEPS[*]} " == *" curl "* ]]; then
          sudo apt install -y curl
        fi
        ;;
        
      *Fedora*|*CentOS*|*Red\ Hat*)
        echo -e "${BLUE}Installing dependencies with dnf/yum...${NC}"
        
        # Install Git if needed
        if [[ " ${MISSING_DEPS[*]} " == *" git "* ]]; then
          sudo dnf install -y git
        fi
        
        # Install Terraform if needed
        if [[ " ${MISSING_DEPS[*]} " == *" terraform "* ]]; then
          echo -e "${BLUE}Installing Terraform...${NC}"
          sudo dnf install -y dnf-plugins-core
          sudo dnf config-manager --add-repo https://rpm.releases.hashicorp.com/fedora/hashicorp.repo
          sudo dnf install -y terraform
        fi
        
        # Install Ansible if needed
        if [[ " ${MISSING_DEPS[*]} " == *" ansible "* ]]; then
          sudo dnf install -y ansible
        fi
        
        # Install Docker if needed
        if [[ " ${MISSING_DEPS[*]} " == *" docker "* ]]; then
          echo -e "${BLUE}Installing Docker...${NC}"
          sudo dnf install -y dnf-plugins-core
          sudo dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
          sudo dnf install -y docker-ce docker-ce-cli containerd.io
          sudo systemctl start docker
          sudo systemctl enable docker
          sudo usermod -aG docker $USER
          echo -e "${YELLOW}You may need to log out and back in for Docker permissions to take effect.${NC}"
        fi
        
        # Install Docker Compose if needed
        if [[ " ${MISSING_DEPS[*]} " == *" docker-compose "* ]]; then
          sudo dnf install -y docker-compose
        fi
        
        # Install SSH utilities if needed
        if [[ " ${MISSING_DEPS[*]} " == *" ssh "* ]]; then
          sudo dnf install -y openssh-clients
        fi
        
        # Install curl if needed
        if [[ " ${MISSING_DEPS[*]} " == *" curl "* ]]; then
          sudo dnf install -y curl
        fi
        ;;
        
      *macOS*|*Darwin*)
        echo -e "${BLUE}Installing dependencies with Homebrew...${NC}"
        
        # Check if Homebrew is installed
        if ! command_exists brew; then
          echo -e "${YELLOW}Homebrew is not installed. Installing Homebrew...${NC}"
          /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        fi
        
        # Install Git if needed
        if [[ " ${MISSING_DEPS[*]} " == *" git "* ]]; then
          brew install git
        fi
        
        # Install Terraform if needed
        if [[ " ${MISSING_DEPS[*]} " == *" terraform "* ]]; then
          brew install terraform
        fi
        
        # Install Ansible if needed
        if [[ " ${MISSING_DEPS[*]} " == *" ansible "* ]]; then
          brew install ansible
        fi
        
        # Install Docker if needed
        if [[ " ${MISSING_DEPS[*]} " == *" docker "* ]]; then
          brew install --cask docker
          echo -e "${YELLOW}Please open Docker Desktop to complete the installation.${NC}"
        fi
        
        # Install Docker Compose if needed (included with Docker Desktop)
        if [[ " ${MISSING_DEPS[*]} " == *" docker-compose "* ]]; then
          echo -e "${YELLOW}Docker Compose is included with Docker Desktop.${NC}"
        fi
        
        # Install SSH utilities if needed
        if [[ " ${MISSING_DEPS[*]} " == *" ssh "* ]]; then
          echo -e "${YELLOW}SSH utilities should be pre-installed on macOS.${NC}"
        fi
        
        # Install curl if needed
        if [[ " ${MISSING_DEPS[*]} " == *" curl "* ]]; then
          brew install curl
        fi
        ;;
        
      *)
        echo -e "${RED}Unsupported OS: $OS${NC}"
        echo -e "${YELLOW}Please install the following dependencies manually:${NC}"
        for dep in "${MISSING_DEPS[@]}"; do
          echo "- $dep"
        done
        ;;
    esac
    
    # Verify installed dependencies
    echo -e "\n${BLUE}Verifying installed dependencies...${NC}"
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

# Check if a new .gitignore file is needed
if [ ! -f ".gitignore" ]; then
  echo -e "\n${BLUE}Creating .gitignore file...${NC}"
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