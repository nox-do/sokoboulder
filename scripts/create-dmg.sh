#!/bin/bash
# Finder layout is stored in the image, independent of the build machine's UI.
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ $# -ne 3 ]]; then
  echo "Usage: $0 STAGING_DIRECTORY OUTPUT_DMG VOLUME_NAME" >&2
  exit 1
fi
stage="$1"
output="$2"
volume_name="$3"
mkdir -p build
venv="$PWD/build/packaging-venv"
if [[ ! -x "$venv/bin/python3" ]]; then
  python3 -m venv "$venv"
fi
"$venv/bin/python3" -m pip install --disable-pip-version-check --quiet -r scripts/dmg/requirements.txt
work=$(mktemp -d "$PWD/build/dmg.XXXXXX")
mounted=false
cleanup() {
  if [[ "$mounted" == true ]]; then
    hdiutil detach "$work/volume" -force >/dev/null || true
  fi
  rm -rf "$work"
}
trap cleanup EXIT
mkdir -p "$stage/.background"
cp scripts/dmg/background.png "$stage/.background/"
hdiutil create -volname "$volume_name" -fs HFS+ -srcfolder "$stage" \
  -format UDRW "$work/writable.dmg"
hdiutil attach "$work/writable.dmg" -readwrite -nobrowse -noautoopen \
  -mountpoint "$work/volume"
mounted=true
"$venv/bin/python3" scripts/dmg/layout.py "$work/volume"
hdiutil detach "$work/volume"
mounted=false
hdiutil convert "$work/writable.dmg" -format UDZO -o "$output"
hdiutil verify "$output"
