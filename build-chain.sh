#!/bin/bash
# build-chain.sh — Build all hyprland packages in dependency order using mock.
#
# Each package is built as an SRPM, then rebuilt in mock. The resulting RPMs
# are added to a local repo so that subsequent builds can satisfy
# BuildRequires on earlier packages.
#
# Usage:
#   ./build-chain.sh [--mock-config CONFIG] [--resultdir DIR] [--start-from PKG]
#
# Examples:
#   ./build-chain.sh
#   ./build-chain.sh --mock-config fedora-43-x86_64
#   ./build-chain.sh --start-from hyprtoolkit

set -euo pipefail

. package-order

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

MOCK_CONFIG="fedora-$(rpm --eval '%{fedora}')-$(uname -m)"
RESULT_DIR="${SCRIPT_DIR}/_results"
START_FROM=""
STOP_ON_ERROR=false
OFFLINE=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --mock-config) MOCK_CONFIG="$2"; shift 2 ;;
        --resultdir)   RESULT_DIR="$2";  shift 2 ;;
        --start-from)  START_FROM="$2";  shift 2 ;;
        --stop-on-error) STOP_ON_ERROR=true; shift ;;
        --offline)     OFFLINE=true; shift ;;
        -h|--help)
            sed -n '2,/^$/s/^# \?//p' "$0"
            exit 0
            ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

if [[ -t 1 ]]; then
    BOLD=$'\e[1m'  GREEN=$'\e[32m'  RED=$'\e[31m'  CYAN=$'\e[36m'  RESET=$'\e[0m'
else
    BOLD=""  GREEN=""  RED=""  CYAN=""  RESET=""
fi

info()  { echo "${BOLD}${CYAN}==> $*${RESET}"; }
ok()    { echo "${BOLD}${GREEN} ✓  $*${RESET}"; }
die()   { echo "${BOLD}${RED}ERROR: $*${RESET}" >&2; exit 1; }

fmt_duration() {
    local secs=$1
    local m=$((secs / 60)) s=$((secs % 60))
    if (( m > 0 )); then printf '%dm %ds' "$m" "$s"
    else printf '%ds' "$s"; fi
}

for cmd in mock rpmbuild spectool createrepo_c; do
    command -v "$cmd" &>/dev/null || die "$cmd is not installed"
done

LOCAL_REPO="${RESULT_DIR}/local-repo"
SRPMS_DIR="${RESULT_DIR}/srpms"
LOGS_DIR="${RESULT_DIR}/logs"
mkdir -p "$LOCAL_REPO" "$SRPMS_DIR" "$LOGS_DIR"

# Seed the local repo metadata so mock can reference it immediately
createrepo_c --quiet "$LOCAL_REPO"

MOCK_CFG_OVERLAY="${RESULT_DIR}/hyprland-local-repo.cfg"
cat > "$MOCK_CFG_OVERLAY" <<EOF
include("${MOCK_CONFIG}.cfg")

config_opts['dnf.conf'] += """
[hyprland-local]
name=Hyprland local build repo
baseurl=file://${LOCAL_REPO}
enabled=1
gpgcheck=0
priority=1
module_hotfixes=1
"""
EOF

info "Mock config : ${MOCK_CONFIG}"
info "Results dir : ${RESULT_DIR}"
info "Local repo  : ${LOCAL_REPO}"
echo

SKIPPING=false
if [[ -n "$START_FROM" ]]; then
    SKIPPING=true
fi

