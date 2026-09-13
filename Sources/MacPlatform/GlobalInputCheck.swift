import AppKit
import ApplicationServices
import Combine

public struct InputCheckHealth: Codable {
    public var inputMonitoring: Bool
    public var accessibility: Bool
    public var ownAppActive: Bool
    public var localMonitor: Bool
    public var globalMonitor: Bool
    public var tapEnabled: Bool?
    public var dispatchTicks: Int
    public var sessionAvailable: Bool
    public var windowServerCounters: [String: UInt32]?
}

public protocol InputCheckSource: AnyObject {
    func start(onEvent: @escaping (InputCheckChannel, InputCheckKind) -> Void)
    func snapshot() -> InputCheckHealth
    func stop()
}

public struct InputCheckReport: Codable {
    public let schemaVersion: Int
    public let id: String
    public let startedAt: String
    public let finishedAt: String
    public let durationSeconds: Double
    public let reason: InputCheckEnd
    public let counts: [String: Int]
    public let saturated: Bool
    public let foregroundSamples: Int
    public let backgroundSamples: Int
    public let healthBefore: InputCheckHealth
    public let healthAfter: InputCheckHealth
    public let windowServerDelta: [String: UInt32]?
    public let limitations: [String]
    public func pointerCount(channel: InputCheckChannel) -> Int? {
        let available: Bool
        switch channel {
        case .local: available = healthBefore.localMonitor
        case .global: available = healthBefore.globalMonitor
        case .quartz: available = healthBefore.tapEnabled != nil
        }
        return available ? counts[channel.rawValue + ".pointer", default: 0] : nil
    }
}

// Called on the app's main thread; the source also delivers on its main run loop.
public final class GlobalInputCheck: ObservableObject {
    @Published public private(set) var isRunning = false
    @Published public private(set) var remaining = 0
    @Published public private(set) var message = "30秒間、入力の種類と件数だけを確認します。終了時に自動保存します。"
    @Published public private(set) var report: InputCheckReport?
    @Published public private(set) var saveSucceeded: Bool?
    private let source: InputCheckSource
    private let clock: () -> Double
    private let save: (Data) throws -> Void
    private let automaticallyTick: Bool
    private var window: InputCheckWindow?
    private var timer: Timer?
    private var healthBefore: InputCheckHealth?
    private var startedAt = ""
    private var id = ""
    private var foregroundSamples = 0
    private var backgroundSamples = 0

    public init(source: InputCheckSource = PublicInputCheckSource(),
                clock: @escaping () -> Double = { ProcessInfo.processInfo.systemUptime },
                save: @escaping (Data) throws -> Void, automaticallyTick: Bool = true) {
        self.source = source; self.clock = clock; self.save = save; self.automaticallyTick = automaticallyTick
    }
    public func start() {
        guard !isRunning else { return }
        report = nil; saveSucceeded = nil; id = UUID().uuidString
        startedAt = ISO8601DateFormatter().string(from: Date())
        window = InputCheckWindow(start: clock()); foregroundSamples = 0; backgroundSamples = 0
        isRunning = true; remaining = 30
        source.start { [weak self] channel, kind in
            guard let self, self.isRunning else { return }
            self.window?.record(channel: channel, kind: kind, at: self.clock())
        }
        healthBefore = source.snapshot()
        message = "記録中です。Finderへ切り替えて操作してください。キー・座標・画面内容は保存しません。"
        if automaticallyTick {
            let timer = Timer(timeInterval: 0.2, repeats: true) { [weak self] _ in self?.tick() }
            RunLoop.main.add(timer, forMode: .common); self.timer = timer
        }
    }
    public func tick() {
        guard isRunning, let window, let healthBefore else { return }
        let now = clock(), health = source.snapshot()
        if health.inputMonitoring != healthBefore.inputMonitoring || health.accessibility != healthBefore.accessibility {
            stop(reason: .permissionChanged); return
        }
        if window.expired(at: now) { stop(reason: .completed); return }
        if health.ownAppActive { foregroundSamples = min(150, foregroundSamples + 1) }
        else { backgroundSamples = min(150, backgroundSamples + 1) }
        remaining = Int(ceil(max(0, InputCheckWindow.limit - (now - window.start))))
    }
    public func stop(reason: InputCheckEnd) {
        guard isRunning, var window, let healthBefore else { return }
        isRunning = false; timer?.invalidate(); timer = nil
        window.finish(reason: reason, at: clock()); self.window = window; remaining = 0
        let healthAfter = source.snapshot()
        source.stop()
        let delta = healthBefore.windowServerCounters.flatMap { before in
            healthAfter.windowServerCounters.map { after in
                after.reduce(into: [String: UInt32]()) { result, entry in
                    if let initial = before[entry.key] { result[entry.key] = entry.value &- initial }
                }
            }
        }
        let report = InputCheckReport(schemaVersion: 1, id: id, startedAt: startedAt,
            finishedAt: ISO8601DateFormatter().string(from: Date()), durationSeconds: window.duration,
            reason: reason, counts: window.counts, saturated: window.saturated,
            foregroundSamples: foregroundSamples, backgroundSamples: backgroundSamples,
            healthBefore: healthBefore, healthAfter: healthAfter, windowServerDelta: delta,
            limitations: ["Count-only public API diagnostic; no contact capture or action execution",
                "Channels may observe the same input; do not add their counts",
                "Session counters do not establish physical origin, device identity or event loss",
                "Zero counts do not prove unsupported gestures; endpoint health is not continuous health",
                "Foreground/background samples are status observations, not event attribution or exact durations"])
        self.report = report
        do {
            let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try save(encoder.encode(report)); saveSucceeded = true
            message = reason == .completed ? "診断が終了し、自動保存しました。追加の保存操作は不要です。" : "診断を中断しました。中断理由と件数を自動保存しました。"
        } catch {
            saveSucceeded = false; message = "診断は終了しましたが、自動保存に失敗しました。結果はこの画面に残っています。"
        }
    }
    deinit { timer?.invalidate(); source.stop() }
}

