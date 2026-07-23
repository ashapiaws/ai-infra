"""
Model Registry

Central registry of all available models and their backend routing.
Add new models here — the rest of the app picks them up automatically.
"""

from dataclasses import dataclass, field
from enum import Enum
from typing import Optional


class Backend(str, Enum):
    """Supported inference backends."""

    VLLM = "vllm"  # Self-hosted vLLM via Envoy AI Gateway
    BEDROCK = "bedrock"  # AWS Bedrock via Mantle endpoint


@dataclass
class ModelConfig:
    """Configuration for a single model entry."""

    id: str  # Display ID shown in the UI / used in API calls
    backend: Backend
    backend_model_id: str  # Actual model identifier sent to the backend
    display_name: Optional[str] = None
    description: str = ""
    extra: dict = field(default_factory=dict)

    @property
    def name(self) -> str:
        return self.display_name or self.id


# ---------------------------------------------------------------------------
# Model definitions — extend this list to add new models
# ---------------------------------------------------------------------------

MODELS: list[ModelConfig] = [
    # --- Self-hosted vLLM models (routed via Envoy AI Gateway) ---
    ModelConfig(
        id="model-a",
        backend=Backend.VLLM,
        backend_model_id="model-a",
        display_name="Model A (vLLM)",
        description="Self-hosted model A behind Envoy AI Gateway",
    ),
    ModelConfig(
        id="model-b",
        backend=Backend.VLLM,
        backend_model_id="model-b",
        display_name="Model B (vLLM)",
        description="Self-hosted model B behind Envoy AI Gateway",
    ),
    # --- Bedrock models (routed via Mantle endpoint) ---
    ModelConfig(
        id="bedrock-claude-sonnet-4",
        backend=Backend.BEDROCK,
        backend_model_id="us.anthropic.claude-sonnet-4-20250514",
        display_name="Claude Sonnet 4 (Bedrock)",
        description="Anthropic Claude Sonnet 4 via Bedrock Mantle",
    ),
]

# Lookup helpers
_MODEL_MAP: dict[str, ModelConfig] = {m.id: m for m in MODELS}


def get_model(model_id: str) -> Optional[ModelConfig]:
    """Return model config by ID, or None if not found."""
    return _MODEL_MAP.get(model_id)


def list_models() -> list[dict]:
    """Return model list in OpenAI-compatible format."""
    return [
        {
            "id": m.id,
            "object": "model",
            "owned_by": m.backend.value,
            "display_name": m.name,
            "description": m.description,
        }
        for m in MODELS
    ]
