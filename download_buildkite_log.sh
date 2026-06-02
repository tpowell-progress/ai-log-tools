#!/usr/bin/env bash
# Download and distill Buildkite job logs for efficient analysis
#
# Usage:
#   download_buildkite_log.sh <job_id> [output_file]
#   download_buildkite_log.sh <org> <pipeline> <job_id> [output_file]
#
# Examples:
#   # Download from the default org/pipeline
#   download_buildkite_log.sh 019e7621-8db2-4d3a-8541-d78b910bd808
#
#   # Download from custom org/pipeline
#   download_buildkite_log.sh myorg mypipeline 019e7621-8db2-4d3a-8541-d78b910bd808
#
# Requires:
#   - BK_CHEF_ONLY_2024 environment variable (or other Buildkite API token)
#   - distill_log.py in same directory

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DISTILL_SCRIPT="$SCRIPT_DIR/distill_log.py"

# Default org/pipeline
DEFAULT_ORG="chef"
DEFAULT_PIPELINE="chef-chef-chef-18-validate-adhoc"

# Parse arguments
if [ $# -lt 1 ]; then
    echo "Usage: $0 <job_id> [output_file]"
    echo "   or: $0 <org> <pipeline> <job_id> [output_file]"
    exit 1
fi

if [ $# -eq 1 ] || [ $# -eq 2 ]; then
    ORG="$DEFAULT_ORG"
    PIPELINE="$DEFAULT_PIPELINE"
    JOB_ID="$1"
    OUTPUT="${2:-/tmp/job_${JOB_ID}_distilled.txt}"
elif [ $# -ge 3 ]; then
    ORG="$1"
    PIPELINE="$2"
    JOB_ID="$3"
    OUTPUT="${4:-/tmp/job_${JOB_ID}_distilled.txt}"
fi

# Check for API token
if [ -z "${BK_CHEF_ONLY_2024:-}" ]; then
    echo "Error: BK_CHEF_ONLY_2024 environment variable not set"
    echo "Run: source ~/.env"
    exit 1
fi

# Check for distill script
if [ ! -f "$DISTILL_SCRIPT" ]; then
    echo "Error: distill_log.py not found at $DISTILL_SCRIPT"
    exit 1
fi

echo "Downloading logs for job $JOB_ID..."
echo "Organization: $ORG"
echo "Pipeline: $PIPELINE"

# Download raw log JSON
RAW_LOG="/tmp/raw_log_${JOB_ID}.json"
curl -s "https://api.buildkite.com/v2/organizations/$ORG/pipelines/$PIPELINE/builds/-/jobs/$JOB_ID/log" \
  -H "Authorization: Bearer $BK_CHEF_ONLY_2024" \
  -H "Accept: application/json" > "$RAW_LOG"

# Check if download succeeded
if [ ! -s "$RAW_LOG" ]; then
    echo "Error: Failed to download log"
    exit 1
fi

echo "Extracting and distilling..."

# Extract log content and distill
python3 -c "import json; data=json.load(open('$RAW_LOG')); print(data.get('content', ''))" | \
  python3 "$DISTILL_SCRIPT" > "$OUTPUT"

# Calculate reduction
RAW_LINES=$(python3 -c "import json; data=json.load(open('$RAW_LOG')); print(len(data.get('content', '').split('\n')))")
DIST_LINES=$(wc -l < "$OUTPUT")

if [ "$RAW_LINES" -gt 0 ]; then
    REDUCTION=$(python3 -c "print(f'{(1 - $DIST_LINES/$RAW_LINES)*100:.1f}%')")
    echo "✓ Distilled: $RAW_LINES → $DIST_LINES lines ($REDUCTION reduction)"
else
    echo "✓ Distilled: $DIST_LINES lines"
fi

echo "✓ Saved to: $OUTPUT"

# Cleanup
rm -f "$RAW_LOG"
