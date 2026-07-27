#!/usr/bin/env bash
# ============================================================================
# Rent95 live operational preflight audit
#
# Runs a battery of production checks against a fully-deployed stack.
# Exit code:
#   0  — all critical checks passed
#   1  — one or more critical checks failed (details in output)
#   2  — bad invocation (missing env / bad args)
#
# Usage:
#   ./scripts/preflight-audit.sh
#
# Reads config from a `.audit-env` file in the repo root, or from the
# environment directly. Required:
#
#   API_HOST                 e.g. https://api.rent95.app
#   ADMIN_HOST               e.g. https://admin.rent95.app
#   EXPECTED_CORS_ORIGINS    e.g. https://admin.rent95.app,https://rent95.app
#   BAD_TEST_ORIGIN          e.g. https://evil.example.com
#   STRIPE_SECRET_KEY        sk_live_… (only used to verify webhook shape)
#   STRIPE_WEBHOOK_ID        we_… (Stripe webhook endpoint id)
#   CLOUDINARY_CLOUD_NAME    e.g. rent95-prod
#   CLOUDINARY_API_KEY
#   CLOUDINARY_API_SECRET
#   FLY_APP_API              e.g. rent95-api  (skip block if not on Fly)
#   FLY_APP_ADMIN            e.g. rent95-admin
#   FLY_PG_APP               e.g. rent95-db   (skip block if not on Fly Postgres)
#   SENTRY_DSN               your Sentry DSN (used to fire one canary event)
#
# We deliberately never write secrets to stdout — every check either passes
# ("OK …") or fails with a redacted reason.
# ============================================================================
set -o pipefail

# --------------------------------------------------------------------------
# Helpers
# --------------------------------------------------------------------------

# Colours only when stdout is a TTY, so CI logs stay clean.
if [ -t 1 ]; then
  BOLD=$(printf '\033[1m'); DIM=$(printf '\033[2m'); RESET=$(printf '\033[0m')
  RED=$(printf '\033[31m'); GREEN=$(printf '\033[32m'); YELLOW=$(printf '\033[33m'); BLUE=$(printf '\033[34m')
else
  BOLD=""; DIM=""; RESET=""; RED=""; GREEN=""; YELLOW=""; BLUE=""
fi

PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0
declare -a FAILURES=()

section() { printf '\n%s%s%s\n' "$BOLD" "▎ $1" "$RESET"; }
pass()    { printf '  %sOK%s  %s\n'   "$GREEN"  "$RESET" "$1"; PASS_COUNT=$((PASS_COUNT+1)); }
warn()    { printf '  %sWARN%s %s\n'  "$YELLOW" "$RESET" "$1"; WARN_COUNT=$((WARN_COUNT+1)); }
fail()    {
  printf '  %sFAIL%s %s\n' "$RED" "$RESET" "$1"
  FAIL_COUNT=$((FAIL_COUNT+1))
  FAILURES+=("$1")
}
skip()    { printf '  %sSKIP%s %s\n'  "$DIM"    "$RESET" "$1"; }
info()    { printf '  %s·%s    %s\n'  "$BLUE"   "$RESET" "$1"; }

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || { fail "missing dependency: $1"; return 1; }
}

# --------------------------------------------------------------------------
# Load config
# --------------------------------------------------------------------------

if [ -f .audit-env ]; then
  # shellcheck disable=SC1091
  set -a; . ./.audit-env; set +a
fi

for cmd in curl jq openssl base64; do
  require_cmd "$cmd" || exit 2
done

printf '%sRent95 preflight audit — %s%s\n' "$BOLD" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$RESET"
info "target API:    ${API_HOST:-<unset>}"
info "target admin:  ${ADMIN_HOST:-<unset>}"

# --------------------------------------------------------------------------
# 1. Compute + network registration
# --------------------------------------------------------------------------

section "1. HTTPS + Load-balancer registration"

if [ -z "$API_HOST" ]; then
  fail "API_HOST not set"
