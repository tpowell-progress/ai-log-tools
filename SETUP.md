# Quick Setup Guide

Complete setup instructions for using log distillation tools in Claude Desktop and command line.

## 5-Minute Setup

### 1. Get API Tokens

**Buildkite:**
- Go to [buildkite.com/user/api-tokens](https://buildkite.com/user/api-tokens)
- Create a new token
- Copy the token

**GitHub:**
- Go to [github.com/settings/tokens](https://github.com/settings/tokens)
- Create new personal access token (classic)
- Select `actions:read` scope
- Copy the token

### 2. Set Environment Variables

```bash
# Add to ~/.bashrc, ~/.zshrc, or ~/.config/fish/config.fish
export BUILDKITE_TOKEN="bk_..."
export GITHUB_TOKEN="ghp_..."
```

Then reload:
```bash
source ~/.bashrc  # or ~/.zshrc or ~/.config/fish/config.fish
```

### 3. Set Up Claude Desktop

#### Option A: Automatic Setup (Recommended)

```bash
# Navigate to the tools directory
cd /path/to/ai-log-tools

# Update config with absolute path
sed -i 's|SCRIPT_DIR|'"$(pwd)"'|g' logs-distiller.mcp.json

# Apply to global config
./apply_mcp_config.sh logs-distiller.mcp.json

# Verify
./apply_mcp_config.sh --list

# Restart Claude Desktop
```

#### Option B: Manual Setup

1. Open `~/.config/Claude/mcp.json` (or create if doesn't exist)

2. Add the following:
```json
{
  "mcpServers": {
    "logs-distiller": {
      "command": "python3",
      "args": ["/absolute/path/to/logs_distiller_server.py"],
      "env": {
        "BUILDKITE_TOKEN": "bk_...",
        "GITHUB_TOKEN": "ghp_..."
      }
    }
  }
}
```

3. Restart Claude Desktop

### 4. Verify Setup

```bash
# List configured servers
./apply_mcp_config.sh --list

# Should show:
# MCP Servers configured in: ~/.config/Claude/mcp.json
#   logs-distiller:
#     Command: python3
#     Args: /path/to/logs_distiller_server.py
#     Env: BUILDKITE_TOKEN, GITHUB_TOKEN
```

## Usage Examples

### Claude Desktop

Ask Claude to help analyze logs:

```
"Download and analyze the buildkite job 019e7621-8db2-4d3a-8541-d78b910bd808"

"I'm seeing failures in my GitHub Actions workflow. Can you download and analyze run 1234567890 
from owner/repo?"

"Here's a raw buildkite log, can you distill and find the error?"
```

### Command Line

#### Buildkite

```bash
# Download and distill
./download_buildkite_log.sh 019e7621-8db2-4d3a-8541-d78b910bd808

# Custom org/pipeline
./download_buildkite_log.sh myorg mypipeline 019e7621-8db2-4d3a-8541-d78b910bd808 output.txt

# Distill existing log
python3 distill_log.py raw.log > distilled.txt

# Pipe from stdin
cat huge.log | python3 distill_log.py > small.txt
```

#### GitHub Actions

```bash
# Download and distill
./download_github_actions_log.sh myorg myrepo 1234567890

# Using environment variable
export GITHUB_REPO=myorg/myrepo
./download_github_actions_log.sh 1234567890 output.txt

# Distill existing log
python3 distill_github_actions_log.py raw.log > distilled.txt

# Pipe from stdin
cat huge.log | python3 distill_github_actions_log.py > small.txt
```

## File Locations

```
~/.config/Claude/mcp.json           Global MCP configuration (Claude)
~/.bashrc                           Shell environment variables
~/.zshrc                            (for zsh users)
~/.config/fish/config.fish          (for fish users)

./logs-distiller.mcp.json           Config template (this repo)
./logs_distiller_server.py          MCP server (this repo)
./distill_log.py                    Buildkite distiller
./distill_github_actions_log.py     GitHub Actions distiller
```

## Troubleshooting

### "Command not found: distill_log.py"

```bash
# Make sure you're in the right directory
cd /path/to/ai-log-tools

# Or use full path
python3 /path/to/ai-log-tools/distill_log.py raw.log > distilled.txt
```

### "API token not found"

```bash
# Check if variables are set
echo $BUILDKITE_TOKEN
echo $GITHUB_TOKEN

# If empty, add to shell config
echo 'export BUILDKITE_TOKEN="bk_..."' >> ~/.bashrc
source ~/.bashrc
```

### "MCP server not appearing in Claude"

1. Verify config was applied:
   ```bash
   cat ~/.config/Claude/mcp.json
   ```

2. Verify absolute path in config:
   ```bash
   ./apply_mcp_config.sh --status logs-distiller
   ```

3. Restart Claude Desktop completely (not just reload)

4. Check for errors:
   ```bash
   # Try running the server directly
   python3 /path/to/logs_distiller_server.py
   # Should start without errors
   ```

### "curl: command not found"

Install curl:
```bash
# macOS
brew install curl

# Linux (Ubuntu/Debian)
sudo apt-get install curl

# Linux (RedHat/CentOS)
sudo yum install curl
```

### "gh: command not found"

Install gh CLI (optional but recommended for GitHub Actions):
```bash
# macOS
brew install gh

# Linux
https://github.com/cli/cli/blob/trunk/docs/install_linux.md

# Windows
choco install gh
```

## Next Steps

1. **Read the full documentation:**
   - [README.md](README.md) - Overview
   - [MCP_SERVER.md](MCP_SERVER.md) - Claude integration details
   - [MCP_CONFIG_MANAGEMENT.md](MCP_CONFIG_MANAGEMENT.md) - Config manager docs
   - [GITHUB_ACTIONS.md](GITHUB_ACTIONS.md) - GitHub Actions specific

2. **Try it out:**
   - Get a Buildkite job ID and download a log
   - Get a GitHub Actions run ID and analyze it
   - Use Claude to help interpret distilled logs

3. **Integrate into workflow:**
   - Add to CI pipelines for automated log analysis
   - Create aliases for quick distillation
   - Share distilled logs with teammates

## Support

- Check [MCP_CONFIG_MANAGEMENT.md](MCP_CONFIG_MANAGEMENT.md) for config issues
- Check [GITHUB_ACTIONS.md](GITHUB_ACTIONS.md) for GitHub Actions issues
- Check [MCP_SERVER.md](MCP_SERVER.md) for Claude Desktop issues
- See [EXAMPLE.md](EXAMPLE.md) for real-world usage

## Tips

- **Save tokens:** Use distilled logs with AI to save ~95% of tokens
- **Keep both:** Save raw logs for complete history, use distilled for analysis
- **Automate:** Create wrapper scripts for your common use cases
- **Share:** Distilled logs are much easier to share and review
- **Store:** Distilled logs take up ~20x less space

---

**Need help?** Check the full documentation or review the example in [EXAMPLE.md](EXAMPLE.md).
