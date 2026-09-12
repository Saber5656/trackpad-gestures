# Review and remediation

2026-09-08. Main agent performed implementation/self-review; a separate Luna agent performed public-source research and read-only platform/core reviews. Parallel core implementation was moved into an isolated Git worktree after the user's explicit reminder. The first core delivery was not accepted as completion: main review found missing acceptance coverage and corrected it before integration.

## Adopted findings

| Finding | Fix and verification |
|---|---|
| USB-only Apple vendor matching misses Bluetooth namespace | Enumerate 0x05ac + 0x004c; independent IORegistry metadata cross-check; vendor namespace test |
| Touch identity map can grow when terminal delivery is lost | Hard 10-identity bound, abort callback, clear on cancellation; identity-churn regression |
| Import size check has a file replacement race | Open once, no symlinks/special files, bounded 256KiB+1 read; oversized/directory tests |
| Background action backend can abort | Throw safely before AppKit calls; no input injection is present |
| Permission text suggests global capability | Explicit UNUSED/global unavailable; app preflights differ from CLI probe |
| Unbounded or inconsistent save validation | Shared codec limits, byte limit before persistence, references/IDs/duration/bundle checks |
| Stale app-bundle files can survive rebuilding | Fresh staging bundle, retained previous bundle, rollback on rename failure; Python regression |
| One-finger input and missing contact capabilities accepted | Enforce 2–5 definitions and intrinsic contact/identity/coordinate capabilities; red/green regression |
| Candidate selected before recognition | Keep candidates through release, choose only matching candidates by shared deterministic ordering |
| Global app scope and lower-left direction mishandled | Snapshot actual scope; higher y means up/top; direction/scope tests |
| Sequential finger arrival/lift and phase rollback | 80ms assembly, explicit active/ended state, no missing active IDs; mixed-phase and churn tests |
| Out-and-back or divergent motion misrecognized | Maximum per-contact displacement; bounded coherent translation; rejected-fixture regressions |
| Cooldown reset at every local sequence | Confirm known empty boundary without clearing cooldown; app-model regression |
| Timestamp gap poisons recovery | Gap only applies while active; rejected future gap does not advance accepted clock; empty-boundary regression |
| Idle native interference consumes next gesture | Idle empty interference is ready; active interference cancels; final independent re-review confirmed fix |
| Fixtures were not actually replayed; fuzz assertion was vacuous | Four on-disk frame golden fixtures now run in both definition orders; 1,000×12-frame deterministic/property checks; legacy files retained privately |

The independent final focused re-review confirmed the idle-interference and extreme-timestamp repairs (3 tests / 2 suites). The earlier core-only filter ran 23 tests; the final whole-package run has 45 tests including platform and app-model suites. These are different scopes, not interchangeable counts.

## Disposition and limitations

No known unaddressed blocking finding remains for the **local simulation prototype**. Full global USB product acceptance is not granted: reference hardware, physical false-trigger/coexistence, TCC revocation, lifecycle hardware tests and distribution verification remain unperformed.

The review's suggestion to duplicate all codec size validation in the UI was only partially adopted: the codec already limits input size/item counts; the actual unbounded file read and persistence defense were fixed. No second independent schema validator or guessed capture backend was added.

All committed files were checked for personal absolute paths, secret-like tokens, whitespace errors and broken local document links. No third-party protocol/driver implementation was copied. Final documentation changes do not change executable behavior and are outside TDD; consistency checks apply.

## USB follow-up review

A separate Luna reviewer used `task/capture-audit` in an isolated worktree while the main agent performed device observation and implementation.

