# Troubleshooting Guide

Common issues and solutions for Shift-on-Stack Lab.

## Table of Contents

- [Installation Issues](#installation-issues)
- [OpenStack Issues](#openstack-issues)
- [Network Issues](#network-issues)
- [Resource Issues](#resource-issues)
- [Validation Issues](#validation-issues)

## Installation Issues

### MicroStack Installation Fails

**Symptom:** `snap install microstack` fails or hangs

**Possible Causes:**
- Insufficient disk space
- Snap daemon not running
- Network connectivity issues

**Solutions:**

```bash
# Check snap daemon
sudo systemctl status snapd

# Restart snap daemon
sudo systemctl restart snapd

# Check disk space
df -h

# Try manual installation
sudo snap install microstack --beta --devmode
```

### MicroStack Initialization Hangs

**Symptom:** `microstack init` hangs or times out

**Possible Causes:**
- Insufficient resources
- Conflicting services
- Previous incomplete initialization

**Solutions:**

```bash
# Check system resources
free -h
top

# Remove and reinstall
sudo snap remove --purge microstack
sudo snap install microstack --beta --devmode
sudo microstack init --auto --control
```

## OpenStack Issues

### OpenStack CLI Not Responding

**Symptom:** `microstack.openstack` commands hang or fail

**Possible Causes:**
- Services not started
- Database connection issues
- Configuration corruption

**Solutions:**

```bash
# Check service status
sudo snap services microstack

# Restart services
sudo snap restart microstack

# Check logs
sudo snap logs microstack -n=100
```

### Project Creation Fails

**Symptom:** Cannot create project or user

**Possible Causes:**
- Keystone service issues
- Database problems
- Permission issues

**Solutions:**

```bash
# Verify Keystone is running
sudo snap services microstack.keystone

# Check admin credentials
sudo microstack.openstack token issue

# Try with explicit admin credentials
sudo microstack.openstack --os-cloud microstack project list
```

### Image Upload Fails

**Symptom:** Image upload times out or fails

**Possible Causes:**
- Network connectivity
- Insufficient disk space
- Glance service issues

**Solutions:**

```bash
# Check Glance service
sudo snap services microstack.glance

# Check disk space
df -h /var/snap/microstack

# Try smaller image first
curl -sL http://download.cirros-cloud.net/0.6.2/cirros-0.6.2-x86_64-disk.img -o /tmp/test.img
sudo microstack.openstack image create --file /tmp/test.img --disk-format qcow2 test-image
```

## Network Issues

### Network Creation Fails

**Symptom:** Cannot create network or subnet

**Possible Causes:**
- Neutron service issues
- IP range conflicts
- OVN configuration problems

**Solutions:**

```bash
# Check Neutron services
sudo snap services microstack.neutron

# List existing networks
sudo microstack.openstack network list

# Check for IP conflicts
ip addr show

# Try different subnet range
sudo microstack.openstack subnet create \
  --network shift-network \
  --subnet-range 192.168.200.0/24 \
  shift-subnet-alt
```

### Router Configuration Fails

**Symptom:** Cannot attach router to external network

**Possible Causes:**
- External network not configured
- Gateway conflicts
- OVN issues

**Solutions:**

```bash
# Verify external network exists
sudo microstack.openstack network list --external

# Check router status
sudo microstack.openstack router show shift-router

# Recreate router
sudo microstack.openstack router delete shift-router
sudo microstack.openstack router create shift-router
sudo microstack.openstack router set --external-gateway external shift-router
```

### Floating IP Allocation Fails

**Symptom:** Cannot allocate floating IPs

**Possible Causes:**
- External network pool exhausted
- Router not connected to external network
- Quota exceeded

**Solutions:**

```bash
# Check floating IP availability
sudo microstack.openstack floating ip list

# Check external network
sudo microstack.openstack network show external

# Check quota
sudo microstack.openstack quota show shift-lab
```

## Resource Issues

### Quota Exceeded

**Symptom:** "Quota exceeded" errors when creating resources

**Possible Causes:**
- Default quotas too low
- Resources not cleaned up from previous runs

**Solutions:**

```bash
# Check current quota
sudo microstack.openstack quota show shift-lab

# Increase quota
sudo microstack.openstack quota set \
  --instances 20 \
  --cores 40 \
  --ram 81920 \
  shift-lab

# Clean up old resources
make destroy
```

### Insufficient Resources

**Symptom:** Instance creation fails with "No valid host found"

**Possible Causes:**
- Host resources exhausted
- Flavor requirements too high
- Placement service issues

**Solutions:**

```bash
# Check available resources
sudo microstack.openstack hypervisor stats show

# Use smaller flavor
sudo microstack.openstack flavor list

# Check compute service
sudo snap services microstack.nova
```

### Disk Space Issues

**Symptom:** Operations fail with disk space errors

**Possible Causes:**
- Snap storage full
- Instance volumes consuming space
- Log files growing

**Solutions:**

```bash
# Check disk usage
df -h
du -sh /var/snap/microstack/*

# Clean up old instances
sudo microstack.openstack server list --all-projects
sudo microstack.openstack server delete <instance-id>

# Clean up old images
sudo microstack.openstack image list
sudo microstack.openstack image delete <image-id>

# Clean up logs
sudo snap logs microstack --clear
```

## Validation Issues

### Instance Boot Test Fails

**Symptom:** Test instance fails to reach ACTIVE state

**Possible Causes:**
- Image corruption
- Network misconfiguration
- Compute service issues
- Insufficient resources

**Solutions:**

```bash
# Check instance status
sudo microstack.openstack server show validation-test-*

# Check instance console log
sudo microstack.openstack console log show validation-test-*

# Check compute logs
sudo snap logs microstack.nova-compute

# Try manual instance creation
sudo microstack.openstack server create \
  --flavor m1.tiny \
  --image cirros-test \
  --network shift-network \
  manual-test
```

### DNS Resolution Fails

**Symptom:** DNS lookups fail from instances or host

**Possible Causes:**
- DNS server unreachable
- Subnet DNS configuration wrong
- Network connectivity issues

**Solutions:**

```bash
# Check DNS configuration
sudo microstack.openstack subnet show shift-subnet

# Update subnet DNS
sudo microstack.openstack subnet set \
  --dns-nameserver 8.8.8.8 \
  --dns-nameserver 8.8.4.4 \
  shift-subnet

# Test DNS from host
nslookup google.com
```

### Security Group Rules Not Working

**Symptom:** Cannot connect to instances despite security group rules

**Possible Causes:**
- Rules not applied correctly
- OVN flow issues
- Port security conflicts

**Solutions:**

```bash
# List security group rules
sudo microstack.openstack security group rule list shift-secgroup

# Recreate security group
sudo microstack.openstack security group delete shift-secgroup
bash hack/openstack_up.sh  # Recreates security group

# Check port security
sudo microstack.openstack port list --network shift-network
```

## General Debugging

### Enable Debug Logging

```bash
# Set debug mode for OpenStack CLI
export OS_DEBUG=1
sudo microstack.openstack server list

# Check service logs
sudo snap logs microstack.nova -n=100
sudo snap logs microstack.neutron -n=100
sudo snap logs microstack.keystone -n=100
```

### Collect Diagnostic Information

```bash
# System info
uname -a
free -h
df -h

# MicroStack info
sudo snap list microstack
sudo snap services microstack

# OpenStack info
sudo microstack.openstack versions show
sudo microstack.openstack endpoint list

# Network info
ip addr
ip route
sudo iptables -L -n
```

### Reset to Clean State

```bash
# Full cleanup
make destroy
make openstack-down

# Remove MicroStack
sudo snap remove --purge microstack

# Clean artifacts
make clean

# Start fresh
make bootstrap
make openstack-up
```

## Getting Help

If issues persist:

1. Check logs in `artifacts/logs/`
2. Review [KNOWN-ISSUES.md](KNOWN-ISSUES.md)
3. Search GitHub issues
4. Open new issue with:
   - Error messages
   - Relevant logs
   - Output of diagnostic commands
   - Environment details (OS, resources, MicroStack version)
