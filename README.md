# Metrics - Monitoring Infrastructure

A comprehensive monitoring infrastructure using Prometheus, Grafana, and other open-source tools to monitor various systems across multiple environments.

## Features

- **Hierarchical Monitoring**: DNS → Cloud → Edge → Internal components
- **Security-Focused**: Encrypted communications, authentication, and firewall rules
- **Distributed Architecture**: Frontend and backend components for secure collection
- **CloudFlare Integration**: Automated DNS management and added security layer
- **Automated SSH Setup**: Dedicated SSH key generation for secure, simplified access
- **Configuration as Code**: Complete infrastructure defined in Terraform and Ansible
- **Containerized Stack**: Easy deployment and updates with Docker
- **Comprehensive Monitoring**: Various exporters for different system types

## Architecture Overview

The monitoring infrastructure follows a distributed architecture:

- **Frontend Component**: Public-facing proxy that receives metrics from remote nodes
- **Backend Components**: Core monitoring stack (Prometheus, Grafana, Alertmanager, Loki)
- **Secure Communication**: WireGuard VPN for secure data transmission between frontend and backend

```
┌─────────────────┐            ┌─────────────────────────────────────────┐
│                 │            │                                         │
│  Remote Systems ├────────────►  Frontend Component (Public IP)         │
│                 │            │                                         │
└─────────────────┘            └───────────────┬─────────────────────────┘
                                               │
                                               │ WireGuard VPN
                                               │
                                               ▼
                               ┌─────────────────────────────────────────┐
                               │                                         │
                               │  Backend Components (Private Network)   │
                               │                                         │
                               └─────────────────────────────────────────┘
```

Systems monitored:
- Linux VMs and servers
- Hypervisors (Proxmox and XCP-ng)
- Docker containers/swarms
- Ubuntu-based kiosks
- Windows servers and workstations (stretch goal)

## Getting Started

### Prerequisites

- Git
- Docker and Docker Compose
- Terraform
- Ansible
- Vultr account with API key
- CloudFlare account (optional, for DNS management)

### Installation

#### Option 1: Fresh Installation (Recommended)

1. **Clone the repository**
   ```bash
   git clone https://github.com/ait88/metrics.git
   cd metrics
   ```

2. **Run the installation script**
   ```bash
   chmod +x install.sh
   ./install.sh
   ```

   The installation script will:
   - Check and install missing dependencies (with your permission)
   - Generate a dedicated SSH key for the project
   - Guide you through adding the key to Vultr
   - Set up the necessary configuration files
   - Deploy the frontend infrastructure
   - Configure CloudFlare DNS (if enabled)
   - Deploy the monitoring services

#### Option 2: Manual Installation

If you prefer more control over the installation process:

1. **Clone the repository**
   ```bash
   git clone https://github.com/ait88/metrics.git
   cd metrics
   ```

2. **Generate an SSH key**
   ```bash
   mkdir -p ~/.ssh/metrics
   ssh-keygen -t rsa -b 4096 -f ~/.ssh/metrics/id_rsa -N "" -C "metrics_deployment"
   ```

3. **Add the SSH key to Vultr**
   - Copy the public key: `cat ~/.ssh/metrics/id_rsa.pub`
   - Add it to your Vultr account under Account → SSH Keys

4. **Run the setup script**
   ```bash
   chmod +x setup.sh
   SSH_KEY_PATH=~/.ssh/metrics/id_rsa ./setup.sh
   ```

5. **Deploy the infrastructure**
   ```bash
   chmod +x scripts/deploy.sh
   SSH_KEY_PATH=~/.ssh/metrics/id_rsa ./scripts/deploy.sh
   ```

### Quick Start (For Existing Clones)

If you already have the repository cloned and just need to set up a new environment:

```bash
# Ensure you're in the repository root
cd /path/to/metrics

# Run the installation script
./install.sh
```

## Infrastructure Details

### Cloud Provider

This project uses Vultr as the cloud provider for the frontend component. The frontend infrastructure is defined in Terraform configurations under `terraform/frontend/`. 

