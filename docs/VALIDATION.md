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

## USB follow-up validation

- Swift tests: **50 tests / 12 suites passed**, including descriptor/collection bounds, unavailable enumeration, standard input-vs-feature distinction, and full descriptor summary outside the retained sample. Initial follow-up had 49 tests; the final review added collection-limit coverage.
- `swift build --product TrackpadProbe` and `python3 -m unittest discover -s Tests/ProbeTests`: **1 isolated-process test passed**. The same test failed with the old bare RunLoop implementation. Its application-defined sentinel tests AppKit dispatch only, not physical input capture.
- `probe-usb-final.json` was collected by the corrected probe with USB metadata and no raw values. The Mac remained locked; physical gestures, GUI preview and unlocked permission/lifecycle cases remain untested. Final source also passed **50 tests** in the isolated clean-source workspace; final release app rebuilt successfully. Packaging regression remains 1 pass. GUI relaunch/physical input were not rechecked while locked.

- Final collection-summary code initially failed Swift initialization checking. The failure was repaired before acceptance; clean tests and release build were repeated successfully. A process test that accidentally ran a stale binary after the failed build was excluded from acceptance, and rebuilt-binary testing passed. Failure/recovery logs are retained.

## Operator physical confirmation — 2026-09-12

- **Confirmed by operator:** three fingers displayed as three local contact points. Agent subsequently confirmed the app's USB metadata and Local preview selection; active contact screenshot/fixture is not available.
- **Still pending:** recognition of a complete physical tap/hold/swipe, timestamp/identity/coordinate corpus checks, background/other-app capture and native coexistence. A native-click cancellation message was visible, which must not be presented as successful hold recognition.
- A preview-only hold definition was prepared using the existing GUI; no source behavior changed. Documentation was self-reviewed for scope/provenance, local link validity and privacy. Prior 50-test/12-suite and build results are reused for unchanged code rather than rerun as supposed new hardware evidence.


## First saved sample and recorder repair — 2026-09-12

- The saved physical sample was found and parsed (1,221 bytes). It contains two start-phase frames and three distinct contacts, with no release. Independent replay returns `tracking` twice and emits zero gesture events. See [physical sample records](PHYSICAL-SAMPLES.md); this is an incomplete physical fixture, not successful hold recognition.
- TDD reproduced button-relative recording dropping a gesture that begins five seconds after pressing Record. The new bounded arming path preserves both began and ended frames for that case, rejects mid-sequence start, times out without contact after ten seconds, caps actual capture at three seconds/180 frames, and freezes export with schema-v2 timing metadata.
- Final `scripts/test.sh`: **56 tests / 15 suites passed**. Fresh source copy with no `.env`, `.build`, Git metadata or profiles, and a minimal process environment, also passed all **56**. This is isolation on the same Mac, not another physical machine.
- Release packaging succeeded and the packaging regression passed (1 Python test). The app was normally quit/restarted; existing tap/hold definitions restored; the new waiting-for-first-contact status was visibly confirmed. The preview was then stopped, leaving the hold definition and Local preview selected.
- No physical sample from the repaired recorder has been obtained yet. Its benefit is established by automated timing regression and UI state, not by claiming a second physical run.
