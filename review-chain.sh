#!/bin/bash
# review-chain.sh — Run fedora-review against every package in dependency order.
#
# After each successful review-build, the resulting RPMs are added to a local
# repo so later packages can satisfy BuildRequires on earlier ones.
#
# Usage:
#   ./review-chain.sh [--mock-config CONFIG] [--resultdir DIR] [--start-from PKG]
#                     [--srpmdir DIR]
#
# Examples:
#   ./review-chain.sh
#   ./review-chain.sh --mock-config fedora-43-x86_64
#   ./review-chain.sh --start-from hyprtoolkit
#   ./review-chain.sh --srpmdir _results/srpms   # use pre-built SRPMs

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── defaults ──────────────────────────────────────────────────────────────────
MOCK_CONFIG="fedora-$(rpm --eval '%{fedora}')-$(uname -m)"
RESULT_DIR="${SCRIPT_DIR}/_review"
SRPM_DIR=""
START_FROM=""

# ── parse args ────────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        --mock-config) MOCK_CONFIG="$2"; shift 2 ;;
        --resultdir)   RESULT_DIR="$2";  shift 2 ;;
        --srpmdir)     SRPM_DIR="$2";    shift 2 ;;
        --start-from)  START_FROM="$2";  shift 2 ;;
        -h|--help)
            sed -n '2,/^$/s/^# \?//p' "$0"
            exit 0
            ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

# ── build order (same as build-chain.sh) ─────────────────────────────────────
BUILD_ORDER=(
    hyprutils
    glaze
    hyprwayland-scanner
    hyprland-protocols
    hyprlang
    hyprwire
    hyprgraphics
    aquamarine
    hyprland-qtutils
    hyprcursor
    hyprland-qt-support
    hypridle
    hyprsunset
    hyprlock
    xdg-desktop-portal-hyprland
    hyprtoolkit
    hyprpaper
    hyprland-guiutils
    hyprlauncher
    hyprland-git
)

# ── colours ───────────────────────────────────────────────────────────────────
if [[ -t 1 ]]; then
    BOLD=$'\e[1m'  GREEN=$'\e[32m'  RED=$'\e[31m'  YELLOW=$'\e[33m'  CYAN=$'\e[36m'  RESET=$'\e[0m'
else
    BOLD=""  GREEN=""  RED=""  YELLOW=""  CYAN=""  RESET=""
fi

info()  { echo "${BOLD}${CYAN}==> $*${RESET}"; }
ok()    { echo "${BOLD}${GREEN} ✓  $*${RESET}"; }
warn()  { echo "${BOLD}${YELLOW} ⚠  $*${RESET}"; }
die()   { echo "${BOLD}${RED}ERROR: $*${RESET}" >&2; exit 1; }

# ── sanity checks ─────────────────────────────────────────────────────────────
for cmd in fedora-review rpmbuild spectool createrepo_c; do
    command -v "$cmd" &>/dev/null || die "$cmd is not installed"
done

# ── set up local repo ────────────────────────────────────────────────────────
LOCAL_REPO="${RESULT_DIR}/local-repo"
LOGS_DIR="${RESULT_DIR}/logs"
mkdir -p "$LOCAL_REPO" "$LOGS_DIR"
createrepo_c --quiet "$LOCAL_REPO"

# ── write a mock config overlay that includes the local repo ─────────────────
MOCK_CFG_OVERLAY="${RESULT_DIR}/hyprland-review.cfg"
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
info "Config overlay: ${MOCK_CFG_OVERLAY}"
info "Results dir : ${RESULT_DIR}"
info "Local repo  : ${LOCAL_REPO}"
[[ -n "$SRPM_DIR" ]] && info "SRPM dir    : ${SRPM_DIR}"
echo

# ── handle --start-from ──────────────────────────────────────────────────────
SKIPPING=false
if [[ -n "$START_FROM" ]]; then
    SKIPPING=true
fi

