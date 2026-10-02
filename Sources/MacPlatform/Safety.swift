import AppKit
import ApplicationServices

public struct PermissionSnapshot: Equatable {
    public let inputMonitoring: Bool
    public let accessibility: Bool
    public init(inputMonitoring: Bool, accessibility: Bool) {
        self.inputMonitoring = inputMonitoring; self.accessibility = accessibility
    }
    public static func current() -> Self { .init(inputMonitoring: CGPreflightListenEventAccess(), accessibility: AXIsProcessTrusted()) }
}
public enum LifecycleEvent: String, CaseIterable {
    case disable, disconnect, sleep, resume, lock, unlock, permissionChanged, shutdown, configurationChanged, appChanged, captureExpired
}
public final class CaptureLifecycle {
    public private(set) var active = false
    private var permissions: PermissionSnapshot?
    private let cancel: () -> Void
    public init(cancel: @escaping () -> Void) { self.cancel = cancel }
    public func start() { active = true }
    public func handle(_ event: LifecycleEvent) { active = false; cancel() }
    public func permissionsChanged(_ next: PermissionSnapshot) {
        if permissions != next { permissions = next; handle(.permissionChanged) }
    }
}
public enum DiagnosticEvent: String { case frame, recognized, rejected, cancelled, permissionChanged, deviceChanged, captureStopped, actionDispatched, actionFailed }
public struct SafeDiagnostics {
    public private(set) var events: [DiagnosticEvent] = []
    public private(set) var total: UInt64 = 0
    private let capacity: Int
    public init(capacity: Int = 64) { self.capacity = min(256, max(1, capacity)) }
    public mutating func record(_ event: DiagnosticEvent) {
        total = total == UInt64.max ? total : total + 1
        if events.count == capacity { events.removeFirst() }; events.append(event)
    }
}
public enum SafeAction: Equatable {
    case beep, openURL(String), launchApp(String), focusApp(String), hideApp(String), appleShortcut(String), keyboardShortcut
    public func validate() throws {
        switch self {
        case .beep: break
        case .keyboardShortcut: throw ActionFailure.unsupported
        case .openURL(let value):
            guard value.utf8.count <= 2048, !value.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }),
                  let url = URLComponents(string: value), ["https", "http"].contains(url.scheme?.lowercased() ?? ""),
                  let host = url.host, !host.isEmpty, url.user == nil, url.password == nil else { throw ActionFailure.invalid }
        case .launchApp(let id), .focusApp(let id), .hideApp(let id):
            guard id.utf8.count <= 200, id.contains("."), id.range(of: "^[A-Za-z0-9-]+(\\.[A-Za-z0-9-]+)+$", options: .regularExpression) != nil else { throw ActionFailure.invalid }
        case .appleShortcut(let name):
            guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, name.utf8.count <= 200,
                  !name.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) else { throw ActionFailure.invalid }
        }
    }
}
public enum ActionOrigin { case preview, manualTest }
public enum ActionFailure: Error, LocalizedError {
    case unsupported, previewOnly, invalid, cooldown, unavailable
    public var errorDescription: String? {
        switch self {
        case .unsupported: return "Unsupported: keyboard injection is disabled until forced-termination release safety is proven."
        case .previewOnly: return "Preview never executes an action."
        case .invalid: return "Invalid action data."
        case .cooldown: return "Action cooldown: wait at least 500 ms."
        case .unavailable: return "The requested application or system handler is unavailable."
        }
    }
}
public protocol ActionBackend { func perform(_ action: SafeAction) throws }
public final class SafeActionExecutor {
    private let backend: ActionBackend
    private var lastTime: Double?
    public init(backend: ActionBackend) { self.backend = backend }
    public func execute(_ action: SafeAction, origin: ActionOrigin, now: Double) throws {
        guard origin == .manualTest else { throw ActionFailure.previewOnly }
        try action.validate()
        guard now.isFinite, now >= 0 else { throw ActionFailure.invalid }
        if let lastTime, now - lastTime < 0.5 { throw ActionFailure.cooldown }
        // Consume the slot before dispatch, including failed dispatches.
        lastTime = now
        try backend.perform(action)
    }
}
func requestApplicationHide(isHidden: @escaping () -> Bool, hide: () -> Bool,
                            schedule: @escaping (TimeInterval, @escaping () -> Void) -> Void = { delay, work in
                                DispatchQueue.main.asyncAfter(deadline: .now()+delay, execute: work)
                            }, completion: @escaping (Bool) -> Void) {
    if isHidden() || hide() || isHidden() { completion(true); return }
    // hide() can return false before macOS publishes the hidden state.
    func check(_ attemptsRemaining: Int) {
        schedule(0.05) {
            if isHidden() { completion(true) }
            else if attemptsRemaining > 1 { check(attemptsRemaining-1) }
            else { completion(false) }
        }
    }
    check(20)
}
public final class WorkspaceActionBackend: ActionBackend {
    public var completion: ((Bool) -> Void)?
    public init() {}
    public func perform(_ action: SafeAction) throws {
        guard Thread.isMainThread else { throw ActionFailure.unavailable }
        try action.validate()
        switch action {
        case .beep: NSSound.beep(); completion?(true)
        case .openURL(let value):
            guard let url = URL(string: value), NSWorkspace.shared.open(url) else { throw ActionFailure.unavailable }
            completion?(true)
        case .launchApp(let id):
            guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) else { throw ActionFailure.unavailable }
            NSWorkspace.shared.openApplication(at: url, configuration: .init()) { [weak self] app, error in
                DispatchQueue.main.async { self?.completion?(app != nil && error == nil) }
            }
        case .focusApp(let id):
            guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: id).first,
                  app.activate(options: []) else { throw ActionFailure.unavailable }
            completion?(true)
        case .hideApp(let id):
            guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: id).first else { throw ActionFailure.unavailable }
            requestApplicationHide(isHidden: { app.isHidden }, hide: { app.hide() }) { [weak self] success in
                self?.completion?(success)
            }
        case .appleShortcut(let name):
            var parts = URLComponents(); parts.scheme = "shortcuts"; parts.host = "run-shortcut"
            parts.queryItems = [.init(name: "name", value: name)]
            guard let url = parts.url, NSWorkspace.shared.open(url) else { throw ActionFailure.unavailable }
            // Handler dispatch only; does not claim the shortcut completed.
            completion?(true)
        case .keyboardShortcut: throw ActionFailure.unsupported
        }
    }
}
