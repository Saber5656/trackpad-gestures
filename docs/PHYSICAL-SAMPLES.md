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

検証コマンド:

```text
scripts/test.sh --filter PhysicalReplayTests
```
