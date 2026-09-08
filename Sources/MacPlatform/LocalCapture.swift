import AppKit

public struct ObservedContact: Codable {
    public let id: String
    public let x: Double
    public let y: Double
    public let phase: String
    public init(id: String, x: Double, y: Double, phase: String) { self.id = id; self.x = x; self.y = y; self.phase = phase }
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
public struct SampleRecorder {
    public private(set) var samples: [TouchObservation] = []
    public private(set) var recording = false
    private var startTime = 0.0
    public init() {}
    public mutating func start(at time: Double) { clear(); startTime = time; recording = true }
    public mutating func clear() { samples.removeAll(keepingCapacity: false); recording = false }
    public mutating func expire(at time: Double) { if time > startTime + 3 { recording=false } }
    public mutating func append(_ sample: TouchObservation) {
        guard recording else { return }
        guard sample.timestamp.isFinite, sample.timestamp >= startTime, sample.timestamp <= startTime + 3 else { recording = false; return }
        guard sample.contacts.count <= 10 else { return }
        guard samples.count < 180 else { recording = false; return }
        samples.append(sample)
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
    private var sessionID = UUID().uuidString
    private var active = false
    public override init(frame: NSRect) {
        super.init(frame: frame)
        allowedTouchTypes = [.indirect]
        wantsRestingTouches = false
    }
    public required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
    public func start() { stop(); active = true; sessionID = UUID().uuidString }
    public func stop() { active = false; identityMap.clear() }
    private func fail() { stop(); onCaptureFailure?() }
    private func observe(_ event: NSEvent) {
        guard active else { return }
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
            contacts.append(.init(id: contactID, x: touch.normalizedPosition.x, y: touch.normalizedPosition.y, phase: phase))
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
