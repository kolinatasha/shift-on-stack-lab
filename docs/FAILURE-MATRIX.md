# Failure Matrix

Documented failure scenarios with reproduction steps, detection, and remediation.

## How to Use This Matrix

Each failure scenario includes:
- **Symptom**: What you observe
- **Detection**: How to identify the issue
- **Root Cause**: Why it happens
- **Fix**: How to resolve it
- **Prevention**: How to avoid it
- **Repro Steps**: How to reproduce for testing

## Failure Scenarios

### 1. Misconfigured Security Group

**Symptom:** Cannot connect to instances despite correct network setup

**Detection:**
```bash
# Check security group rules
sudo microstack.openstack security group rule list shift-secgroup

# Expected: Rules for SSH (22), HTTP (80), HTTPS (443), ICMP
# Actual: Missing or incorrect rules
```

**Root Cause:** Security group created without proper ingress rules or rules deleted accidentally

**Fix:**
```bash
# Recreate security group with proper rules
sudo microstack.openstack security group delete shift-secgroup
sudo microstack.openstack security group create shift-secgroup

# Add required rules
sudo microstack.openstack security group rule create --protocol tcp --dst-port 22 shift-secgroup
sudo microstack.openstack security group rule create --protocol tcp --dst-port 80 shift-secgroup
sudo microstack.openstack security group rule create --protocol tcp --dst-port 443 shift-secgroup
sudo microstack.openstack security group rule create --protocol tcp --dst-port 6443 shift-secgroup
sudo microstack.openstack security group rule create --protocol icmp shift-secgroup
```

**Prevention:**
- Use automation scripts (hack/openstack_up.sh) consistently
- Validate security groups after creation
- Document required ports in runbook

**Repro Steps:**
```bash
# Delete all rules from security group
for rule in $(sudo microstack.openstack security group rule list shift-secgroup -f value -c ID); do
  sudo microstack.openstack security group rule delete $rule
done

# Try to create instance - connectivity will fail
```

---

### 2. Quota Exceeded

**Symptom:** Instance creation fails with "Quota exceeded for instances/cores/ram"

**Detection:**
```bash
# Check quota usage
sudo microstack.openstack quota show shift-lab

# Check current usage
sudo microstack.openstack server list --project shift-lab
```

**Root Cause:** Too many instances running or quota limits set too low

**Fix:**
```bash
# Option 1: Clean up old instances
sudo microstack.openstack server list --project shift-lab
sudo microstack.openstack server delete <instance-id>

# Option 2: Increase quota
sudo microstack.openstack quota set \
  --instances 20 \
  --cores 40 \
  --ram 81920 \
  shift-lab
```

**Prevention:**
- Always run `make destroy` after testing
- Set appropriate quotas during setup
- Monitor resource usage regularly

**Repro Steps:**
```bash
# Set very low quota
sudo microstack.openstack quota set --instances 1 --cores 1 --ram 512 shift-lab

# Try to create multiple instances
make install  # Will fail with quota exceeded
```

---

### 3. Image Missing

**Symptom:** Instance creation fails with "Image not found" or "No valid image"

**Detection:**
```bash
# Check if image exists
sudo microstack.openstack image show cirros-test

# Check image status
sudo microstack.openstack image list
```

**Root Cause:** Image deleted, upload failed, or wrong image name referenced

**Fix:**
```bash
# Re-upload image
curl -sL http://download.cirros-cloud.net/0.6.2/cirros-0.6.2-x86_64-disk.img -o /tmp/cirros.img
sudo microstack.openstack image create \
  --disk-format qcow2 \
  --container-format bare \
  --public \
  --file /tmp/cirros.img \
  cirros-test
rm /tmp/cirros.img
```

**Prevention:**
- Verify image upload in openstack_up.sh
- Check image status before instance creation
- Use image IDs instead of names when possible

**Repro Steps:**
```bash
# Delete the image
sudo microstack.openstack image delete cirros-test

# Try validation
make validate  # Will fail on image check
```

---

### 4. Floating IP Failure

**Symptom:** Cannot allocate floating IP or associate with instance

**Detection:**
```bash
# Check floating IP pool
sudo microstack.openstack floating ip list

# Check external network
sudo microstack.openstack network show external
```

