import Foundation
import Testing
@testable import MacPlatform

struct SampleSequenceTests {
    func frame(_ time: Double, _ phases: [(String,String)], session: String = "s") -> TouchObservation {
        .init(timestamp:time,sessionID:session,contacts:phases.map {
            .init(id:$0.0,x:0.5,y:0.5,phase:$0.1)
        },modifiers:[])
    }
    @Test func exportButtonMovementCannotExtendCompletedGesture() {
        var recorder=SampleRecorder(); recorder.arm(at:10)
        recorder.append(frame(11,[("a","began"),("b","began"),("c","began")]))
        recorder.append(frame(11.2,[("a","ended"),("b","ended"),("c","ended")]))
        recorder.append(frame(11.3,[("pointer","began")]))
        recorder.append(frame(11.4,[("pointer","moved")]))
        recorder.append(frame(11.5,[("pointer","ended")]))
        recorder.finishForExport(at:12)
        #expect(recorder.samples.count == 2)
        #expect(!recorder.active)
        #expect(recorder.metadata.finishedAt == 11.2)
        #expect(recorder.metadata.finishReason?.rawValue == "sequenceEnded")
    }
    @Test func staggeredLiftWaitsForEveryObservedContact() {
        var recorder=SampleRecorder(); recorder.arm(at:10)
        recorder.append(frame(11,[("a","began"),("b","began"),("c","began")]))
        recorder.append(frame(11.1,[("a","ended"),("b","stationary"),("c","stationary")]))
        #expect(recorder.active)
        recorder.append(frame(11.2,[("b","ended"),("c","stationary")]))
        #expect(recorder.active)
        recorder.append(frame(11.3,[("c","ended")]))
        #expect(!recorder.active)
        #expect(recorder.metadata.finishReason?.rawValue == "sequenceEnded")
        #expect(recorder.samples.count == 4)
    }
    @Test func missingContactsOrEmptyFrameDoNotInventAnEnd() {
        var recorder=SampleRecorder(); recorder.arm(at:10)
        recorder.append(frame(11,[("a","began"),("b","began"),("c","began")]))
        recorder.append(frame(11.1,[("a","ended")]))
        recorder.append(frame(11.2,[]))
        #expect(recorder.active)
        recorder.expire(at:14.01)
        #expect(recorder.metadata.finishReason == .durationLimit)
    }
    @Test func cancellationFreezesWithoutClaimingCompletion() {
        var recorder=SampleRecorder(); recorder.arm(at:10)
        recorder.append(frame(11,[("a","began"),("b","began")]))
        recorder.append(frame(11.1,[("a","cancelled"),("b","stationary")]))
        recorder.append(frame(11.2,[("pointer","began")]))
        #expect(recorder.samples.count == 2)
        #expect(recorder.metadata.finishReason?.rawValue == "sequenceCancelled")
    }
    @Test func foreignSessionOrUnknownTerminalCannotMarkSequenceCompleted() {
        for (terminal,session) in [("unknown","s"),("a","other")] {
            var recorder=SampleRecorder(); recorder.arm(at:10)
            recorder.append(frame(11,[("a","began")]))
            recorder.append(frame(11.1,[(terminal,"ended")],session:session))
            #expect(!recorder.active)
            #expect(recorder.metadata.finishReason?.rawValue == "invalidSequence")
            #expect(recorder.samples.count == 2) // Keep the bad observation for diagnosis.
        }
    }
    @Test func sequenceTrackingIsBoundedAndResetWhenRearmed() {
        var recorder=SampleRecorder(); recorder.arm(at:10)
        for index in 0..<11 {
            recorder.append(frame(11+Double(index)*0.01,[(String(index),"began")]))
        }
        #expect(!recorder.active)
        #expect(recorder.metadata.finishReason?.rawValue == "invalidSequence")
        recorder.arm(at:20)
        recorder.append(frame(21,[("fresh","began")]))
        recorder.append(frame(21.1,[("fresh","ended")]))
        #expect(recorder.samples.count == 2)
        #expect(recorder.metadata.finishReason?.rawValue == "sequenceEnded")
    }
}
