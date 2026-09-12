# Physical sample replay records

この記録は、2026-09-12 に `appkit-local-unverified` の保存機能で得た2フレームのsampleを、個人を特定しない短いfixtureへ変換し、既存 `TrackpadCore` で再生した結果を残すものです。保存されたraw sampleはGitへ追加せず、fixtureのraw観測部分には座標・phase・フレーム間隔だけを保持しました。sourceのsession/contact IDは `session1` と `c1`〜`c3`へ一対一で置換しています。

## physical-incomplete-hold

- fixture: [`Tests/TrackpadCoreTests/Fixtures/physical-incomplete-hold.json`](../Tests/TrackpadCoreTests/Fixtures/physical-incomplete-hold.json)
- provenance: `physical; AppKit local sample sanitized for replay`
- sourceSHA-256: `f9a07d86abe77fdd8687447a88316e1596fdd7503d86ddba24e9209e473bb15b`
- source shape: 2 frames, 15.027250 ms apart, first frame is `c1/began`; second is `c2/began`, `c3/began`, `c1/stationary`; 3 distinct contacts; no terminal phase
- replay definitions: 3-finger hold (`minDuration=0.6`, `maxDuration=2`, `movementThreshold=0.06`, `cooldown=0.5`, enabled), with a same-finger-count tap (`0`–`0.35` seconds) also enabled; no application scope; intrinsic contact capabilities are present
- observed Core result: both frames return `tracking`; no gesture event is emitted because no frame closes all three contacts, so hold completion is not observed

このfixtureの期待値は、観測した保存データを既存Coreへ入力した結果を固定するものです。新しい認識挙動を追加したものではないため、今回のテストはTDDの対象外としました。保存が成功し3点入力が含まれていても、2フレームで記録窓が終わった理由やOSからterminal phaseが届かなかった理由は、この保存データだけでは確定できません。したがって、この結果を完全な物理holdの認識、記録窓終了原因、またはOSイベント欠落原因の証拠として扱いません。

## physical-second-sample

- fixture: [`Tests/TrackpadCoreTests/Fixtures/physical-second-sample.json`](../Tests/TrackpadCoreTests/Fixtures/physical-second-sample.json)
- provenance: `physical; AppKit local sample sanitized for replay`
- sourceSHA-256: `e9fbbfb738cbf6d74383b5c3963479b6ed016efbb7aad615bb3052d4ce8de8c5`
- source shape: 43 frames, one session, five source contact IDs mapped one-to-one to anonymous `c1`〜`c5`; pressure/area unavailable; coordinates and phases are retained
- first contact sequence: frame 0〜5 spans exactly `0.06098020798526704` seconds (about 61 ms); frame 3 reports `c2/ended`, and frame 4 repeats the same timestamp with the same terminal coordinates under a new anonymous ID `c4/ended`; no frame was inserted or corrected
- later sequence: frame 6 begins a separate one-contact `c5` sequence about 1.156 seconds after frame 0, but replay is already waiting for an empty boundary after the malformed frame
- observed Core result: frame 0〜3 return `tracking`; frame 4 returns `malformed` because its timestamp is not greater than the preceding frame; frames 5〜42 return `waitingForBoundary`; no gesture event is emitted

The 61 ms interval is the interval between observed AppKit contact phases, not a measurement of how long the user held three fingers. The saved observations contain no `isResting` state or other physical-release timing, so they cannot establish a short tap, a completed hold, or the cause of the terminal phase. In particular, the `c4` record is evidence of a same-time re-notification with a changed identity in the saved stream; the Core replay rejects the ordering before it evaluates contact identity. The separate capture-adapter investigation covers object-identity deduplication for repeated callbacks.

This is a core-only replay: the GUI adapter normally calls `confirmEmptyBoundary()` after an all-terminal observation, which this direct `process` replay does not inject. Therefore its later waiting statuses are not a recording of the live GUI state. Native-interference context is also absent from the sample.

This fixture records existing behavior and evidence only. Its test is outside TDD because it adds no recognition behavior: it fixes the exact raw-derived phases, relative timestamps, coordinates and resulting `status/events` for later diagnosis. The sample confirms that contact phases were observed and that this replay produced no action; it does not certify physical hold recognition, release duration, or native coexistence.

検証コマンド:

```text
scripts/test.sh --filter PhysicalReplayTests
```
