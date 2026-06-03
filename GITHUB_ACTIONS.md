# GitHub Actions Log Tools

Efficiently analyze GitHub Actions workflow run logs by removing noise while preserving critical error information.

## Quick Start

### Command Line

```bash
# Download and distill a GitHub Actions run log
./download_github_actions_log.sh <owner> <repo> <run_id>

# Example
./download_github_actions_log.sh myorg myrepo 1234567890

# Or use environment variable
export GITHUB_REPO=myorg/myrepo
./download_github_actions_log.sh 1234567890
```

### Claude Desktop (via MCP)

See main [README.md](README.md) for MCP setup instructions.

## Setup

### 1. Get GitHub Token

Generate a personal access token at [github.com/settings/tokens](https://github.com/settings/tokens) with `actions:read` permission.

### 2. Set Environment Variable

```bash
export GITHUB_TOKEN="ghp_your_token_here"
# OR
export GH_TOKEN="ghp_your_token_here"
```

### 3. Make Script Executable

```bash
chmod +x distill_github_actions_log.py download_github_actions_log.sh
```

## Usage

### Download Full Run Log

```bash
# Using owner/repo/run_id
./download_github_actions_log.sh myorg myrepo 1234567890

# Using GITHUB_REPO environment variable
export GITHUB_REPO=myorg/myrepo
./download_github_actions_log.sh 1234567890 output.txt
```

### Distill Existing Log

```bash
python3 distill_github_actions_log.py raw_workflow.log > distilled.txt
cat huge_log.txt | python3 distill_github_actions_log.py > small_log.txt
```

## What Gets Removed

- **GitHub Action Markers:** `##[group]`, `##[endgroup]`, `##[debug]`, etc.
- **Timestamps:** `2026-06-02T11:30:45.123456Z` → `[TIME]`
- **Attempt Markers:** `attempt #3` → `[ATTEMPT]`
- **GitHub URLs:** `https://github.com/owner/repo/actions/runs/...` → `[GH_URL]`
- **API URLs:** `https://api.github.com/...` → `[API_URL]`
- **UUIDs:** `a1b2c3d4-e5f6-7890-abcd-ef1234567890` → `[UUID]`
- **Git SHAs:** `39b18ac3c1` → `[SHA]`
- **Progress Indicators:** Spinners and progress bars
- **Repetitive Download Lines:** Multiple identical "Downloading..." lines
- **Separators:** Lines of `----`, `====`, etc.
- **Empty Lines:** Collapsed

## What Gets Kept

- Error messages and stack traces
- Test failures and assertion details
- Dependency conflicts and resolution info
- Command output and exit codes
- File paths and line numbers
- Warning messages
- Exception details

## Example

### Before (8,450 lines)

```
2026-06-02T10:15:22.456Z ##[group]Run npm install
2026-06-02T10:15:22.567Z npm info it worked if it ends with ok
2026-06-02T10:15:22.678Z npm info using npm@9.6.7
[================>        ] 65% | Resolving dependencies
[====================>    ] 85% | Resolving dependencies
2026-06-02T10:15:45.234Z npm warn deprecated request@2.88.2: request has been deprecated
2026-06-02T10:15:45.345Z npm warn deprecated request@2.88.2: request has been deprecated
2026-06-02T10:15:45.456Z npm WARN npm WARN deprecated request@2.88.2
2026-06-02T10:15:56.789Z ##[error]Error: @package/test has peer dependency on react@>=16.8.0 but you have react@16.7.0
2026-06-02T10:15:57.890Z ##[endgroup]
2026-06-02T10:15:58.901Z ##[error]Process completed with exit code 1.
```

### After (120 lines – 98.6% reduction)

```
--- Run npm install ---
npm info it worked if it ends with ok
npm info using npm@9.6.7
npm warn deprecated request@2.88.2
[ERROR] Error: @package/test has peer dependency on react@>=16.8.0 but you have react@16.7.0
[ERROR] Process completed with exit code 1.
```

## Troubleshooting

### "GITHUB_TOKEN environment variable not set"

```bash
export GITHUB_TOKEN="your-token"
# Add to ~/.bashrc or ~/.zshrc for permanence
```

### "Failed to download log"

- Verify the run ID is correct
- Check that `gh` CLI is installed (optional) or `curl` is available
- Ensure token has `actions:read` permission

### Empty log file

- Verify the run exists and is public (or you have access)
- Check that the run hasn't expired (GitHub deletes logs after 90 days)

## Dependencies

- Python 3.7+
- `curl` (for downloading)
- `gh` CLI (optional, auto-detected)
- GitHub API token

## Tips

- **Token Storage:** Add to `~/.bashrc` or `~/.zshrc` for persistence
- **Large Logs:** Distillation reduces size by ~90-95%, making AI analysis token-efficient
- **Multiple Repos:** Use `export GITHUB_REPO=owner/repo` to avoid repeating
- **Debugging:** Keep both raw and distilled logs for complete history vs. quick analysis

## License

MIT
