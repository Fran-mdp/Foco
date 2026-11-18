#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
FOCO_TEST_DIR="$(mktemp -d "${TMPDIR:-/private/tmp}/foco-tests.XXXXXX")"
FOCO_TEST_BINARY="$FOCO_TEST_DIR/tests"
FOCO_CACHE="$(cd .. && pwd)/.build/module-cache"
mkdir -p "$FOCO_CACHE"
trap 'rm -rf "$FOCO_TEST_DIR"' EXIT
xcrun swiftc -swift-version 5 -parse-as-library -module-cache-path "$FOCO_CACHE" Sources/Achievements.swift Sources/Core.swift Sources/BlockingRules.swift Tests/CoreTests.swift -o "$FOCO_TEST_BINARY"
"$FOCO_TEST_BINARY"
node Tests/ExtensionTests.cjs
node Tests/WorkerStateTests.cjs
xcrun swiftc -swift-version 5 -parse-as-library -module-cache-path "$FOCO_CACHE" Sources/Achievements.swift Sources/Core.swift Sources/BlockingRules.swift Sources/Metrics.swift Tests/MetricsTests.swift -o "$FOCO_TEST_BINARY"
"$FOCO_TEST_BINARY"

xcrun swiftc -swift-version 5 -parse-as-library -module-cache-path "$FOCO_CACHE" Sources/Achievements.swift Sources/Core.swift Sources/BlockingRules.swift Tests/BlockingRulesTests.swift -o "$FOCO_TEST_BINARY"
"$FOCO_TEST_BINARY"
xcrun swiftc -swift-version 5 -D TESTING -parse-as-library -module-cache-path "$FOCO_CACHE" Sources/Achievements.swift Sources/Core.swift Sources/BlockingRules.swift Sources/AppBlocker.swift Sources/NativeHost.swift -o "$FOCO_TEST_BINARY"
python3 Tests/NativeHostTests.py "$FOCO_TEST_BINARY"

xcrun swiftc -swift-version 5 -D RENDERING -parse-as-library -module-cache-path "$FOCO_CACHE" Sources/Achievements.swift Sources/Core.swift Sources/BlockingRules.swift Sources/AppBlocker.swift Sources/Metrics.swift Sources/Dashboard.swift Sources/AchievementsView.swift Sources/TasksView.swift Sources/BlockEditor.swift Sources/ApplicationPicker.swift Sources/FocoApp.swift Tests/UndoNoticeTests.swift -o "$FOCO_TEST_BINARY"
"$FOCO_TEST_BINARY"

xcrun swiftc -swift-version 5 -parse-as-library -module-cache-path "$FOCO_CACHE" Sources/Achievements.swift Sources/Core.swift Sources/BlockingRules.swift Sources/Metrics.swift Tests/TasksTests.swift -o "$FOCO_TEST_BINARY"
"$FOCO_TEST_BINARY"

xcrun swiftc -swift-version 5 -parse-as-library -module-cache-path "$FOCO_CACHE" Sources/Achievements.swift Sources/Core.swift Sources/BlockingRules.swift Tests/AchievementsTests.swift -o "$FOCO_TEST_BINARY"
"$FOCO_TEST_BINARY"
