# Envoy Gateway — Backlog & Hub-Spoke Routing Roadmap

## Current State (Phase 0)

Static Envoy bootstrap on a single cluster. ConfigMap-driven routing with hardcoded upstreams. Good for learning Envoy internals and validating basic L7 routing.

---

## Phase 1: Single Cluster — Custom Envoy Fundamentals

**Goal:** Validate core Envoy capabilities before adding multi-cluster complexity.

| Task | Description | Status |
|------|-------------|--------|
| Deploy base Envoy | Static bootstrap, namespace isolation, NLB exposure | TODO |
| Route to inference | /api/inference → vLLM service in inference namespace | TODO |
| Route to Bedrock | /api/bedrock → external Bedrock endpoint via Envoy cluster | TODO |
| Header-based routing | Route by `x-model-id` header to different backends | TODO |
| Rate limiting | Local rate limiter filter per route | TODO |
| Observability | Expose /stats, integrate with Prometheus, Grafana dashboard | TODO |
| mTLS between Envoy and backends | SPIFFE/cert-manager for workload identity | TODO |
| Admin interface lockdown | Network policy restricting admin port access | TODO |

---

## Phase 2: xDS Control Plane — Dynamic Configuration

**Goal:** Move from static config to dynamic discovery. This is the prerequisite for multi-cluster.

| Task | Description | Status |
|------|-------------|--------|
| Deploy xDS control plane | Options: go-control-plane, Envoy Gateway, or custom gRPC server | TODO |
| Migrate listeners to LDS | Listeners discovered dynamically via Listener Discovery Service | TODO |
| Migrate routes to RDS | Route tables pushed from control plane | TODO |
| Migrate clusters to CDS | Backend clusters registered dynamically | TODO |
| Endpoint discovery (EDS) | Pod IPs resolved via Endpoint Discovery Service | TODO |
| Secret discovery (SDS) | TLS certs rotated via Secret Discovery Service | TODO |
| Config versioning | Control plane versions configs, supports rollback | TODO |
| Canary route deployment | Push new routes to subset of Envoy instances first | TODO |

**Key Decision:** Control plane choice

| Option | Pros | Cons |
|--------|------|------|
| Envoy Gateway (K8s native) | Gateway API CRDs, active community, simple | K8s only, less flexible for multi-cluster |
| go-control-plane (custom) | Full control, multi-cluster aware from day one | Build and maintain yourself |
| Gloo Edge | Enterprise features, OIDC, WAF | Commercial, heavier |

---

## Phase 3: Hub-and-Spoke Multi-Cluster Routing

**Goal:** Central Envoy cluster (hub) routes traffic to workload clusters (spokes). Spokes register themselves; hub makes routing decisions.

### Architecture

```
                         ┌─────────────────────────────────┐
                         │         HUB CLUSTER              │
                         │                                  │
  Internet/Internal ──▶  │  ┌────────────────────────────┐ │
                         │  │  Envoy Fleet (xDS-driven)   │ │
                         │  │                              │ │
                         │  │  LDS: listeners per domain   │ │
                         │  │  RDS: routes per model/path  │ │
                         │  │  CDS: spoke clusters         │ │
                         │  │  EDS: spoke endpoints        │ │
                         │  └────────────┬─────────────────┘ │
                         │               │                   │
                         │  ┌────────────▼─────────────────┐ │
                         │  │  xDS Control Plane            │ │
                         │  │  (cluster registry, health)   │ │
                         │  └────────────┬─────────────────┘ │
                         └───────────────┼───────────────────┘
                                         │
                    ┌────────────────────┼────────────────────┐
                    │                    │                    │
          ┌─────────▼────────┐  ┌────────▼───────┐  ┌────────▼───────┐
          │  SPOKE: Inference │  │ SPOKE: Training│  │ SPOKE: Agents  │
          │                   │  │                │  │                │
          │  vLLM / SGLang    │  │  Ray / Flyte   │  │  Temporal      │
          │  GPU nodes        │  │  GPU nodes     │  │  CPU nodes     │
          │                   │  │                │  │                │
          │  Envoy sidecar    │  │  Envoy sidecar │  │  Envoy sidecar │
          │  (reports to hub) │  │  (reports)     │  │  (reports)     │
          └───────────────────┘  └────────────────┘  └────────────────┘
```

### Spoke Registration Flow

