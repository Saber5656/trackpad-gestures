import Foundation

public enum Transport: String, Codable, Hashable, Sendable { case usb, bluetooth, simulation, unknown }
public enum Capability: String, Codable, Hashable, Sendable { case pressure, area, highResolution, multiTouch, contactIdentity, normalizedCoordinates, nativeScroll, nativePinch }
public enum Modifier: String, Codable, Hashable, Sendable { case command, option, control, shift, function, capsLock }
public enum ContactPhase: String, Codable, Hashable, Sendable { case began, moved, stationary, ended, cancelled }

public struct Contact: Codable, Equatable, Hashable, Sendable {
    public let id: String
    public let x: Double
    public let y: Double
    public let phase: ContactPhase
    public let pressure: Double?
    public let area: Double?

    public init(id: String, x: Double, y: Double, phase: ContactPhase,
                pressure: Double? = nil, area: Double? = nil) {
        self.id = id; self.x = x; self.y = y; self.phase = phase
        self.pressure = pressure; self.area = area
    }
}

public enum FrameInterference: String, Codable, Hashable, Sendable { case scroll, pinch, rotate }

public struct NormalizedFrame: Codable, Equatable, Sendable {
    public let timestamp: TimeInterval
    public let sessionID: String
    public let transport: Transport
    public let capabilities: Set<Capability>
    public let contacts: [Contact]
    public let appScope: String?
    public let modifiers: Set<Modifier>
    public let interference: FrameInterference?

    public init(timestamp: TimeInterval, sessionID: String, transport: Transport,
                capabilities: Set<Capability> = [], contacts: [Contact], appScope: String? = nil,
                modifiers: Set<Modifier> = [], interference: FrameInterference? = nil) {
        self.timestamp = timestamp; self.sessionID = sessionID; self.transport = transport
        self.capabilities = capabilities; self.contacts = contacts; self.appScope = appScope
        self.modifiers = modifiers; self.interference = interference
    }
}

public enum Zone: String, Codable, Hashable, Sendable { case any, left, right, top, bottom, topLeft, topRight, bottomLeft, bottomRight }
public enum Direction: String, Codable, Hashable, Sendable { case up, down, left, right }
public enum GestureKind: Codable, Equatable, Hashable, Sendable {
    case tap, hold, swipe(Direction), pinch, rotate
    public var isRecognizable: Bool { switch self { case .pinch, .rotate: return false; default: return true } }
}

public struct GestureDefinition: Codable, Equatable, Sendable {
    public let id: String; public let name: String; public let kind: GestureKind
    public let fingerCount: Int; public let zone: Zone; public let movementThreshold: Double
    public let minDuration: TimeInterval?; public let maxDuration: TimeInterval?
    public let modifiers: Set<Modifier>; public let applicationScope: String?
    public let priority: Int; public let cooldown: TimeInterval; public let actionID: String
    public let requiredCapabilities: Set<Capability>; public let enabled: Bool

    public init(id: String, name: String, kind: GestureKind, actionID: String,
                fingerCount: Int = 3, zone: Zone = .any, movementThreshold: Double = 0.05,
                minDuration: TimeInterval? = nil, maxDuration: TimeInterval? = nil,
                modifiers: Set<Modifier> = [], applicationScope: String? = nil, priority: Int = 0,
                cooldown: TimeInterval = 0, requiredCapabilities: Set<Capability> = [], enabled: Bool = true) {
        self.id=id; self.name=name; self.kind=kind; self.fingerCount=fingerCount; self.zone=zone
        self.movementThreshold=movementThreshold; self.minDuration=minDuration; self.maxDuration=maxDuration
        self.modifiers=modifiers; self.applicationScope=applicationScope; self.priority=priority
        self.cooldown=cooldown; self.actionID=actionID; self.requiredCapabilities=requiredCapabilities; self.enabled=enabled
    }
}

