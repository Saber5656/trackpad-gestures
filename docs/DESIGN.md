# Design

## Product contract

A local-only, gesture-first editor with portable versioned data, explainable winner selection, capability visibility, opt-in preview and threshold/cooldown controls. Formal global USB gesture support is pending M-00. This local build offers simulation and experimental view-local capture with manual safe-action testing. No telemetry, remote backend, plug-in loader, embedded execution language or arbitrary shell facility exists.

## Boundaries

- `TrackpadCore`: immutable normalized frames, strict config codec, state machine and deterministic conflict analysis. Foundation only. No OS event APIs.
- `MacPlatform`: metadata allowlist, local AppKit capture behind `CaptureAdapter`, permissions, cancel lifecycle, fixed action vocabulary, bounded diagnostics/3s extraction.
- `TrackpadApp`: editing, explicit preview, conflict/unsupported explanation, file panels and local persistence. Simulation never dispatches an action.
- `TrackpadProbe`: count-only comparison of three public API paths, non-seizing, no output/feature HID reports.

Input coordinates use lower-left origin and [0,1]. Session identifiers are ephemeral random IDs, not serials. Contact IDs preserve equality only within a live capture session. Missing pressure/area stay absent. The preview adapter has no device-transport attribution; it reports unknown rather than borrowing metadata from discovery. Source provenance (synthetic or AppKit local) accompanies fixture export separately from observed fields.

Full frame snapshots contain all active contacts and explicit terminal phases; consumers reject stale/malformed/out-of-order/contact-churn streams and wait for a clean boundary. Native gesture interference cancels recognition. At most one exclusive winner is selected on sequence completion. Hold means duration-qualified **release**, not an action while fingers remain down. Conflict order: scoped app first, required-capability specificity, priority descending, stable ID ascending. It is independent of profile list order.

Edge zones are the outer 20%; corners intersect these edges. See [configuration semantics](CONFIGURATION.md) for the 80ms contact assembly window, snapshot/terminal rules and exact thresholds.

Configuration changes, switching sources, permission changes and lifecycle interruptions cancel the current sequence. Imported enabled state is disarmed in the UI and no import executes an action. Keyboard actions remain invalid for execution. Pinch/rotate definitions can be carried but are unsupported recognizers. The UI displays support per source, not a global green check inferred from generated fixtures.

## Permission and execution boundary

Input Monitoring is for observing input in other apps. Accessibility permits controlling other apps/input; it does not unlock missing public touch fields. This app only preflights state and opens system settings on explicit click. No permission prompt is made automatically. Local AppKit view preview and manual beep/NSWorkspace handler dispatch do not need Accessibility.

Allowed manual actions: beep, HTTP(S) URL handler, app launch/focus/hide by bundle ID, named existing Apple Shortcut through its system handler. A Shortcut may itself perform user-defined work, so the name and explicit test action are displayed before dispatch. The app does not inspect, download or execute code from profiles. Logs never include action payloads or handler URL queries. Handler acceptance is not action completion.

Native pointer/button/scroll/pinch are never injected, seized or filtered. Read-only event monitors return the original event. No global mappings are armed. This preserves the fail-open design without claiming physical coexistence has been tested.
