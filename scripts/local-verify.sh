#!/usr/bin/env bash
# =============================================================================
#  Rent95 — Local SDK Verification
# -----------------------------------------------------------------------------
#  Runs the full real-SDK gate locally and captures everything into a report
#  file you can paste back for triage. Never aborts early — every phase runs
#  and reports its own status.
#
#  Usage:   ./scripts/local-verify.sh
#  Output:  verify-report-YYYYMMDD-HHMMSS.txt (in the repo root)
# =============================================================================

REPORT="verify-report-$(date +%Y%m%d-%H%M%S).txt"
PASS=(); FAIL=()

say()  { echo -e "$*"; echo -e "$*" >> "$REPORT"; }
run_phase() {
  local name="$1"; shift
  say "\n\e[1m▶ $name\e[0m"
  say "  \$ $*"
  if "$@" >> "$REPORT" 2>&1; then
    say "  ✅ PASS"
    PASS+=("$name")
  else
    say "  ❌ FAIL (exit $?) — details in $REPORT"
    FAIL+=("$name")
  fi
}

say "Rent95 local verification — $(date)"
say "Working directory: $(pwd)"

# 0. Flutter must exist
if ! command -v flutter >/dev/null 2>&1; then
  say "\n\e[1m❌ flutter not on PATH.\e[0m Install Flutter, then re-run."
  exit 1
fi
run_phase "flutter doctor"        flutter doctor -v

# 1. Platform scaffolding (repo ships without android/ ios/ web/)
if [ ! -d android ]; then
  run_phase "create platform folders" \
    flutter create --platforms=android,ios,web --org com.rent95 .
fi

# 2. Dependencies
run_phase "flutter pub get"       flutter pub get

# 3. Static analysis (strict — analysis_options.yaml promotes lints to errors)
run_phase "flutter analyze"       flutter analyze

# 4. Formatting (informational)
run_phase "dart format check"     dart format --output=none lib test

# 5. Tests
run_phase "flutter test"          flutter test

# 6. Android debug build (ultimate proof it runs)
if [ -d android ]; then
  run_phase "android debug build" flutter build apk --debug
fi

say "\n\e[1m════════ SUMMARY ════════\e[0m"
say "PASS (${#PASS[@]}): ${PASS[*]:-none}"
say "FAIL (${#FAIL[@]}): ${FAIL[*]:-none}"
say "\nFull log: $REPORT — paste this file back if anything failed."