Key components of the frontend infrastructure:
- Vultr instance (1 CPU, 1 GB RAM by default)
- Firewall rules for required ports (SSH, HTTP, HTTPS, WireGuard)
- Optional reserved IP address for stable connectivity

### Security

The monitoring infrastructure implements several security measures:
- Dedicated SSH keys for secure, automated access
- WireGuard VPN for secure communication between frontend and backend
- Firewall rules to restrict access to necessary ports
- HTTPS with Let's Encrypt certificates for all web services
- Basic authentication for web interfaces
- CloudFlare proxy for added DDoS protection and WAF capabilities
- Principle of least privilege for service accounts

### Communication Flow

1. Remote systems connect to the frontend component via HTTPS
2. The frontend component securely forwards data to the backend via WireGuard VPN
3. Backend components process, store, and visualize the data
4. Alerts are generated and sent to notification channels as needed

## CloudFlare Integration

This project includes automated CloudFlare DNS management:

- **DNS Automation**: Automatically create and update DNS records
- **Security Layer**: Use CloudFlare proxy for protection against DDoS and common attacks
- **Performance**: Configure caching for static assets
- **Easy Setup**: Integrated with the main deployment workflow

CloudFlare DNS records created:
- Base monitoring URL: `metrics.yourdomain.com`
- Service-specific records:
  - `prometheus.metrics.yourdomain.com`
  - `grafana.metrics.yourdomain.com`
  - `push.metrics.yourdomain.com`
  - `alertmanager.metrics.yourdomain.com`
- Non-proxied record for WireGuard: `wg.metrics.yourdomain.com`

## CI/CD Workflow

This project includes a GitHub Actions workflow for automated deployment:

- **Validation**: Checks Terraform formatting and validates configurations
- **Frontend Deployment**: Provisions the Vultr infrastructure
- **Backend Deployment**: Sets up the backend components

The workflow can be triggered manually through the GitHub Actions interface.

## Troubleshooting

### Common Issues

1. **Installation script fails with "directory not empty"**
   - Make sure you're running the script in an empty directory or a cloned repository
   - If you downloaded just the install.sh file, let it clone the repository for you

2. **SSH key issues**
   - Ensure the SSH key is added to Vultr before running the deployment
   - Check that the SSH key path is correct in your environment

3. **Terraform state issues**
   - If you have existing infrastructure, the script will ask how to proceed
   - You can force a fresh deployment with: `./scripts/deploy.sh --force`

4. **DNS propagation delays**
   - CloudFlare DNS updates usually propagate within 5 minutes
   - You can verify DNS records in the CloudFlare dashboard

### Getting Help

If you encounter issues:
1. Check the logs in the respective service directories
2. Ensure all prerequisites are installed
3. Verify your API keys and credentials are correct
4. Check firewall rules and network connectivity

## Project Organization

```
metrics/
├── docs/                       # Documentation
│   ├── architecture.md         # Architecture diagrams and explanations
│   ├── setup.md                # Setup instructions
│   └── git_workflow.md         # Git workflow guidelines
├── terraform/                  # Infrastructure as code
│   ├── frontend/               # Vultr infrastructure for frontend
│   ├── backend/                # Backend infrastructure
│   └── cloudflare/             # CloudFlare DNS and security configuration
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
├── scripts/                    # Utility scripts
│   ├── deploy.sh               # Infrastructure deployment script
│   └── update_cloudflare.sh    # CloudFlare DNS update script
├── .github/workflows/          # CI/CD workflows
├── .gitignore                  # Git ignore patterns
├── setup.sh                    # Configuration setup script
├── install.sh                  # Main installation script
└── README.md                   # This file
```

## Implementation Phases

### Phase 1: Core Infrastructure ✅
- [x] Initialize repository structure
- [x] Create Terraform configuration for frontend
- [x] Set up automated deployment workflow
- [x] Implement frontend provisioning
- [x] Add CloudFlare integration for DNS management
- [x] Implement automated SSH key generation
- [x] Configure WireGuard VPN
- [x] Set up Docker services on frontend

### Phase 2: Backend Setup 🚧
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

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

[MIT License](LICENSE)