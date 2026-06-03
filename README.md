# Log Distillation Tools

Complete suite for efficiently analyzing logs by removing noise while preserving critical error information.

**Supports:** Buildkite + GitHub Actions  
**Available as:** CLI tools + Unified Claude Desktop MCP Server

## Quick Start

### Option 1: Claude Desktop (Recommended)

See [MCP_SERVER.md](MCP_SERVER.md) for full setup:

```bash
# Prepare the config
sed -i 's|SCRIPT_DIR|'"$(pwd)"'|g' logs-distiller.mcp.json

# Apply to global config
./apply_mcp_config.sh logs-distiller.mcp.json

# Verify
./apply_mcp_config.sh --list

# Restart Claude Desktop
```

### Option 2: Command Line

**distill_log** (Python/PowerShell/Bash) reduces log volume by ~95-98% while keeping what matters:
- ✓ Error messages and stack traces
- ✓ Dependency conflicts
- ✓ Command output and exit codes
- ✓ File paths and line numbers

#### Buildkite (PowerShell - Windows)

```powershell
# Download and distill a Buildkite job log from URL
.\download_buildkite_log.ps1 'https://buildkite.com/org/pipeline/builds/123'

# Example with specific job
.\download_buildkite_log.ps1 'https://buildkite.com/chef-oss/chef-chef-main-verify/builds/23274/canvas?sid=019e65e5-4043-4079-b1ec-bce7c586e1a2'
```

#### Buildkite (Bash/Linux/Mac)

```bash
# Download and distill a Buildkite job log
./download_buildkite_log.sh <job_id>

# Example
./download_buildkite_log.sh 019e7621-8db2-4d3a-8541-d78b910bd808
```

#### Distill an existing Buildkite log file

**PowerShell:**
```powershell
.\distill_log.ps1 raw.log > distilled.txt
Get-Content huge.log | .\distill_log.ps1 > small.txt
```

**Python/Bash:**
```bash
python3 distill_log.py raw.log > distilled.txt
cat huge.log | python3 distill_log.py > small.txt
```

#### GitHub Actions

```bash
# Download and distill a GitHub Actions run
./download_github_actions_log.sh <owner> <repo> <run_id>

# Example
./download_github_actions_log.sh myorg myrepo 1234567890

# Distill existing log
python3 distill_github_actions_log.py raw.log > distilled.txt
cat huge.log | python3 distill_github_actions_log.py > small.txt
```

#### Custom output location (PowerShell)

```powershell
.\download_buildkite_log.ps1 'https://buildkite.com/org/pipeline/builds/123' -OutputFile 'C:\logs\distilled.txt'
```

## Problem

Logs are massive with lots of noise:
- Timestamps on every line
- UUIDs, hashes, IDs
- Progress bars and spinners
- Repetitive fetch attempts
- ANSI color codes
- GitHub Actions markers

This makes logs token-inefficient for AI and hard for humans to scan.

## Solution

Unified distiller reduces log volume by **90-98%** while keeping what matters:
- ✓ Error messages and stack traces
- ✓ Dependency conflicts
- ✓ Command output and exit codes
- ✓ File paths and line numbers
- ✓ Test failures
- ✓ Exception details

**Examples:**
- Buildkite: 11,363 lines → 280 lines (97.5% reduction)
- GitHub Actions: 8,450 lines → 120 lines (98.6% reduction)

## Setup

### Requirements

