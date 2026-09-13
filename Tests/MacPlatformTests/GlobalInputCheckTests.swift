import Foundation
import Testing
@testable import MacPlatform

private final class FakeInputCheckSource: InputCheckSource {
    var event: ((InputCheckChannel, InputCheckKind) -> Void)?
    var gestureEvent: ((InputCheckChannel, GestureEventKind, Bool, Int, [TouchPhaseKind]) -> Void)?
    var health = InputCheckHealth(inputMonitoring: true, accessibility: false, ownAppActive: true,
        localMonitor: true, globalMonitor: true, tapEnabled: true, dispatchTicks: 1, sessionAvailable: true,
        windowServerCounters: ["mouseMoved": UInt32.max])
    var stopCount = 0
    func start(until deadline: Double, onEvent: @escaping (InputCheckChannel, InputCheckKind) -> Void,
               onGestureDetail: @escaping (InputCheckChannel, GestureEventKind, Bool, Int, [TouchPhaseKind]) -> Void) {
        event = onEvent; gestureEvent = onGestureDetail
    }
    func snapshot() -> InputCheckHealth { health }
    func stop() { stopCount += 1; event = nil; gestureEvent = nil }
}

private final class FakeHIDUsageSource: HIDUsageSource {
    var onValue: ((Int, Int) -> Void)?
    var outcome: HIDUsageStartOutcome = .unavailable(reason: "test")
    var stopCount = 0
    func start(until deadline: Double, onValue: @escaping (Int, Int) -> Void) -> HIDUsageStartOutcome {
        self.onValue = onValue; return outcome
    }
    func stop() { stopCount += 1; onValue = nil }
}

@MainActor struct GlobalInputCheckTests {
    @Test func unavailableMonitorIsNotDisplayedAsZero() {
        let source = FakeInputCheckSource()
        source.health.inputMonitoring = false
        source.health.tapEnabled = nil
        source.health.globalMonitor = false
        let check = GlobalInputCheck(source: source, hidUsageSource: FakeHIDUsageSource(),
            clock: { 100 }, save: { _ in }, automaticallyTick: false)
        check.start(); check.stop(reason: .cancelled)
        #expect(check.report?.pointerCount(channel: .quartz) == nil)
        #expect(check.report?.pointerCount(channel: .global) == nil)
        #expect(check.report?.pointerCount(channel: .local) == 0)
    }

    @Test func automaticallySavesFrozenCountsAndPreservesSourceDistinction() throws {
        let source = FakeInputCheckSource()
        var now = 100.0
        var saved: [Data] = []
        let check = GlobalInputCheck(source: source, hidUsageSource: FakeHIDUsageSource(),
            clock: { now }, save: { saved.append($0) }, automaticallyTick: false)
        check.start()
        source.event?(.local, .pointer)
        source.event?(.global, .pointer)
        source.health.ownAppActive = false
        source.health.windowServerCounters = ["mouseMoved": 1]
        now = 101; check.tick()
        #expect(check.isRunning)
        now = 130; check.tick()
        #expect(!check.isRunning)
        #expect(source.stopCount == 1)
        #expect(saved.count == 1)
        let report = try JSONDecoder().decode(InputCheckReport.self, from: saved[0])
        #expect(report.counts == ["global.pointer": 1, "local.pointer": 1])
        #expect(report.windowServerDelta == ["mouseMoved": 2])
        #expect(report.reason == .completed)
        #expect(report.backgroundSamples > 0)
        now = 132; check.stop(reason: .cancelled)
        #expect(saved.count == 1)
        #expect(check.report?.id == report.id)
        #expect(report.healthBefore.accessibility == false)
    }

    @Test(arguments: [InputCheckEnd.permissionChanged, .sleepOrLock, .deviceChanged, .appExit])
    func interruptionStopsSourceAndSavesReason(reason: InputCheckEnd) throws {
        let source = FakeInputCheckSource()
        var now = 100.0
        var saved: [Data] = []
        let check = GlobalInputCheck(source: source, hidUsageSource: FakeHIDUsageSource(),
            clock: { now }, save: { saved.append($0) }, automaticallyTick: false)
        check.start(); now = 103
        if reason == .permissionChanged { source.health.inputMonitoring = false; check.tick() }
        else { check.stop(reason: reason) }
        #expect(source.stopCount == 1)
        #expect(check.report?.reason == reason)
        #expect(check.report?.durationSeconds == 3)
        #expect(saved.count == 1)
    }

    @Test func failedSaveIsVisibleAndRestartClearsOldResult() {
        let source = FakeInputCheckSource()
        let check = GlobalInputCheck(source: source, hidUsageSource: FakeHIDUsageSource(),
            clock: { 100 }, save: { _ in throw CocoaError(.fileWriteNoPermission) }, automaticallyTick: false)
        check.start(); source.event?(.global, .scroll)
        check.stop(reason: .cancelled)
        #expect(check.saveSucceeded == false)
        #expect(check.report?.counts == ["global.scroll": 1])
        check.start()
        #expect(check.report == nil)
        #expect(check.saveSucceeded == nil)
        check.stop(reason: .appExit)
        #expect(check.report?.counts.isEmpty == true)
    }

