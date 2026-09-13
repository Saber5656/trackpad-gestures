"""Failure-injection experiments for the keyboard-shortcut key-up guarantee.

Scope and limits (see docs/ADR-002-keyboard-release-safety.md):
  * No CGEvent, no HID, no Quartz, no Accessibility API is touched here.
  * No real key or mouse input is ever generated or sent to the OS.
  * All processes here are throwaway Python helpers writing timestamped
    text markers ("DOWN"/"UP") to a private log file; "DOWN"/"UP" model the
    two CGEvent posts of a hypothetical modifier-key press/release pair,
    nothing more.
  * These experiments measure process/signal timing guarantees only. They
    do not, and cannot, prove anything about real macOS key-up delivery.
  * DOWN is released by a pipe trigger byte and UP is released by pipe EOF
    (every writer closing its end), not by a fixed sleep duration. A kill
    is issued only after the relevant marker is confirmed in the log, and
    a negative assertion ("UP never appears") is only made after the
    process that could have written it has been reaped (confirmed dead),
    never after a fixed wait-and-hope delay.
  * Each test run writes to a fresh temporary directory so it never
    overwrites or deletes log files from a previous run.

Each test is bounded in wall-clock time (for polling for markers that are
expected to appear) and reaps every process it directly spawned, and closes
every file descriptor it directly opened, before returning, whether the
scenario passed or failed.
"""
import os
import signal
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
HELPER = HERE / "fake_helper.py"
MAIN_HOLDER = HERE / "parent_wrapper.py"

POLL_TIMEOUT_SECONDS = 10.0
POLL_INTERVAL_SECONDS = 0.02
REAP_TIMEOUT_SECONDS = 5.0


def _wait_for_marker(log_path: Path, marker: str, timeout: float) -> bool:
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if log_path.exists() and marker in log_path.read_text():
            return True
        time.sleep(POLL_INTERVAL_SECONDS)
    return log_path.exists() and marker in log_path.read_text()


def _kill(pid: int) -> None:
    try:
        os.kill(pid, signal.SIGKILL)
    except ProcessLookupError:
        pass


def _reap(proc: subprocess.Popen, timeout: float = REAP_TIMEOUT_SECONDS) -> None:
    try:
        proc.wait(timeout=timeout)
    except subprocess.TimeoutExpired:
        _kill(proc.pid)
        proc.wait(timeout=timeout)


def _close(fd: int) -> None:
    try:
        os.close(fd)
    except OSError:
        pass


class KeyboardReleaseSafetyExperiments(unittest.TestCase):
    """Each test records observed guarantees, it does not assert a design is safe."""

    def setUp(self):
        self._tmpdir = tempfile.TemporaryDirectory(prefix="keyboard-safety-proof-")
        self.log_path = Path(self._tmpdir.name) / "log.txt"

    def tearDown(self):
        self._tmpdir.cleanup()

    def test_single_process_pair_killed_between_down_and_up_loses_the_up(self):
        # Models: CGEvent down/up posted in-process, no separate helper.
        # The test itself holds the gate pipe's write end: it releases DOWN
        # by writing a trigger byte, waits for the DOWN marker to actually
        # appear (not a fixed sleep), kills the process while it is blocked
        # waiting for EOF (which the test never sends), reaps it, and only
        # then checks for UP -- by that point the process is confirmed dead
        # and cannot write anything further.
        read_fd, write_fd = os.pipe()
        proc = None
        try:
            proc = subprocess.Popen(
                [sys.executable, str(HELPER), str(self.log_path), str(read_fd)],
                pass_fds=(read_fd,),
            )
            os.close(read_fd)
            read_fd = None
            os.write(write_fd, b"D")

            self.assertTrue(
                _wait_for_marker(self.log_path, "DOWN", POLL_TIMEOUT_SECONDS),
                "DOWN marker never appeared",
            )
            _kill(proc.pid)
            _reap(proc)

            contents = self.log_path.read_text()
            self.assertIn("DOWN", contents)
            self.assertNotIn("UP", contents, "SIGKILL mid-pair unexpectedly allowed the UP marker to be written")
        finally:
            if read_fd is not None:
                _close(read_fd)
            _close(write_fd)
            if proc is not None:
                _reap(proc)

    def test_independent_helper_survives_main_process_kill_and_still_emits_up(self):
        # Models: a separate helper process holds the down/up pair; only the
        # main app process is killed. The test owns both Popen objects
        # directly (no XPC/launchd involved): a "main" holder process holds
        # the pipe's write end and releases DOWN, and an independent helper
        # holds the read end. The test closes its own copies of both pipe
        # ends immediately after spawning, so the main holder is the only
        # remaining write-end holder; killing and reaping it is what
        # produces EOF for the helper, deterministically, not a race against
        # a sleep duration.
        read_fd, write_fd = os.pipe()
        main_proc = None
        helper_proc = None
        try:
            main_proc = subprocess.Popen(
                [sys.executable, str(MAIN_HOLDER), str(write_fd)],
                pass_fds=(write_fd,),
            )
            helper_proc = subprocess.Popen(
                [sys.executable, str(HELPER), str(self.log_path), str(read_fd)],
                pass_fds=(read_fd,),
            )
            os.close(read_fd)
            os.close(write_fd)
            read_fd = write_fd = None

            self.assertTrue(
                _wait_for_marker(self.log_path, "DOWN", POLL_TIMEOUT_SECONDS),
                "DOWN marker never appeared",
            )
            _kill(main_proc.pid)
            _reap(main_proc)

            self.assertTrue(
                _wait_for_marker(self.log_path, "UP", POLL_TIMEOUT_SECONDS),
                "helper failed to emit UP after only the main process was killed",
            )
        finally:
            if read_fd is not None:
                _close(read_fd)
            if write_fd is not None:
                _close(write_fd)
            if main_proc is not None:
                _reap(main_proc)
            if helper_proc is not None:
                _reap(helper_proc)

    def test_killing_the_helper_itself_still_loses_the_up(self):
        # Models: the same separate helper design, but this time the helper
        # process itself is what receives SIGKILL (e.g. a user killing "all
        # trackpad-gestures processes", or the OS terminating it under memory
        # pressure), while the main holder stays alive throughout. Confirms
        # a helper process is not, by itself, a guarantee: it only narrows
        # which kill target loses the up marker, it does not remove the
        # possibility. UP is only checked after the helper is reaped, so the
        # absence is a fact about a dead process, not a timing guess.
        read_fd, write_fd = os.pipe()
        main_proc = None
        helper_proc = None
        try:
            main_proc = subprocess.Popen(
                [sys.executable, str(MAIN_HOLDER), str(write_fd)],
                pass_fds=(write_fd,),
            )
            helper_proc = subprocess.Popen(
                [sys.executable, str(HELPER), str(self.log_path), str(read_fd)],
                pass_fds=(read_fd,),
            )
            os.close(read_fd)
            os.close(write_fd)
            read_fd = write_fd = None

            self.assertTrue(
                _wait_for_marker(self.log_path, "DOWN", POLL_TIMEOUT_SECONDS),
                "DOWN marker never appeared",
            )
            _kill(helper_proc.pid)
            _reap(helper_proc)

            contents = self.log_path.read_text()
            self.assertIn("DOWN", contents)
            self.assertNotIn("UP", contents, "killing the helper itself unexpectedly still produced an UP marker")
        finally:
            if read_fd is not None:
                _close(read_fd)
            if write_fd is not None:
                _close(write_fd)
            if helper_proc is not None:
                _reap(helper_proc)
            if main_proc is not None:
                _reap(main_proc)


if __name__ == "__main__":
    unittest.main()
