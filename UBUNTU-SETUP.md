# Ubuntu Setup Guide

This guide helps you set up an Ubuntu system to run the Shift-on-Stack Lab.

## Option 1: Use Existing Ubuntu System

If you have access to an Ubuntu machine (physical or VM):

### Requirements
- Ubuntu 20.04 or later
- 16GB+ RAM
- 4+ CPU cores
- 100GB+ free disk space
- Sudo access
- Internet connection

### Quick Start
```bash
# Clone the repository
git clone https://github.com/kolinatasha/shift-on-stack-lab.git
cd shift-on-stack-lab

# Run full automated deployment
bash hack/full_deployment.sh
```

This will:
1. Bootstrap environment (5 min)
2. Deploy OpenStack (15-30 min)
3. Validate setup (2-5 min)
4. Run 10 installation tests (1-2 hours)
5. Generate final report

**Total time: 2-3 hours** (mostly automated, you can walk away)

---

## Option 2: Create Ubuntu VM on Windows

If you're on Windows, you can create an Ubuntu VM:

### Using VirtualBox (Free)

1. **Download VirtualBox**
   - https://www.virtualbox.org/wiki/Downloads
   - Install VirtualBox on Windows

2. **Download Ubuntu ISO**
   - https://ubuntu.com/download/desktop
   - Get Ubuntu 22.04 LTS (latest)

3. **Create VM**
   ```
   Name: shift-lab
   Type: Linux
   Version: Ubuntu (64-bit)
   Memory: 16384 MB (16GB)
   CPU: 4 cores
   Disk: 120 GB (dynamically allocated)
   ```

4. **Install Ubuntu**
   - Mount the ISO
   - Start VM and follow installation
   - Create user account
   - Enable SSH (optional but recommended)

5. **Run the lab**
   ```bash
   # Inside Ubuntu VM
   git clone https://github.com/kolinatasha/shift-on-stack-lab.git
   cd shift-on-stack-lab
   bash hack/full_deployment.sh
   ```

### Using WSL2 (Windows Subsystem for Linux)

⚠️ **NOT RECOMMENDED** - MicroStack requires full Ubuntu, not WSL2.

WSL2 limitations:
- No snap support (MicroStack uses snap)
- Limited nested virtualization
- Network complications

Use VirtualBox or cloud VM instead.

---

## Option 3: Use Cloud VM (Easiest)

Spin up an Ubuntu VM in the cloud for testing:

### AWS EC2
```bash
# Instance type: t3.xlarge or larger
# - 4 vCPUs
# - 16 GB RAM
# - Ubuntu 22.04 LTS AMI
# - 120 GB storage

# SSH into instance
ssh -i your-key.pem ubuntu@<instance-ip>

# Clone and run
git clone https://github.com/kolinatasha/shift-on-stack-lab.git
cd shift-on-stack-lab
bash hack/full_deployment.sh
```

**Cost estimate:** ~$0.17/hour (t3.xlarge) = ~$0.50 for full test suite

### DigitalOcean Droplet
```bash
# Droplet: Premium Intel 16GB/4CPU
# - Ubuntu 22.04 LTS
# - 16 GB RAM
# - 4 vCPUs

# SSH into droplet
ssh root@<droplet-ip>

# Clone and run
git clone https://github.com/kolinatasha/shift-on-stack-lab.git
cd shift-on-stack-lab
bash hack/full_deployment.sh
```

**Cost estimate:** ~$0.12/hour = ~$0.36 for full test suite

### Azure VM
```bash
# VM Size: Standard_D4s_v3
# - 4 vCPUs
# - 16 GB RAM
# - Ubuntu 22.04 LTS

# SSH into VM
ssh azureuser@<vm-ip>

# Clone and run
git clone https://github.com/kolinatasha/shift-on-stack-lab.git
cd shift-on-stack-lab
bash hack/full_deployment.sh
```

---

## Automated Scripts Available

Once you're on Ubuntu, you have two automation options:

### Option A: Full Automated Deployment
```bash
bash hack/full_deployment.sh
```
Runs everything from start to finish (2-3 hours).

