
Infra 

Amazon EKS Cluster
3 Nodes


AWS LB Controller Install:


Promethues Install:
- IRSA/Pod Identity
- Collectors 
- S3 Storage

Grafana Install:
- IRSA/Pod Identity
- Pull in Metrics
- Dedicated Namespace: grafana
- Expose through AWS LB


Analytics Platform:

Trino(future)
Query Data in S3

Ingestion?
