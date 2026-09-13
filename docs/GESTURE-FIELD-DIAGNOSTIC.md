# Gesture field-availability diagnostic

Extends the existing user-started 30-second `GlobalInputCheck` to check what
public APIs actually deliver. This is an observation tool, not a global
contact adapter or a gesture recognizer. It never executes actions.

## AppKit fields

`gestureDetail` has separate `local` and `global` summaries. It counts exact
`gesture`, `magnify`, `rotate`, `swipe`, `beginGesture`, and `endGesture` event
kinds. Only the first four query `NSEvent.touches(matching: .any, in: nil)`.
Apple names those four as examples of eligible gesture events; our collector
conservatively leaves bookends as count-only. This is our allowlist choice,
not an assertion that Apple explicitly prohibits bookend queries.
[Apple method documentation](https://developer.apple.com/documentation/appkit/nsevent/touches(matching:in:))

- `touchesCheckedEvents`: number of queries made.
- `eventsWithTouches`: queries returning a nonempty set.
- `maxObservedTouches`: absent until a query is made; 0 means a query returned
  an empty set, not an inferred zero-finger gesture. The observed count is
  not clamped or converted into a physical finger count.
- `phaseCounts`: bounded totals of documented touch phases. Each event
  processes at most 10 touches. Oversized sets skip phase processing and
  increment `oversizedTouchEvents`; their actual set count is still reported.
  Unknown phases have no fabricated substitute and are not counted.
- Each counter saturates at 1,000,000 with `countersSaturated` set. Missing
  event-kind entries mean unobserved, not unsupported. Quartz has no entry.

No identity, location, pressure, timestamps per event, app name, or raw touch
sequence is retained. `NSTouch` objects exist transiently only while querying
an eligible event. The returned set may include ended or resting contacts;
its size is not necessarily the number currently touching the surface.
Mouse, key, and scroll events are never queried for touches. Local events are
returned unchanged and global events are only observed.
[Apple event monitors](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/EventOverview/MonitoringEvents/MonitoringEvents.html)

## USB HID metadata

`hidUsageObservation` records only public input-value callback usage page/usage
IDs, never their values or report bytes. The manager matches all four exact
properties: Apple VID `0x05ac`, reference PID `0x0324`, product `Magic Trackpad`,
and transport `USB`. Initial collections (at most 16) and every callback's
device are checked against the same metadata. Missing metadata is unavailable;
Bluetooth is not included by selecting the first device from an unordered set.

Input Monitoring is preflighted without requesting new permission. The manager
opens with options 0 (non-seizing), registers only an input-value callback,
and performs no report/feature access, writes, mode switches, or decoding.
Open status is recorded if an open was attempted. Unavailable reasons are
`inputMonitoringNotGranted`, `referenceUSBDeviceNotFound`,
`referenceMatchMismatch`, or `openFailed`.

`inputValueEvents` and `digitizerUsageEvents` are absent when unavailable.
When available they count actual callbacks, including 0 if none arrived.
`digitizerUsageEvents` independently counts page `0x0d` callbacks even after
the 64-distinct-usage dictionary fills; `distinctUsagesTruncated` then becomes
true. All totals saturate at 1,000,000 with `countersSaturated` set.
Usage IDs alone establish neither contact fields nor finger counts.
[Apple IOHIDManager](https://developer.apple.com/documentation/iokit/iohidmanager)

## Lifetime and interpretation

Both sources receive the same absolute monotonic deadline. AppKit and HID
callbacks check it before querying touch fields or HID metadata; accumulators
also reject late callbacks. Stop, permission/lifecycle cancellation, restart,
and deinitialization remove monitors, invalidate the tap, unregister callbacks,
close/unschedule the HID manager, and cease collection. An unsuccessful HID
open also cleans up its registrations. No held keys/buttons are created.

The new report fields are optional additions to diagnostic schema 1, and old
reports still decode. A count-only pointer trial does not establish global
tap/hold/swipe support. Neither monitor creation nor a successful HID open
proves that useful fields will arrive. Global touch delivery must be measured;
we do not treat a lack of documentation guaranteeing it as a hardware result.
Endpoint health and aggregate counts do not measure event loss, continuous
permission health, physical latency, or gesture chronology. The counters are
not a substitute for a bounded contact replay if global contacts become available.

## Next physical comparison

After the parent verifies the rebuilt app's permission and source setup, start
its existing 30-second diagnostic. With the pointer over the app, perform three
light three-finger taps, one light one-second three-finger hold, then a short
three-finger horizontal swipe. Switch to Finder and repeat the same operations
with the pointer over Finder. Wait for automatic save; no Export operation is
needed. Report any native gesture effect separately. This comparison establishes
field availability by channel, not individual gesture recognition or action
execution. Do not claim any physical result before reading that saved report.


## Unexecuted hardware failure check

The real `IOHIDManagerOpen` error cleanup is statically reviewed, not covered by
an automated injected IOKit failure. If an authorized hardware session produces
`openFailed`, expect its actual nonzero `openStatus`, absent event totals, no HID
callbacks after stop, and a later fresh start to reopen after recovery. Do not
force failure by seizing the device, escalating privilege, changing the driver,
or altering system security. Permission-denied preflight is separately verified
and must not be labeled an open-failure-path test.
