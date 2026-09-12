import Testing
import Foundation
import TrackpadCore
@testable import TrackpadApp

@MainActor struct AppModelTests {
    @Test func importDisarmsAndPreservesUnsupportedAction() throws {
        let dir=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at:dir) }
        let model=AppModel(storage:dir.appendingPathComponent("profile.json")); defer { model.shutdown() }
        let action=ActionDefinition(id:"key",kind:.keyboardShortcut(keycode:49,modifiers:[.command]))
        let g=GestureDefinition(id:"imported",name:"Imported",kind:.tap,actionID:"key",fingerCount:3,enabled:true)
        try model.importData(ProfileCodec.encode(.init(profiles:[.init(id:"p",name:"p",gestures:[g],actions:[action])])))
        #expect(model.definitions.first?.enabled == false)
        #expect(model.draft.actionKind == "unsupported")
        model.draft.name="Renamed"; model.saveGesture()
        #expect(model.profile.actions.first?.kind == action.kind)
        #expect(model.definitions.first?.enabled == false)
        #expect(!model.live)
    }
    @Test func invalidImportDoesNotReplaceProfile() throws {
        let dir=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at:dir) }
        let model=AppModel(storage:dir.appendingPathComponent("profile.json")); defer { model.shutdown() }
        let original=model.document
        #expect(throws:(any Error).self) { try model.importData(Data(#"{"schemaVersion":1,"profiles":[],"code":"shell"}"#.utf8)) }
        #expect(model.document == original)
    }
    @Test func disabledGestureSurvivesSaveAndRoundTrip() throws {
        let dir=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at:dir) }
        let model=AppModel(storage:dir.appendingPathComponent("profile.json")); defer { model.shutdown() }
        model.draft.enabled=false; model.saveGesture()
        #expect(model.definitions.first?.enabled == false)
        let data=try Data(contentsOf:dir.appendingPathComponent("profile.json"))
        #expect(try ProfileCodec.decode(data).document == model.document)
    }
}

@MainActor struct LivePreviewTests {
    @Test func completingLocalSequencePreservesCooldown() throws {
        let dir=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at:dir) }
        let model=AppModel(storage:dir.appendingPathComponent("profile.json")); defer { model.shutdown() }
        model.startLocal()
        func send(_ t:Double,_ phase:String) {
            model.acceptObservation(.init(timestamp:t,sessionID:"live-session",contacts:(0..<3).map { .init(id:String($0),x:0.3+Double($0)*0.06,y:0.4,phase:phase) },modifiers:[]))
        }
        send(1,"began"); send(1.1,"ended")
        let first=model.diagnostics.events.filter{$0 == .recognized}.count
        send(1.2,"began"); send(1.3,"ended")
        #expect(first == 1)
        #expect(model.diagnostics.events.filter{$0 == .recognized}.count == 1)
        #expect(model.contacts.isEmpty)
    }
}

@MainActor struct SampleRecordingAppTests {
    @Test func recordButtonWaitsForContactAfterPointerRepositioning() throws {
        let dir=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at:dir) }
        let model=AppModel(storage:dir.appendingPathComponent("profile.json")); defer { model.shutdown() }
        model.startLocal(); model.recordSample()
        let start=ProcessInfo.processInfo.systemUptime + 5
        for (offset,phase) in [(0.0,"began"),(1.0,"ended")] {
            model.acceptObservation(.init(timestamp:start+offset,sessionID:"record-test",contacts:(0..<3).map {
                .init(id:"c\($0)",x:0.3+Double($0)*0.1,y:0.5,phase:phase)
            },modifiers:[]))
        }
        #expect(model.sampleCount == 2)
        #expect(!model.isRecording)
        let data=try model.sampleDataForExport(at:start+1.1)
        let json=try #require(JSONSerialization.jsonObject(with:data) as? [String:Any])
        #expect(json["schemaVersion"] as? Int == 2)
        let recording=try #require(json["recording"] as? [String:Any])
        #expect(recording["captureStartedAt"] as? Double == start)
        #expect(recording["finishReason"] as? String == "sequenceEnded")
        #expect((json["samples"] as? [Any])?.count == 2)
        #expect(!model.isRecording)
    }
}

@MainActor struct FrozenSampleAppTests {
    @Test func livePointerMovementDoesNotChangeFrozenExport() throws {
        let dir=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at:dir) }
        let model=AppModel(storage:dir.appendingPathComponent("profile.json")); defer { model.shutdown() }
        model.startLocal(); model.recordSample()
        let start=ProcessInfo.processInfo.systemUptime+1
        for (offset,phase) in [(0.0,"began"),(0.1,"ended")] {
            model.acceptObservation(.init(timestamp:start+offset,sessionID:"gesture",contacts:(0..<3).map {
                .init(id:"c\($0)",x:0.3+Double($0)*0.1,y:0.5,phase:phase)
            },modifiers:[]))
        }
        #expect(!model.isRecording)
        #expect(model.status.contains("frozen"))
        model.acceptObservation(.init(timestamp:start+0.2,sessionID:"gesture",contacts:[
            .init(id:"pointer",x:0.6,y:0.7,phase:"began")
        ],modifiers:[]))
        #expect(model.sampleCount == 2)
        #expect(model.contacts.first?.id == "pointer") // Live visualizer remains live.
        let first=try model.sampleDataForExport(at:start+0.3)
        model.acceptObservation(.init(timestamp:start+0.4,sessionID:"gesture",contacts:[
            .init(id:"pointer",x:0.8,y:0.7,phase:"ended")
        ],modifiers:[]))
        #expect(try model.sampleDataForExport(at:start+0.5) == first)
        let file=try #require(JSONSerialization.jsonObject(with:first) as? [String:Any])
        #expect((file["samples"] as? [Any])?.count == 2)
        let meta=try #require(file["recording"] as? [String:Any])
        #expect(meta["finishReason"] as? String == "sequenceEnded")
        #expect(meta["finishedAt"] as? Double == start+0.1)
    }
}
