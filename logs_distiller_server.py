#!/usr/bin/env python3
"""
Unified Logs MCP Server - Buildkite + GitHub Actions

Provides tools for downloading and distilling logs from both Buildkite and GitHub Actions
through the Model Context Protocol.

Tools:
  - download_and_distill_buildkite_log: Download Buildkite job log
  - distill_buildkite_log_text: Distill raw Buildkite log
  - download_and_distill_github_actions_log: Download GitHub Actions run log
  - distill_github_actions_log_text: Distill raw GitHub Actions log
"""

import json
import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Any

# Try to import mcp
try:
    from mcp.server.models import InitializationOptions
    from mcp.types import (
        Tool,
        TextContent,
        ToolResponse,
    )
    import mcp.server.stdio
except ImportError:
    pass


def distill_buildkite_log_text(text: str) -> str:
    """Distill Buildkite log text by removing noise while preserving errors."""
    lines = text.split('\n')
    output = []
    seen_lines = set()
    
    for line in lines:
        # Strip ANSI codes
        line = re.sub(r'\x1b\[[0-9;]*m', '', line)
        
        # Remove timestamps
        line = re.sub(r'\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}:\d{2}([.,]\d+)?([+-]\d{2}:\d{2}|Z)?', '[TIME]', line)
        line = re.sub(r'\[\d{2}:\d{2}:\d{2}\]', '[TIME]', line)
        
        # Remove UUIDs
        line = re.sub(r'[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}', '[UUID]', line, flags=re.IGNORECASE)
        
        # Remove git SHAs
        line = re.sub(r'\b[0-9a-f]{7,40}\b', '[SHA]', line)
        
        # Remove buildkite URLs
        line = re.sub(r'https://buildkite\.com/[^/]+/[^/]+/builds/\d+#[0-9a-f-]+', '[BK_URL]', line)
        
        # Skip progress bars
        if re.search(r'[\|/\-\\]|\[=+>?\s*\]|█|▓|░', line):
            continue
        
        # Skip empty lines
        if not line.strip():
            continue
            
        # Deduplicate common messages
        if 'Fetching gem metadata' in line:
            if line in seen_lines:
                continue
            seen_lines.add(line)
        
        if 'Retrying' in line and 'attempt' in line.lower():
            canonical = re.sub(r'\d+', 'N', line)
            if canonical in seen_lines:
                continue
            seen_lines.add(canonical)
        
        if 'bundle install' in line.lower() and '--' in line:
            canonical = re.sub(r'--\S+', '--FLAG', line)
            if canonical in seen_lines:
                continue
            seen_lines.add(canonical)
        
        output.append(line)
    
    # Deduplicate consecutive errors
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


def distill_github_actions_log_text(text: str) -> str:
    """Distill GitHub Actions log text by removing noise while preserving errors."""
    lines = text.split('\n')
    output = []
    seen_lines = set()
    
    for line in lines:
        # Strip ANSI codes
        line = re.sub(r'\x1b\[[0-9;]*m', '', line)
        
        # Skip GitHub Actions markers
        if line.strip().startswith('##['):
            if '##[group]' in line:
                group_name = line.replace('##[group]', '').strip()
                if group_name and any(kw in group_name.lower() for kw in ['error', 'fail', 'test', 'build']):
                    output.append(f"--- {group_name} ---")
            continue
        
        # Remove timestamps
        line = re.sub(r'\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}[.,]\d+Z', '[TIME]', line)
        
        # Remove attempt markers
        line = re.sub(r'attempt\s+#\d+', '[ATTEMPT]', line, flags=re.IGNORECASE)
        
        # Remove URLs
        line = re.sub(r'https://github\.com/[^/]+/[^/]+/(actions/runs|pull|issues)/\d+[#\?]?\S*', '[GH_URL]', line)
        line = re.sub(r'https://api\.github\.com/\S+', '[API_URL]', line)
        
        # Remove UUIDs
        line = re.sub(r'[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}', '[UUID]', line, flags=re.IGNORECASE)
        
        # Remove SHAs
        line = re.sub(r'\b[0-9a-f]{7,40}\b', '[SHA]', line)
        
        # Skip progress indicators
        if re.search(r'[\|/\-\\]|\[=+>?\s*\]|█|▓|░|⠋|⠙|⠹', line):
            continue
        
        # Skip empty lines
        if not line.strip():
            continue
        
        # Skip separators
        if re.match(r'^[-=_*]{10,}$', line.strip()):
            continue
        
        # Deduplicate non-error lines
        is_error = any(kw in line.lower() for kw in ['error', 'fail', 'exception', 'traceback', 'warning'])
        
        if not is_error:
            canonical = re.sub(r'https?://[^\s]+', '[URL]', line)
            canonical = re.sub(r'\d+\s*%', 'N%', canonical)
            if canonical in seen_lines:
                continue
            seen_lines.add(canonical)
        
        output.append(line)
    
    return '\n'.join(output)


