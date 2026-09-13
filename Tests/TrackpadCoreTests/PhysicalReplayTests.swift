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

    @Test func secondPhysicalSamplePreservesContactPhasesAndReplayOutcome() throws {
        let url = try #require(Bundle.module.url(forResource: "physical-second-sample", withExtension: "json", subdirectory: "Fixtures"))
        let fixture = try JSONDecoder().decode(Fixture.self, from: Data(contentsOf: url))

        #expect(fixture.provenance == "physical; AppKit local sample sanitized for replay")
        #expect(fixture.sourceSHA == "e9fbbfb738cbf6d74383b5c3963479b6ed016efbb7aad615bb3052d4ce8de8c5")
        #expect(fixture.frames.count == 43)
        #expect(Set(fixture.frames.flatMap { $0.contacts }.map(\.id)) == ["c1", "c2", "c3", "c4", "c5"])
        #expect(fixture.frames.allSatisfy { $0.sessionID == "session1" && $0.transport == .unknown })
        #expect(fixture.frames.allSatisfy { $0.capabilities == CapabilityRegistry.contactRecognition })

        // The first contact sequence spans 60.980208 ms. The two same-time frames
        // retain the suspected duplicate terminal notification and its new ID.
        #expect(fixture.frames[5].timestamp - fixture.frames[0].timestamp == 0.06098020798526704)
        #expect(fixture.frames[3].timestamp == fixture.frames[4].timestamp)
        #expect(fixture.frames[3].contacts[1].id == "c2")
        #expect(fixture.frames[3].contacts[1].phase == .ended)
        #expect(fixture.frames[4].contacts[0].id == "c4")
        #expect(fixture.frames[4].contacts[0].phase == .ended)
        #expect(fixture.frames[4].contacts[0].x == 0.544219970703125)
        #expect(fixture.frames[4].contacts[0].y == 0.730255126953125)
        #expect(fixture.frames[5].contacts.map(\.phase) == [.ended, .ended])
        #expect(fixture.frames[42].contacts.count == 1)
        #expect(fixture.frames[42].contacts[0].phase == .ended)

        let engine = GestureEngine(definitions: fixture.definitions)
        let outputs = fixture.frames.map { engine.process($0) }
        print("physical-second-sample statuses=\(outputs.map { $0.status.rawValue }); events=\(outputs.flatMap(\.events).map { $0.gestureID })")
        #expect(outputs.map(\.status.rawValue) == fixture.expectedStatuses)
        #expect(outputs.flatMap(\.events).map(\.gestureID) == fixture.expectedIDs)
        #expect(outputs.flatMap(\.events).isEmpty)
        #expect(outputs[3].status == .tracking)
        #expect(outputs[4].status == .malformed)
        #expect(outputs[5].status == .waitingForBoundary)
        #expect(outputs[42].status == .waitingForBoundary)
    }

    @Test func thirdPhysicalSampleReplaysThreeFingerTapSequence() throws {
        let url = try #require(Bundle.module.url(forResource: "physical-third-sample", withExtension: "json", subdirectory: "Fixtures"))
        let fixture = try JSONDecoder().decode(Fixture.self, from: Data(contentsOf: url))

        #expect(fixture.provenance == "physical; AppKit local sample sanitized for replay")
        #expect(fixture.sourceSHA == "cdacd7df1fd34545968f83a924fa968df3dfaebc37860cda5390dc0dc49a13ff")
        #expect(fixture.frames.count == 7)
        #expect(Set(fixture.frames.flatMap { $0.contacts }.map(\.id)) == ["c1", "c2", "c3"])
        #expect(fixture.frames.allSatisfy { $0.sessionID == "session1" && $0.transport == .unknown })
        #expect(fixture.frames.allSatisfy { $0.capabilities == CapabilityRegistry.contactRecognition })
        #expect(fixture.frames[6].timestamp - fixture.frames[0].timestamp == 0.1060192920267582)
        #expect(fixture.frames[5].contacts.map(\.id) == ["c2", "c3", "c1"])
        #expect(fixture.frames[5].contacts.map(\.phase) == [.stationary, .ended, .ended])
        #expect(fixture.frames[6].contacts.map(\.id) == ["c2"])
        #expect(fixture.frames[6].contacts[0].phase == .ended)
        let hold = try #require(fixture.definitions.first { $0.id == "hold" })
        #expect(hold.kind == .hold)
        #expect(hold.fingerCount == 3)
        #expect(hold.minDuration == 0.6)
        #expect(hold.maxDuration == 2)
        #expect(hold.movementThreshold == 0.06)
        #expect(hold.cooldown == 0.5)
        #expect(hold.enabled)
        let tap = try #require(fixture.definitions.first { $0.id == "tap" })
        #expect(tap.kind == .tap)
        #expect(tap.minDuration == 0)
        #expect(tap.maxDuration == 0.35)
        #expect(tap.movementThreshold == 0.06)
        #expect(tap.cooldown == 0.5)
        #expect(tap.enabled)

        let envelope = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        let capture = try #require(envelope["captureMetadata"] as? [String: Any])
        let window = try #require(capture["recording"] as? [String: Any])
        #expect(capture["sampleSchemaVersion"] as? Int == 2)
        #expect(capture["restingByFrame"] as? [[Bool]] == fixture.frames.map { $0.contacts.map { _ in false } })
        #expect(window["finishReason"] as? String == "sequenceEnded")
        #expect(window["sampleCount"] as? Int == fixture.frames.count)
        let capturedAt = try #require(window["captureStartedAt"] as? Double)
        let finishedAt = try #require(window["finishedAt"] as? Double)
        #expect(finishedAt - capturedAt == fixture.frames[6].timestamp)

        let engine = GestureEngine(definitions: fixture.definitions)
        let outputs = fixture.frames.map { engine.process($0) }
        print("physical-third-sample statuses=\(outputs.map { $0.status.rawValue }); events=\(outputs.flatMap(\.events).map { $0.gestureID })")

        #expect(outputs.map(\.status.rawValue) == fixture.expectedStatuses)
        #expect(outputs.flatMap(\.events).map(\.gestureID) == fixture.expectedIDs)
    }
}
