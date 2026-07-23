# Design Constraints: ALB with TLS Termination and Plaintext to Istio

## TLS Termination Strategy

- **External TLS**: ALB terminates client-facing TLS using an ACM-managed certificate
- **Internal traffic**: Plaintext HTTP from ALB to Istio Ingress Gateway on port 8080
- **No internal encryption**: Traffic between ALB and Istio is unencrypted

### Security Implications

- Traffic is unencrypted within the VPC between ALB and Istio pods
- Acceptable when: VPC is trusted, compliance does not require encryption in transit within the cluster
- **NOT suitable** for environments requiring end-to-end encryption (PCI-DSS, HIPAA without compensating controls)
- Istio mTLS still encrypts east-west traffic within the mesh

## Certificate Management

### External (ACM)
- Managed by AWS Certificate Manager — automatic renewal
- DNS validation via Route53 (automated in Terraform)
- No operational overhead for rotation

### Internal
- **No TLS certificate required** for ALB-to-Istio communication
- Cross-namespace cert sub-patterns are provided for mesh-internal TLS (service-to-service)
- Simpler operational model compared to Pattern 1 (TLS re-encryption)

## Architecture Decisions

### ClusterIP + IP Target Type
- Istio Ingress Gateway uses `ClusterIP` service type
- ALB target group uses `ip` target type, protocol `HTTP`, port `8080`
- **Trade-off**: Same networking requirements as Pattern 1 (pods must be routable from ALB)
- **Benefit**: Simplest configuration — no internal cert management for the ingress path

### Port 8080 (Non-privileged)
- Istio Gateway listens on port 8080 for HTTP traffic
- Non-privileged port avoids requiring elevated container permissions
- ALB listener on 443 (HTTPS) forwards to target group on 8080 (HTTP)

### X-Forwarded-For + numTrustedProxies
- ALB automatically adds X-Forwarded-For header
- Istio mesh config sets `numTrustedProxies: 1`
- Real client IP preserved through the proxy chain
- X-Forwarded-Proto header indicates original protocol was HTTPS

### Health Checks
- Port 15021 (Istio pilot agent) with path `/healthz/ready`
- Protocol: HTTP
- Same health check configuration as Pattern 1 — consistent across all ALB patterns

## When to Use This Pattern

**Appropriate for:**
- Development and staging environments
- Internal-only services where VPC is trusted
- Scenarios where operational simplicity outweighs internal encryption
- Applications that don't handle sensitive data in the ALB-to-Istio hop

**NOT appropriate for:**
- Production environments with strict compliance requirements
- Multi-tenant clusters where network isolation is insufficient
- Environments where traffic sniffing within the VPC is a concern

## Limitations

1. **No internal encryption**: Traffic between ALB and Istio is plaintext HTTP
2. **VPC trust assumption**: Security relies on VPC network controls
3. **Pod IP stability**: Same constraint as Pattern 1 — requires target group updates on pod changes
4. **No certificate validation**: ALB cannot verify Istio identity (no mutual TLS on this hop)

## Dependencies

| Component | Required | Purpose |
|-----------|----------|---------|
| AWS ALB | Yes | External load balancing + TLS termination |
| AWS ACM | Yes | External certificate management |
| AWS Load Balancer Controller | Recommended | Automatic target group registration |
| Route53 | Optional | ACM DNS validation |
| cert-manager | Optional | Only for mesh-internal cert management |

## Failure Modes

| Failure | Impact | Recovery |
|---------|--------|----------|
| ACM cert expires | ALB rejects client connections | ACM auto-renews; check DNS validation |
| Pod crash | ALB deregisters unhealthy target | Kubernetes restarts pod; ALB re-registers |
| Port 8080 blocked | ALB cannot reach Istio | Check security groups and network policies |
| Health check fails | Target deregistered | Verify Istio pilot agent is running |