else
  # 1a. TLS + HTTP/2 handshake succeeds; certificate is valid and not expiring within 21 days.
  # We ask openssl for the not-after date, parse it into an epoch, compare to now+21d.
  host_no_scheme="${API_HOST#https://}"
  host_no_scheme="${host_no_scheme%%/*}"
  cert_expiry=$(echo | openssl s_client -servername "$host_no_scheme" -connect "${host_no_scheme}:443" 2>/dev/null \
    | openssl x509 -noout -enddate 2>/dev/null | cut -d= -f2)
  if [ -z "$cert_expiry" ]; then
    fail "could not fetch TLS certificate for $host_no_scheme (DNS or LB not up)"
  else
    now_epoch=$(date -u +%s)
    exp_epoch=$(date -u -d "$cert_expiry" +%s 2>/dev/null || date -u -j -f "%b %e %T %Y %Z" "$cert_expiry" +%s 2>/dev/null || echo 0)
    days_left=$(( (exp_epoch - now_epoch) / 86400 ))
    if [ "$exp_epoch" = 0 ]; then
      warn "could not parse cert expiry '$cert_expiry' — check the LB by hand"
    elif [ "$days_left" -lt 0 ]; then
      fail "TLS certificate EXPIRED ${days_left#-} days ago"
    elif [ "$days_left" -lt 21 ]; then
      warn "TLS certificate expires in ${days_left} days — schedule renewal"
    else
      pass "TLS certificate valid (${days_left} days remaining)"
    fi
  fi

  # 1b. HSTS + security headers present on the LB response.
  #     Everything below asserts what the security audit shipped.
  headers=$(curl -sSI --max-time 10 "$API_HOST/health" 2>/dev/null || true)
  if [ -z "$headers" ]; then
    fail "no HTTP response from $API_HOST/health"
  else
    _has() { echo "$headers" | grep -qi "^$1:"; }
    _val() { echo "$headers" | grep -i "^$1:" | head -1 | sed 's/^[^:]*: *//' | tr -d '\r'; }

    _has 'strict-transport-security' && pass "HSTS header present ($(_val 'strict-transport-security'))" \
      || fail "HSTS header missing on API"

    _has 'content-security-policy' && pass "CSP header present" \
      || fail "CSP header missing on API"

    _has 'x-frame-options' && pass "X-Frame-Options: $(_val 'x-frame-options')" \
      || warn "X-Frame-Options missing"

    if _has 'x-powered-by'; then
      fail "x-powered-by header LEAKS platform — should be disabled"
    else
      pass "x-powered-by header absent"
    fi

    if _has 'referrer-policy'; then
      rp=$(_val 'referrer-policy')
      [ "$rp" = "no-referrer" ] && pass "Referrer-Policy: no-referrer" \
        || warn "Referrer-Policy is '$rp' (audit expects 'no-referrer')"
    else
      fail "Referrer-Policy header missing"
    fi
  fi

  # 1c. /health?deep=1 → the audit-defined deep check that pings Postgres.
  deep_body=$(curl -sS --max-time 15 -o /tmp/rent95-audit-health.json -w '%{http_code}' \
    "$API_HOST/health?deep=1" 2>/dev/null || echo "000")
  if [ "$deep_body" = "200" ]; then
    db_ok=$(jq -r '.checks.database // empty' /tmp/rent95-audit-health.json 2>/dev/null)
    if [ "$db_ok" = "ok" ]; then
      pass "deep health check 200 + Postgres pool open"
    else
      fail "deep health returned 200 but checks.database != 'ok' ($db_ok)"
    fi
  else
    fail "deep health check returned HTTP $deep_body — DB pool likely closed"
  fi
fi

# --------------------------------------------------------------------------
# 2. CORS lockdown
# --------------------------------------------------------------------------

section "2. CORS gate"

if [ -z "$EXPECTED_CORS_ORIGINS" ] || [ -z "$BAD_TEST_ORIGIN" ]; then
  skip "set EXPECTED_CORS_ORIGINS + BAD_TEST_ORIGIN to run"
else
  # 2a. Approved origin gets exact reflection.
  IFS=',' read -r -a origins <<< "$EXPECTED_CORS_ORIGINS"
  for origin in "${origins[@]}"; do
    acao=$(curl -sSI --max-time 10 -H "Origin: $origin" "$API_HOST/health" 2>/dev/null \
      | awk -F': ' 'tolower($1)=="access-control-allow-origin"{print $2}' | tr -d '\r' | head -1)
    if [ "$acao" = "$origin" ]; then
      pass "approved origin reflected exactly: $origin"
    else
      fail "approved origin $origin got ACAO='$acao' (expected exact match)"
    fi
  done

  # 2b. Unapproved origin is refused — no reflection, never '*'.
  acao=$(curl -sSI --max-time 10 -H "Origin: $BAD_TEST_ORIGIN" "$API_HOST/health" 2>/dev/null \
    | awk -F': ' 'tolower($1)=="access-control-allow-origin"{print $2}' | tr -d '\r' | head -1)
  if [ -z "$acao" ] || [ "$acao" = "" ]; then
    pass "unapproved origin refused (no ACAO header)"
  elif [ "$acao" = "*" ]; then
    fail "ACAO='*' on request with credentials — CATASTROPHIC misconfig"
  else
    fail "unapproved origin got ACAO='$acao' — should be absent"
  fi

  # 2c. Preflight sanity — approved origin, POST + auth header.
  preflight=$(curl -sSI --max-time 10 -X OPTIONS \
    -H "Origin: ${origins[0]}" \
    -H "Access-Control-Request-Method: POST" \
    -H "Access-Control-Request-Headers: authorization,content-type" \
    "$API_HOST/api/products" 2>/dev/null)
  if echo "$preflight" | grep -qi '^access-control-allow-methods:.*POST'; then
    pass "preflight allows POST + authorization for ${origins[0]}"
  else
    warn "preflight from ${origins[0]} did not include POST in allow-methods"
  fi
