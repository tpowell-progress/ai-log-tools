#!/usr/bin/env bash
# Global MCP Configuration Manager
#
# Applies, updates, and manages MCP server configurations in ~/.mcp.json or
# ~/.config/Claude/mcp.json
#
# Usage:
#   apply_mcp_config.sh <config_file> [--install-all|--remove]
#   apply_mcp_config.sh --list
#   apply_mcp_config.sh --status <server_name>
#
# Examples:
#   # Apply a single MCP server config
#   apply_mcp_config.sh ./buildkite-logs.mcp.json
#
#   # Remove a server
#   apply_mcp_config.sh ./buildkite-logs.mcp.json --remove
#
#   # List all configured servers
#   apply_mcp_config.sh --list
#
# Config file format (JSON):
#   {
#     "name": "buildkite-logs",
#     "command": "python3",
#     "args": ["/path/to/server.py"],
#     "env": {
#       "API_TOKEN": "value"
#     }
#   }

set -euo pipefail

OPERATION="apply"
CONFIG_FILE=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --list)
            OPERATION="list"
            shift
            ;;
        --status)
            OPERATION="status"
            STATUS_SERVER="$2"
            shift 2
            ;;
        --remove)
            OPERATION="remove"
            shift
            ;;
        --install-all)
            OPERATION="install_all"
            shift
            ;;
        -h|--help)
            cat << 'EOF'
Global MCP Configuration Manager

Usage:
  apply_mcp_config.sh <config_file> [--remove]
  apply_mcp_config.sh --list
  apply_mcp_config.sh --status <server_name>
  apply_mcp_config.sh --help

Options:
  --remove          Remove the server instead of adding/updating it
  --list            List all configured MCP servers
  --status SERVER   Show status of a specific server
  --help            Show this help message

Environment Variables:
  MCP_CONFIG_DIR    Custom config directory (default: ~/.config/Claude or ~/.mcp)

Config File Format (JSON):
  {
    "name": "my-server",
    "command": "python3",
    "args": ["/path/to/server.py"],
    "env": {
      "API_TOKEN": "${API_TOKEN}"
    }
  }

Note: Environment variables in the config can reference shell variables using ${VAR_NAME}
EOF
            exit 0
            ;;
        *)
            if [ -z "$CONFIG_FILE" ] && [ ! "$OPERATION" = "list" ] && [ ! "$OPERATION" = "status" ]; then
                CONFIG_FILE="$1"
            fi
            shift
            ;;
    esac
done

# Determine MCP config directory
if [ -n "${MCP_CONFIG_DIR:-}" ]; then
    MCP_CONFIG_HOME="$MCP_CONFIG_DIR"
elif [ -d "$HOME/.config/Claude" ]; then
    MCP_CONFIG_HOME="$HOME/.config/Claude"
else
    MCP_CONFIG_HOME="$HOME/.mcp"
fi

MCP_JSON="$MCP_CONFIG_HOME/mcp.json"

# Create config directory if needed
mkdir -p "$MCP_CONFIG_HOME"

# Initialize mcp.json if it doesn't exist
if [ ! -f "$MCP_JSON" ]; then
    echo "Creating new MCP configuration at $MCP_JSON"
    cat > "$MCP_JSON" << 'EOF'
{
  "mcpServers": {}
}
EOF
fi

# Handle operations
case "$OPERATION" in
    list)
        echo "MCP Servers configured in: $MCP_JSON"
        echo ""
        python3 << 'PYTHON'
import json
import sys
from pathlib import Path

config_file = "$MCP_JSON"
try:
    with open(config_file) as f:
        config = json.load(f)
    
    servers = config.get("mcpServers", {})
    if not servers:
        print("No MCP servers configured")
        sys.exit(0)
    
    for name, server_config in servers.items():
        print(f"  {name}:")
        if "command" in server_config:
            print(f"    Command: {server_config['command']}")
        if "args" in server_config:
            print(f"    Args: {' '.join(server_config['args'])}")
        if "env" in server_config:
            print(f"    Env: {', '.join(server_config['env'].keys())}")
        print()
