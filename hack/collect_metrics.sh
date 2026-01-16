#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ARTIFACTS_DIR="$PROJECT_ROOT/artifacts"
METRICS_FILE="$ARTIFACTS_DIR/metrics.json"

# Logging functions
log_info() {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] INFO: $*"
}

log_info "Collecting metrics from: $METRICS_FILE"

if [[ ! -f "$METRICS_FILE" ]]; then
  log_info "No metrics file found. Creating empty metrics file."
  mkdir -p "$ARTIFACTS_DIR"
  echo '{"runs":[]}' > "$METRICS_FILE"
  exit 0
fi

# Display current metrics
TOTAL_RUNS=$(jq '.runs | length' "$METRICS_FILE")
log_info "Total runs recorded: $TOTAL_RUNS"

if [[ $TOTAL_RUNS -gt 0 ]]; then
  log_info "Latest run:"
  jq -r '.runs[-1] | "  Run ID: \(.run_id)\n  Success: \(.success)\n  Duration: \(.duration_seconds)s\n  Failure: \(.failure_signature // "none")"' "$METRICS_FILE"
fi

log_info "Metrics collection complete"
