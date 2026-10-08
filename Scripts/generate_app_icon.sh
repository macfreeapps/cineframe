#!/bin/bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
swift "$root/Scripts/generate_app_icon.swift"
icon_dir="$root/CineFrame/Resources/Assets.xcassets/AppIcon.appiconset"
for spec in "icon_16.png 16" "icon_32.png 32" "icon_64.png 64" "icon_128.png 128" "icon_256.png 256" "icon_512.png 512"; do
  name="${spec% *}"
  size="${spec##* }"
  sips -z "$size" "$size" "$icon_dir/AppIcon.png" --out "$icon_dir/$name" >/dev/null
done
