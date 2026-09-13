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

## Second saved sample / delivery repair — 2026-09-12

- New physical file: 16,918 bytes / 43 frames, span 1.7790116249816492 seconds, schema2, explicit export before its deadline. Core-only replay gives tracking×4, malformed×1, waitingForBoundary×38, zero events. GUI boundary recovery and native-interference context are not recorded by this replay. Full phase endpoints were observed; physical release timing/hold recognition remain unverified.
- Public AppKit test doubles reproduce a single event delivered to multiple touch callbacks and the resulting extra terminal ID. Red: 5 observations/4 IDs/no winning event; green: 4 observations/3 IDs/one synthetic tap. Distinct same-time event objects remain observable. Stop/restart resets state. Resting delivery/actual flag serialization and absent legacy fields have separate red→green assertions. These are adapter tests, not physical input.
- Final whole-package run: **61 tests / 16 suites passed**. A fresh source copy, no environment/profile/build/Git state, minimal process environment on the same Mac, also passed **61 / 16**. Historical fixtures remain unchanged.
- Release package build passed. The app was normally quit and restarted at the exact current bundle path; stored tap/hold definitions restored. The hold definition and Local preview are selected, stopped ready for another physical sample. No gesture was physically performed by the agent. Unchanged packaging-script tests were not rerun.
- Host remeasured: macOS **26.6.2 (25G83), arm64**. GUI still reports USB Magic Trackpad 0x05ac/0x0324 and unused/ungranted Input Monitoring/Accessibility. No OS permission changes were made. The revised resting-inclusive stream, full hold completion and native coexistence are pending.

## One-sequence sample boundary — 2026-09-13

- The operator described a three-finger tap followed by sliding to Export sample. The prior recorder appended every delivered local contact observation within its bounded window, so a later one-contact sequence could be included. It did not overwrite the earlier contact frames. The previous duplicate timestamp occurred earlier inside the three-contact portion; the later movement did not cause that error. The physical hold duration remains unreported.
- TDD: recorder regression initially appended the later pointer sequence; app-model regression saved three frames instead of two and reported an export-time finish. The repaired GUI arming path freezes after all tracked IDs end, after cancellation, or on an invalid sequence. Missing/empty frames do not invent a release, ID tracking is capped at ten, and rearming clears previous state. Explicit immediate recording retains its time-window behavior.
- Focused tests: **12 / 4 suites passed**. Whole package: **68 tests / 18 suites passed**. A fresh source copy/minimal environment on the same host also passed **68 / 18**. App-model replay confirms the live contacts can change while two saved gesture frames and repeated exported bytes remain unchanged.
- Release packaging passed. Normal app restart restored the existing tap/hold definitions. Local preview, the new `not recording`/`recording` footer and one-gesture arming guidance were verified through the GUI; the test preview was stopped. `frozen` state and unchanged export were verified by automated app-model tests; a physical recording with the revised boundary is still pending. No OS permission, input-injection or publication action was performed.

## Saved physical three-finger tap — 2026-09-13

- Saved file confirmed on disk: 5,151 bytes / 7 frames, source SHA-256 `cdacd7df1fd34545968f83a924fa968df3dfaebc37860cda5390dc0dc49a13ff`. All three observed contacts end, timestamp order is strict, resting flags are present/false, and the recorder freezes with `sequenceEnded` at its final frame. Subsequent save movement is absent. The save confirmation dialog was already closed when inspected.
- Exact fixture replay: **tracking ×6 → fired ×1, event IDs `[tap]`**. Both tap and hold definitions were enabled; no hold event or action execution occurred. The parent independently checked every source position, phase, relative timestamp and one-to-one identity mapping; original recording/resting metadata is preserved in a separate fixture envelope.
- Focused physical replay: **3 tests passed** (old incomplete, old malformed, new complete). Whole package: **69 tests / 18 suites passed**. Only fixture/tests/documentation changed, so the previously passing release build, clean-source build and app launch are reused; no executable change or new runtime build is claimed.
- Physical scope: local AppKit data was captured on the operator's Mac with a USB Magic Trackpad visible in discovery. Exact touch-to-USB attribution is still unknown in this adapter. Offline tap recognition is confirmed; live GUI recognition status, native gesture coexistence, hold/swipe, background/global capture and hardware lifecycle tests are not established by this file.


## Autonomous validation follow-up — 2026-09-13

