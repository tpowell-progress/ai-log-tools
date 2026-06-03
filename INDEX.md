# AI Log Tools - Complete Index

## 📚 Documentation

Start here based on your goal:

- **[SETUP.md](SETUP.md)** - ⭐ **START HERE** - 5-minute quick setup
- **[README.md](README.md)** - Overview of all tools
- **[MCP_SERVER.md](MCP_SERVER.md)** - Claude Desktop integration
- **[MCP_CONFIG_MANAGEMENT.md](MCP_CONFIG_MANAGEMENT.md)** - Global config manager
- **[GITHUB_ACTIONS.md](GITHUB_ACTIONS.md)** - GitHub Actions specific tools
- **[EXAMPLE.md](EXAMPLE.md)** - Real-world usage example

## 🛠️ Tools

### Buildkite
- `distill_log.py` - Distillation logic (core)
- `download_buildkite_log.sh` - Download & distill CLI tool
- `buildkite_logs_server.py` - Legacy MCP server

### GitHub Actions
- `distill_github_actions_log.py` - Distillation logic
- `download_github_actions_log.sh` - Download & distill CLI tool

### Unified
- `logs_distiller_server.py` - Combined MCP server for both platforms
- `apply_mcp_config.sh` - Universal MCP config manager
- `install_mcp_server.sh` - Buildkite-only installer (legacy)

### Configuration
- `logs-distiller.mcp.json` - MCP server config template

## 🚀 Quick Start Paths

### Path 1: Claude Desktop (Recommended)
```bash
SETUP.md → MCP_SERVER.md → Start using in Claude
```

### Path 2: Command Line
```bash
SETUP.md → GITHUB_ACTIONS.md or README.md → Use CLI tools
```

### Path 3: Advanced Configuration
```bash
SETUP.md → MCP_CONFIG_MANAGEMENT.md → Manage multiple servers
```

## 📋 Feature Matrix

| Feature | Buildkite | GitHub Actions |
|---------|-----------|----------------|
| CLI distillation | ✓ | ✓ |
| Download & distill | ✓ | ✓ |
| Claude Desktop (MCP) | ✓ | ✓ |
| Reduction rate | 95-98% | 90-95% |

## 🔧 Common Tasks

### I want to...

**...use Claude Desktop to analyze logs**
→ [SETUP.md](SETUP.md) → [MCP_SERVER.md](MCP_SERVER.md)

**...analyze logs from the command line**
→ [SETUP.md](SETUP.md) → Use `./download_*_log.sh` scripts

**...distill a raw log file**
→ Use `python3 distill_*.py input.log > output.txt`

**...manage multiple MCP servers**
→ [MCP_CONFIG_MANAGEMENT.md](MCP_CONFIG_MANAGEMENT.md)

**...set up GitHub Actions logs**
→ [GITHUB_ACTIONS.md](GITHUB_ACTIONS.md)

**...see a real example**
→ [EXAMPLE.md](EXAMPLE.md)

## 📊 Performance

- **Reduction:** 90-98% of lines removed
- **Time:** ~1 second per log
- **Token savings:** ~95% for AI analysis

## 🎯 Architecture

```
User Input
    ↓
[download_*.sh] ← API Tokens → [logs_distiller_server.py]
    ↓                               ↓
[distill_*.py]                [Claude Desktop]
    ↓
Output (90-98% smaller)
```

## 📦 Dependencies

- Python 3.7+
- `curl`
- Optional: `gh` CLI for GitHub

## 🔐 Secrets

Requires API tokens:
- Buildkite: `BUILDKITE_TOKEN` (or `BK_CHEF_ONLY_2024`)
- GitHub: `GITHUB_TOKEN` or `GH_TOKEN`

See [SETUP.md](SETUP.md) for how to set up.

## ✅ Checklist for First Time

- [ ] Read [SETUP.md](SETUP.md)
- [ ] Get API tokens
- [ ] Set environment variables
- [ ] Run setup script: `./apply_mcp_config.sh logs-distiller.mcp.json`
- [ ] Restart Claude Desktop
- [ ] Try an example: `./download_buildkite_log.sh <job_id>`
- [ ] Ask Claude to analyze a log

## 📞 Support

- **Setup issues?** → [SETUP.md](SETUP.md) troubleshooting section
- **Config issues?** → [MCP_CONFIG_MANAGEMENT.md](MCP_CONFIG_MANAGEMENT.md)
- **GitHub Actions issues?** → [GITHUB_ACTIONS.md](GITHUB_ACTIONS.md)
- **Claude Desktop issues?** → [MCP_SERVER.md](MCP_SERVER.md)

---

**Next:** Read [SETUP.md](SETUP.md) to get started in 5 minutes!
