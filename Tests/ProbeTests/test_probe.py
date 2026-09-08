import json
from pathlib import Path
import subprocess
import unittest


class ProbeProcessTests(unittest.TestCase):
    def test_appkit_dispatch_and_bounded_process_completion(self):
        probe = Path(__file__).resolve().parents[2] / '.build/debug/TrackpadProbe'
        result = subprocess.run([str(probe), '1', '--verify-dispatch'], capture_output=True, text=True, timeout=15, check=True)
        report = json.loads(result.stdout)
        self.assertIs(report.get('dispatchSelfTest'), True)
        self.assertIs(report.get('hidOpenAttempted'), report['inputMonitoring'])
        if not report['hidOpenAttempted']:
            self.assertNotIn('hidOpenStatus', report)
        else:
            self.assertIsInstance(report['hidOpenStatus'], int)
        self.assertEqual(report['counts'].get('local.15'), 1)
        self.assertGreaterEqual(report['durationSeconds'], 1)
        self.assertLess(report['durationSeconds'], 10)
        self.assertNotIn('serial', result.stdout.lower())
        self.assertNotIn('keycode', result.stdout.lower())


if __name__ == '__main__':
    unittest.main()
