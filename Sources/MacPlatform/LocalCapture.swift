import AppKit

public struct ObservedContact: Codable {
    public let id: String
    public let x: Double
    public let y: Double
    public let phase: String
    public let isResting: Bool?
    public init(id: String, x: Double, y: Double, phase: String, isResting: Bool? = nil) {
        self.id = id; self.x = x; self.y = y; self.phase = phase; self.isResting = isResting
    }
}
public struct TouchObservation: Codable {
    public let timestamp: Double
    public let sessionID: String
    public let contacts: [ObservedContact]
    public let modifiers: [String]
    public init(timestamp: Double, sessionID: String, contacts: [ObservedContact], modifiers: [String]) {
        self.timestamp = timestamp; self.sessionID = sessionID; self.contacts = contacts; self.modifiers = modifiers
    }
}
public enum SampleFinishReason: String, Codable {
    case durationLimit, sampleLimit, waitingTimeout, exported, invalidTimestamp
}
public struct SampleRecordingMetadata: Codable {
    public let armedAt: Double?
    public let captureStartedAt: Double?
    public let captureDeadline: Double?
    public let finishedAt: Double?
    public let finishReason: SampleFinishReason?
    public let sampleCount: Int
}
public struct SampleRecorder {
    public private(set) var samples: [TouchObservation] = []
    public private(set) var recording = false
    public private(set) var waitingForContact = false
    public var active: Bool { recording || waitingForContact }
    private var armedAt: Double?
    private var startTime: Double?
    private var finishedAt: Double?
    private var finishReason: SampleFinishReason?
    public var metadata: SampleRecordingMetadata {
        .init(armedAt: armedAt, captureStartedAt: startTime, captureDeadline: startTime.map { $0 + 3 },
              finishedAt: finishedAt, finishReason: finishReason, sampleCount: samples.count)
    }
    public init() {}
    // Immediate recording is retained for callers with an already synchronized start.
    public mutating func start(at time: Double) {
        clear(); guard time.isFinite else { return }
        armedAt = time; startTime = time; recording = true
    }
    // UI callers have up to ten seconds to return the pointer and begin a fresh touch.
    // Only the following three seconds can be retained, still capped at 180 samples.
    public mutating func arm(at time: Double) {
        clear(); guard time.isFinite else { return }
        armedAt = time; waitingForContact = true
    }
    public mutating func clear() {
        samples.removeAll(keepingCapacity: false); recording = false; waitingForContact = false
        armedAt = nil; startTime = nil; finishedAt = nil; finishReason = nil
    }
    private mutating func finish(_ reason: SampleFinishReason, at time: Double) {
        recording = false; waitingForContact = false; finishReason = reason
        finishedAt = time.isFinite ? time : nil
    }
    public mutating func expire(at time: Double) {
        guard active else { return }
        guard time.isFinite else { finish(.invalidTimestamp, at: time); return }
        if waitingForContact, let armedAt, time > armedAt + 10 { finish(.waitingTimeout, at: time) }
        if recording, let startTime, time > startTime + 3 { finish(.durationLimit, at: time) }
    }
    public mutating func finishForExport(at time: Double) {
        expire(at: time)
        if active { finish(.exported, at: time) }
    }
    public mutating func append(_ sample: TouchObservation) {
        guard active else { return }
        guard sample.timestamp.isFinite, let armedAt, sample.timestamp >= armedAt else {
            finish(.invalidTimestamp, at: sample.timestamp); return
        }
        expire(at: sample.timestamp)
        guard active, sample.contacts.count <= 10 else { return }
        if waitingForContact {
            guard !sample.contacts.isEmpty, sample.contacts.allSatisfy({ $0.phase == "began" }) else { return }
            startTime = sample.timestamp; waitingForContact = false; recording = true
        }
        guard recording, let startTime, sample.timestamp >= startTime else { return }
        guard samples.count < 180 else { finish(.sampleLimit, at: sample.timestamp); return }
        samples.append(sample)
        if samples.count == 180 { finish(.sampleLimit, at: sample.timestamp) }
    }
}
public protocol CaptureAdapter: AnyObject {
    var onObservation: ((TouchObservation) -> Void)? { get set }
    func start()
    func stop()
}
// Local view touch delivery only. No transparent overlay, event suppression, raw HID decoding or private framework.
public final class TouchCaptureView: NSView, CaptureAdapter {
    public var onObservation: ((TouchObservation) -> Void)?
    public var onNativeGesture: ((String) -> Void)?
    public var onCaptureFailure: (() -> Void)?
    private var identityMap=ContactIdentityMap()
    private weak var lastTouchEvent: NSEvent?
    private var sessionID = UUID().uuidString
    private var active = false
    public override init(frame: NSRect) {
        super.init(frame: frame)
        allowedTouchTypes = [.indirect]
        // Preserve stationary holds across the driver's resting-state transitions.
        wantsRestingTouches = true
    }
    public required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
    public func start() { stop(); active = true; sessionID = UUID().uuidString }
    public func stop() { active = false; identityMap.clear(); lastTouchEvent = nil }
    private func fail() { stop(); onCaptureFailure?() }
    private func observe(_ event: NSEvent) {
        // AppKit may deliver the same event to multiple phase callbacks. Normalize its
        // full touch set once, before retiring ended IDs; timestamps alone are not identities.
        guard active, lastTouchEvent !== event else { return }
        lastTouchEvent = event
        let touches = event.touches(matching: .any, in: self)
        guard touches.count <= 10 else { fail(); return }
        var contacts: [ObservedContact] = []
        for touch in touches {
            guard let key = touch.identity as? NSObject, let contactID=identityMap.id(for:key) else { fail(); return }
            let phase: String
            switch touch.phase {
            case .began: phase = "began"
            case .moved: phase = "moved"
            case .stationary: phase = "stationary"
            case .ended: phase = "ended"
            default: phase = "cancelled"
            }
            contacts.append(.init(id: contactID, x: touch.normalizedPosition.x, y: touch.normalizedPosition.y, phase: phase, isResting: touch.isResting))
        }
        let flags: [(NSEvent.ModifierFlags, String)] = [(.command,"command"), (.control,"control"), (.option,"option"), (.shift,"shift")]
        onObservation?(.init(timestamp: event.timestamp, sessionID: sessionID, contacts: contacts.sorted { $0.id < $1.id },
                             modifiers: flags.filter { event.modifierFlags.contains($0.0) }.map { $0.1 }))
        for touch in touches where touch.phase == .ended || touch.phase == .cancelled { if let key = touch.identity as? NSObject { identityMap.remove(key) } }
    }
    public override func touchesBegan(with event: NSEvent) { observe(event); super.touchesBegan(with: event) }
    public override func touchesMoved(with event: NSEvent) { observe(event); super.touchesMoved(with: event) }
    public override func touchesEnded(with event: NSEvent) { observe(event); super.touchesEnded(with: event) }
    public override func touchesCancelled(with event: NSEvent) { observe(event); super.touchesCancelled(with: event) }
    public override func scrollWheel(with event: NSEvent) { onNativeGesture?("scroll"); super.scrollWheel(with: event) }
    public override func magnify(with event: NSEvent) { onNativeGesture?("pinch"); super.magnify(with: event) }
    public override func rotate(with event: NSEvent) { onNativeGesture?("rotate"); super.rotate(with: event) }
    public override func mouseDown(with event: NSEvent) { onNativeGesture?("click"); super.mouseDown(with: event) }
}

struct ContactIdentityMap {
    private var ids: [NSObject: String] = [:]
    var count: Int { ids.count }
    mutating func id(for identity: NSObject) -> String? {
        if let existing=ids[identity] { return existing }
        guard ids.count < 10 else { return nil }
        let id=UUID().uuidString; ids[identity]=id; return id
    }
    mutating func remove(_ identity: NSObject) { ids.removeValue(forKey:identity) }
    mutating func clear() { ids.removeAll() }
}
