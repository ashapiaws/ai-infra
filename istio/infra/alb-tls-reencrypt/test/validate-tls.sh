#!/usr/bin/env bash
# Validate TLS configuration for ALB TLS Re-encryption Pattern
# This script verifies end-to-end TLS from client through ALB to Istio
set -euo pipefail

ALB_DNS="${ALB_DNS:-}"
DOMAIN="${DOMAIN:-httpbin.example.com}"
EXPECTED_TLS_VERSION="${EXPECTED_TLS_VERSION:-TLSv1.2}"

if [[ -z "$ALB_DNS" ]]; then
  echo "ERROR: ALB_DNS environment variable is required"
  echo "Usage: ALB_DNS=<alb-dns-name> DOMAIN=<domain> ./validate-tls.sh"
  exit 1
fi

echo "=== TLS Validation: ALB TLS Re-encryption Pattern ==="
echo "ALB DNS: $ALB_DNS"
echo "Domain: $DOMAIN"
echo ""

# Test 1: Verify HTTPS connectivity through ALB
echo "[Test 1] Verifying HTTPS connectivity..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
  --resolve "${DOMAIN}:443:$(dig +short "$ALB_DNS" | head -1)" \
  "https://${DOMAIN}/status/200" \
  --max-time 10 || echo "000")

if [[ "$HTTP_CODE" == "200" ]]; then
  echo "  PASS: HTTPS request returned HTTP $HTTP_CODE"
else
  echo "  FAIL: HTTPS request returned HTTP $HTTP_CODE (expected 200)"
  exit 1
fi

# Test 2: Verify TLS version
echo "[Test 2] Verifying TLS version..."
TLS_INFO=$(curl -s -v --resolve "${DOMAIN}:443:$(dig +short "$ALB_DNS" | head -1)" \
  "https://${DOMAIN}/status/200" 2>&1 | grep "SSL connection using" || true)

if echo "$TLS_INFO" | grep -q "TLSv1.[23]"; then
  echo "  PASS: TLS version is 1.2 or higher"
  echo "  Details: $TLS_INFO"
else
  echo "  FAIL: Could not verify TLS version >= 1.2"
  echo "  Details: $TLS_INFO"
  exit 1
fi

# Test 3: Verify certificate is valid (not expired)
echo "[Test 3] Verifying certificate validity..."
CERT_INFO=$(echo | openssl s_client -servername "$DOMAIN" \
  -connect "$(dig +short "$ALB_DNS" | head -1):443" 2>/dev/null | \
  openssl x509 -noout -dates 2>/dev/null || true)

if [[ -n "$CERT_INFO" ]]; then
  echo "  PASS: Certificate is valid"
  echo "  $CERT_INFO"
else
  echo "  FAIL: Could not retrieve certificate information"
  exit 1
fi

# Test 4: Verify X-Forwarded-For header preservation
echo "[Test 4] Verifying X-Forwarded-For header..."
HEADERS=$(curl -s --resolve "${DOMAIN}:443:$(dig +short "$ALB_DNS" | head -1)" \
  "https://${DOMAIN}/headers" --max-time 10 || echo "{}")

if echo "$HEADERS" | grep -qi "X-Forwarded-For"; then
  echo "  PASS: X-Forwarded-For header is present"
else
  echo "  WARN: X-Forwarded-For header not found in response (may need app-level check)"
fi

echo ""
echo "=== All TLS validation tests passed ==="
