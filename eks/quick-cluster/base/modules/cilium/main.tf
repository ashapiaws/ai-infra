################################################################################
# Cilium CNI
# Deploys Cilium for advanced networking, eBPF-based dataplane,
# and optional network policy enforcement
################################################################################

resource "helm_release" "cilium" {
  name             = "cilium"
  repository       = "https://helm.cilium.io"
  chart            = "cilium"
  namespace        = "kube-system"
  timeout          = 600
  wait             = true

  set = [
    {
      name  = "eni.enabled"
      value = "true"
    },
    {
      name  = "ipam.mode"
      value = "eni"
    },
    {
      name  = "egressMasqueradeInterfaces"
      value = "eth0"
    },
    {
      name  = "routingMode"
      value = "native"
    },
    {
      name  = "hubble.relay.enabled"
      value = "true"
    },
    {
      name  = "hubble.ui.enabled"
      value = "true"
    },
  ]
}
