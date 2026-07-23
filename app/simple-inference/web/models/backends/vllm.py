"""
vLLM Backend

Routes inference requests to self-hosted vLLM instances via the Envoy AI Gateway.
"""

import os
from typing import AsyncIterator

import httpx

GATEWAY_URL = os.environ.get(
    "GATEWAY_URL",
    "http://envoy-ai-gateway.envoy-ai-gateway.svc.cluster.local:8080",
)


async def chat_completion(payload: dict) -> dict:
    """Send a non-streaming chat completion to the vLLM gateway."""
    async with httpx.AsyncClient(timeout=120) as client:
        resp = await client.post(
            f"{GATEWAY_URL}/v1/chat/completions",
            json=payload,
        )
        resp.raise_for_status()
        return resp.json()


async def chat_completion_stream(payload: dict) -> AsyncIterator[bytes]:
    """Stream SSE chunks from the vLLM gateway."""
    async with httpx.AsyncClient(timeout=120) as client:
        async with client.stream(
            "POST",
            f"{GATEWAY_URL}/v1/chat/completions",
            json=payload,
        ) as resp:
            async for chunk in resp.aiter_bytes():
                yield chunk
