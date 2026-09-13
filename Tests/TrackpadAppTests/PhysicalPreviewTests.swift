import Foundation
import Testing
import TrackpadCore
import MacPlatform
@testable import TrackpadApp

// Replay captured observations through the app model, not a new physical capture.
// Only the clock origin changes; offsets, IDs, phases and positions stay intact.
@MainActor struct PhysicalPreviewTests {
    private struct Fixture: Decodable {
        let definitions: [GestureDefinition]
        let frames: [NormalizedFrame]
        let captureMetadata: Metadata
        struct Metadata: Decodable { let restingByFrame: [[Bool]] }
    }
    private func fixture() throws -> Fixture {
        // This integration suite runs in the source checkout, including clean-source tests.
        let url=URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("TrackpadCoreTests/Fixtures/physical-third-sample.json")
        return try JSONDecoder().decode(Fixture.self,from:Data(contentsOf:url))
    }
    private func withModel(_ body:(AppModel,Fixture) throws -> Void) throws {
        let fixture=try fixture()
        let dir=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at:dir,withIntermediateDirectories:true)
        defer { try? FileManager.default.removeItem(at:dir) }
        let url=dir.appendingPathComponent("profile.json")
        let action=ActionDefinition(id:"beep",kind:.systemAction(.beep))
        try ProfileCodec.encode(.init(profiles:[.init(id:"replay",name:"Replay",gestures:fixture.definitions,actions:[action])])).write(to:url)
        let model=AppModel(storage:url); defer { model.shutdown() }
        model.startLocal()
        try body(model,fixture)
    }
    private func replay(_ fixture:Fixture, into model:AppModel, at origin:Double, beforeFrame:((Int) -> Void)?=nil) {
        for (i,frame) in fixture.frames.enumerated() {
            beforeFrame?(i)
            model.capture.onObservation?(.init(timestamp:origin+frame.timestamp,sessionID:frame.sessionID,
                contacts:frame.contacts.enumerated().map { j,c in
                    .init(id:c.id,x:c.x,y:c.y,phase:c.phase.rawValue,isResting:fixture.captureMetadata.restingByFrame[i][j])
                },modifiers:frame.modifiers.map(\.rawValue)))
        }
    }
    @Test func physicalTapReachesPreviewAndFrozenExportWithoutDispatch() throws {
        try withModel { model,fixture in
            model.recordSample()
            let origin=ProcessInfo.processInfo.systemUptime+1
            replay(fixture,into:model,at:origin)
            #expect(model.diagnostics.events.filter { $0 == .recognized }.count == 1)
            #expect(!model.diagnostics.events.contains(.actionDispatched))
            #expect(!model.diagnostics.events.contains(.actionFailed))
            #expect(model.status.contains("Physical Tap"))
            #expect(model.status.contains("No action executed"))
            #expect(model.status.contains("Sample frozen"))
            #expect(model.contacts.isEmpty)
            #expect(!model.isRecording)
            let data=try model.sampleDataForExport(at:origin+0.2)
            let json=try #require(JSONSerialization.jsonObject(with:data) as? [String:Any])
            let recording=try #require(json["recording"] as? [String:Any])
            #expect(recording["finishReason"] as? String == "sequenceEnded")
            #expect((json["samples"] as? [Any])?.count == 7)
        }
    }
    @Test(arguments:["click","scroll","pinch","rotate"])
    func nativeInterferenceCancelsPhysicalReplayAndNextFreshSequenceRecovers(_ kind:String) throws {
        try withModel { model,fixture in
            let origin=ProcessInfo.processInfo.systemUptime+1
            replay(fixture,into:model,at:origin) { i in
                if i == 3 { model.capture.onNativeGesture?(kind) }
            }
            #expect(!model.diagnostics.events.contains(.recognized))
            #expect(!model.diagnostics.events.contains(.actionDispatched))
            replay(fixture,into:model,at:origin+1)
            #expect(model.diagnostics.events.filter { $0 == .recognized }.count == 1)
            #expect(model.contacts.isEmpty)
        }
    }
    @Test(arguments:[0.2, 1.0])
    func tenReplaysRespectCooldownAcrossEmptyBoundaries(_ interval:Double) throws {
        try withModel { model,fixture in
            let origin=ProcessInfo.processInfo.systemUptime+1
            model.diagnostics=SafeDiagnostics(capacity:128) // Retain this bounded short replay for the tally.
            for i in 0..<10 { replay(fixture,into:model,at:origin+Double(i)*interval) }
            // Cooldown filters candidates at sequence start: fast taps win at 0.106,
            // 0.906 and 1.706. One-second spacing admits every tap.
            #expect(model.diagnostics.events.filter { $0 == .recognized }.count == (interval == 0.2 ? 3 : 10))
            #expect(!model.diagnostics.events.contains(.actionDispatched))
            #expect(model.contacts.isEmpty)
        }
    }
}
