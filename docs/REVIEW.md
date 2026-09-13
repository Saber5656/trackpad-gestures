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

## Sample boundary and save movement — 2026-09-13

The parent confirmed that bounded recording appended the operator's later input; it did not overwrite earlier frames. The existing three-contact duplicate was earlier than the later one-contact motion, so the save interaction is not blamed for that defect. A separate Luna/high worktree updated the data-contract and sample interpretation documents alongside the parent's TDD implementation.

Adopted corrections to the first document draft: cancellation stops without waiting for every remaining ID; missing contacts cannot imply ended; inconsistent sequence observations use an explicit failure reason. The historical malformed frame would stop the new recorder at its unknown terminal ID, not become a successful completed sample. Trackpad coordinates cannot establish the screen destination of the later movement. The draft was corrected before integration, and the operator's word “tap” is preserved without inferring actual hold duration.

The worker reviewed the recorder, app integration, status text and regressions once, read-only, with no actionable code findings. The parent checked the implementation against the focused/full/clean-source results and GUI restart. Exported bytes remain stable after the observed sequence boundary while live contacts update; cancellation/invalid input are distinguished from completion. First-contact wait, contact count, raw time/count limits, preview expiry and unsupported global actions remain unchanged. The small native UI text change uses the existing design; no new design flow was introduced. Documentation/links and personal-path/secret scans were checked before the single feature commit.

## Saved physical tap verification — 2026-09-13

A Claude work execution in an isolated worktree added the third physical fixture/replay and its source record. A separate Claude read-only execution reviewed the integrated fixture/test/docs. Both requested `sonnet` / `low`; the CLI reported `claude-sonnet-5`. The local runner flagged the alias/name difference as `model_mismatch`; this flag is preserved in private evidence, not described as a verified exact model-name match. No quota fallback or extra provider was used.

The parent checked raw-to-fixture correspondence for every timestamp, position, phase and one-to-one contact ID mapping. Integration corrected a prose-only last-contact typo (`c1` to `c2`) and retained the raw recording/resting metadata in a supplemental envelope. Source Core/Capture code and the old samples were unchanged.

The reviewer returned `approve` with one low-severity finding, so the harness classified the contradictory approval/nonempty-findings result as incomplete. No automated approval-gate success is claimed. The finding notes that an all-false resting expectation does not distinguish an actual copy from a constant-filled fixture and should not be generalized to a future sample with true values. The parent did not change this fixed-sample assertion: all source flags are actually false, this is a golden observation test rather than an exporter implementation, and existing adapter tests already verify a true resting flag. An additional exact raw-to-envelope comparison confirms all flags and recording fields match. Future fixtures must retain their own actual values; the observation does not establish a current functional defect.

The reviewer independently read raw/fixture correspondence and traced the tap recognition but did not rerun tests or hashes. The parent's executed physical replay (3 tests), whole package (69 tests), exact metadata comparison, privacy/link checks and doc self-review provide those checks. Physical live GUI recognition, actions, native coexistence and global capture remain outside this evidence. The existing expiry-message wording issue was registered locally without a new UI change.


## Keyboard failure-model research — 2026-09-13

Claude sonnet/low authored research and three no-input subprocess experiments in an isolated worktree. A separate read-only Claude execution found helper-lifecycle scope and incomplete grandchild cleanup issues. Its approve/nonempty-findings response was classified as `review_incomplete`, not successful approval. The parent adopted both issues and found an additional overclaim: modifier flags do not turn a primary key/button down into a complete, atomic shortcut. Directly fetched Apple keyboard-initializer and flags documentation supported the correction; the web tool's Markdown content-type error was recovered by reading the same official URL through an HTTP client.

A separate work execution replaced sleep races with pipes and made both Popen objects owned and reaped by each test. The parent rewrote the ADR around the actual key/button requirement, removed unsupported claims about physical modifiers, and distinguished sibling-process experiments from installed XPC/launchd helpers. Three parent-run experiments passed; no real input was posted. A final separate Claude review of the changed experiments/document and input-validation changes returned approve with no findings. Its limitations: static only, no independent test execution or official-link fetching. Parent source checks, primary documentation and executed tests supply those parts. Requested alias sonnet/low reported claude-sonnet-5, with the runner's alias/name mismatch retained; no fallback was used. Keyboard injection remains unsupported.


## Autonomous input validation — 2026-09-13

The parent extended the process probe after both operator-window and CUA-control callbacks were zero, without labelling either as a hardware failure. Red-first schema/timer assertions passed after adding bounded allowlisted session/monitor health and aggregate counters. The parent confirmed public SDK symbols, that source/tap state is sampled before teardown, and that session dictionaries and key contents are not exported. Existing source tests and new app-model characterization retain the physical sample's measured shape while explicitly rebasing only its clock.

A separate Claude execution reviewed the new probe/test/fixture-routing changes and related documentation, returning approve with no findings. Its stated limitations include no test rerun, no live hardware, no web lookup and no reading of unchanged AppModel internals. The parent inspected those internals directly, corrected the initial cooldown test expectation using the sequence-start filter, and ran focused/full/clean-source tests plus release-probe build. Documentation additions recording subsequent GUI observations were self-reviewed for scope and preserved the unsuccessful Hide result. No claim of real gesture-to-action dispatch, physical coexistence, global capture or a complete keyboard release guarantee was added.


## Visible bounded diagnostic — 2026-09-13

A Claude sonnet/low audit ran in an isolated worktree while the parent prepared the native control. Its timestamp fields were adopted. The parent rejected unsupported ranking of timing mismatch as most likely, treating endpoint tap health as continuous health, treating resting three fingers as a mouse-button press, and claiming activation-policy hypotheses were disproved. The original worker report/commit is preserved privately; only the corrected evidence document and reviewed source were integrated. The worker committed before the requested parent review; the parent did not reuse that premature commit as acceptance.

The parent tested the new count-window and lifecycle/save manager from missing-behavior failures, fixed the concrete C callback type, then caught and repaired an unavailable-monitor-as-zero UI defect with a failing optional-value test. Source counters are fixed-vocabulary and capped, callbacks return original input, the tap is listen-only and skipped without permission, and stop removes all sources. No contact/action path is added.

A separate Claude read-only execution reviewed an isolated snapshot of the integrated source/tests/docs and returned approve with no findings. Limitations: no test rerun or physical input, abbreviated DESIGN/ISSUE_PLAN checks, and no runtime thread-contention experiment. The parent verified main-run-loop registration, performed the full and clean-copy tests/builds, checked UI/autosave and reviewed the doc updates. Both executions requested sonnet/low and reported claude-sonnet-5; alias mismatch flags are retained. No fallback was used. Unchanged evidence was reviewed once.

Physical input delivery, gesture capability, native coexistence and hardware lifecycle remain open. Coarse CPU/RSS observations are not performance acceptance. Failed initial test invocations and initial UI presentation are recorded rather than described as successful. No permissions or distribution policy changed.
