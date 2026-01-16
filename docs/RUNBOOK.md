# Shift-on-Stack Lab Runbook

Operational procedures for running the Shift-on-Stack Lab.

## Prerequisites Check

Before starting, verify:

```bash
# Check OS
cat /etc/os-release | grep "Ubuntu"

# Check resources
free -h  # Should show 16GB+ RAM
nproc    # Should show 4+ CPUs
df -h    # Should show 100GB+ free space

# Check sudo access
sudo -v
```

## Standard Operating Procedures

### 1. Initial Setup

```bash
# Clone repository
git clone https://github.com/kolinatasha/shift-on-stack-lab.git
cd shift-on-stack-lab

# Bootstrap environment
make bootstrap
```

Expected output:
- System resources validated
- Required packages installed
- Artifacts directory created
- Metrics file initialized

### 2. OpenStack Environment Setup

```bash
# Bring up OpenStack
make openstack-up
```

This will:
1. Install MicroStack (if not present) - 5-10 minutes
2. Initialize MicroStack - 10-15 minutes
3. Create project, user, network, subnet, router
4. Configure security groups
5. Upload base image
6. Generate `artifacts/openstack_env.json`

Expected duration: 15-30 minutes (first run)

### 3. Validate OpenStack

```bash
# Run validation
make validate
```

Checks:
- MicroStack installation
- OpenStack services
- Network resources
- Security groups
- Image availability
- Basic instance boot test

Expected duration: 2-5 minutes

### 4. Install OpenShift

```bash
# Run installation harness
make install
```

Phases:
1. Prerequisites validation
2. DNS configuration check
3. Network validation
4. Quota validation
5. Installation (harness or full)

Expected duration: 10-15 minutes (harness), 45-90 minutes (full)

### 5. Generate Report

```bash
# Generate metrics report
make report
```

Outputs:
- Console summary
- `artifacts/report.md` with detailed metrics

### 6. Cleanup

```bash
# Destroy cluster resources
make destroy

# Tear down OpenStack environment
make openstack-down
```

## Troubleshooting Quick Reference

| Issue | Quick Fix |
|-------|-----------|
| MicroStack install fails | Check snap: `sudo snap list` |
| Network creation fails | Check existing networks: `sudo microstack.openstack network list` |
| Validation fails | Review logs in `artifacts/logs/` |
| Quota exceeded | Check quotas: `sudo microstack.openstack quota show shift-lab` |
| Instance boot fails | Check image status: `sudo microstack.openstack image list` |

See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for detailed solutions.

## Monitoring

### Check OpenStack Status

```bash
# Service status
sudo snap services microstack

# Resource usage
sudo microstack.openstack server list
sudo microstack.openstack network list
sudo microstack.openstack volume list
```

### Check Logs

```bash
# Latest logs
ls -lt artifacts/logs/

# View specific log
cat artifacts/logs/install_YYYYMMDD_HHMMSS.log
```

### Check Metrics

```bash
# View metrics
cat artifacts/metrics.json | jq .

# Latest run
cat artifacts/metrics.json | jq '.runs[-1]'
```

## Emergency Procedures

### Force Cleanup

If normal cleanup fails:

```bash
# List all resources
sudo microstack.openstack server list --all-projects
sudo microstack.openstack network list
sudo microstack.openstack router list

# Force delete instances
for id in $(sudo microstack.openstack server list -f value -c ID); do
  sudo microstack.openstack server delete $id --wait
done

# Remove MicroStack completely
sudo snap remove --purge microstack
```

### Reset Environment

```bash
# Clean artifacts
make clean

# Re-bootstrap
make bootstrap

# Start fresh
make openstack-up
```

## Maintenance

### Update MicroStack

```bash
sudo snap refresh microstack
```

### Backup Configuration

```bash
# Backup environment config
cp artifacts/openstack_env.json ~/openstack_env_backup.json

# Backup metrics
cp artifacts/metrics.json ~/metrics_backup.json
```

## Performance Tuning

### Increase Quotas

```bash
sudo microstack.openstack quota set \
  --instances 20 \
  --cores 40 \
  --ram 81920 \
  shift-lab
```

### Optimize MicroStack

```bash
# Check resource allocation
sudo snap get microstack

# Adjust if needed (example)
sudo snap set microstack config.network.ovn-northd-nb-db-port=6641
```

## Scheduled Tasks

### Daily Health Check

```bash
#!/bin/bash
make validate && echo "Health check passed" || echo "Health check failed"
```

### Weekly Metrics Review

```bash
#!/bin/bash
make report
# Review artifacts/report.md
```

## Contact and Escalation

For issues not covered in this runbook:
1. Check [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
2. Review [KNOWN-ISSUES.md](KNOWN-ISSUES.md)
3. Check logs in `artifacts/logs/`
4. Open GitHub issue with logs and environment details
