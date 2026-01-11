# Cloud Infrastructure Manager

Collection of scripts to manage infrastructure across multiple cloud providers in a simple and efficient way.

## Description

This project provides command-line tools to create, manage, and destroy cloud infrastructure. Currently supports AWS, with plans to expand to other providers in the future.

## Current Use Case

These scripts were initially created to manage the infrastructure for [peer-observer](https://github.com/0xB10C/peer-observer), a Bitcoin network observation and monitoring project.

## Supported Providers

### ✅ AWS (Amazon Web Services)

Complete scripts to manage EC2 instances with specific configuration for peer-observer.

**Features:**
- Automated EC2 infrastructure creation
- Instance management (start/stop/status)
- Complete destruction with resource cleanup
- Security Group configuration
- Elastic IP management
- EBS volumes with deletion protection
- SSH key pair management

### 🔜 Upcoming Providers

See [TODO.md](TODO.md) for the complete list of planned providers.

## Project Structure

```
cloud-infra-manager/
├── README.md                    # This file
├── TODO.md                      # Roadmap and pending tasks
├── aws/
│   ├── create-aws-infra.sh      # Infrastructure creation script
│   └── manage-aws-instances.sh  # Instance management script
└── (future providers here)
```

## AWS - Usage Guide

### Prerequisites

1. **AWS CLI installed**
   ```bash
   # macOS
   brew install awscli

   # Linux (Ubuntu/Debian)
   curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
   unzip awscliv2.zip
   sudo ./aws/install
   ```

2. **AWS credentials configured**
   ```bash
   aws configure
   ```

### Create Infrastructure

The `create-aws-infra.sh` script creates all necessary infrastructure:

```bash
cd aws
./create-aws-infra.sh
```

**What it creates:**
- 2 EC2 instances (node01 for Bitcoin, web01 for dashboard)
- Security Groups with configured rules
- Persistent Elastic IPs
- EBS volumes (1000 GB for blockchain, with DeleteOnTermination: false)
- SSH Key Pair

**Output:**
- `aws-config.env` - Configuration variables (DO NOT commit)
- `aws-infrastructure.txt` - Infrastructure documentation

### Manage Instances

Once the infrastructure is created, use `manage-aws-instances.sh`:

```bash
cd aws
./manage-aws-instances.sh [command]
```

**Available commands:**

| Command | Description |
|---------|-------------|
| `start` | Starts EC2 instances (stopped → running) |
| `stop` | Stops EC2 instances (running → stopped) |
| `status` | Shows current instance status |
| `destroy` | Permanently destroys all infrastructure |
| `help` | Shows help |

**Examples:**

```bash
# View instance status
./manage-aws-instances.sh status

# Start instances
./manage-aws-instances.sh start

# Stop instances (to save costs)
./manage-aws-instances.sh stop

# Destroy complete infrastructure (CAREFUL!)
./manage-aws-instances.sh destroy
```

### Complete Infrastructure Destruction

The `destroy` command performs a complete cleanup:

1. ✅ Terminates EC2 instances
2. ✅ Releases Elastic IPs (avoids charges)
3. ✅ Detects and allows deletion of orphaned EBS volumes
4. ✅ Cleans up Security Groups (with automatic retries)
5. ✅ Optionally deletes the AWS Key Pair

**Important:**
- Requires double confirmation
- You must type "DESTROY" to confirm
- The local `.pem` file is NOT automatically deleted
- The 1000 GB Bitcoin volume can be preserved if desired

## Security

⚠️ **IMPORTANT**: Never commit sensitive files to the repository.

The following files contain sensitive information and are in `.gitignore`:
- `aws-config.env` - Credentials and configuration
- `aws-infrastructure.txt` - IPs and infrastructure details
- `*.pem` - SSH private keys
- `.env` - Environment variables

## AWS Costs

Keep in mind AWS costs when using these scripts:

| Resource | Estimated Cost | Notes |
|---------|----------------|-------|
| t3.large (node01) | ~$0.08/hour | Only when running |
| t3.medium (web01) | ~$0.04/hour | Only when running |
| EBS 1000 GB (gp3) | ~$80/month | Permanent while it exists |
| EBS 100 GB (gp3) | ~$8/month | Permanent while it exists |
| Elastic IP (in use) | Free | |
| Elastic IP (unassociated) | ~$3.6/month | Delete it with destroy! |

**Saving tip:**
- Use `stop` instead of `destroy` if you plan to reuse the instances
- Stopped instances do NOT generate compute costs, only storage
- Run `destroy` completely if you no longer need the infrastructure

## Contributing

This project is in active development. Contributions are welcome:

1. Fork the project
2. Create a branch for your feature (`git checkout -b feature/new-provider`)
3. Commit your changes (`git commit -m 'Add: GCP support'`)
4. Push to the branch (`git push origin feature/new-provider`)
5. Open a Pull Request

## Roadmap

See [TODO.md](TODO.md) for details about:
- Upcoming cloud providers (GCP, Azure, DigitalOcean, etc.)
- Planned improvements
- Features in development

---

**Note**: Initially developed to manage the infrastructure for [peer-observer](https://github.com/0xB10C/peer-observer).
