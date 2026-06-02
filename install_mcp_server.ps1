# Install Buildkite Logs MCP Server
#
# This script adds the buildkite-logs MCP server to the active MCP config.
# It prefers ~/.copilot/mcp-config.json when present, then falls back to the
# existing Claude Desktop locations.
# The server provides tools for downloading and distilling Buildkite job logs.
#
# Usage:
#   .\install_mcp_server.ps1
#   .\install_mcp_server.ps1 -ServerDir C:\custom\path
#   .\install_mcp_server.ps1 -Remove  # Uninstall
#
# Environment variables:
#   MCP_CONFIG_DIR - Custom config directory (default: ~/.config/Claude)

param(
    [string]$ServerDir = ".",
    [switch]$Remove
)

$ErrorActionPreference = "Stop"

# Get script directory
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$InstallMode = if ($Remove) { "remove" } else { "add" }

# Resolve server directory to absolute path
if (-not [System.IO.Path]::IsPathRooted($ServerDir)) {
    $ServerDir = Join-Path $ScriptDir $ServerDir
}
$ServerDir = Resolve-Path $ServerDir -ErrorAction Stop

# Determine MCP config path
$UserHome = $env:USERPROFILE
$MCP_JSON = $null
$MCP_CONFIG_HOME = $null

if ($env:MCP_CONFIG_DIR) {
    $MCP_CONFIG_HOME = $env:MCP_CONFIG_DIR
}
elseif (Test-Path "$UserHome\.copilot\mcp-config.json") {
    $MCP_JSON = "$UserHome\.copilot\mcp-config.json"
}
elseif (Test-Path "$UserHome\.config\Claude" -PathType Container) {
    $MCP_CONFIG_HOME = "$UserHome\.config\Claude"
}
else {
    $MCP_CONFIG_HOME = "$UserHome\.mcp"
}

if (-not $MCP_JSON) {
    if (-not $MCP_CONFIG_HOME) {
        $MCP_CONFIG_HOME = "$UserHome\.mcp"
    }
    $MCP_JSON = Join-Path $MCP_CONFIG_HOME "mcp.json"
}

Write-Host "MCP Configuration: $MCP_JSON"
Write-Host "Server Directory: $ServerDir"

# Check for required files
if (-not (Test-Path (Join-Path $ServerDir "buildkite_logs_server.ps1"))) {
    Write-Host "Error: buildkite_logs_server.ps1 not found in $ServerDir" -ForegroundColor Red
    exit 1
}

# Create config directory if needed
if ($MCP_CONFIG_HOME -and -not (Test-Path $MCP_CONFIG_HOME)) {
    New-Item -Path $MCP_CONFIG_HOME -ItemType Directory -Force | Out-Null
}

# Create parent directory for mcp.json if needed
$MCP_JSON_Dir = Split-Path -Parent $MCP_JSON
if (-not (Test-Path $MCP_JSON_Dir)) {
    New-Item -Path $MCP_JSON_Dir -ItemType Directory -Force | Out-Null
}

# Initialize mcp.json if it doesn't exist
if (-not (Test-Path $MCP_JSON)) {
    Write-Host "Creating new MCP configuration..."
    $initialConfig = @{
        mcpServers = @{}
    }
    $initialConfig | ConvertTo-Json | Set-Content -Path $MCP_JSON -Encoding UTF8
}

# Use PowerShell to safely modify JSON
$config_path = $MCP_JSON
$server_dir = $ServerDir
$mode = $InstallMode

try {
    $config = Get-Content -Path $config_path -Raw | ConvertFrom-Json
}
catch {
    $config = @{
        mcpServers = @{}
    }
}

if (-not $config.mcpServers) {
    $config | Add-Member -NotePropertyName "mcpServers" -NotePropertyValue @{}
}

$server_config = @{
    command = "pwsh"
    args    = @("-NoLogo", "-NoProfile", "-File", (Join-Path $server_dir "buildkite_logs_server.ps1"))
    env     = @{}
}

# Add environment variable if it exists
if ($env:BK_API_TOKEN) {
    $server_config.env["BK_API_TOKEN"] = $env:BK_API_TOKEN
}

# Remove env key if it's empty
if ($server_config.env.Count -eq 0) {
    $server_config.PSObject.Properties.Remove("env")
}

# Convert env dict to PSCustomObject if it has values (needed for JSON serialization)
if ($server_config.env.Count -gt 0) {
    $server_config.env = [PSCustomObject]$server_config.env
}

# Convert args array to proper format for JSON
$server_config.args = @($server_config.args)

# Convert server_config to PSCustomObject
$server_config = [PSCustomObject]$server_config

if ($mode -eq "add") {
    $config.mcpServers | Add-Member -NotePropertyName "buildkite-logs" -NotePropertyValue $server_config -Force
    Write-Host "✓ Added buildkite-logs server to MCP configuration"
}
elseif ($mode -eq "remove") {
    if ($config.mcpServers.PSObject.Properties["buildkite-logs"]) {
        $config.mcpServers.PSObject.Properties.Remove("buildkite-logs")
        Write-Host "✓ Removed buildkite-logs server from MCP configuration"
    }
    else {
        Write-Host "✗ buildkite-logs server not found in configuration" -ForegroundColor Yellow
        exit 1
    }
}

# Write config back with proper formatting
$config | ConvertTo-Json -Depth 10 | Set-Content -Path $config_path -Encoding UTF8
Write-Host "✓ Updated $config_path"

if ($mode -eq "add") {
    Write-Host ""
    Write-Host "Setup complete! Next steps:"
    Write-Host "1. Ensure Buildkite API token is set:"
    Write-Host "   `$env:BK_API_TOKEN = 'your-token'"
    Write-Host ""
    Write-Host "2. Restart Claude Desktop for changes to take effect"
    Write-Host ""
    Write-Host "Available tools:"
    Write-Host "  • download_and_distill_buildkite_log - Download and distill a job log"
    Write-Host "  • distill_buildkite_log_text - Distill raw log text"
}
else {
    Write-Host ""
    Write-Host "Uninstall complete!"
}
