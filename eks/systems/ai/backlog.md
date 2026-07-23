Base Cluster Testing:
Date: 06/29/2026
Goal: Standup cluster
Base Cluster Tests: 
    Validate Cilium
    Validate Envoy
    Test Basic routing from Envoy to Test Pods
    Test Routing to Bedrock Endpoints
    Testing Routing to vLLM with Simple Model on g6 node

Next Step:
    First Principles of Infra and Inference Serving


Research:

Tieried Gateways 
    Tier One Routing/Auth
    Tier Two - self-hosted Modesl
    https://aigateway.envoyproxy.io/blog/envoy-ai-gateway-reference-architecture/

vLLM Optimizations



Research Tests:
    Gateways - Envoy vs Ai Gateways
    Inference Serving Componets - vLLM, SGLang, 


Base Cluster Backlog Changes:

- Module - Move to AWS EKS Module for deployment, easier for EFA and below changes - COMPLETE
- Infra Layer - Karpenter and AWS Load Balancer Controler Operators installed in Cluster Base  - COMPLETE
- Infra Layer - Update SG to allow ICMP
- Infra Layer - NVMe Volume - Add functionality to create NVMe disk is RAID Format
- Infra Layer - E2E Tests
- Platform Layer - Tier Storage - image cache, model cache etc
- Platform Layer - Tests Ray Job, Simple Inference Model Endpoint
- Security 



