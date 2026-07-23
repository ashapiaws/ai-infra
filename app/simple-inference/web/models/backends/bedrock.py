"""
Bedrock Backend (Mantle Endpoint)

Routes inference requests to AWS Bedrock via the bedrock-mantle endpoint,
which provides an OpenAI-compatible Chat Completions API.

Configuration (environment variables):
    BEDROCK_API_KEY   - Bedrock API key for authentication
    BEDROCK_REGION    - AWS region (default: us-west-2)

The endpoint follows the pattern:
    https://bedrock-mantle.{region}.api.aws/v1/chat/completions
"""

import os
from typing import AsyncIterator

import httpx

BEDROCK_API_KEY = os.environ.get("BEDROCK_API_KEY", "")
BEDROCK_REGION = os.environ.get("BEDROCK_REGION", "us-west-2")


def _base_url() -> str:
    """Build the Bedrock Mantle base URL for the configured region."""
    return f"https://bedrock-mantle.{BEDROCK_REGION}.api.aws/v1"


def _headers() -> dict:
    """Return auth headers for Bedrock Mantle requests."""
    return {
        "Authorization": f"Bearer {BEDROCK_API_KEY}",
        "Content-Type": "application/json",
    }


async def chat_completion(payload: dict) -> dict:
    """Send a non-streaming chat completion to Bedrock Mantle."""
    async with httpx.AsyncClient(timeout=120) as client:
        resp = await client.post(
            f"{_base_url()}/chat/completions",
            json=payload,
            headers=_headers(),
        )
        resp.raise_for_status()
        return resp.json()


async def chat_completion_stream(payload: dict) -> AsyncIterator[bytes]:
    """Stream SSE chunks from Bedrock Mantle."""
    async with httpx.AsyncClient(timeout=120) as client:
        async with client.stream(
            "POST",
            f"{_base_url()}/chat/completions",
            json=payload,
            headers=_headers(),
        ) as resp:
            async for chunk in resp.aiter_bytes():
                yield chunk
