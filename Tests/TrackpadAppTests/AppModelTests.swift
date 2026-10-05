import Testing
import Foundation
import TrackpadCore
import MacPlatform
@testable import TrackpadApp

final class DeferredActionBackend: ActionBackend {
    var completions: [(Bool) -> Void]=[]
    func perform(_ action: SafeAction) throws { throw ActionFailure.unavailable }
    func perform(_ action: SafeAction, completion: @escaping (Bool) -> Void) throws { completions.append(completion) }
}

@MainActor struct AppModelTests {
    @Test func deferredActionFailureRecordsOnlyItsConfirmedOutcome() throws {
        let dir=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at:dir) }
        let backend=DeferredActionBackend()
        let model=AppModel(storage:dir.appendingPathComponent("profile.json"),actionBackend:backend); defer { model.shutdown() }
        model.draft.actionKind="hide"; model.draft.actionValue="com.apple.calculator"
        model.testAction(now:1)
        #expect(!model.diagnostics.events.contains(.actionDispatched))
        #expect(!model.diagnostics.events.contains(.actionFailed))
        #expect(backend.completions.count == 1)
        let complete=try #require(backend.completions.first)
        complete(false)
        #expect(model.diagnostics.events.filter { $0 == .actionFailed }.count == 1)
        #expect(!model.diagnostics.events.contains(.actionDispatched))
        #expect(model.status == "System handler could not dispatch the action.")
    }
    @Test func staleActionCompletionPreservesNewerFeedbackAndRecordsFailure() throws {
        let dir=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at:dir) }
        let backend=DeferredActionBackend()
        let model=AppModel(storage:dir.appendingPathComponent("profile.json"),actionBackend:backend); defer { model.shutdown() }
        model.draft.actionKind="hide"; model.draft.actionValue="com.apple.calculator"
        model.testAction(now:1)
        let hide=try #require(backend.completions.first)
        model.draft.actionKind="beep"; model.testAction(now:1.6)
        #expect(backend.completions.count == 2)
        let beep=try #require(backend.completions.last)
        beep(true)
        #expect(model.status == "Action dispatched to its system handler. Completion is not monitored.")
        let newerStatus=model.status
        hide(false)
        #expect(model.status == newerStatus)
        #expect(model.diagnostics.events.filter { $0 == .actionDispatched }.count == 1)
        #expect(model.diagnostics.events.filter { $0 == .actionFailed }.count == 1)
    }
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
    @Test func fiveFingerRightZoneSwipeRecognizesWithoutAction() {
        let dir=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at:dir) }
        let model=AppModel(storage:dir.appendingPathComponent("profile.json")); defer { model.shutdown() }
        model.draft.name="Right-zone swipe"; model.draft.kind="swipe"; model.draft.direction="left"
        model.draft.fingers=5; model.draft.zone="right"; model.draft.movement=0.15
        model.draft.maximum=1; model.draft.command=true; model.draft.appScope="com.apple.calculator"
        model.draft.priority=2; model.draft.cooldown=1.25; model.previewScope=model.draft.appScope
        model.saveGesture()
        model.simulate()
        RunLoop.main.run(until:Date().addingTimeInterval(0.4))
        #expect(model.status == "Recognized in preview: Right-zone swipe. No action executed.")
        #expect(!model.diagnostics.events.contains(.actionDispatched))
    }
}

struct SyntheticPathTests {
    let zones: [Zone]=[.any,.left,.right,.top,.bottom,.topLeft,.topRight,.bottomLeft,.bottomRight]
    @Test func everyZoneAndFingerCountKeepsCoherentBoundedSwipes() throws {
        for fingers in 2...5 { for zone in zones { for direction in [Direction.left,.right,.up,.down] {
            let g=GestureDefinition(id:"swipe",name:"swipe",kind:.swipe(direction),actionID:"beep",fingerCount:fingers,
                                    zone:zone,movementThreshold:0.15,maxDuration:1,modifiers:[.command],applicationScope:"com.apple.calculator")
            let path=try #require(SyntheticContactPath(g))
            let engine=GestureEngine(definitions:[g])
            var winners: [String]=[]
            for step in 0...6 {
                let contacts=path.contacts(at:Double(step)/6,phase:step==0 ? .began : (step==6 ? .ended : .moved))
                #expect(contacts.allSatisfy { (0...1).contains($0.x) && (0...1).contains($0.y) })
                let frame=NormalizedFrame(timestamp:1+Double(step)/30,sessionID:"synthetic",transport:.simulation,
                                          capabilities:[.multiTouch,.contactIdentity,.normalizedCoordinates],contacts:contacts,
                                          appScope:g.applicationScope,modifiers:g.modifiers)
                winners += engine.process(frame).events.map(\.gestureID)
            }
            #expect(winners == [g.id], "\(fingers) fingers / \(zone) / \(direction)")
        } } }
    }
    @Test func marginDoesNotPreventFeasibleEdgeSwipe() throws {
        let g=GestureDefinition(id:"swipe",name:"swipe",kind:.swipe(.right),actionID:"beep",fingerCount:5,zone:.right,movementThreshold:0.19)
        let path=try #require(SyntheticContactPath(g))
        #expect(abs(path.dx-0.19) < 1e-9)
        #expect(path.contacts(at:1,phase:.ended).allSatisfy { $0.x <= 1 })
    }
    @Test func impossibleEdgeSwipeDoesNotInventClippedMotion() {
        let g=GestureDefinition(id:"swipe",name:"swipe",kind:.swipe(.right),actionID:"beep",fingerCount:5,zone:.right,movementThreshold:0.4)
        #expect(SyntheticContactPath(g) == nil)
    }
    @Test func stationaryGesturesKeepTheirStartCentroidInZone() throws {
        for fingers in 2...5 { for zone in zones { for kind in [GestureKind.tap,.hold] {
            let g=GestureDefinition(id:"stationary",name:"stationary",kind:kind,actionID:"beep",fingerCount:fingers,zone:zone)
            let path=try #require(SyntheticContactPath(g))
            let contacts=path.contacts(at:0,phase:.began)
            #expect(GestureOrdering.zoneContains(zone,x:contacts.map(\.x).reduce(0,+)/Double(fingers),y:contacts.map(\.y).reduce(0,+)/Double(fingers)))
            #expect(path.dx == 0 && path.dy == 0)
            #expect(contacts.allSatisfy { (0...1).contains($0.x) && (0...1).contains($0.y) })
        } } }
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
