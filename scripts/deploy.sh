#!/bin/bash

# Colors for better output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Default settings
FORCE=false
SKIP_CONFIRMATION=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    -f|--force)
      FORCE=true
      SKIP_CONFIRMATION=true
      shift
      ;;
    -y|--yes)
      SKIP_CONFIRMATION=true
      shift
      ;;
    -h|--help)
      echo "Usage: $0 [options]"
      echo "Options:"
      echo "  -f, --force    Force deployment, skip confirmations and destroy existing infrastructure"
      echo "  -y, --yes      Skip all confirmations but don't destroy existing infrastructure"
      echo "  -h, --help     Show this help message"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      echo "Use -h or --help for usage information"
      exit 1
      ;;
  esac
done


echo -e "${BLUE}====================================${NC}"
echo -e "${BLUE}Metrics Monitoring Infrastructure Deployment${NC}"
echo -e "${BLUE}====================================${NC}"

# Function to check if a command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Check if SSH_KEY_PATH is set
if [ -z "${SSH_KEY_PATH}" ]; then
  echo -e "${YELLOW}SSH_KEY_PATH not set. Using default ~/.ssh/id_rsa${NC}"
  SSH_KEY_PATH="$HOME/.ssh/id_rsa"
else
  echo -e "${GREEN}Using SSH key: ${SSH_KEY_PATH}${NC}"
fi

# Check if the SSH key exists
if [ ! -f "${SSH_KEY_PATH}" ]; then
  echo -e "${RED}SSH key not found at ${SSH_KEY_PATH}. Please check the path.${NC}"
  echo -e "${YELLOW}You can create a key using: ssh-keygen -t rsa -b 4096 -f \"${SSH_KEY_PATH}\" -N \"\"${NC}"
  exit 1
fi

# Function to ask for confirmation
confirm() {
  if [ "$SKIP_CONFIRMATION" = true ]; then
    return 0
  fi
  
  read -p "$1 [y/N] " -n 1 -r
  echo
  [[ $REPLY =~ ^[Yy]$ ]]
}

# Check prerequisites
echo -e "\n${YELLOW}Checking prerequisites...${NC}"
command_exists terraform || { echo -e "${RED}Terraform is required but not installed. Aborting.${NC}"; exit 1; }
command_exists git || { echo -e "${RED}Git is required but not installed. Aborting.${NC}"; exit 1; }
command_exists ssh || { echo -e "${RED}SSH is required but not installed. Aborting.${NC}"; exit 1; }
command_exists ansible-playbook || { echo -e "${YELLOW}Warning: ansible-playbook not found. Ansible deployment will be skipped.${NC}"; }
command_exists curl || { echo -e "${YELLOW}Warning: curl not found. Some features may not work properly.${NC}"; }

# Create scripts directory if it doesn't exist
mkdir -p scripts

# Check if Terraform files exist
if [ ! -d "terraform/frontend" ] || [ ! -f "terraform/frontend/main.tf" ]; then
  echo -e "${RED}Terraform frontend configuration not found. Make sure to run setup.sh first.${NC}"
  exit 1
fi

# Check for CloudFlare integration
USE_CLOUDFLARE=false
if [ -d "terraform/cloudflare" ] && [ -f "terraform/cloudflare/terraform.tfvars" ]; then
  USE_CLOUDFLARE=true
  echo -e "${YELLOW}CloudFlare configuration detected. Will update DNS records after deployment.${NC}"
fi

# Check for existing infrastructure
echo -e "\n${YELLOW}Checking for existing infrastructure...${NC}"
cd terraform/frontend || { echo -e "${RED}Could not access terraform/frontend directory.${NC}"; exit 1; }

# Initialize Terraform without applying anything
terraform init -reconfigure > /dev/null || { echo -e "${RED}Terraform initialization failed.${NC}"; exit 1; }

# Check if state exists and has resources
EXISTING_INFRASTRUCTURE=false
if [ -f ".terraform/terraform.tfstate" ] || [ -f "terraform.tfstate" ]; then
  # Check if there are actual resources in the state
  RESOURCE_COUNT=$(terraform state list 2>/dev/null | wc -l)
  if [ "$RESOURCE_COUNT" -gt 0 ]; then
    EXISTING_INFRASTRUCTURE=true
    echo -e "${YELLOW}Existing infrastructure detected.${NC}"
    
    # Get current frontend IP if available
    CURRENT_IP=$(terraform output -raw frontend_ip 2>/dev/null)
    if [ -n "$CURRENT_IP" ]; then
      echo -e "${YELLOW}Current frontend IP: ${CURRENT_IP}${NC}"
    fi
  fi
