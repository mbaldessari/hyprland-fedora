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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── defaults ──────────────────────────────────────────────────────────────────
MOCK_CONFIG="fedora-$(rpm --eval '%{fedora}')-$(uname -m)"
RESULT_DIR="${SCRIPT_DIR}/_results"
START_FROM=""

# ── parse args ────────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        --mock-config) MOCK_CONFIG="$2"; shift 2 ;;
        --resultdir)   RESULT_DIR="$2";  shift 2 ;;
        --start-from)  START_FROM="$2";  shift 2 ;;
        -h|--help)
            sed -n '2,/^$/s/^# \?//p' "$0"
            exit 0
            ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

# ── Topologically sorted build order ─────────────────────────────────────────
# Level 1: no internal deps
# Level 2: depend on level 1
# Level 3: depend on levels 1–2
# Level 4: depend on level 3
# Level 5: depends on nearly everything
BUILD_ORDER=(
    # Level 1
    hyprutils
    glaze
    hyprwayland-scanner
    hyprland-protocols
    # Level 2
    hyprlang
    hyprwire
    hyprgraphics
    aquamarine
    hyprland-qtutils
    # Level 3
    hyprcursor
    hyprland-qt-support
    hypridle
    hyprsunset
    hyprlock
    xdg-desktop-portal-hyprland
    hyprtoolkit
    # Level 4
    hyprpaper
    hyprland-guiutils
    hyprlauncher
    # Level 5
    hyprland-git
)

# ── colours ───────────────────────────────────────────────────────────────────
if [[ -t 1 ]]; then
    BOLD=$'\e[1m'  GREEN=$'\e[32m'  RED=$'\e[31m'  CYAN=$'\e[36m'  RESET=$'\e[0m'
else
    BOLD=""  GREEN=""  RED=""  CYAN=""  RESET=""
fi

info()  { echo "${BOLD}${CYAN}==> $*${RESET}"; }
ok()    { echo "${BOLD}${GREEN} ✓  $*${RESET}"; }
die()   { echo "${BOLD}${RED}ERROR: $*${RESET}" >&2; exit 1; }

# ── sanity checks ─────────────────────────────────────────────────────────────
for cmd in mock rpmbuild spectool createrepo_c; do
    command -v "$cmd" &>/dev/null || die "$cmd is not installed"
done

# ── set up local repo ────────────────────────────────────────────────────────
LOCAL_REPO="${RESULT_DIR}/local-repo"
SRPMS_DIR="${RESULT_DIR}/srpms"
LOGS_DIR="${RESULT_DIR}/logs"
mkdir -p "$LOCAL_REPO" "$SRPMS_DIR" "$LOGS_DIR"

# Seed the local repo metadata so mock can reference it immediately
createrepo_c --quiet "$LOCAL_REPO"

# ── write a mock config overlay that adds the local repo ─────────────────────
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

# ── handle --start-from ──────────────────────────────────────────────────────
SKIPPING=false
if [[ -n "$START_FROM" ]]; then
    SKIPPING=true
fi

# ── main build loop ──────────────────────────────────────────────────────────
TOTAL=${#BUILD_ORDER[@]}
BUILT=0
FAILED=()

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

    echo
    info "[${BUILT}/${TOTAL}] Building ${pkg}"

    if [[ ! -f "$SPEC_FILE" ]]; then
        die "Spec file not found: ${SPEC_FILE}"
    fi

    # ── download sources ──────────────────────────────────────────────────
    info "  Downloading sources..."
    if ! spectool -g -C "$SPEC_DIR" "$SPEC_FILE" \
            >> "${LOGS_DIR}/${pkg}-spectool.log" 2>&1; then
        echo "${RED}  ✗ spectool failed (see ${LOGS_DIR}/${pkg}-spectool.log)${RESET}"
        FAILED+=("$pkg")
        continue
    fi

    # ── build SRPM ────────────────────────────────────────────────────────
    info "  Building SRPM..."
    SRPM_OUT=$(rpmbuild -bs \
        --define "_sourcedir ${SPEC_DIR}" \
        --define "_srcrpmdir ${SRPMS_DIR}" \
        --define "_topdir ${RESULT_DIR}/rpmbuild" \
        "$SPEC_FILE" 2>&1 | tee "${LOGS_DIR}/${pkg}-srpm.log" | tail -1)

    SRPM_PATH=$(echo "$SRPM_OUT" | grep -oP '(?<=Wrote: ).*\.src\.rpm' || true)
    if [[ -z "$SRPM_PATH" || ! -f "$SRPM_PATH" ]]; then
        echo "${RED}  ✗ SRPM build failed (see ${LOGS_DIR}/${pkg}-srpm.log)${RESET}"
        FAILED+=("$pkg")
        continue
    fi

    # ── mock rebuild ──────────────────────────────────────────────────────
    PKG_RESULT="${RESULT_DIR}/${pkg}"
    mkdir -p "$PKG_RESULT"

    info "  mock --rebuild (this may take a while)..."
    if ! mock -r "$MOCK_CFG_OVERLAY" \
            --resultdir="$PKG_RESULT" \
            --rebuild "$SRPM_PATH" \
            >> "${LOGS_DIR}/${pkg}-mock.log" 2>&1; then
        echo "${RED}  ✗ mock build failed (see ${LOGS_DIR}/${pkg}-mock.log)${RESET}"
        FAILED+=("$pkg")
        continue
    fi

    # ── copy RPMs to local repo and update ────────────────────────────────
    cp -n "$PKG_RESULT"/*.rpm "$LOCAL_REPO/" 2>/dev/null || true
    createrepo_c --update --quiet "$LOCAL_REPO"

    ok "${pkg} built successfully"
done

# ── summary ───────────────────────────────────────────────────────────────────
echo
echo "═══════════════════════════════════════════════════════════════"
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
echo "═══════════════════════════════════════════════════════════════"

exit ${#FAILED[@]}
