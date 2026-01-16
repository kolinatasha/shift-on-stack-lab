#!/usr/bin/env bash
set -euo pipefail

# Automated test suite runner
# Runs multiple installation tests and generates final report

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Configuration
NUM_RUNS=${1:-10}  # Default to 10 runs, or use first argument
DELAY_BETWEEN_RUNS=${2:-30}  # Seconds to wait between runs

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
  echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} INFO: $*"
}

log_success() {
  echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} SUCCESS: $*"
}

log_error() {
  echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} ERROR: $*"
}

log_warning() {
  echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} WARNING: $*"
}

# Banner
cat << "EOF"
╔════════════════════════════════════════════════════════════════════════╗
║              SHIFT-ON-STACK LAB - AUTOMATED TEST SUITE                 ║
╚════════════════════════════════════════════════════════════════════════╝
EOF

log_info "Starting automated test suite"
log_info "Number of runs: $NUM_RUNS"
log_info "Delay between runs: ${DELAY_BETWEEN_RUNS}s"
echo ""

# Check if we're on Ubuntu
if [[ ! -f /etc/os-release ]] || ! grep -q "Ubuntu" /etc/os-release; then
  log_error "This script must run on Ubuntu (MicroStack requirement)"
  exit 1
fi

# Check if already bootstrapped
if [[ ! -f "$PROJECT_ROOT/artifacts/metrics.json" ]]; then
  log_info "Running initial bootstrap..."
  cd "$PROJECT_ROOT"
  make bootstrap || {
    log_error "Bootstrap failed"
    exit 1
  }
  log_success "Bootstrap complete"
fi

# Check if OpenStack is up
if [[ ! -f "$PROJECT_ROOT/artifacts/openstack_env.json" ]]; then
  log_info "OpenStack not detected. Starting OpenStack environment..."
  cd "$PROJECT_ROOT"
  make openstack-up || {
    log_error "OpenStack setup failed"
    exit 1
  }
  log_success "OpenStack setup complete"
  
  log_info "Running validation..."
  make validate || {
    log_error "Validation failed"
    exit 1
  }
  log_success "Validation passed"
else
  log_info "OpenStack environment already running"
fi

echo ""
log_info "═══════════════════════════════════════════════════════════════"
log_info "Starting $NUM_RUNS installation test runs"
log_info "═══════════════════════════════════════════════════════════════"
echo ""

# Track overall statistics
TOTAL_RUNS=0
SUCCESSFUL_RUNS=0
FAILED_RUNS=0
START_TIME=$(date +%s)

# Run the test suite
for i in $(seq 1 "$NUM_RUNS"); do
  echo ""
  log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  log_info "RUN $i of $NUM_RUNS"
  log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  
  RUN_START=$(date +%s)
  
  # Run installation
  cd "$PROJECT_ROOT"
  if make install; then
    log_success "Run $i: Installation successful"
    SUCCESSFUL_RUNS=$((SUCCESSFUL_RUNS + 1))
  else
    log_error "Run $i: Installation failed"
    FAILED_RUNS=$((FAILED_RUNS + 1))
  fi
  
  TOTAL_RUNS=$((TOTAL_RUNS + 1))
  RUN_END=$(date +%s)
  RUN_DURATION=$((RUN_END - RUN_START))
  
  log_info "Run $i completed in ${RUN_DURATION}s"
  
  # Cleanup
  log_info "Cleaning up run $i..."
  make destroy || log_warning "Cleanup had issues (non-fatal)"
  
  # Progress update
  CURRENT_SUCCESS_RATE=$(echo "scale=2; $SUCCESSFUL_RUNS * 100 / $TOTAL_RUNS" | bc)
  log_info "Progress: $TOTAL_RUNS/$NUM_RUNS runs complete (${CURRENT_SUCCESS_RATE}% success rate)"
  
  # Wait before next run (except on last run)
  if [[ $i -lt $NUM_RUNS ]]; then
    log_info "Waiting ${DELAY_BETWEEN_RUNS}s before next run..."
    sleep "$DELAY_BETWEEN_RUNS"
  fi
done

END_TIME=$(date +%s)
TOTAL_DURATION=$((END_TIME - START_TIME))

echo ""
log_info "═══════════════════════════════════════════════════════════════"
log_success "TEST SUITE COMPLETE"
log_info "═══════════════════════════════════════════════════════════════"
echo ""

# Generate final report
log_info "Generating final report..."
cd "$PROJECT_ROOT"
make report

echo ""
log_info "═══════════════════════════════════════════════════════════════"
log_info "FINAL STATISTICS"
log_info "═══════════════════════════════════════════════════════════════"
log_info "Total runs:        $TOTAL_RUNS"
log_info "Successful:        $SUCCESSFUL_RUNS"
log_info "Failed:            $FAILED_RUNS"
log_info "Success rate:      ${CURRENT_SUCCESS_RATE}%"
log_info "Total duration:    ${TOTAL_DURATION}s ($(echo "scale=2; $TOTAL_DURATION / 60" | bc) minutes)"
log_info "Average per run:   $(echo "scale=2; $TOTAL_DURATION / $TOTAL_RUNS" | bc)s"
echo ""
log_info "Reports available at:"
log_info "  - Console output above"
log_info "  - artifacts/report.md"
log_info "  - artifacts/metrics.json"
echo ""

if [[ $FAILED_RUNS -gt 0 ]]; then
  log_warning "Some runs failed. Check artifacts/logs/ for details"
  log_info "Review artifacts/metrics.json for failure signatures"
fi

log_success "Automated test suite complete!"
echo ""
log_info "Next steps:"
log_info "  1. Review artifacts/report.md"
log_info "  2. Check artifacts/logs/ for any failures"
log_info "  3. Update your resume with these metrics!"
echo ""
