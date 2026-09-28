#!/bin/bash
# Check for new upstream releases for all spec files
# Usage: ./check-updates.sh [--quiet]
#
# Requires: curl, jq

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
QUIET="${1:-}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BOLD='\033[1m'
RESET='\033[0m'

if ! command -v jq &>/dev/null; then
    echo "Error: jq is required. Install with: sudo dnf install jq" >&2
    exit 1
fi

# Extract the base version (strip RPM snapshot suffixes like ^4.gitXXXXXXX)
strip_version() {
    echo "$1" | sed -E 's/\^.*//; s/~.*//'
}

# Compare two version strings, returns 0 if $1 < $2
version_lt() {
    [ "$(printf '%s\n%s' "$1" "$2" | sort -V | head -n1)" = "$1" ] && [ "$1" != "$2" ]
}

check_package() {
    local specfile="$1"
    local pkg_dir
    pkg_dir="$(basename "$(dirname "$specfile")")"

    # Extract Version and URL from spec
    local raw_version url
    raw_version="$(grep -m1 '^Version:' "$specfile" | awk '{print $2}')"
    url="$(grep -m1 '^URL:' "$specfile" | awk '{print $2}')"

    # Skip specs without a GitHub URL
    if [[ ! "$url" =~ github\.com ]]; then
        return
    fi

    # Extract owner/repo from URL
    local owner repo
    owner="$(echo "$url" | sed -E 's|https?://github\.com/([^/]+)/.*|\1|')"
    repo="$(echo "$url" | sed -E 's|https?://github\.com/[^/]+/([^/]+).*|\1|')"

    # Clean the version for comparison
    local current_version
    current_version="$(strip_version "$raw_version")"

    # Resolve any remaining RPM macros in version (e.g. %{?bumpver:...})
    # Strip everything from the first % onward
    if [[ "$current_version" == *"%"* ]]; then
        current_version="${current_version%%%*}"
    fi

    # Query GitHub API for the latest release
    local api_url="https://api.github.com/repos/${owner}/${repo}/releases/latest"
    local response
    response="$(curl -sf -H "Accept: application/vnd.github.v3+json" "$api_url" 2>/dev/null)" || true

    local latest_tag=""
    if [[ -n "$response" ]]; then
        latest_tag="$(echo "$response" | jq -r '.tag_name // empty' 2>/dev/null)"
    fi

    # If no release found, try tags instead
    if [[ -z "$latest_tag" ]]; then
        local tags_url="https://api.github.com/repos/${owner}/${repo}/tags?per_page=1"
        response="$(curl -sf -H "Accept: application/vnd.github.v3+json" "$tags_url" 2>/dev/null)" || true
        if [[ -n "$response" ]]; then
            latest_tag="$(echo "$response" | jq -r '.[0].name // empty' 2>/dev/null)"
        fi
    fi

    if [[ -z "$latest_tag" ]]; then
        printf "${YELLOW}%-35s %-12s  %-12s  %s${RESET}\n" \
            "$pkg_dir" "$current_version" "???" "Could not query upstream"
        return
    fi

    # Strip leading 'v' from tag
    local latest_version="${latest_tag#v}"

    if version_lt "$current_version" "$latest_version"; then
        printf "${RED}${BOLD}%-35s %-12s  %-12s  UPDATE AVAILABLE${RESET}\n" \
            "$pkg_dir" "$current_version" "$latest_version"
    else
        if [[ "$QUIET" != "--quiet" ]]; then
            printf "${GREEN}%-35s %-12s  %-12s  up to date${RESET}\n" \
                "$pkg_dir" "$current_version" "$latest_version"
        fi
    fi
}

printf "${BOLD}%-35s %-12s  %-12s  %s${RESET}\n" \
    "PACKAGE" "CURRENT" "UPSTREAM" "STATUS"
printf "%s\n" "$(printf '%.0s-' {1..85})"

# Find all spec files in direct subdirectories (skip _review/)
for specfile in "$SCRIPT_DIR"/*//*.spec; do
    dir="$(dirname "$specfile")"
    # Skip _review directory
    [[ "$dir" == *"_review"* ]] && continue
    check_package "$specfile"
done