**Root Cause:** External network not configured, pool exhausted, or router not connected

**Fix:**
```bash
# Verify external network exists
sudo microstack.openstack network list --external

# Verify router has external gateway
sudo microstack.openstack router show shift-router

# Set external gateway if missing
sudo microstack.openstack router set --external-gateway external shift-router

# Create floating IP
sudo microstack.openstack floating ip create external
```

**Prevention:**
- Verify router configuration during setup
- Monitor floating IP pool usage
- Clean up unused floating IPs

**Repro Steps:**
```bash
# Remove router's external gateway
sudo microstack.openstack router unset --external-gateway shift-router

# Try to create floating IP
sudo microstack.openstack floating ip create external  # Will fail
```

---

### 5. DNS Resolution Issue

**Symptom:** Instances cannot resolve domain names

**Detection:**
```bash
# Check subnet DNS configuration
sudo microstack.openstack subnet show shift-subnet -c dns_nameservers

# Test DNS from host
nslookup google.com
```

**Root Cause:** Subnet created without DNS nameservers or incorrect DNS servers specified

**Fix:**
```bash
# Update subnet with DNS servers
sudo microstack.openstack subnet set \
  --dns-nameserver 8.8.8.8 \
  --dns-nameserver 8.8.4.4 \
  shift-subnet

# Restart instances to pick up new DNS
sudo microstack.openstack server reboot <instance-id>
```

**Prevention:**
- Always specify DNS nameservers during subnet creation
- Validate DNS configuration after network setup
- Test DNS resolution as part of validation

**Repro Steps:**
```bash
# Create subnet without DNS
sudo microstack.openstack subnet create \
  --network shift-network \
  --subnet-range 192.168.100.0/24 \
  --no-dns-nameservers \
  shift-subnet-broken

# Instances on this subnet will have no DNS
```

---

### 6. Time Drift

**Symptom:** Authentication failures, certificate errors, or "Token has expired" messages

**Detection:**
```bash
# Check system time
date

# Check NTP sync
timedatectl status

# Check time difference
ntpdate -q pool.ntp.org
```

**Root Cause:** System clock out of sync, NTP not configured, or VM time drift

**Fix:**
```bash
# Sync time immediately
sudo ntpdate pool.ntp.org

# Or use timedatectl
sudo timedatectl set-ntp true

# Verify sync
timedatectl status
```

**Prevention:**
- Enable NTP on host system
- Monitor time sync status
- Use hardware clock sync for VMs

**Repro Steps:**
```bash
# Manually set wrong time (requires sudo)
sudo timedatectl set-ntp false
sudo date -s "2020-01-01 00:00:00"

# Try OpenStack operations - will fail with auth errors
sudo microstack.openstack server list
```

---

### 7. Auth Token Issue

**Symptom:** "Authentication required" or "Invalid token" errors

**Detection:**
```bash
# Try to get token
sudo microstack.openstack token issue

# Check Keystone service
sudo snap services microstack.keystone
```

**Root Cause:** Keystone service down, credentials expired, or configuration corruption

**Fix:**
```bash
# Restart Keystone
sudo snap restart microstack.keystone

# Wait for service to be ready
sleep 5

# Verify token issuance
sudo microstack.openstack token issue
```

**Prevention:**
- Monitor Keystone service health
- Use service accounts with appropriate permissions
- Implement token refresh logic in automation

**Repro Steps:**
```bash
# Stop Keystone service
sudo snap stop microstack.keystone

# Try any OpenStack command
sudo microstack.openstack server list  # Will fail with auth error
```

---

### 8. Network MTU Mismatch

**Symptom:** Instances can ping but large packets fail, SSH hangs, or HTTP transfers stall

**Detection:**
```bash
# Check network MTU
sudo microstack.openstack network show shift-network -c mtu

# Check interface MTU on host
ip link show | grep mtu

# Test with different packet sizes
ping -M do -s 1472 <instance-ip>  # Should work
ping -M do -s 1500 <instance-ip>  # May fail if MTU issue
```

**Root Cause:** Network MTU set higher than physical interface supports, causing packet fragmentation issues

