################################################################################
# Flyte Workflow Orchestrator
# Deploys Flyte Binary (single binary mode) for simplified deployment
################################################################################

resource "helm_release" "flyte" {
  name             = "flyte"
  repository       = "https://flyteorg.github.io/flyte"
  chart            = "flyte-binary"
  version          = var.chart_version
  namespace        = "flyte"
  create_namespace = true
  timeout          = 600
  wait             = true

  set = [
    {
      name  = "configuration.database.postgres.enabled"
      value = "true"
    },
    {
      name  = "clusterResourceTemplates.enabled"
      value = "true"
    },
    {
      name  = "flyteadmin.enabled"
      value = "true"
    },
  ]
}
