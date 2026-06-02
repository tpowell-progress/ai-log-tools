#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Download and distill Buildkite build logs for efficient analysis.

.DESCRIPTION
    Downloads a Buildkite build log via the API and distills it using distill_log.ps1
    to reduce noise while preserving error information.

.PARAMETER Url
    Buildkite build URL (UI or API format). Examples:
    - https://buildkite.com/chef-oss/chef-chef-main-verify/builds/23274
    - https://api.buildkite.com/v2/organizations/chef-oss/pipelines/chef-chef-main-verify/builds/23274

.PARAMETER OutputFile
    Path to save the distilled output. Defaults to $env:TEMP\build_<BuildNumber>_distilled.txt

.EXAMPLE
    .\download_buildkite_log.ps1 'https://buildkite.com/chef-oss/chef-chef-main-verify/builds/23274'

.EXAMPLE
    .\download_buildkite_log.ps1 'https://api.buildkite.com/v2/organizations/chef-oss/pipelines/chef-chef-main-verify/builds/23274'

.NOTES
    Requires the BK_API_TOKEN environment variable set to a valid Buildkite API token.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Url,

    [Parameter(Position = 1)]
    [string]$OutputFile
)

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$DistillScript = Join-Path $ScriptDir 'distill_log.ps1'

# Check for API token
$ApiToken = $env:BK_API_TOKEN
if (-not $ApiToken) {
    Write-Error "BK_API_TOKEN environment variable not set.`nRun: `$env:BK_API_TOKEN = 'your-token'"
    exit 1
}

# Check for distill script
if (-not (Test-Path $DistillScript)) {
    Write-Error "distill_log.ps1 not found at $DistillScript"
    exit 1
}

# Parse URL: support both UI and API formats
$Org = $null
$Pipeline = $null
$BuildNumber = $null

# Try UI URL format: https://buildkite.com/{org}/{pipeline}/builds/{build_number}
if ($Url -match 'buildkite\.com/([^/]+)/([^/]+)/builds/(\d+)') {
    $Org = $matches[1]
    $Pipeline = $matches[2]
    $BuildNumber = $matches[3]
}
# Try API URL format: https://api.buildkite.com/v2/organizations/{org}/pipelines/{pipeline}/builds/{build_number}
elseif ($Url -match 'api\.buildkite\.com/v2/organizations/([^/]+)/pipelines/([^/]+)/builds/(\d+)') {
    $Org = $matches[1]
    $Pipeline = $matches[2]
    $BuildNumber = $matches[3]
}
else {
    Write-Error "Invalid Buildkite URL format. Accepted formats:`n  https://buildkite.com/{org}/{pipeline}/builds/{build_number}`n  https://api.buildkite.com/v2/organizations/{org}/pipelines/{pipeline}/builds/{build_number}"
    exit 1
}

if (-not $OutputFile) {
    $OutputFile = Join-Path $env:TEMP "build_${BuildNumber}_distilled.txt"
}

Write-Host "Downloading logs from Buildkite..."
Write-Host "Organization: $Org"
Write-Host "Pipeline:     $Pipeline"
Write-Host "Build:        $BuildNumber"

# Fetch the build to get jobs list
try {
    $BaseUrl = "https://api.buildkite.com/v2/organizations/$Org/pipelines/$Pipeline/builds/$BuildNumber"
    $BuildUrl = $BaseUrl + "?include=jobs"
    
    $Response = Invoke-RestMethod `
        -Uri $BuildUrl `
        -Headers @{
            'Authorization' = "Bearer $ApiToken"
            'Accept'        = 'application/json'
        } `
        -Method Get
    
    # Response might be a JSON string or an object, so parse if needed
    if ($Response -is [string]) {
        $Build = $Response | ConvertFrom-Json -AsHashtable
    } else {
        $Build = $Response
    }
} catch {
    Write-Error "Failed to fetch build: $_"
    exit 1
}

if (-not $Build.jobs -or $Build.jobs.Count -eq 0) {
    Write-Error "No jobs found in build"
    exit 1
}

# Use first job's log_url
$FirstJob = $Build.jobs[0]
$ApiUrl = $FirstJob.log_url
$JobName = $FirstJob.name

Write-Host "Job:          $JobName"
Write-Host "Fetching log..."

# Download log
try {
    $Response = Invoke-RestMethod `
        -Uri $ApiUrl `
        -Headers @{
            'Authorization' = "Bearer $ApiToken"
            'Accept'        = 'text/plain'
        } `
        -Method Get
} catch {
    Write-Error "Failed to download log: $_"
    exit 1
}

# Response is HTML-encoded plain text, need to decode HTML entities
$Content = [System.Net.WebUtility]::HtmlDecode($Response)

if (-not $Content) {
    Write-Error "Log content is empty or download failed"
    exit 1
}

Write-Host "Distilling..."

# Dot-source distill script to call its function directly (no subprocess needed)
. $DistillScript

$RawLines      = ($Content -split '\r?\n').Count
$Distilled     = Distill-Log -Text $Content
$Distilled | Set-Content -Path $OutputFile -Encoding UTF8
$DistilledLines = (Get-Content $OutputFile).Count

if ($RawLines -gt 0) {
    $Reduction = '{0:F1}%' -f ((1.0 - $DistilledLines / $RawLines) * 100)
    Write-Host "✓ Distilled: $RawLines → $DistilledLines lines ($Reduction reduction)"
} else {
    Write-Host "✓ Distilled: $DistilledLines lines"
}

Write-Host "✓ Saved to: $OutputFile"
