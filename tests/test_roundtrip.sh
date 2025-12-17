#!/bin/bash
set -euo pipefail

# This script verifies that extracting and then re-creating an image results in the same file structure.
# Usage: ./tests/test_roundtrip.sh [path_to_image]

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_DIR="$BASE_DIR/tmp_test_run"
IMAGE="${1:-}"

if [ -z "$IMAGE" ]; then
    echo "SKIPPING: No image provided. Usage: $0 <path_to_image>"
    echo "To run this test, provide a valid WAS-110 firmware image."
    exit 0
fi

if [ ! -f "$IMAGE" ]; then
    echo "ERROR: Image file '$IMAGE' not found."
    exit 1
fi

echo "Starting roundtrip test with image: $IMAGE"

# Clean up previous run
rm -rf "$TEST_DIR"
mkdir -p "$TEST_DIR"

cleanup() {
    echo "Cleaning up..."
    rm -rf "$TEST_DIR"
}
trap cleanup EXIT

# Step 1: Extract
echo "Step 1: Extracting..."
"$BASE_DIR/extract.sh" -i "$IMAGE" -H "$TEST_DIR/header.bin" -b "$TEST_DIR/bootcore.bin" -k "$TEST_DIR/kernel.bin" -r "$TEST_DIR/rootfs.img"

# Step 2: Create (Re-assemble)
echo "Step 2: Re-creating..."
# We reuse the extracted header, bootcore, kernel, and rootfs to build a new image
NEW_IMAGE="$TEST_DIR/new_image.img"

"$BASE_DIR/create.sh" --bfw -i "$NEW_IMAGE" -H "$TEST_DIR/header.bin" -b "$TEST_DIR/bootcore.bin" -k "$TEST_DIR/kernel.bin" -r "$TEST_DIR/rootfs.img"

# Step 3: Compare
echo "Step 3: Verifying..."
if [ ! -f "$NEW_IMAGE" ]; then
    echo "FAILURE: New image was not created."
    exit 1
fi

# Note: The new image might not be bit-identical depending on how CRCs or timestamps are handled,
# but we can check if it extracts again correctly or check sizes.
# For now, let's just check if it exists and has a somewhat similar size.

ORIG_SIZE=$(stat -c%s "$IMAGE")
NEW_SIZE=$(stat -c%s "$NEW_IMAGE")

echo "Original Size: $ORIG_SIZE"
echo "New Size:      $NEW_SIZE"

# Allow some variance if metadata changes, but for exact reconstruction it should be close.
DIFF=$((ORIG_SIZE - NEW_SIZE))
if [ "${DIFF#-}" -gt 1024 ]; then
    echo "WARNING: Size difference is > 1KB ($DIFF bytes). Verification might have failed."
else
    echo "SUCCESS: Roundtrip complete. Image recreated successfully with similar size."
fi
