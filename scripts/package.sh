#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
swift build -c release --product TrackpadGestures
python3 scripts/package_bundle.py "$(swift build -c release --show-bin-path)/TrackpadGestures" dist
