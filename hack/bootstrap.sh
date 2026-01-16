#!/usr/bin/env bash
set -euo pipefail

# Logging functions
log_info() {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] INFO: $*"
}

log_error() {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $*" >&2
}

log_success() {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] SUCCESS: $*"
}

# Create artifacts directory structure
log_info "Creating artifacts directory structure..."
mkdir -p artifacts/logs

# Check OS
if [[ ! -f /etc/os-release ]]; then
  log_error "Cannot detect OS. /etc/os-release not found."
  exit 1
fi

source /etc/os-release
log_info "Detected OS: $NAME $VERSION"

if [[ "$ID" != "ubuntu" ]]; then
  log_error "This lab is designed for Ubuntu. Detected: $ID"
  log_error "MicroStack requires Ubuntu for snap installation."
  exit 1
fi

# Check system resources
log_info "Checking system resources..."
total_mem=$(free -g | awk '/^Mem:/{print $2}')
cpu_count=$(nproc)
disk_space=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')

log_info "System resources: ${total_mem}GB RAM, ${cpu_count} CPUs, ${disk_space}GB free disk"

if [[ $total_mem -lt 16 ]]; then
  log_error "Insufficient RAM. Required: 16GB+, Available: ${total_mem}GB"
  exit 1
fi

if [[ $cpu_count -lt 4 ]]; then
  log_error "Insufficient CPUs. Required: 4+, Available: ${cpu_count}"
  exit 1
fi

if [[ $disk_space -lt 100 ]]; then
  log_error "Insufficient disk space. Required: 100GB+, Available: ${disk_space}GB"
  exit 1
fi

log_success "System resources check passed"

# Check for required commands
log_info "Checking for required commands..."
commands=("snap" "jq" "curl")
missing=()

for cmd in "${commands[@]}"; do
  if ! command -v "$cmd" &> /dev/null; then
    missing+=("$cmd")
  fi
done

if [[ ${#missing[@]} -gt 0 ]]; then
  log_info "Installing missing packages: ${missing[*]}"
  sudo apt-get update -qq
  for pkg in "${missing[@]}"; do
    sudo apt-get install -y "$pkg"
  done
fi

log_success "All required commands available"

# Initialize metrics file
log_info "Initializing metrics tracking..."
cat > artifacts/metrics.json <<EOF
{
  "runs": []
}
EOF

log_success "Bootstrap complete!"
log_info "Next step: make openstack-up"
