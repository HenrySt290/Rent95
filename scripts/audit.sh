#!/usr/bin/env bash
# =============================================================================
#  Rent95 — Flutter Project Audit Pipeline
# -----------------------------------------------------------------------------
#  Sequential quality / safety / performance gate. Any phase failure aborts
#  the run (set -euo pipefail). Designed to be identical in local + CI.
#
#  Phases:
#    1. Environment Sanitation      (flutter clean + pub get)
#    2. Strict Static Analysis      (flutter analyze --fatal-infos/warnings)
#    3. Formatting Enforcement      (dart format --set-exit-if-changed)
#    4. Dependency Modernization    (dart pub outdated)
#    5. Secure Dependency Scanning  (native + third-party fallback)
#    6. Compilation & Size Profile  (flutter build --analyze-size)
#
#  Usage:
#      ./scripts/audit.sh                # full run, all phases
#      ./scripts/audit.sh --skip-build   # phases 1-5 only (CI PR mode)
#      ./scripts/audit.sh --platform ios # size profile against iOS instead
#      SKIP_OUTDATED=1 ./scripts/audit.sh  # env-var toggle
# =============================================================================

set -euo pipefail

# ---------- Terminal styling ---------------------------------------------------
if [[ -t 1 ]] && [[ -z "${NO_COLOR:-}" ]]; then
  BOLD=$'\033[1m'; DIM=$'\033[2m'; RED=$'\033[31m'; GREEN=$'\033[32m'
  YELLOW=$'\033[33m'; BLUE=$'\033[34m'; MAGENTA=$'\033[35m'; CYAN=$'\033[36m'
  RESET=$'\033[0m'
else
  BOLD=""; DIM=""; RED=""; GREEN=""; YELLOW=""; BLUE=""; MAGENTA=""; CYAN=""; RESET=""
fi

RULE="────────────────────────────────────────────────────────────────────────────"

banner() {
  local title="$1"
  echo ""
  echo "${CYAN}${BOLD}╔${RULE}╗${RESET}"
  printf "${CYAN}${BOLD}║${RESET}  %-70s ${CYAN}${BOLD}║${RESET}\n" "$title"
  echo "${CYAN}${BOLD}╚${RULE}╝${RESET}"
}
phase() {
  local n="$1"; local name="$2"
  echo ""
  echo "${BLUE}${BOLD}▶ Phase ${n}: ${name}${RESET}"
  echo "${DIM}${RULE}${RESET}"
}
ok()   { echo "${GREEN}✔ ${1}${RESET}"; }
warn() { echo "${YELLOW}⚠ ${1}${RESET}"; }
fail() { echo "${RED}✖ ${1}${RESET}"; }
info() { echo "${DIM}› ${1}${RESET}"; }

# ---------- Args + env ---------------------------------------------------------
PLATFORM="apk"
SKIP_BUILD="${SKIP_BUILD:-0}"
SKIP_OUTDATED="${SKIP_OUTDATED:-0}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-build)    SKIP_BUILD=1 ; shift ;;
    --skip-outdated) SKIP_OUTDATED=1 ; shift ;;
    --platform)      PLATFORM="$2" ; shift 2 ;;
    -h|--help)
      sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *) fail "Unknown arg: $1"; exit 2 ;;
  esac
done

# ---------- Preflight ----------------------------------------------------------
banner "Rent95 Flutter Audit Pipeline"
info "cwd: $(pwd)"
info "date: $(date -u +'%Y-%m-%dT%H:%M:%SZ')"
info "platform target: ${PLATFORM}"

command -v flutter >/dev/null 2>&1 || { fail "flutter not on PATH — install stable channel first"; exit 127; }
command -v dart    >/dev/null 2>&1 || { fail "dart not on PATH";    exit 127; }

flutter --version | sed "s/^/${DIM}| ${RESET}/"

FLUTTER_CHANNEL="$(flutter --version 2>/dev/null | awk '/channel/ {print $2}' | head -n1 || true)"
if [[ -n "$FLUTTER_CHANNEL" && "$FLUTTER_CHANNEL" != "stable" ]]; then
  warn "Flutter channel is '${FLUTTER_CHANNEL}' — audit expects 'stable'."
fi

ARTIFACTS_DIR="build/audit"
mkdir -p "$ARTIFACTS_DIR"

STARTED_AT="$(date +%s)"
FAILED_PHASES=()

run_phase() {
  local n="$1" name="$2"; shift 2
  phase "$n" "$name"
  if "$@"; then
    ok "Phase ${n} passed"
  else
    fail "Phase ${n} failed"
    FAILED_PHASES+=("Phase ${n}: ${name}")
    exit 1
  fi
}

# ---------- Phase 1: Environment Sanitation -----------------------------------
phase1() {
  info "flutter clean"
  flutter clean | sed "s/^/${DIM}| ${RESET}/"
  info "flutter pub get"
  flutter pub get | sed "s/^/${DIM}| ${RESET}/"
}

# ---------- Phase 2: Strict Static Analysis -----------------------------------
phase2() {
  info "flutter analyze --fatal-infos --fatal-warnings"
  flutter analyze --fatal-infos --fatal-warnings
}

# ---------- Phase 3: Formatting Enforcement -----------------------------------
phase3() {
  info "dart format --output=none --set-exit-if-changed ."
  # Exclude generated + build to avoid false positives
  dart format \
    --output=none \
    --set-exit-if-changed \
    lib test
}

