#!/usr/bin/env bash
# Validate health check endpoint for ALB Plaintext Pattern
# Verifies Istio pilot agent health endpoint on port 15021
set -euo pipefail

NAMESPACE="${NAMESPACE:-istio-system}"
HEALTH_PORT="${HEALTH_PORT:-15021}"
HEALTH_PATH="${HEALTH_PATH:-/healthz/ready}"

echo "=== Health Check Validation: ALB Plaintext Pattern ==="

# Test 1: Check health endpoint via kubectl
echo "[Test 1] Checking health endpoint..."
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

if [[ "$HTTP_CODE" == "200" ]]; then
  echo "  PASS: Health endpoint returned HTTP $HTTP_CODE"
else
  echo "  FAIL: Health endpoint returned HTTP $HTTP_CODE (expected 200)"
  exit 1
fi

# Test 2: Verify service type is ClusterIP
echo "[Test 2] Verifying service type is ClusterIP..."
SVC_TYPE=$(kubectl get svc istio-ingressgateway -n "$NAMESPACE" \
  -o jsonpath='{.spec.type}' 2>/dev/null || echo "")

if [[ "$SVC_TYPE" == "ClusterIP" ]]; then
  echo "  PASS: Service type is ClusterIP"
else
  echo "  FAIL: Service type is '$SVC_TYPE' (expected ClusterIP)"
  exit 1
fi

# Test 3: Verify port 8080 is exposed (plaintext traffic port)
echo "[Test 3] Verifying port 8080 is exposed..."
SVC_PORTS=$(kubectl get svc istio-ingressgateway -n "$NAMESPACE" \
  -o jsonpath='{.spec.ports[*].port}' 2>/dev/null || echo "")

if echo "$SVC_PORTS" | grep -q "8080"; then
  echo "  PASS: Port 8080 is exposed on the service"
else
  echo "  FAIL: Port 8080 not found in service ports (found: $SVC_PORTS)"
  exit 1
fi

echo ""
echo "=== All health check validation tests passed ==="
