"""Fake "main app" process used only to model whether a separate helper
process's pending key-up survives a SIGKILL of the main app process.

This process holds the write end of a pipe open (`write_fd`), writes a single
trigger byte to release the helper's DOWN, and then idles until it is killed;
when it dies, the OS closes `write_fd` for it, which is what lets an
independent helper (holding the read end) observe EOF and proceed to UP. No
OS input is generated anywhere in this experiment.
"""
import os
import sys
import time


def main() -> int:
    write_fd = int(sys.argv[1])
    os.write(write_fd, b"D")
    while True:
        time.sleep(0.05)


if __name__ == "__main__":
    sys.exit(main())
