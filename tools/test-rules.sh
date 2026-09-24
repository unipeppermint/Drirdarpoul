#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
BUILD_DIR=$(mktemp -d /tmp/card-trace-rules.XXXXXX)
trap 'rm -rf "$BUILD_DIR"' EXIT
mkdir -p "$BUILD_DIR/module-cache"
xcrun swiftc -swift-version 5 -O -module-cache-path "$BUILD_DIR/module-cache" \
    "$ROOT/Drirdarpoul/Core/Models.swift" \
    "$ROOT/Drirdarpoul/Core/GameSession.swift" \
    "$ROOT/Drirdarpoul/Core/RuleEngine.swift" \
    "$ROOT/Drirdarpoul/Core/SolutionCounter.swift" \
    "$ROOT/Tests/RulesTests.swift" -o "$BUILD_DIR/rules-tests"
"$BUILD_DIR/rules-tests" "$@"
