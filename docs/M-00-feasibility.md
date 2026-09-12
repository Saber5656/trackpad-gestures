# M-00 — public API feasibility evidence

Status: **NOT PASSED / three-contact local display confirmed by operator; global recognition pending**. Updated 2026-09-12.
Initial observations below are preserved; see the USB follow-up for the current hardware state.
This is executable feasibility work, not certification of a global customizer.

## Environment and execution

- macOS 26.6.2, build 25G83, arm64. Swift 6.3.2, CLT selected.
- Xcode 26.6 / 17F113 installed but its license is not accepted. No license acceptance or machine configuration was performed. CLT builds work.
- Run `swift run TrackpadProbe 12`. Duration clamped to 1–60 seconds. JSON stdout is metadata/counters only. Raw report bytes, keycodes, serial, locations and URLs are not collected.
- Probe uses AppKit local + global monitors, session `CGEventTap` `.listenOnly`, and non-seizing `IOHIDManager` input-value callback. No feature/output report is sent.
- Initial USB VID-only discovery missed Bluetooth's Apple VID namespace. Corrected discovery matches both `0x05ac` and `0x004c`; independent IORegistry metadata check exposed the error. Preserve both probe runs in private evidence.
- Initial 12-second observation: input-monitoring and Accessibility preflights true in this host execution context, tap created, HID open returned success, zero observed events. This does not imply permission for a future signed app or successful contacts capture.
- Bluetooth Magic Trackpad observed: VID 0x004c, PID 0x0324, IOHID VersionNumber 793 (0x0319), primary usages page 0xFF00/18, 0xFF00/11, 1/2, 0xFF00/13. Firmware **unknown**: VersionNumber is not asserted to be firmware. Model generation is not inferred from PID alone.
- USB-C wired reference device not observed. Bluetooth is roadmap-only, not a supported capture backend.

## Documented API comparison

| Path | Available public contract | Missing/uncertain | Capture policy |
|---|---|---|---|
| AppKit responder touches | Local view touch identity, normalized position, phase, timestamp; modifiers from event | Global contacts, reliable physical transport/model binding, pressure/area | Opt-in view-local preview; transport unknown; no global actions |
| NSEvent local/global monitors | Delivered event kind, native gesture fields where applicable | Reliable contacts from gesture-event objects; finger count/device binding | Count-only probe; original local event returned unchanged |
| CGEventTap | Mouse/button/scroll/key event types in public headers | Per-finger trackpad contacts | Listen-only probe; no input injection or suppression |
| IOHIDManager | Public discovery and values/reports APIs | Documented Magic Trackpad multitouch field semantics; wired reference evidence | Enumerate and count usages; no decoder/feature writes |

See [official research](research.md) for citations. No private-framework implementation was inspected or copied.

## Pass criteria

| Criterion | Result |
|---|---|
| Global multi-finger tap/hold/directional swipe | Not demonstrated; no supported global contact adapter |
| Deterministic sequence processing | Synthetic fixtures only; see validation |
| Native pointer/click/scroll not suppressed or duplicated | Code path is observational, no posting or filter; physical coexistence untested |
| Exit/disconnect has no stuck synthetic key/button | No key/button synthesis implemented; lifecycle cancellation tests; physical transitions untested |
| Bounded capture/log | 30s live preview, at most 10 contacts; explicit 3s/180-sample recorder; 64 diagnostic entries, no general payload logger |
| Notarization and App Store | Not attempted; sandbox disabled, no entitlements requested, no approval implied |

Initial idle probe: 12.46s wall, 0.01s user + 0.03s system, 28,295,168 bytes peak RSS, 7,029,360 peak memory footprint (`/usr/bin/time -l`). These are idle process measurements, not input latency/CPU under load. Event loss and physical latency are **unknown** because there is no independent event source/count baseline. A zero count is not zero loss.

## Distribution decision, if wired probe also lacks required contacts

| Option | Value | Cost/limitations | Approval |
|---|---|---|---|
| Public APIs, narrower global vocabulary | Avoid undocumented framework dependency; preserve local visualizer and portable config | Does not meet arbitrary finger/zone global tap/hold promise; native gestures may be reserved; validate every supported combination | User must approve reducing the product vocabulary |
| Private API, notarized direct distribution candidate | Potential per-contact global stream, supported only after probe | OS update breakage, maintenance/provenance audit, no App Store assumption; notarization success not guaranteed | Explicit user approval before any implementation |

No option has been silently selected. This build is the independent simulation/local-preview work explicitly authorized when reference hardware is absent. The initial product goal remains open. Do not label native AppKit pinch/rotate or Bluetooth contact paths as formally supported gestures.

## Repeatable real-device procedure

1. Connect current USB-C Magic Trackpad by cable; disable Bluetooth only if the operator independently chooses to establish transport. Do not infer wired transport from a cable alone. Keep a separate mouse available.
2. Run metadata probe; record OS/build, architecture, VID/PID, advertised version, transport and permission preflights. Record firmware only from an authoritative exposed field, else unknown.
3. Build app with `scripts/package.sh`, open `dist/TrackpadGestures.app`, select Local preview, start and move pointer over the pad. Record whether 2/3/4/5 contacts show stable IDs, x/y and phases; no pressure/area expected without evidence.
4. Use opt-in Record 3s, execute one gesture, export sanitized fixture. Document source, device metadata, intended gesture and observed outcome. Never mark synthetic fixtures as hardware capture.
5. Repeat tap/hold/swipe, scroll/click/pinch/rotate while app is foreground, background and while manipulating another app. Use the count-only probe for global observation. View-local contacts are expected to stop outside the receiving view; no global support is inferred from native gesture counters.
6. Test disconnect/reconnect, sleep/resume, lock/unlock, permission deny/grant/revoke/change, app quit/crash/kill -9. Preview must cancel and require explicit restart; native mouse must continue. No action is armed by default or restored from imports.
7. Measure 30-minute idle/active usage externally; app capture itself expires after 30s and never persistently records raw touches. Measure CPU/RSS and known physical sequences versus observed counts. Only claim event loss/latency with a known reference clock and source count.
8. Save pass/fail/untested for every scenario, application identity category (no document names), and redacted counters. Signing/notarization/sandbox testing requires separate authorization.

