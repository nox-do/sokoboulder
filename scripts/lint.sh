#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
xcrun swift-format lint --strict --recursive --parallel --configuration .swift-format \
  MacGameApp MacGameAppTests Packages/GameCore/Sources Packages/GameCore/Tests \
  Packages/GameCore/Package.swift scripts/generate-release-artwork.swift
