import Testing
@testable import MacPlatform

final class FakeBackend: ActionBackend {
    var calls: [SafeAction] = []
    func perform(_ action: SafeAction) throws { calls.append(action) }
}
struct SafetyTests {
    @Test func testPreviewNeverExecutesAndKeyboardNeverInjects() throws {
        let backend = FakeBackend(); let executor = SafeActionExecutor(backend: backend)
        #expect(throws: (any Error).self) { try executor.execute(.beep, origin: .preview, now: 1) }
        #expect(throws: (any Error).self) { try executor.execute(.keyboardShortcut, origin: .manualTest, now: 2) }
        #expect(backend.calls.isEmpty)
    }
    @Test func testSafeActionsAndCooldown() throws {
        let backend = FakeBackend(); let executor = SafeActionExecutor(backend: backend)
        try executor.execute(.beep, origin: .manualTest, now: 1)
        #expect(throws: (any Error).self) { try executor.execute(.beep, origin: .manualTest, now: 1.1) }
        try executor.execute(.openURL("https://example.com"), origin: .manualTest, now: 2)
        #expect(backend.calls.count == 2)
    }
    @Test func testRejectUnsafeURLsAndNames() {
        for value in ["file:///tmp/code", "javascript:alert(1)", "https://u:p@example.com", "https://example.com/\nfoo"] {
            #expect(throws: (any Error).self) { try SafeAction.openURL(value).validate() }
        }
        #expect(throws: (any Error).self) { try SafeAction.launchApp("/tmp/app").validate() }
        #expect(throws: (any Error).self) { try SafeAction.appleShortcut("").validate() }
    }
    @Test func testLifecycleCancelsAndNeedsExplicitRestart() {
        var cancelled = 0
        let lifecycle = CaptureLifecycle { cancelled += 1 }
        lifecycle.start(); #expect(lifecycle.active)
        for event in LifecycleEvent.allCases {
            lifecycle.start(); lifecycle.handle(event)
            #expect(!lifecycle.active)
        }
        #expect(cancelled == LifecycleEvent.allCases.count)
    }
    @Test func testPermissionChangeCancelsIncludingGrant() {
        var cancelled = 0
        let lifecycle = CaptureLifecycle { cancelled += 1 }
        lifecycle.start()
        lifecycle.permissionsChanged(.init(inputMonitoring: false, accessibility: false))
        #expect(!lifecycle.active)
        lifecycle.start()
        lifecycle.permissionsChanged(.init(inputMonitoring: true, accessibility: false))
        #expect(!lifecycle.active)
        #expect(cancelled == 2)
    }
    @Test func testDiagnosticsBoundedNoPayloadAPI() {
        var log = SafeDiagnostics(capacity: 8)
        for _ in 0..<10000 { log.record(.frame) }
        #expect(log.events.count == 8)
        #expect(log.total == 10000)
    }
}
