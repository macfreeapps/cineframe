#!/bin/bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "Usage: $0 INPUT OUTPUT" >&2
  exit 64
fi
if ! command -v exiftool >/dev/null 2>&1; then
  echo "exiftool is required; install it before comparing metadata." >&2
  exit 69
fi

input="$1"
output="$2"
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

exiftool -a -G1 -s "$input" | LC_ALL=C sort > "$tmpdir/input.txt"
exiftool -a -G1 -s "$output" | LC_ALL=C sort > "$tmpdir/output.txt"

# These values are expected to change after cropping, orientation normalization,
# export, or app attribution. Everything else remains visible in the diff.
filter_expected_changes() {
  awk -F'] ' '
    /\[XMP-cineframe\]/ { next }
    {
      field = $NF
      if (field ~ /^(FileName|Directory|FileSize|FileModifyDate|FileAccessDate|FileInodeChangeDate|Permissions|FilePermissions|MIMEType|ImageWidth|ImageHeight|ExifImageWidth|ExifImageHeight|PixelXDimension|PixelYDimension|Orientation|Software|ModifyDate|MetadataDate|History|ThumbnailImage|PreviewImage|JpgFromRaw|Megapixels|ImageSize|BitDepth|Compression|BitsPerSample|SourceFile|SubjectArea|RegionInfo|Regions|Faces)$/) next
      print
    }
  ' "$1"
}
filter_expected_changes "$tmpdir/input.txt" > "$tmpdir/input-filtered.txt"
filter_expected_changes "$tmpdir/output.txt" > "$tmpdir/output-filtered.txt"

if diff -u "$tmpdir/input-filtered.txt" "$tmpdir/output-filtered.txt"; then
  echo "Metadata comparison passed (excluding expected output changes)."
else
  echo "Metadata differences found; inspect the diff above." >&2
  exit 1
fi
