import Foundation

public enum EngineStatus: String, Equatable, Sendable { case ready, tracking, fired, cancelled, malformed, waitingForBoundary }
public struct GestureEvent: Equatable, Sendable {
    public let gestureID: String
    public let actionID: String
    public let sessionID: String
    public let timestamp: TimeInterval
    public let kind: GestureKind
}
public struct EngineOutput: Equatable, Sendable {
    public let status: EngineStatus
    public let events: [GestureEvent]
    public init(status: EngineStatus, events: [GestureEvent] = []) { self.status=status; self.events=events }
}

public enum CapabilityRegistry {
    public static let contactRecognition: Set<Capability> = [.multiTouch, .contactIdentity, .normalizedCoordinates]
    public static func requirements(for definition: GestureDefinition) -> Set<Capability> {
        contactRecognition.union(definition.requiredCapabilities)
    }
    public static func missing(for definition: GestureDefinition, available: Set<Capability>) -> Set<Capability> {
        requirements(for: definition).subtracting(available)
    }
}

// Single serial owner. Intentionally not Sendable: adapters serialize their callbacks.
public final class GestureEngine {
    private struct Sequence {
        let began: Double
        let scope: String?
        let modifiers: Set<Modifier>
        let capabilities: Set<Capability>
        let transport: Transport
        var starts: [String: Contact]
        var latest: [String: Contact]
        var ended: Set<String> = []
        var maxMovement: Double = 0
        var maxDeviation: Double = 0
        var candidates: [GestureDefinition]
    }
    private var definitions: [GestureDefinition] = []
    private var sequence: Sequence?
    private var lastTimestamp: Double?
    private var sessionID: String?
    private var waiting = false
    private var firedAt: [String: Double] = [:]
    public let maximumFrameGap: TimeInterval
    public static let assemblyWindow = 0.08
    public static let coherenceTolerance = 0.04
    private static let epsilon = 1e-9

    public init(definitions: [GestureDefinition] = [], maximumFrameGap: TimeInterval = 1) {
        self.maximumFrameGap = maximumFrameGap
        setDefinitions(definitions)
    }
    private func setDefinitions(_ values: [GestureDefinition]) {
        // Reject excessive/duplicate definitions, rather than silently choose a subset.
        guard values.count <= 128, Set(values.map(\.id)).count == values.count else { definitions=[]; return }
        definitions=values.filter { ProfileCodec.isValidGesture($0) }
    }
    public func replaceDefinitions(_ values: [GestureDefinition]) { setDefinitions(values); reset() }
    public func reset() { sequence=nil; waiting=false; lastTimestamp=nil; sessionID=nil; firedAt.removeAll(keepingCapacity:true) }
    public func cancel() { if sequence != nil { sequence=nil; waiting=true } }
    // Called only after the adapter observes that every contact has terminated.
    public func confirmEmptyBoundary() { sequence=nil; waiting=false }

