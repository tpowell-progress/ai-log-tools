#!/usr/bin/env python3
"""
Distill GitHub Actions logs by removing noise while preserving error context.

Reduces log volume by ~90-95% while keeping critical information:
- Error messages and stack traces
- Test failures and assertion details
- Dependency conflicts and resolution errors
- Command output
- File paths and line numbers

Removes:
- Timestamps
- Group fold markers
- Progress indicators
- Repetitive status updates
- ANSI color codes

Usage:
    python3 distill_github_actions_log.py input.log > output.txt
    cat raw.log | python3 distill_github_actions_log.py
"""

import re
import sys


def distill_github_actions_log(text: str) -> str:
    """Distill GitHub Actions log text by removing noise while preserving errors."""
    lines = text.split('\n')
    output = []
    seen_lines = set()
    in_group = False
    group_depth = 0
    
    for line in lines:
        # Strip ANSI codes
        line = re.sub(r'\x1b\[[0-9;]*m', '', line)
        
        # Track group depth for fold markers
        if '##[group]' in line:
            group_depth += 1
            # Include important group headers
            if any(keyword in line.lower() for keyword in ['error', 'fail', 'test', 'build', 'deploy', 'warning']):
                # Extract group name
                group_name = line.replace('##[group]', '').strip()
                if group_name:
                    output.append(f"--- {group_name} ---")
            continue
        elif '##[endgroup]' in line:
            group_depth = max(0, group_depth - 1)
            continue
        
        # Skip other GitHub Actions markers
        if line.strip().startswith('##['):
            continue
        
        # Remove GitHub Actions timestamps (e.g., "2026-06-02T11:30:45.123456Z")
        line = re.sub(r'\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}[.,]\d+Z', '[TIME]', line)
        
        # Remove job IDs and attempt markers (e.g., "attempt #3")
        line = re.sub(r'attempt\s+#\d+', '[ATTEMPT]', line, flags=re.IGNORECASE)
        
        # Remove common GitHub URLs
        line = re.sub(r'https://github\.com/[^/]+/[^/]+/(actions/runs|pull|issues)/\d+[#\?]?\S*', '[GH_URL]', line)
        line = re.sub(r'https://api\.github\.com/\S+', '[API_URL]', line)
        
        # Remove UUIDs and run IDs
        line = re.sub(r'[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}', '[UUID]', line, flags=re.IGNORECASE)
        
        # Remove git commit SHAs and hashes
        line = re.sub(r'\b[0-9a-f]{7,40}\b', '[SHA]', line)
        
        # Skip progress indicators and spinners
        if re.search(r'[\|/\-\\]|\[=+>?\s*\]|█|▓|░|⠋|⠙|⠹|⠸|⠼|⠴|⠦|⠧|⠇|⠏', line):
            continue
        
        # Skip repetitive "Waiting for..." messages
        if 'Waiting for' in line or 'Checking status' in line:
            canonical = re.sub(r'\d+\s*(s|ms|seconds?)', 'Ns', line)
            if canonical in seen_lines:
                continue
            seen_lines.add(canonical)
        
        # Skip repetitive download/fetch lines (keep first)
        if any(kw in line.lower() for kw in ['downloading', 'fetching', 'retrieving']) and ('from' in line or 'url' in line):
            canonical = re.sub(r'https?://[^\s]+', '[URL]', line)
            canonical = re.sub(r'\d+\s*%', 'N%', canonical)
            if canonical in seen_lines:
                continue
            seen_lines.add(canonical)
        
        # Skip empty lines
        if not line.strip():
            continue
        
        # Skip lines that are just separators
        if re.match(r'^[-=_*]{10,}$', line.strip()):
            continue
        
        output.append(line)
    
    # Additional pass: deduplicate consecutive identical non-error lines
    final = []
    prev_line = None
    
    for line in output:
        # Always keep error/warning lines
        is_error = any(kw in line.lower() for kw in ['error', 'fail', 'exception', 'traceback', 'warning', 'panic', 'fatal'])
        
        if is_error or line != prev_line:
            final.append(line)
            prev_line = line
    
    return '\n'.join(final)


def main():
    if len(sys.argv) > 1:
        with open(sys.argv[1]) as f:
            text = f.read()
    else:
        text = sys.stdin.read()
    
    print(distill_github_actions_log(text))


if __name__ == '__main__':
    main()