fi

# If existing infrastructure found and not forcing, ask what to do
if [ "$EXISTING_INFRASTRUCTURE" = true ] && [ "$FORCE" != true ]; then
  echo -e "\n${YELLOW}What would you like to do with the existing infrastructure?${NC}"
  echo -e "1. Continue with existing infrastructure (update configuration)"
  echo -e "2. Destroy existing infrastructure and create new"
  echo -e "3. Abort deployment"
  
  if [ "$SKIP_CONFIRMATION" = true ]; then
    CHOICE=1
  else
    read -p "Enter your choice [1-3]: " CHOICE
  fi
  
  case $CHOICE in
    1)
      echo -e "${GREEN}Continuing with existing infrastructure...${NC}"
      ;;
    2)
      echo -e "${YELLOW}Destroying existing infrastructure...${NC}"
      terraform destroy -auto-approve || { 
        echo -e "${RED}Failed to destroy infrastructure.${NC}"; 
        if ! confirm "Continue anyway?"; then
          echo -e "${YELLOW}Deployment aborted.${NC}";
          exit 1;
        fi
      }
      ;;
    3|*)
      echo -e "${YELLOW}Deployment aborted.${NC}"
      exit 0
      ;;
  esac
elif [ "$EXISTING_INFRASTRUCTURE" = true ] && [ "$FORCE" = true ]; then
  echo -e "${YELLOW}Force flag set. Destroying existing infrastructure...${NC}"
  terraform destroy -auto-approve || {
    echo -e "${RED}Failed to destroy infrastructure with force flag. This is unusual.${NC}"; 
    echo -e "${RED}Check for permission issues or locked state files.${NC}";
    exit 1;
  }
fi

# Prepare for deployment
echo -e "\n${YELLOW}Starting deployment process...${NC}"

# Step 1: Deploy frontend infrastructure
echo -e "\n${BLUE}Step 1: Deploying frontend infrastructure...${NC}"

echo -e "${YELLOW}Creating deployment plan...${NC}"
terraform plan -out=tfplan || { echo -e "${RED}Terraform plan failed.${NC}"; exit 1; }

# Check if there are any changes to apply
PLAN_CHANGES=$(terraform show -no-color tfplan | grep -E '^\s*[~+-]' | wc -l)
if [ "$PLAN_CHANGES" -eq 0 ]; then
  echo -e "${GREEN}No changes to apply. Infrastructure is up to date.${NC}"
else
  echo -e "${YELLOW}Applying infrastructure changes...${NC}"
  terraform apply tfplan || { echo -e "${RED}Terraform apply failed.${NC}"; exit 1; }
fi

# Get the frontend IP
FRONTEND_IP=$(terraform output -raw frontend_ip 2>/dev/null)
if [ -z "$FRONTEND_IP" ]; then
  echo -e "${RED}Could not get frontend IP from Terraform output.${NC}"
  exit 1
fi

echo -e "${GREEN}Frontend infrastructure deployed successfully with IP: ${FRONTEND_IP}${NC}"

# Return to project root
cd ../..

# Step 2: Update Ansible inventory
echo -e "\n${BLUE}Step 2: Updating Ansible inventory...${NC}"
mkdir -p ansible/inventories/production
INVENTORY_FILE="ansible/inventories/production/hosts.yml"

# Check if inventory file exists and has the same IP
INVENTORY_EXISTS=false
INVENTORY_NEEDS_UPDATE=true
if [ -f "$INVENTORY_FILE" ]; then
  INVENTORY_EXISTS=true
  CURRENT_INVENTORY_IP=$(grep ansible_host "$INVENTORY_FILE" | head -1 | awk -F'"' '{print $2}')
  
  if [ "$CURRENT_INVENTORY_IP" = "$FRONTEND_IP" ]; then
    echo -e "${GREEN}Ansible inventory already up to date.${NC}"
    INVENTORY_NEEDS_UPDATE=false
  fi
fi

if [ "$INVENTORY_NEEDS_UPDATE" = true ]; then
  cat > "$INVENTORY_FILE" << EOF
---
all:
  children:
    frontend:
      hosts:
        metrics-frontend:
          ansible_host: "${FRONTEND_IP}"
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

  echo -e "${GREEN}Ansible inventory updated successfully.${NC}"
fi

