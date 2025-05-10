# Metrics - Monitoring Infrastructure

A comprehensive monitoring infrastructure using Prometheus, Grafana, and other open-source tools to monitor various systems across multiple environments.

## Project Overview

This project implements a scalable, hierarchical monitoring solution with the following features:

- Relationship/dependency mapping
- Hierarchical visibility (DNS → Cloud → Edge → Internal)
- Pure open-source solution
- Exportable metrics for custom dashboards/portals
- Configuration as code (Git-based)

## Infrastructure Details

### Cloud Provider

This project uses Vultr as the cloud provider for the frontend component. The frontend infrastructure is defined in Terraform configurations under `terraform/frontend/`. 

Key components of the frontend infrastructure:
- Vultr instance (1 CPU, 1 GB RAM by default)
- Firewall rules for required ports (SSH, HTTP, HTTPS, WireGuard)
- Reserved IP address for stable connectivity

### Security

The monitoring infrastructure implements several security measures:
- WireGuard VPN for secure communication between frontend and backend
- Firewall rules to restrict access to necessary ports
- HTTPS with Let's Encrypt certificates for all web services
- Basic authentication for web interfaces
- Principle of least privilege for service accounts

### Communication Flow

1. Remote systems connect to the frontend component via HTTPS
2. The frontend component securely forwards data to the backend via WireGuard VPN
3. Backend components process, store, and visualize the data
4. Alerts are generated and sent to notification channels as needed

## CI/CD Workflow

This project includes a GitHub Actions workflow for automated deployment:

- **Validation**: Checks Terraform formatting and validates configurations
- **Frontend Deployment**: Provisions the Vultr infrastructure
- **Backend Deployment**: Sets up the backend components

The workflow can be triggered manually through the GitHub Actions interface.

## Project Organization

```
metrics/
├── docs/                       # Documentation
│   ├── architecture.md         # Architecture diagrams and explanations
│   ├── setup.md                # Setup instructions
│   └── git_workflow.md         # Git workflow guidelines
├── terraform/                  # Infrastructure as code
│   ├── frontend/               # Vultr infrastructure for frontend
│   └── backend/                # Backend infrastructure
├── ansible/                    # Configuration management
│   ├── playbooks/              # Deployment playbooks
│   ├── roles/                  # Reusable roles
│   ├── inventories/            # Environment-specific inventories
│   └── vars/                   # Variables and secrets
├── docker/                     # Container configurations
│   ├── frontend/               # Frontend Docker services
│   └── backend/                # Backend Docker services
├── exporters/                  # Exporter configurations
├── dashboards/                 # Grafana dashboard JSON files
├── .github/workflows/          # CI/CD workflows
├── .gitignore                  # Git ignore patterns
└── setup.sh                    # Automated setup script
```

## Monitoring Architecture

The monitoring infrastructure follows a distributed architecture:

- **Frontend Component**: Public-facing proxy that receives metrics from remote nodes
- **Backend Components**: Core monitoring stack (Prometheus, Grafana, Alertmanager, Loki)
- **Secure Communication**: Wireguard VPN for secure data transmission

Systems monitored:
- Linux VMs and servers
- Hypervisors (Proxmox and XCP-ng)
- Docker containers/swarms
- Ubuntu-based kiosks
- Windows servers and workstations (stretch goal)

## Getting Started

### Prerequisites

- Docker and Docker Compose
- Terraform
- Ansible
- Git
- Vultr account with API key

### Automated Setup

We provide a setup script that helps you configure the necessary files and directories:

```bash
# Make the setup script executable
chmod +x setup.sh

# Run the setup script
./setup.sh
```

The setup script will:
1. Create the necessary directory structure
2. Prompt for configuration values (Vultr API key, SSH key name, domain, etc.)
3. Generate configuration files from these inputs
4. Set up terraform.tfvars and other required files

### Manual Setup

If you prefer to set up the project manually:

1. Clone the repository:
   ```bash
   git clone https://github.com/ait88/metrics.git
   cd metrics
   ```

2. Create terraform.tfvars from the example:
   ```bash
   cp terraform/frontend/terraform.tfvars.example terraform/frontend/terraform.tfvars
   # Edit the terraform.tfvars file with your Vultr credentials
   ```

3. Deploy the frontend infrastructure:
   ```bash
   cd terraform/frontend
   terraform init
   terraform plan -out=tfplan
   terraform apply tfplan
   ```

Detailed setup instructions can be found in [docs/setup.md](docs/setup.md).

### Git Workflow

For guidelines on working with this Git repository, including best practices and handling sensitive data, see [docs/git_workflow.md](docs/git_workflow.md).

## Implementation Phases

### Phase 1: Core Infrastructure
- [x] Initialize repository structure
- [x] Create Terraform configuration for frontend
- [x] Set up automated deployment workflow
- [x] Implement frontend provisioning
- [ ] Configure WireGuard VPN
- [ ] Set up Docker services on frontend

### Phase 2: Backend Setup
- [ ] Create backend infrastructure
- [ ] Deploy Prometheus, Grafana, Alertmanager, and Loki
- [ ] Configure persistent storage
- [ ] Set up authentication and security
- [ ] Create initial dashboards

### Phase 3: Monitoring Agents
- [ ] Deploy node_exporter to Linux systems
- [ ] Set up Docker monitoring with cAdvisor
- [ ] Configure hypervisor monitoring
- [ ] Set up kiosk monitoring
- [ ] Implement Windows monitoring (stretch goal)

### Phase 4: Advanced Features
- [ ] Deploy NetBox for infrastructure modeling
- [ ] Create service dependency configurations
- [ ] Build relationship visualization dashboards
- [ ] Implement topology views
- [ ] Set up advanced alerting rules

## License

[MIT License](LICENSE)