fi

# --------------------------------------------------------------------------
# 3. Stripe integration
# --------------------------------------------------------------------------

section "3. Stripe webhook registration"

if [ -z "$STRIPE_SECRET_KEY" ]; then
  skip "STRIPE_SECRET_KEY not set — skipping live Stripe checks"
else
  # 3a. Confirm the webhook endpoint is registered and points where we expect.
  webhooks_json=$(curl -sS --max-time 15 -u "$STRIPE_SECRET_KEY:" \
    https://api.stripe.com/v1/webhook_endpoints 2>/dev/null)
  if ! echo "$webhooks_json" | jq empty 2>/dev/null; then
    fail "could not list Stripe webhook endpoints (bad key or network)"
  else
    expected_url="$API_HOST/api/payments/webhook/stripe"
    matching=$(echo "$webhooks_json" | jq -r --arg u "$expected_url" \
      '.data[] | select(.url == $u) | .id')
    if [ -n "$matching" ]; then
      pass "webhook endpoint registered: $matching → $expected_url"
      # 3b. Confirm subscribed events cover the payment flow we depend on.
      events=$(echo "$webhooks_json" | jq -r --arg u "$expected_url" \
        '.data[] | select(.url == $u) | .enabled_events | join(",")')
      for needed in payment_intent.succeeded payment_intent.payment_failed payment_intent.amount_capturable_updated; do
        if echo ",$events," | grep -q ",$needed,"; then
          pass "  subscribes to $needed"
        else
          warn "  does NOT subscribe to $needed (add via `stripe webhook_endpoints update`)"
        fi
      done
      # 3c. Confirm the endpoint is active, not disabled.
      status=$(echo "$webhooks_json" | jq -r --arg u "$expected_url" \
        '.data[] | select(.url == $u) | .status')
      [ "$status" = "enabled" ] && pass "  status=enabled" \
        || fail "  status=$status (should be enabled)"
    else
      fail "no webhook endpoint registered for $expected_url"
      echo "$webhooks_json" | jq -r '.data[]?.url' | sed 's/^/       registered: /'
    fi
  fi
fi

# --------------------------------------------------------------------------
# 4. Firebase FCM base64 sanity
# --------------------------------------------------------------------------

section "4. Firebase Admin credentials"

if [ -z "${FCM_SERVICE_ACCOUNT_JSON_BASE64:-}" ]; then
  skip "FCM_SERVICE_ACCOUNT_JSON_BASE64 not set locally — check via `fly ssh console` on the app"
else
  # Decode into a temp file and validate the JSON shape.
  tmp_fcm=$(mktemp)
  trap 'rm -f "$tmp_fcm"' EXIT
  if ! echo "$FCM_SERVICE_ACCOUNT_JSON_BASE64" | base64 -d > "$tmp_fcm" 2>/dev/null; then
    fail "base64 decode failed — string is corrupt"
  elif ! jq empty "$tmp_fcm" 2>/dev/null; then
    fail "decoded output is not valid JSON"
  else
    project_id=$(jq -r '.project_id // empty' "$tmp_fcm")
    client_email=$(jq -r '.client_email // empty' "$tmp_fcm")
    if [ -z "$project_id" ] || [ -z "$client_email" ]; then
      fail "decoded JSON is missing project_id or client_email"
    else
      pass "FCM service account decodes ($project_id, ${client_email%@*}@…)"
    fi
  fi
fi

# --------------------------------------------------------------------------
# 5. Cloudinary credentials
# --------------------------------------------------------------------------

section "5. Cloudinary credentials"

if [ -z "${CLOUDINARY_CLOUD_NAME:-}" ] || [ -z "${CLOUDINARY_API_KEY:-}" ] || [ -z "${CLOUDINARY_API_SECRET:-}" ]; then
  skip "Cloudinary vars not present locally — verify via `fly ssh console`"
else
  # /usage returns 200 iff the API key + secret authenticate. We don't
  # actually care about the numbers — the auth challenge IS the test.
  http=$(curl -sS --max-time 15 -o /tmp/rent95-audit-cld.json -w '%{http_code}' \
    -u "$CLOUDINARY_API_KEY:$CLOUDINARY_API_SECRET" \
    "https://api.cloudinary.com/v1_1/${CLOUDINARY_CLOUD_NAME}/usage")
  case "$http" in
    200) pass "Cloudinary API key + secret authenticate against cloud '$CLOUDINARY_CLOUD_NAME'" ;;
    401) fail "Cloudinary 401 — API key/secret rejected" ;;
    404) fail "Cloudinary 404 — cloud name '$CLOUDINARY_CLOUD_NAME' unknown" ;;
    *)   fail "Cloudinary unexpected HTTP $http (see /tmp/rent95-audit-cld.json)" ;;
  esac
