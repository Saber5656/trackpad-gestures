"""Build a fresh local bundle; retain previous generated output for recovery."""
from pathlib import Path
import os
import plistlib
import shutil
import sys
import tempfile


def package(binary: Path, destination: Path) -> Path:
    if not binary.is_file():
        raise ValueError("Build the application executable first")
    destination.mkdir(parents=True, exist_ok=True)
    stage = Path(tempfile.mkdtemp(prefix=".stage-", dir=destination))
    new = stage / "TrackpadGestures.app"
    (new / "Contents/MacOS").mkdir(parents=True)
    (new / "Contents/Resources").mkdir()
    shutil.copy2(binary, new / "Contents/MacOS/TrackpadGestures")
    info = {
        "CFBundleExecutable": "TrackpadGestures",
        "CFBundleIdentifier": "local.trackpad-gestures.studio",
        "CFBundleName": "Trackpad Gestures",
        "CFBundlePackageType": "APPL",
        "CFBundleShortVersionString": "0.1.0",
        "CFBundleVersion": "1",
        "LSMinimumSystemVersion": "15.1",
        "NSHighResolutionCapable": True,
    }
    (new / "Contents/Info.plist").write_bytes(plistlib.dumps(info))
    target = destination / "TrackpadGestures.app"
    previous = stage / "previous.app"
    if target.exists():
        os.rename(target, previous)
    try:
        os.rename(new, target)
    except OSError:
        if previous.exists():
            os.rename(previous, target)
        raise
    return target


if __name__ == "__main__":
    print("Local app:", package(Path(sys.argv[1]), Path(sys.argv[2])))
