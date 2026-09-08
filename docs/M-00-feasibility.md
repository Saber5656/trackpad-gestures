# M-00 — public API feasibility evidence

Status: **NOT PASSED / USB reference hardware unavailable**. 2026-09-08.
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