fi

# --------------------------------------------------------------------------
# 6. Fly Postgres backup posture
# --------------------------------------------------------------------------

section "6. Fly Postgres backup posture"

if [ -z "${FLY_PG_APP:-}" ] || ! command -v flyctl >/dev/null 2>&1; then
  skip "set FLY_PG_APP and install flyctl to auto-check backup config"
else
  # Fly's managed Postgres uses barman for base backups + WAL streaming.
  # We check volume snapshots and running processes as a proxy.
  snaps=$(flyctl volumes list -a "$FLY_PG_APP" 2>/dev/null | tail -n +2 | wc -l | tr -d ' ')
  if [ "$snaps" -gt 0 ]; then
    pass "Fly PG cluster '$FLY_PG_APP' has $snaps volume(s) (snapshots enabled by default)"
  else
    warn "no volumes listed on '$FLY_PG_APP' — is the app right?"
  fi
  info "  daily snapshot retention on Fly is 5 days by default;"
  info "  to extend: fly volumes update <vol_id> --snapshot-retention 30"
  info "  PITR (WAL-based, sub-second) is available on `fly-managed-postgres`; see docs/OPS_AUDIT.md."
fi

# --------------------------------------------------------------------------
# 7. Sentry canary
# --------------------------------------------------------------------------

section "7. Sentry canary event"

if [ -z "${SENTRY_DSN:-}" ]; then
  skip "SENTRY_DSN not set — skipping canary"
else
  # We POST a hand-crafted event that includes a decoy 'password' field
  # to prove the redaction path fires end-to-end. If our beforeSend hook
  # is wired correctly, the Sentry UI will show '[REDACTED]' for the
  # password field.
  # Sentry accepts events on the /store/ endpoint with the DSN's public key.
  dsn_re='^https?://([a-f0-9]+)@([^/]+)/([0-9]+)$'
  if [[ ! "$SENTRY_DSN" =~ $dsn_re ]]; then
    fail "SENTRY_DSN doesn't match expected shape"
  else
    key="${BASH_REMATCH[1]}"; host="${BASH_REMATCH[2]}"; proj="${BASH_REMATCH[3]}"
    payload=$(cat <<JSON
{
  "event_id": "$(openssl rand -hex 16)",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "platform": "other",
  "message": "rent95-audit canary — should show [REDACTED] on the password field below",
  "environment": "production",
  "tags": { "audit": "preflight" },
  "extra": {
    "password": "should-be-scrubbed-if-you-see-me-fail-the-audit",
    "orderId": "R95-visible-in-sentry"
  }
}
JSON
)
    resp=$(curl -sS --max-time 10 -o /dev/null -w '%{http_code}' \
      -X POST \
      -H "Content-Type: application/json" \
      -H "X-Sentry-Auth: Sentry sentry_version=7, sentry_key=$key" \
      "https://$host/api/$proj/store/" \
      -d "$payload")
    if [ "$resp" = "200" ]; then
      pass "Sentry accepted canary event — check UI for [REDACTED] on 'password' field"
    else
      warn "Sentry returned HTTP $resp on canary POST (may need @sentry/node client-side scrubbing)"
    fi
    info "  Note: this endpoint doesn't run our beforeSend hook. That"
    info "  hook lives inside the Node process — to verify it, force an"
    info "  error via 'curl -X POST $API_HOST/api/products' with bad JSON"
    info "  and inspect the resulting Sentry event's request.data."
  fi
fi

# --------------------------------------------------------------------------
# Summary
# --------------------------------------------------------------------------

printf '\n%s══════════════════════════════════%s\n' "$BOLD" "$RESET"
printf '  %sPass:%s %d   %sWarn:%s %d   %sFail:%s %d\n' \
  "$GREEN" "$RESET" "$PASS_COUNT" \
  "$YELLOW" "$RESET" "$WARN_COUNT" \
  "$RED" "$RESET" "$FAIL_COUNT"
printf '%s══════════════════════════════════%s\n' "$BOLD" "$RESET"

if [ "$FAIL_COUNT" -gt 0 ]; then
  printf '\n%sFailures require attention before launch:%s\n' "$RED" "$RESET"
  for f in "${FAILURES[@]}"; do
    printf '  • %s\n' "$f"
  done
  exit 1
fi

exit 0
