# Monitoring Infrastructure Architecture

This document outlines the architecture of our monitoring infrastructure.

## Overview

The monitoring infrastructure follows a distributed architecture with frontend and backend components. The frontend component serves as a public-facing interface for collecting metrics from remote systems, while the backend components handle the storage, processing, and visualization of the collected metrics.

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

## Components

### Frontend Component

The frontend component is deployed on a VM with a public IP address and serves as the entry point for remote systems to send metrics.

Key components:
- **Reverse Proxy**: Nginx/Traefik for handling incoming connections and authentication
- **Push Gateway**: Receives metrics from remote systems that can't be directly scraped
- **WireGuard VPN Endpoint**: Provides secure communication channel to the backend
- **Minimal Prometheus Instance**: For receiving and forwarding metrics

```
┌───────────────────────────────────────────────────────────┐
│                     Frontend Component                    │
│                                                           │
│  ┌─────────────┐   ┌─────────────┐   ┌─────────────────┐  │
│  │             │   │             │   │                 │  │
│  │   Reverse   │   │    Push     │   │    Minimal      │  │
│  │    Proxy    │   │   Gateway   │   │   Prometheus    │  │
│  │             │   │             │   │                 │  │
│  └──────┬──────┘   └──────┬──────┘   └─────────┬───────┘  │
│         │                 │                    │          │
│         └─────────────────┼────────────────────┘          │
│                           │                               │
│                    ┌──────┴──────┐                        │
│                    │             │                        │
│                    │  WireGuard  │                        │
│                    │     VPN     │                        │
│                    │             │                        │
│                    └──────┬──────┘                        │
│                           │                               │
└───────────────────────────┼───────────────────────────────┘
                            │
                            ▼ To Backend
```

### Backend Components

The backend components are deployed on a private network (UniFi-managed) and handle the core monitoring functionality.

Key components:
- **Prometheus Server(s)**: Central and federated instances for metrics collection and storage
- **Grafana**: For visualization and dashboards
- **Alertmanager**: For alert routing and notifications
- **Loki**: For log aggregation
- **NetBox**: For infrastructure resource modeling and visualization

```
┌──────────────────────────────────────────────────────────────────────────┐
│                           Backend Components                             │
│                                                                          │
│  ┌─────────────┐   ┌─────────────┐   ┌─────────────┐   ┌─────────────┐   │
│  │             │   │             │   │             │   │             │   │
│  │  Prometheus │   │   Grafana   │   │ Alertmanager│   │    Loki     │   │
│  │             │   │             │   │             │   │             │   │
│  └──────┬──────┘   └──────┬──────┘   └──────┬──────┘   └──────┬──────┘   │
│         │                 │                 │                 │          │
│         └─────────────────┼─────────────────┼─────────────────┘          │
│                           │                 │                            │
│                    ┌──────┴──────┐   ┌──────┴──────┐                     │
│                    │             │   │             │                     │
│                    │   NetBox    │   │  Persistent │                     │
│                    │             │   │   Storage   │                     │
│                    └─────────────┘   └─────────────┘                     │
│                                                                          │
└──────────────────────────────────────────────────────────────────────────┘
```

## Deployment Strategy

The infrastructure will be deployed using Infrastructure as Code (IaC) principles:

1. **Terraform** for provisioning infrastructure resources
2. **Ansible** for configuration management
3. **Docker** for containerized deployment of components
4. **Git** for version control and collaboration

## Monitoring Targets

The infrastructure will monitor the following systems:

1. **Linux VMs and Servers**: Using node_exporter
2. **Hypervisors**: Proxmox and XCP-ng using specific exporters
3. **Docker Containers/Swarms**: Using cAdvisor and Docker metrics
4. **Ubuntu-based Kiosks**: Using node_exporter with custom configurations
5. **Windows Servers and Workstations**: Using windows_exporter (stretch goal)

## Network Communication

Communication between components follows these principles:

1. **Remote Systems → Frontend**: HTTPS with authentication
2. **Frontend → Backend**: WireGuard VPN tunnel
3. **Backend Components**: Internal network communication with mutual TLS where applicable

## Security Considerations

- All external communication is encrypted (HTTPS, WireGuard)
- Authentication is required for all external access
- Firewall rules to restrict access to necessary ports
- Regular updates and security patches
- Principle of least privilege for service accounts
