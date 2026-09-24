#!/bin/sh
set -eu
TASK_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TASK_TMP=$(mktemp -d "${TMPDIR:-/tmp}/card-trace-session.XXXXXX")
trap 'rm -rf "$TASK_TMP"' EXIT HUP INT TERM
xcrun swiftc -swift-version 5 -module-cache-path "$TASK_TMP/module-cache" \
  "$TASK_ROOT/Drirdarpoul/Core/Models.swift" \
  "$TASK_ROOT/Drirdarpoul/Core/RuleEngine.swift" \
  "$TASK_ROOT/Drirdarpoul/Core/GameSession.swift" \
  "$TASK_ROOT/Drirdarpoul/Data/SaveRepository.swift" \
  "$TASK_ROOT/Drirdarpoul/Data/Settings.swift" \
  "$TASK_ROOT/Tests/SessionTests.swift" \
  -o "$TASK_TMP/session-tests"
"$TASK_TMP/session-tests" "$TASK_ROOT/Drirdarpoul/Data/levels.json"
