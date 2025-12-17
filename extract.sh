#!/bin/bash
set -euo pipefail

# -----------------------------------------------------------------------------
# extract.sh
# 
# Purpose:
#   Parses a proprietary WAS-110 firmware header to extract embedded components.
#   The header structure contains offsets and lengths for:
#   - bootcore.bin
#   - kernel.bin
#   - rootfs.img
#
# Usage:
#   ./extract.sh -i <image_file>
# -----------------------------------------------------------------------------

_help() {
	printf -- 'Tool for extracting stock WAS-110 local upgrade images\n\n'
	printf -- 'Usage: %s [options]\n\n' "$0"
	printf -- 'Options:\n'
	printf -- '-i --image <filename>\t\tSpecify local upgrade image file to extract (required).\n'
	printf -- '-H --header <filename>\t\tSpecify filename to extract image header to (default: header.bin).\n'
	printf -- '-b --bootcore <filename>\tSpecify filename to extract bootcore image to (default: bootcore.bin).\n'
	printf -- '-k --kernel <filename>\t\tSpecify filename to extract kernel image to (default: kernel.bin).\n'
	printf -- '-r --rootfs <filename>\t\tSpecify filename to extract rootfs image to (default: rootfs.img).\n'
	printf -- '-h --help\t\t\tThis help text\n'
}

LOCAL=
HEADER="header.bin"
BOOTCORE="bootcore.bin"
KERNEL="kernel.bin"
ROOTFS="rootfs.img"

while [ $# -gt 0 ]; do
	case "$1" in
		-i|--image)
			LOCAL="$2"
			shift
		;;
		-H|--header)
			HEADER="$2"
			shift
		;;
		-b|--bootcore)
			BOOTCORE="$2"
			shift
		;;
		-k|--kernel)
			KERNEL="$2"
			shift
		;;
		-r|--rootfs)
			ROOTFS="$2"
			shift
		;;
		--help|-h)
			_help
			exit 0
		;;
		*)
			_help
			exit 1
		;;
	esac
	shift
done

_err() {
	echo "$1" >&2
	exit ${2:-1}
}

set -e

[ -n "$LOCAL" ] || _err "Error: Image file to extract must be specified."
[ -f "$LOCAL" ] || _err "Error: Image file '$LOCAL' does not exist."
[ -n "$HEADER" ] || _err "Error: Invalid header file specified."
[ -n "$BOOTCORE" ] || _err "Error: Invalid bootcore file specified."
[ -n "$KERNEL" ] || _err "Error: Invalid kernel file specified."
[ -n "$ROOTFS" ] || _err "Error: Invalid rootfs file specified."

# Check magic string (first 16 bytes)
MAGIC=$(head -c 16 "$LOCAL")
if [ "$MAGIC" != '~@$^*)+ATOS!#%&(' ]; then
    _err "Invalid magic string in '$LOCAL'. Is this a valid WAS-110 firmware image?"
fi

LEN_HDR=$((0xD00))

echo "Extracting image header to '$HEADER' ($LEN_HDR bytes)"
head -c "$LEN_HDR" "$LOCAL" > "$HEADER"

POS=$LEN_HDR
NUM=0
FILE_OFFSET=$((0x100))

extract_image() {
	IMAGE="$1"
	OUT="${2:-$1}"

	DETAIL_OFFSET=$((FILE_OFFSET + (NUM + 1) * 48))
	FILE=$(head -c $((DETAIL_OFFSET - 16)) "$HEADER" | tail -c 32 | tr -d '\0')
	if [ "$FILE" != "$IMAGE" ]; then
		_err "Image '$IMAGE' expected as image #$NUM but found '$FILE'"
	fi

	LEN_RAW=$(head -c $DETAIL_OFFSET "$HEADER" | tail -c 16 | tr -d '\0')
	# Ensure LEN_RAW is a number
	if ! [[ "$LEN_RAW" =~ ^[0-9]+$ ]]; then
		_err "Failed to parse length for image #$NUM ($IMAGE)"
	fi
	LEN=$((0 + LEN_RAW))
	POS=$((POS + LEN))

	echo "Extracting image #$NUM ($IMAGE) to '$OUT' ($LEN bytes)"
	head -c "$POS" "$LOCAL" | tail -c "$LEN" > "$OUT"
	SIZE=$(stat -c "%s" "$OUT")
	if [ "$SIZE" -ne "$LEN" ]; then
		echo "Extracted Image '$OUT' is not the expected size (expected: $LEN, actual: $SIZE)" >&2
		exit 1
	fi

	NUM=$((NUM + 1))
}


extract_image "bootcore.bin" "$BOOTCORE"
extract_image "kernel.bin" "$KERNEL"
extract_image "rootfs.img" "$ROOTFS"


