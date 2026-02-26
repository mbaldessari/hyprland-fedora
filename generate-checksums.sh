#!/bin/bash
# Generate or verify SHA256 checksums for all spec file sources.
# Checksums are stored in a 'sources' file in each package directory,
# following the dist-git convention.
#
# Usage:
#   ./generate-checksums.sh              # Generate/update all checksums
#   ./generate-checksums.sh --verify     # Verify existing checksums
#   ./generate-checksums.sh <package>    # Generate for a single package
#
# Requires: spectool (from rpmdevtools), sha256sum

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODE="${1:-generate}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BOLD='\033[1m'
RESET='\033[0m'

if ! command -v spectool &>/dev/null; then
    echo "Error: spectool is required. Install with: sudo dnf install rpmdevtools" >&2
    exit 1
fi

process_package() {
    local specfile="$1"
    local pkg_dir
    pkg_dir="$(dirname "$specfile")"
    local pkg_name
    pkg_name="$(basename "$pkg_dir")"
    local sources_file="${pkg_dir}/sources"

    if [[ "$MODE" == "--verify" ]]; then
        if [[ ! -f "$sources_file" ]]; then
            printf "${YELLOW}%-35s  no sources file${RESET}\n" "$pkg_name"
            return 1
        fi

        local tmpdir
        tmpdir="$(mktemp -d)"
        trap "rm -rf '$tmpdir'" RETURN

        # Download sources
        if ! spectool -g -C "$tmpdir" "$specfile" &>/dev/null; then
            printf "${RED}%-35s  download failed${RESET}\n" "$pkg_name"
            return 1
        fi

        # Verify each checksum
        local fail=0
        while IFS= read -r line; do
            [[ -z "$line" || "$line" == \#* ]] && continue
            local hash filename
            hash="$(echo "$line" | awk '{print $1}')"
            filename="$(echo "$line" | awk '{print $2}')"

            if [[ ! -f "${tmpdir}/${filename}" ]]; then
                printf "${RED}%-35s  %s: missing${RESET}\n" "$pkg_name" "$filename"
                fail=1
                continue
            fi

            local actual_hash
            actual_hash="$(sha256sum "${tmpdir}/${filename}" | awk '{print $1}')"

            if [[ "$hash" != "$actual_hash" ]]; then
                printf "${RED}${BOLD}%-35s  %s: MISMATCH${RESET}\n" "$pkg_name" "$filename"
                printf "  expected: %s\n" "$hash"
                printf "  got:      %s\n" "$actual_hash"
                fail=1
            fi
        done < "$sources_file"

        if [[ "$fail" -eq 0 ]]; then
            printf "${GREEN}%-35s  OK${RESET}\n" "$pkg_name"
        fi

        trap - RETURN
        rm -rf "$tmpdir"
        return "$fail"
    else
        # Generate mode
        local tmpdir
        tmpdir="$(mktemp -d)"

        printf "%-35s  downloading..." "$pkg_name"

        if ! spectool -g -C "$tmpdir" "$specfile" &>/dev/null; then
            printf "\r${RED}%-35s  download failed${RESET}\n" "$pkg_name"
            rm -rf "$tmpdir"
            return 1
        fi

        # Generate checksums (only for remote sources, skip local files like .rpmlintrc and patches)
        > "$sources_file"
        for src in "$tmpdir"/*; do
            [[ -f "$src" ]] || continue
            local filename
            filename="$(basename "$src")"
            local hash
            hash="$(sha256sum "$src" | awk '{print $1}')"
            echo "$hash  $filename" >> "$sources_file"
        done

        printf "\r${GREEN}%-35s  sources file updated${RESET}\n" "$pkg_name"

        rm -rf "$tmpdir"
    fi
}

# Header
if [[ "$MODE" == "--verify" ]]; then
    printf "${BOLD}Verifying source checksums...${RESET}\n\n"
else
    printf "${BOLD}Generating source checksums...${RESET}\n\n"
fi

# If a specific package name was given, process only that one
if [[ "$MODE" != "--verify" && "$MODE" != "generate" && -d "$SCRIPT_DIR/$MODE" ]]; then
    specfile="$(ls "$SCRIPT_DIR/$MODE"/*.spec 2>/dev/null | head -1)"
    if [[ -n "$specfile" ]]; then
        process_package "$specfile"
    else
        echo "No spec file found in $MODE/" >&2
        exit 1
    fi
    exit 0
fi

# Process all packages
fail_count=0
for specfile in "$SCRIPT_DIR"/*//*.spec; do
    dir="$(dirname "$specfile")"
    [[ "$dir" == *"_review"* ]] && continue
    process_package "$specfile" || ((fail_count++)) || true
done

if [[ "$MODE" == "--verify" && "$fail_count" -gt 0 ]]; then
    echo ""
    printf "${RED}${BOLD}%d package(s) failed verification${RESET}\n" "$fail_count"
    exit 1
fi
