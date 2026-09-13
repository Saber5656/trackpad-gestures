# Physical input control — 2026-09-13

The operator pressed the app's diagnostic button, moved the pointer over the app,
switched to Finder and moved it again, then reported completion. A new, completed
report was automatically saved at 21:23:02 JST. Its recording window was
21:22:32–21:23:02 JST (30 monotonic seconds).

## Observed result

| Route | Pointer event callbacks | Other callbacks |
|---|---:|---|
| AppKit local monitor | 257 | 302 in the generic gesture category |
| AppKit global monitor | 442 | 4 button-event callbacks |
| CG listen-only session tap | 702 | 4 button-event callbacks |

Input Monitoring and tap-enabled endpoints were true; Accessibility was false.
Both AppKit monitors were created. There were 67 own-app-foreground and 82
background status samples, and 300 common-mode timer ticks. No counter saturation
was reported. The window-server mouse-moved counter increased by 700, with two
left-button down and two up events; its scroll counter did not change.

Source report SHA-256:
`8a6722f41524d6d4f103939a7c588f972fa5844ee73ce69479c9821a8b01b511`.
Check ID: `220B2BF4-0441-4656-BF28-396F5E968C89`.
Raw count-only evidence is retained privately, separately from earlier zero-count
and deliberately cancelled setup reports. The operator's completion statement is
preserved with it.

## What this establishes

Ordinary pointer input reached this app's local and other-app monitoring routes
during an operator-confirmed physical test. The GUI permission context and its
normal event loop have now been exercised with real input; the previous all-zero
CLI result is no longer the only external-input evidence. The original CLI zero
result remains unexplained and is not retroactively attributed to one cause.

The host was rechecked: macOS 26.6.2 (25G83), arm64. The operator reports using the
connected Magic Trackpad. These AppKit/CG routes have no per-device attribution,
so the counts alone do not certify USB transport or exclude other input devices.

## What it does not establish

- A callback count is not a count of gestures. In particular, `local.gesture=302`
  does not mean 302 taps or successful recognitions; the old report groups several
  event kinds and retains no contact-count fields.
- The routes overlap and can coalesce/deliver events differently. Neither their
  sum nor differences establish event loss, duplicate native input, physical
  sampling frequency or latency. Four button callbacks are not four full clicks.
- Finder is the operator-reported context. No application names or document data
  are captured by the diagnostic to independently identify the target app.
- Global finger count, contact identity/coordinates, tap/hold/swipe recognition,
  action execution, native scroll/pinch coexistence and hardware lifecycle recovery
  remain unverified. This pointer-only test did not exercise those gestures.

Next, add bounded field-availability diagnostics for actual AppKit gesture events
and non-seizing USB HID usage callbacks before requesting the gesture-specific
physical test. Use only returned fields. Do not infer touches from pointer events,
and do not adopt private APIs or narrow the product vocabulary without the required
distribution/product decision.
