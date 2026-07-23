# EKS + Karpenter vs. SageMaker HyperPod — Customer Discovery Guide

## Framing note

SageMaker HyperPod is not a separate compute substrate from EKS — "HyperPod on EKS" *uses* an EKS cluster as its orchestrator and control plane. HyperPod adds a managed layer on top of (or beside) EKS: resilient instance provisioning, a health-monitoring/auto-recovery agent, a training operator, task governance (Kueue-based quota/priority scheduling), built-in observability wiring, and — as of Sept 2025 — a managed, Karpenter-based autoscaler. So the real decision for most customers isn't "EKS or HyperPod" in isolation, it's "self-managed EKS + Karpenter + DIY resiliency tooling" vs. "EKS + HyperPod's managed resiliency/governance/observability layer." Some customers also run HyperPod with Slurm instead of EKS as the orchestrator — worth clarifying early which comparison the customer actually means.

## Your stated framing (confirmed accurate)

- **Management model**: SMHP is the more managed solution; EKS + Karpenter gives more flexibility operationally and architecturally.
- **Advanced ML-specific features**: SMHP's scheduler/health system gives you checkpoint-aware process recovery, elastic scaling, and built-in observability out of the box.
- **Bleeding edge**: Self-managed EKS lets you stay current with upstream OSS (latest Karpenter, CNI, schedulers, kubelet versions, community operators) without waiting on AWS to support/validate them for HyperPod.
- **Cost — correction**: HyperPod's `ml.*` instances carry a real, consistent premium over the equivalent raw EC2 instance, generally in the **~15-40% range** depending on instance family and source. Confirmed example: `g6e.4xlarge` in us-east-2 is $3.998/hr on EC2 vs. $4.998/hr as `ml.g6e.4xlarge` on HyperPod — a ~25% premium. This is not a "slight upcost" — model it explicitly in any cost comparison rather than assuming near-parity. The premium buys you the managed resiliency/health-monitoring/governance/observability layer bundled in; on self-managed EKS you'd pay close to raw EC2 rates but need to build or license that tooling yourself (engineering time, or third-party tooling cost, or accepted operational risk). Whether the ml.* premium is cheaper or more expensive than the fully-loaded cost of DIY tooling is workload- and team-dependent and worth modeling with the customer's actual instance mix and scale rather than assuming either way.

## Additional design, security, resiliency, and operational differences to raise

### Resiliency & fault handling
- **Automatic node health monitoring**: HyperPod runs a health-monitoring agent doing continuous basic + deep health checks (GPU, network, etc.) and can auto-replace or auto-reboot faulty nodes without human intervention. On vanilla EKS you'd need to build this (e.g., Node Problem Detector + custom remediation, or third-party tools) or rely on EC2/ASG-level health checks only, which don't understand GPU-specific failure signatures.
- **Job auto-resume tied to checkpoints**: HyperPod's auto-resume detects a training failure, replaces the faulty node(s), and automatically restarts the job from the last checkpoint — AWS claims up to 40% training time savings from avoiding full restarts. This requires your training framework to checkpoint in a way HyperPod's operator understands (works with the HyperPod training operator / Slurm auto-resume). On EKS you'd implement this yourself via a training operator (e.g., Kubeflow Training Operator, custom controller) and your own checkpoint/restart logic.
- **Manual remediation APIs**: HyperPod also exposes explicit Reboot/Replace APIs for manual intervention, consistent across orchestrators (EKS or Slurm) — a more transparent, faster path than raw EC2/ASG replacement.
- **Blast radius of failures**: On EKS, a node failure is a Kubernetes-level event you handle with your own controllers; nothing understands "this is a distributed training job that needs coordinated restart across all ranks" unless you build it.

