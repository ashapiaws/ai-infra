# Design Constraints: Reflector (Annotation-Based Secret Replication)

## Approach

cert-manager generates self-signed TLS certificates and stores them in a source Kubernetes secret. The Reflector controller watches for secrets with specific annotations and automatically replicates them to the specified target namespaces.

## Architecture

```
cert-manager → Source Secret (with reflector annotations) → Reflector Controller → Target Secrets
```

## Dependencies

| Component | Version | Purpose |
|-----------|---------|---------|
| Reflector | >= 7.0 | Annotation-based secret replication |
| cert-manager | >= 1.13 | Certificate generation |

## Annotations Used

```yaml
reflector.v1/reflection-allowed: "true"
reflector.v1/reflection-allowed-namespaces: "ns-a,ns-b,ns-c"
reflector.v1/reflection-auto-enabled: "true"
reflector.v1/reflection-auto-namespaces: "ns-a,ns-b,ns-c"
```

## Operational Considerations

### Secret Rotation
- When cert-manager renews the certificate, the source secret is updated
- Reflector detects the change and propagates to all target namespaces
- Propagation is near-instant (event-driven, not polling)

### Namespace Selection
- Target namespaces are specified in annotations (comma-separated)
- Supports regex patterns for namespace matching
- New namespaces matching the pattern are automatically included

### Adding New Target Namespaces
- Update the annotation on the source secret
- Reflector will create the secret in the new namespace

## Limitations

1. **Annotation-based**: Namespace list is stored in annotations on the source secret — can become unwieldy with many namespaces
2. **No access control**: Any namespace listed in the annotation receives the secret — no additional authorization
3. **Single cluster**: Reflector only works within a single Kubernetes cluster
4. **Controller dependency**: If Reflector is down, new secrets/updates are not propagated (existing secrets remain)
5. **No audit trail**: No built-in logging of who accessed replicated secrets

## Advantages

1. **Simple setup**: Just annotations on the source secret
2. **Event-driven**: Near-instant propagation on secret changes
3. **No external dependencies**: Purely Kubernetes-native (no AWS services needed)
4. **Low operational overhead**: No IAM, no external secret stores
5. **Automatic cleanup**: When source secret is deleted, replicated copies are also removed

## Differences from Kubernetes Replicator

| Feature | Reflector | Kubernetes Replicator |
|---------|-----------|----------------------|
| Annotation prefix | `reflector.v1/` | `replicator.v1/` |
| Namespace regex | Supported | Supported |
| Label-based targeting | Limited | Supported |
| Auto-cleanup | Yes | Yes |
| Helm chart | emberstack/reflector | mittwald/kubernetes-replicator |