extension GestureDefinition {
    private enum CodingKeys: String, CodingKey { case id, name, kind, direction, fingerCount, zone, movementThreshold, minDuration, maxDuration, modifiers, applicationScope, priority, cooldown, actionID, requiredCapabilities, enabled }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let id = try c.decode(String.self, forKey: .id), name = try c.decode(String.self, forKey: .name)
        let kindName = try c.decode(String.self, forKey: .kind)
        let kind: GestureKind
        switch kindName { case "tap": kind = .tap; case "hold": kind = .hold; case "pinch": kind = .pinch; case "rotate": kind = .rotate; case "swipe": kind = .swipe(try c.decode(Direction.self, forKey: .direction)); default: throw ProfileCodecError.invalidValue("kind") }
        self.init(id: id, name: name, kind: kind, actionID: try c.decode(String.self, forKey: .actionID), fingerCount: try c.decodeIfPresent(Int.self, forKey: .fingerCount) ?? 3, zone: try c.decodeIfPresent(Zone.self, forKey: .zone) ?? .any, movementThreshold: try c.decodeIfPresent(Double.self, forKey: .movementThreshold) ?? 0.05, minDuration: try c.decodeIfPresent(TimeInterval.self, forKey: .minDuration), maxDuration: try c.decodeIfPresent(TimeInterval.self, forKey: .maxDuration), modifiers: try c.decodeIfPresent(Set<Modifier>.self, forKey: .modifiers) ?? [], applicationScope: try c.decodeIfPresent(String.self, forKey: .applicationScope), priority: try c.decodeIfPresent(Int.self, forKey: .priority) ?? 0, cooldown: try c.decodeIfPresent(TimeInterval.self, forKey: .cooldown) ?? 0, requiredCapabilities: try c.decodeIfPresent(Set<Capability>.self, forKey: .requiredCapabilities) ?? [], enabled: try c.decodeIfPresent(Bool.self, forKey: .enabled) ?? true)
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id); try c.encode(name, forKey: .name); try c.encode(actionID, forKey: .actionID)
        switch kind { case .tap: try c.encode("tap", forKey: .kind); case .hold: try c.encode("hold", forKey: .kind); case .pinch: try c.encode("pinch", forKey: .kind); case .rotate: try c.encode("rotate", forKey: .kind); case .swipe(let d): try c.encode("swipe", forKey: .kind); try c.encode(d, forKey: .direction) }
        try c.encode(fingerCount, forKey: .fingerCount); try c.encode(zone, forKey: .zone); try c.encode(movementThreshold, forKey: .movementThreshold)
        try c.encodeIfPresent(minDuration, forKey: .minDuration); try c.encodeIfPresent(maxDuration, forKey: .maxDuration)
        try c.encode(modifiers, forKey: .modifiers); try c.encodeIfPresent(applicationScope, forKey: .applicationScope); try c.encode(priority, forKey: .priority); try c.encode(cooldown, forKey: .cooldown); try c.encode(requiredCapabilities, forKey: .requiredCapabilities); try c.encode(enabled, forKey: .enabled)
    }
}

public enum SystemAction: String, Codable, Hashable, Sendable { case beep, showDesktop }
public enum ActionKind: Codable, Equatable, Hashable, Sendable {
    case openURL(String), launch(bundleID: String), focusApp(bundleID: String), hideApp(bundleID: String)
    case appleShortcut(name: String), systemAction(SystemAction), keyboardShortcut(keycode: Int, modifiers: Set<Modifier>)
    public var executionSupported: Bool {
        switch self { case .openURL, .launch, .focusApp, .hideApp, .appleShortcut: return true; case .systemAction(let action): return action == .beep; case .keyboardShortcut: return false }
    }
}

public struct ActionDefinition: Codable, Equatable, Sendable {
    public let id: String; public let kind: ActionKind
    public init(id: String, kind: ActionKind) { self.id=id; self.kind=kind }
}

extension ActionDefinition {
    private enum CodingKeys: String, CodingKey { case id, kind, url, bundleID, name, systemAction, keycode, modifiers }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(id: try c.decode(String.self, forKey: .id), kind: try ActionKind(from: decoder))
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self); try c.encode(id, forKey: .id)
        switch kind { case .openURL(let u): try c.encode("openURL", forKey: .kind); try c.encode(u, forKey: .url); case .launch(let b): try c.encode("launch", forKey: .kind); try c.encode(b, forKey: .bundleID); case .focusApp(let b): try c.encode("focusApp", forKey: .kind); try c.encode(b, forKey: .bundleID); case .hideApp(let b): try c.encode("hideApp", forKey: .kind); try c.encode(b, forKey: .bundleID); case .appleShortcut(let n): try c.encode("appleShortcut", forKey: .kind); try c.encode(n, forKey: .name); case .systemAction(let a): try c.encode("systemAction", forKey: .kind); try c.encode(a, forKey: .systemAction); case .keyboardShortcut(let k, let m): try c.encode("keyboardShortcut", forKey: .kind); try c.encode(k, forKey: .keycode); try c.encode(m, forKey: .modifiers) }
    }
}