**Fix:**
```bash
# Update network MTU
sudo microstack.openstack network set --mtu 1400 shift-network

# Recreate instances to pick up new MTU
sudo microstack.openstack server reboot <instance-id>
```

**Prevention:**
- Set conservative MTU (1400) during network creation
- Document MTU requirements
- Test with various packet sizes during validation

**Repro Steps:**
```bash
# Create network with high MTU
sudo microstack.openstack network create --mtu 9000 test-network

# Create instance on this network
# Large packets will fail if underlying network doesn't support jumbo frames
```

---

### 9. Insufficient Resources

**Symptom:** "No valid host found" error when creating instances

**Detection:**
```bash
# Check hypervisor resources
sudo microstack.openstack hypervisor stats show

# Check host resources
free -h
df -h
```

**Root Cause:** Host system running out of RAM, CPU, or disk space

**Fix:**
```bash
# Option 1: Free up resources
make destroy  # Clean up old instances

# Option 2: Use smaller flavors
sudo microstack.openstack flavor list
sudo microstack.openstack server create --flavor m1.tiny ...

# Option 3: Add more resources to host (if possible)
```

**Prevention:**
- Monitor host resource usage
- Set appropriate quotas
- Use resource-efficient flavors
- Clean up after each test run

**Repro Steps:**
```bash
# Create many large instances to exhaust resources
for i in {1..20}; do
  sudo microstack.openstack server create \
    --flavor m1.large \
    --image cirros-test \
    --network shift-network \
    test-$i
done

# Eventually will fail with "No valid host found"
```

---

### 10. Stale Resource Cleanup

**Symptom:** Resources from previous runs interfere with new deployments

**Detection:**
```bash
# Check for orphaned resources
sudo microstack.openstack server list --all-projects
sudo microstack.openstack port list --all-projects
sudo microstack.openstack volume list --all-projects

# Check for resources in ERROR state
sudo microstack.openstack server list --status ERROR
```

**Root Cause:** Incomplete cleanup from failed runs, resources stuck in transitional states

**Fix:**
```bash
# Force delete stuck instances
for id in $(sudo microstack.openstack server list --status ERROR -f value -c ID); do
  sudo microstack.openstack server delete $id --wait
done

# Clean up orphaned ports
for port in $(sudo microstack.openstack port list --network shift-network -f value -c ID); do
  device_owner=$(sudo microstack.openstack port show $port -f value -c device_owner)
  if [[ "$device_owner" != *"router"* ]]; then
    sudo microstack.openstack port delete $port
  fi
done

# Clean up orphaned volumes
for vol in $(sudo microstack.openstack volume list --status error -f value -c ID); do
  sudo microstack.openstack volume delete $vol
done
```

**Prevention:**
- Always run `make destroy` after testing
- Implement proper cleanup in automation
- Monitor for resources in ERROR state
- Use resource tagging for easier cleanup

**Repro Steps:**
```bash
# Create resources
make install

# Simulate incomplete cleanup (kill process mid-cleanup)
make destroy &
DESTROY_PID=$!
sleep 2
kill -9 $DESTROY_PID

# Resources will be left in inconsistent state
sudo microstack.openstack server list  # Will show orphaned resources
```

---

## Failure Signature Reference

For use in metrics tracking:

| Signature | Scenario |
|-----------|----------|
| `missing_openstack_env` | Environment file not found |
| `openstack_cli_unavailable` | OpenStack CLI not responding |
| `dns_resolution_failure` | DNS not working |
| `network_not_found` | Network resource missing |
| `quota_exceeded_instances` | Instance quota exceeded |
| `quota_exceeded_cores` | Core quota exceeded |
| `image_not_found` | Required image missing |
| `floating_ip_exhausted` | No floating IPs available |
| `auth_token_expired` | Authentication token issues |
| `insufficient_resources` | Host resources exhausted |
| `mtu_mismatch` | Network MTU configuration issue |
| `stale_resources` | Orphaned resources from previous runs |

## Testing Failure Scenarios

To test failure handling:

```bash
# Set environment variable to trigger specific failure
export FAILURE_TEST=quota_exceeded_instances
make install

# Or use script flag (if implemented)
bash hack/install_openshift.sh --simulate-failure=dns_resolution_failure
```
