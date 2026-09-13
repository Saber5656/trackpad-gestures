import Foundation
import Testing
@testable import MacPlatform

private final class FakeInputCheckSource: InputCheckSource {
    var event: ((InputCheckChannel, InputCheckKind) -> Void)?
    var health = InputCheckHealth(inputMonitoring: true, accessibility: false, ownAppActive: true,
        localMonitor: true, globalMonitor: true, tapEnabled: true, dispatchTicks: 1, sessionAvailable: true,
        windowServerCounters: ["mouseMoved": UInt32.max])
    var stopCount = 0
    func start(onEvent: @escaping (InputCheckChannel, InputCheckKind) -> Void) { event = onEvent }
    func snapshot() -> InputCheckHealth { health }
    func stop() { stopCount += 1; event = nil }
}

@MainActor struct GlobalInputCheckTests {
    @Test func unavailableMonitorIsNotDisplayedAsZero() {
        let source = FakeInputCheckSource()
        source.health.inputMonitoring = false
        source.health.tapEnabled = nil
        source.health.globalMonitor = false
        let check = GlobalInputCheck(source: source, clock: { 100 }, save: { _ in }, automaticallyTick: false)
        check.start(); check.stop(reason: .cancelled)
        #expect(check.report?.pointerCount(channel: .quartz) == nil)
        #expect(check.report?.pointerCount(channel: .global) == nil)
        #expect(check.report?.pointerCount(channel: .local) == 0)
    }

    @Test func automaticallySavesFrozenCountsAndPreservesSourceDistinction() throws {
        let source = FakeInputCheckSource()
        var now = 100.0
        var saved: [Data] = []
        let check = GlobalInputCheck(source: source, clock: { now }, save: { saved.append($0) }, automaticallyTick: false)
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
        let check = GlobalInputCheck(source: source, clock: { now }, save: { saved.append($0) }, automaticallyTick: false)
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
        let check = GlobalInputCheck(source: source, clock: { 100 }, save: { _ in throw CocoaError(.fileWriteNoPermission) }, automaticallyTick: false)
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
}
