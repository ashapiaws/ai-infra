#!/usr/bin/env bash
# Validate cross-namespace secret replication for ALB Plaintext Pattern
# Verifies TLS secrets exist in all target namespaces with matching content
set -euo pipefail

SECRET_NAME="${SECRET_NAME:-istio-mesh-tls}"
SOURCE_NAMESPACE="${SOURCE_NAMESPACE:-istio-system}"
TARGET_NAMESPACES="${TARGET_NAMESPACES:-default}"

echo "=== Secret Replication Validation: ALB Plaintext Pattern ==="
echo "Secret Name: $SECRET_NAME"
echo "Source Namespace: $SOURCE_NAMESPACE"
echo "Target Namespaces: $TARGET_NAMESPACES"
echo ""

# Test 1: Verify source secret exists
echo "[Test 1] Checking source secret in $SOURCE_NAMESPACE..."
SOURCE_EXISTS=$(kubectl get secret "$SECRET_NAME" -n "$SOURCE_NAMESPACE" \
  -o jsonpath='{.metadata.name}' 2>/dev/null || echo "")

if [[ "$SOURCE_EXISTS" == "$SECRET_NAME" ]]; then
  echo "  PASS: Source secret exists in $SOURCE_NAMESPACE"
else
  echo "  FAIL: Source secret '$SECRET_NAME' not found in $SOURCE_NAMESPACE"
  exit 1
fi

# Test 2: Verify secret type
echo "[Test 2] Checking secret type..."
SECRET_TYPE=$(kubectl get secret "$SECRET_NAME" -n "$SOURCE_NAMESPACE" \
  -o jsonpath='{.type}' 2>/dev/null || echo "")

if [[ "$SECRET_TYPE" == "kubernetes.io/tls" ]]; then
  echo "  PASS: Secret type is kubernetes.io/tls"
else
  echo "  FAIL: Secret type is '$SECRET_TYPE' (expected kubernetes.io/tls)"
  exit 1
fi

# Test 3: Verify replication to target namespaces
echo "[Test 3] Checking target namespaces..."
IFS=',' read -ra NAMESPACES <<< "$TARGET_NAMESPACES"
ALL_PASS=true

SOURCE_HASH=$(kubectl get secret "$SECRET_NAME" -n "$SOURCE_NAMESPACE" \
  -o jsonpath='{.data.tls\.crt}' 2>/dev/null | sha256sum | cut -d' ' -f1)

for NS in "${NAMESPACES[@]}"; do
  NS=$(echo "$NS" | xargs)
  TARGET_EXISTS=$(kubectl get secret "$SECRET_NAME" -n "$NS" \
    -o jsonpath='{.metadata.name}' 2>/dev/null || echo "")

  if [[ "$TARGET_EXISTS" != "$SECRET_NAME" ]]; then
    echo "  FAIL: Secret not found in namespace '$NS'"
    ALL_PASS=false
    continue
  fi

  TARGET_HASH=$(kubectl get secret "$SECRET_NAME" -n "$NS" \
    -o jsonpath='{.data.tls\.crt}' 2>/dev/null | sha256sum | cut -d' ' -f1)

  if [[ "$SOURCE_HASH" == "$TARGET_HASH" ]]; then
    echo "  PASS: Secret in '$NS' matches source"
  else
    echo "  FAIL: Secret in '$NS' does NOT match source"
    ALL_PASS=false
  fi
done

echo ""
if [[ "$ALL_PASS" == "true" ]]; then
  echo "=== All secret replication validation tests passed ==="
else
  echo "=== Some secret replication tests FAILED ==="
  exit 1
fi
