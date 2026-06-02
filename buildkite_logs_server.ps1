#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Buildkite Logs MCP server implemented in PowerShell.

.DESCRIPTION
    Provides two MCP tools:
    - download_and_distill_buildkite_log
    - distill_buildkite_log_text

    Uses stdio JSON-RPC framing with Content-Length headers.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$DistillScript = Join-Path $ScriptDir 'distill_log.ps1'

if (-not (Test-Path $DistillScript)) {
    throw "distill_log.ps1 not found at $DistillScript"
}

. $DistillScript

$Utf8 = [System.Text.UTF8Encoding]::new($false)
$InputStream = [Console]::OpenStandardInput()
$OutputStream = [Console]::OpenStandardOutput()

function Read-LineFromStream {
    param([System.IO.Stream]$Stream)

    $buffer = [System.Collections.Generic.List[byte]]::new()
    while ($true) {
        $b = $Stream.ReadByte()
        if ($b -lt 0) {
            if ($buffer.Count -eq 0) {
                return $null
            }
            break
        }
        $buffer.Add([byte]$b)
        if ($b -eq 10) {
            break
        }
    }

    $line = $Utf8.GetString($buffer.ToArray())
    return $line.TrimEnd("`r", "`n")
}

function Read-ExactBytes {
    param(
        [System.IO.Stream]$Stream,
        [int]$Length
    )

    $bytes = New-Object byte[] $Length
    $offset = 0
    while ($offset -lt $Length) {
        $read = $Stream.Read($bytes, $offset, $Length - $offset)
        if ($read -le 0) {
            throw "Unexpected EOF while reading message body"
        }
        $offset += $read
    }
    return $bytes
}

function Read-McpMessage {
    param([System.IO.Stream]$Stream)

    $headers = @{}
    while ($true) {
        $line = Read-LineFromStream -Stream $Stream
        if ($null -eq $line) {
            return $null
        }
        if ($line -eq '') {
            break
        }

        $idx = $line.IndexOf(':')
        if ($idx -gt 0) {
            $name = $line.Substring(0, $idx).Trim()
            $value = $line.Substring($idx + 1).Trim()
            $headers[$name.ToLowerInvariant()] = $value
        }
    }

    if (-not $headers.ContainsKey('content-length')) {
        throw 'Missing Content-Length header'
    }

    $contentLength = [int]$headers['content-length']
    $bodyBytes = Read-ExactBytes -Stream $Stream -Length $contentLength
    $json = $Utf8.GetString($bodyBytes)
    return $json | ConvertFrom-Json -AsHashtable
}

function Write-McpMessage {
    param([object]$Message)

    $json = $Message | ConvertTo-Json -Depth 100 -Compress
    $bodyBytes = $Utf8.GetBytes($json)
    $header = "Content-Length: $($bodyBytes.Length)`r`n`r`n"
    $headerBytes = $Utf8.GetBytes($header)

    $OutputStream.Write($headerBytes, 0, $headerBytes.Length)
    $OutputStream.Write($bodyBytes, 0, $bodyBytes.Length)
    $OutputStream.Flush()
}

function Get-BuildkiteToken {
    return $env:BK_API_TOKEN
}

