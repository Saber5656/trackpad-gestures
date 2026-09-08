# ADR-001: Swift-first with a portable semantic contract

Status: accepted for this local feasibility build, 2026-09-08.

Decision: Swift Package with Foundation-only `TrackpadCore`, `MacPlatform`, a count-only `TrackpadProbe`, and SwiftUI/AppKit settings app. No external package dependencies. No license is selected; planned OSS is not yet a licensed/public release.

Swift-first gives the shortest macOS implementation loop and direct public API access. Rust shared core offers stronger Windows ecosystem/toolchain reuse but adds ABI ownership, error bridging and a second build pipeline before capture feasibility is known. C++ shares a stable C boundary but requires extra ownership/undefined-behavior review and Objective-C++/Swift integration. All three can support deterministic pure tests. Size/performance comparisons are estimates; only this Swift build is measured. Detailed comparison: [research](research.md).

Windows 11 x64 must reuse the schema, ordering rules and golden fixtures; Swift core portability is a candidate, not a verified Windows binary. If a Rust/C++ port is later justified, it must pass the same fixtures and version semantics rather than silently translate unsupported features. Windows 10, ARM64, Bluetooth, ML/drawing/chains, one-finger customization and Force Touch/haptics remain excluded.

Minimum build deployment target: macOS 15.1, matching USB-C hardware's published requirements. Only arm64 macOS 26.6.2 is tested; Intel and other OS releases are unverified.

Safety choice: no global raw-contact backend until evidence and any necessary API/distribution decision. AppKit preview cannot bind a touch device to a USB VID/PID, so its transport is unknown. No keyboard/button injection is implemented: an ordinary process cannot execute cleanup after SIGKILL. A best-effort watchdog would not establish the requested unconditional key-up guarantee, so this action remains unsupported, visibly and in execution validation.
