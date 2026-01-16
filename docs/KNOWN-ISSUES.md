# Known Issues

Tracked issues and workarounds for Shift-on-Stack Lab.

## Issue Template

When reporting new issues, please include:

```markdown
### Issue Title

**Environment:**
- OS: Ubuntu XX.XX
- MicroStack version: X.X
- RAM: XXG
- CPU: X cores

**Description:**
Clear description of the issue

**Steps to Reproduce:**
1. Step one
2. Step two
3. Step three

**Expected Behavior:**
What should happen

**Actual Behavior:**
What actually happens

**Logs:**
```
Relevant log excerpts
```

**Workaround:**
If known, describe workaround
```

## Active Issues

### Issue #1: MicroStack Init Timeout on Low-Memory Systems

**Status:** Open  
**Severity:** Medium  
**Affects:** Systems with 16GB RAM or less

**Description:**
MicroStack initialization (`microstack init`) may timeout or hang on systems with exactly 16GB RAM, especially if other applications are running.

**Workaround:**
```bash
# Close unnecessary applications before init
# Increase swap space
sudo fallocate -l 8G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile

# Then run init
sudo microstack init --auto --control
```

**Tracking:** Monitor memory usage during init with `watch -n 1 free -h`

---

### Issue #2: Snap Refresh During Operations

**Status:** Open  
**Severity:** Low  
**Affects:** All versions

**Description:**
Snap may automatically refresh MicroStack during operations, causing service interruptions.

**Workaround:**
```bash
# Hold snap refreshes during critical operations
sudo snap refresh --hold=24h microstack

# After operations complete, allow refreshes
sudo snap refresh --unhold microstack
```

**Prevention:** Schedule maintenance windows for snap updates

---

### Issue #3: Network Creation Fails After Unclean Shutdown

**Status:** Open  
**Severity:** Medium  
**Affects:** Systems with unexpected shutdowns

**Description:**
After system crash or unclean shutdown, OVN database may be in inconsistent state, preventing network creation.

**Symptoms:**
```
ERROR: Unable to create network
OVN database connection failed
```

**Workaround:**
```bash
# Restart OVN services
sudo snap restart microstack.ovn-northd
sudo snap restart microstack.ovn-controller

# Wait for services to stabilize
sleep 10

# Verify services are running
sudo snap services microstack | grep ovn

# Retry network creation
make openstack-up
```

---

### Issue #4: Instance Console Access Intermittent

**Status:** Open  
**Severity:** Low  
**Affects:** All versions

**Description:**
`openstack console log show` or `console url show` may fail intermittently with "Console not available" error.

**Workaround:**
```bash
# Wait a few seconds and retry
sleep 5
sudo microstack.openstack console log show <instance-id>

# Or access via VNC URL
sudo microstack.openstack console url show <instance-id>
```

**Note:** This is typically a timing issue during instance boot.

---

### Issue #5: Floating IP Association Delay

**Status:** Open  
**Severity:** Low  
**Affects:** All versions

**Description:**
After associating floating IP to instance, connectivity may not work immediately.

**Workaround:**
```bash
# Wait 10-15 seconds after association
sudo microstack.openstack server add floating ip <instance> <floating-ip>
sleep 15

# Verify association
sudo microstack.openstack server show <instance> | grep addresses

# Test connectivity
ping <floating-ip>
```

---

### Issue #6: Security Group Rule Deletion Fails

**Status:** Open  
**Severity:** Low  
**Affects:** Rules associated with active instances

**Description:**
Cannot delete security group rules while instances using the security group are running.

**Workaround:**
```bash
# Option 1: Stop instances first
sudo microstack.openstack server stop <instance-id>
sudo microstack.openstack security group rule delete <rule-id>
sudo microstack.openstack server start <instance-id>

# Option 2: Create new security group and migrate
sudo microstack.openstack security group create new-secgroup
# Add rules to new-secgroup
sudo microstack.openstack server set --security-group new-secgroup <instance-id>
# Delete old security group
```

---

