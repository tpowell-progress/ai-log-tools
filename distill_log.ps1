#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Distill buildkite logs by removing noise while preserving error context.

.DESCRIPTION
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

.PARAMETER InputFile
    Path to input log file. If omitted, reads from pipeline or stdin.

.EXAMPLE
    .\distill_log.ps1 input.log > output.txt

.EXAMPLE
    Get-Content raw.log | .\distill_log.ps1
#>
param(
    [Parameter(Position = 0)]
    [string]$InputFile
)

function Distill-Log {
    param([string]$Text)

    # Normalize line endings
    $lines = $Text -split '\r?\n'
    $output = [System.Collections.Generic.List[string]]::new()
    $seenLines = [System.Collections.Generic.HashSet[string]]::new()

    foreach ($line in $lines) {
        # Strip ANSI codes
        $line = $line -replace '\x1b\[[0-9;]*m', ''

        # Remove timestamps (ISO8601, RFC3339, etc)
        $line = $line -replace '\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}:\d{2}([.,]\d+)?([+-]\d{2}:\d{2}|Z)?', '[TIME]'
        $line = $line -replace '\[\d{2}:\d{2}:\d{2}\]', '[TIME]'

        # Remove UUIDs (8-4-4-4-12 format)
        $line = $line -replace '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}', '[UUID]'

        # Remove git commit SHAs (7-40 lowercase hex chars) - case-sensitive to match Python behavior
        $line = $line -creplace '\b[0-9a-f]{7,40}\b', '[SHA]'

        # Remove buildkite job URLs with IDs
        $line = $line -replace 'https://buildkite\.com/[^/]+/[^/]+/builds/\d+#[0-9a-f-]+', '[BK_URL]'

        # Skip progress bars and spinners (lines that are purely progress indicators,
        # not lines that merely contain these chars — e.g. file paths and gem names must be kept)
        if ($line -match '^\s*\[[\s=>]*\]\s*\d*%?\s*$' -or   # bracketed bars: [===>  ] 45%
            $line -match '^\s*[|/\-\\]\s*$' -or               # isolated spinner char on its own line
            $line -match '[█▓░]') {                            # block character bars
            continue
        }

        # Skip git operation progress lines (remote: Compressing objects: 41% (62/150), etc)
        if ($line -match '(remote:\s+)?(\w+\s+)*\w+:\s+\d+%\s+\(\d+/\d+\)') {
            continue
        }

        # Skip empty lines
        if (-not $line.Trim()) {
            continue
        }

        # Skip repeated "Fetching gem metadata" lines (keep first)
        if ($line -match 'Fetching gem metadata') {
            if (-not $seenLines.Add($line)) {
                continue
            }
        }

        # Skip repeated "Retrying" lines (keep unique patterns)
        if ($line -match 'Retrying' -and $line -imatch 'attempt') {
            $canonical = $line -replace '\d+', 'N'
            if (-not $seenLines.Add($canonical)) {
                continue
            }
        }

        # Collapse repetitive bundle install attempts (keep first)
        if ($line -imatch 'bundle install' -and $line -match '--') {
            $canonical = $line -replace '--\S+', '--FLAG'
            if (-not $seenLines.Add($canonical)) {
                continue
            }
        }

        $output.Add($line)
    }

    # Second pass: collapse consecutive similar "Could not find" errors
    $final = [System.Collections.Generic.List[string]]::new()
    $prevErrorType = $null
    $errorCount = 0

    foreach ($line in $output) {
        if ($line -imatch 'could not find') {
            if ($prevErrorType -eq 'could_not_find') {
                $errorCount++
            } else {
                $prevErrorType = 'could_not_find'
                $errorCount = 1
                $final.Add($line)
            }
        } else {
            if ($prevErrorType -eq 'could_not_find' -and $errorCount -gt 1) {
                $final.Add("  [...$($errorCount - 1) more similar errors...]")
            }
            $prevErrorType = $null
            $errorCount = 0
            $final.Add($line)
        }
    }

    # Flush any trailing "Could not find" summary
    if ($prevErrorType -eq 'could_not_find' -and $errorCount -gt 1) {
        $final.Add("  [...$($errorCount - 1) more similar errors...]")
    }

    return $final -join "`n"
}

# Only execute when run directly (not dot-sourced)
if ($MyInvocation.InvocationName -ne '.') {
    if ($InputFile) {
        $text = Get-Content -Path $InputFile -Raw -Encoding UTF8
    } else {
        $pipelineInput = @($input)
        if ($pipelineInput.Count -gt 0) {
            $text = $pipelineInput -join "`n"
        } else {
            $text = [Console]::In.ReadToEnd()
        }
    }

    Write-Output (Distill-Log -Text $text)
}