def download_buildkite_log(job_id: str, org: str = "chef", pipeline: str = "chef-chef-chef-18-validate-adhoc") -> str:
    """Download raw log from Buildkite API."""
    api_token = os.environ.get("BK_CHEF_ONLY_2024") or os.environ.get("BUILDKITE_TOKEN")
    
    if not api_token:
        raise ValueError(
            "Buildkite API token not found. "
            "Set BK_CHEF_ONLY_2024 or BUILDKITE_TOKEN environment variable."
        )
    
    url = f"https://api.buildkite.com/v2/organizations/{org}/pipelines/{pipeline}/builds/-/jobs/{job_id}/log"
    
    try:
        result = subprocess.run(
            ["curl", "-s", url, "-H", f"Authorization: Bearer {api_token}", "-H", "Accept: application/json"],
            capture_output=True,
            text=True,
            timeout=30,
        )
        
        if result.returncode != 0:
            raise RuntimeError(f"curl failed: {result.stderr}")
        
        if not result.stdout.strip():
            raise RuntimeError("Empty response from API")
        
        data = json.loads(result.stdout)
        return data.get("content", "")
    except json.JSONDecodeError as e:
        raise RuntimeError(f"Failed to parse API response: {e}")
    except subprocess.TimeoutExpired:
        raise RuntimeError("Buildkite API request timed out")


def download_github_actions_log(owner: str, repo: str, run_id: str) -> str:
    """Download raw log from GitHub Actions API."""
    api_token = os.environ.get("GITHUB_TOKEN") or os.environ.get("GH_TOKEN")
    
    if not api_token:
        raise ValueError(
            "GitHub API token not found. "
            "Set GITHUB_TOKEN or GH_TOKEN environment variable."
        )
    
    # Try gh CLI first
    try:
        result = subprocess.run(
            ["gh", "run", "view", run_id, "--repo", f"{owner}/{repo}", "--log"],
            capture_output=True,
            text=True,
            timeout=30,
            env={**os.environ, "GH_TOKEN": api_token},
        )
        
        if result.returncode == 0 and result.stdout.strip():
            return result.stdout
    except (FileNotFoundError, subprocess.TimeoutExpired):
        pass
    
    # Fall back to curl
    try:
        result = subprocess.run(
            [
                "curl", "-s",
                f"https://api.github.com/repos/{owner}/{repo}/actions/runs/{run_id}/attempts/1/logs",
                "-H", f"Authorization: Bearer {api_token}",
                "-H", "Accept: application/vnd.github.v3.raw",
                "-L",
            ],
            capture_output=True,
            text=True,
            timeout=30,
        )
        
        if result.returncode != 0:
            raise RuntimeError(f"curl failed: {result.stderr}")
        
        if not result.stdout.strip():
            raise RuntimeError("Empty response from API")
        
        return result.stdout
    except subprocess.TimeoutExpired:
        raise RuntimeError("GitHub API request timed out")


