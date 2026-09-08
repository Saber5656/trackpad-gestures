import importlib.util
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location("package_bundle", Path(__file__).parents[2] / "scripts/package_bundle.py")
package = importlib.util.module_from_spec(spec)
spec.loader.exec_module(package)

class PackagingTests(unittest.TestCase):
    def test_rebuild_replaces_stale_contents_and_preserves_backup(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp)
            binary=root/"binary"; binary.write_bytes(b"local build")
            destination=root/"dist"
            app=package.package(binary,destination)
            (app/"Contents/Resources/stale.txt").write_text("old")
            next_app=package.package(binary,destination)
            self.assertFalse((next_app/"Contents/Resources/stale.txt").exists())
            self.assertEqual((next_app/"Contents/MacOS/TrackpadGestures").read_bytes(), b"local build")
            self.assertEqual(len(list(destination.glob(".stage-*/previous.app/Contents/Resources/stale.txt"))),1)

if __name__=="__main__": unittest.main()
