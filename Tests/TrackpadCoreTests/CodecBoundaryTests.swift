import Testing
import Foundation
@testable import TrackpadCore

struct CodecBoundaryTests {
    @Test func rejectsOversizeMalformedFutureAndExecutableData() {
        for data in [Data(repeating:32,count:256*1024+1),Data([0xff]),Data(#"{"schemaVersion":2,"profiles":[]}"#.utf8),Data(#"{"schemaVersion":1,"profiles":[{"id":"p","name":"p","gestures":[],"actions":[{"id":"x","kind":"shell","command":"anything"}]}]}"#.utf8)] {
            #expect(throws:(any Error).self) { try ProfileCodec.decode(data) }
        }
    }
    @Test func rejectsDuplicateIDsMissingActionAndInvalidDuration() {
        let a=ActionDefinition(id:"beep",kind:.systemAction(.beep))
        let g=GestureDefinition(id:"g",name:"g",kind:.tap,actionID:"beep",fingerCount:3)
        let bad=GestureDefinition(id:"bad",name:"bad",kind:.hold,actionID:"beep",fingerCount:3,minDuration:2,maxDuration:1)
        for profile in [Profile(id:"p",name:"p",gestures:[g,g],actions:[a]),Profile(id:"p",name:"p",gestures:[g],actions:[]),Profile(id:"p",name:"p",gestures:[bad],actions:[a])] {
            #expect(throws:(any Error).self) { try ProfileCodec.encode(.init(profiles:[profile])) }
        }
    }
    @Test func missingPressureIsNotEncodedAsZeroAndNativePointerHasNoGesture() throws {
        let frame=NormalizedFrame(timestamp:1,sessionID:"s",transport:.unknown,contacts:[],modifiers:[])
        let encoded=try JSONEncoder().encode(frame)
        #expect(!String(decoding:encoded,as:UTF8.self).contains("pressure"))
        #expect(GestureEngine().process(frame).events.isEmpty)
    }
}