def process_tool_call(name: str, arguments: dict) -> str:
    """Process a tool call and return the result."""
    try:
        if name == "download_and_distill_buildkite_log":
            job_id = arguments.get("job_id")
            if not job_id:
                return "Error: job_id is required"
            
            org = arguments.get("org", "chef")
            pipeline = arguments.get("pipeline", "chef-chef-chef-18-validate-adhoc")
            
            raw_log = download_buildkite_log(job_id, org, pipeline)
            distilled = distill_buildkite_log_text(raw_log)
            
            raw_lines = len(raw_log.split('\n'))
            distilled_lines = len(distilled.split('\n'))
            
            if raw_lines > 0:
                reduction = (1 - distilled_lines / raw_lines) * 100
                summary = f"Distilled: {raw_lines} → {distilled_lines} lines ({reduction:.1f}% reduction)\n\n"
            else:
                summary = ""
            
            return summary + distilled
        
        elif name == "distill_buildkite_log_text":
            text = arguments.get("text")
            if not text:
                return "Error: text is required"
            
            return distill_buildkite_log_text(text)
        
        elif name == "download_and_distill_github_actions_log":
            owner = arguments.get("owner")
            repo = arguments.get("repo")
            run_id = arguments.get("run_id")
            
            if not all([owner, repo, run_id]):
                return "Error: owner, repo, and run_id are required"
            
            raw_log = download_github_actions_log(owner, repo, run_id)
            distilled = distill_github_actions_log_text(raw_log)
            
            raw_lines = len(raw_log.split('\n'))
            distilled_lines = len(distilled.split('\n'))
            
            if raw_lines > 0:
                reduction = (1 - distilled_lines / raw_lines) * 100
                summary = f"Distilled: {raw_lines} → {distilled_lines} lines ({reduction:.1f}% reduction)\n\n"
            else:
                summary = ""
            
            return summary + distilled
        
        elif name == "distill_github_actions_log_text":
            text = arguments.get("text")
            if not text:
                return "Error: text is required"
            
            return distill_github_actions_log_text(text)
        
        else:
            return f"Unknown tool: {name}"
    
    except Exception as e:
        return f"Error: {str(e)}"


class UnifiedLogsServer:
    """MCP Server for both Buildkite and GitHub Actions logs."""
    
    def __init__(self):
        self.server = mcp.server.stdio.stdio_server(
            self.handle_init,
            self.handle_call_tool,
            self.handle_list_tools,
            self.handle_get_tool,
        )
    
    async def handle_init(self, options: InitializationOptions) -> dict:
        """Handle initialization."""
        return {
            "protocolVersion": "2024-11-05",
            "capabilities": {"tools": {}},
            "serverInfo": {
                "name": "logs-distiller",
                "version": "1.0.0",
            },
        }
    
    async def handle_list_tools(self) -> list[Tool]:
        """List available tools."""
        return [
            Tool(
                name="download_and_distill_buildkite_log",
                description="Download a Buildkite job log and return distilled content",
                inputSchema={
                    "type": "object",
                    "properties": {
                        "job_id": {
                            "type": "string",
                            "description": "Buildkite job ID (UUID format)",
                        },
                        "org": {
                            "type": "string",
                            "description": "Organization name (default: chef)",
                        },
                        "pipeline": {
                            "type": "string",
                            "description": "Pipeline name (default: chef-chef-chef-18-validate-adhoc)",
                        },
                    },
                    "required": ["job_id"],
                },
            ),
            Tool(
                name="distill_buildkite_log_text",
                description="Distill raw Buildkite log text",
                inputSchema={
                    "type": "object",
                    "properties": {
                        "text": {
                            "type": "string",
                            "description": "Raw Buildkite log text",
                        },
                    },
                    "required": ["text"],
                },
            ),
            Tool(
                name="download_and_distill_github_actions_log",
                description="Download a GitHub Actions run log and return distilled content",
                inputSchema={
                    "type": "object",
                    "properties": {
                        "owner": {
                            "type": "string",
                            "description": "Repository owner (username or organization)",
                        },
                        "repo": {
                            "type": "string",
                            "description": "Repository name",
                        },
                        "run_id": {
                            "type": "string",
                            "description": "GitHub Actions run ID",
                        },
                    },
                    "required": ["owner", "repo", "run_id"],
                },
            ),
            Tool(
                name="distill_github_actions_log_text",
                description="Distill raw GitHub Actions log text",
                inputSchema={
                    "type": "object",
                    "properties": {
                        "text": {
                            "type": "string",
                            "description": "Raw GitHub Actions log text",
                        },
                    },
                    "required": ["text"],
                },
            ),
        ]
    
    async def handle_get_tool(self, name: str) -> Tool | None:
        """Get a specific tool."""
        tools = await self.handle_list_tools()
        for tool in tools:
            if tool.name == name:
                return tool
        return None
    
    async def handle_call_tool(self, name: str, arguments: dict) -> list[ToolResponse]:
        """Handle a tool call."""
        result = process_tool_call(name, arguments)
        return [ToolResponse(type="text", text=result)]
    
    async def run(self):
        """Run the server."""
        await self.server


def main():
    """Entry point."""
    import asyncio
    
    server = UnifiedLogsServer()
    asyncio.run(server.run())


if __name__ == "__main__":
    main()
