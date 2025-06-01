# Setup Instructions

This document provides step-by-step instructions for setting up the monitoring infrastructure.

## Prerequisites

Before starting the setup, ensure you have the following:

- A VM or VPS with a public IP address for the frontend component
- Access to your personal network for deploying backend components
- The following tools installed on your development machine:
  - Git
  - Terraform
  - Ansible
  - Docker and Docker Compose

## Step 1: Clone the Repository

```bash
git clone https://github.com/ait88/metrics.git
cd metrics
```

## Step 2: Configure Environment Variables

Create a `.env` file for local development:

```bash
cp .env.example .env
```

Edit the `.env` file to set the required environment variables for your setup.

## Step 3: Deploy Frontend Component

The frontend component will be deployed on a VM with a public IP address.

```bash
# Navigate to the terraform directory
cd terraform/frontend

# Initialize Terraform
terraform init

# Create a terraform.tfvars file with your specific variables
cp terraform.tfvars.example terraform.tfvars

# Edit the terraform.tfvars file
nano terraform.tfvars

# Apply the Terraform configuration
terraform apply
```

This will provision the necessary infrastructure for the frontend component.

## Step 4: Configure WireGuard VPN

After deploying the frontend component, you need to configure the WireGuard VPN for secure communication with the backend.

```bash
# Navigate to the ansible directory
cd ../../ansible

# Run the WireGuard setup playbook
ansible-playbook -i inventories/production playbooks/wireguard-setup.yml
```

## Step 5: Deploy Backend Components

The backend components will be deployed on your personal network.

```bash
# Navigate to the terraform directory
cd ../terraform/backend

# Initialize Terraform
terraform init

# Create a terraform.tfvars file with your specific variables
cp terraform.tfvars.example terraform.tfvars

# Edit the terraform.tfvars file
nano terraform.tfvars

# Apply the Terraform configuration
terraform apply
```

## Step 6: Configure Backend Services

After deploying the backend infrastructure, configure the services using Ansible:

```bash
# Navigate to the ansible directory
cd ../../ansible

# Run the backend setup playbook
ansible-playbook -i inventories/production playbooks/backend-setup.yml
```

## Step 7: Deploy Monitoring Exporters

Deploy the necessary exporters on your target systems:

```bash
# For Linux systems
ansible-playbook -i inventories/production playbooks/node-exporter.yml

# For Docker hosts
ansible-playbook -i inventories/production playbooks/cadvisor.yml

# For hypervisors
ansible-playbook -i inventories/production playbooks/hypervisor-exporters.yml

# For Windows systems (stretch goal)
ansible-playbook -i inventories/production playbooks/windows-exporter.yml
```

## Step 8: Configure Grafana Dashboards

Import the predefined dashboards into Grafana:

1. Access the Grafana UI (the URL will be provided in the outputs of the backend deployment)
2. Log in with the default credentials (admin/admin) and change the password
3. Navigate to Dashboards -> Import
4. Import the JSON files from the `dashboards` directory

## Backend Infrastructure Setup

### Prerequisites for Backend

The backend components require:
- A VM or physical server on your private network
- Ubuntu 22.04 or similar Linux distribution
- Docker and Docker Compose installed
- At least 2GB RAM and 20GB storage
- Access to the WireGuard VPN network (10.8.0.0/24)

### Manual Backend Setup Steps

Since the backend infrastructure varies by environment, manual setup is required:

1. **Prepare the Backend Server**
   ```bash
   # Install Docker
   curl -fsSL https://get.docker.com | sh
   
   # Install Docker Compose
   sudo curl -L "https://github.com/docker/compose/releases/download/v2.24.6/docker-compose-linux-x86_64" \
     -o /usr/local/bin/docker-compose
   sudo chmod +x /usr/local/bin/docker-compose
   
   # Install WireGuard
   sudo apt update
   sudo apt install -y wireguard
   ```

2. **Configure WireGuard**
   ```bash
   # Generate keys
   wg genkey | sudo tee /etc/wireguard/private.key
   sudo chmod 600 /etc/wireguard/private.key
   cat /etc/wireguard/private.key | wg pubkey | sudo tee /etc/wireguard/public.key
   
   # Create configuration
   sudo nano /etc/wireguard/wg0.conf
   ```
   
   Use this configuration:
   ```ini
   [Interface]
   Address = 10.8.0.2/24
   PrivateKey = <your-private-key>
   ListenPort = 51820
   
   [Peer]
   PublicKey = <frontend-public-key>
   AllowedIPs = 10.8.0.1/32
   Endpoint = <frontend-public-ip>:51820
   PersistentKeepalive = 25
   ```

3. **Deploy Backend Services**
   ```bash
   # Create directory structure
   sudo mkdir -p /opt/metrics/docker/{prometheus,alertmanager,loki/wal,grafana}
   cd /opt/metrics/docker
   
   # Copy docker-compose.yml from docker/backend/
   # Copy configuration files
   
   # Set Loki permissions
   sudo chown -R 10001:10001 ./loki
   
   # Start services
   docker-compose up -d
   ```

### Loki Directory Permissions Fix

Loki requires specific permissions for its data directories:

```bash
# Create required directories
mkdir -p ./loki/{wal,chunks,boltdb-shipper-active,boltdb-shipper-cache,compactor}

# Set ownership (Loki runs as UID 10001)
sudo chown -R 10001:10001 ./loki

# If Loki fails to start, check logs:
docker logs <loki-container-name>
```

### Network Configuration Requirements

#### Docker Networks
Ensure services can communicate:

1. **Frontend Requirements**:
   - Traefik must be on both `traefik-net` AND `prometheus-net`
   - All services that need external access must be on `traefik-net`
   - All monitoring services must be on `prometheus-net`

2. **Backend Requirements**:
   - All services on a single `monitoring` network
   - Ports exposed on all interfaces (0.0.0.0) or WireGuard interface (10.8.0.2)

#### Firewall Rules
```bash
# Frontend (public)
sudo ufw allow 80/tcp    # HTTP
sudo ufw allow 443/tcp   # HTTPS
sudo ufw allow 51820/udp # WireGuard
sudo ufw allow from 10.8.0.0/24 to any port 9090  # Prometheus for backend

# Backend (private)
# Only allow from WireGuard network
sudo ufw allow from 10.8.0.0/24 to any port 9090  # Prometheus
sudo ufw allow from 10.8.0.0/24 to any port 3000  # Grafana
sudo ufw allow from 10.8.0.0/24 to any port 9093  # Alertmanager
sudo ufw allow from 10.8.0.0/24 to any port 3100  # Loki
```

## Step 9: Set Up Alerting

Configure alerting rules and notification channels:

```bash
# Navigate to the ansible directory
cd ../../ansible

# Run the alerting setup playbook
ansible-playbook -i inventories/production playbooks/alerting-setup.yml
```

## Troubleshooting

If you encounter issues during the setup process, check the following:

1. Ensure all required ports are open in your firewall
2. Verify that the WireGuard VPN connection is active
3. Check the logs of the services for any error messages:
   ```bash
   docker logs prometheus
   docker logs grafana
   docker logs alertmanager
   docker logs loki
   ```
4. Ensure that the exporters are running and accessible from the Prometheus server

## Next Steps

After completing the basic setup, you can:

1. Add more target systems to monitor
2. Customize the dashboards according to your needs
3. Set up additional alerting rules
4. Implement the dependency mapping using NetBox
