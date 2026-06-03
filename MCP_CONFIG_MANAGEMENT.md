# MCP Configuration Management

Global configuration tool for managing multiple MCP (Model Context Protocol) servers in Claude Desktop.

## Quick Start

### Apply Logs Distiller Server

```bash
# Update the config file with your script directory
sed -i 's|SCRIPT_DIR|'"$(pwd)"'|g' logs-distiller.mcp.json

# Apply to global config
./apply_mcp_config.sh logs-distiller.mcp.json
```

### List All Servers

```bash
./apply_mcp_config.sh --list
```

### Check Server Status

```bash
./apply_mcp_config.sh --status logs-distiller
```

## Config File Format

MCP config files are simple JSON documents:

```json
{
  "name": "my-server",
  "command": "python3",
  "args": ["/path/to/server.py"],
  "env": {
    "API_TOKEN": "${MY_API_TOKEN}",
    "DEBUG": "false"
  }
}
```

**Fields:**
- `name` (required): Server name for configuration
- `command` (required): Executable to run
- `args` (required): Array of arguments
- `env` (optional): Environment variables (supports `${VAR}` substitution)

### Environment Variable Substitution

Use `${VAR_NAME}` in config files to reference shell environment variables:

```json
{
  "name": "my-server",
  "env": {
    "API_KEY": "${MY_API_KEY}",
    "GITHUB_TOKEN": "${GITHUB_TOKEN}",
    "DEBUG": "false"
  }
}
```

When applied, `${MY_API_KEY}` is replaced with the value of the `MY_API_KEY` environment variable.

## Usage

### Apply a Server

```bash
./apply_mcp_config.sh my-server.mcp.json
```

**What happens:**
1. Reads the JSON config file
2. Expands environment variables (e.g., `${TOKEN}`)
3. Adds/updates the server in global MCP config
4. Removes the `name` field (not part of MCP spec)
5. Writes changes to `~/.config/Claude/mcp.json` or `~/.mcp/mcp.json`

### Remove a Server

```bash
./apply_mcp_config.sh my-server.mcp.json --remove
```

Or if you don't have the config file:

```bash
./apply_mcp_config.sh --list
# Manually remove from the output
```

### List All Servers

```bash
./apply_mcp_config.sh --list
```

Shows all configured servers with their commands and environment variables.

### Check Specific Server

```bash
./apply_mcp_config.sh --status server-name
```

Displays full configuration for a specific server.

### View Help

```bash
./apply_mcp_config.sh --help
```

## Working with Multiple Servers

### Create Config Files

Create separate `.mcp.json` files for each server:

```bash
# logs-distiller.mcp.json
{
  "name": "logs-distiller",
  "command": "python3",
  "args": ["${HOME}/tools/logs_distiller_server.py"],
  "env": {
    "BUILDKITE_TOKEN": "${BUILDKITE_TOKEN}",
    "GITHUB_TOKEN": "${GITHUB_TOKEN}"
  }
}

# my-custom-tool.mcp.json
{
  "name": "my-custom-tool",
  "command": "node",
  "args": ["${HOME}/tools/my-tool.js"],
  "env": {
    "API_KEY": "${CUSTOM_API_KEY}"
  }
}
```

### Apply All Servers

```bash
for config in *.mcp.json; do
    ./apply_mcp_config.sh "$config"
done
```

### Update Environment Variables

Edit your shell profile:

```bash
# ~/.bashrc or ~/.zshrc
export BUILDKITE_TOKEN="bk_..."
export GITHUB_TOKEN="ghp_..."
export CUSTOM_API_KEY="key_..."
```

Then reapply configurations:

```bash
source ~/.bashrc  # or ~/.zshrc
for config in *.mcp.json; do
    ./apply_mcp_config.sh "$config"
done
```

## Config Directory

The tool automatically detects and uses:

1. `~/.config/Claude/mcp.json` (Claude Desktop standard)
2. `~/.mcp/mcp.json` (fallback)

Override with environment variable:

```bash
export MCP_CONFIG_DIR="$HOME/.config/my-mcp"
./apply_mcp_config.sh my-server.mcp.json
```

## Example Workflows

### Logs Distiller Setup

