# Public input diagnostic follow-up — 2026-09-13

The operator explicitly confirmed performing the requested Finder pointer movement,
three three-finger taps and approximately one-second hold. The earlier 60-second CLI
report still contains zero callbacks. Preserve both facts; do not reinterpret the
operator's confirmation or claim that zero demonstrates a public-API limitation.

## Evidence and unresolved cause

- The 60-second report had Input Monitoring and Accessibility preflight true, a
  created listen-only session tap and successful non-seizing IOHID open. These are
  setup observations, not successful event delivery.
- Later, separate diagnostic windows showed console-session booleans and enabled
  tap endpoints. They cannot establish the earlier window's session continuity or
  continuous tap health. A local AppKit sentinel and common-mode timer passed in
  the CLI process; neither is a physical-input positive control.
- CUA blank-Finder operations also produced zero counts. CUA can operate a hidden
  app through accessibility, so those operations do not prove physical event
  delivery to this monitor.
- The packaged GUI app reports Input Monitoring **not granted** and Accessibility
  **not trusted**, while the CLI reports granted/trusted. Permissions belong to
  their execution contexts; the CLI result cannot be applied to the GUI app.
- No explicit defect causing all counters to stay zero was established by the
  code audit. The manual AppKit loop, activation policy, execution context and
  capture window remain unverified hypotheses. No probability ranking is justified.
- Merely resting three fingers for a hold is not a mouse-button press. Absence of
  `leftMouseDown` does not reject the operator's hold. Absence of a dedicated
  three-finger event enum does not prove that all public paths lack contact data.

## Implemented next control

The GUI now has an explicit **30秒の入力診断を開始** button. Its normal NSApplication
event loop observes local/global NSEvent mouse/scroll/gesture event kinds and, only
when preflight allows it, a listen-only CG session tap. Local events are returned
unchanged. It captures no keys, coordinates, raw touches, HID payloads or app names;
it never injects or suppresses input and never requests permission automatically.

The diagnostic holds a fixed vocabulary of 12 counters (each capped at one million),
rejects events at/after 30 seconds and freezes on completion/cancel/lifecycle change.
It saves one latest count-only JSON report in the app's Application Support directory.
Each run has a new random check ID, wall-clock bounds, monotonic duration, registration
and permission endpoints, bounded main-run-loop tick counts and coarse own-app-active
samples. The channels can overlap: do not sum them. Session counter deltas have no
device attribution, physical-origin or loss guarantee. A save failure is visible.

The CLI also gains wall-clock endpoints. Those aid correlation; monotonic duration
remains authoritative if wall time changes. Historic reports are not rewritten.

## Physical control procedure and expected interpretation

1. With the app open, the operator presses the diagnostic start button. This makes
   the beginning of the window directly visible. No time estimate or export step
   is required from the operator.
2. Move the pointer over the app, switch to Finder, then move its pointer. These are
   the positive-control operations; taps/holds can be assessed only after a capture
   path is shown to receive ordinary input.
3. Wait for automatic completion. The parent reads the new check ID/report and
   interprets each route together with its actual permission state. If the GUI
   lacks Input Monitoring, granting it in macOS settings is a separate operator
   step before the CG route can be evaluated; Accessibility is not requested.
4. Nonzero ordinary-input counts establish only delivery on that route during the
   check. They do not certify global contacts, three-finger recognition or USB
   attribution. All-zero counts with a confirmed in-app control remain a diagnostic
   failure to investigate, not authorization for private APIs.

Normal stop removes monitors, run-loop source and tap. Sleep/lock, device-list
change, permission change and normal app exit save an interrupted result and stop.
Force-kill may prevent saving; there is no input injection or held output state to
release. No automatic restart is performed. Actual hardware lifecycle and native
coexistence tests remain pending.

## Primary references

- [Apple event monitoring](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/EventOverview/MonitoringEvents/MonitoringEvents.html):
  local/global scope, main-thread handlers, removal and event forwarding.
- [Global event monitor](https://developer.apple.com/documentation/appkit/nsevent/addglobalmonitorforevents(matching:handler:)):
  copies for other apps; observation does not prevent original delivery.
- [CGEvent tap creation](https://developer.apple.com/documentation/coregraphics/cgevent/tapcreate(tap:place:options:eventsofinterest:callback:userinfo:)):
  callback/run-loop-source setup. A created source is not a receipt of events.
- [Prohibited activation policy](https://developer.apple.com/documentation/appkit/nsapplication/activationpolicy-swift.enum/prohibited):
  activation/window restrictions do not by themselves settle monitor delivery.

No private API, new entitlement, root, kernel extension, signing, notarization,
permission grant or publication was performed. The public/private distribution
decision remains pending evidence and the operator's explicit choice.
