# Agents Platform

Infrastructure for running autonomous AI agents with durable execution, state management, and tool access.

## Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│                      Agents Platform                              │
├──────────────────────────────────────────────────────────────────┤
│                                                                    │
│  State & Messaging                                                 │
│  ┌──────────┐                                                     │
│  │  Redis   │  Session state, pub/sub, short-term memory           │
│  └──────────┘                                                     │
│                                                                    │
│  Durable Execution                                                 │
│  ┌──────────┐                                                     │
│  │ Temporal │  Long-running agent workflows, retries, saga         │
│  └──────────┘                                                     │
│                                                                    │
│  Tool Access                                                       │
│  ┌──────────────┐                                                 │
│  │ MCP Gateway  │  Tool registry, routing to MCP servers           │
│  └──────────────┘                                                 │
│                                                                    │
└──────────────────────────────────────────────────────────────────┘
```

## Components

| Component | Purpose |
|-----------|---------|
| Redis | Agent session state, pub/sub messaging, vector similarity |
| Temporal | Durable workflow execution for multi-step agent tasks |
| MCP Gateway | Centralized tool registry and MCP server routing |

## Usage

```bash
terraform init
terraform plan -var-file=dev.tfvars
terraform apply -var-file=dev.tfvars
```

## How Agents Use the Inference Platform

Agents call the inference platform's gateway endpoint for LLM completions:
- Agent → Tier 1 Gateway (auth + routing) → vLLM/SGLang/Bedrock
- The gateway URL is output by the inference platform: `systems/inference` → `gateway_url`

## Future Additions

- **Vector store** (Qdrant/Milvus) for agent long-term memory
- **Sandbox runtime** for code execution agents
- **Guardrails service** for safety filtering
