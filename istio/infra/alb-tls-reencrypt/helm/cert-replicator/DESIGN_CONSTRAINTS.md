# Design Constraints: Kubernetes Replicator (Secret Replication)

## Approach

cert-manager generates self-signed TLS certificates and stores them in a source Kubernetes secret. The Kubernetes Replicator controller watches for secrets with specific annotations and replicates them to the specified target namespaces.

## Architecture

```
cert-manager → Source Secret (with replicator annotations) → Replicator Controller → Target Secrets
```

## Dependencies

| Component | Version | Purpose |
|-----------|---------|---------|
| Kubernetes Replicator | >= 2.9 | Annotation-based secret replication |
| cert-manager | >= 1.13 | Certificate generation |

## Annotations Used

```yaml
# Replicate to specific namespaces
replicator.v1/replicate-to: "ns-a,ns-b,ns-c"

# OR replicate to namespaces matching a label
replicator.v1/replicate-to-matching: "needs-istio-tls=true"
```

## Operational Considerations

### Secret Rotation
- When cert-manager renews the certificate, the source secret is updated
- Replicator detects the change and propagates to all target namespaces
- Propagation is event-driven (near-instant)

### Namespace Targeting Strategies
1. **Explicit list**: `replicator.v1/replicate-to: "ns-a,ns-b"`
2. **Label matching**: `replicator.v1/replicate-to-matching: "label=value"`
   - More dynamic — new namespaces with the label automatically receive the secret

### Adding New Target Namespaces
- **Explicit**: Update the annotation on the source secret
- **Label-based**: Add the matching label to the new namespace

## Limitations

1. **Annotation-based**: Same annotation size limits as Reflector
2. **No access control**: Any namespace in the target list receives the secret
3. **Single cluster**: Only works within one Kubernetes cluster
4. **Controller dependency**: If Replicator is down, updates are not propagated
5. **No audit trail**: No built-in access logging

## Advantages

1. **Label-based targeting**: More flexible than explicit namespace lists
2. **Simple setup**: Just annotations on the source secret
3. **Event-driven**: Near-instant propagation
4. **No external dependencies**: Purely Kubernetes-native
5. **Lightweight**: Minimal resource footprint

## Differences from Reflector

| Feature | Kubernetes Replicator | Reflector |
|---------|----------------------|-----------|
| Annotation prefix | `replicator.v1/` | `reflector.v1/` |
| Label-based targeting | Native support | Limited |
| Namespace regex | Via matching | Direct support |
| "Pull" replication | Supported (from annotation on target) | Not supported |
| Helm chart | mittwald/kubernetes-replicator | emberstack/reflector |
| Community | Mittwald | Emberstack |

## When to Choose Replicator over Reflector

- When you need label-based namespace targeting (dynamic namespace discovery)
- When you want "pull" replication (target namespace requests the secret)
- When you prefer the Mittwald ecosystem
