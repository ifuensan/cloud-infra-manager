# TODO - Cloud Infrastructure Manager

## Upcoming Cloud Providers

### 🔲 Google Cloud Platform (GCP)
- [ ] Infrastructure creation script (Compute Engine)
- [ ] Instance management script
- [ ] GCP-specific documentation
- [ ] Persistent disk management
- [ ] Firewall rules configuration

**Directory:** `gcp/`

### 🔲 Microsoft Azure
- [ ] Infrastructure creation script (Virtual Machines)
- [ ] Instance management script
- [ ] Azure-specific documentation
- [ ] Managed disk management
- [ ] Network Security Groups configuration

**Directory:** `azure/`

### 🔲 DigitalOcean
- [ ] Infrastructure creation script (Droplets)
- [ ] Droplet management script
- [ ] DigitalOcean-specific documentation
- [ ] Volume management
- [ ] Firewall configuration

**Directory:** `digitalocean/`

### 🔲 Hetzner Cloud
- [ ] Infrastructure creation script
- [ ] Server management script
- [ ] Hetzner-specific documentation
- [ ] Volume management
- [ ] Firewall configuration

**Directory:** `hetzner/`

### 🔲 Oracle Cloud Infrastructure (OCI)
- [ ] Infrastructure creation script
- [ ] Instance management script
- [ ] OCI-specific documentation
- [ ] Leverage the permanent free tier

**Directory:** `oracle/`

### 🔲 Linode (Akamai)
- [ ] Infrastructure creation script
- [ ] Linode management script
- [ ] Linode-specific documentation

**Directory:** `linode/`

## AWS Improvements

### Management
- [ ] Command to resize instances (change instance type)
- [ ] Command to create EBS volume snapshots
- [ ] Command to restore from snapshots
- [ ] Automated backup script
- [ ] Multi-region management
- [ ] Auto Scaling Groups support

### Monitoring and Costs
- [ ] Script to show estimated monthly costs
- [ ] Cost alerts (CloudWatch)
- [ ] Resource usage dashboard
- [ ] Export CloudWatch metrics

### Security
- [ ] Security Group audit
- [ ] Automatic key rotation
- [ ] AWS Secrets Manager integration
- [ ] Enable encryption on EBS volumes
- [ ] MFA for critical operations

### Networking
- [ ] Custom VPC configuration
- [ ] Private/public subnet support
- [ ] VPN setup (OpenVPN or WireGuard)
- [ ] NAT Gateway configuration

## General Project Features

### Multi-Cloud Architecture
- [ ] Unified script to manage multiple providers
- [ ] Centralized configuration (YAML or JSON)
- [ ] Migration between providers
- [ ] Cost comparison between providers

### Automation
- [ ] Terraform integration
- [ ] Ansible integration for configuration
- [ ] CI/CD for automatic deployments
- [ ] Webhooks for notifications (Slack, Discord)

### Documentation
- [ ] Migration guides between providers
- [ ] Video tutorials
- [ ] Troubleshooting guide
- [ ] FAQ section
- [ ] Cost comparison between providers

### Testing
- [ ] Unit tests for bash scripts
- [ ] Integration tests
- [ ] Automated syntax validation
- [ ] Dry-run mode for all scripts

### Enhanced CLI
- [ ] Unified tool in Python or Go
- [ ] JSON output for integration
- [ ] Interactive mode (TUI)
- [ ] Shell autocompletion
- [ ] Global configuration (`~/.cloud-infra-manager/config`)

## Additional Use Cases

### Specific Infrastructures
- [ ] Template for WordPress hosting
- [ ] Template for Kubernetes clusters
- [ ] Template for databases (PostgreSQL, MySQL)
- [ ] Template for CI/CD runners
- [ ] Template for Bitcoin/Lightning nodes
- [ ] Template for development (staging environments)

### Project Management
- [ ] Multiple project support
- [ ] Consistent tagging and labeling
- [ ] Resource inventory by project
- [ ] Separate costs by project

## Optimizations

### Performance
- [ ] Parallel operations (create multiple resources simultaneously)
- [ ] API query caching
- [ ] Use AWS SDKs instead of CLI (faster)

### Usability
- [ ] Customizable aliases and shortcuts
- [ ] Reusable configuration templates
- [ ] Interactive wizard for initial configuration
- [ ] Configuration validation before execution

## Priorities

**High Priority (Q1 2026)**
1. Complete cleanup of existing AWS code
2. Thorough testing and validation of AWS scripts
3. Complete AWS documentation
4. Basic support for DigitalOcean or Hetzner

**Medium Priority (Q2 2026)**
1. Unified multi-cloud script
2. GCP support
3. Cost comparison
4. Basic monitoring

**Low Priority (Future)**
1. Remaining cloud providers
2. Terraform integration
3. Advanced CLI in Python/Go
4. Templates for specific use cases

## Contributions

If you want to contribute to any of these TODOs:
1. Open an issue to discuss the feature
2. Fork the project
3. Implement the feature following the style guides
4. Submit a Pull Request

---

**Last updated:** 2025-12-18