public struct Profile: Codable, Equatable, Sendable {
    public let id: String; public let name: String; public let gestures: [GestureDefinition]; public let actions: [ActionDefinition]
    public init(id: String, name: String, gestures: [GestureDefinition] = [], actions: [ActionDefinition] = []) {
        self.id=id; self.name=name; self.gestures=gestures; self.actions=actions
    }
}

public struct ProfileDocument: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1
    public let schemaVersion: Int; public let profiles: [Profile]
    public init(schemaVersion: Int = 1, profiles: [Profile]) { self.schemaVersion=schemaVersion; self.profiles=profiles }
}

public struct MigrationReport: Equatable, Sendable {
    public let migrated: Bool; public let explanation: String?
    public init(migrated: Bool, explanation: String? = nil) { self.migrated=migrated; self.explanation=explanation }
}
public struct ProfileDecodeResult: Equatable, Sendable {
    public let document: ProfileDocument; public let migration: MigrationReport
    public init(document: ProfileDocument, migration: MigrationReport) { self.document=document; self.migration=migration }
}

public enum ProfileCodecError: Error, Equatable, CustomStringConvertible {
    case tooLarge, invalidJSON, unknownField(String), unsupportedSchema(Int), invalidValue(String), duplicateID(String), tooManyItems
    public var description: String { switch self { case .tooLarge: return "profile exceeds 256 KiB"; case .invalidJSON: return "invalid JSON"; case .unknownField(let s): return "unknown field: \(s)"; case .unsupportedSchema(let v): return "unsupported schema version \(v)"; case .invalidValue(let s): return "invalid value: \(s)"; case .duplicateID(let s): return "duplicate id: \(s)"; case .tooManyItems: return "too many profile items" } }
}

public enum ProfileCodec {
    public static func encode(_ document: ProfileDocument) throws -> Data {
        try validate(document)
        let data = try JSONEncoder().encode(document)
        guard data.count <= 256 * 1024 else { throw ProfileCodecError.tooLarge }
        return data
    }
    public static func decode(_ data: Data) throws -> ProfileDecodeResult {
        guard data.count <= 256 * 1024 else { throw ProfileCodecError.tooLarge }
        guard let object = try? JSONSerialization.jsonObject(with: data), let root = object as? [String: Any] else { throw ProfileCodecError.invalidJSON }
        try validateKeys(root, allowed: ["schemaVersion", "profiles"], path: "")
        let version = root["schemaVersion"] as? Int ?? -1
        guard version == 0 || version == 1 else { throw ProfileCodecError.unsupportedSchema(version) }
        do {
            let decoded = try JSONDecoder().decode(ProfileDocument.self, from: data)
            if version == 0 {
                let migrated = ProfileDocument(profiles: decoded.profiles)
                try validate(migrated)
                return ProfileDecodeResult(document: migrated, migration: MigrationReport(migrated: true, explanation: "Schema version 0 contains the same declarative fields and was safely normalized to version 1."))
            }
            try validate(decoded)
            return ProfileDecodeResult(document: decoded, migration: MigrationReport(migrated: false))
        } catch let e as ProfileCodecError { throw e } catch { throw ProfileCodecError.invalidJSON }
    }
    public static func `import`(_ data: Data) throws -> ProfileDecodeResult { try decode(data) }

