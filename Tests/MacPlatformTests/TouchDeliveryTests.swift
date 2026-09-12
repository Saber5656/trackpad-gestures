import AppKit
import Foundation
import Testing
@testable import MacPlatform
import TrackpadCore

// Public AppKit test doubles; these events are never posted to the OS.
private final class TestTouch: NSTouch, @unchecked Sendable {
    let key: NSString
    let value: NSTouch.Phase
    init(_ key: NSString, _ phase: NSTouch.Phase) { self.key=key; value=phase; super.init() }
    override var identity: any NSCopying & NSObjectProtocol { key }
    override var phase: NSTouch.Phase { value }
    override var normalizedPosition: NSPoint { .init(x:0.5,y:0.5) }
    override var isResting: Bool { true }
}
private final class TestTouchEvent: NSEvent {
    let time: Double
    let values: Set<NSTouch>
    init(_ time: Double, _ values: [NSTouch]) { self.time=time; self.values=Set(values); super.init() }
    required init?(coder: NSCoder) { fatalError("unused") }
    override var timestamp: TimeInterval { time }
    override var modifierFlags: NSEvent.ModifierFlags { [] }
    override func touches(matching phase: NSTouch.Phase, in view: NSView?) -> Set<NSTouch> { values }
}

@MainActor struct TouchDeliveryTests {
    @Test func mixedPhaseEventIsNormalizedOnceAndDoesNotReassignEndedIdentity() {
        let view=TouchCaptureView(frame:.zero)
        var samples: [TouchObservation]=[]
        view.onObservation={ samples.append($0) }; view.start()
        let a="a" as NSString, b="b" as NSString, c="c" as NSString
        view.touchesBegan(with:TestTouchEvent(0,[TestTouch(a,.began)]))
        view.touchesBegan(with:TestTouchEvent(0.016,[TestTouch(a,.stationary),TestTouch(b,.began),TestTouch(c,.began)]))
        let mixed=TestTouchEvent(0.046,[TestTouch(a,.stationary),TestTouch(b,.ended),TestTouch(c,.moved)])
        view.touchesMoved(with:mixed)
        view.touchesEnded(with:mixed)
        view.touchesEnded(with:TestTouchEvent(0.061,[TestTouch(a,.ended),TestTouch(c,.ended)]))
        #expect(samples.count == 4)
        #expect(Set(samples.flatMap(\.contacts).map(\.id)).count == 3)
        let tap=GestureDefinition(id:"tap",name:"Tap",kind:.tap,actionID:"beep",fingerCount:3,movementThreshold:0.06,enabled:true)
        let engine=GestureEngine(definitions:[tap])
        let results=samples.map { sample in
            engine.process(.init(timestamp:sample.timestamp,sessionID:sample.sessionID,transport:.unknown,
                capabilities:CapabilityRegistry.contactRecognition,contacts:sample.contacts.map {
                    Contact(id:$0.id,x:$0.x,y:$0.y,phase:ContactPhase(rawValue:$0.phase)!)
                }))
        }
        #expect(results.flatMap(\.events).map(\.gestureID) == ["tap"])
        #expect(!results.contains { $0.status == .malformed })
    }
    @Test func restingContactsAreRequestedAndReportedWithoutInventingUnavailableFlags() throws {
        let view=TouchCaptureView(frame:.zero)
        #expect(view.wantsRestingTouches)
        var samples: [TouchObservation]=[]
        view.onObservation={ samples.append($0) }; view.start()
        view.touchesBegan(with:TestTouchEvent(1,[TestTouch("resting" as NSString,.began)]))
        let contact=try #require(samples.first?.contacts.first)
        let encoded=try #require(JSONSerialization.jsonObject(with:JSONEncoder().encode(contact)) as? [String:Any])
        #expect(encoded["isResting"] as? Bool == true)
        let old=try JSONDecoder().decode(ObservedContact.self,from:Data(#"{"id":"c1","x":0.5,"y":0.5,"phase":"began"}"#.utf8))
        let roundTrip=try #require(JSONSerialization.jsonObject(with:JSONEncoder().encode(old)) as? [String:Any])
        #expect(roundTrip["isResting"] == nil)
    }
    @Test func distinctEventsAreNotDroppedJustBecauseTheirTimestampsMatch() {
        let view=TouchCaptureView(frame:.zero)
        var samples: [TouchObservation]=[]
        view.onObservation={ samples.append($0) }; view.start()
        let a="a" as NSString
        view.touchesBegan(with:TestTouchEvent(1,[TestTouch(a,.began)]))
        view.touchesEnded(with:TestTouchEvent(1,[TestTouch(a,.ended)]))
        #expect(samples.count == 2)
        #expect(samples.first?.contacts.first?.id == samples.last?.contacts.first?.id)
    }
    @Test func restartClearsDeliveryMemoryAndStopProducesNoObservation() {
        let view=TouchCaptureView(frame:.zero)
        var samples: [TouchObservation]=[]
        view.onObservation={ samples.append($0) }
        let event=TestTouchEvent(1,[TestTouch("a" as NSString,.began)])
        view.start(); view.touchesBegan(with:event); view.stop(); view.touchesMoved(with:event)
        #expect(samples.count == 1)
        view.start(); view.touchesBegan(with:event)
        #expect(samples.count == 2)
        #expect(samples.first?.sessionID != samples.last?.sessionID)
        #expect(samples.first?.contacts.first?.id != samples.last?.contacts.first?.id)
    }
}
