# Buildkite Log Tools

Utilities for efficiently analyzing Buildkite job logs by removing noise while preserving critical error information.

## Problem

Buildkite job logs can be massive (10,000+ lines) with lots of noise:
- Timestamps on every line
- UUIDs and hex identifiers
- Progress bars and spinners
- Repeated fetch attempts
- ANSI color codes

This makes logs token-inefficient for AI analysis and hard for humans to scan.

## Solution

**distill_log.py** reduces log volume by ~95-98% while keeping what matters:
- ✓ Error messages and stack traces
- ✓ Dependency conflicts
- ✓ Command output and exit codes
- ✓ File paths

**Example:** 11,363 lines → 280 lines (97.5% reduction)

## Usage

### Quick Start

```bash
# Download and distill a Buildkite job log
./download_buildkite_log.sh <job_id>

# Example
./download_buildkite_log.sh 019e7621-8db2-4d3a-8541-d78b910bd808
```

### Distill an existing log file

```bash
python3 distill_log.py raw.log > distilled.txt
cat huge.log | python3 distill_log.py > small.txt
```

### Custom org/pipeline

```bash
./download_buildkite_log.sh myorg mypipeline <job_id> output.txt
```

## Setup

1. **Install dependencies:** None! Uses standard Python 3 libraries.

2. **Set up Buildkite API token:**
   ```bash
   export BK_CHEF_ONLY_2024="your-api-token"
   # Or source from ~/.env
   ```

3. **Make scripts executable:**
   ```bash
   chmod +x distill_log.py download_buildkite_log.sh
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

- **For AI analysis:** Feed the distilled log to save ~97% of tokens
- **For debugging:** Keep both raw and distilled - raw for complete history, distilled for quick scanning
- **For CI failures:** Download failed job logs automatically and distill for quick triage

## Contributing

Improvements welcome! Consider adding:
- Support for other CI systems (GitHub Actions, GitLab CI)
- More intelligent error grouping
- Configurable noise patterns
- JSON/YAML output format

## License

MIT (or whatever Chef uses for internal tools)