    private static func validateKeys(_ value: Any, allowed: Set<String>, path: String) throws {
        if let object = value as? [String: Any] {
            for key in object.keys where !allowed.contains(key) { throw ProfileCodecError.unknownField(path.isEmpty ? key : "\(path).\(key)") }
            if path.contains(".actions[") { try validateActionShape(object, path: path) }
            if path.contains(".gestures[") { try validateGestureShape(object, path: path) }
            for (key, child) in object { try validateKeys(child, allowed: allowedFor(path: path.isEmpty ? key : "\(path).\(key)"), path: path.isEmpty ? key : "\(path).\(key)") }
        } else if let array = value as? [Any] {
            for (i, child) in array.enumerated() { try validateKeys(child, allowed: allowedFor(path: "\(path)[\(i)]"), path: "\(path)[\(i)]") }
        }
    }
    private static func allowedFor(path: String) -> Set<String> {
        if path == "profiles" || path.hasPrefix("profiles[") && !path.contains(".gestures[") && !path.contains(".actions[") { return ["id", "name", "gestures", "actions"] }
        if path.contains(".gestures[") { return ["id","name","kind","direction","fingerCount","zone","movementThreshold","minDuration","maxDuration","modifiers","applicationScope","priority","cooldown","actionID","requiredCapabilities","enabled"] }
        if path.contains(".actions[") { return ["id","kind","url","bundleID","name","systemAction","keycode","modifiers"] }
        return ["schemaVersion", "profiles"]
    }
    public static func validate(_ document: ProfileDocument) throws {
        guard document.schemaVersion == ProfileDocument.currentSchemaVersion else { throw ProfileCodecError.unsupportedSchema(document.schemaVersion) }
        guard document.profiles.count <= 128 else { throw ProfileCodecError.tooManyItems }
        var ids = Set<String>(); var total = 0
        for profile in document.profiles {
            guard validText(profile.id), validText(profile.name) else { throw ProfileCodecError.invalidValue("invalid profile id/name") }
            guard ids.insert(profile.id).inserted else { throw ProfileCodecError.duplicateID(profile.id) }
            total += profile.gestures.count + profile.actions.count
            guard total <= 128 else { throw ProfileCodecError.tooManyItems }
            try validate(profile.gestures); try validate(profile.actions)
            let actionIDs = Set(profile.actions.map(\.id))
            guard profile.gestures.allSatisfy({ actionIDs.contains($0.actionID) }) else { throw ProfileCodecError.invalidValue("gesture references missing action") }
        }
    }
    private static func validate(_ gestures: [GestureDefinition]) throws {
        var ids = Set<String>(); for g in gestures {
            guard ids.insert(g.id).inserted else { throw ProfileCodecError.duplicateID(g.id) }
            guard validText(g.id), validText(g.name), validText(g.actionID), (2...5).contains(g.fingerCount), g.movementThreshold > 0, g.movementThreshold.isFinite, g.movementThreshold <= 1 else { throw ProfileCodecError.invalidValue("gesture \(g.id)") }
            if let d = g.minDuration, d < 0 || !d.isFinite || d > 3600 { throw ProfileCodecError.invalidValue("duration") }
            if let d = g.maxDuration, d < 0 || !d.isFinite || d > 3600 { throw ProfileCodecError.invalidValue("duration") }
            if let min = g.minDuration, let max = g.maxDuration, min > max { throw ProfileCodecError.invalidValue("duration order") }
            if let scope=g.applicationScope, !validBundleID(scope) { throw ProfileCodecError.invalidValue("applicationScope") }
            if !(-100...100).contains(g.priority) { throw ProfileCodecError.invalidValue("priority") }
            if g.cooldown < 0 || !g.cooldown.isFinite || g.cooldown > 86400 { throw ProfileCodecError.invalidValue("cooldown") }
        }
    }
    private static func validate(_ actions: [ActionDefinition]) throws {
        var ids = Set<String>(); for a in actions {
            guard ids.insert(a.id).inserted, validText(a.id) else { throw ProfileCodecError.duplicateID(a.id) }
            if case .openURL(let raw) = a.kind {
                guard let url = URL(string: raw), ["http", "https"].contains(url.scheme?.lowercased()), url.user == nil && url.password == nil, url.host?.isEmpty == false, validText(raw) else { throw ProfileCodecError.invalidValue("openURL must be http(s) without credentials") }
            }
            switch a.kind { case .launch(let b), .focusApp(let b), .hideApp(let b): guard validBundleID(b) else { throw ProfileCodecError.invalidValue("bundleID") }; case .appleShortcut(let n): guard validText(n) else { throw ProfileCodecError.invalidValue("shortcut name") }; case .keyboardShortcut(let k, _): guard (0...65535).contains(k) else { throw ProfileCodecError.invalidValue("keycode") }; default: break }
        }
    }
    private static func validText(_ value: String) -> Bool { !value.isEmpty && value.utf8.count <= 512 && value.unicodeScalars.allSatisfy { $0.value >= 0x20 && $0.value != 0x7f } }
    private static func validBundleID(_ value: String) -> Bool {
        value.utf8.count <= 200 && value.range(of: "^[A-Za-z0-9-]+(\\.[A-Za-z0-9-]+)+$", options: .regularExpression) != nil
    }
    public static func isValidGesture(_ gesture: GestureDefinition) -> Bool { (try? validate([gesture])) != nil }

