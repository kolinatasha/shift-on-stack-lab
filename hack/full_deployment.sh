#!/usr/bin/env bash
set -euo pipefail

# Full deployment automation script
# Runs complete deployment from scratch to final report

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
  echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $*"
}

log_success() {
  echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} ✓ $*"
}

# Banner
cat << "EOF"
╔════════════════════════════════════════════════════════════════════════╗
║           SHIFT-ON-STACK LAB - FULL DEPLOYMENT AUTOMATION              ║
╚════════════════════════════════════════════════════════════════════════╝

This script will:
  1. Bootstrap the environment
  2. Deploy OpenStack (MicroStack)
  3. Validate the setup
  4. Run 10 installation tests
  5. Generate final report

Estimated time: 2-3 hours
Press Ctrl+C to cancel, or Enter to continue...
EOF

read -r

cd "$PROJECT_ROOT"

# Phase 1: Bootstrap
log_info "Phase 1/5: Bootstrapping environment..."
make bootstrap
log_success "Bootstrap complete"
echo ""

# Phase 2: OpenStack Setup
log_info "Phase 2/5: Setting up OpenStack (this may take 15-30 minutes)..."
make openstack-up
log_success "OpenStack setup complete"
echo ""

# Phase 3: Validation
log_info "Phase 3/5: Validating OpenStack environment..."
make validate
log_success "Validation passed"
echo ""

# Phase 4: Test Suite
log_info "Phase 4/5: Running 10 installation tests (this will take 1-2 hours)..."
bash "$SCRIPT_DIR/run_test_suite.sh" 10 30
log_success "Test suite complete"
echo ""

# Phase 5: Final Report
log_info "Phase 5/5: Generating final report..."
make report
log_success "Report generated"
echo ""

# Summary
cat << "EOF"
╔════════════════════════════════════════════════════════════════════════╗
║                        DEPLOYMENT COMPLETE!                            ║
╚════════════════════════════════════════════════════════════════════════╝

Your results are ready:
  📊 artifacts/report.md - Detailed metrics report
  📈 artifacts/metrics.json - Raw metrics data
  📝 artifacts/logs/ - All execution logs

Next steps:
  1. Review artifacts/report.md for your success rate
  2. Update your resume with the metrics
  3. Share the GitHub repo: https://github.com/kolinatasha/shift-on-stack-lab

To cleanup:
  make destroy && make openstack-down

EOF
