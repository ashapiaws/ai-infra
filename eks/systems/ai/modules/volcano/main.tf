################################################################################
# Volcano Batch Scheduler
# Gang scheduling and batch job management for ML/HPC workloads
################################################################################

resource "helm_release" "volcano" {
  name             = "volcano"
  repository       = "https://volcano-sh.github.io/helm-charts"
  chart            = "volcano"
  version          = var.chart_version
  namespace        = "volcano-system"
  create_namespace = true
  timeout          = 300
  wait             = true

  set = [
    {
      name  = "basic.controller_enable"
      value = "true"
    },
    {
      name  = "basic.scheduler_enable"
      value = "true"
    },
    {
      name  = "basic.admission_enable"
      value = "true"
    },
  ]
}
