# Trackpad Gestures

A macOS-first, local gesture studio for Magic Trackpad. Planned cross-platform OSS; **unpublished, license undecided**.

**Current build: simulation-only MVP prototype with experimental AppKit view-local preview.** It does not yet recognize global USB Magic Trackpad gestures or run actions from real gestures. A connected Magic Trackpad reports USB transport. On 2026-09-12 the operator confirmed three physical contacts displayed in the app-local preview; full physical gesture recognition and global capture remain unverified. Earlier Bluetooth observation is outside the formal MVP transport.

## Use locally

Requires macOS 15.1+ and Swift 6 tooling; tested on macOS 26.6.2 arm64 with Swift 6.3.2.

```sh
scripts/test.sh
scripts/package.sh
open dist/TrackpadGestures.app
```

1. Select or create a gesture. Set 2–5 fingers, trigger, direction, start zone, movement/time limits, modifiers, application scope, priority and cooldown.
2. Preview synthetic input. Recognition is evaluated on release; hold is a duration-qualified release. No preview dispatches an action.
3. Save a definition; enabled/disabled applies to preview recognition. Potential overlaps and global capture limitations remain visible.
4. Test an action explicitly: beep, HTTP(S) URL, app launch/focus/hide, or a named existing Apple Shortcut. Handler dispatch is not proof the requested operation completed. Keyboard shortcuts are unsupported until a safe forced-termination design is proven.
5. Import/export JSON. Unknown/executable fields are rejected, imports are data only and all imported gestures start disabled. Profiles are stored under the current user's Application Support / TrackpadGestures directory. Exported URLs may contain your own data; application diagnostics never include URL payloads.
6. Experimental Local preview receives public `NSTouch` callbacks only over its view. Start a bounded 30-second preview; Record 3s waits up to 10 seconds for a fresh touch, then records every observed AppKit touch observation in the first contact sequence. It freezes immediately when a contact is `cancelled`, or when all observed IDs reach `ended`; empty snapshots and missing IDs do not invent an `ended` phase. An inconsistent frame is retained for diagnosis and freezes with `invalidSequence`, while the 3-second/180-sample limit remains. Export also freezes the sample, so movement after any freeze is not appended. Lift all fingers before beginning; export is explicit and must be opened before the 30-second preview expires. The live contact view may continue updating independently. This records delivered local touch observations only, not every physical motion, raw HID report or global input. Transport/model attribution, pressure and area are not invented. This experimental adapter requests resting touches and records the OS-reported resting flag; physical hold behavior with this setting remains unverified. Repeated phase callbacks for the same event produce one observation.

No private API, root, kernel extension, SIP change, protocol write, downloaded plugin, arbitrary shell or telemetry is used. Input Monitoring and Accessibility are explained separately. This build does not request them automatically, suppress native events or synthesize keys/buttons.

## Probe and evidence

```sh
swift run TrackpadProbe 12
```

The probe compares AppKit monitors, listen-only session CGEventTap and non-seizing IOHIDManager callbacks. Output is allowlisted metadata, bounded public HID descriptor samples and counters, not raw touch/key/report payloads. It never requests new permissions. Success creating a tap is not global gesture feasibility.

- [M-00 evidence and hardware procedure](docs/M-00-feasibility.md)
- [v1 requirements](docs/REQUIREMENTS.md) and [design](docs/DESIGN.md)
- [Versioned data contracts](docs/CONFIGURATION.md)
- [Architecture ADR](docs/ADR-001-architecture.md)
- [Official-source research and competition](docs/research.md)
- [Issue plan and dependency DAG](docs/ISSUE_PLAN.md)
- [Validation and coverage](docs/VALIDATION.md)
- [Review findings](docs/REVIEW.md)

Future: complete unlocked USB-C reference input verification, choose a global capture/distribution approach if public APIs are insufficient, then Windows 11 x64 USB, then Bluetooth on both platforms. Windows 10/ARM64, one-finger customization, ML/drawing/chains and haptics are not initial targets.

No OSS license is implied. Publication, license selection, Developer ID signing and notarization require a separate decision. The package script does not invoke signing/notarization; Apple Silicon linker-generated local ad-hoc signatures are not Developer ID signatures.

Optional `.env` roots support private development records only; builds require no personal absolute paths, keys or accounts. See `.env.example`.
