#!/bin/bash
# check-bugs.sh — Query Fedora Bugzilla for open bugs in all packages.
#
# Usage:
#   ./check-bugs.sh

set -euo pipefail

. package-order

BUGZILLA="https://bugzilla.redhat.com/rest/bug"

if [[ -t 1 ]]; then
    BOLD=$'\e[1m'  GREEN=$'\e[32m'  RED=$'\e[31m'  CYAN=$'\e[36m'  YELLOW=$'\e[33m'  RESET=$'\e[0m'
else
    BOLD=""  GREEN=""  RED=""  CYAN=""  YELLOW=""  RESET=""
fi

command -v curl &>/dev/null || { echo "ERROR: curl is not installed" >&2; exit 1; }
command -v jq &>/dev/null   || { echo "ERROR: jq is not installed" >&2; exit 1; }

TOTAL_BUGS=0

for pkg in "${BUILD_ORDER[@]}"; do
    url="${BUGZILLA}?product=Fedora&component=${pkg}&bug_status=NEW&bug_status=ASSIGNED&bug_status=POST&bug_status=MODIFIED&include_fields=id,summary,status,severity,creation_time"

    response=$(curl -s --fail-with-body "$url") || {
        echo "${RED}${BOLD}${pkg}${RESET}${RED}: failed to query bugzilla${RESET}" >&2
        continue
    }

    count=$(echo "$response" | jq '.bugs | length')

    if [[ "$count" -eq 0 ]]; then
        echo "${GREEN}${pkg}${RESET}: no open bugs"
        continue
    fi

    TOTAL_BUGS=$((TOTAL_BUGS + count))
    echo "${YELLOW}${BOLD}${pkg}${RESET}${YELLOW}: ${count} open bug(s)${RESET}"

    echo "$response" | jq -r '.bugs[] | "  #\(.id) [\(.status)] \(.summary)"'
done

echo
if [[ "$TOTAL_BUGS" -eq 0 ]]; then
    echo "${GREEN}${BOLD}No open bugs across all packages.${RESET}"
else
    echo "${CYAN}${BOLD}Total open bugs: ${TOTAL_BUGS}${RESET}"
fi