except Exception as e:
    print(f"Error: {e}", file=sys.stderr)
    sys.exit(1)
PYTHON
        ;;
    
    status)
        python3 << PYTHON
import json
import sys
from pathlib import Path

config_file = "$MCP_JSON"
server_name = "$STATUS_SERVER"

try:
    with open(config_file) as f:
        config = json.load(f)
    
    servers = config.get("mcpServers", {})
    if server_name not in servers:
        print(f"Server '{server_name}' not found in configuration")
        sys.exit(1)
    
    server = servers[server_name]
    print(f"Server: {server_name}")
    print(f"Status: Configured")
    print(json.dumps(server, indent=2))
except Exception as e:
    print(f"Error: {e}", file=sys.stderr)
    sys.exit(1)
PYTHON
        ;;
    
    apply|remove)
        if [ -z "$CONFIG_FILE" ]; then
            echo "Error: Config file required for apply/remove operations"
            echo "Usage: apply_mcp_config.sh <config_file> [--remove]"
            exit 1
        fi
        
        if [ ! -f "$CONFIG_FILE" ]; then
            echo "Error: Config file not found: $CONFIG_FILE"
            exit 1
        fi
        
        python3 << PYTHON_SCRIPT
import json
import os
import sys
import re
from pathlib import Path

config_file = "$CONFIG_FILE"
mcp_json = "$MCP_JSON"
operation = "$OPERATION"

def expand_env_vars(obj):
    """Recursively expand ${VAR} style env vars in a config object."""
    if isinstance(obj, dict):
        return {k: expand_env_vars(v) for k, v in obj.items()}
    elif isinstance(obj, list):
        return [expand_env_vars(item) for item in obj]
    elif isinstance(obj, str):
        # Replace ${VAR_NAME} with environment variable value
        def replace_var(match):
            var_name = match.group(1)
            return os.environ.get(var_name, match.group(0))
        return re.sub(r'\$\{([^}]+)\}', replace_var, obj)
    else:
        return obj

try:
    # Load server config
    with open(config_file) as f:
        server_config = json.load(f)
    
    if not isinstance(server_config, dict):
        print("Error: Config file must contain a JSON object")
        sys.exit(1)
    
    server_name = server_config.get("name")
    if not server_name:
        print("Error: Config file must have a 'name' field")
        sys.exit(1)
    
    # Load global MCP config
    with open(mcp_json) as f:
        global_config = json.load(f)
    
    if "mcpServers" not in global_config:
        global_config["mcpServers"] = {}
    
    if operation == "apply":
        # Expand environment variables
        server_config_expanded = expand_env_vars(server_config)
        
        # Remove 'name' field from the server config (not part of MCP spec)
        server_config_expanded.pop("name", None)
        
        # Add or update the server
        global_config["mcpServers"][server_name] = server_config_expanded
        print(f"✓ Added/updated server '{server_name}'")
    
    elif operation == "remove":
        if server_name not in global_config["mcpServers"]:
            print(f"✗ Server '{server_name}' not found in configuration")
            sys.exit(1)
        
        del global_config["mcpServers"][server_name]
        print(f"✓ Removed server '{server_name}'")
    
    # Write config back
    with open(mcp_json, 'w') as f:
        json.dump(global_config, f, indent=2)
    
    print(f"✓ Updated {mcp_json}")

except json.JSONDecodeError as e:
    print(f"Error: Invalid JSON in config file: {e}", file=sys.stderr)
    sys.exit(1)
except Exception as e:
    print(f"Error: {e}", file=sys.stderr)
    sys.exit(1)
PYTHON_SCRIPT
        
        if [ $? -eq 0 ] && [ "$OPERATION" = "apply" ]; then
            echo ""
            echo "Setup complete! Restart Claude Desktop for changes to take effect."
        fi
        ;;
    
    *)
        echo "Unknown operation: $OPERATION"
        exit 1
        ;;
esac
