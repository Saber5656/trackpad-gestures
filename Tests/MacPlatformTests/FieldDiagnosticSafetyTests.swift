import AppKit
import Testing
@testable import MacPlatform

private final class InspectableEvent: NSEvent {
    var eventType: NSEvent.EventType = .mouseMoved
    var queryCount = 0
    var suppliedTouches: Set<NSTouch> = []
    override var type: NSEvent.EventType { eventType }
    override func touches(matching phase: NSTouch.Phase, in view: NSView?) -> Set<NSTouch> {
        queryCount += 1
        return suppliedTouches
    }
}

struct FieldDiagnosticSafetyTests {
    @Test func eventExtractionNeverQueriesOrdinaryEventsOrBookends() throws {
        let event = InspectableEvent()
        for type in [NSEvent.EventType.mouseMoved, .leftMouseDown, .scrollWheel, .keyDown] {
            event.eventType = type
            #expect(PublicInputCheckSource.gestureDetail(for: event) == nil)
        }
        for type in [NSEvent.EventType.beginGesture, .endGesture] {
            event.eventType = type
            let detail = try #require(PublicInputCheckSource.gestureDetail(for: event))
            #expect(!detail.touchesChecked)
        }
        #expect(event.queryCount == 0)
    }
    @Test func eventExtractionDistinguishesQueriedEmptySet() throws {
        let event = InspectableEvent()
        for type in [NSEvent.EventType.gesture, .magnify, .rotate, .swipe] {
            event.eventType = type
            let detail = try #require(PublicInputCheckSource.gestureDetail(for: event))
            #expect(detail.touchesChecked)
            #expect(detail.touchCount == 0)
            #expect(detail.phases.isEmpty)
        }
        #expect(event.queryCount == 4)
    }
    @Test func gestureDetailsRejectExpiredInvalidAndQuartzCallbacks() {
        var window = InputCheckWindow(start: 100)
        for time in [99, Double.nan, Double.infinity, 130, 131] {
            window.recordGesture(channel: .local, kind: .gesture, touchesChecked: true,
                touchCount: 3, phases: [.began], at: time)
        }
        window.recordGesture(channel: .quartz, kind: .gesture, touchesChecked: true,
            touchCount: 3, phases: [.began], at: 101)
        #expect(window.gestureDetail.isEmpty)
        window.finish(reason: .cancelled, at: 102)
        window.recordGesture(channel: .local, kind: .gesture, touchesChecked: true,
            touchCount: 3, phases: [.began], at: 103)
        #expect(window.gestureDetail.isEmpty)
    }

    @Test func noTouchQueryHasNoMaximum() {
        var window = InputCheckWindow(start: 100)
        window.recordGesture(channel: .global, kind: .beginGesture, touchesChecked: false,
            touchCount: 0, phases: [], at: 101)
        #expect(window.gestureDetail["global"]?.maxObservedTouches == nil)
    }
    @Test func oversizedTouchSetIsNotClampedToAnInventedCount() {
        var window = InputCheckWindow(start: 100)
        window.recordGesture(channel: .local, kind: .gesture, touchesChecked: true,
            touchCount: 21, phases: Array(repeating: .began, count: 21), at: 101)
        #expect(window.gestureDetail["local"]?.maxObservedTouches == 21)
        #expect(window.gestureDetail["local"]?.phaseCounts.isEmpty == true)
    }
    @Test func digitizerTotalSurvivesUsageDictionaryTruncation() {
        var accumulator = HIDUsageAccumulator()
        for usage in 0..<64 { accumulator.record(page: 1, usage: usage) }
        accumulator.record(page: 13, usage: 1)
        #expect(accumulator.truncated)
        #expect(accumulator.digitizerUsageEvents == 1)
    }
    @Test func onlyReferenceUSBMetadataMatches() {
        #expect(PublicHIDUsageSource.matchesReference(vendorID: 1452, productID: 804, product: "Magic Trackpad", transport: "USB"))
        #expect(!PublicHIDUsageSource.matchesReference(vendorID: 1452, productID: 804, product: "Magic Trackpad", transport: "Bluetooth"))
        #expect(!PublicHIDUsageSource.matchesReference(vendorID: 1452, productID: 804, product: "Magic Trackpad", transport: nil))
        #expect(!PublicHIDUsageSource.matchesReference(vendorID: 1452, productID: 1, product: "Magic Trackpad", transport: "USB"))
        #expect(!PublicHIDUsageSource.matchesReference(vendorID: nil, productID: 804, product: "Magic Trackpad", transport: "USB"))
    }
}
