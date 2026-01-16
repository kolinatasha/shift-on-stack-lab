#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ARTIFACTS_DIR="$PROJECT_ROOT/artifacts"
METRICS_FILE="$ARTIFACTS_DIR/metrics.json"
REPORT_FILE="$ARTIFACTS_DIR/report.md"

# Logging functions
log_info() {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] INFO: $*"
}

log_info "Generating installation metrics report..."

if [[ ! -f "$METRICS_FILE" ]]; then
  log_info "No metrics file found. Run 'make install' first."
  exit 1
fi

TOTAL_RUNS=$(jq '.runs | length' "$METRICS_FILE")

if [[ $TOTAL_RUNS -eq 0 ]]; then
  log_info "No runs recorded yet."
  exit 0
fi

# Calculate metrics
SUCCESSFUL_RUNS=$(jq '[.runs[] | select(.success == true)] | length' "$METRICS_FILE")
FAILED_RUNS=$(jq '[.runs[] | select(.success == false)] | length' "$METRICS_FILE")
SUCCESS_RATE=$(echo "scale=2; $SUCCESSFUL_RUNS * 100 / $TOTAL_RUNS" | bc)

# Duration statistics
DURATIONS=$(jq -r '.runs[].duration_seconds' "$METRICS_FILE" | sort -n)
MEAN_DURATION=$(echo "$DURATIONS" | awk '{sum+=$1} END {if (NR>0) print sum/NR; else print 0}')
MEDIAN_DURATION=$(echo "$DURATIONS" | awk '{a[NR]=$1} END {if (NR%2==1) print a[(NR+1)/2]; else print (a[NR/2]+a[NR/2+1])/2}')

# Failure signatures
FAILURE_SIGS=$(jq -r '[.runs[] | select(.failure_signature != "") | .failure_signature] | group_by(.) | map({signature: .[0], count: length}) | sort_by(.count) | reverse' "$METRICS_FILE")

# Rollback statistics
ROLLBACK_ATTEMPTED=$(jq '[.runs[] | select(.rollback_attempted == true)] | length' "$METRICS_FILE")
ROLLBACK_SUCCESSFUL=$(jq '[.runs[] | select(.rollback_success == true)] | length' "$METRICS_FILE")
ROLLBACK_SUCCESS_RATE=0
if [[ $ROLLBACK_ATTEMPTED -gt 0 ]]; then
  ROLLBACK_SUCCESS_RATE=$(echo "scale=2; $ROLLBACK_SUCCESSFUL * 100 / $ROLLBACK_ATTEMPTED" | bc)
fi

# Console output
echo ""
echo "=========================================="
echo "  OpenShift Installation Metrics Report"
echo "=========================================="
echo ""
echo "Total Runs:           $TOTAL_RUNS"
echo "Successful:           $SUCCESSFUL_RUNS"
echo "Failed:               $FAILED_RUNS"
echo "Success Rate:         ${SUCCESS_RATE}%"
echo ""
echo "Duration Statistics:"
echo "  Mean:               ${MEAN_DURATION}s"
echo "  Median:             ${MEDIAN_DURATION}s"
echo ""
echo "Rollback Statistics:"
echo "  Attempted:          $ROLLBACK_ATTEMPTED"
echo "  Successful:         $ROLLBACK_SUCCESSFUL"
echo "  Success Rate:       ${ROLLBACK_SUCCESS_RATE}%"
echo ""
echo "Top Failure Signatures:"
if [[ $(echo "$FAILURE_SIGS" | jq 'length') -gt 0 ]]; then
  echo "$FAILURE_SIGS" | jq -r '.[] | "  \(.signature): \(.count) occurrence(s)"'
else
  echo "  None"
fi
echo ""
echo "=========================================="

# Generate markdown report
cat > "$REPORT_FILE" <<EOF
# OpenShift Installation Metrics Report

Generated: $(date -Iseconds)

## Summary

| Metric | Value |
|--------|-------|
| Total Runs | $TOTAL_RUNS |
| Successful | $SUCCESSFUL_RUNS |
| Failed | $FAILED_RUNS |
| Success Rate | ${SUCCESS_RATE}% |

## Duration Statistics

| Statistic | Value |
|-----------|-------|
| Mean Duration | ${MEAN_DURATION}s |
| Median Duration | ${MEDIAN_DURATION}s |

## Rollback Statistics

| Metric | Value |
|--------|-------|
| Rollback Attempted | $ROLLBACK_ATTEMPTED |
| Rollback Successful | $ROLLBACK_SUCCESSFUL |
| Rollback Success Rate | ${ROLLBACK_SUCCESS_RATE}% |

## Top Failure Signatures

EOF

if [[ $(echo "$FAILURE_SIGS" | jq 'length') -gt 0 ]]; then
  echo "$FAILURE_SIGS" | jq -r '.[] | "- **\(.signature)**: \(.count) occurrence(s)"' >> "$REPORT_FILE"
else
  echo "No failures recorded." >> "$REPORT_FILE"
fi

cat >> "$REPORT_FILE" <<EOF

## Run History

| Run ID | Start Time | Duration | Success | Failure Signature |
|--------|------------|----------|---------|-------------------|
EOF

jq -r '.runs[] | "| \(.run_id) | \(.start_timestamp) | \(.duration_seconds)s | \(.success) | \(.failure_signature // "N/A") |"' "$METRICS_FILE" >> "$REPORT_FILE"

log_info "Report generated: $REPORT_FILE"
log_info "Console summary displayed above"