# Step 3: Update CloudFlare DNS (if configured)
if [ "$USE_CLOUDFLARE" = true ]; then
  echo -e "\n${BLUE}Step 3: Updating CloudFlare DNS records...${NC}"
  
  # Check if we need to update CloudFlare
  CF_NEEDS_UPDATE=true
  if [ -f "terraform/cloudflare/terraform.tfstate" ]; then
    # Get current IP from CloudFlare config
    CF_CURRENT_IP=$(grep -A1 "frontend_ip" terraform/cloudflare/terraform.tfvars | tail -1 | awk -F'"' '{print $2}')
    if [ "$CF_CURRENT_IP" = "$FRONTEND_IP" ] && [ "$CF_CURRENT_IP" != "FRONTEND_IP_PLACEHOLDER" ]; then
      echo -e "${GREEN}CloudFlare DNS records already up to date.${NC}"
      CF_NEEDS_UPDATE=false
    fi
  fi
  
# Wait for VM first boot and updates.
# Countdown Timer Function
countdown_timer() {
    local DURATION=${1:-180}
    local TOP_MESSAGE=${2:-"Please wait..."}
    local BOTTOM_MESSAGE=${3:-"Complete!"}

    # Terminal control sequences
    local CURSOR_UP="\033[13A"  # Move cursor up 13 lines (including blank lines and message)
    local RESET="\033[0m"
    local RED="\033[31m"
    local GREEN="\033[32m"
    local YELLOW="\033[33m"
    local BLUE="\033[34m"

    # Temporary trap to handle Ctrl+C within the timer
    local old_trap
    old_trap=$(trap -p SIGINT)
    trap 'echo -e "\n\n${RED}Timer interrupted!${RESET}\n"; eval "${old_trap#trap -- }"; return 1' SIGINT

    # Define ASCII art for digits with explicit newlines
    declare -a DIGITS
    # We're using heredocs to preserve exact formatting of the ASCII art
    read -r -d '' DIGITS[0] << 'EOF'
--______--
-/------\-
/$$$$$$--|
$$$--\$$-|
$$$$--$$-|
$$-$$-$$-|
$$-\$$$$-|
$$---$$$/-
-$$$$$$/--
----------
EOF

    read -r -d '' DIGITS[1] << 'EOF'
---__-----
-_/--|----
/-$$-|----
$$$$-|----
--$$-|----
--$$-|----
-_$$-|_---
/-$$---|--
$$$$$$/---
----------
EOF

    read -r -d '' DIGITS[2] << 'EOF'
--______--
-/------\-
/$$$$$$--|
$$____$$-|
-/----$$/-
/$$$$$$/--
$$-|_____-
$$-------|
$$$$$$$$/-
----------
EOF

    read -r -d '' DIGITS[3] << 'EOF'
--______--
-/------\-
/$$$$$$--|
$$-___$$-|
--/---$$<-
-_$$$$$--|
/--\__$$-|
$$----$$/-
-$$$$$$/--
----------
EOF

    read -r -d '' DIGITS[4] << 'EOF'
-__----__-
/--|--/--|
$$-|--$$-|
$$-|__$$-|
$$----$$-|
$$$$$$$$-|
------$$-|
------$$-|
------$$/-
----------
EOF

    read -r -d '' DIGITS[5] << 'EOF'
-_______--
/-------|-
$$$$$$$/--
$$-|____--
$$------\-
$$$$$$$--|
/--\__$$-|
$$----$$/-
-$$$$$$/--
----------
EOF

    read -r -d '' DIGITS[6] << 'EOF'
--______--
-/------\-
/$$$$$$--|
$$-\__$$/-
$$------\-
$$$$$$$--|
$$-\__$$-|
$$----$$/-
-$$$$$$/--
----------
EOF

    read -r -d '' DIGITS[7] << 'EOF'
-________-
/--------|
$$$$$$$$/-
----/$$/--
---/$$/---
--/$$/----
-/$$/-----
/$$/------
$$/-------
----------
EOF

    read -r -d '' DIGITS[8] << 'EOF'
--______--
-/------\-
/$$$$$$--|
$$-\__$$-|
$$----$$<-
-$$$$$$--|
$$-\__$$-|
$$----$$/-
-$$$$$$/--
----------
EOF

    read -r -d '' DIGITS[9] << 'EOF'
--______--
-/------\-
/$$$$$$--|
$$-\__$$-|
$$----$$-|
-$$$$$$$-|
/--\__$$-|
$$----$$/-
-$$$$$$/--
----------
EOF

    # Define colon separator 
    read -r -d '' COLON << 'EOF'
------
------
--__--
-/--|-
-$$/--
--__--
-/--|-
-$$/--
------
------
EOF

    # Function to display a row of the time (HH:MM:SS)
    display_time_row() {
        local hours=$1
        local minutes=$2
        local seconds=$3
        local row=$4
        local color=$5

        local h1=$((hours / 10))
        local h2=$((hours % 10))
        local m1=$((minutes / 10))
        local m2=$((minutes % 10))
        local s1=$((seconds / 10))
        local s2=$((seconds % 10))

        local h1_row=$(printf "%s\n" "${DIGITS[$h1]}" | sed -n "${row}p")
        local h2_row=$(printf "%s\n" "${DIGITS[$h2]}" | sed -n "${row}p")
        local m1_row=$(printf "%s\n" "${DIGITS[$m1]}" | sed -n "${row}p")
        local m2_row=$(printf "%s\n" "${DIGITS[$m2]}" | sed -n "${row}p")
        local s1_row=$(printf "%s\n" "${DIGITS[$s1]}" | sed -n "${row}p")
        local s2_row=$(printf "%s\n" "${DIGITS[$s2]}" | sed -n "${row}p")
        local colon_row=$(printf "%s\n" "$COLON" | sed -n "${row}p")

        echo -e "$color$h1_row$h2_row$colon_row$m1_row$m2_row$colon_row$s1_row$s2_row$RESET"
    }

    # Function to display the full time
    display_time() {
        local remaining=$1
        
        # Calculate hours, minutes, seconds
        local hours=$((remaining / 3600))
        local minutes=$(((remaining % 3600) / 60))
        local seconds=$((remaining % 60))
        
        # Choose color based on remaining time
        local color
        if [ $remaining -gt 60 ]; then
            color=$GREEN
        elif [ $remaining -gt 30 ]; then
            color=$BLUE
        elif [ $remaining -gt 10 ]; then
            color=$YELLOW
        else
            color=$RED
        fi
        
        # Display top message
        echo -e "\n$color$TOP_MESSAGE$RESET"
        
        # Display each row of the time
        for row in {1..7}; do
            display_time_row $hours $minutes $seconds $row "$color"
        done
    }

    # Main countdown loop
    local remaining=$DURATION
    display_time $remaining

    while [ $remaining -gt 0 ]; do
        sleep 1
        remaining=$((remaining - 1))
        
        # Move cursor up to redraw the time display
        echo -e "$CURSOR_UP"
        display_time $remaining
    done

    # Display completion message
    echo -e "\n$RED$BOTTOM_MESSAGE$RESET\n"
    
    # Optional beep for time's up
    echo -e "\a"
    
    # Restore the original trap
    if [ -n "$old_trap" ]; then
        eval "$old_trap"
    else
        trap - SIGINT
    fi
    
    return 0
}

