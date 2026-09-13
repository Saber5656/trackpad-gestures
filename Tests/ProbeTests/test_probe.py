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
        self.assertEqual(report['counts'].get('probe.runLoopSelfTest'), 1)
        self.assertIs(report.get('localMonitorCreated'), True)
        self.assertIsInstance(report.get('globalMonitorCreated'), bool)
        for key in ['sessionBefore', 'sessionAfter']:
            session = report.get(key)
            self.assertIsInstance(session, dict)
            self.assertIsInstance(session['available'], bool)
            self.assertTrue(set(session).issubset({'available', 'onConsole', 'loginDone'}))
            for flag in set(session) - {'available'}:
                self.assertIsInstance(session[flag], bool)
        for key in ['eventTapEnabledBefore', 'eventTapEnabledAfter']:
            if report['eventTapCreated']:
                self.assertIsInstance(report.get(key), bool)
            else:
                self.assertNotIn(key, report)
        if 'windowServerCounts' in report:
            self.assertEqual(set(report['windowServerCounts']), {'mouseMoved', 'leftMouseDown', 'leftMouseUp', 'scrollWheel'})
            self.assertTrue(all(isinstance(v, int) and v >= 0 for v in report['windowServerCounts'].values()))
        self.assertGreaterEqual(report['durationSeconds'], 1)
        self.assertLess(report['durationSeconds'], 10)
        self.assertNotIn('serial', result.stdout.lower())
        self.assertNotIn('keycode', result.stdout.lower())


if __name__ == '__main__':
    unittest.main()
