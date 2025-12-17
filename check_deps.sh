#!/bin/bash
set -euo pipefail

# -----------------------------------------------------------------------------
# check_deps.sh
# 
# Purpose:
#   Verifies that the build environment has all necessary tools installed.
#   This is essential because the build process relies on several external
#   utilities (u-boot-tools, squashfs-tools, etc.) and Perl modules.
#
# Usage:
#   ./check_deps.sh
#
# Returns:
#   0 on success (all deps found)
#   1 on failure (missing deps)
# -----------------------------------------------------------------------------

# Dependencies required for the build process
REQUIRED_CMDS=("bash" "perl" "mkimage" "unsquashfs" "mksquashfs" "7z" "git" "sha256sum" "dd" "stat" "awk" "sed" "grep" "tr" "head" "tail" "cut")

# Optional but recommended
OPTIONAL_CMDS=("fakeroot" "shellcheck")

# Perl modules
REQUIRED_PERL_MODS=("Digest::CRC")

_err() {
    echo "ERROR: $*" >&2
    exit 1
}

check_cmd() {
    if ! command -v "$1" &> /dev/null; then
        echo "MISSING: Command '$1' is not found in PATH."
        return 1
    else
        echo "OK: '$1' found."
        return 0
    fi
}

check_perl_mod() {
    if ! perl -M"$1" -e 1 &> /dev/null; then
        echo "MISSING: Perl module '$1' is not installed."
        return 1
    else
        echo "OK: Perl module '$1' found."
        return 0
    fi
}

echo "Checking build dependencies..."
MISSING_COUNT=0

for cmd in "${REQUIRED_CMDS[@]}"; do
    if ! check_cmd "$cmd"; then
        MISSING_COUNT=$((MISSING_COUNT + 1))
    fi
done

for mod in "${REQUIRED_PERL_MODS[@]}"; do
    if ! check_perl_mod "$mod"; then
        MISSING_COUNT=$((MISSING_COUNT + 1))
    fi
done

echo ""
echo "Checking optional dependencies..."
for cmd in "${OPTIONAL_CMDS[@]}"; do
    check_cmd "$cmd" || true
done

echo ""
if [ "$MISSING_COUNT" -gt 0 ]; then
    _err "Missing $MISSING_COUNT required dependencies. Please install them and try again."
else
    echo "Success: All required dependencies are present."
fi
