# Metrics Monitoring Infrastructure

A comprehensive monitoring solution based on Prometheus and Grafana for:
- Linux VMs and servers
- Hypervisors (Proxmox and XCP-ng)
- Docker containers/swarms
- Ubuntu-based kiosks
- Windows servers and workstations

## Project Structure
- `ansible/`: Ansible playbooks for deployment
- `docs/`: Documentation
- `dashboards/`: Grafana dashboard definitions
- `prometheus/`: Prometheus configuration
- `alertmanager/`: Alertmanager configuration
- `grafana/`: Grafana configuration
- `exporters/`: Exporter configurations
- `netbox/`: NetBox configuration for dependency mapping
- `terraform/`: Infrastructure as code for deployment

## Getting Started
See [docs/deployment/installation.md](docs/deployment/installation.md) for setup instructions.
