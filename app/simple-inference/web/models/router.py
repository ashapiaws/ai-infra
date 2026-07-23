"""
Model Router

Dispatches chat requests to the correct backend based on the model registry.
Adding a new backend only requires:
  1. Creating a new module in models/backends/
  2. Registering a model in models/registry.py with the new Backend enum value
  3. Adding a case to the dispatch logic below
"""

from typing import AsyncIterator

import httpx

from models.registry import Backend, ModelConfig, get_model
from models.backends import bedrock, vllm


class ModelNotFoundError(Exception):
    """Raised when the requested model ID is not in the registry."""

    pass


class BackendError(Exception):
    """Raised when the backend returns a non-2xx response."""

    def __init__(self, status_code: int, detail: str):
        self.status_code = status_code
        self.detail = detail
        super().__init__(f"Backend error {status_code}: {detail}")


def _resolve_model(model_id: str) -> ModelConfig:
    """Look up the model config or raise."""
    config = get_model(model_id)
    if config is None:
        raise ModelNotFoundError(f"Unknown model: {model_id}")
    return config


def _build_payload(config: ModelConfig, body: dict) -> dict:
    """Build the backend-specific payload from the user request body."""
    return {
        "model": config.backend_model_id,
        "messages": body.get("messages", []),
        "stream": body.get("stream", True),
        "max_tokens": body.get("max_tokens", 1024),
        "temperature": body.get("temperature", 0.7),
    }


async def route_chat(body: dict) -> dict:
    """Route a non-streaming chat request to the appropriate backend."""
    model_id = body.get("model", "model-a")
    config = _resolve_model(model_id)
    payload = _build_payload(config, body)
    payload["stream"] = False

    try:
        if config.backend == Backend.VLLM:
            return await vllm.chat_completion(payload)
        elif config.backend == Backend.BEDROCK:
            return await bedrock.chat_completion(payload)
        else:
            raise ModelNotFoundError(f"Unsupported backend: {config.backend}")
    except httpx.HTTPStatusError as e:
        raise BackendError(e.response.status_code, e.response.text)


async def route_chat_stream(body: dict) -> AsyncIterator[bytes]:
    """Route a streaming chat request to the appropriate backend."""
    model_id = body.get("model", "model-a")
    config = _resolve_model(model_id)
    payload = _build_payload(config, body)
    payload["stream"] = True

    try:
        if config.backend == Backend.VLLM:
            async for chunk in vllm.chat_completion_stream(payload):
                yield chunk
        elif config.backend == Backend.BEDROCK:
            async for chunk in bedrock.chat_completion_stream(payload):
                yield chunk
        else:
            raise ModelNotFoundError(f"Unsupported backend: {config.backend}")
    except httpx.HTTPStatusError as e:
        raise BackendError(e.response.status_code, e.response.text)