### Scheduling & multi-tenant governance
- **Task governance (Kueue-based)**: HyperPod layers fine-grained compute quota allocation, priority classes, preemption, and idle-capacity borrowing across teams — designed for shared GPU clusters where training, evaluation, inference, and interactive dev workloads compete for scarce accelerators. This is genuinely differentiated: you *can* build Kueue yourself on plain EKS (it's open source), but HyperPod pre-integrates it with cluster-level quota administration UI/APIs and per-team compute allocation out of the box.
- **Elastic/continuous provisioning + managed Karpenter**: HyperPod's newer autoscaling is explicitly built on a managed Karpenter implementation — AWS runs and patches the Karpenter controllers for you and ties scaling decisions into HyperPod's resiliency system. Self-managed Karpenter on EKS means you own controller upgrades, NodePool/NodeClass tuning, and drift/disruption handling yourself — more flexible (you can customize consolidation policies, use any provider features immediately) but more toil.

### Observability
- **Built-in dashboards**: HyperPod ships a pre-built CloudWatch Container Insights integration (cluster/node/task-level GPU and hardware health) plus a "one-click" Prometheus + Grafana setup pre-tuned for FM development (hardware health, utilization, task-level performance across 9 metric categories). On plain EKS, Container Insights and AMP/AMG are available but you assemble the dashboards, alerting, and GPU-specific metrics yourself (DCGM exporter, custom Grafana boards, etc.).
- **Usage/cost accountability reporting**: HyperPod Usage Reports give per-team/task financial accountability on top of the operational metrics — a governance feature, not just monitoring.

### Security & isolation
- **Shared control plane, AWS-managed data plane pieces**: With HyperPod on EKS, AWS still requires you to secure API server access with least privilege and to lock down network egress from the cluster — this responsibility doesn't go away just because HyperPod manages more of the compute layer.
- **IAM/permission surface**: HyperPod introduces its own IAM actions/roles (cluster creation, task governance administration, observability add-on) in addition to standard EKS IAM/RBAC and IRSA — slightly larger permission surface to model in your IAM strategy, and something security reviewers will want mapped explicitly.
- **Add-on trust boundary**: The HyperPod training operator, task governance, and observability pieces are installed as EKS add-ons with their own CRDs and controllers running with elevated privileges in-cluster — worth reviewing like any other privileged add-on (comparable to installing Karpenter, cluster-autoscaler, or a service mesh yourself).
- **Patch/CVE responsibility**: On self-managed EKS + Karpenter, you own patching Karpenter, CNI, and any DIY resiliency/observability tooling. HyperPod's managed pieces (health agent, managed Karpenter, training operator) are patched by AWS — reduces your patching surface but also means you're on AWS's release cadence for those components, tying back to the "bleeding edge" trade-off you already called out.

### Operational / day-2
- **Upgrade cadence coupling**: Self-managed EKS lets you upgrade Kubernetes, Karpenter, and add-ons independently and immediately. HyperPod's managed components (training operator, managed Karpenter, health agent) are versioned and released by AWS — you gain less operational toil but move at AWS's pace and are constrained to their supported instance types/AMIs for HyperPod-labeled node pools.
- **Portability across orchestrators**: A relevant SMHP-specific advantage — HyperPod clusters can be shared/reused across Slurm and EKS orchestration (or moved between them), and the Reboot/Replace APIs work "across all orchestrators." If the customer might use Slurm for some teams and Kubernetes for others, that's a differentiator worth surfacing.
- **Spot & flexible training plans**: HyperPod supports Spot Instances (up to 90% off on-demand) and "flexible training plans" (reserve capacity for a defined timeline/duration with automated setup and fault recovery) — a capacity-planning capability with no direct EKS equivalent; on EKS you'd combine EC2 Spot + Karpenter consolidation + your own capacity reservation strategy manually.
- **Savings Plans/commitment mechanics differ**: Standard EC2 Instance Savings Plans/RIs apply directly to self-managed EKS worker nodes. HyperPod instance usage needs SageMaker Savings Plans (up to 64% off list) instead — a different commitment vehicle, and it's the mechanism that claws back some of the on-demand `ml.*` premium noted above. If a customer already holds EC2 Savings Plans/RIs, those don't apply to HyperPod usage — factor a separate commitment strategy (and the transition cost/risk of splitting commitments) into the comparison.
- **Non-HyperPod costs still apply**: AWS is explicit that HyperPod pricing does not cover EKS control plane, FSx for Lustre, or S3 charges connected to the cluster — those are billed separately regardless of which path you choose, so they shouldn't factor into the EKS-vs-HyperPod cost delta itself.

## Discovery questions to guide the conversation

### Workload & scale
1. Is this primarily large-scale distributed training (multi-week/month jobs), fine-tuning, batch inference, real-time inference, or a mix? (HyperPod's resiliency story is strongest for long-running training; less differentiated for stateless inference.)
2. What GPU/accelerator scale are we talking about — tens, hundreds, thousands of accelerators? At what scale does a single node failure currently cost you the most wall-clock time?
3. How often do you see hardware failures (GPU ECC errors, NVLink/EFA issues, node drops) today, and how do you currently detect and recover from them?

### Current state & team
4. What's your team's current Kubernetes operational maturity — do you already run and patch Karpenter, cluster-autoscaler, or similar controllers in-house?
5. Do you have existing investment in open-source ML scheduling/tooling (Kueue, Volcano, Ray, custom operators) that you'd want to keep using as-is?
6. Is your team more comfortable operating infrastructure themselves, or do you want AWS to own more of the operational burden even at the cost of some flexibility?

### Multi-tenancy & governance
7. Will multiple teams share the same GPU cluster? If so, how do you handle quota, priority, and preemption today?
8. Do you need chargeback/cost-accountability reporting per team or project?
9. Do you need interactive development (notebooks/IDE-in-cluster) coexisting with production training/inference workloads on the same capacity?

### Resiliency requirements
10. What's your tolerance for a training job restarting from scratch vs. resuming from the last checkpoint? How is checkpointing implemented today (framework-native, custom)?
11. Do you need automated node replacement, or is manual/on-call-driven remediation acceptable?
12. Do any workloads need to run across multiple orchestrators (e.g., some teams on Slurm, others on Kubernetes) against the same physical cluster?

### Security & compliance
13. What are your requirements around who/what can access the EKS API server and what network egress is permitted from the cluster?
14. Do you have existing IAM/RBAC governance standards that a HyperPod add-on's additional roles and CRDs would need to fit into?
15. Are there regulatory or internal audit requirements around patch cadence and CVE response time for cluster components that would favor AWS-managed patching vs. self-managed?

### Cost & commercial
16. Do you already hold EC2 Savings Plans/RIs you'd want to apply to this workload, or are you starting fresh on commitment strategy?
17. Is Spot capacity or flexible/time-boxed capacity planning (e.g., a known training run with a deadline) relevant to how you'd consume GPU capacity?
18. How is your organization currently budgeting/tracking GPU spend — do you need built-in usage reporting, or do you have existing cost allocation tooling?
19. Given the ~15-40% on-demand premium on `ml.*` instances, what's the fully-loaded cost of the engineering time you'd otherwise spend building/maintaining equivalent resiliency, governance, and observability tooling on self-managed EKS? At your scale, does that offset the premium?

### Roadmap & flexibility
20. How important is staying on the absolute latest Kubernetes/Karpenter/CNI versions vs. accepting AWS's validated release cadence for a managed layer?
21. Are you likely to want to move workloads between AWS and other environments (on-prem, other clouds) — does that push toward keeping more of the stack self-managed/open-source for portability?
