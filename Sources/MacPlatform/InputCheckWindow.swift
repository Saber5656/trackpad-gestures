import Foundation

public enum InputCheckChannel: String, CaseIterable, Sendable { case local, global, quartz }
public enum InputCheckKind: String, CaseIterable, Sendable { case pointer, click, scroll, gesture }
public enum InputCheckEnd: String, Codable, Sendable {
    case completed, cancelled, permissionChanged, sleepOrLock, deviceChanged, appExit
}

// Exact public event kinds. The collector conservatively queries touches on the four
// examples explicitly named in Apple's method documentation; bookends are count-only.
public enum GestureEventKind: String, CaseIterable, Sendable, Codable {
    case gesture, magnify, rotate, swipe, beginGesture, endGesture
}
public enum TouchPhaseKind: String, CaseIterable, Sendable, Codable {
    case began, moved, stationary, ended, cancelled
}

// Per-channel, bounded summary of gesture-kind events actually delivered, and, only for the
// event kinds where touches(matching:in:) is valid, whether those events carried NSTouch data.
// Missing eventKindCounts keys are unobserved kinds, not zero-finger gestures.
public struct GestureChannelSummary: Codable, Sendable, Equatable {
    public private(set) var eventKindCounts: [String: Int] = [:]
    public private(set) var touchesCheckedEvents = 0
    public private(set) var eventsWithTouches = 0
    public private(set) var maxObservedTouches: Int?
    public private(set) var phaseCounts: [String: Int] = [:]
    public private(set) var oversizedTouchEvents = 0
    public private(set) var countersSaturated = false
    static let touchCap = 10
    mutating func record(kind: GestureEventKind, touchesChecked: Bool, touchCount: Int, phases: [TouchPhaseKind]) {
        let previous = eventKindCounts[kind.rawValue, default: 0]
        if previous < 1_000_000 { eventKindCounts[kind.rawValue] = previous + 1 } else { countersSaturated = true }
        guard touchesChecked else { return }
        guard touchCount >= 0 else { return }
        if touchesCheckedEvents < 1_000_000 { touchesCheckedEvents += 1 } else { countersSaturated = true }
        maxObservedTouches = max(maxObservedTouches ?? 0, touchCount)
        if touchCount > 0 {
            if eventsWithTouches < 1_000_000 { eventsWithTouches += 1 } else { countersSaturated = true }
        }
        guard touchCount <= Self.touchCap, phases.count <= Self.touchCap else {
            if oversizedTouchEvents < 1_000_000 { oversizedTouchEvents += 1 } else { countersSaturated = true }
            return
        }
        for phase in phases.prefix(Self.touchCap) {
            let previous = phaseCounts[phase.rawValue, default: 0]
            if previous < 1_000_000 { phaseCounts[phase.rawValue] = previous + 1 } else { countersSaturated = true }
        }
    }
}

// A fixed vocabulary of 12 counters, with no event payloads or contact data.
public struct InputCheckWindow {
    public static let limit: Double = 30
    public let start: Double
    public private(set) var counts: [String: Int] = [:]
    public private(set) var saturated = false
    public private(set) var reason: InputCheckEnd?
    public private(set) var duration: Double = 0
    // Bounded by channel (local/global) x GestureEventKind (6 cases); never grows with event volume.
    public private(set) var gestureDetail: [String: GestureChannelSummary] = [:]
    public init(start: Double) { self.start = start }
    public func expired(at time: Double) -> Bool { time.isFinite && time >= start + Self.limit }
    public mutating func record(channel: InputCheckChannel, kind: InputCheckKind, at time: Double) {
        guard reason == nil, time.isFinite, start.isFinite, time >= start, !expired(at: time) else { return }
        let key = channel.rawValue + "." + kind.rawValue
        let previous = counts[key, default: 0]
        if previous < 1_000_000 { counts[key] = previous + 1 } else { saturated = true }
    }
    public mutating func recordGesture(channel: InputCheckChannel, kind: GestureEventKind, touchesChecked: Bool,
                                        touchCount: Int, phases: [TouchPhaseKind], at time: Double) {
        guard channel != .quartz, reason == nil, time.isFinite, start.isFinite, time >= start, !expired(at: time) else { return }
        var summary = gestureDetail[channel.rawValue] ?? GestureChannelSummary()
        summary.record(kind: kind, touchesChecked: touchesChecked, touchCount: touchCount, phases: phases)
        gestureDetail[channel.rawValue] = summary
    }
    public mutating func finish(reason: InputCheckEnd, at time: Double) {
        guard self.reason == nil else { return }
        self.reason = reason
        duration = time.isFinite && start.isFinite ? min(Self.limit, max(0, time - start)) : 0
    }
}
