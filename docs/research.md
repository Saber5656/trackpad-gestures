# Trackpad Gestures 調査メモ

確認日: 2026-09-08 (JST)
対象: USB-C Magic Trackpad を macOS-first に扱い、将来の cross-platform backend を許容する OSS gesture engine。
調査環境メモ（依頼記載値）: macOS 26.6.2 (25G83), arm64, Swift 6.3.2, Rust 1.95.0。

## 結論

初期実装は public API に限定し、`NSEvent` → `CGEventTap` → 必要最小限の `IOHIDManager` の順で probe する。root、private API、署名・notarization・公開は今回の範囲から除外する。`NSEvent` で解釈済みの swipe/magnify/rotate 等を得られることは Apple の公開資料で確認できるが、グローバルな per-finger contact frame を得られる公開契約は確認できない。したがって「任意の指数・軌跡を system-wide で認識できる」は現時点で未検証であり、実機 probe の結果が出るまで実装可能・対応済みとは扱わない。

## 公開 API と global contact の限界

| API | Apple が保証する範囲 | 初期方針 |
|---|---|---|
| [`NSEvent`](https://developer.apple.com/documentation/appkit/nsevent) | AppKit のイベントキューに届く gesture/touch。`phase`、`magnification`、`rotation`、scroll delta 等を提供。Apple の [Handling Trackpad Events](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/EventOverview/HandlingTouchEvents/HandlingTouchEvents.html) では、trackpad driver が解釈した gesture は active application の view へ responder chain 経由で配送される。 | アプリ内の認識と fixture 化に使う。`addGlobalMonitorForEvents` は他アプリ向けイベントのコピーを非同期に観測できるが、イベントを変更・抑止できず、自アプリ宛は届かない（[公式仕様](https://developer.apple.com/documentation/appkit/nsevent/addglobalmonitorforevents%28matching%3Ahandler%3A)）。 |
| [`CGEventTapCreate`](https://developer.apple.com/documentation/coregraphics/cgevent/tapcreate%28tap%3Aplace%3Aoptions%3Aeventsofinterest%3Acallback%3Auserinfo%3A%29) | Quartz の低レベル event stream を observe/filter。公開 [`CGEventType`](https://developer.apple.com/documentation/coregraphics/cgeventtype) 列挙は mouse/key/scroll/tablet と tap-disabled 通知などで、touch contact 型は含まれない。HID ingress (`.cghidEventTap`) は root だけが作成できる。 | root を使わず session tap と listen-only を probe。許可されない event bit は tap 作成時に落とされ、空なら `NULL` になるため、失敗を通常状態として扱う。 |
| [`IOHIDManager`](https://developer.apple.com/documentation/iokit/iohidmanager_h) | HID device の列挙・接続/切断・input report/value callback と matching。 | 公開 API として device discovery の補助に限定。Magic Trackpad の multi-touch contact が一般 user の manager にどこまで露出するかは Apple の API 契約からは判断できず、親担当の実機 probe 待ち。 |

根拠を合わせると、`NSEvent` の global monitor は「system-wide に見える」ものの、Apple が説明するのは既に配送されるイベントのコピーであり、指ごとの raw contact stream ではない。一方 `CGEventTap` の公開 event type に contact 型がない。よって **public API だけで global per-finger contacts を前提に設計するのは不適切**、というのが資料からの推論である。raw contacts を提供すると記載する OSS（例: [Subsurface](https://github.com/mrkai77/Subsurface)）は private `MultitouchSupport.framework` の wrapper であり、今回の許容範囲外である。

Apple は Magic Trackpad (USB-C) を 2024 年製、Multi-Touch/Force Touch、USB-C/Bluetooth、macOS 15.1 以降として案内している（[Tech Specs](https://support.apple.com/en-ca/121932)）。USB 接続時もこの仕様から raw contact 公開を推測してはならない。

## 権限、sandbox、配布

権限はユーザー向けに別物として説明する。

- **Input Monitoring**: Apple は「他のアプリ使用中でも keyboard/mouse/trackpad を監視」する権限として説明している（[Support](https://support.apple.com/en-mide/guide/mac-help/mchl4cedafb6/mac)）。listen-only の event tap では [`CGPreflightListenEventAccess`](https://developer.apple.com/documentation/coregraphics/cgpreflightlisteneventaccess%28%29) / [`CGRequestListenEventAccess`](https://developer.apple.com/documentation/coregraphics/cgrequestlisteneventaccess%28%29) を使い、拒否時も UI と機能を graceful に縮退する。
- **Accessibility / Post Event**: Apple は Accessibility を scripts/system commands による Mac の制御として説明している（[Privacy & Security settings](https://support.apple.com/en-euro/guide/mac-help/-mchl211c911f/mac)）。`AXIsProcessTrusted` は Accessibility client の trust を返し、`CGPreflightPostEventAccess` / `CGRequestPostEventAccess` は Quartz event posting の access API である（[AXIsProcessTrusted](https://developer.apple.com/documentation/applicationservices/1460720-axisprocesstrusted)、[CGRequestPostEventAccess](https://developer.apple.com/documentation/coregraphics/cgrequestposteventaccess%28%29)）。認識（listen）とショートカット/クリック合成（post）を同じ許可として表示しない。

App Sandbox は Mac App Store 配布で必須（[Preparing your app for distribution](https://developer.apple.com/documentation/xcode/preparing-your-app-for-distribution/)）。Apple DTS の公式 forum 回答では、sandboxed app の `CGEventTap` は Input Monitoring の明示許可後に動作し得るとされる一方、`IOHIDDeviceOpen` は TCC deny になり得る（[DTS thread](https://developer.apple.com/forums/thread/724608)）。従って sandbox で event tap が動くことと、HID manager で raw input が読めることは同じではない。App Store 審査で global gesture utility が承認されるか、Magic Trackpad contacts が sandbox で取得できるかは未検証である。

外部配布を将来行う場合、Apple の notarization は Developer ID 署名、Hardened Runtime、secure timestamp を要求する（[Notarizing macOS software](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)、[Hardened Runtime](https://developer.apple.com/documentation/security/hardened-runtime)）。今回のリポジトリでは署名・notarization・公開を行わず、配布可能とは表現しない。private framework 使用を選ぶ設計は App Store と notarization のリスクを増やすため、初期方針から除外する。

## 競合と差別化候補

| 対象 | 確認できた事実 | 差別化の仮説 / 未検証 |
|---|---|---|
| [BetterTouchTool](https://folivora.ai/features/trackpad-gestures/) | macOS 向け。1〜5 fingers の taps/clicks/swipes、TipTap/Force click/drawing、global/per-app、600+ actions と window/shortcut/script integration を公式に掲げる。 | 機能数・成熟度では競争しない。public-API-first、OSS、local-only、最小設定、backend 分離が候補。ただし public API だけで同等の 1〜5 finger raw recognition が可能かは未検証。 |
| [Multitouch](https://multitouch.app/) | macOS 10.15+、Intel/Apple Silicon。trackpad/Magic Mouse gesture engine、browser/keystroke/click actions、window management を公式に掲げる。 | macOS 専用の完成度と action catalog は既存優位。差別化候補は license 監査可能な OSS と cross-platform core。ユーザー調査、精度、遅延、権限 UX の比較は未実施。 |
| [Touchégg](https://github.com/JoseExposito/touchegg) / [Fusuma](https://github.com/iberianpig/fusuma) | Linux の libinput ベース gesture recognizer。Touchégg は GPLv3、Fusuma は MIT とリポジトリに表示。 | cross-platform backend の先行例だが、macOS public API backend の品質/互換性は未提供。設定 schema や実装をコピーせず、概念比較だけに留める。 |
| [Subsurface](https://github.com/mrkai77/Subsurface) / [Sleight](https://github.com/kamenlevi/Sleight) | macOS OSS の raw contacts/gesture/haptic 例。両者とも README で private `MultitouchSupport.framework` 利用を明示し、Subsurface は Apache-2.0、Sleight は GPLv3。 | raw contact の価値を示す prior art だが、今回の public API 初期調査の範囲外（App Store は未決定）。API/コードの取り込みはしない。 |

実装方針として検証可能なのは「公開 API 制約を守る」「権限理由を分離して説明する」「core と platform backend を分ける」という設計上の選択であり、認識精度・遅延・対応 gesture 数での優位はまだ主張しない。

## License / provenance

このプロジェクトの license は未決定。今回の調査では上記ページと公開 README の事実だけを参照し、他プロジェクトの実装、コード片、画像、設定、商標表現をコピーしていない。[Touchégg](https://github.com/JoseExposito/touchegg) (GPLv3)、[Fusuma](https://github.com/iberianpig/fusuma) (MIT)、[Jitouch](https://github.com/JitouchApp/Jitouch-project) (GPL-3.0-or-later)、[Subsurface](https://github.com/mrkai77/Subsurface) (Apache-2.0)、[Sleight](https://github.com/kamenlevi/Sleight) (GPLv3) は候補実装の provenance と license の比較対象であり、依存として導入したものではない。license を決めるまでは新規コードを特定 OSS の派生物として扱わず、将来の依存追加時に SPDX、NOTICE、SBOM、著作権表示を個別監査する。

## ADR 案: Swift-first、shared core は後から切り出す

**Status: accepted for local build — see ADR-001**
**Decision:** macOS MVP は Swift（AppKit/CoreGraphics/IOKit bridge）で実装し、gesture recognizer の純粋なデータ型・状態機械を platform-independent な module として保つ。Windows/Linux backend の必要性と public contact source が実測で確認できた段階で、Rust shared core または C++ を再評価する。

| 観点 | Swift-first | Rust shared | C++ |
|---|---|---|---|
| 速度 | macOS event callback と小規模 recognizer には十分という工学的見積り。benchmark 未実施。 | 高速。callback/alloc/FFI の設計次第。benchmark 未実施。 | 高速。benchmark 未実施。 |
| Windows 再利用 | 低い。UI/TCC/API adapter は macOS 固有。core を純粋 Swift に保つ範囲だけ再利用候補。 | 高い。core を Windows/Linux と共有しやすい。 | 高い。C ABI を設計すれば共有しやすい。 |
| Apple API / FFI | 最も自然。`NSEvent`、`CGEventTap`、`IOHIDManager` を直接扱える。 | C headers との bindgen/unsafe boundary が必要。 | C API との境界は自然だが AppKit/Swift UI 連携は別層。 |
| testability | core を pure Swift にすれば高い。UI/TCC は integration test。 | core の unit/property test が強い。 | 高いが ownership/ABI の試験面積が増える。 |
| size / build complexity | 小さく始めやすい。Swift runtime と universal build は確認が必要。 | core は小さくできるが toolchain/FFI 配布が増える。 | runtime は不要にしやすいが C++ standard library/ABI 管理が増える。 |

上表はこのリポジトリの制約からの推論で、実測値ではない。Swift-first を暫定採用する理由は、最初の不確実性が性能よりも「どの public event が実際に Magic Trackpad から届くか」と権限/TCC だからである。Windows 再利用を約束せず、`PlatformInputSource` 相当の境界とシリアライズ可能な `GestureFrame` を先に固定し、親担当の実機 probe 結果で ADR を更新する。

## 未解決・次の検証

1. 親担当の実機 probe で USB-C/Bluetooth の各接続について `NSEvent` gesture、session `CGEventTap`、`IOHIDManager` input value/report の実測を取得する。
2. contacts が得られない場合は、public vocabulary 縮小案と private API/direct distribution 案を比較してユーザー判断を求める。要件を自動縮小しない。
3. listen-only と post の許可を別々に revoke/再付与し、エラーと UX を確認する。署名・notarization・公開は別の明示的な計画ができるまで行わない。
4. Windows/Linux backend の API と license 方針は、最初の macOS probe/recognizer の後に再評価する。
