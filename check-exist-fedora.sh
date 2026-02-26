#!/bin/bash

set -euo pipefail

. package-order

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

SKIPPING=false
if [[ -n "$START_FROM" ]]; then
    SKIPPING=true
fi

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

    pushd /tmp &> /dev/null
    rm -rf "${pkg}"
    set +e
    fedpkg clone -a "${pkg}" &> /tmp/lastfedpkg
    ret=$?
    set -e
    if [ $ret -ne 0 ]; then
        echo "${pkg} does not exist yet"
    else
        if [ -f "./${pkg}/dead.package" ]; then
            echo "${pkg} is ORPHANED"
        else
            echo "${pkg} is maintained"
        fi
    fi
    popd &> /dev/null
done