TOTAL=${#BUILD_ORDER[@]}
BUILT=0
FAILED=()
CHAIN_START=$(date +%s)

for pkg in "${BUILD_ORDER[@]}"; do
    # Skip until we reach the start-from package
    if $SKIPPING; then
        if [[ "$pkg" == "$START_FROM" ]]; then
            SKIPPING=false
        else
            echo "  ⏭  Skipping ${pkg} (--start-from ${START_FROM})"
            continue
        fi
    fi

    BUILT=$((BUILT + 1))
    SPEC_DIR="${SCRIPT_DIR}/${pkg}"
    SPEC_FILE="${SPEC_DIR}/${pkg}.spec"

    PKG_START=$(date +%s)

    echo
    info "[${BUILT}/${TOTAL}] Building ${pkg}"

    if [[ ! -f "$SPEC_FILE" ]]; then
        die "Spec file not found: ${SPEC_FILE}"
    fi

    info "  Downloading sources..."
    if ! spectool -g -C "$SPEC_DIR" "$SPEC_FILE" \
            >> "${LOGS_DIR}/${pkg}-spectool.log" 2>&1; then
        echo "${RED}  ✗ spectool failed (see ${LOGS_DIR}/${pkg}-spectool.log)${RESET} [$(fmt_duration $(($(date +%s) - PKG_START)))]"
        FAILED+=("$pkg")
        if $STOP_ON_ERROR; then break; fi
        continue
    fi

    info "  Building SRPM..."
    SRPM_OUT=$(rpmbuild -bs \
        --define "_sourcedir ${SPEC_DIR}" \
        --define "_srcrpmdir ${SRPMS_DIR}" \
        --define "_topdir ${RESULT_DIR}/rpmbuild" \
        "$SPEC_FILE" 2>&1 | tee "${LOGS_DIR}/${pkg}-srpm.log")

    SRPM_PATH=$(echo "$SRPM_OUT" | grep -oP '(?<=Wrote: ).*\.src\.rpm' | head -1 || true)
    if [[ -z "$SRPM_PATH" || ! -f "$SRPM_PATH" ]]; then
        echo "${RED}  ✗ SRPM build failed (see ${LOGS_DIR}/${pkg}-srpm.log)${RESET} [$(fmt_duration $(($(date +%s) - PKG_START)))]"
        FAILED+=("$pkg")
        if $STOP_ON_ERROR; then break; fi
        continue
    fi

    PKG_RESULT="${RESULT_DIR}/${pkg}"
    mkdir -p "$PKG_RESULT"

    # Clean any leftover chroot from a previous build to avoid
    # permission/ownership collisions
    info "  Cleaning mock chroot..."
    mock --scrub=chroot -r "$MOCK_CFG_OVERLAY" >> "${LOGS_DIR}/${pkg}-mock-clean.log" 2>&1 || true

    MOCK_EXTRA_ARGS=()
    if $OFFLINE; then MOCK_EXTRA_ARGS+=(--offline); fi

    info "  mock --rebuild (this may take a while)..."
    if ! mock -r "$MOCK_CFG_OVERLAY" \
            "${MOCK_EXTRA_ARGS[@]}" \
            --resultdir="$PKG_RESULT" \
            --rebuild "$SRPM_PATH" \
            >> "${LOGS_DIR}/${pkg}-mock.log" 2>&1; then
        echo "${RED}  ✗ mock build failed (see ${LOGS_DIR}/${pkg}-mock.log)${RESET} [$(fmt_duration $(($(date +%s) - PKG_START)))]"
        FAILED+=("$pkg")
        if $STOP_ON_ERROR; then break; fi
        continue
    fi

    cp -n "$PKG_RESULT"/*.rpm "$LOCAL_REPO/" 2>/dev/null || true
    createrepo_c --update --quiet "$LOCAL_REPO"

    ok "${pkg} built successfully [$(fmt_duration $(($(date +%s) - PKG_START)))]"
done

CHAIN_ELAPSED=$(( $(date +%s) - CHAIN_START ))

echo
info "Total elapsed time: $(fmt_duration $CHAIN_ELAPSED)"
if [[ ${#FAILED[@]} -eq 0 ]]; then
    ok "All packages built successfully!"
else
    echo "${RED}${BOLD}Failed packages (${#FAILED[@]}):${RESET}"
    for f in "${FAILED[@]}"; do
        echo "  • $f  (log: ${LOGS_DIR}/${f}-mock.log)"
    done
fi
echo
info "All RPMs are in: ${LOCAL_REPO}"
echo ""

exit ${#FAILED[@]}
