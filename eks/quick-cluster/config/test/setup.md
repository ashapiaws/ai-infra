helm install kueue https://github.com/kubernetes-sigs/kueue/releases/download/v0.14.4/kueue-0.14.4.tgz \
  --namespace kueue-system \
  --create-namespace \
  --wait --timeout 300s


  https://kueue.sigs.k8s.io/docs/installation/#install-by-helm


  https://kueue.sigs.k8s.io/docs/concepts/topology_aware_scheduling/