# Metrics - Monitoring Infrastructure

A comprehensive monitoring infrastructure using Prometheus, Grafana, and other open-source tools to monitor various systems across multiple environments.

## Project Overview

This project implements a scalable, hierarchical monitoring solution with the following features:

- Relationship/dependency mapping
- Hierarchical visibility (DNS → Cloud → Edge → Internal)
- Pure open-source solution
- Exportable metrics for custom dashboards/portals
- Configuration as code (Git-based)

## Architecture

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

## Repository Structure

```
metrics/
├── docs/                       # Documentation
│   ├── architecture.md         # Architecture diagrams and explanations
│   └── setup.md                # Setup instructions
├── terraform/                  # Infrastructure as code
│   ├── frontend/               # VPS with public IP
│   └── backend/                # Backend infrastructure
├── ansible/                    # Configuration management
│   ├── playbooks/              # Deployment playbooks
│   └── roles/                  # Reusable roles
├── docker/                     # Container configurations
│   ├── prometheus/             # Prometheus container setup
│   ├── grafana/                # Grafana container setup
│   ├── alertmanager/           # Alertmanager container setup
│   └── loki/                   # Loki container setup
├── exporters/                  # Exporter configurations
│   ├── node_exporter/          # Linux systems monitoring
│   ├── cadvisor/               # Container monitoring
│   ├── blackbox_exporter/      # Endpoint probing
│   ├── hypervisor_exporters/   # Proxmox and XCP-ng monitoring
│   └── windows_exporter/       # Windows monitoring
├── dashboards/                 # Grafana dashboard JSON files
└── .github/                    # GitHub workflows
    └── workflows/              # CI/CD workflows
```

## Getting Started

### Prerequisites

- Docker and Docker Compose
- Terraform
- Ansible
- Git

### Setup Instructions

Detailed setup instructions can be found in [docs/setup.md](docs/setup.md).

## Implementation Phases

### Phase 1: Core Infrastructure
1. Set up central Prometheus/Grafana server
2. Implement secure remote access architecture
3. Create base configuration templates
4. Establish Git repository structure

### Phase 2: Basic Monitoring
1. Deploy node_exporter to Linux systems
2. Set up Docker monitoring
3. Create initial dashboards
4. Implement basic alerting

### Phase 3: Advanced Monitoring
1. Add hypervisor monitoring
2. Implement Windows monitoring
3. Set up kiosk monitoring
4. Configure advanced alerting rules

### Phase 4: Relationship Mapping
1. Deploy NetBox for infrastructure modeling
2. Create service dependency configurations
3. Build relationship visualization dashboards
4. Implement topology views

## License

[MIT License](LICENSE)
