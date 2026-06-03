#!/usr/bin/env bash
# Download and distill GitHub Actions workflow run logs
#
# Usage:
#   download_github_actions_log.sh <owner> <repo> <run_id> [output_file]
#   download_github_actions_log.sh <run_id>  # Uses GITHUB_REPO env var
#
# Examples:
#   # Download with owner/repo
#   download_github_actions_log.sh myorg myrepo 1234567890
#
#   # Download using environment variable (export GITHUB_REPO=myorg/myrepo)
#   download_github_actions_log.sh 1234567890
#
# Requires:
#   - GITHUB_TOKEN environment variable (or GH_TOKEN)
#   - distill_github_actions_log.py in same directory
#   - gh CLI (optional, falls back to curl)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DISTILL_SCRIPT="$SCRIPT_DIR/distill_github_actions_log.py"

# Parse arguments
if [ $# -lt 1 ]; then
    echo "Usage: $0 <owner> <repo> <run_id> [output_file]"
    echo "   or: $0 <run_id>  # Uses GITHUB_REPO env var"
    exit 1
fi

if [ $# -eq 1 ] || [ $# -eq 2 ]; then
    # Format: run_id [output_file]
    if [ -z "${GITHUB_REPO:-}" ]; then
        echo "Error: GITHUB_REPO not set"
        echo "Run: export GITHUB_REPO=owner/repo"
        exit 1
    fi
    
    OWNER="${GITHUB_REPO%/*}"
    REPO="${GITHUB_REPO#*/}"
    RUN_ID="$1"
    OUTPUT="${2:-/tmp/run_${RUN_ID}_distilled.txt}"
elif [ $# -ge 3 ]; then
    # Format: owner repo run_id [output_file]
    OWNER="$1"
    REPO="$2"
    RUN_ID="$3"
    OUTPUT="${4:-/tmp/run_${RUN_ID}_distilled.txt}"
fi

# Check for API token
if [ -z "${GITHUB_TOKEN:-${GH_TOKEN:-}}" ]; then
    echo "Error: GITHUB_TOKEN environment variable not set"
    echo "Run: export GITHUB_TOKEN='your-token'"
    exit 1
fi

# Check for distill script
if [ ! -f "$DISTILL_SCRIPT" ]; then
    echo "Error: distill_github_actions_log.py not found at $DISTILL_SCRIPT"
    exit 1
fi

TOKEN="${GITHUB_TOKEN:-${GH_TOKEN}}"

echo "Downloading logs for run $RUN_ID..."
echo "Repository: $OWNER/$REPO"

# Download raw log
RAW_LOG="/tmp/raw_log_${RUN_ID}.txt"

# Use gh CLI if available, otherwise fall back to curl
if command -v gh &> /dev/null; then
    gh run view "$RUN_ID" --repo "$OWNER/$REPO" --log > "$RAW_LOG" 2>/dev/null || {
        echo "Error: Failed to download log using gh CLI"
        exit 1
    }
else
    # Fall back to curl + GitHub API
    curl -s \
      "https://api.github.com/repos/$OWNER/$REPO/actions/runs/$RUN_ID/attempts/1/logs" \
      -H "Authorization: Bearer $TOKEN" \
      -H "Accept: application/vnd.github.v3.raw" \
      -L > "$RAW_LOG"
fi

# Check if download succeeded
if [ ! -s "$RAW_LOG" ]; then
    echo "Error: Failed to download log"
    rm -f "$RAW_LOG"
    exit 1
fi

echo "Extracting and distilling..."

# Distill the log
python3 "$DISTILL_SCRIPT" "$RAW_LOG" > "$OUTPUT"

# Calculate reduction
RAW_LINES=$(wc -l < "$RAW_LOG")
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
