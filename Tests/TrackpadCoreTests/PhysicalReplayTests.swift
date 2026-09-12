import Foundation
import Testing
@testable import TrackpadCore

struct PhysicalReplayTests {
    private struct Fixture: Decodable {
        let provenance: String
        let sourceSHA: String
        let definitions: [GestureDefinition]
        let frames: [NormalizedFrame]
        let expectedStatuses: [String]
        let expectedIDs: [String]
    }

    @Test func incompletePhysicalHoldReplaysAsTrackingWithoutEvent() throws {
        let url = try #require(Bundle.module.url(forResource: "physical-incomplete-hold", withExtension: "json", subdirectory: "Fixtures"))
        let fixture = try JSONDecoder().decode(Fixture.self, from: Data(contentsOf: url))

        #expect(fixture.provenance == "physical; AppKit local sample sanitized for replay")
        #expect(fixture.sourceSHA == "f9a07d86abe77fdd8687447a88316e1596fdd7503d86ddba24e9209e473bb15b")
        #expect(fixture.frames.count == 2)
        #expect(Set(fixture.frames.flatMap { $0.contacts }.map(\.id)) == ["c1", "c2", "c3"])
        #expect(fixture.frames.flatMap { $0.contacts }.allSatisfy { $0.phase != .ended && $0.phase != .cancelled })
        #expect(fixture.frames[1].timestamp - fixture.frames[0].timestamp == 0.015027249930426478)
        let hold = try #require(fixture.definitions.first { $0.id == "hold" })
        #expect(hold.kind == .hold)
        #expect(hold.fingerCount == 3)
        #expect(hold.minDuration == 0.6)
        #expect(hold.maxDuration == 2)
        #expect(hold.movementThreshold == 0.06)
        #expect(hold.cooldown == 0.5)
        #expect(hold.enabled)
        #expect(hold.applicationScope == nil)
        let tap = try #require(fixture.definitions.first { $0.id == "tap" })
        #expect(tap.kind == .tap)
        #expect(tap.minDuration == 0)
        #expect(tap.maxDuration == 0.35)
        #expect(fixture.frames.allSatisfy { $0.capabilities == CapabilityRegistry.contactRecognition })

        let engine = GestureEngine(definitions: fixture.definitions)
        let outputs = fixture.frames.map { engine.process($0) }

        #expect(outputs.map { $0.status.rawValue } == fixture.expectedStatuses)
        #expect(outputs.flatMap(\.events).map(\.gestureID) == fixture.expectedIDs)
        #expect(outputs.last?.status == .tracking)
        #expect(outputs.flatMap(\.events).isEmpty)
    }
}
