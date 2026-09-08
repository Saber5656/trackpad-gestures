import AppKit

public enum ProbeEventLoop {
    // AppKit monitors participate in application dispatch, not just CFRunLoop sources.
    // No activation, overlay, fabricated event or system event posting is used here.
    @MainActor public static func run(seconds: Double) {
        guard seconds.isFinite, seconds > 0 else { return }
        let app = NSApplication.shared
        app.finishLaunching()
        let deadline = ProcessInfo.processInfo.systemUptime + min(seconds, 60)
        while ProcessInfo.processInfo.systemUptime < deadline {
            autoreleasepool {
                let remaining = deadline - ProcessInfo.processInfo.systemUptime
                guard remaining > 0 else { return }
                if let event = app.nextEvent(matching: .any, until: Date().addingTimeInterval(min(remaining, 0.05)), inMode: .default, dequeue: true) {
                    app.sendEvent(event)
                }
            }
        }
    }
}
