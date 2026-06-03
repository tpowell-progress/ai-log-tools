#!/usr/bin/env python3
"""
Buildkite Logs MCP Server

Provides tools for downloading and distilling Buildkite job logs through the
Model Context Protocol.

Tools:
  - download_and_distill_buildkite_log: Download a job log and return distilled content
  - distill_buildkite_log_text: Distill raw log text
"""

import json
import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Any

# Try to import mcp, but allow graceful fallback for testing
try:
    from mcp.server.models import InitializationOptions
    from mcp.types import (
        Tool,
        TextContent,
        ToolResponse,
    )
    import mcp.server.stdio
except ImportError:
    # Fallback for development/testing
    pass


def distill_log_text(text: str) -> str:
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
            distilled = distill_log_text(raw_log)
            
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
            
            return distill_log_text(text)
        
        else:
            return f"Unknown tool: {name}"
    
    except Exception as e:
        return f"Error: {str(e)}"


class BuildkiteLogsServer:
    """MCP Server for Buildkite logs."""
    
    def __init__(self):
        self.server = mcp.server.stdio.stdio_server(self.handle_init, self.handle_call_tool, self.handle_list_tools, self.handle_get_tool)
    
    async def handle_init(self, options: InitializationOptions) -> dict:
        """Handle initialization."""
        return {
            "protocolVersion": "2024-11-05",
            "capabilities": {"tools": {}},
            "serverInfo": {
                "name": "buildkite-logs",
                "version": "1.0.0",
            },
        }
    
    async def handle_list_tools(self) -> list[Tool]:
        """List available tools."""
        return [
            Tool(
                name="download_and_distill_buildkite_log",
                description="Download a Buildkite job log and return distilled content (noise removed)",
                inputSchema={
                    "type": "object",
                    "properties": {
                        "job_id": {
                            "type": "string",
                            "description": "The Buildkite job ID (UUID format)",
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
                description="Distill raw log text by removing noise (timestamps, UUIDs, progress bars, etc)",
                inputSchema={
                    "type": "object",
                    "properties": {
                        "text": {
                            "type": "string",
                            "description": "Raw log text to distill",
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
    
    server = BuildkiteLogsServer()
    asyncio.run(server.run())


if __name__ == "__main__":
    main()