- Adopted: bare RunLoop can miss AppKit dispatch. Replaced it with `nextEvent` / `sendEvent`; isolated process sentinel fails on the old path and passes on the new one.
- Adopted: HID counters alone cannot establish exposed fields. Added bounded public descriptor inventory with all-element Digitizer summary, explicit truncation and unavailable state; five focused tests and real USB enumeration.
- Adopted: Input Monitoring preflight is not an actual IOHID open result. `hidOpenAttempted` now distinguishes a skipped open; `hidOpenStatus` is absent when not attempted. No permission prompt is requested merely to test denial.
- Deferred to unlocked hardware validation: `.any` touch snapshots and sequential arrival/lift must be checked against actual responder callbacks. A persistent active-contact cache was not added on speculation, since retaining an unobserved contact could conceal loss; current core cancels missing active contacts.
- Limitation at this earlier review (superseded by the callback repair below): `wantsRestingTouches` was false in the experimental local adapter. Apple documents resting-touch exclusion and generated began/ended transitions. Finger count therefore describes delivered active touches, not all physical fingers. Resting transitions and a future explicit resting-contact policy must be verified before any real gesture action is armed. See [Apple resting touch behavior](https://developer.apple.com/documentation/appkit/nsview/wantsrestingtouches).
- Not adopted without evidence: deprecated `acceptsTouchEvents` was not added alongside the current `allowedTouchTypes` API.

Final limited independent review found no blocking safety defect and one conditional collection-limit issue. Adopted: `totalCollectionCount` and `collectionsTruncated` now expose a 16-collection cap; unavailable enumeration has absent totals. The final source was self-reviewed, rebuilt and tested after this fix.

No USB global gesture pass is claimed. The Mac remained locked, so the GUI/physical input blocker is separate from the corrected probe and passing automated tests. No private protocol implementation, new privileges or distribution change was introduced.


## Recorder timing repair review — 2026-09-12

The independent worker first replayed the physical input in `task/physical-replay`, producing tracking/no-event evidence and an anonymous-ID fixture. Integration retained the exact source timestamp difference rather than the worker's display-rounded value; the fixture test passed afterward. The worker then performed one static review of the separate recorder implementation and its tests, finding no actionable defect. Its auxiliary review harness marked the response `review_incomplete` because explanatory prose accompanied the result JSON; that harness run is not represented as a completed automated review gate. The main agent read the bounded-state/export paths and relied on the actual regression, full-suite, isolated-build and GUI evidence for acceptance.

The repair keeps the three-second/180-frame raw limit and 30-second preview expiry. Waiting for fresh contact stores no frames and expires after ten seconds. Sample schema v2 exposes missing/timed-out/explicitly stopped capture windows without fabricating release events. Profile schema and action execution are unchanged. The first file alone cannot distinguish window expiration from missing native terminal delivery; no unsupported causal claim or public-API/distribution change was adopted.

## Second physical sample / touch delivery repair — 2026-09-12

An isolated Luna/high worker preserved and replayed the second physical sample without correcting the duplicate timestamp or changed terminal ID. The parent checked every relative timestamp, position and phase against the raw file and verified the ID mapping was bijective before integration. A clarification distinguishes the core-only replay from the GUI's explicit empty-boundary recovery; later waiting statuses are not a recording of the live application state.

TDD reproduced double normalization through two public AppKit callbacks receiving one test event: five observations/four IDs instead of four/three, no winning event and malformed ordering. A weak event-object reference fixes this without discarding distinct equal-timestamp events. Separate resting tests failed for exclusion/missing flag, then passed with public resting-touch delivery and optional observed flags. The initial test compile failed because the stub identity lacked NSCopying and an initializer's arguments were out of order; those test-authoring errors were corrected before the actual behavioral red run.

The worker reviewed the changed adapter/tests once, read-only, with no actionable findings. The parent adopted the review and inspected forwarding, bounds, stop/restart, exact observation preservation, optional serialization and docs consistency. Actual OS callback object lifetime, resting transitions and native coexistence remain hardware validation limits. Final automated checks and app restart are recorded in [validation](VALIDATION.md). No private API, permission expansion, automatic action or raw-file correction was added.
