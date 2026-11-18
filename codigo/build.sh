#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
FOCO_DEST="$(cd .. && pwd)"
FOCO_CACHE="$FOCO_DEST/.build/module-cache"
FOCO_STAGE="$(mktemp -d /private/tmp/foco-package.XXXXXX)"
trap 'rm -rf "$FOCO_STAGE"' EXIT
FOCO_BUNDLE="$FOCO_STAGE/Foco.app"
mkdir -p "$FOCO_CACHE" "$FOCO_BUNDLE/Contents/MacOS" "$FOCO_BUNDLE/Contents/Resources"
xcrun swiftc -swift-version 5 -O -parse-as-library -target arm64-apple-macosx26.0 -module-cache-path "$FOCO_CACHE" Sources/Goals.swift Sources/Achievements.swift Sources/Core.swift Sources/BlockingRules.swift Sources/AppBlocker.swift Sources/NativeHost.swift -o "$FOCO_BUNDLE/Contents/MacOS/FocoBridge"
xcrun swiftc -swift-version 5 -O -parse-as-library -target arm64-apple-macosx26.0 -module-cache-path "$FOCO_CACHE" Sources/Goals.swift Sources/Achievements.swift Sources/Core.swift Sources/BlockingRules.swift Sources/AppBlocker.swift Sources/Metrics.swift Sources/Dashboard.swift Sources/GoalsView.swift Sources/AchievementsView.swift Sources/TasksView.swift Sources/BlockEditor.swift Sources/ApplicationPicker.swift Sources/FocoApp.swift -o "$FOCO_BUNDLE/Contents/MacOS/Foco"
cp Resources/Info.plist "$FOCO_BUNDLE/Contents/Info.plist"
if [ -f Resources/Foco.icns ]; then cp Resources/Foco.icns "$FOCO_BUNDLE/Contents/Resources/"; fi
mkdir -p "$FOCO_DEST/Extension-Chrome"
cp Extension/* "$FOCO_DEST/Extension-Chrome/"
mkdir -p "$FOCO_BUNDLE/Contents/Resources/Extension-Chrome"
cp Extension/* "$FOCO_BUNDLE/Contents/Resources/Extension-Chrome/"
xattr -cr "$FOCO_BUNDLE"
codesign --force --sign - "$FOCO_BUNDLE/Contents/MacOS/FocoBridge"
codesign --force --sign - "$FOCO_BUNDLE"
codesign --verify --deep --strict "$FOCO_BUNDLE"
ditto -c -k --keepParent --norsrc --noextattr "$FOCO_BUNDLE" "$FOCO_DEST/Foco-Mac.zip"
# Replace only the generated bundle. User data lives outside it.
python3 - "$FOCO_DEST/Foco.app" <<'PYINNER'
from pathlib import Path
import sys,shutil,plistlib
p=Path(sys.argv[1])
if p.is_symlink():
    raise SystemExit('Refusing to replace a symlink at the output app path')
if p.exists():
    info=plistlib.loads((p/'Contents/Info.plist').read_bytes())
    if info.get('CFBundleIdentifier') not in ['local.francisco.Foco', 'local.foco.Foco']:
        raise SystemExit('Refusing to replace an unrelated application')
    shutil.rmtree(p)
PYINNER
ditto --noextattr --norsrc "$FOCO_BUNDLE" "$FOCO_DEST/Foco.app"
# iCloud may attach FinderInfo to a visible .app after copying it.
xattr -d com.apple.FinderInfo "$FOCO_DEST/Foco.app" 2>/dev/null || true
# The archive above is verified before export. iCloud can reattach FinderInfo
# to a visible app copy; install by extracting the clean ZIP in Applications.
echo "Foco compilado: $FOCO_DEST/Foco.app"
