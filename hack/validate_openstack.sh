#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ARTIFACTS_DIR="$PROJECT_ROOT/artifacts"
LOG_FILE="$ARTIFACTS_DIR/logs/validate_$(date +%Y%m%d_%H%M%S).log"

# Logging functions
log_info() {
  local msg="[$(date +'%Y-%m-%d %H:%M:%S')] INFO: $*"
  echo "$msg" | tee -a "$LOG_FILE"
}

log_error() {
  local msg="[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $*"
  echo "$msg" | tee -a "$LOG_FILE" >&2
}

log_success() {
  local msg="[$(date +'%Y-%m-%d %H:%M:%S')] SUCCESS: $*"
  echo "$msg" | tee -a "$LOG_FILE"
}

mkdir -p "$ARTIFACTS_DIR/logs"

log_info "Starting OpenStack validation..."

VALIDATION_FAILED=0

# Check if MicroStack is installed
log_info "Checking MicroStack installation..."
if ! snap list microstack &>/dev/null; then
  log_error "MicroStack is not installed"
  VALIDATION_FAILED=1
else
  log_success "MicroStack is installed"
fi

# Check if environment file exists
log_info "Checking environment configuration..."
if [[ ! -f "$ARTIFACTS_DIR/openstack_env.json" ]]; then
  log_error "Environment file not found: $ARTIFACTS_DIR/openstack_env.json"
  log_error "Run 'make openstack-up' first"
  exit 1
fi
log_success "Environment configuration found"

# Extract project name
PROJECT_NAME=$(jq -r '.project.name' "$ARTIFACTS_DIR/openstack_env.json")

# Check OpenStack services
log_info "Checking OpenStack services..."
if ! sudo microstack.openstack --version &>/dev/null; then
  log_error "OpenStack CLI not responding"
  VALIDATION_FAILED=1
else
  log_success "OpenStack CLI is functional"
fi

# Check compute quotas
log_info "Checking compute quotas..."
QUOTA_OUTPUT=$(sudo microstack.openstack quota show "$PROJECT_NAME" 2>/dev/null || echo "")
if [[ -z "$QUOTA_OUTPUT" ]]; then
  log_error "Failed to retrieve quotas"
  VALIDATION_FAILED=1
else
  INSTANCES=$(echo "$QUOTA_OUTPUT" | grep "instances" | awk '{print $4}')
  CORES=$(echo "$QUOTA_OUTPUT" | grep "cores" | awk '{print $4}')
  RAM=$(echo "$QUOTA_OUTPUT" | grep "ram" | awk '{print $4}')
  
  log_info "Quota limits - Instances: $INSTANCES, Cores: $CORES, RAM: ${RAM}MB"
  log_success "Compute quotas retrieved"
fi

# Check network resources
log_info "Checking network resources..."
NETWORK_NAME=$(jq -r '.network.name' "$ARTIFACTS_DIR/openstack_env.json")
if ! sudo microstack.openstack network show "$NETWORK_NAME" &>/dev/null; then
  log_error "Network not found: $NETWORK_NAME"
  VALIDATION_FAILED=1
else
  log_success "Network exists: $NETWORK_NAME"
fi

SUBNET_NAME=$(jq -r '.subnet.name' "$ARTIFACTS_DIR/openstack_env.json")
if ! sudo microstack.openstack subnet show "$SUBNET_NAME" &>/dev/null; then
  log_error "Subnet not found: $SUBNET_NAME"
  VALIDATION_FAILED=1
else
  log_success "Subnet exists: $SUBNET_NAME"
fi

ROUTER_NAME=$(jq -r '.router.name' "$ARTIFACTS_DIR/openstack_env.json")
if ! sudo microstack.openstack router show "$ROUTER_NAME" &>/dev/null; then
  log_error "Router not found: $ROUTER_NAME"
  VALIDATION_FAILED=1
else
  log_success "Router exists: $ROUTER_NAME"
fi

# Check security group
log_info "Checking security group..."
SECGROUP_NAME=$(jq -r '.security_group.name' "$ARTIFACTS_DIR/openstack_env.json")
if ! sudo microstack.openstack security group show "$SECGROUP_NAME" &>/dev/null; then
  log_error "Security group not found: $SECGROUP_NAME"
  VALIDATION_FAILED=1
else
  RULE_COUNT=$(sudo microstack.openstack security group rule list "$SECGROUP_NAME" -f value | wc -l)
  log_info "Security group has $RULE_COUNT rules"
  log_success "Security group exists: $SECGROUP_NAME"
fi

# Check image availability
log_info "Checking image availability..."
IMAGE_NAME=$(jq -r '.image.name' "$ARTIFACTS_DIR/openstack_env.json")
if ! sudo microstack.openstack image show "$IMAGE_NAME" &>/dev/null; then
  log_error "Image not found: $IMAGE_NAME"
  VALIDATION_FAILED=1
else
  IMAGE_STATUS=$(sudo microstack.openstack image show "$IMAGE_NAME" -f value -c status)
  if [[ "$IMAGE_STATUS" != "active" ]]; then
    log_error "Image is not active: $IMAGE_STATUS"
    VALIDATION_FAILED=1
  else
    log_success "Image is active: $IMAGE_NAME"
  fi
fi

# Test instance boot (optional, can be slow)
log_info "Testing basic instance boot..."
TEST_INSTANCE="validation-test-$(date +%s)"
FLAVOR="m1.tiny"

if sudo microstack.openstack server create \
  --flavor "$FLAVOR" \
  --image "$IMAGE_NAME" \
  --network "$NETWORK_NAME" \
  --security-group "$SECGROUP_NAME" \
  "$TEST_INSTANCE" &>/dev/null; then
  
  log_info "Waiting for instance to become active..."
  sleep 10
  
  INSTANCE_STATUS=$(sudo microstack.openstack server show "$TEST_INSTANCE" -f value -c status 2>/dev/null || echo "ERROR")
  
  if [[ "$INSTANCE_STATUS" == "ACTIVE" ]] || [[ "$INSTANCE_STATUS" == "BUILD" ]]; then
    log_success "Instance boot test passed"
  else
    log_error "Instance failed to boot. Status: $INSTANCE_STATUS"
    VALIDATION_FAILED=1
  fi
  
  # Cleanup test instance
  log_info "Cleaning up test instance..."
  sudo microstack.openstack server delete "$TEST_INSTANCE" &>/dev/null || true
else
  log_error "Failed to create test instance"
  VALIDATION_FAILED=1
fi

# Final validation result
echo ""
if [[ $VALIDATION_FAILED -eq 0 ]]; then
  log_success "=== VALIDATION PASSED ==="
  log_info "OpenStack environment is ready for OpenShift installation"
  exit 0
else
  log_error "=== VALIDATION FAILED ==="
  log_error "Please review errors above and fix issues before proceeding"
  exit 1
fi