1. Spoke cluster deploys a lightweight Envoy sidecar + registration agent
2. Registration agent calls hub control plane gRPC endpoint
3. Agent reports: cluster ID, available services, endpoints, health
4. Hub control plane updates CDS/EDS for the spoke
5. Hub Envoy fleet picks up new endpoints via xDS stream
6. Traffic flows: client → hub Envoy → spoke Envoy → workload pod

### Tasks

| Task | Description | Status |
|------|-------------|--------|
| Hub control plane design | gRPC service: RegisterCluster, DeregisterCluster, Heartbeat | TODO |
| Spoke registration agent | Sidecar that watches local services and reports to hub | TODO |
| Cross-cluster networking | VPC peering or Transit Gateway between hub and spoke VPCs | TODO |
| DNS strategy | Private hosted zones per spoke, or hub resolves spoke IPs directly | TODO |
| Hub CDS configuration | Each spoke becomes an Envoy cluster with STRICT_DNS or EDS | TODO |
| Weighted routing | Route 80% to spoke-A (vLLM), 20% to spoke-B (SGLang) | TODO |
| Failover routing | If spoke-A health check fails, 100% to spoke-B | TODO |
| Circuit breaking | Per-spoke connection limits, retry budgets | TODO |
| Locality-aware routing | Prefer same-AZ spokes, fallback to cross-AZ | TODO |
| Observability (hub) | Per-spoke latency, error rate, throughput dashboards | TODO |
| Auth propagation | Hub validates JWT, passes identity headers to spokes | TODO |
| Spoke-level rate limiting | Per-spoke capacity limits enforced at hub | TODO |

---

## Phase 4: Advanced Patterns

### Model-Aware Routing (AI-Specific)

| Task | Description | Status |
|------|-------------|--------|
| Model registry integration | Control plane reads model catalog, maps model → spoke | TODO |
| Token budget routing | Route based on estimated token cost, not just RPS | TODO |
| Inference queue spillover | If spoke GPU queue > threshold, spill to Bedrock | TODO |
| A/B model routing | Route % of traffic to new model version on separate spoke | TODO |
| Model warmup routing | New model gets shadow traffic before receiving live | TODO |

### Operational Maturity

| Task | Description | Status |
|------|-------------|--------|
| GitOps for route config | Envoy routes in Git, ArgoCD syncs to control plane | TODO |
| Spoke auto-discovery | New EKS cluster auto-registers via cluster labels | TODO |
| Chaos testing | Fault injection at hub (delay, abort, partition) | TODO |
| Cost attribution | Per-spoke, per-model traffic volume for chargeback | TODO |
| Multi-region hub | Active-active hubs in us-west-2 and us-east-1 | TODO |

---

## Key Design Decisions (to resolve)

| Decision | Options | Notes |
|----------|---------|-------|
| Cross-cluster transport | VPC Peering vs Transit Gateway vs PrivateLink | TGW more scalable, Peering simpler for <5 spokes |
| Spoke Envoy role | Full proxy vs transparent sidecar | Full proxy gives spoke autonomy, sidecar is lighter |
| Hub HA | Active-passive vs active-active | Active-active needs shared xDS state (etcd/Redis) |
| Config store | etcd vs PostgreSQL vs CRDs | CRDs if staying K8s-native, etcd for raw performance |
| Health checking | Hub-initiated vs spoke-reported | Both — hub active probes + spoke heartbeats |

---

## Reference Material

- [Envoy xDS Protocol](https://www.envoyproxy.io/docs/envoy/latest/api-docs/xds_protocol)
- [go-control-plane](https://github.com/envoyproxy/go-control-plane)
- [Envoy Gateway](https://gateway.envoyproxy.io/)
- [Envoy AI Gateway Reference Architecture](https://aigateway.envoyproxy.io/blog/envoy-ai-gateway-reference-architecture/)
- [Multi-Cluster Envoy Mesh (Istio approach)](https://istio.io/latest/docs/setup/install/multicluster/)
- [AWS Transit Gateway for EKS](https://docs.aws.amazon.com/eks/latest/userguide/network-reqs.html)

---

## Priority Order

```
Phase 1 (now)     → Learn Envoy, validate routing primitives
Phase 2 (next)    → xDS control plane, dynamic config
Phase 3 (target)  → Hub-spoke multi-cluster routing
Phase 4 (stretch) → Model-aware routing, multi-region
```

Each phase is independently valuable. You don't need Phase 4 to get value from Phase 1.
