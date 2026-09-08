# v1 requirements and current acceptance

Reference product: one cross-platform Magic Trackpad gesture customizer, macOS first. Target hardware is the current USB-C Magic Trackpad over verified wired USB. Windows 11 x64 and Bluetooth are subsequent adapters. Full v1 acceptance remains open until M-00 hardware/global capture succeeds or a user-approved vocabulary/distribution decision changes it.

| ID | Required user outcome | Local build status | Evidence / remaining work |
|---|---|---|---|
| R01 | See device, transport, capabilities and permissions separately | Implemented with explicit unknown/unsupported | Discovery + GUI; wired device not observed |
| R02 | See input live without corrupting native input | Synthetic studio + experimental view-local preview | No post/seize/filter API; physical coexistence untested |
| R03 | Edit 2–5 fingers, trigger, direction, zone, timing/movement, modifiers, app scope, priority, cooldown | Implemented | App model, vocabulary and replay tests |
| R04 | Detect conflicts deterministically before enablement | Implemented | Shared ordering/overlap helper; one winner per sequence |
| R05 | Safely assign actions | Declarative assignment and manual handler tests | No automatic live dispatch; keyboard/showDesktop unsupported |
| R06 | Export/import portable versioned data, never executable profiles | Implemented | Strict codec, schemas, GUI round trip; imports disarmed |
| R07 | Cancel on permission/lifecycle changes without stuck state | Implemented software cancellation | No synthesized key/button exists; physical lifecycle matrix pending |
| R08 | Local-only, telemetry off, bounded/redacted diagnostics | Implemented | 64-entry enum log; 30s preview; 3s/180-sample explicit recording |
| R09 | Public API global tap/hold/swipe on reference device | Not verified | M-00 NOT PASSED; no private API fallback chosen |
| R10 | Reproducible build, tests, reviewed local commits | Verified on this host | See VALIDATION/REVIEW; unsigned local bundle only |
| R11 | License/provenance and distribution approval | Pending user decision | No external code/dependencies copied; no LICENSE/publication |
| R12 | Shared Windows/Bluetooth semantics without silent remapping | Design boundary only | Schema/core/fixtures reusable; Windows/Bluetooth not implemented |

Excluded: one-finger customization, free-form drawing, ML, gesture chains, Force Touch/haptic programming, arbitrary shell, downloaded plugins, remote automation, embedded executable profile payloads. Pinch and rotate are candidate future recognizers, not formally supported by this build.

[Design](DESIGN.md), [configuration](CONFIGURATION.md), [dependency DAG](ISSUE_PLAN.md), [coverage and results](VALIDATION.md), [M-00](M-00-feasibility.md).