- Saved physical observations now also replay through `capture.onObservation` and the actual AppModel recognition/preview/recorder path: one tap, seven frozen frames, no action-dispatch diagnostic. This remains replay, not live physical recognition or an instrumented OS-action test.
- Native click/scroll/pinch/rotate callbacks cancel that replay, and the next fresh sequence recovers. Ten identical replay sequences produce ten recognitions at one-second spacing and three at 0.2-second spacing. Cooldown eligibility is checked at sequence start; the initial expectation of four fast-tap recognitions was incorrect and corrected after checking the existing Core rule. The failed expectation is retained privately. These are characterization tests, with no product recognition behavior changed.
- `scripts/test.sh`: **72 tests / 19 suites passed**. The new AppModel suite has three tests with seven parameter cases in total.
- Probe diagnostics followed red-first tests for missing monitor/session health fields and missing run-loop self-test evidence. Rebuilt process self-test: **1 test passed**, including both an app-local event and a common-mode run-loop timer. Neither sentinel is physical or system input.
- Probe now exposes registration and tap-enabled states, an allowlist of three GUI-session booleans, and four aggregate window-server counter deltas. No session dictionary, usernames, event payloads or keyboard values are serialized. These deltas do not establish device attribution, event loss or a stable session across account switching.
- The initial eight-second preflight and a 60-second operator window had zero callbacks despite a created tap and successful HID open. At that checkpoint the operator had confirmed readiness; the later completion report is recorded below. Two separate CUA-generated blank-Finder click/drag checks also yielded zero callback counts; the diagnostic repeat also had zero aggregate deltas. CUA interaction is not physical hardware evidence, so this is not proof of public-API failure.
- Diagnostic snapshots report an available, logged-in console session and an enabled tap before/after. Device discovery still reports USB Magic Trackpad 0x05ac/0x0324. CLI preflight is granted/trusted; this does not grant or alter the app's permissions.
- Three isolated-process keyboard experiments passed using DOWN/UP file markers, synchronized pipes and owned child cleanup. See [keyboard safety](ADR-002-keyboard-release-safety.md). No keys/buttons were sent to the OS and injection stays unsupported.

Only the diagnostic executable changed at runtime. The GUI application sources and permissions are unchanged; the previous packaged-app launch evidence remains applicable. Physical completion, global contacts, hold/swipe and the full safety/coexistence matrix remain open.


- Final isolation check: a fresh source copy without `.env`, `.local`, profiles or prior `.build`, and an environment containing only the standard command path, passed **72 tests / 19 suites**. Release `TrackpadProbe` also built there successfully (58.23 seconds). This is the same Mac, not a second machine or pristine OS. GUI app sources are unchanged.
- Additional GUI handler checks: a launch request for the already-running Finder reported system-handler dispatch. The CUA connection closed before the response, so the parent read back the actual UI instead of blindly replaying the action. This is not a cold-start test. A subsequent Hide request displayed unavailable; a read-only `NSRunningApplication` query found Finder already hidden. Its pre-action hidden state was not recorded, so this does not establish the cause or a successful hide transition. The unavailability-versus-already-hidden distinction is recorded for action-layer follow-up. The saved tap definition was reselected to discard the unsaved action edits, and Finder's Raise action was used; readback reports no longer hidden (not active). Neither CUA interaction nor Raise proves physical event delivery. No profile save or permission change was made.


## User-confirmed operations and visible diagnostic — 2026-09-13

- The user explicitly confirmed the requested physical operations were performed. The preserved 60-second CLI file still has zero callbacks. This is unresolved capture evidence, not a rejected gesture or a public-API feasibility failure. See [audit](PUBLIC-INPUT-AUDIT.md).
- Added a native user-started 30-second count-only check with a visible countdown, automatic latest-report save, stop/cancel/lifecycle cleanup and per-channel optional counts. It has no raw touch stream, keystrokes, coordinates, automatic actions or permission prompts. The CG event-tap route is skipped when Input Monitoring is not granted.
- Red-first tests cover bounded counter vocabulary, deadline freezing, early cancellation, automatic save, permission changes, source cleanup, counter wrap, source distinction, failed save and rerun clearing. A missing-monitor regression keeps uncreated routes as unavailable instead of displaying zero.
- Direct `swift test` initially lacked the CLT Testing framework; the repository test script supplies the required framework paths. A C callback initially captured dynamic Self; replacing it with the concrete class fixed compilation. These failures are preserved privately.
- Release app build and normal restart passed; saved tap/hold definitions restored. A 30-second GUI idle check saved an actual report with 300 timer ticks, 149 background state samples, zero callbacks and zero aggregate deltas. Input Monitoring/Accessibility were false; the tap fields were absent. No physical control was requested for this idle test.
- Three process snapshots around this check showed approximately 10.0–10.8% CPU and 96,016–96,064 KiB RSS. These are coarse process samples, not incremental diagnostic overhead, a memory-growth test or physical latency/event-loss measurements. Performance acceptance remains pending.
- Parent source/UI review caught a first-draft zero display for an uncreated tap and corrected it using optional route availability; the saved JSON already kept tap availability absent. CLI clock endpoints were independently authored and are auxiliary; monotonic timing remains authoritative.

- Final `scripts/test.sh`: **79 tests / 21 suites passed**. Probe process test: **1 passed**. A fresh source copy without `.env`, `.local`, profiles or prior build output, run with only a standard command PATH, also passed **79 / 21** and built the release GUI app. This is the same Mac, not a second device or pristine OS.
- Separate Claude read-only review returned approve with no findings. Runtime/hardware checks were not rerun by the reviewer. No permission change, private API or input injection was introduced. The macOS Input Monitoring settings page listed only the pre-existing third-party entry, not Trackpad Gestures. The app needs its own user grant before this diagnostic's CG route can be physically evaluated.