countdown_timer 180 "${YELLOW}Please wait while VM boots for the first time...${NC}" "${YELLOW}VM boot process complete.${NC}"

# Display completion message
echo -e "${YELLOW}Rebooting the VM to ensure clean state...${NC}"

if ssh -o ConnectTimeout=10 -o BatchMode=yes -o StrictHostKeyChecking=no -i "${SSH_KEY_PATH}" root@$FRONTEND_IP "reboot" &>/dev/null; then
  echo -e "${GREEN}Reboot command sent. Waiting for VM to come back online...${NC}"
  sleep 30  # Initial wait for VM to go down
  
  # Wait for VM to come back online
  REBOOT_RETRIES=10
  for i in $(seq 1 $REBOOT_RETRIES); do
    if ssh -o ConnectTimeout=10 -o BatchMode=yes -o StrictHostKeyChecking=no -i "${SSH_KEY_PATH}" root@$FRONTEND_IP "echo VM is back online" &>/dev/null; then
      echo -e "${GREEN}VM is back online after reboot.${NC}"
      sleep 10  # Give services a moment to fully start
      break
    else
      echo -e "${YELLOW}Waiting for VM to come back online (attempt $i of $REBOOT_RETRIES)...${NC}"
      sleep 15
    fi
    
    if [ $i -eq $REBOOT_RETRIES ]; then
      echo -e "${RED}VM did not come back online after reboot. Continuing anyway...${NC}"
    fi
  done
else
  echo -e "${RED}Failed to send reboot command to VM. Continuing anyway...${NC}"
fi

