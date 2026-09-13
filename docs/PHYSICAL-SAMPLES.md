# Physical sample replay records

この記録は、2026-09-12 に `appkit-local-unverified` の保存機能で得た2フレームのsampleを、個人を特定しない短いfixtureへ変換し、既存 `TrackpadCore` で再生した結果を残すものです。保存されたraw sampleはGitへ追加せず、fixtureのraw観測部分には座標・phase・フレーム間隔だけを保持しました。sourceのsession/contact IDは `session1` と `c1`〜`c3`へ一対一で置換しています。2026-09-13 に保存された3件目のsample（`physical-third-sample`、schemaVersion 2、7フレーム）も同じ方針で追加しています。

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

The later points are present in the historical raw export because that capture was held open until the operator pressed Export. After the duplicate-timestamp frame (frame 4), frame 5 finishes the initially observed three-contact sequence (`c1`, `c2`, `c3`, with the changed terminal identity `c4` also observed), and frame 6 starts a separate one-contact sequence. That later sequence contributes movement observations from about `1.156008` through `1.779012` seconds after the first frame. Its movement fits the reported tap-then-Export interaction sequence, but the destination is not recorded and trackpad coordinates alone cannot identify a UI control or establish the operator's intention.

Under the revised GUI Record boundary, frame 4 is an inconsistent observation because `c4/ended` is an unknown terminal identity in the selected sequence. The recorder would retain that bad frame and freeze with `finishReason=invalidSequence` there; it would not append frames 5〜42. The live preview may still show the later movement, but that display is independent of the frozen sample. The later movement therefore cannot explain the duplicate timestamp: the duplicate occurs earlier, within the three-finger sequence, before any of those one-finger points. This interpretation does not rewrite the raw export or turn its malformed replay into successful gesture recognition.

The operator described the initial action as a three-finger tap followed by moving to Export. The raw sample does not establish the physical hold duration, so it cannot by itself distinguish a tap from a hold attempt. Core-only replay emits no event for either the tap or hold definition because the malformed duplicate frame stops replay; this is evidence about the malformed stream, not a claim that a physical gesture was successfully recognized or that the later movement reached Export.

The 61 ms interval is the interval between observed AppKit contact phases, not a measurement of how long the user held three fingers. The saved observations contain no `isResting` state or other physical-release timing, so they cannot establish a short tap, a completed hold, or the cause of the terminal phase. In particular, the `c4` record is evidence of a same-time re-notification with a changed identity in the saved stream; the Core replay rejects the ordering before it evaluates contact identity. The separate capture-adapter investigation covers object-identity deduplication for repeated callbacks.

This is a core-only replay: the GUI adapter normally calls `confirmEmptyBoundary()` after an all-terminal observation, which this direct `process` replay does not inject. Therefore its later waiting statuses are not a recording of the live GUI state. Native-interference context is also absent from the sample.

This fixture records existing behavior and evidence only. Its test is outside TDD because it adds no recognition behavior: it fixes the exact raw-derived phases, relative timestamps, coordinates and resulting `status/events` for later diagnosis. The sample confirms that contact phases were observed and that this replay produced no action; it does not certify physical hold recognition, release duration, or native coexistence.

## physical-third-sample

- fixture: [`Tests/TrackpadCoreTests/Fixtures/physical-third-sample.json`](../Tests/TrackpadCoreTests/Fixtures/physical-third-sample.json)
- provenance: `physical; AppKit local sample sanitized for replay`
- sourceSHA-256: `cdacd7df1fd34545968f83a924fa968df3dfaebc37860cda5390dc0dc49a13ff`（読み取り専用のraw source: `.local/physical-evidence/2026-09-13-three-finger-tap.json`、schemaVersion 2）
- source shape: `recording.finishReason=sequenceEnded`、`sampleCount=7`、7フレーム、3個の識別子（一対一で `c1`〜`c3` に置換）、全 `isResting=false`。frame 0〜6は `604251.781411833`〜`604251.887431125` の絶対timestampで、frame 0を基準とした相対差分は最終フレームで `0.1060192920267582` 秒（rawの `finishedAt - captureStartedAt` と一致）。3点は同時刻での重複終了イベントを含まない。
- replay definitions: 3-finger tap（`minDuration=0`, `maxDuration=0.35`, `movementThreshold=0.06`, `cooldown=0.5`, enabled, `actionID=beep`）と同一fingerCountのhold（`minDuration=0.6`, `maxDuration=2`, `movementThreshold=0.06`, `cooldown=0.5`, enabled, `actionID=beep`）。actionIDはCore側の再生用参照データのみで、実際のbeep再生・GUI通知は今回のCore-onlyテストの対象外。
- observed Core result: frame 0〜5は `tracking`、最終frame 6（最後の `c2` が単独で `ended` になる）で `fired` となり `tap` イベントが1件発火。`hold` イベントは発火しない（`minDuration=0.6` に到達する前にsequenceが終了しているため）。
- fixtureの `captureMetadata` は実観測のrecording metadataと各frame順の `isResting` 値を保持する。Coreのframeやcapabilityに存在しない情報は追加していない。
- テストログ: `.local/physical-third-sample-test.log`（このworktree内、git対象外）に `scripts/test.sh --filter PhysicalReplayTests` の全出力を保存済み。

このfixtureは、以前の2件（`physical-incomplete-hold`＝2フレームでhold未完了、`physical-second-sample`＝43フレームで重複timestampによりmalformed）とは異なり、tapイベントが最後まで正常に発火した初めての物理sampleである。ただし、これはCore-onlyのreplayが保存済み観測データに対して`process`を直接呼び出した結果であり、実機でのGUI経路（`confirmEmptyBoundary()` 呼び出しを含む）、beepの実再生、長押し(hold)との共存、または本番のglobal監視下での動作を証明するものではない。観測データは既に固定されているため新しい認識挙動を追加するものではなく、今回のテストはTDDの対象外とした。

検証コマンド:

```text
scripts/test.sh --filter PhysicalReplayTests
```
