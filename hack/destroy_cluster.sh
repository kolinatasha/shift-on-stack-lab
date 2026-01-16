#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ARTIFACTS_DIR="$PROJECT_ROOT/artifacts"
LOG_FILE="$ARTIFACTS_DIR/logs/destroy_$(date +%Y%m%d_%H%M%S).log"
METRICS_FILE="$ARTIFACTS_DIR/metrics.json"

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

log_info "Starting OpenShift cluster destruction..."

ROLLBACK_ID="rollback-$(date +%Y%m%d-%H%M%S)"
START_TIME=$(date +%s)
ROLLBACK_SUCCESS=false

# Check if OpenStack environment exists
if [[ ! -f "$ARTIFACTS_DIR/openstack_env.json" ]]; then
  log_error "OpenStack environment file not found"
  exit 1
fi

PROJECT_NAME=$(jq -r '.project.name' "$ARTIFACTS_DIR/openstack_env.json")

log_info "Destroying cluster resources in project: $PROJECT_NAME"

# List and delete all instances
log_info "Finding cluster instances..."
INSTANCES=$(sudo microstack.openstack server list --project "$PROJECT_NAME" -f value -c ID 2>/dev/null || true)

if [[ -n "$INSTANCES" ]]; then
  INSTANCE_COUNT=$(echo "$INSTANCES" | wc -l)
  log_info "Found $INSTANCE_COUNT instance(s) to delete"
  
  for instance in $INSTANCES; do
    INSTANCE_NAME=$(sudo microstack.openstack server show "$instance" -f value -c name 2>/dev/null || echo "unknown")
    log_info "Deleting instance: $INSTANCE_NAME ($instance)"
    
    if sudo microstack.openstack server delete "$instance" 2>/dev/null; then
      log_success "Instance deleted: $INSTANCE_NAME"
    else
      log_error "Failed to delete instance: $INSTANCE_NAME"
    fi
  done
  
  # Wait for instances to be fully deleted
  log_info "Waiting for instances to be fully deleted..."
  sleep 10
  
  # Verify deletion
  REMAINING=$(sudo microstack.openstack server list --project "$PROJECT_NAME" -f value -c ID 2>/dev/null | wc -l)
  if [[ $REMAINING -eq 0 ]]; then
    log_success "All instances deleted successfully"
    ROLLBACK_SUCCESS=true
  else
    log_error "$REMAINING instance(s) still remain"
    ROLLBACK_SUCCESS=false
  fi
else
  log_info "No instances found to delete"
  ROLLBACK_SUCCESS=true
fi

# Delete floating IPs
log_info "Checking for floating IPs..."
FLOATING_IPS=$(sudo microstack.openstack floating ip list --project "$PROJECT_NAME" -f value -c ID 2>/dev/null || true)

if [[ -n "$FLOATING_IPS" ]]; then
  for fip in $FLOATING_IPS; do
    log_info "Deleting floating IP: $fip"
    sudo microstack.openstack floating ip delete "$fip" 2>/dev/null || true
  done
  log_success "Floating IPs deleted"
fi

# Delete volumes
log_info "Checking for volumes..."
VOLUMES=$(sudo microstack.openstack volume list --project "$PROJECT_NAME" -f value -c ID 2>/dev/null || true)

if [[ -n "$VOLUMES" ]]; then
  for vol in $VOLUMES; do
    log_info "Deleting volume: $vol"
    sudo microstack.openstack volume delete "$vol" 2>/dev/null || true
  done
  log_success "Volumes deleted"
fi

# Delete ports (except those managed by router)
log_info "Checking for orphaned ports..."
NETWORK_ID=$(jq -r '.network.id' "$ARTIFACTS_DIR/openstack_env.json")
PORTS=$(sudo microstack.openstack port list --network "$NETWORK_ID" -f value -c ID 2>/dev/null || true)

if [[ -n "$PORTS" ]]; then
  for port in $PORTS; do
    DEVICE_OWNER=$(sudo microstack.openstack port show "$port" -f value -c device_owner 2>/dev/null || echo "")
    
    # Skip router ports
    if [[ "$DEVICE_OWNER" != *"router"* ]]; then
      log_info "Deleting port: $port"
      sudo microstack.openstack port delete "$port" 2>/dev/null || true
    fi
  done
fi

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

log_info "Cluster destruction completed in ${DURATION}s"

# Update the last run's rollback metrics
TEMP_METRICS=$(mktemp)
jq --argjson rollback_attempted "true" \
   --argjson rollback_success "$ROLLBACK_SUCCESS" \
   '.runs[-1].rollback_attempted = $rollback_attempted | 
    .runs[-1].rollback_success = $rollback_success' \
   "$METRICS_FILE" > "$TEMP_METRICS" 2>/dev/null || echo '{"runs":[]}' > "$TEMP_METRICS"
mv "$TEMP_METRICS" "$METRICS_FILE"

if [[ "$ROLLBACK_SUCCESS" == "true" ]]; then
  log_success "Cluster destruction successful"
  exit 0
else
  log_error "Cluster destruction completed with errors"
  exit 1
fi
