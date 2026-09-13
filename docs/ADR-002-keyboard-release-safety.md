# ADR-002: Keyboard release safety remains unproven

Status: research recorded; keyboard injection remains unsupported. 2026-09-13.

## Requirement and decision

Any key or button synthesized as down must be released after abnormal application termination, including forced termination. Ordinary keys and mouse buttons matter as well as modifiers. No tested design yet establishes this whole requirement. Keep `SafeAction.keyboardShortcut` rejected; do not silently replace a keyboard assignment with an Apple Shortcut or menu action.

This investigation changes no permissions and posts no OS input. It is a process failure experiment, not a measurement of macOS keyboard state. The product remains local-only, with its existing manual handler actions.

## Public API evidence

Apple's [keyboard-event initializer](https://developer.apple.com/documentation/coregraphics/cgevent/init(keyboardeventsource:virtualkey:keydown:)) creates either a down or an up event. Its example uses separate press and release events. [CGEvent posting](https://developer.apple.com/documentation/coregraphics/cgevent/post(tap:)) submits one event; the reviewed documentation does not specify an atomic down/up transaction or a rollback on process death. These are limits of the documented guarantee found, not proof that every missed up produces a stuck physical key.

The [flags property](https://developer.apple.com/documentation/coregraphics/cgevent/flags) describes event attributes. Adding Command flags does not turn the ordinary key's down event into a complete down/up pair. A flagged mouse-down likewise still needs a mouse-up. No claim of universal target-app support, unchanged physical modifier state, atomicity or automatic release follows from this property.

The installed public `CGEventSource.h`, `CGEvent.h`, `signal(2)`, `sigaction(2)` and `launchd.plist(5)` were also inspected. SIGKILL cannot invoke a user-space cleanup handler. Source/tap lifetime documentation reviewed here does not promise to undo previously posted down events. [NSXPCConnection](https://developer.apple.com/documentation/foundation/nsxpcconnection) offers interruption/invalidation callbacks in a surviving process; that is not an unconditional release guarantee if the receiver also dies.

## Designs compared

| Design | What it can address | Remaining proof obligation |
|---|---|---|
| Down/up in the app, with `defer` or a signal handler | Ordinary return/error cleanup | No code runs after SIGKILL between posts |
| Independent helper owns the complete request | Main-app death while that helper survives | Helper death, process-group termination, actual XPC/launchd lifetime, permission loss and OS delivery |
| Modifier flags on primary key/button events | Potentially avoids separate modifier posts for supported targets | Primary down/up still separate; modifier and target behavior need validation |
| Release on source/tap teardown or helper restart | Candidate recovery mechanism only | No reviewed public contract guarantees rollback or replay of an undelivered release |

Physical keys held by the user require separate coexistence testing. No blanket release of all keys is acceptable as a substitute: it could interfere with the user's physical input. This experiment did not test that interaction or permission revocation.

## Reproducible counterexamples

Run `python3 -m unittest discover -s Tests/KeyboardSafetyTests -v`.

Three experiments use Python child processes that write only DOWN/UP text markers to private temporary files. A pipe trigger permits DOWN; an open writer prevents UP. The test waits for DOWN before killing a process. UP becomes possible only after pipe EOF, so the experiment does not race a fixed sleep:

1. Kill the only emitting process after DOWN: UP is absent after it is reaped.
2. Kill a separate main-process model: a surviving helper observes EOF and writes UP.
3. Kill the helper after DOWN: UP is absent after it is reaped.

The test owns both Popen objects in the two-process cases and closes/reaps them in `finally`. Marker waits have monotonic deadlines. Temporary files contain no user input. The two processes are siblings owned by the test; this is neither an installed helper nor an XPC/launchd experiment. Success means the expected process-model result occurred, not that keyboard injection is safe. Existing earlier experiment logs were preserved privately.

## Next implementation boundary

A surviving helper may improve recovery from main-app failure, but its complete failure/permission model and actual OS behavior still need validation. Enabling injection while accepting an unclosed release risk would change the agreed security requirement and requires a user decision after a concrete design is prepared. No such relaxation was made here. Continue capture/core and allowlisted handler work independently.