- Final packaged binary matches the release executable byte for byte. Its new process restored existing profiles, started the diagnostic and saved an explicit cancelled report when stopped. The GUI displayed **OS側のポインター: 未取得** with an absent tap, verifying the corrected presentation. The app remains stopped/ready; no physical gesture is inferred from these GUI automation checks.
- macOS requested the operator's password when opening Add in Input Monitoring. The parent stopped at that authentication dialog and requested on-device entry. Authentication/permission grant is pending; no credential was read or entered by the agent.


## Permission grant and restart — 2026-09-13

- Operator completed macOS authentication. The exact tested local app was added to Input Monitoring and restarted using macOS Quit & Reopen. Settings shows its switch on, and the app itself reports granted. Accessibility remains not trusted. No credential was entered/read by the agent; no other app grant was changed.
- A short startup/cancel check saved duration **4.237 seconds**, **42 timer ticks**, both AppKit monitors created and an enabled CG listen-only tap at both endpoints. This establishes setup after the grant, not physical delivery; callback counts were zero in this non-physical control. App SHA-256 remains `76ddcf6aa37ae0e6cfd93aaa5f50dddbbab39c50dfd54a4e69ff86e2b5fd3f7d`.
- Source is unchanged; the previous 79 Swift tests / 21 suites, process test, clean-copy build and independent source review are reused. Documentation-only evidence updates have no executable behavior for TDD; parent reviewed the diff against the actual UI/report and checked personal-path/secret scope before commit. The physical in-app/Finder pointer control is now requested and pending.

## Operator-confirmed physical pointer control — 2026-09-13

The operator reported completion and a new 30-second completed report was found.
Local/global/CG pointer callbacks were **257 / 442 / 702**. Permission and tap
endpoints remained enabled, 67 foreground/82 background status samples were
recorded, and counters did not saturate. Schema, distinct check ID, completion,
duration, enabled endpoints, nonzero route counts and source SHA were checked
automatically. See [exact physical results and limits](PHYSICAL-INPUT-RESULTS.md).
This passes the ordinary-input positive control; multi-finger global recognition
and native gesture coexistence remain untested. No source change or additional
test/build success is claimed for this evidence-only update.


## 2026-09-13 — Gesture-field diagnostic integration

- Added exact AppKit gesture-type/touch-availability summaries and reference-USB
  usage-only HID observation; see [field semantics](GESTURE-FIELD-DIAGNOSTIC.md).
- Parent behavioral RED: three tests produced four failing assertions against
  the worker version (no-query maximum, oversized count/phase handling, lost
  digitizer total after dictionary truncation); reference matcher initially
  failed compilation until implemented. Corrected an SDK compile mismatch:
  `IOHIDElementGetDevice` returns a nonoptional device. Direct NSEvent doubles
  also verify the eligible-event guard and queried-empty-set distinction.
- Final main: **92 tests / 22 suites passed**. A fresh source-only copy without
  `.env`, profiles, build or Git metadata, and with a reduced process environment,
  passed the same **92 tests / 22 suites** and release app packaging. This is
  a same-host clean build, not an independent OS installation. Unchanged probe,
  packaging, keyboard no-input subprocess and core validation evidence is reused.
- The new release executable SHA-256 is
  `81c736f12b51a218f2cab90ad35c034067ab7feff5398b2a6a5ecf8330878baf`.
  Parent confirmed source equality with the clean-tested build, normally quit
  the previous app and packaged/launched the replacement at the same local path.
- After replacement, System Settings retained the app's Input Monitoring switch
  on, but the new app preflight returned false. A 4.164136624895036-second cancelled
  startup check (ID `5A87733D-6E36-4267-A730-8EBADB94E1FD`) saved successfully:
  AppKit monitor handles existed, dispatch ticks41, Accessibilityfalse,
  no CG tap, HID unavailable with `inputMonitoringNotGranted`, no invented HID
  event totals, no gesture detail. Counts were empty; no physical input was
  requested, so this is not a negative gesture trial. It confirms safe degradation.
- Refreshing the existing app permission reached macOS's password sheet. Operator
  authentication is pending; no credential was entered/read by the agent.
  This update-related permission continuity issue is a distribution limitation
  of the current development build. No signing, Apple Developer authentication,
  notarization, private API, HID mode change or publication was performed.
- Next physical tap/hold/swipe comparison is pending permission restoration and
  actual source-open preflight. The previously positive ordinary pointer report
  remains intact and is not overwritten by this setup check's evidence copy.

- New release idle smoke: ten one-second `ps` samples after the cancelled setup
  diagnostic reported CPU 0.0–0.1% and resident memory 69,584 KiB. These are
  bounded process estimates at idle, not physical-input latency/loss or load
  measurements. The current input-permission authentication sheet stayed open.
