import Testing
import Foundation
@testable import TrackpadCore

struct CoreTests {
    @Test func normalizedFrameAndContactAreImmutableValueTypes() {
        let contact = Contact(id: "a", x: 0.5, y: 0.25, phase: .began, pressure: 0.4, area: 1)
        let frame = NormalizedFrame(timestamp: 1, sessionID: "s", transport: .simulation,
                                    capabilities: [.pressure], contacts: [contact],
                                    appScope: "com.example.Editor", modifiers: [.command])
        #expect(frame.contacts.first?.x == 0.5)
        #expect(frame.appScope == "com.example.Editor")
    }

    @Test func tapWinsAndOnlyFiresOncePerSequence() {
        let definition = GestureDefinition(id: "tap", name: "Tap", kind: .tap, actionID: "beep")
        let engine = GestureEngine(definitions: [definition])
        #expect(engine.process(frame(0, "s", [c("1", .began, 0.2, 0.2)])).events.isEmpty)
        #expect(engine.process(frame(0.1, "s", [c("1", .ended, 0.2, 0.2)])).events.count == 1)
        #expect(engine.process(frame(0.2, "s", [])).events.isEmpty)
    }

    @Test func malformedFrameRequiresEmptyBoundaryBeforeRestart() {
        let definition = GestureDefinition(id: "tap", name: "Tap", kind: .tap, actionID: "beep")
        let engine = GestureEngine(definitions: [definition])
        _ = engine.process(frame(0, "s", [c("1", .began, 0.2, 0.2)]))
        let bad = NormalizedFrame(timestamp: 0.5, sessionID: "s", transport: .simulation,
                                  capabilities: [], contacts: [Contact(id: "1", x: 1.2, y: 0.2, phase: .moved)])
        #expect(engine.process(bad).status == .malformed)
        #expect(engine.process(frame(0.6, "s", [c("1", .began, 0.2, 0.2)])).status == .waitingForBoundary)
        #expect(engine.process(frame(0.7, "s", [])).status == .ready)
        #expect(engine.process(frame(0.8, "s", [c("1", .began, 0.2, 0.2)])).status == .tracking)
    }

    @Test func configurationRejectsUnknownAndExecutableFieldsAndRoundTrips() throws {
        let profile = Profile(id: "default", name: "Default", gestures: [
            GestureDefinition(id: "tap", name: "Tap", kind: .tap, actionID: "beep")
        ], actions: [ActionDefinition(id: "beep", kind: .systemAction(.beep))])
        let data = try ProfileCodec.encode(ProfileDocument(profiles: [profile]))
        let decoded = try ProfileCodec.decode(data)
        #expect(decoded.document.profiles == [profile])
        #expect(throws: (any Error).self) { try ProfileCodec.decode(Data(#"{"schemaVersion":1,"profiles":[],"code":"x"}"#.utf8)) }
        #expect(throws: (any Error).self) { try ProfileCodec.decode(Data(#"{"schemaVersion":1,"profiles":[],"actions":[]}"#.utf8)) }
        #expect(throws: (any Error).self) { try ProfileCodec.decode(Data(#"{"schemaVersion":1,"profiles":[{"id":"p","name":"p","gestures":[],"actions":[{"id":"x","kind":"openURL","url":"https://u:pw@example.com"}]}]}"#.utf8)) }
    }

    @Test func interferenceAndIdentifierChurnCancelUntilBoundary() {
        let d = GestureDefinition(id: "tap", name: "Tap", kind: .tap, actionID: "beep")
        let engine = GestureEngine(definitions: [d])
        _ = engine.process(frame(0, "s", [c("1", .began, 0.2, 0.2)]))
        #expect(engine.process(NormalizedFrame(timestamp: 0.1, sessionID: "s", transport: .simulation, contacts: [Contact(id: "2", x: 0.2, y: 0.2, phase: .moved)])).status == .cancelled)
        #expect(engine.process(frame(0.2, "s", [c("1", .began, 0.2, 0.2)])).status == .waitingForBoundary)
        #expect(engine.process(frame(0.3, "s", [])).status == .ready)
        _ = engine.process(frame(0.4, "s", [c("1", .began, 0.2, 0.2)]))
        #expect(engine.process(NormalizedFrame(timestamp: 0.5, sessionID: "s", transport: .simulation, contacts: [Contact(id: "1", x: 0.2, y: 0.2, phase: .moved)], interference: .pinch)).status == .cancelled)
    }

    @Test func candidateOrderingIsDeterministicAndSwipeDirectionUsesLowerLeftCoordinates() {
        let a = GestureDefinition(id: "z", name: "Z", kind: .swipe(.up), actionID: "a", movementThreshold: 0.1, priority: 1)
        let b = GestureDefinition(id: "a", name: "A", kind: .swipe(.up), actionID: "b", movementThreshold: 0.1, priority: 1)
        let engine = GestureEngine(definitions: [a, b])
        _ = engine.process(frame(0, "s", [c("1", .began, 0.2, 0.2)]))
        _ = engine.process(frame(0.1, "s", [c("1", .moved, 0.2, 0.4)]))
        let output = engine.process(frame(0.2, "s", [c("1", .ended, 0.2, 0.4)]))
        #expect(output.events.first?.gestureID == "a")
    }

    @Test func schemaZeroMigratesSafelyAndFuzzedFramesStayBounded() throws {
        let migrated = try ProfileCodec.decode(Data(#"{"schemaVersion":0,"profiles":[]}"#.utf8))
        #expect(migrated.document.schemaVersion == 1)
        #expect(migrated.migration.migrated)
        let engine = GestureEngine(definitions: [GestureDefinition(id: "t", name: "T", kind: .tap, actionID: "a")])
        var seed: UInt64 = 0x9E3779B97F4A7C15
        for i in 0..<128 {
            seed = seed &* 6364136223846793005 &+ 1
            let x = Double(seed % 120) / 100.0
            let id = i % 7 == 0 ? "" : "\(i % 4)"
            #expect(engine.process(NormalizedFrame(timestamp: Double(i) + 0.001, sessionID: "fuzz", transport: .simulation, contacts: [Contact(id: id, x: x, y: 0.5, phase: .moved)])).events.isEmpty)
        }
    }

    private func c(_ id: String, _ phase: ContactPhase, _ x: Double, _ y: Double) -> Contact {
        Contact(id: id, x: x, y: y, phase: phase)
    }
    private func frame(_ t: TimeInterval, _ session: String, _ contacts: [Contact]) -> NormalizedFrame {
        NormalizedFrame(timestamp: t, sessionID: session, transport: .simulation,
                        capabilities: [.multiTouch,.contactIdentity,.normalizedCoordinates], contacts: contacts.flatMap { c in (0..<3).map { i in Contact(id:c.id+"-"+String(i),x:c.x+Double(i)*0.03,y:c.y,phase:c.phase) } })
    }
}
