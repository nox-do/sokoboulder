#!/bin/bash
# Universal, ad-hoc signed distribution; requires macOS and Xcode 26.6.
set -euo pipefail
cd "$(dirname "$0")/.."

version="${1:-}"
build_number="${BUILD_NUMBER:-1}"
if [[ $# -ne 1 || ! "$version" =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]]; then
  echo "Usage: $0 MAJOR.MINOR.PATCH (e.g. 0.1.0)" >&2
  exit 1
fi
if [[ ! "$build_number" =~ ^[1-9][0-9]*$ ]]; then
  echo 'BUILD_NUMBER must be a positive integer.' >&2
  exit 1
fi
output="$PWD/dist/$version"
if [[ -e "$output" ]]; then
  echo "Output already exists: $output. Move it aside before rebuilding." >&2
  exit 1
fi
mkdir -p build dist
work=$(mktemp -d "$PWD/build/package.XXXXXX")
trap 'rm -rf "$work"' EXIT
stage="$work/stage"
artifacts="$work/artifacts"
mkdir -p "$stage" "$artifacts"

xcodebuild \
  -project MacGameApp.xcodeproj \
  -scheme MacGameApp \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -derivedDataPath "$work/DerivedData" \
  ARCHS='arm64 x86_64' ONLY_ACTIVE_ARCH=NO \
  CODE_SIGNING_ALLOWED=NO CLANG_ENABLE_CODE_COVERAGE=NO \
  MARKETING_VERSION="$version" CURRENT_PROJECT_VERSION="$build_number" \
  build

app="$stage/SokoBoulder.app"
ditto "$work/DerivedData/Build/Products/Release/MacGameApp.app" "$app"
# Keep credits inside the app so they travel with ZIP and DMG installations.
mkdir -p "$app/Contents/Resources/Legal"
cp LICENSE THIRD_PARTY_NOTICES.md "$app/Contents/Resources/Legal/"
codesign --force --sign - \
  --entitlements MacGameApp/MacGameApp.entitlements "$app"
codesign --verify --deep --strict --verbose=2 "$app"
lipo "$app/Contents/MacOS/MacGameApp" -verify_arch arm64 x86_64
[[ "$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$app/Contents/Info.plist")" == "$version" ]]
[[ "$(/usr/libexec/PlistBuddy -c 'Print CFBundleVersion' "$app/Contents/Info.plist")" == "$build_number" ]]

ln -s /Applications "$stage/Programme"
cat > "$artifacts/START-HERE.txt" <<'NOTES'
SokoBoulder — macOS 14 oder neuer; Apple Silicon und Intel

DMG: öffnen und SokoBoulder.app nach Programme ziehen; von dort starten.
ZIP: entpacken, SokoBoulder.app nach Programme verschieben und dort starten.
Xcode wird nicht benötigt.

SokoBoulder ist eine quelloffene Demo, die du selbst bauen kannst. Für dieses
Projekt verzichten wir auf ein kostenpflichtiges Apple-Entwicklerkonto und damit
auf die Notarisierung.

Falls macOS beim ersten Start „Apple konnte nicht überprüfen …“ meldet:

1. Fertig klicken.
2. Systemeinstellungen → Datenschutz & Sicherheit → Sicherheit → Dennoch öffnen wählen.
3. Mit Öffnen bestätigen.

Drittanbieter-Lizenzen:
SokoBoulder.app/Contents/Resources/Legal/THIRD_PARTY_NOTICES.md.
Eigener Quellcode: MIT-Lizenz, siehe
SokoBoulder.app/Contents/Resources/Legal/LICENSE.
Drittanbieter-Assets behalten ihre jeweiligen Lizenzen.
NOTES
name="SokoBoulder-$version-macos-universal"
# ditto preserves bundle metadata, permissions and symlinks.
ditto -c -k --sequesterRsrc --keepParent "$app" "$artifacts/$name.zip"
./scripts/create-dmg.sh "$stage" "$artifacts/$name.dmg" "SokoBoulder $version"
(
  cd "$artifacts"
  shasum -a 256 "$name.dmg" "$name.zip" START-HERE.txt > SHA256SUMS.txt
)
# Publish output only once all packaging and validation steps succeeded.
mv "$artifacts" "$output"
printf '\nRelease artifacts: %s\n' "$output"
