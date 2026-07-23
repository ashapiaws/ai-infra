# Design Constraints: Kubernetes Replicator (ALB Plaintext Pattern)

## Context

In the ALB Plaintext pattern, TLS is terminated at the ALB and traffic to Istio is plaintext HTTP. This sub-pattern provides cross-namespace certificate management for **mesh-internal TLS** (service-to-service), not for the ALB-to-Istio hop.

## Architecture

Same as Pattern 1 Replicator sub-pattern — cert-manager generates certificates, Kubernetes Replicator replicates them across namespaces via annotations.

## Key Differences from Pattern 1

- Certificates are used for mesh-internal mTLS, not for the ingress gateway's external-facing TLS
- The Istio Gateway does NOT need a TLS secret for the ALB connection (plaintext)
- Cross-namespace secrets are for services that need to present certificates within the mesh

## Dependencies

Same as Pattern 1: Kubernetes Replicator controller, cert-manager.

## Limitations

Same as Pattern 1 Replicator sub-pattern. See `alb-tls-reencrypt/helm/cert-replicator/DESIGN_CONSTRAINTS.md` for full details.

## When to Use

- When mesh-internal services need shared TLS certificates across namespaces
- When you want label-based namespace targeting (dynamic discovery)
- When you prefer "pull" replication (target namespace requests the secret)
