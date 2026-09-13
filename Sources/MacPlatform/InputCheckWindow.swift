import Foundation

public enum InputCheckChannel: String, CaseIterable, Sendable { case local, global, quartz }
public enum InputCheckKind: String, CaseIterable, Sendable { case pointer, click, scroll, gesture }
public enum InputCheckEnd: String, Codable, Sendable {
    case completed, cancelled, permissionChanged, sleepOrLock, deviceChanged, appExit
}

// A fixed vocabulary of 12 counters, with no event payloads or contact data.
public struct InputCheckWindow {
    public static let limit: Double = 30
    public let start: Double
    public private(set) var counts: [String: Int] = [:]
    public private(set) var saturated = false
    public private(set) var reason: InputCheckEnd?
    public private(set) var duration: Double = 0
    public init(start: Double) { self.start = start }
    public func expired(at time: Double) -> Bool { time.isFinite && time >= start + Self.limit }
    public mutating func record(channel: InputCheckChannel, kind: InputCheckKind, at time: Double) {
        guard reason == nil, time.isFinite, start.isFinite, time >= start, !expired(at: time) else { return }
        let key = channel.rawValue + "." + kind.rawValue
        let previous = counts[key, default: 0]
        if previous < 1_000_000 { counts[key] = previous + 1 } else { saturated = true }
    }
    public mutating func finish(reason: InputCheckEnd, at time: Double) {
        guard self.reason == nil else { return }
        self.reason = reason
        duration = time.isFinite && start.isFinite ? min(Self.limit, max(0, time - start)) : 0
    }
}
