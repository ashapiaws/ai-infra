# Design Constraints: ALB with TLS Re-encryption to Istio

## TLS Termination Strategy

- **External TLS**: ALB terminates client-facing TLS using an ACM-managed certificate
- **Internal TLS**: ALB re-encrypts traffic using TLS 1.2+ before forwarding to Istio Ingress Gateway
- **End-to-end encryption**: Traffic is encrypted at every hop (client → ALB → Istio → mesh)

### Security Implications

- Dual certificate management: ACM for external, cert-manager (self-signed) for internal
- ALB has access to decrypted traffic momentarily during re-encryption
- Internal certificates are self-signed — not publicly trusted, but sufficient for ALB-to-Istio communication
- TLS 1.2 minimum enforced on both external (via SSL policy) and internal connections

## Certificate Management

### External (ACM)
- Managed by AWS Certificate Manager — automatic renewal
- DNS validation via Route53 (automated in Terraform)
- No operational overhead for rotation

### Internal (cert-manager)
- Self-signed CA issuer generates gateway certificates
- 90-day validity with 30-day renewal window (2/3 of validity)
- Certificates created via Helm hooks BEFORE Istio Gateway starts
- Cross-namespace sharing via one of three sub-patterns (ESO, Reflector, Replicator)

## Architecture Decisions

### ClusterIP + IP Target Type
- Istio Ingress Gateway uses `ClusterIP` service type
- ALB target group uses `ip` target type for direct pod routing
- **Trade-off**: Requires AWS VPC CNI or compatible networking; pods must be routable from ALB subnets
- **Benefit**: Eliminates NodePort overhead, enables direct health checks to pods

### X-Forwarded-For + numTrustedProxies
- ALB automatically adds X-Forwarded-For header
- Istio mesh config sets `numTrustedProxies: 1`
- Envoy extracts real client IP from the rightmost untrusted entry
- **Constraint**: If additional proxies exist between client and ALB, adjust numTrustedProxies accordingly

### Health Checks
- Port 15021 (Istio pilot agent) with path `/healthz/ready`
- Protocol: HTTP (even though target group uses HTTPS)
- **Rationale**: The status port is always HTTP regardless of gateway TLS configuration

## Limitations

1. **Self-signed certificates**: ALB does not validate the backend certificate by default, but if strict validation is needed, a publicly-trusted cert must be used for the internal hop
2. **Pod IP stability**: When pods restart, ALB target group must be updated (handled by AWS Load Balancer Controller or TargetGroupBinding)
3. **Certificate ordering**: If cert-manager is slow to issue, Istio Gateway pods will fail to start until the TLS secret is available
4. **No HTTP/2 multiplexing**: ALB re-encryption creates a new TLS session per connection to Istio

## Dependencies

| Component | Required | Purpose |
|-----------|----------|---------|
| AWS ALB | Yes | External load balancing + TLS termination |
| AWS ACM | Yes | External certificate management |
| cert-manager | Yes | Internal certificate generation |
| AWS Load Balancer Controller | Recommended | Automatic target group registration |
| Route53 | Optional | ACM DNS validation |

## Failure Modes

| Failure | Impact | Recovery |
|---------|--------|----------|
| ACM cert expires | ALB rejects client connections | ACM auto-renews; check DNS validation |
| Internal cert expires | ALB health checks fail, traffic stops | cert-manager auto-renews at 2/3 validity |
| cert-manager unavailable | No new certs issued; existing certs continue working | Restart cert-manager; existing certs valid until expiry |
| Pod crash | ALB deregisters unhealthy target | Kubernetes restarts pod; ALB re-registers when healthy |
| Secret replication fails | Target namespaces missing cert | Check replication controller logs |
