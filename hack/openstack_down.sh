#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ARTIFACTS_DIR="$PROJECT_ROOT/artifacts"
LOG_FILE="$ARTIFACTS_DIR/logs/openstack_down_$(date +%Y%m%d_%H%M%S).log"

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

log_info "Starting OpenStack environment cleanup..."

# Check if environment file exists
if [[ ! -f "$ARTIFACTS_DIR/openstack_env.json" ]]; then
  log_error "Environment file not found: $ARTIFACTS_DIR/openstack_env.json"
  log_error "Cannot determine resources to clean up"
  exit 1
fi

# Extract resource names
PROJECT_NAME=$(jq -r '.project.name' "$ARTIFACTS_DIR/openstack_env.json")
NETWORK_NAME=$(jq -r '.network.name' "$ARTIFACTS_DIR/openstack_env.json")
SUBNET_NAME=$(jq -r '.subnet.name' "$ARTIFACTS_DIR/openstack_env.json")
ROUTER_NAME=$(jq -r '.router.name' "$ARTIFACTS_DIR/openstack_env.json")
SECGROUP_NAME=$(jq -r '.security_group.name' "$ARTIFACTS_DIR/openstack_env.json")
USER_NAME=$(jq -r '.user.name' "$ARTIFACTS_DIR/openstack_env.json")

log_info "Cleaning up resources for project: $PROJECT_NAME"

# Delete any running instances in the project
log_info "Checking for running instances..."
INSTANCES=$(sudo microstack.openstack server list --project "$PROJECT_NAME" -f value -c ID 2>/dev/null || true)
if [[ -n "$INSTANCES" ]]; then
  for instance in $INSTANCES; do
    log_info "Deleting instance: $instance"
    sudo microstack.openstack server delete "$instance" || true
  done
  sleep 5
fi

# Remove router interface
log_info "Removing router interface..."
if sudo microstack.openstack router show "$ROUTER_NAME" &>/dev/null; then
  sudo microstack.openstack router remove subnet "$ROUTER_NAME" "$SUBNET_NAME" 2>/dev/null || true
  sudo microstack.openstack router delete "$ROUTER_NAME" || true
  log_success "Router deleted: $ROUTER_NAME"
fi

# Delete subnet
log_info "Deleting subnet: $SUBNET_NAME"
if sudo microstack.openstack subnet show "$SUBNET_NAME" &>/dev/null; then
  sudo microstack.openstack subnet delete "$SUBNET_NAME" || true
  log_success "Subnet deleted: $SUBNET_NAME"
fi

# Delete network
log_info "Deleting network: $NETWORK_NAME"
if sudo microstack.openstack network show "$NETWORK_NAME" &>/dev/null; then
  sudo microstack.openstack network delete "$NETWORK_NAME" || true
  log_success "Network deleted: $NETWORK_NAME"
fi

# Delete security group
log_info "Deleting security group: $SECGROUP_NAME"
if sudo microstack.openstack security group show "$SECGROUP_NAME" &>/dev/null; then
  sudo microstack.openstack security group delete "$SECGROUP_NAME" || true
  log_success "Security group deleted: $SECGROUP_NAME"
fi

# Delete user
log_info "Deleting user: $USER_NAME"
if sudo microstack.openstack user show "$USER_NAME" &>/dev/null; then
  sudo microstack.openstack user delete "$USER_NAME" || true
  log_success "User deleted: $USER_NAME"
fi

# Delete project
log_info "Deleting project: $PROJECT_NAME"
if sudo microstack.openstack project show "$PROJECT_NAME" &>/dev/null; then
  sudo microstack.openstack project delete "$PROJECT_NAME" || true
  log_success "Project deleted: $PROJECT_NAME"
fi

log_success "OpenStack environment cleanup complete!"
log_info "Note: MicroStack itself is still installed. To remove: sudo snap remove microstack"