```bash
# 1. Update config with absolute path
sed -i 's|SCRIPT_DIR|'"$(pwd)"'|g' logs-distiller.mcp.json

# 2. Set required tokens
export BUILDKITE_TOKEN="bk_..."
export GITHUB_TOKEN="ghp_..."

# 3. Apply configuration
./apply_mcp_config.sh logs-distiller.mcp.json

# 4. List to verify
./apply_mcp_config.sh --list

# 5. Restart Claude Desktop
```

### Add Multiple Servers

```bash
# Create config files
mkdir -p ~/.mcp-configs

cat > ~/.mcp-configs/logs-distiller.mcp.json << 'EOF'
{
  "name": "logs-distiller",
  "command": "python3",
  "args": ["/path/to/logs_distiller_server.py"],
  "env": {
    "BUILDKITE_TOKEN": "${BUILDKITE_TOKEN}",
    "GITHUB_TOKEN": "${GITHUB_TOKEN}"
  }
}
EOF

cat > ~/.mcp-configs/my-tool.mcp.json << 'EOF'
{
  "name": "my-tool",
  "command": "node",
  "args": ["/path/to/tool.js"],
  "env": {
    "API_KEY": "${CUSTOM_API_KEY}"
  }
}
EOF

# Set environment variables
export BUILDKITE_TOKEN="bk_..."
export GITHUB_TOKEN="ghp_..."
export CUSTOM_API_KEY="key_..."

# Apply all
for config in ~/.mcp-configs/*.mcp.json; do
    ./apply_mcp_config.sh "$config"
done

# Verify
./apply_mcp_config.sh --list
```

### Update a Server

```bash
# Edit the config file
vim logs-distiller.mcp.json

# Reapply
./apply_mcp_config.sh logs-distiller.mcp.json

# Verify
./apply_mcp_config.sh --status logs-distiller

# Restart Claude Desktop
```

### Remove a Server

```bash
# Option 1: Using config file
./apply_mcp_config.sh logs-distiller.mcp.json --remove

# Option 2: Verify removal
./apply_mcp_config.sh --list
```

## Troubleshooting

### "Config file not found"

Ensure the `.mcp.json` file exists and path is correct:

```bash
ls -la logs-distiller.mcp.json
./apply_mcp_config.sh ./logs-distiller.mcp.json
```

### "Config file must have a 'name' field"

Add a `name` field to your config:

```json
{
  "name": "my-server",
  "command": "python3",
  "args": ["/path/to/server.py"]
}
```

### "Server not appearing in Claude"

1. Verify config was applied:
   ```bash
   ./apply_mcp_config.sh --list
   ```

2. Check the MCP config file:
   ```bash
   cat ~/.config/Claude/mcp.json
   ```

3. Restart Claude Desktop completely

4. Try environment variable substitution:
   ```bash
   echo "BUILDKITE_TOKEN=$BUILDKITE_TOKEN"
   echo "GITHUB_TOKEN=$GITHUB_TOKEN"
   ```

### Environment Variables Not Expanding

Ensure variables are exported:

```bash
export BUILDKITE_TOKEN="value"  # ✓ Will expand
BUILDKITE_TOKEN="value"          # ✗ Won't expand
```

Verify before applying:

```bash
echo ${BUILDKITE_TOKEN}
./apply_mcp_config.sh config.mcp.json
```

## Best Practices

1. **Store configs in version control:**
   ```bash
   git add *.mcp.json
   git commit -m "Add MCP server configs"
   ```

2. **Use environment variables for secrets:**
   ```json
   {
     "name": "my-server",
     "env": {
      "API_KEY": "${SENSITIVE_API_KEY}"
    }
   }
   ```

3. **Document required tokens:**
   ```bash
   # Add to project README
   export BUILDKITE_TOKEN="bk_..."  # From buildkite.com/user/api-tokens
   export GITHUB_TOKEN="ghp_..."    # From github.com/settings/tokens
   ```

4. **Keep config directory clean:**
   ```bash
   mkdir ~/.mcp-configs
   mv *.mcp.json ~/.mcp-configs/
   ```

5. **Backup original config:**
   ```bash
   cp ~/.config/Claude/mcp.json ~/.config/Claude/mcp.json.backup
   ```

## Architecture

The tool uses Python's `json` module to:
- Parse and validate config files
- Expand environment variables with `${VAR}` syntax
- Merge configs into global MCP file
- Format output for readability

Supports all standard JSON operations:
- Adding new servers
- Updating existing servers
- Removing servers
- Listing current configuration

## License

MIT