# ---------- Phase 4: Dependency Modernization ---------------------------------
phase4() {
  if [[ "$SKIP_OUTDATED" == "1" ]]; then
    warn "SKIP_OUTDATED=1 — skipping"
    return 0
  fi
  info "dart pub outdated --mode=null-safety --no-dev-dependencies=false"
  # Non-fatal by design: reports drift but doesn't hard-fail the pipeline.
  # (Bumping major versions requires human judgment.)
  local outdated_log="${ARTIFACTS_DIR}/pub-outdated.txt"
  if dart pub outdated --json > "${outdated_log}.json" 2>&1; then
    dart pub outdated | tee "${outdated_log}" || true
    local upgradable
    upgradable=$(dart pub outdated 2>/dev/null | awk '/^[a-z0-9_]+ +[0-9]/ {c++} END{print c+0}')
    if [[ "${upgradable:-0}" -gt 0 ]]; then
      warn "${upgradable} package(s) have newer resolvable versions — see ${outdated_log}"
    else
      ok "All dependencies at latest resolvable versions"
    fi
  else
    warn "dart pub outdated returned non-zero — logs at ${outdated_log}.json"
  fi
  return 0
}

# ---------- Phase 5: Secure Dependency Scanning -------------------------------
phase5() {
  local sec_log="${ARTIFACTS_DIR}/dep-security.txt"
  : > "$sec_log"

  # (a) Native path: some Dart SDKs expose `dart pub security audit`.
  #     If unavailable, we fall back to `pana` and to advisory scraping via
  #     `dart pub outdated` (which surfaces retracted / discontinued deps).
  if dart pub --help 2>&1 | grep -qiE '(^| )security($| )|audit'; then
    info "dart pub security audit (native)"
    if dart pub security audit | tee -a "$sec_log"; then
      ok "No security advisories reported by native audit"
      return 0
    fi
    fail "Native pub security audit reported findings — see ${sec_log}"
    return 1
  fi

  warn "Native 'dart pub security audit' not available on this SDK"
  info "Falling back to 'dart pub outdated' (retracted/discontinued) + optional pana"

  # (b) Detect retracted / discontinued packages (surfaced by pub outdated).
  if dart pub outdated --show-all --json > "${ARTIFACTS_DIR}/pub-outdated-full.json" 2>/dev/null; then
    if grep -qE '"isDiscontinued":true|"isRetracted":true' "${ARTIFACTS_DIR}/pub-outdated-full.json"; then
      grep -B2 -A2 -E '"isDiscontinued":true|"isRetracted":true' \
        "${ARTIFACTS_DIR}/pub-outdated-full.json" | tee -a "$sec_log"
      fail "Discontinued or retracted package(s) detected"
      return 1
    fi
    ok "No discontinued/retracted packages"
  fi

  # (c) Optional pana scan (installs on-demand if AUDIT_INSTALL_PANA=1)
  if command -v pana >/dev/null 2>&1; then
    info "Running pana quick scan"
    pana --no-warning --json . > "${ARTIFACTS_DIR}/pana.json" 2>/dev/null || true
    ok "pana report saved to ${ARTIFACTS_DIR}/pana.json"
  elif [[ "${AUDIT_INSTALL_PANA:-0}" == "1" ]]; then
    info "AUDIT_INSTALL_PANA=1 — activating pana globally"
    dart pub global activate pana >/dev/null 2>&1 || warn "pana activation failed"
  else
    info "Skip pana (set AUDIT_INSTALL_PANA=1 to enable)"
  fi

  return 0
}

# ---------- Phase 6: Compilation & Size Profiling -----------------------------
phase6() {
  if [[ "$SKIP_BUILD" == "1" ]]; then
    warn "SKIP_BUILD=1 — skipping compile/size profile"
    return 0
  fi
  local target
  case "$PLATFORM" in
    apk)   target=(build apk    --release --analyze-size --target-platform=android-arm64) ;;
    ios)   target=(build ios    --release --analyze-size --no-codesign)                  ;;
    web)   target=(build web    --release)                                                ;;
    aab|appbundle)
           target=(build appbundle --release --analyze-size --target-platform=android-arm64) ;;
    *) fail "Unknown --platform '$PLATFORM' (expected apk|aab|ios|web)"; return 2 ;;
  esac
  info "flutter ${target[*]}"
  flutter "${target[@]}" | tee "${ARTIFACTS_DIR}/build-${PLATFORM}.log"

  # Flutter drops size analysis JSON under build/ – hoist it into artifacts.
  local size_json
  size_json="$(find build -type f -name '*-code-size-analysis*.json' 2>/dev/null | head -n1 || true)"
  if [[ -n "$size_json" ]]; then
    cp "$size_json" "${ARTIFACTS_DIR}/size-analysis-${PLATFORM}.json"
    ok "Size analysis JSON copied to ${ARTIFACTS_DIR}/size-analysis-${PLATFORM}.json"
    info "Open with:  flutter pub global run devtools  →  App Size Tool"
  else
    warn "No code-size-analysis JSON produced (older Flutter?)"
  fi
}

# ---------- Runner -------------------------------------------------------------
run_phase 1 "Environment Sanitation"      phase1
run_phase 2 "Strict Static Analysis"      phase2
run_phase 3 "Formatting Enforcement"      phase3
run_phase 4 "Dependency Modernization"    phase4
run_phase 5 "Secure Dependency Scanning"  phase5
run_phase 6 "Compilation & Size Profile"  phase6

ELAPSED=$(( $(date +%s) - STARTED_AT ))
banner "AUDIT PASSED"
ok "All phases completed in ${ELAPSED}s"
info "Artifacts: ${ARTIFACTS_DIR}/"
exit 0