    private static func validateActionShape(_ object: [String: Any], path: String) throws {
        guard let kind = object["kind"] as? String else { throw ProfileCodecError.invalidValue("action kind") }
        let common = Set(["id", "kind"]); let allowed: Set<String>
        switch kind { case "openURL": allowed = common.union(["url"]); case "launch", "focusApp", "hideApp": allowed = common.union(["bundleID"]); case "appleShortcut": allowed = common.union(["name"]); case "systemAction": allowed = common.union(["systemAction"]); case "keyboardShortcut": allowed = common.union(["keycode", "modifiers"]); default: throw ProfileCodecError.invalidValue("action kind") }
        for key in object.keys where !allowed.contains(key) { throw ProfileCodecError.unknownField("\(path).\(key)") }
    }
    private static func validateGestureShape(_ object: [String: Any], path: String) throws {
        if object["kind"] as? String == "swipe" && object["direction"] == nil { throw ProfileCodecError.invalidValue("swipe direction") }
        if object["kind"] as? String != "swipe" && object["direction"] != nil { throw ProfileCodecError.unknownField("\(path).direction") }
    }
}

extension GestureKind {
    enum CodingKeys: String, CodingKey { case type, direction }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self); let type = try c.decode(String.self, forKey: .type)
        switch type { case "tap": self = .tap; case "hold": self = .hold; case "pinch": self = .pinch; case "rotate": self = .rotate; case "swipe": self = .swipe(try c.decode(Direction.self, forKey: .direction)); default: throw ProfileCodecError.invalidValue("kind") }
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self { case .tap: try c.encode("tap", forKey: .type); case .hold: try c.encode("hold", forKey: .type); case .pinch: try c.encode("pinch", forKey: .type); case .rotate: try c.encode("rotate", forKey: .type); case .swipe(let d): try c.encode("swipe", forKey: .type); try c.encode(d, forKey: .direction) }
    }
}

extension ActionKind {
    enum CodingKeys: String, CodingKey { case kind, url, bundleID, name, systemAction, keycode, modifiers }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self); let kind = try c.decode(String.self, forKey: .kind)
        switch kind { case "openURL": self = .openURL(try c.decode(String.self, forKey: .url)); case "launch": self = .launch(bundleID: try c.decode(String.self, forKey: .bundleID)); case "focusApp": self = .focusApp(bundleID: try c.decode(String.self, forKey: .bundleID)); case "hideApp": self = .hideApp(bundleID: try c.decode(String.self, forKey: .bundleID)); case "appleShortcut": self = .appleShortcut(name: try c.decode(String.self, forKey: .name)); case "systemAction": self = .systemAction(try c.decode(SystemAction.self, forKey: .systemAction)); case "keyboardShortcut": self = .keyboardShortcut(keycode: try c.decode(Int.self, forKey: .keycode), modifiers: try c.decode(Set<Modifier>.self, forKey: .modifiers)); default: throw ProfileCodecError.invalidValue("action kind") }
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self { case .openURL(let u): try c.encode("openURL", forKey: .kind); try c.encode(u, forKey: .url); case .launch(let b): try c.encode("launch", forKey: .kind); try c.encode(b, forKey: .bundleID); case .focusApp(let b): try c.encode("focusApp", forKey: .kind); try c.encode(b, forKey: .bundleID); case .hideApp(let b): try c.encode("hideApp", forKey: .kind); try c.encode(b, forKey: .bundleID); case .appleShortcut(let n): try c.encode("appleShortcut", forKey: .kind); try c.encode(n, forKey: .name); case .systemAction(let a): try c.encode("systemAction", forKey: .kind); try c.encode(a, forKey: .systemAction); case .keyboardShortcut(let k, let m): try c.encode("keyboardShortcut", forKey: .kind); try c.encode(k, forKey: .keycode); try c.encode(m, forKey: .modifiers) }
    }
}