## USB follow-up — 2026-09-08

The operator connected the trackpad to the Mac mini. Read-only discovery now reports **USB**, Apple VID **0x05ac**, PID **0x0324**, IOHID VersionNumber **1296 / 0x0510**. This is advertised metadata, not a verified firmware version or independent proof of USB-C model generation. Same host: macOS 26.6.2 (25G83), arm64.

The GUI control surface reports the Mac is locked. The operator was asked to unlock manually. No credentials were read, no lock bypass or security setting change was attempted. All observations in this follow-up were made before an operator-confirmed unlock or a physical gesture sequence. Zero event counters are **inconclusive**, not a global capture failure result.

Public `IOHIDDeviceCopyMatchingElements` / `IOHIDElementGet*` inventory:

| Primary usage page / usage | Returned elements | Standard Digitizer input elements (all returned elements) | Descriptor sample |
|---|---:|---:|---|
| 0x0001 / 2 | 1,407 | 0 | First 256; truncated explicitly |
| 0xFF00 / 11 | 35 | 0 | Complete |
| 0xFF00 / 13 | 9 | 0 | Complete |

The standard Digitizer summary counts input element types 1–4 with usage page 0x0d across the entire returned array, including elements outside the bounded sample. Enumeration failure is `available: false` with absent counts, not a fabricated successful empty inventory. At most 16 collections and 256 descriptor samples per collection are retained. `totalCollectionCount` and `collectionsTruncated` disclose omitted collections; final USB inventory contained 3 collections with no collection truncation. Samples contain static type/usage/report size/count/range/relative metadata only. No report bytes, current element values, serial or persistent device identity are saved.

Relative mouse X/Y, buttons, vendor-defined and battery-related declarations were observed. No standard per-contact declaration was found in these exposed collections. This supports an **unverified/unsupported public HID contact adapter**, not a conclusion that vendor packets can never carry contacts. No vendor decoder or feature/output write was introduced.

An independent-process regression showed that the old bare `RunLoop.run` path did not dispatch an app-local AppKit sentinel. The probe now uses `NSApplication.nextEvent` / `sendEvent` while servicing the run loop. `--verify-dispatch` posts one process-local application-defined sentinel for diagnostic testing; it does not synthesize mouse/key input and is never physical evidence. Normal probes post no events. The old path failed the sentinel test; the corrected path passed. An attempted in-process Swift Testing/AppKit test interfered with runner completion; its exit status was not accepted as a pass and the test was replaced with the isolated-process test.

Corrected 8-second locked observation: JSON duration 8.013s; process 8.57s wall, 0.10s user + 0.03s system, peak RSS 37,421,056 bytes, peak footprint 12,092,016 bytes. Permission preflights remained true for the CLI, tap created, HID open succeeded; event counts were empty. Descriptor enumeration is included in process cost. End-to-end latency/event loss and unlocked coexistence remain unknown.

Next: operator unlock, then foreground view-local tap/hold/swipe with explicit 3-second fixture extraction; background/other-app count comparison and native scroll/click/pinch checks. Do not choose private API distribution or shrink the product vocabulary based on locked idle data.

References: [Apple IOHIDDevice public API](https://developer.apple.com/documentation/iokit/iohiddevice_h_user-space), [Apple event monitoring](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/EventOverview/MonitoringEvents/MonitoringEvents.html), [Apple NSApplication event dispatch](https://developer.apple.com/documentation/appkit/nsapplication/sendevent(_:)). Local SDK `IOHIDElement.h` and `IOHIDUsageTables.h` were also inspected; no implementation was copied.

## First physical local-contact confirmation — 2026-09-12

The operator followed the local-preview procedure and reported that placing three fingers displayed three contact points. This is **operator-confirmed physical three-contact display inside the app's receiving view**. A subsequent GUI read showed USB Magic Trackpad metadata (0x05ac / 0x0324), Local preview selected, and a nonzero last-frame core timing. The contacts had already ended; no screenshot or raw fixture of the active three-contact state was obtained by the agent.

This confirms the view-local public AppKit path can deliver enough contact information for three displayed points in this setup. It does not certify coordinate accuracy, stable identity across transitions, complete phase delivery, resting fingers, global background capture, or tap/hold/swipe recognition. The last UI status was a native-click cancellation, so finger display is specifically separated from gesture recognition. The 2026-09-08 OS/build metadata has not been remeasured during this operator report.

A separate three-finger hold definition was prepared in the local profile (release after 0.6–2 seconds; movement at most 0.06; no modifiers/scope restriction; preview only). The original tap definition was preserved. Next requested sample: explicit Record 3s, lightly hold three fingers for about 1 second without clicking, release, and open Export sample before the 30-second preview expires. The agent handles the save panel and replay analysis after the operator performs physical contact. No sample has yet been captured/exported for this confirmation.