public final class PublicInputCheckSource: InputCheckSource {
    private var local: Any?
    private var global: Any?
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var timer: Timer?
    private var ticks = 0
    private var onEvent: ((InputCheckChannel, InputCheckKind) -> Void)?
    public init() {}
    public func start(onEvent: @escaping (InputCheckChannel, InputCheckKind) -> Void) {
        stop(); self.onEvent = onEvent; ticks = 0
        let mask: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged,
            .leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp, .otherMouseDown, .otherMouseUp,
            .scrollWheel, .gesture, .magnify, .rotate, .swipe, .beginGesture, .endGesture]
        local = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
            self?.onEvent?(.local, Self.kind(event.type)); return event
        }
        global = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] event in
            self?.onEvent?(.global, Self.kind(event.type))
        }
        if CGPreflightListenEventAccess() {
            let types: [CGEventType] = [.mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged,
                .leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp, .otherMouseDown, .otherMouseUp, .scrollWheel]
            let mask = types.reduce(UInt64(0)) { $0 | (1 << $1.rawValue) }
            tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .tailAppendEventTap, options: .listenOnly,
                eventsOfInterest: mask, callback: { _, type, event, info in
                    if let info, let nsType = NSEvent.EventType(rawValue: UInt(type.rawValue)) {
                        let instance = Unmanaged<PublicInputCheckSource>.fromOpaque(info).takeUnretainedValue()
                        instance.onEvent?(.quartz, PublicInputCheckSource.kind(nsType))
                    }
                    return Unmanaged.passUnretained(event)
                }, userInfo: Unmanaged.passUnretained(self).toOpaque())
            if let tap {
                runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
                CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
            }
        }
        let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self else { return }; self.ticks = min(300, self.ticks + 1)
        }
        RunLoop.main.add(timer, forMode: .common); self.timer = timer
    }
    private static func kind(_ type: NSEvent.EventType) -> InputCheckKind {
        switch type {
        case .mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged: return .pointer
        case .leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp, .otherMouseDown, .otherMouseUp: return .click
        case .scrollWheel: return .scroll
        default: return .gesture
        }
    }
    public func snapshot() -> InputCheckHealth {
        let available = CGSessionCopyCurrentDictionary() != nil
        let types: [(String, CGEventType)] = [("mouseMoved", .mouseMoved), ("leftMouseDown", .leftMouseDown),
            ("leftMouseUp", .leftMouseUp), ("scrollWheel", .scrollWheel)]
        let counters = available ? Dictionary(uniqueKeysWithValues: types.map {
            ($0.0, CGEventSource.counterForEventType(.combinedSessionState, eventType: $0.1))
        }) : nil
        return .init(inputMonitoring: CGPreflightListenEventAccess(), accessibility: AXIsProcessTrusted(),
            ownAppActive: NSApp?.isActive ?? false, localMonitor: local != nil, globalMonitor: global != nil,
            tapEnabled: tap.map { CGEvent.tapIsEnabled(tap: $0) }, dispatchTicks: ticks,
            sessionAvailable: available, windowServerCounters: counters)
    }
    public func stop() {
        timer?.invalidate(); timer = nil
        if let local { NSEvent.removeMonitor(local) }; local = nil
        if let global { NSEvent.removeMonitor(global) }; global = nil
        if let runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes) }; runLoopSource = nil
        if let tap { CFMachPortInvalidate(tap) }; tap = nil
        onEvent = nil
    }
    deinit { stop() }
}
