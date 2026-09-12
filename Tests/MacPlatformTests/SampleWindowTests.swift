import Testing
import Foundation
@testable import MacPlatform

struct SampleWindowTests {
    func sample(_ time: Double, phase: String = "began") -> TouchObservation {
        .init(timestamp: time, sessionID: "test", contacts: (0..<3).map {
            .init(id: "c\($0)", x: 0.3 + Double($0)*0.1, y: 0.5, phase: phase)
        }, modifiers: [])
    }
    @Test func movingFromRecordButtonDoesNotConsumeContactWindow() {
        var recorder = SampleRecorder()
        recorder.arm(at: 100)
        recorder.expire(at: 104)
        #expect(recorder.waitingForContact)
        recorder.append(sample(109))
        recorder.append(sample(110, phase: "ended"))
        #expect(recorder.samples.count == 2)
        #expect(recorder.metadata.captureStartedAt == 109)
        #expect(recorder.metadata.captureDeadline == 112)
        #expect(recorder.recording)
    }
    @Test func waitingIsBoundedAndDoesNotStartMidSequence() {
        var recorder = SampleRecorder(); recorder.arm(at: 10)
        recorder.append(sample(11, phase: "stationary"))
        recorder.append(.init(timestamp:12,sessionID:"test",contacts:[],modifiers:[]))
        #expect(recorder.waitingForContact)
        #expect(recorder.samples.isEmpty)
        recorder.expire(at:20.001)
        #expect(!recorder.active)
        #expect(recorder.metadata.finishReason == .waitingTimeout)
        #expect(recorder.metadata.captureStartedAt == nil)
    }
    @Test func actualContactRecordingStillHasThreeSecondLimit() {
        var recorder = SampleRecorder(); recorder.arm(at: 10)
        recorder.append(sample(12))
        recorder.append(sample(15, phase: "stationary"))
        recorder.append(sample(15.001, phase: "ended"))
        #expect(recorder.samples.count == 2)
        #expect(!recorder.active)
        #expect(recorder.metadata.finishReason == .durationLimit)
    }
    @Test func exportFreezesSampleAndRecordsActualWindow() throws {
        var recorder = SampleRecorder(); recorder.arm(at:10)
        recorder.append(sample(12)); recorder.append(sample(13,phase:"ended"))
        recorder.finishForExport(at:13.1)
        recorder.append(sample(13.2))
        #expect(recorder.samples.count == 2)
        #expect(recorder.metadata.finishReason == .exported)
        #expect(recorder.metadata.armedAt == 10)
        let data=try JSONEncoder().encode(recorder.metadata)
        #expect(try JSONDecoder().decode(SampleRecordingMetadata.self,from:data).captureStartedAt == 12)
        recorder.clear()
        #expect(recorder.metadata.captureStartedAt == nil)
        #expect(recorder.samples.isEmpty)
    }
}
