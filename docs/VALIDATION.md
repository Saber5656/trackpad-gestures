# Validation and acceptance coverage

Status: local prototype verified; full USB MVP acceptance remains open. This file records observed results, never converts untested hardware into a pass.

## Matrix

| Requirement | Automated evidence | Manual / unavailable evidence |
|---|---|---|
| Recognized/rejected/cancelled/ambiguous | Core replay fixtures and deterministic tests | Wired physical gesture corpus pending |
| ID churn/timestamp disorder/malformed/boundaries | Seeded fuzz/property and regression tests | Real report-loss injection pending |
| Pointer/scroll/click/pinch false triggers | No synthesis; recognizer rejects interference; synthetic tests | Ordinary physical workflows in other apps untested |
| Permission denied/granted/revoked/changed | PermissionSnapshot + CaptureLifecycle cancellation tests | Host preflight true, real TCC prompts/revocation untested |
| Disconnect/sleep/resume/lock/unlock | Cancellation and explicit restart unit tests; public NSWorkspace notifications | Physical transitions untested |
| Crash/forced termination | No synthesized held input exists; process test reported below when run | Native coexistence during device failure untested |
| Config roundtrip/migration/unknown/executable | Strict codec tests; app import disables definitions and preserves unsupported actions | File panel UI checks recorded below |
| key-up/button-up | No key/button down API exposed; execution rejects keyboard action | Keyboard shortcuts are unsupported, not a tested release implementation |
| Bounded capture/logs | Recorder count/time bounds, diagnostic capacity tests | 30-minute physical soak untested |
| CPU/memory/latency | Probe `/usr/bin/time -l`; core synthetic measurement | End-to-end physical latency/event loss unknown |
| Clean build/test | Fresh SwiftPM scratch directory reported below when run | Other macOS/Intel/Windows targets untested |
| Secrets/personal paths | Source/docs scan and pre-commit diff check | No public upload |

## Test environment recovery

Default CLT `swift test` initially could not find XCTest. Full Xcode exists but license is unaccepted; no agreement was performed. Tests use Swift Testing from selected developer directory. `scripts/test.sh` adds framework and interop runtime search paths without changing machine settings. A missing Fixtures folder and overlapping SwiftPM builds caused temporary build failures; initial failing logs remain in private evidence.

Core/schema and app import behavior use failing tests before fixes. The exploratory M-00 probe was executable research rather than a TDD feature. Initial local-view/UI scaffolding was built before complete integration tests; those areas are subsequently verified with focused unit and GUI checks rather than misreported as uniformly red-first development. No claim is made that source inspection proves physical native input coexistence.

## Local results

- `scripts/test.sh`: **45 tests / 11 suites passed**. Includes real disk fixture replay, 2–5 finger tap/hold/all swipe directions, native interference, malformed/phase/timestamp recovery, cooldown, strict codec, permissions/lifecycle, record/file bounds and app model.
- Seeded property exercise: 1,000 streams × 12 frames through two engines with reversed definition order; identical outputs and no duplicate winner in the bounded test sequence.
- `python3 -m unittest discover -s Tests/PackagingTests`: **1 test passed**; no stale files enter a rebuilt app.
- Clean source copy: no `.env`, `.build`, profiles or Git metadata copied; process environment cleared except standard tool/home/temp paths. Initial clean build/test passed 39 tests; updated final source passed all **45** in this isolated workspace. This is a clean build on the same host, not another physical Mac or a pristine OS install.
- `scripts/package.sh`: release app built successfully. Bundle allocation **1,440 KiB**. Executable SHA-256 `a67633dd8b58ba3f8c99753ec36a9d3a67618c558849e2a040cebe33748180a7`.
- Synthetic core measurement: 3,000 two-frame sequences all recognized. Final main test run p50 **21.63 µs**, p95 **58.13 µs**, max **856.88 µs**. Concurrent clean-workspace run p50 36.04 µs, p95 62.08 µs, max 6,877.25 µs. Scheduling/tooling noise is included; these are not physical input latency or real-time guarantees.
- GUI: initial window visibly rendered; three-finger tap preview recognized; disabled gesture rejected; re-enabled gesture saved; manual beep dispatched; JSON exported and then imported through the file panel with all gestures disabled. No gesture preview executed an action.
- An early file-panel Go To automation attempt did not accept input. After restart, the exposed Open Finder item action completed the import; this was retained as a failed-then-recovered GUI attempt rather than a passed first attempt.
- Owned app was force-terminated with SIGKILL, restarted, and restored its local profile. Normal Command-Q then restart also succeeded. No key/button injection exists; physical native input during termination was not observed.
- After the final two core regression fixes, the release bundle rebuilt and Launch Services accepted a restart. Final screenshot reinspection was unavailable because the Mac was locked; the GUI observations above were made before those two pure-core fixes.
- GUI preflight states: Input Monitoring not granted, Accessibility not trusted. Local UI remained usable. CLI probe inherited granted/trusted state; this does not transfer to app identity.
- Source/docs privacy scan: no personal home paths or secret-like values; JSON syntax and local Markdown links checked. No signing command, notarization, push, remote repo creation or publication executed.

Raw logs remain in private development context. Reproduction: `scripts/test.sh`; `python3 -m unittest discover -s Tests/PackagingTests`; `scripts/package.sh`; `swift run TrackpadProbe 12`.