- Python 3.7+
- PowerShell 7+ (optional, for Windows PowerShell scripts)
- `curl` (for downloading logs)
- Buildkite API token (from [buildkite.com/user/api-tokens](https://buildkite.com/user/api-tokens))
- GitHub API token (from [github.com/settings/tokens](https://github.com/settings/tokens)) - optional
- `gh` CLI (optional, for GitHub Actions)

### PowerShell (Windows)

1. **Install dependencies:** None! Uses .NET Framework built-ins.

2. **Set up Buildkite API token:**
   ```powershell
   $env:BK_API_TOKEN = 'your-api-token'
   # Or add to your PowerShell profile for persistence
   ```

3. **Make scripts executable:**
   ```powershell
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
   ```

### Python/Bash (Linux/Mac)

1. **Install dependencies:** None! Uses standard Python 3 libraries.

2. **Set up Buildkite API token:**
   ```bash
   export BK_API_TOKEN="your-api-token"
   # Or source from ~/.env
   ```

3. **Make scripts executable:**
   ```bash
   chmod +x distill_log.py download_buildkite_log.sh download_github_actions_log.sh
   ```

### Installation

```bash
# Set up API tokens
export BUILDKITE_TOKEN="your-buildkite-token"
export GITHUB_TOKEN="your-github-token"

# Add to ~/.bashrc or ~/.zshrc for persistence
echo 'export BUILDKITE_TOKEN="..."' >> ~/.bashrc
echo 'export GITHUB_TOKEN="..."' >> ~/.bashrc
```

## Documentation

- **[MCP_SERVER.md](MCP_SERVER.md)** - Claude Desktop integration setup
- **[MCP_CONFIG_MANAGEMENT.md](MCP_CONFIG_MANAGEMENT.md)** - Global MCP config tool documentation
- **[GITHUB_ACTIONS.md](GITHUB_ACTIONS.md)** - GitHub Actions specific tools
- **[EXAMPLE.md](EXAMPLE.md)** - Real-world example

## Tools & Scripts

### Buildkite
- `distill_log.py` - Core distillation logic
- `distill_log.ps1` - PowerShell distillation script
- `download_buildkite_log.sh` - CLI tool to download and distill
- `download_buildkite_log.ps1` - PowerShell CLI tool to download and distill
- `buildkite_logs_server.py` - MCP server (legacy)

### GitHub Actions
- `distill_github_actions_log.py` - Distillation for GitHub Actions
- `download_github_actions_log.sh` - CLI tool to download and distill

### Unified
- `logs_distiller_server.py` - Combined MCP server for both Buildkite + GitHub Actions
- `logs-distiller.mcp.json` - MCP configuration template
- `apply_mcp_config.sh` - Universal MCP config manager
- `install_mcp_server.sh` - Legacy Buildkite-only installer

## What Gets Removed

### Timestamps
- ISO8601: `2026-06-01T11:54:37.466-04:00` → `[TIME]`
- Time markers: `[11:54:37]` → `[TIME]`
- GitHub format: `2026-06-02T11:30:45.123456Z` → `[TIME]`

### Identifiers
- UUIDs: `019e7621-8db2-4d3a-8541-d78b910bd808` → `[UUID]`
- Git SHAs: `39b18ac3c1` → `[SHA]`
- Buildkite URLs with IDs

### Visual Noise
- Progress bars: `[===========>    ]` → removed
- Spinners: `⠋⠙⠹` → removed
- ANSI color codes: `\x1b[32m` → removed
- Empty lines: collapsed
- Separators: `----`, `====`, etc.

### Repetitive Content
- Multiple identical fetch/download lines → single line
- Retry attempts with same pattern
- Bundle install attempts with same flags

### Platform-Specific
- GitHub Actions markers: `##[group]`, `##[endgroup]`, `##[debug]`
- GitHub URLs and API URLs
- Attempt markers
- Git operation progress: `remote: Compressing objects: 41% (62/150)` → removed
- Fetch progress: `Receiving objects: 27% (601/2225)` → removed

## What Gets Kept

- Error messages and warnings
- Stack traces
- Dependency version conflicts
- Command execution output
- Exit codes
- File paths
- Gem/package resolution errors

## Examples

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

### After (280 lines)
```
Fetching gem metadata from https://rubygems.org/
Bundler could not find compatible versions for gem "pry":
  In Gemfile:
    pry (= 0.15.2)
    pry-byebug (< 3.11) was resolved to 3.8.0, which depends on
      pry (~> 0.10)
```

## Tips

- **Claude Desktop:** Use the MCP server to save ~95% tokens on AI analysis
- **Command Line:** Run locally for instant distillation without token cost
- **Large Logs:** Distilled logs load faster and are easier to scan
- **Debugging:** Keep both raw and distilled - raw for complete history, distilled for analysis
- **CI/CD:** Integrate into pipelines for automated log analysis
- **For AI analysis:** Feed the distilled log to save ~97% of tokens
- **For CI failures:** Download failed job logs automatically and distill for quick triage
- **URL format:** Paste the full Buildkite build URL directly into `download_buildkite_log.ps1` — no need to parse org/pipeline/build manually

## Architecture

```
distill_[platform]_log.py     Core distillation logic (regex-based)
                              ├─ distill_buildkite_log_text()
                              └─ distill_github_actions_log_text()

download_[platform]_log.sh    CLI downloaders
                              ├─ Uses API tokens
                              └─ Pipes to distillers

logs_distiller_server.py      Unified MCP server
                              ├─ 4 tools for both platforms
                              └─ Environment variable support

apply_mcp_config.sh           Global config manager
                              ├─ JSON config handling
                              ├─ Environment substitution
                              └─ Multi-server support
```

## Performance

| Platform | Reduction | Time |
|----------|-----------|------|
| Buildkite | 97.5% | ~1s |
| GitHub Actions | 98.6% | ~1s |

## Features

✓ **90-98% log reduction** while preserving critical errors  
✓ **Token efficient** for AI analysis (~95% token savings)  
✓ **No external dependencies** beyond Python 3  
✓ **Easy integration** with Claude Desktop via MCP  
✓ **Command-line tools** for standalone use  
✓ **Universal config manager** for multiple MCP servers  
✓ **Environment variable support** in configs  
✓ **Support for both Buildkite + GitHub Actions**

## Troubleshooting

### "API token not found"

```bash
# Buildkite
export BUILDKITE_TOKEN="bk_..."

# GitHub
export GITHUB_TOKEN="ghp_..."
```

### "Failed to download log"

- Verify token has correct permissions
- Check that log exists and hasn't expired (GitHub: 90 days)
- Ensure `curl` is available (or `gh` CLI for GitHub)

### "MCP server not appearing in Claude"

1. Verify config was applied: `./apply_mcp_config.sh --list`
2. Check config file: `cat ~/.config/Claude/mcp.json`
3. Verify environment variables: `echo $BUILDKITE_TOKEN`
4. Restart Claude Desktop completely

## Similar Projects

- [GitHub Actions Log Parser](https://github.com/gacts/run-and-post-run)
- [Buildkite CLI](https://github.com/buildkite/cli)
- [Log Parser Tools](https://github.com/topics/log-parser)

## License

MIT