# ── build an SRPM for a package ──────────────────────────────────────────────
build_srpm() {
    local pkg="$1"
    local spec_dir="${SCRIPT_DIR}/${pkg}"
    local spec_file="${spec_dir}/${pkg}.spec"
    local srpm_out_dir="${RESULT_DIR}/srpms"
    mkdir -p "$srpm_out_dir"

    # download sources
    spectool -g -C "$spec_dir" "$spec_file" \
        >> "${LOGS_DIR}/${pkg}-spectool.log" 2>&1 || return 1

    # build SRPM
    local output
    output=$(rpmbuild -bs \
        --define "_sourcedir ${spec_dir}" \
        --define "_srcrpmdir ${srpm_out_dir}" \
        --define "_topdir ${RESULT_DIR}/rpmbuild" \
        "$spec_file" 2>&1 | tee "${LOGS_DIR}/${pkg}-srpm.log")

    echo "$output" | grep -oP '(?<=Wrote: ).*\.src\.rpm' | head -1 || return 1
}

# ── find a pre-built SRPM ────────────────────────────────────────────────────
find_srpm() {
    local pkg="$1" dir="$2"
    find "$dir" -maxdepth 1 -name "${pkg}-*.src.rpm" -print -quit 2>/dev/null
}

# ── main review loop ─────────────────────────────────────────────────────────
TOTAL=${#BUILD_ORDER[@]}
REVIEWED=0
FAILED=()

for pkg in "${BUILD_ORDER[@]}"; do
    if $SKIPPING; then
        if [[ "$pkg" == "$START_FROM" ]]; then
            SKIPPING=false
        else
            echo "  ⏭  Skipping ${pkg} (--start-from ${START_FROM})"
            continue
        fi
    fi

    REVIEWED=$((REVIEWED + 1))
    SPEC_FILE="${SCRIPT_DIR}/${pkg}/${pkg}.spec"

    echo
    info "[${REVIEWED}/${TOTAL}] Reviewing ${pkg}"

    if [[ ! -f "$SPEC_FILE" ]]; then
        die "Spec file not found: ${SPEC_FILE}"
    fi

    # ── locate or build SRPM ──────────────────────────────────────────────
    SRPM_PATH=""
    if [[ -n "$SRPM_DIR" ]]; then
        SRPM_PATH=$(find_srpm "$pkg" "$SRPM_DIR")
    fi

    if [[ -z "$SRPM_PATH" ]]; then
        info "  Building SRPM..."
        SRPM_PATH=$(build_srpm "$pkg") || true
    fi

    if [[ -z "$SRPM_PATH" || ! -f "$SRPM_PATH" ]]; then
        echo "${RED}  ✗ Could not obtain SRPM (see ${LOGS_DIR}/${pkg}-srpm.log)${RESET}"
        FAILED+=("$pkg")
        continue
    fi

    # ── run fedora-review in its own workdir ──────────────────────────────
    REVIEW_WORKDIR="${RESULT_DIR}/${pkg}"
    mkdir -p "$REVIEW_WORKDIR"

    # fedora-review -n expects <name>.spec and <name>-*.src.rpm in the cwd
    PKG_NAME=$(rpm -qp --qf '%{NAME}' "$SRPM_PATH" 2>/dev/null)
    ln -sf "$SPEC_FILE" "${REVIEW_WORKDIR}/${PKG_NAME}.spec"
    ln -sf "$SRPM_PATH" "${REVIEW_WORKDIR}/$(basename "$SRPM_PATH")"

    # Build the fedora-review command
    # Use the overlay config so mock can find previously-built packages
    FR_ARGS=(
        fedora-review
        -n "$PKG_NAME"
        --mock-config "$MOCK_CFG_OVERLAY"
    )

    REVIEW_LOG="${LOGS_DIR}/${pkg}-review.log"

    info "  Running: ${FR_ARGS[*]}"
    info "  Working directory: ${REVIEW_WORKDIR}"
    FR_RC=0
    cd "$REVIEW_WORKDIR"
    "${FR_ARGS[@]}" > "$REVIEW_LOG" 2>&1 || FR_RC=$?
    cd "$SCRIPT_DIR"

    if [[ $FR_RC -ne 0 ]]; then
        echo "${RED}  ✗ fedora-review exited with code ${FR_RC}${RESET}"
        if [[ -s "$REVIEW_LOG" ]]; then
            echo "${RED}  Last 15 lines of log:${RESET}"
            tail -15 "$REVIEW_LOG" | sed 's/^/    /'
        else
            echo "${RED}  ✗ Log file is empty — fedora-review produced no output${RESET}"
        fi
        FAILED+=("$pkg")
        # still try to harvest RPMs for later packages
    fi

    # ── copy any built RPMs to local repo ─────────────────────────────────
    # fedora-review may leave results under results/ or <pkg>/results/
    find "$REVIEW_WORKDIR" -name '*.rpm' -not -name '*.src.rpm' \
        -exec cp -n {} "$LOCAL_REPO/" \; 2>/dev/null || true
    createrepo_c --update --quiet "$LOCAL_REPO"

    # ── show review outcome ───────────────────────────────────────────────
    # fedora-review may put review.txt in the workdir or a subdirectory
    REVIEW_TXT=$(find "$REVIEW_WORKDIR" -name 'review.txt' -print -quit 2>/dev/null)
    if [[ -n "$REVIEW_TXT" && -f "$REVIEW_TXT" ]]; then
        ok "${pkg} — review complete"

        # Count PASS / FAIL / PENDING
        # Note: grep -c outputs "0" and exits 1 when no matches; || true
        # prevents set -e from killing the script without duplicating output
        PASS_N=$(grep -c '^\[x\]'  "$REVIEW_TXT" 2>/dev/null) || PASS_N=0
        FAIL_N=$(grep -c '^\[!\]'  "$REVIEW_TXT" 2>/dev/null) || FAIL_N=0
        PEND_N=$(grep -c '^\[ \]'  "$REVIEW_TXT" 2>/dev/null) || PEND_N=0
        NA_N=$(grep -c '^\[na\]'   "$REVIEW_TXT" 2>/dev/null) || NA_N=0

        echo "     ${GREEN}PASS: ${PASS_N}${RESET}  ${RED}FAIL: ${FAIL_N}${RESET}  PENDING: ${PEND_N}  N/A: ${NA_N}"
        echo "     Report: ${REVIEW_TXT}"

        if [[ "$FAIL_N" -gt 0 ]]; then
            warn "  Failures:"
            grep '^\[!\]' "$REVIEW_TXT" | sed 's/^/       /'
        fi
    else
        warn "${pkg} — no review.txt produced"
        if [[ -s "$REVIEW_LOG" ]]; then
            echo "     Log: ${REVIEW_LOG}"
            echo "     Last 10 lines:"
            tail -10 "$REVIEW_LOG" | sed 's/^/       /'
        else
            echo "     No log output was captured — fedora-review may have crashed immediately."
            echo "     Try running manually:  cd ${REVIEW_WORKDIR} && ${FR_ARGS[*]}"
        fi
    fi
done

# ── summary ───────────────────────────────────────────────────────────────────
echo
echo "═══════════════════════════════════════════════════════════════"
info "Review reports are in: ${RESULT_DIR}/<package>/review.txt"
echo

if [[ ${#FAILED[@]} -eq 0 ]]; then
    ok "All packages reviewed successfully!"
else
    echo "${RED}${BOLD}Failed packages (${#FAILED[@]}):${RESET}"
    for f in "${FAILED[@]}"; do
        echo "  • $f  (log: ${LOGS_DIR}/${f}-review.log)"
    done
fi
echo "═══════════════════════════════════════════════════════════════"

exit ${#FAILED[@]}