echo -e "${YELLOW}Verifying VM IP address...${NC}"
if ! ping -c 1 -W 5 "$FRONTEND_IP" &>/dev/null; then
  echo -e "${RED}Warning: Cannot ping $FRONTEND_IP. The VM may have a different IP.${NC}"
  read -p "Please enter the correct VM IP address (or press Enter to continue with $FRONTEND_IP): " CORRECTED_IP
  if [ -n "$CORRECTED_IP" ]; then
    FRONTEND_IP="$CORRECTED_IP"
    echo -e "${GREEN}Using corrected IP: $FRONTEND_IP${NC}"
  fi
fi

  # Check CF_NEEDS_UPDATE variable exists
  if [ -z ${CF_NEEDS_UPDATE+x} ]; then
    CF_NEEDS_UPDATE=true
  fi
  
  if [ "$CF_NEEDS_UPDATE" = true ]; then
    # Check if update_cloudflare.sh exists, create it if not
    if [ ! -f "scripts/update_cloudflare.sh" ]; then
      echo -e "${YELLOW}CloudFlare update script not found. Creating it...${NC}"
      cat > "scripts/update_cloudflare.sh" << 'EOFSCRIPT'
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

# Check if CloudFlare configuration exists
if [ ! -d "terraform/cloudflare" ] || [ ! -f "terraform/cloudflare/terraform.tfvars" ]; then
  echo -e "${RED}Error: CloudFlare configuration not found.${NC}"
  echo -e "${YELLOW}Make sure you've run setup.sh with CloudFlare configuration enabled.${NC}"
  exit 1
fi

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

echo -e "\n${YELLOW}Note: DNS propagation may take up to 5 minutes with CloudFlare.${NC}"
echo -e "${YELLOW}You can verify the DNS records in the CloudFlare dashboard.${NC}"
EOFSCRIPT
      chmod +x scripts/update_cloudflare.sh
      echo -e "${GREEN}CloudFlare update script created.${NC}"
    fi

    chmod +x scripts/update_cloudflare.sh
    ./scripts/update_cloudflare.sh "$FRONTEND_IP" || { 
      echo -e "${RED}CloudFlare DNS update failed.${NC}"; 
      echo -e "${YELLOW}You can try running it manually:${NC}";
      echo -e "   ./scripts/update_cloudflare.sh $FRONTEND_IP";
      # Continue despite error
    }
  else
    echo -e "${RED}CloudFlare update script not found.${NC}"
    echo -e "${YELLOW}You can manually update the CloudFlare DNS records to point to: ${FRONTEND_IP}${NC}"
  fi
fi

# Step 4: Wait for DNS propagation if using CloudFlare
if [ "$USE_CLOUDFLARE" = true ] && [ "$CF_NEEDS_UPDATE" = true ]; then
  echo -e "\n${BLUE}Step 4: Waiting for DNS propagation...${NC}"
  echo -e "${YELLOW}This may take a few minutes. Press Enter to continue, or wait 60 seconds.${NC}"
  
  if [ "$SKIP_CONFIRMATION" = true ]; then
    echo -e "${YELLOW}Waiting 60 seconds for DNS propagation...${NC}"
    sleep 60
  else
    read -t 60 -p ""
  fi
fi

