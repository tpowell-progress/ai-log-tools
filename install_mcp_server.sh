#!/usr/bin/env bash
# Install Buildkite Logs MCP Server
#
# This script adds the buildkite-logs MCP server to the active MCP config.
# It prefers ~/.copilot/mcp-config.json when present, then falls back to the
# existing Claude Desktop locations.
# The server provides tools for downloading and distilling Buildkite job logs.
#
# Usage:
#   ./install_mcp_server.sh
#   ./install_mcp_server.sh --server-dir /custom/path
#   ./install_mcp_server.sh --remove  # Uninstall
#
# Environment variables:
#   MCP_CONFIG_DIR - Custom config directory (default: ~/.config/Claude)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVER_DIR="${SERVER_DIR:-.}"
INSTALL_MODE="add"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --server-dir)
            SERVER_DIR="$2"
            shift 2
            ;;
        --remove)
            INSTALL_MODE="remove"
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--server-dir DIR] [--remove]"
            exit 1
            ;;
    esac
done

# Resolve server directory to absolute path
SERVER_DIR="$(cd "$SERVER_DIR" && pwd)"

# Determine MCP config path
if [ -n "${MCP_CONFIG_DIR:-}" ]; then
    MCP_CONFIG_HOME="$MCP_CONFIG_DIR"
elif [ -f "$HOME/.copilot/mcp-config.json" ]; then
    MCP_JSON="$HOME/.copilot/mcp-config.json"
elif [ -d "$HOME/.config/Claude" ]; then
    MCP_CONFIG_HOME="$HOME/.config/Claude"
else
    MCP_CONFIG_HOME="$HOME/.mcp"
    mkdir -p "$MCP_CONFIG_HOME"
fi

if [ -z "${MCP_JSON:-}" ]; then
    MCP_JSON="$MCP_CONFIG_HOME/mcp.json"
fi

echo "MCP Configuration: $MCP_JSON"
echo "Server Directory: $SERVER_DIR"

# Check for required files
if [ ! -f "$SERVER_DIR/buildkite_logs_server.py" ]; then
    echo "Error: buildkite_logs_server.py not found in $SERVER_DIR"
    exit 1
fi

# Create config directory if needed
if [ -n "${MCP_CONFIG_HOME:-}" ]; then
    mkdir -p "$MCP_CONFIG_HOME"
fi

# Initialize mcp.json if it doesn't exist
if [ ! -f "$MCP_JSON" ]; then
    echo "Creating new MCP configuration..."
    cat > "$MCP_JSON" << 'EOF'
{
  "mcpServers": {}
}
EOF
fi

# Use Python to safely modify JSON
python3 << PYTHON_SCRIPT
import json
import os
import sys
from pathlib import Path

config_path = "$MCP_JSON"
server_dir = "$SERVER_DIR"
mode = "$INSTALL_MODE"

try:
    with open(config_path, 'r') as f:
        config = json.load(f)
except (json.JSONDecodeError, FileNotFoundError):
    config = {"mcpServers": {}}

if "mcpServers" not in config:
    config["mcpServers"] = {}

server_config = {
    "command": "python3",
    "args": [os.path.join(server_dir, "buildkite_logs_server.py")],
    "env": {
        "BK_CHEF_ONLY_2024": os.environ.get("BK_CHEF_ONLY_2024", ""),
        "BUILDKITE_TOKEN": os.environ.get("BUILDKITE_TOKEN", ""),
    },
}

# Remove empty env vars
server_config["env"] = {k: v for k, v in server_config["env"].items() if v}

if mode == "add":
    config["mcpServers"]["buildkite-logs"] = server_config
    print("✓ Added buildkite-logs server to MCP configuration")
elif mode == "remove":
    if "buildkite-logs" in config["mcpServers"]:
        del config["mcpServers"]["buildkite-logs"]
        print("✓ Removed buildkite-logs server from MCP configuration")
    else:
        print("✗ buildkite-logs server not found in configuration")
        sys.exit(1)

# Write config back
with open(config_path, 'w') as f:
    json.dump(config, f, indent=2)

print(f"✓ Updated {config_path}")
PYTHON_SCRIPT

if [ $? -ne 0 ]; then
    echo "Error: Failed to update MCP configuration"
    exit 1
fi

if [ "$INSTALL_MODE" = "add" ]; then
    echo ""
    echo "Setup complete! Next steps:"
    echo "1. Ensure Buildkite API token is set:"
    echo "   export BK_CHEF_ONLY_2024='your-token'"
    echo "   # OR"
    echo "   export BUILDKITE_TOKEN='your-token'"
    echo ""
    echo "2. Restart Claude Desktop for changes to take effect"
    echo ""
    echo "Available tools:"
    echo "  • download_and_distill_buildkite_log - Download and distill a job log"
    echo "  • distill_buildkite_log_text - Distill raw log text"
else
    echo ""
    echo "Uninstall complete!"
fi
