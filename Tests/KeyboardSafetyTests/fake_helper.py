"""Fake modifier-key helper used only for failure-injection timing experiments.

This process never touches real OS input (no CGEvent, no Quartz, no HID).
It only appends timestamped markers to a log file to model the "DOWN"/"UP"
CGEvent posts of a hypothetical modifier-key press/release pair, using a pipe
file descriptor as a synchronization gate instead of a fixed sleep:

  1. Block reading `gate_fd` until at least one byte arrives (the "trigger"),
     then write DOWN.
  2. Block reading `gate_fd` again until it reports EOF (every writer of the
     pipe has closed its end), then write UP.

A parent test controls exactly when DOWN and UP become possible by writing
the trigger byte and/or closing its copies of the pipe, and can kill this
process at a precise point in step 1 or step 2 without relying on wall-clock
timing to "land" the kill inside a race window.
"""
import argparse
import os
import sys
import time


def _read_until(fd: int, want_eof: bool) -> None:
    while True:
        chunk = os.read(fd, 1)
        if chunk == b"" :
            return
        if not want_eof:
            return


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("log_path")
    parser.add_argument("gate_fd", type=int)
    args = parser.parse_args()

    with open(args.log_path, "a", buffering=1) as log:
        _read_until(args.gate_fd, want_eof=False)
        log.write(f"DOWN {time.time()}\n")
        log.flush()
        _read_until(args.gate_fd, want_eof=True)
        log.write(f"UP {time.time()}\n")
        log.flush()
    return 0


if __name__ == "__main__":
    sys.exit(main())