### Option B: Custom Test Suite
```bash
# Run specific number of tests
bash hack/run_test_suite.sh 5    # 5 runs
bash hack/run_test_suite.sh 20   # 20 runs
bash hack/run_test_suite.sh 10 60  # 10 runs, 60s delay between
```

### Option C: Manual Step-by-Step
```bash
make bootstrap      # Setup
make openstack-up   # Deploy OpenStack
make validate       # Validate
make install        # Single test run
make destroy        # Cleanup
make report         # Generate report
```

---

## What Happens During Automation

### Phase 1: Bootstrap (5 minutes)
- Checks system requirements
- Installs dependencies (snap, jq, curl)
- Creates artifacts directory
- Initializes metrics tracking

### Phase 2: OpenStack Setup (15-30 minutes)
- Installs MicroStack via snap
- Initializes OpenStack services
- Creates network infrastructure
- Configures security groups
- Uploads base image

### Phase 3: Validation (2-5 minutes)
- Tests OpenStack CLI
- Validates network resources
- Checks quotas
- Boots test instance

### Phase 4: Test Suite (1-2 hours)
- Runs 10 installation tests
- Captures metrics for each run
- Cleans up after each test
- Tracks success/failure rates

### Phase 5: Report Generation (1 minute)
- Analyzes all test runs
- Calculates success rate
- Identifies failure patterns
- Generates markdown report

---

## Monitoring Progress

### Watch Logs in Real-Time
```bash
# In another terminal
tail -f artifacts/logs/install_*.log
```

### Check Current Status
```bash
# View latest metrics
cat artifacts/metrics.json | jq '.runs[-1]'

# Count total runs
cat artifacts/metrics.json | jq '.runs | length'

# Check success rate
cat artifacts/metrics.json | jq '[.runs[] | select(.success == true)] | length'
```

### OpenStack Status
```bash
# Check services
sudo snap services microstack

# Check resources
sudo microstack.openstack server list
sudo microstack.openstack network list
```

---

## Troubleshooting

### Script Fails to Start
```bash
# Check you're on Ubuntu
cat /etc/os-release

# Check system resources
free -h
df -h
nproc
```

### MicroStack Installation Fails
```bash
# Check snap
sudo systemctl status snapd

# Retry installation
sudo snap remove --purge microstack
sudo snap install microstack --beta --devmode
```

### Out of Disk Space
```bash
# Check usage
df -h

# Clean up old logs
rm -rf artifacts/logs/*

# Clean up snap cache
sudo snap set system refresh.retain=2
```

### Need to Stop and Resume
```bash
# Stop current run: Ctrl+C

# Resume with remaining runs
bash hack/run_test_suite.sh 5  # Run remaining tests

# Or continue manually
make install
make destroy
make report
```

---

## After Completion

### View Results
```bash
# Console summary
make report

# Detailed report
cat artifacts/report.md

# Raw metrics
cat artifacts/metrics.json | jq .
```

### Cleanup
```bash
# Remove cluster resources
make destroy

# Remove OpenStack environment
make openstack-down

# Complete cleanup (removes MicroStack)
sudo snap remove --purge microstack
make clean
```

### Save Results
```bash
# Backup metrics
cp artifacts/metrics.json ~/shift-lab-metrics-$(date +%Y%m%d).json
cp artifacts/report.md ~/shift-lab-report-$(date +%Y%m%d).md

# Backup logs
tar -czf ~/shift-lab-logs-$(date +%Y%m%d).tar.gz artifacts/logs/
```

---

## Cost Comparison

| Option | Cost | Setup Time | Notes |
|--------|------|------------|-------|
| Local Ubuntu | Free | 30 min | Need hardware |
| VirtualBox VM | Free | 1 hour | Uses your PC resources |
| AWS EC2 | ~$0.50 | 15 min | Pay per hour |
| DigitalOcean | ~$0.36 | 15 min | Pay per hour |
| Azure VM | ~$0.50 | 15 min | Pay per hour |

**Recommendation:** Use cloud VM for one-time testing (cheapest and fastest).

---

## Questions?

- Check [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)
- Review [DEPLOYMENT-CHECKLIST.md](DEPLOYMENT-CHECKLIST.md)
- Open GitHub issue with logs
