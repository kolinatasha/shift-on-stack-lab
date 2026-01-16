#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ARTIFACTS_DIR="$PROJECT_ROOT/artifacts"
LOG_FILE="$ARTIFACTS_DIR/logs/openstack_up_$(date +%Y%m%d_%H%M%S).log"

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

# Ensure artifacts directory exists
mkdir -p "$ARTIFACTS_DIR/logs"

log_info "Starting OpenStack environment setup..."

# Check if MicroStack is installed
if ! snap list microstack &>/dev/null; then
  log_info "MicroStack not found. Installing..."
  sudo snap install microstack --beta --devmode
  log_success "MicroStack installed"
else
  log_info "MicroStack already installed"
fi

# Initialize MicroStack if not already initialized
if ! sudo microstack.openstack --version &>/dev/null 2>&1; then
  log_info "Initializing MicroStack (this may take 10-15 minutes)..."
  sudo microstack init --auto --control
  log_success "MicroStack initialized"
else
  log_info "MicroStack already initialized"
fi

# Wait for services to be ready
log_info "Waiting for OpenStack services to be ready..."
sleep 10

# Create project and user
PROJECT_NAME="shift-lab"
USER_NAME="shift-user"
USER_PASS="shift-pass-$(date +%s)"

log_info "Creating project: $PROJECT_NAME"
if ! sudo microstack.openstack project show "$PROJECT_NAME" &>/dev/null; then
  sudo microstack.openstack project create --description "Shift-on-Stack Lab" "$PROJECT_NAME"
  log_success "Project created: $PROJECT_NAME"
else
  log_info "Project already exists: $PROJECT_NAME"
fi

log_info "Creating user: $USER_NAME"
if ! sudo microstack.openstack user show "$USER_NAME" &>/dev/null; then
  sudo microstack.openstack user create --project "$PROJECT_NAME" --password "$USER_PASS" "$USER_NAME"
  sudo microstack.openstack role add --project "$PROJECT_NAME" --user "$USER_NAME" member
  log_success "User created: $USER_NAME"
else
  log_info "User already exists: $USER_NAME"
fi

# Create network
NETWORK_NAME="shift-network"
SUBNET_NAME="shift-subnet"
ROUTER_NAME="shift-router"

log_info "Creating network: $NETWORK_NAME"
if ! sudo microstack.openstack network show "$NETWORK_NAME" &>/dev/null; then
  sudo microstack.openstack network create "$NETWORK_NAME"
  log_success "Network created: $NETWORK_NAME"
else
  log_info "Network already exists: $NETWORK_NAME"
fi

log_info "Creating subnet: $SUBNET_NAME"
if ! sudo microstack.openstack subnet show "$SUBNET_NAME" &>/dev/null; then
  sudo microstack.openstack subnet create \
    --network "$NETWORK_NAME" \
    --subnet-range 192.168.100.0/24 \
    --dns-nameserver 8.8.8.8 \
    "$SUBNET_NAME"
  log_success "Subnet created: $SUBNET_NAME"
else
  log_info "Subnet already exists: $SUBNET_NAME"
fi

log_info "Creating router: $ROUTER_NAME"
if ! sudo microstack.openstack router show "$ROUTER_NAME" &>/dev/null; then
  sudo microstack.openstack router create "$ROUTER_NAME"
  sudo microstack.openstack router set --external-gateway external "$ROUTER_NAME"
  sudo microstack.openstack router add subnet "$ROUTER_NAME" "$SUBNET_NAME"
  log_success "Router created: $ROUTER_NAME"
else
  log_info "Router already exists: $ROUTER_NAME"
fi

# Create security group
SECGROUP_NAME="shift-secgroup"

log_info "Creating security group: $SECGROUP_NAME"
if ! sudo microstack.openstack security group show "$SECGROUP_NAME" &>/dev/null; then
  sudo microstack.openstack security group create --description "Shift Lab Security Group" "$SECGROUP_NAME"
  
  # Allow SSH
  sudo microstack.openstack security group rule create --protocol tcp --dst-port 22 "$SECGROUP_NAME"
  # Allow ICMP
  sudo microstack.openstack security group rule create --protocol icmp "$SECGROUP_NAME"
  # Allow HTTP/HTTPS
  sudo microstack.openstack security group rule create --protocol tcp --dst-port 80 "$SECGROUP_NAME"
  sudo microstack.openstack security group rule create --protocol tcp --dst-port 443 "$SECGROUP_NAME"
  # Allow OpenShift API
  sudo microstack.openstack security group rule create --protocol tcp --dst-port 6443 "$SECGROUP_NAME"
  
  log_success "Security group created: $SECGROUP_NAME"
else
  log_info "Security group already exists: $SECGROUP_NAME"
fi

# Upload base image if missing
IMAGE_NAME="cirros-test"
log_info "Checking for base image: $IMAGE_NAME"
if ! sudo microstack.openstack image show "$IMAGE_NAME" &>/dev/null; then
  log_info "Downloading and uploading base image..."
  curl -sL http://download.cirros-cloud.net/0.6.2/cirros-0.6.2-x86_64-disk.img -o /tmp/cirros.img
  sudo microstack.openstack image create \
    --disk-format qcow2 \
    --container-format bare \
    --public \
    --file /tmp/cirros.img \
    "$IMAGE_NAME"
  rm -f /tmp/cirros.img
  log_success "Base image uploaded: $IMAGE_NAME"
else
  log_info "Base image already exists: $IMAGE_NAME"
fi

# Collect resource IDs
log_info "Collecting resource IDs..."
PROJECT_ID=$(sudo microstack.openstack project show "$PROJECT_NAME" -f value -c id)
NETWORK_ID=$(sudo microstack.openstack network show "$NETWORK_NAME" -f value -c id)
SUBNET_ID=$(sudo microstack.openstack subnet show "$SUBNET_NAME" -f value -c id)
ROUTER_ID=$(sudo microstack.openstack router show "$ROUTER_NAME" -f value -c id)
SECGROUP_ID=$(sudo microstack.openstack security group show "$SECGROUP_NAME" -f value -c id)
IMAGE_ID=$(sudo microstack.openstack image show "$IMAGE_NAME" -f value -c id)

# Generate machine-readable output
cat > "$ARTIFACTS_DIR/openstack_env.json" <<EOF
{
  "timestamp": "$(date -Iseconds)",
  "project": {
    "name": "$PROJECT_NAME",
    "id": "$PROJECT_ID"
  },
  "user": {
    "name": "$USER_NAME",
    "password": "$USER_PASS"
  },
  "network": {
    "name": "$NETWORK_NAME",
    "id": "$NETWORK_ID"
  },
  "subnet": {
    "name": "$SUBNET_NAME",
    "id": "$SUBNET_ID",
    "cidr": "192.168.100.0/24"
  },
  "router": {
    "name": "$ROUTER_NAME",
    "id": "$ROUTER_ID"
  },
  "security_group": {
    "name": "$SECGROUP_NAME",
    "id": "$SECGROUP_ID"
  },
  "image": {
    "name": "$IMAGE_NAME",
    "id": "$IMAGE_ID"
  },
  "endpoints": {
    "identity": "http://10.20.20.1:5000/v3",
    "compute": "http://10.20.20.1:8774/v2.1",
    "network": "http://10.20.20.1:9696"
  }
}
EOF

log_success "OpenStack environment ready!"
log_info "Environment details saved to: $ARTIFACTS_DIR/openstack_env.json"
log_info "Next step: make validate"