    public func process(_ frame: NormalizedFrame) -> EngineOutput {
        guard validShape(frame) else { return poison(.malformed) }
        if sessionID != frame.sessionID {
            sequence=nil; waiting=false; lastTimestamp=nil; firedAt.removeAll(keepingCapacity:true)
            sessionID=frame.sessionID
        }
        if let lastTimestamp, frame.timestamp <= lastTimestamp { return poison(.malformed) }
        let gap = lastTimestamp.map { frame.timestamp - $0 } ?? 0
        if sequence != nil && gap > maximumFrameGap {
            sequence=nil; waiting = !frame.contacts.isEmpty
            return .init(status:.cancelled)
        }
        lastTimestamp=frame.timestamp
        if waiting {
            if frame.contacts.isEmpty { waiting=false; return .init(status:.ready) }
            return .init(status:.waitingForBoundary)
        }
        if frame.interference != nil {
            let wasTracking=sequence != nil
            sequence=nil; waiting = !frame.contacts.isEmpty
            return .init(status:wasTracking || waiting ? .cancelled : .ready)
        }
        if frame.contacts.isEmpty {
            let wasTracking=sequence != nil; sequence=nil
            return .init(status:wasTracking ? .cancelled : .ready)
        }
        if frame.contacts.contains(where: { $0.phase == .cancelled }) { return poison(.cancelled) }
        if sequence == nil {
            guard frame.contacts.allSatisfy({$0.phase == .began}) else { return poison(.cancelled) }
            let candidates=definitions.filter { d in
                d.enabled && d.kind.isRecognizable && d.fingerCount >= frame.contacts.count &&
                d.modifiers == frame.modifiers && (d.applicationScope == nil || d.applicationScope == frame.appScope) &&
                CapabilityRegistry.missing(for:d,available:frame.capabilities).isEmpty &&
                (firedAt[d.id].map { frame.timestamp - $0 + Self.epsilon >= d.cooldown } ?? true)
            }
            guard !candidates.isEmpty else { return poison(.cancelled) }
            let points=Dictionary(uniqueKeysWithValues:frame.contacts.map { ($0.id,$0) })
            sequence=Sequence(began:frame.timestamp,scope:frame.appScope,modifiers:frame.modifiers,capabilities:frame.capabilities,transport:frame.transport,starts:points,latest:points,candidates:candidates)
            return .init(status:.tracking)
        }
        guard var s=sequence, s.scope == frame.appScope, s.modifiers == frame.modifiers,
              s.capabilities == frame.capabilities, s.transport == frame.transport else { return poison(.cancelled) }
        let incoming=Set(frame.contacts.map(\.id))
        let previousActive=Set(s.starts.keys).subtracting(s.ended)
        guard previousActive.isSubset(of:incoming), incoming.isDisjoint(with:s.ended) else { return poison(.cancelled) }
        for contact in frame.contacts {
            if s.starts[contact.id] == nil {
                guard contact.phase == .began, s.ended.isEmpty,
                      frame.timestamp - s.began <= Self.assemblyWindow + Self.epsilon else { return poison(.cancelled) }
                s.starts[contact.id]=contact
            } else if contact.phase == .began { return poison(.cancelled) }
            s.latest[contact.id]=contact
            if contact.phase == .ended { s.ended.insert(contact.id) }
        }
        guard s.starts.count <= 5 else { return poison(.cancelled) }
        s.candidates=s.candidates.filter { $0.fingerCount >= s.starts.count }
        guard !s.candidates.isEmpty else { return poison(.cancelled) }
        let delta=translation(s)
        for (id,start) in s.starts {
            guard let point=s.latest[id] else { return poison(.malformed) }
            let dx=point.x-start.x, dy=point.y-start.y
            s.maxMovement=max(s.maxMovement,hypot(dx,dy))
            s.maxDeviation=max(s.maxDeviation,hypot(dx-delta.0,dy-delta.1))
        }
        sequence=s
        if s.ended.count == s.starts.count { return finish(s,frame:frame) }
        return .init(status:.tracking)
    }
    private func poison(_ status:EngineStatus)->EngineOutput { sequence=nil; waiting=true; return .init(status:status) }
    private func translation(_ s:Sequence)->(Double,Double) {
        // Sort to make floating point summation independent of dictionary/hash order.
        var dx=0.0,dy=0.0
        for id in s.starts.keys.sorted() { dx += s.latest[id]!.x-s.starts[id]!.x; dy += s.latest[id]!.y-s.starts[id]!.y }
        return (dx/Double(s.starts.count),dy/Double(s.starts.count))
    }
    private func finish(_ s:Sequence,frame:NormalizedFrame)->EngineOutput {
        sequence=nil
        let duration=frame.timestamp-s.began; let delta=translation(s)
        let positions=s.starts.keys.sorted().map { s.starts[$0]! }
        let x=positions.map(\.x).reduce(0,+)/Double(positions.count)
        let y=positions.map(\.y).reduce(0,+)/Double(positions.count)
        let matches=s.candidates.filter { d in
            let defaultMin = d.kind == .hold ? 0.5 : 0
            let defaultMax = d.kind == .tap ? 0.35 : 2.0
            guard d.fingerCount == positions.count, GestureOrdering.zoneContains(d.zone,x:x,y:y),
                  duration + Self.epsilon >= (d.minDuration ?? defaultMin),
                  duration <= (d.maxDuration ?? defaultMax) + Self.epsilon else { return false }
            switch d.kind {
            case .tap,.hold: return s.maxMovement <= d.movementThreshold + Self.epsilon
            case .swipe(let direction):
                guard hypot(delta.0,delta.1) + Self.epsilon >= d.movementThreshold,
                      s.maxDeviation <= Self.coherenceTolerance + Self.epsilon else { return false }
                switch direction {
                case .right: return delta.0 > 0 && delta.0 >= abs(delta.1)*1.5
                case .left: return delta.0 < 0 && -delta.0 >= abs(delta.1)*1.5
                case .up: return delta.1 > 0 && delta.1 >= abs(delta.0)*1.5
                case .down: return delta.1 < 0 && -delta.1 >= abs(delta.0)*1.5
                }
            case .pinch,.rotate: return false
            }
        }.sorted(by:GestureOrdering.precedes)
        guard let winner=matches.first else { return .init(status:.cancelled) }
        firedAt[winner.id]=frame.timestamp // At most 128 IDs, cleared on device-session change.
        return .init(status:.fired,events:[.init(gestureID:winner.id,actionID:winner.actionID,sessionID:frame.sessionID,timestamp:frame.timestamp,kind:winner.kind)])
    }
    private func validShape(_ f:NormalizedFrame)->Bool {
        guard f.timestamp.isFinite, f.timestamp >= 0, !f.sessionID.isEmpty, f.sessionID.utf8.count <= 256,
              f.contacts.count <= 10, maximumFrameGap.isFinite, maximumFrameGap > 0,
              Set(f.contacts.map(\.id)).count == f.contacts.count else { return false }
        return f.contacts.allSatisfy { c in
            !c.id.isEmpty && c.id.utf8.count <= 64 && c.x.isFinite && c.y.isFinite && (0...1).contains(c.x) && (0...1).contains(c.y) &&
            (c.pressure.map { $0.isFinite && $0 >= 0 && f.capabilities.contains(.pressure) } ?? true) &&
            (c.area.map { $0.isFinite && $0 >= 0 && f.capabilities.contains(.area) } ?? true)
        }
    }
}

