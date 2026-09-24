#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
BUILD_DIR=$(mktemp -d /tmp/card-trace-content.XXXXXX)
trap 'rm -rf "$BUILD_DIR"' EXIT
mkdir -p "$BUILD_DIR/module-cache"
xcrun swiftc -swift-version 5 -O -module-cache-path "$BUILD_DIR/module-cache" \
    "$ROOT/Drirdarpoul/Core/Models.swift" \
    "$ROOT/Drirdarpoul/Core/RuleEngine.swift" \
    "$ROOT/Drirdarpoul/Core/SolutionCounter.swift" \
    "$ROOT/Drirdarpoul/Data/LevelRepository.swift" \
    "$ROOT/Tests/LevelValidation.swift" -o "$BUILD_DIR/validate-levels"
"$BUILD_DIR/validate-levels" "${1:-$ROOT/Drirdarpoul/Data/levels.json}"
