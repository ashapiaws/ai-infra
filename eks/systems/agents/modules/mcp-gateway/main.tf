################################################################################
# MCP Gateway - Tool Registry & Routing
#
# Provides:
#   - Centralized registry of MCP tool servers
#   - Routes tool calls from agents to appropriate MCP servers
#   - Auth and rate-limiting on tool access
################################################################################

variable "chart_version" {
  type    = string
  default = "0.1.0"
}

variable "namespace" {
  type    = string
  default = "agents"
}

variable "tags" {
  type    = map(string)
  default = {}
}

# Placeholder — no public Helm chart yet for MCP Gateway.
# This module will be implemented when a chart or custom deployment is ready.

resource "kubernetes_namespace" "mcp_gateway" {
  metadata {
    name = var.namespace
    labels = {
      "app.kubernetes.io/component" = "mcp-gateway"
    }
  }
}

output "status" {
  value = "placeholder"
}