    @Test func gestureDetailCapturesExactKindAndTouchesOnlyWhereValid() throws {
        let source = FakeInputCheckSource()
        let check = GlobalInputCheck(source: source, hidUsageSource: FakeHIDUsageSource(),
            clock: { 100 }, save: { _ in }, automaticallyTick: false)
        check.start()
        source.gestureEvent?(.local, .magnify, true, 2, [.began, .began])
        source.gestureEvent?(.local, .magnify, true, 0, [])
        source.gestureEvent?(.local, .beginGesture, false, 0, [])
        source.gestureEvent?(.global, .swipe, true, 3, [.stationary])
        check.stop(reason: .cancelled)
        let local = try #require(check.report?.gestureDetail?["local"])
        #expect(local.eventKindCounts == ["magnify": 2, "beginGesture": 1])
        #expect(local.touchesCheckedEvents == 2)
        #expect(local.eventsWithTouches == 1)
        #expect(local.maxObservedTouches == 2)
        #expect(local.phaseCounts == ["began": 2])
        let global = try #require(check.report?.gestureDetail?["global"])
        #expect(global.eventKindCounts == ["swipe": 1])
        #expect(global.maxObservedTouches == 3)
        #expect(check.report?.gestureDetail?["quartz"] == nil)
    }

    @Test func noGestureEventsLeaveGestureDetailAbsentNotZero() {
        let source = FakeInputCheckSource()
        let check = GlobalInputCheck(source: source, hidUsageSource: FakeHIDUsageSource(),
            clock: { 100 }, save: { _ in }, automaticallyTick: false)
        check.start(); check.stop(reason: .cancelled)
        #expect(check.report?.gestureDetail == nil)
    }

    @Test func hidUsageObservationReportsUnavailableReasonWithoutFakingCounts() {
        let source = FakeInputCheckSource()
        let hid = FakeHIDUsageSource()
        hid.outcome = .unavailable(reason: "inputMonitoringNotGranted")
        let check = GlobalInputCheck(source: source, hidUsageSource: hid,
            clock: { 100 }, save: { _ in }, automaticallyTick: false)
        check.start(); check.stop(reason: .cancelled)
        let observation = check.report?.hidUsageObservation
        #expect(observation?.available == false)
        #expect(observation?.reason == "inputMonitoringNotGranted")
        #expect(observation?.usageCounts.isEmpty == true)
        #expect(observation?.inputValueEvents == nil)
        #expect(hid.stopCount == 1)
    }

    @Test func hidUsageObservationCountsUsagesAndCapsCardinality() {
        let source = FakeInputCheckSource()
        let hid = FakeHIDUsageSource()
        hid.outcome = .started(transport: "USB")
        var now = 100.0
        let check = GlobalInputCheck(source: source, hidUsageSource: hid,
            clock: { now }, save: { _ in }, automaticallyTick: false)
        check.start()
        for usage in 0..<80 { hid.onValue?(0x0d, usage) }
        hid.onValue?(0x0d, 0)
        now = 135; check.stop(reason: .cancelled)
        let observation = try! #require(check.report?.hidUsageObservation)
        #expect(observation.available == true)
        #expect(observation.transport == "USB")
        #expect(observation.usageCounts.count == 64)
        #expect(observation.distinctUsagesTruncated == true)
        #expect(observation.inputValueEvents == 81)
        #expect(observation.digitizerUsageEvents == 81)
    }

    @Test func hidUsageStopsDeliveringAfterHardDeadlineEvenIfSourceKeepsCalling() {
        let source = FakeInputCheckSource()
        let hid = FakeHIDUsageSource()
        hid.outcome = .started(transport: "USB")
        var now = 100.0
        let check = GlobalInputCheck(source: source, hidUsageSource: hid,
            clock: { now }, save: { _ in }, automaticallyTick: false)
        check.start()
        hid.onValue?(0x0d, 1)
        now = 130.1
        hid.onValue?(0x0d, 2)
        check.stop(reason: .completed)
        #expect(check.report?.hidUsageObservation?.inputValueEvents == 1)
    }

    @Test func decodingPreExistingSchemaOneReportWithoutNewFieldsSucceeds() throws {
        let legacy = """
        {"schemaVersion":1,"id":"a","startedAt":"t","finishedAt":"t","durationSeconds":30,
         "reason":"completed","counts":{},"saturated":false,"foregroundSamples":1,"backgroundSamples":0,
         "healthBefore":{"inputMonitoring":true,"accessibility":false,"ownAppActive":true,
           "localMonitor":true,"globalMonitor":true,"dispatchTicks":1,"sessionAvailable":true},
         "healthAfter":{"inputMonitoring":true,"accessibility":false,"ownAppActive":true,
           "localMonitor":true,"globalMonitor":true,"dispatchTicks":1,"sessionAvailable":true},
         "limitations":[]}
        """.data(using: .utf8)!
        let report = try JSONDecoder().decode(InputCheckReport.self, from: legacy)
        #expect(report.gestureDetail == nil)
        #expect(report.hidUsageObservation == nil)
    }
}
