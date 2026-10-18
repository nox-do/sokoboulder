#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
xcrun swift-format format --in-place --recursive --parallel --configuration .swift-format \
  MacGameApp MacGameAppTests Packages/GameCore/Sources Packages/GameCore/Tests \
  Packages/GameCore/Package.swift scripts/generate-release-artwork.swift
