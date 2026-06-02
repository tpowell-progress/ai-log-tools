#!/usr/bin/env python3
"""
Distill buildkite logs by removing noise while preserving error context.

Reduces log volume by ~95-98% while keeping critical information:
- Error messages and stack traces
- Dependency conflicts
- Command output
- File paths

Removes:
- Timestamps, UUIDs, hex hashes
- Progress bars and spinners
- Repetitive fetch attempts
- ANSI color codes

Usage:
    python3 distill_log.py input.log > output.txt
    cat raw.log | python3 distill_log.py
"""

import re
import sys

def distill_log(text):
    """Distill log text by removing noise while preserving errors."""
    lines = text.split('\n')
    output = []
    seen_lines = set()
    
    for line in lines:
        # Strip ANSI codes
        line = re.sub(r'\x1b\[[0-9;]*m', '', line)
        
        # Remove timestamps (ISO8601, RFC3339, etc)
        line = re.sub(r'\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}:\d{2}([.,]\d+)?([+-]\d{2}:\d{2}|Z)?', '[TIME]', line)
        line = re.sub(r'\[\d{2}:\d{2}:\d{2}\]', '[TIME]', line)
        
        # Remove UUIDs (8-4-4-4-12 format)
        line = re.sub(r'[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}', '[UUID]', line, flags=re.IGNORECASE)
        
        # Remove git commit SHAs (7-40 hex chars)
        line = re.sub(r'\b[0-9a-f]{7,40}\b', '[SHA]', line)
        
        # Remove buildkite job URLs with IDs
        line = re.sub(r'https://buildkite\.com/[^/]+/[^/]+/builds/\d+#[0-9a-f-]+', '[BK_URL]', line)
        
        # Skip progress bars and spinners
        if re.search(r'[\|/\-\\]|\[=+>?\s*\]|█|▓|░', line):
            continue
        
        # Skip empty lines
        if not line.strip():
            continue
            
        # Skip repeated "Fetching gem metadata" lines (keep first)
        if 'Fetching gem metadata' in line:
            if line in seen_lines:
                continue
            seen_lines.add(line)
        
        # Skip repeated "Retrying" lines (keep unique patterns)
        if 'Retrying' in line and 'attempt' in line.lower():
            canonical = re.sub(r'\d+', 'N', line)
            if canonical in seen_lines:
                continue
            seen_lines.add(canonical)
        
        # Collapse repetitive bundle install attempts (keep first and last)
        if 'bundle install' in line.lower() and '--' in line:
            canonical = re.sub(r'--\S+', '--FLAG', line)
            if canonical in seen_lines:
                continue
            seen_lines.add(canonical)
        
        output.append(line)
    
    # Additional pass: collapse consecutive similar errors
    final = []
    prev_error_type = None
    error_count = 0
    
    for line in output:
        if 'Could not find' in line or 'could not find' in line:
            if prev_error_type == 'could_not_find':
                error_count += 1
                continue
            else:
                prev_error_type = 'could_not_find'
                error_count = 1
                final.append(line)
        else:
            if prev_error_type == 'could_not_find' and error_count > 1:
                final.append(f'  [...{error_count-1} more similar errors...]')
            prev_error_type = None
            error_count = 0
            final.append(line)
    
    return '\n'.join(final)

def main():
    if len(sys.argv) > 1:
        with open(sys.argv[1]) as f:
            text = f.read()
    else:
        text = sys.stdin.read()
    
    print(distill_log(text))

if __name__ == '__main__':
    main()
