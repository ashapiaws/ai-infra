#!/usr/bin/env bash
# Validate health check endpoint for ALB TLS Re-encryption Pattern
# Verifies Istio pilot agent health endpoint on port 15021
set -euo pipefail

GATEWAY_POD_IP="${GATEWAY_POD_IP:-}"
HEALTH_PORT="${HEALTH_PORT:-15021}"
HEALTH_PATH="${HEALTH_PATH:-/healthz/ready}"
NAMESPACE="${NAMESPACE:-istio-system}"

echo "=== Health Check Validation: ALB TLS Re-encryption Pattern ==="

# Test 1: Check health endpoint via kubectl port-forward or direct pod IP
if [[ -n "$GATEWAY_POD_IP" ]]; then
  echo "[Test 1] Checking health endpoint at ${GATEWAY_POD_IP}:${HEALTH_PORT}${HEALTH_PATH}..."
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
    "http://${GATEWAY_POD_IP}:${HEALTH_PORT}${HEALTH_PATH}" \
    --max-time 5 || echo "000")
else
  echo "[Test 1] Checking health endpoint via kubectl..."
  POD_NAME=$(kubectl get pods -n "$NAMESPACE" -l app=istio-ingressgateway \
    -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

  if [[ -z "$POD_NAME" ]]; then
    echo "  FAIL: No Istio Ingress Gateway pod found in namespace $NAMESPACE"
    exit 1
  fi

  echo "  Found pod: $POD_NAME"
  HTTP_CODE=$(kubectl exec -n "$NAMESPACE" "$POD_NAME" -- \
    curl -s -o /dev/null -w "%{http_code}" \
    "http://localhost:${HEALTH_PORT}${HEALTH_PATH}" \
    --max-time 5 2>/dev/null || echo "000")
fi

if [[ "$HTTP_CODE" == "200" ]]; then
  echo "  PASS: Health endpoint returned HTTP $HTTP_CODE"
else
  echo "  FAIL: Health endpoint returned HTTP $HTTP_CODE (expected 200)"
  exit 1
fi

# Test 2: Verify port 15021 is exposed on the pod
echo "[Test 2] Verifying port 15021 is exposed..."
PORTS=$(kubectl get pods -n "$NAMESPACE" -l app=istio-ingressgateway \
  -o jsonpath='{.items[0].spec.containers[*].ports[*].containerPort}' 2>/dev/null || echo "")

if echo "$PORTS" | grep -q "15021"; then
  echo "  PASS: Port 15021 is exposed on the gateway pod"
else
  echo "  FAIL: Port 15021 not found in pod container ports"
  exit 1
fi

# Test 3: Verify service type is ClusterIP
echo "[Test 3] Verifying service type is ClusterIP..."
SVC_TYPE=$(kubectl get svc istio-ingressgateway -n "$NAMESPACE" \
  -o jsonpath='{.spec.type}' 2>/dev/null || echo "")

if [[ "$SVC_TYPE" == "ClusterIP" ]]; then
  echo "  PASS: Service type is ClusterIP (required for ALB IP target)"
else
  echo "  FAIL: Service type is '$SVC_TYPE' (expected ClusterIP)"
  exit 1
fi

echo ""
echo "=== All health check validation tests passed ==="