function Invoke-McpTool {
    param(
        [string]$Name,
        [hashtable]$Arguments
    )

    switch ($Name) {
        'distill_buildkite_log_text' {
            $text = [string]$Arguments.text
            if ([string]::IsNullOrWhiteSpace($text)) {
                throw "Missing required argument: text"
            }

            $distilled = Distill-Log -Text $text
            return @{
                content = @(
                    @{
                        type = 'text'
                        text = $distilled
                    }
                )
            }
        }

        'download_and_distill_buildkite_log' {
            $jobId = [string]$Arguments.job_id
            if ([string]::IsNullOrWhiteSpace($jobId)) {
                throw "Missing required argument: job_id"
            }

            $org = if ($Arguments.ContainsKey('org') -and $Arguments.org) { [string]$Arguments.org } else { 'chef' }
            $pipeline = if ($Arguments.ContainsKey('pipeline') -and $Arguments.pipeline) { [string]$Arguments.pipeline } else { 'chef-chef-chef-18-validate-adhoc' }

            $token = Get-BuildkiteToken
            if ([string]::IsNullOrWhiteSpace($token)) {
                throw "Buildkite token not found. Set BK_API_TOKEN."
            }

            $logUrl = "https://api.buildkite.com/v2/organizations/$org/pipelines/$pipeline/jobs/$jobId/log"

            $response = Invoke-RestMethod `
                -Uri $logUrl `
                -Headers @{
                    Authorization = "Bearer $token"
                    Accept        = 'application/json'
                } `
                -Method Get

            $rawText = $null
            if ($response -is [string]) {
                $rawText = [string]$response
            } elseif ($response.PSObject.Properties['content']) {
                $rawText = [string]$response.content
            }

            if ([string]::IsNullOrEmpty($rawText)) {
                throw "Buildkite API returned empty log content"
            }

            $distilled = Distill-Log -Text $rawText
            return @{
                content = @(
                    @{
                        type = 'text'
                        text = $distilled
                    }
                )
            }
        }

        default {
            throw "Unknown tool: $Name"
        }
    }
}

try {
    while ($true) {
        $request = Read-McpMessage -Stream $InputStream
        if ($null -eq $request) {
            break
        }

        $method = [string]$request.method
        $id = $request.id
        $params = if ($request.ContainsKey('params') -and $request.params) { $request.params } else { @{} }

        # Notifications have no id and do not require responses.
        if ($null -eq $id) {
            continue
        }

        try {
            switch ($method) {
                'initialize' {
                    Write-McpMessage @{
                        jsonrpc = '2.0'
                        id = $id
                        result = @{
                            protocolVersion = '2024-11-05'
                            capabilities = @{
                                tools = @{}
                            }
                            serverInfo = @{
                                name = 'buildkite-logs-powershell'
                                version = '1.0.0'
                            }
                        }
                    }
                }

                'tools/list' {
                    Write-McpMessage @{
                        jsonrpc = '2.0'
                        id = $id
                        result = @{
                            tools = @(
                                @{
                                    name = 'download_and_distill_buildkite_log'
                                    description = 'Download a Buildkite job log and distill it to remove noise while preserving errors'
                                    inputSchema = @{
                                        type = 'object'
                                        properties = @{
                                            job_id = @{
                                                type = 'string'
                                                description = 'Buildkite job UUID'
                                            }
                                            org = @{
                                                type = 'string'
                                                description = 'Buildkite organization'
                                                default = 'chef'
                                            }
                                            pipeline = @{
                                                type = 'string'
                                                description = 'Buildkite pipeline'
                                                default = 'chef-chef-chef-18-validate-adhoc'
                                            }
                                        }
                                        required = @('job_id')
                                    }
                                }
                                @{
                                    name = 'distill_buildkite_log_text'
                                    description = 'Distill raw Buildkite log text by removing timestamps, progress bars, and repetitive noise'
                                    inputSchema = @{
                                        type = 'object'
                                        properties = @{
                                            text = @{
                                                type = 'string'
                                                description = 'Raw log text to distill'
                                            }
                                        }
                                        required = @('text')
                                    }
                                }
                            )
                        }
                    }
                }

                'tools/call' {
                    $toolName = [string]$params.name
                    $args = if ($params.ContainsKey('arguments') -and $params.arguments) { $params.arguments } else { @{} }
                    $result = Invoke-McpTool -Name $toolName -Arguments $args
                    Write-McpMessage @{
                        jsonrpc = '2.0'
                        id = $id
                        result = $result
                    }
                }

                'ping' {
                    Write-McpMessage @{
                        jsonrpc = '2.0'
                        id = $id
                        result = @{}
                    }
                }

                default {
                    Write-McpMessage @{
                        jsonrpc = '2.0'
                        id = $id
                        error = @{
                            code = -32601
                            message = "Method not found: $method"
                        }
                    }
                }
            }
        }
        catch {
            Write-McpMessage @{
                jsonrpc = '2.0'
                id = $id
                error = @{
                    code = -32000
                    message = [string]$_.Exception.Message
                }
            }
        }
    }
}
catch {
    # Fatal loop-level failure; if client can still read, emit an error notification as a log line.
    [Console]::Error.WriteLine("buildkite_logs_server.ps1 fatal error: $($_.Exception.Message)")
    exit 1
}
