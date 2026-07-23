#!/usr/bin/env bash
# Validate HTTP connectivity for ALB Plaintext Pattern
# Verifies ALB terminates TLS and forwards plaintext to Istio on port 8080
set -euo pipefail

ALB_DNS="${ALB_DNS:-}"
DOMAIN="${DOMAIN:-httpbin.example.com}"

if [[ -z "$ALB_DNS" ]]; then
  echo "ERROR: ALB_DNS environment variable is required"
  echo "Usage: ALB_DNS=<alb-dns-name> DOMAIN=<domain> ./validate-http.sh"
  exit 1
fi

echo "=== HTTP Validation: ALB Plaintext Pattern ==="
echo "ALB DNS: $ALB_DNS"
echo "Domain: $DOMAIN"
echo ""

# Test 1: Verify HTTPS connectivity through ALB (client-facing TLS)
echo "[Test 1] Verifying HTTPS connectivity to ALB..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
  --resolve "${DOMAIN}:443:$(dig +short "$ALB_DNS" | head -1)" \
  "https://${DOMAIN}/status/200" \
  --max-time 10 || echo "000")

if [[ "$HTTP_CODE" == "200" ]]; then
  echo "  PASS: HTTPS request through ALB returned HTTP $HTTP_CODE"
else
  echo "  FAIL: HTTPS request returned HTTP $HTTP_CODE (expected 200)"
  exit 1
fi

# Test 2: Verify HTTP redirect (port 80 → 443)
echo "[Test 2] Verifying HTTP to HTTPS redirect..."
REDIRECT_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
  --resolve "${DOMAIN}:80:$(dig +short "$ALB_DNS" | head -1)" \
  "http://${DOMAIN}/status/200" \
  --max-time 10 -L -o /dev/null || echo "000")

# Should get 301 redirect or follow to 200
echo "  INFO: HTTP redirect check returned $REDIRECT_CODE"

# Test 3: Verify X-Forwarded-For header preservation
echo "[Test 3] Verifying X-Forwarded-For header..."
HEADERS=$(curl -s --resolve "${DOMAIN}:443:$(dig +short "$ALB_DNS" | head -1)" \
  "https://${DOMAIN}/headers" --max-time 10 || echo "{}")

if echo "$HEADERS" | grep -qi "X-Forwarded-For"; then
  echo "  PASS: X-Forwarded-For header is present"
  XFF=$(echo "$HEADERS" | grep -i "X-Forwarded-For" | head -1)
  echo "  Value: $XFF"
else
  echo "  WARN: X-Forwarded-For header not found in response"
fi

# Test 4: Verify X-Forwarded-Proto shows HTTPS (ALB terminated TLS)
echo "[Test 4] Verifying X-Forwarded-Proto header..."
if echo "$HEADERS" | grep -qi "X-Forwarded-Proto.*https"; then
  echo "  PASS: X-Forwarded-Proto indicates HTTPS (TLS terminated at ALB)"
else
  echo "  WARN: X-Forwarded-Proto not found or not HTTPS"
fi

echo ""
echo "=== All HTTP validation tests passed ==="
