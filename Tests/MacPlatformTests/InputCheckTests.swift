import Foundation
import Testing
@testable import MacPlatform

struct InputCheckTests {
    @Test func deadlineAndStopFreezeCounts() {
        var window = InputCheckWindow(start: 100)
        window.record(channel: .global, kind: .pointer, at: 100)
        window.record(channel: .quartz, kind: .click, at: 129.999)
        window.record(channel: .global, kind: .pointer, at: 130)
        #expect(window.counts == ["global.pointer": 1, "quartz.click": 1])
        #expect(window.expired(at: 130))
        window.finish(reason: .completed, at: 130.2)
        window.record(channel: .local, kind: .scroll, at: 130.3)
        #expect(window.counts.count == 2)
        #expect(window.duration == 30)
        #expect(window.reason == .completed)
    }

    @Test func invalidClockAndEarlyCancellation() {
        var window = InputCheckWindow(start: 100)
        window.record(channel: .global, kind: .pointer, at: 99)
        window.record(channel: .global, kind: .pointer, at: .nan)
        #expect(window.counts.isEmpty)
        window.record(channel: .local, kind: .click, at: 102)
        window.finish(reason: .permissionChanged, at: 104)
        window.finish(reason: .completed, at: 130)
        window.record(channel: .global, kind: .pointer, at: 105)
        #expect(window.reason == .permissionChanged)
        #expect(window.duration == 4)
        #expect(window.counts == ["local.click": 1])
    }

    @Test func dataVocabularyIsBoundedAndNewRunIsEmpty() throws {
        var window = InputCheckWindow(start: 0)
        for channel in InputCheckChannel.allCases {
            for kind in InputCheckKind.allCases {
                window.record(channel: channel, kind: kind, at: 1)
            }
        }
        #expect(window.counts.count == 12)
        let encoded = try JSONEncoder().encode(window.counts)
        #expect(encoded.count < 512)
        window = InputCheckWindow(start: 500)
        #expect(window.counts.isEmpty)
        #expect(window.reason == nil)
    }
}
