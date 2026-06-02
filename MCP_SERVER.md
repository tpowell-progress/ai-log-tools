# Buildkite Log Tools – MCP Integration

Complete suite for efficiently analyzing Buildkite job logs by removing noise while preserving critical error information.

## Quick Start

### 1. Install the MCP Server

```bash
./install_mcp_server.sh
```

This adds the `buildkite-logs` server to your Claude Desktop configuration.

### 2. Set up Buildkite API Token

```bash
export BK_CHEF_ONLY_2024="your-buildkite-token"
# OR
export BUILDKITE_TOKEN="your-buildkite-token"
```

### 3. Restart Claude Desktop

The server will be automatically available as tools in Claude.

## Available Tools

### `download_and_distill_buildkite_log`

Download a Buildkite job log and return distilled content with noise removed.

**Parameters:**
- `job_id` (required): The Buildkite job ID (UUID format, e.g., `019e7621-8db2-4d3a-8541-d78b910bd808`)
- `org` (optional): Organization name (default: `chef`)
- `pipeline` (optional): Pipeline name (default: `chef-chef-chef-18-validate-adhoc`)

**Example:**
```
Ask Claude: "Download and analyze the buildkite job 019e7621-8db2-4d3a-8541-d78b910bd808"
```

### `distill_buildkite_log_text`

Distill raw log text by removing noise (timestamps, UUIDs, progress bars, etc).

**Parameters:**
- `text` (required): Raw log text to distill

**Example:**
```
Paste raw logs and ask Claude to distill them
```

## What Gets Removed

- **Timestamps:** `2026-06-01T11:54:37.466-04:00` → `[TIME]`
- **UUIDs:** `019e7621-8db2-4d3a-8541-d78b910bd808` → `[UUID]`
- **Git SHAs:** `39b18ac3c1` → `[SHA]`
- **Progress bars:** `[===========>    ]` → removed
- **Repetitive output:** Multiple identical "Fetching..." lines → single line
- **ANSI codes:** `\x1b[32m` → removed
- **Empty lines:** Collapsed

## What Gets Kept

- Error messages and warnings
- Stack traces
- Dependency version conflicts
- Command execution output
- Exit codes
- File paths
- Gem/package resolution errors

## Command-Line Usage

If you prefer command-line tools outside of Claude:

### Download and distill a log

```bash
./download_buildkite_log.sh <job_id>

# Example
./download_buildkite_log.sh 019e7621-8db2-4d3a-8541-d78b910bd808

# Custom org/pipeline
./download_buildkite_log.sh myorg mypipeline 019e7621-8db2-4d3a-8541-d78b910bd808
```

### Distill an existing log file

```bash
python3 distill_log.py raw.log > distilled.txt
cat huge.log | python3 distill_log.py > small.txt
```

## Installation & Configuration

### Automatic Installation

```bash
# Install to default location
./install_mcp_server.sh

# Install with custom server directory
./install_mcp_server.sh --server-dir /path/to/server

# Uninstall
./install_mcp_server.sh --remove
```

### Manual Installation

If you prefer to manually configure:

1. **Open** `~/.copilot/mcp-config.json` if it exists, otherwise `~/.config/Claude/mcp.json` (or `~/.mcp/mcp.json`)

2. **Add** the buildkite-logs server:
```json
{
  "mcpServers": {
    "buildkite-logs": {
      "command": "pwsh",
      "args": ["-NoLogo", "-NoProfile", "-File", "/path/to/buildkite_logs_server.ps1"],
      "env": {
        "BK_CHEF_ONLY_2024": "your-api-token"
      }
    }
  }
}
```

3. **Restart** Claude Desktop

## Distillation Example

### Before (11,363 lines)
```
2026-06-01T10:23:45.123Z Fetching gem metadata from https://rubygems.org/
2026-06-01T10:23:46.234Z Fetching gem metadata from https://rubygems.org/
2026-06-01T10:23:47.345Z Fetching gem metadata from https://rubygems.org/
[===========>              ] 45%
[===============>          ] 67%
[======================>   ] 89%
Bundler could not find compatible versions for gem "pry":
  In Gemfile:
    pry (= 0.15.2)
    pry-byebug (< 3.11) was resolved to 3.8.0, which depends on
      pry (~> 0.10)
```

### After (280 lines – 97.5% reduction)
```
Fetching gem metadata from https://rubygems.org/
Bundler could not find compatible versions for gem "pry":
  In Gemfile:
    pry (= 0.15.2)
    pry-byebug (< 3.11) was resolved to 3.8.0, which depends on
      pry (~> 0.10)
```

## Uninstall

```bash
./install_mcp_server.sh --remove
```

Or manually remove the `buildkite-logs` entry from `~/.copilot/mcp-config.json` if present, otherwise `~/.config/Claude/mcp.json` (or `~/.mcp/mcp.json`).

## Troubleshooting

### "Buildkite API token not found"

Set your API token:
```bash
export BK_CHEF_ONLY_2024="your-token"
# OR
export BUILDKITE_TOKEN="your-token"
```

Add to your shell profile (`~/.bashrc`, `~/.zshrc`, etc.) to make it permanent:
```bash
export BK_CHEF_ONLY_2024="your-buildkite-api-token"
```

### "buildkite_logs_server.ps1 not found"

Ensure the script is in the same directory as `install_mcp_server.sh`, or use `--server-dir`:
```bash
./install_mcp_server.sh --server-dir /path/to/scripts
```

### Server not appearing in Claude

1. Verify `mcp.json` was updated correctly
2. Restart Claude Desktop completely
3. Check the configuration location: `~/.copilot/mcp-config.json`, `~/.config/Claude/mcp.json`, or `~/.mcp/mcp.json`

## Architecture

- **`buildkite_logs_server.ps1`** - MCP server implementing the Model Context Protocol
- **`distill_log.py`** - Core distillation logic (reused by both CLI and MCP server)
- **`download_buildkite_log.sh`** - Command-line tool for direct API access
- **`install_mcp_server.sh`** - Automated installer and configuration manager

## Features

✓ **95-98% log reduction** while preserving critical errors  
✓ **Token efficient** for AI analysis  
✓ **No external dependencies** beyond Python 3  
✓ **Easy integration** with Claude Desktop via MCP  
✓ **Command-line tools** for standalone use  
✓ **Automatic installer** for hassle-free setup  

## Requirements

- Python 3.7+
- `curl` (for downloading logs)
- Buildkite API token (from buildkite.com/user/api-tokens)

## Tips

- **For AI analysis:** Use Claude to ask questions about distilled logs—saves ~97% tokens
- **For debugging:** Keep both raw and distilled—raw for complete history, distilled for quick scanning
- **For CI failures:** Download failed job logs and ask Claude to analyze root causes

## License

MIT