# Step 5: Deploy with Ansible (if Ansible playbooks exist)
echo -e "\n${BLUE}Step 5: Deploying configuration with Ansible...${NC}"
if [ -f "ansible/playbooks/frontend-setup.yml" ]; then
  echo -e "${YELLOW}Running Ansible playbook for frontend setup...${NC}"
  
  # Check if we're using a reserved IP
  USING_RESERVED_IP=false
  if grep -q "use_reserved_ip = true" terraform/frontend/terraform.tfvars 2>/dev/null; then
    USING_RESERVED_IP=true
    echo -e "${YELLOW}Using a reserved IP address. The VM may need extra time to initialize.${NC}"
    
    # Add additional wait time for VM with reserved IP to fully initialize
    if [ "$EXISTING_INFRASTRUCTURE" = false ]; then
      echo -e "${YELLOW}Waiting 60 seconds for initial VM configuration...${NC}"
      sleep 60
    fi
  fi

  # Enhanced SSH connectivity check
  echo -e "${YELLOW}Testing SSH connectivity to frontend...${NC}"
  SSH_CONNECTED=false
  SSH_RETRIES=10
  SSH_TIMEOUT=20

  # Additional retries for reserved IP
  if [ "$USING_RESERVED_IP" = true ]; then
    SSH_RETRIES=15  # More retries for reserved IP case
  fi

  for i in $(seq 1 $SSH_RETRIES); do
    if ssh -o ConnectTimeout=$SSH_TIMEOUT -o BatchMode=yes -o StrictHostKeyChecking=no -i "${SSH_KEY_PATH}" root@$FRONTEND_IP "echo SSH connection successful" &>/dev/null; then
      SSH_CONNECTED=true
      break
    else
      echo -e "${YELLOW}SSH connection attempt $i of $SSH_RETRIES failed.${NC}"
      
      # If using reserved IP and this is the halfway point, try to reboot via API
      if [ "$USING_RESERVED_IP" = true ] && [ $i -eq 7 ]; then
        echo -e "${YELLOW}Attempting to reboot the VM via Vultr API...${NC}"
        # Fetch the API key from terraform.tfvars
        VULTR_API_KEY=$(grep vultr_api_key terraform/frontend/terraform.tfvars | cut -d'"' -f2)
        INSTANCE_ID=$(cd terraform/frontend && terraform output -raw instance_id 2>/dev/null)
        
        if [ -n "$VULTR_API_KEY" ] && [ -n "$INSTANCE_ID" ]; then
          curl -s -X POST "https://api.vultr.com/v2/instances/${INSTANCE_ID}/reboot" \
            -H "Authorization: Bearer ${VULTR_API_KEY}" \
            -H "Content-Type: application/json"
          echo -e "${YELLOW}VM reboot requested. Waiting 60 seconds...${NC}"
          sleep 60  # Wait for reboot to complete
        else
          echo -e "${RED}Could not find Vultr API key or instance ID for reboot.${NC}"
        fi
      fi
      
      echo -e "${YELLOW}Waiting 15 seconds before next attempt...${NC}"
      sleep 15
    fi
  done
    if [ "$SSH_CONNECTED" = true ]; then
    timeout 600 ansible-playbook -i ansible/inventories/production ansible/playbooks/frontend-setup.yml --private-key="${SSH_KEY_PATH}" || {
      echo -e "${RED}Ansible deployment failed.${NC}";
      echo -e "${YELLOW}You may need to wait a bit longer for the server to be ready.${NC}";
      echo -e "${YELLOW}You can try running the playbook manually:${NC}";
      echo -e "   ansible-playbook -i ansible/inventories/production ansible/playbooks/frontend-setup.yml";
    }
  else
    echo -e "${RED}SSH connection to frontend failed after $SSH_RETRIES attempts. Server may not be ready yet.${NC}"
    echo -e "${YELLOW}Wait a few minutes and then run:${NC}"
    echo -e "   ansible-playbook -i ansible/inventories/production ansible/playbooks/frontend-setup.yml"
  fi
else
  echo -e "${YELLOW}Ansible playbooks not found. Skipping Ansible deployment.${NC}"
  echo -e "${YELLOW}You will need to set up the services manually or create Ansible playbooks.${NC}"
fi

# Final status
echo -e "\n${GREEN}Deployment process completed!${NC}"
echo -e "${YELLOW}Frontend server: ${FRONTEND_IP}${NC}"

if [ "$USE_CLOUDFLARE" = true ]; then
  # Try to get domain info from CloudFlare config
  DOMAIN_NAME=$(grep "domain_name" terraform/cloudflare/terraform.tfvars | cut -d'"' -f2 || echo "your-domain.com")
  SUBDOMAIN_PREFIX=$(grep "subdomain_prefix" terraform/cloudflare/terraform.tfvars | cut -d'"' -f2 || echo "metrics")
  
  echo -e "${YELLOW}Monitoring URLs:${NC}"
  echo -e "  - Main: https://${SUBDOMAIN_PREFIX}.${DOMAIN_NAME}"
  echo -e "  - Prometheus: https://prometheus.${SUBDOMAIN_PREFIX}.${DOMAIN_NAME}"
  echo -e "  - Grafana: https://grafana.${SUBDOMAIN_PREFIX}.${DOMAIN_NAME}"
  echo -e "  - Alertmanager: https://alertmanager.${SUBDOMAIN_PREFIX}.${DOMAIN_NAME}"
fi

echo -e "\n${BLUE}Next Steps:${NC}"
echo -e "1. If not using Ansible, manually set up services on the frontend server"
echo -e "2. Set up the backend monitoring infrastructure on your local network"
echo -e "3. Configure WireGuard VPN between frontend and backend"
echo -e "4. Deploy node exporters to your target systems"
echo -e "\n${BLUE}Happy monitoring!${NC}"