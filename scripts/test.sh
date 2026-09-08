#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
# CLT ships Swift Testing but does not put its framework on swift test's search path.
DEVELOPER_ROOT="$(xcode-select -p)"
DEVELOPER_FRAMEWORKS="$DEVELOPER_ROOT/Library/Developer/Frameworks"
if [ -d "$DEVELOPER_ROOT/Platforms/MacOSX.platform/Developer/Library/Frameworks" ]; then
    DEVELOPER_FRAMEWORKS="$DEVELOPER_ROOT/Platforms/MacOSX.platform/Developer/Library/Frameworks"
fi
exec swift test --disable-xctest -Xswiftc -F -Xswiftc "$DEVELOPER_FRAMEWORKS" -Xlinker -rpath -Xlinker "$DEVELOPER_FRAMEWORKS" -Xlinker -rpath -Xlinker "$DEVELOPER_FRAMEWORKS/../usr/lib" "$@"
