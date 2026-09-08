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
