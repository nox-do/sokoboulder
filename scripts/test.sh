#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

./scripts/lint.sh

swift test --package-path Packages/GameCore --scratch-path "$PWD/build/game-core"
xcodebuild \
  -project MacGameApp.xcodeproj \
  -scheme MacGameApp \
  -configuration Debug \
  -destination "platform=macOS,arch=$(uname -m)" \
  -derivedDataPath "$PWD/build/tests" \
  CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual \
  test
