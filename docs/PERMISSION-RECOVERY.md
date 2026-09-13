# Development build Input Monitoring recovery

## Observed failure and cause (2026-09-13)

After replacing the local development binary, System Settings showed Input
Monitoring ON, but `CGPreflightListenEventAccess()` returned false even after
normal restart. Operator-authenticated OFF/ON did not repair it. Selecting the
updated bundle with Add while the old entry existed also did not repair it.

The running process path and executable SHA were verified to match the intended
current `dist/TrackpadGestures.app`. Read-only `codesign -d -r-` inspection found
hash-based designated requirements, with no signing operation performed:

| Executable | SHA-256 prefix | Designated cdhash |
| --- | --- | --- |
| Previous, permission-granted build | `76ddcf6aa37a` | `a38e10243bd8bd944a0d5fa4f15ab89df6287c01` |
| Current field-diagnostic build | `81c736f12b51` | `3ac28e39602488ea58968fbc7f18b7b885d4b0ac` |

The targeted macOS TCC log explicitly recorded `Failed to match existing code
requirement` for `local.trackpad-gestures.studio` / `kTCCServiceListenEvent`,
with these old and new hashes and validation status `-67050`. This establishes
an old-code requirement mismatch, not a failed operator password or wrong
running binary. The file chooser's remembered item also pointed to the preserved
previous bundle; selecting a familiar display name alone is insufficient.

Apple explains designated requirements as code identity, and its DTS guidance
notes problems between ad-hoc development signing and TCC. These sources explain
the mechanism; the exact diagnosis above comes from this Mac's own log.
[Apple TN3127](https://developer.apple.com/documentation/technotes/tn3127-inside-code-signing-requirements),
[Apple DTS](https://developer.apple.com/forums/thread/125438).

## Recovery verified on this Mac

1. Normally quit the app and verify its process exited. Keep the tested binary
   unchanged while restoring permission.
2. Reset only this app's existing Input Monitoring registration with the
   documented macOS privacy utility:
   `tccutil reset ListenEvent local.trackpad-gestures.studio`.
   The installed `tccutil(1)` manual documents service and bundle-specific reset.
   This removes an old decision; it does not grant access.
3. Reopen the Input Monitoring settings page and verify only this app's entry
   disappeared. Logi Options+ remained ON. The profile file hash was unchanged.
4. Add the exact current `dist/TrackpadGestures.app` through System Settings.
   Use Go to Folder to resolve its current full local path, and inspect the
   selected URL before Open. Do not choose the remembered previous build.
5. Launch the exact current bundle. Verify actual app preflight, not only the
   Settings switch. Then start and cancel a short diagnostic to verify the
   CG tap and non-seizing reference-USB HID open in that process.

This sequence restored Input Monitoring in the current app. The existing
operator authentication was sufficient for the final Add; no additional
password request was needed. No credential was read/entered by the agent,
no private TCC database was edited, no privilege escalation or extra permission
was used, and Accessibility remained false. All profile bytes were preserved.

## Verified setup and remaining acceptance

The new cancelled setup report `80A0ED36-0B85-4CA7-B2C7-EE422C12C7F1` spans
5.796232791617513 seconds, UTC 13:32:52–13:32:58. Input Monitoring is true at
both endpoints, both AppKit monitors exist, the CG tap is enabled at both
endpoints, and 57 dispatch ticks were observed. `hidUsageObservation` reports
available true, USB transport, and successful actual open status 0.
SHA-256: `ca461322d51f749fa8b4add92a742e6b4a560e8faa4c0a34370d488cbb6dc3df`.
No physical gesture was requested during this setup; zero callbacks are not a
negative hardware result. This validates the strict reference-device match and
actual open path, not tap/hold/swipe recognition, input loss, or coexistence.

A stable development/distribution signing identity is a future product concern;
no identity creation, signing, Apple Developer authentication, notarization or
publication is authorized or performed here. The current observation executable
remains frozen for the physical comparison. Do not rebuild merely to update
these evidence documents and invalidate the restored permission again.