### Issue #7: Image Upload Slow on First Run

**Status:** Expected Behavior  
**Severity:** Low  
**Affects:** First run only

**Description:**
First image upload can take 5-10 minutes depending on network speed.

**Workaround:**
```bash
# Pre-download image
curl -sL http://download.cirros-cloud.net/0.6.2/cirros-0.6.2-x86_64-disk.img -o /tmp/cirros.img

# Upload from local file (faster)
sudo microstack.openstack image create \
  --disk-format qcow2 \
  --container-format bare \
  --public \
  --file /tmp/cirros.img \
  cirros-test
```

**Note:** Subsequent uploads use cached image.

---

### Issue #8: Validation Test Instance Not Cleaned Up

**Status:** Open  
**Severity:** Low  
**Affects:** Validation script

**Description:**
If validation script is interrupted, test instance may not be deleted.

**Workaround:**
```bash
# Manually clean up validation instances
for id in $(sudo microstack.openstack server list --name validation-test -f value -c ID); do
  sudo microstack.openstack server delete $id
done
```

**Fix:** Implemented trap handler in validation script (pending)

---

### Issue #9: Metrics File Corruption on Concurrent Runs

**Status:** Open  
**Severity:** Medium  
**Affects:** Concurrent executions

**Description:**
Running multiple installations concurrently can corrupt `artifacts/metrics.json`.

**Workaround:**
```bash
# Don't run concurrent installations
# If metrics.json is corrupted, restore from backup or recreate:
cat > artifacts/metrics.json <<EOF
{
  "runs": []
}
EOF
```

**Prevention:** Use file locking (planned enhancement)

---

### Issue #10: OpenShift Install CLI Not Available

**Status:** Expected Behavior  
**Severity:** N/A  
**Affects:** Harness mode

**Description:**
Full OpenShift installation requires `openshift-install` CLI which is not included.

**Workaround:**
```bash
# Download openshift-install
VERSION=4.14.0
curl -sL https://mirror.openshift.com/pub/openshift-v4/clients/ocp/${VERSION}/openshift-install-linux.tar.gz -o /tmp/openshift-install.tar.gz
tar -xzf /tmp/openshift-install.tar.gz -C /tmp/
sudo mv /tmp/openshift-install /usr/local/bin/
sudo chmod +x /usr/local/bin/openshift-install

# Verify installation
openshift-install version
```

**Note:** Harness mode works without this CLI.

---

## Resolved Issues

### Issue #R1: Project Deletion Fails with Active Resources

**Status:** Resolved  
**Resolution:** Implemented proper cleanup order in `openstack_down.sh`

**Previous Workaround:**
```bash
# Delete instances first
# Delete ports
# Delete router interfaces
# Then delete project
```

**Current Solution:** Automated in cleanup script

---

### Issue #R2: Subnet DNS Not Applied to Existing Instances

**Status:** Resolved  
**Resolution:** Documentation updated to note instance reboot required

**Solution:**
```bash
# After updating subnet DNS
sudo microstack.openstack server reboot <instance-id>
```

---

## Reporting New Issues

To report a new issue:

1. Check if issue already exists in this document
2. Review [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for solutions
3. Collect diagnostic information:
   ```bash
   # System info
   uname -a
   free -h
   df -h
   
   # MicroStack info
   sudo snap list microstack
   sudo snap services microstack
   
   # Logs
   ls -la artifacts/logs/
   ```
4. Open GitHub issue using the template above
5. Include all relevant logs and diagnostic output

## Issue Priority Levels

- **Critical:** Blocks all operations, no workaround
- **High:** Blocks major functionality, workaround exists
- **Medium:** Impacts some operations, workaround available
- **Low:** Minor inconvenience, easy workaround

## Contributing Fixes

If you have a fix for a known issue:

1. Fork the repository
2. Create a feature branch
3. Implement the fix
4. Add tests if applicable
5. Update this document to mark issue as resolved
6. Submit pull request

See [CONTRIBUTING.md](../CONTRIBUTING.md) for details.
