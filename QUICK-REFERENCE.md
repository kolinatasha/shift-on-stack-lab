# Quick Reference Card

## One-Line Commands

```bash
# Full workflow
make bootstrap && make openstack-up && make validate && make install && make report

# Quick cleanup
make destroy && make openstack-down && make clean
```

## Common Operations

### Setup
```bash
make bootstrap          # First-time setup
make openstack-up       # Start OpenStack (15-30 min)
make validate          # Verify setup (2-5 min)
```

### Installation
```bash
make install           # Run install harness (10-15 min)
make destroy           # Clean up cluster
```

### Reporting
```bash
make report            # Generate metrics report
cat artifacts/report.md
```

### Troubleshooting
```bash
# View logs
ls -lt artifacts/logs/
tail -f artifacts/logs/install_*.log

# Check OpenStack
sudo microstack.openstack server list
sudo microstack.openstack network list
sudo snap services microstack

# Check metrics
cat artifacts/metrics.json | jq .
cat artifacts/metrics.json | jq '.runs[-1]'  # Latest run
```

## OpenStack Commands

```bash
# List resources
sudo microstack.openstack server list
sudo microstack.openstack network list
sudo microstack.openstack image list
sudo microstack.openstack volume list

# Check quotas
sudo microstack.openstack quota show shift-lab

# Check services
sudo snap services microstack
sudo snap logs microstack.nova -n=50

# Manual cleanup
sudo microstack.openstack server delete <instance-id>
sudo microstack.openstack network delete <network-id>
```

## Debugging

```bash
# Enable debug mode
export OS_DEBUG=1

# Check system resources
free -h
df -h
top

# Validate environment
cat artifacts/openstack_env.json | jq .

# Test connectivity
ping 8.8.8.8
nslookup google.com
```

## Failure Scenarios

```bash
# Reproduce specific failures (see FAILURE-MATRIX.md)

# Quota exceeded
sudo microstack.openstack quota set --instances 1 shift-lab
make install  # Will fail

# Image missing
sudo microstack.openstack image delete cirros-test
make validate  # Will fail

# Network missing
sudo microstack.openstack network delete shift-network
make validate  # Will fail
```

## Metrics Queries

```bash
# Total runs
jq '.runs | length' artifacts/metrics.json

# Success rate
jq '[.runs[] | select(.success == true)] | length' artifacts/metrics.json

# Failed runs
jq '[.runs[] | select(.success == false)]' artifacts/metrics.json

# Average duration
jq '[.runs[].duration_seconds] | add / length' artifacts/metrics.json

# Failure signatures
jq '[.runs[] | .failure_signature] | group_by(.) | map({sig: .[0], count: length})' artifacts/metrics.json
```

## Emergency Procedures

```bash
# Force stop all instances
for id in $(sudo microstack.openstack server list -f value -c ID); do
  sudo microstack.openstack server delete $id
done

# Complete reset
make destroy
make openstack-down
sudo snap remove --purge microstack
make clean
make bootstrap
make openstack-up

# Restart services
sudo snap restart microstack
```

## File Locations

```
artifacts/openstack_env.json    # Environment configuration
artifacts/metrics.json          # All run metrics
artifacts/report.md            # Latest report
artifacts/logs/                # All execution logs
docs/RUNBOOK.md               # Detailed procedures
docs/TROUBLESHOOTING.md       # Issue solutions
docs/FAILURE-MATRIX.md        # Failure scenarios
docs/KNOWN-ISSUES.md          # Known issues
```

## Environment Variables

```bash
# OpenStack debug mode
export OS_DEBUG=1

# Custom pull secret location
export PULL_SECRET_PATH=/path/to/pull-secret.txt

# Failure testing (if implemented)
export FAILURE_TEST=quota_exceeded_instances
```

## Useful Aliases

```bash
# Add to ~/.bashrc
alias mos='sudo microstack.openstack'
alias mos-servers='sudo microstack.openstack server list'
alias mos-networks='sudo microstack.openstack network list'
alias mos-logs='ls -lt artifacts/logs/ | head'
alias mos-metrics='cat artifacts/metrics.json | jq ".runs[-1]"'
```

## Performance Tips

```bash
# Increase quotas for faster testing
sudo microstack.openstack quota set \
  --instances 20 \
  --cores 40 \
  --ram 81920 \
  shift-lab

# Use smaller flavors
sudo microstack.openstack flavor list
# Use m1.tiny or m1.small

# Pre-download images
curl -sL http://download.cirros-cloud.net/0.6.2/cirros-0.6.2-x86_64-disk.img -o /tmp/cirros.img
```

## Documentation Links

- [README.md](README.md) - Project overview
- [RUNBOOK.md](docs/RUNBOOK.md) - Operational procedures
- [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) - Issue resolution
- [FAILURE-MATRIX.md](docs/FAILURE-MATRIX.md) - Failure scenarios
- [KNOWN-ISSUES.md](docs/KNOWN-ISSUES.md) - Known issues
- [CONTRIBUTING.md](CONTRIBUTING.md) - Contribution guide
- [PROJECT-SUMMARY.md](PROJECT-SUMMARY.md) - Implementation details