public enum GestureOrdering {
    public static func precedes(_ a:GestureDefinition,_ b:GestureDefinition)->Bool {
        if (a.applicationScope != nil) != (b.applicationScope != nil) { return a.applicationScope != nil }
        let ac=CapabilityRegistry.requirements(for:a).count,bc=CapabilityRegistry.requirements(for:b).count
        if ac != bc { return ac > bc }
        if a.priority != b.priority { return a.priority > b.priority }
        return a.id < b.id
    }
    public static func zoneContains(_ z:Zone,x:Double,y:Double)->Bool {
        switch z {
        case .any:return true
        case .left:return x <= 0.2
        case .right:return x >= 0.8
        case .top:return y >= 0.8
        case .bottom:return y <= 0.2
        case .topLeft:return x <= 0.2 && y >= 0.8
        case .topRight:return x >= 0.8 && y >= 0.8
        case .bottomLeft:return x <= 0.2 && y <= 0.2
        case .bottomRight:return x >= 0.8 && y <= 0.2
        }
    }
    public static func potentiallyOverlaps(_ a:GestureDefinition,_ b:GestureDefinition)->Bool {
        guard a.enabled && b.enabled, a.kind.isRecognizable && b.kind.isRecognizable,
              a.fingerCount == b.fingerCount, a.modifiers == b.modifiers,
              a.applicationScope == nil || b.applicationScope == nil || a.applicationScope == b.applicationScope else { return false }
        let timeA=(a.minDuration ?? (a.kind == .hold ? 0.5:0),a.maxDuration ?? (a.kind == .tap ? 0.35:2))
        let timeB=(b.minDuration ?? (b.kind == .hold ? 0.5:0),b.maxDuration ?? (b.kind == .tap ? 0.35:2))
        guard max(timeA.0,timeB.0) <= min(timeA.1,timeB.1) else { return false }
        let zonesOverlap=[0.1,0.5,0.9].contains { x in [0.1,0.5,0.9].contains { y in zoneContains(a.zone,x:x,y:y) && zoneContains(b.zone,x:x,y:y) } }
        guard zonesOverlap else { return false }
        if case .swipe(let da)=a.kind, case .swipe(let db)=b.kind { return da == db }
        if case .swipe=a.kind { return a.movementThreshold <= b.movementThreshold }
        if case .swipe=b.kind { return b.movementThreshold <= a.movementThreshold }
        return true
    }
}
