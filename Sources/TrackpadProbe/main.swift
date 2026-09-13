import AppKit
import ApplicationServices
import IOKit.hid
import MacPlatform

// Count-only probe. No event payload, key code, serial or raw HID report is retained.
let seconds = min(60.0, max(1.0, Double(CommandLine.arguments.dropFirst().first ?? "8") ?? 8))
let verifyDispatch = CommandLine.arguments.contains("--verify-dispatch")
let app = NSApplication.shared
app.setActivationPolicy(.prohibited)
var counts: [String: Int] = [:]
func count(_ key: String) { if counts.count < 64 || counts[key] != nil { counts[key, default: 0] += 1 } }
var mask: NSEvent.EventTypeMask = [.gesture, .magnify, .rotate, .swipe, .beginGesture, .endGesture, .scrollWheel, .leftMouseDown, .leftMouseUp, .mouseMoved]
if verifyDispatch { mask.insert(.applicationDefined) }
let local = NSEvent.addLocalMonitorForEvents(matching: mask) { event in count("local.\(event.type.rawValue)"); return event }
let global = NSEvent.addGlobalMonitorForEvents(matching: mask) { event in count("global.\(event.type.rawValue)") }
let listening = CGPreflightListenEventAccess()
var tap: CFMachPort?
var source: CFRunLoopSource?
if listening {
    let eventMask = [CGEventType.mouseMoved, .leftMouseDown, .leftMouseUp, .scrollWheel].reduce(UInt64(0)) { $0 | (1 << $1.rawValue) }
    tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .tailAppendEventTap, options: .listenOnly, eventsOfInterest: eventMask, callback: { _, type, event, _ in
        count("quartz.\(type.rawValue)")
        return Unmanaged.passUnretained(event)
    }, userInfo: nil)
    if let tap { source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0); CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes) }
}
let manager = IOHIDManagerCreate(kCFAllocatorDefault, 0)
IOHIDManagerSetDeviceMatching(manager, [kIOHIDProductKey: "Magic Trackpad"] as CFDictionary)
IOHIDManagerRegisterInputValueCallback(manager, { _, _, _, value in
    let element = IOHIDValueGetElement(value)
    // Store usages only, never actual values. This is not a protocol decoder.
    count("hid.\(IOHIDElementGetUsagePage(element)).\(IOHIDElementGetUsage(element))")
}, nil)
IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetCurrent(), CFRunLoopMode.commonModes.rawValue)
let hidStatus: Int32? = listening ? IOHIDManagerOpen(manager, 0) : nil
var dispatchTimer: Timer?
if verifyDispatch {
    let timer = Timer(timeInterval: 0.01, repeats: false) { _ in count("probe.runLoopSelfTest") }
    RunLoop.current.add(timer, forMode: .common)
    dispatchTimer = timer
    // An app-local sentinel for the isolated process test; never system mouse/key input.
    if let sentinel = NSEvent.otherEvent(with: .applicationDefined, location: .zero, modifierFlags: [],
        timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: 0, context: nil, subtype: 0, data1: 0, data2: 0) {
        app.postEvent(sentinel, atStart: false)
    }
}
struct SessionSnapshot: Codable {
    let available: Bool
    let onConsole: Bool?
    let loginDone: Bool?
    static func current() -> Self {
        let session = CGSessionCopyCurrentDictionary() as? [String: Any]
        // Never serialize the dictionary: it also contains user names and identifiers.
        return .init(available: session != nil, onConsole: session?[kCGSessionOnConsoleKey as String] as? Bool,
                     loginDone: session?[kCGSessionLoginDoneKey as String] as? Bool)
    }
}
let counterTypes: [(String, CGEventType)] = [("mouseMoved", .mouseMoved), ("leftMouseDown", .leftMouseDown),
                                          ("leftMouseUp", .leftMouseUp), ("scrollWheel", .scrollWheel)]
func windowServerCounters() -> [String: UInt32] {
    Dictionary(uniqueKeysWithValues: counterTypes.map { ($0.0, CGEventSource.counterForEventType(.combinedSessionState, eventType: $0.1)) })
}
let sessionBefore = SessionSnapshot.current()
let initialCounters = sessionBefore.available ? windowServerCounters() : nil
let eventTapEnabledBefore = tap.map { CGEvent.tapIsEnabled(tap: $0) }
let start = ProcessInfo.processInfo.systemUptime
// Wall-clock bounds of the recording window, so a user-reported action time can be
// checked against whether it actually fell inside this run rather than before/after it.
let startEpoch = Date().timeIntervalSince1970
MainActor.assumeIsolated { ProbeEventLoop.run(seconds: seconds) }
let endEpoch = Date().timeIntervalSince1970
dispatchTimer?.invalidate()
let eventTapEnabledAfter = tap.map { CGEvent.tapIsEnabled(tap: $0) }
let sessionAfter = SessionSnapshot.current()
// Aggregate session traffic, not device attribution or a loss measurement.
let windowServerCounts: [String: UInt32]? = initialCounters.flatMap { before in
    guard sessionAfter.available else { return nil }
    return windowServerCounters().reduce(into: [:]) { result, entry in
        result[entry.key] = entry.value &- before[entry.key, default: entry.value]
    }
}
if let local { NSEvent.removeMonitor(local) }; if let global { NSEvent.removeMonitor(global) }
if let tap { CFMachPortInvalidate(tap) }
IOHIDManagerUnscheduleFromRunLoop(manager, CFRunLoopGetCurrent(), CFRunLoopMode.commonModes.rawValue)
IOHIDManagerClose(manager, 0)
let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
struct Report: Codable {
    let dispatchSelfTest: Bool
    let localMonitorCreated: Bool; let globalMonitorCreated: Bool
    let eventTapEnabledBefore: Bool?; let eventTapEnabledAfter: Bool?
    let sessionBefore: SessionSnapshot; let sessionAfter: SessionSnapshot
    let windowServerCounts: [String: UInt32]?
    let os: String; let architecture: String; let durationSeconds: Double
    let recordingStartedAtEpoch: Double; let recordingEndedAtEpoch: Double
    let accessibility: Bool; let inputMonitoring: Bool; let eventTapCreated: Bool; let hidOpenAttempted: Bool; let hidOpenStatus: Int32?
    let devices: [DeviceInfo]; let hidInventory: HIDInventorySnapshot; let counts: [String: Int]; let limitations: [String]
}
#if arch(arm64)
let architecture = "arm64"
#else
let architecture = "x86_64"
#endif
let report = Report(dispatchSelfTest: verifyDispatch, localMonitorCreated: local != nil, globalMonitorCreated: global != nil,
 eventTapEnabledBefore: eventTapEnabledBefore, eventTapEnabledAfter: eventTapEnabledAfter,
 sessionBefore: sessionBefore, sessionAfter: sessionAfter, windowServerCounts: windowServerCounts, os: ProcessInfo.processInfo.operatingSystemVersionString, architecture: architecture,
 durationSeconds: ProcessInfo.processInfo.systemUptime - start,
 recordingStartedAtEpoch: startEpoch, recordingEndedAtEpoch: endEpoch, accessibility: AXIsProcessTrusted(), inputMonitoring: listening,
 eventTapCreated: tap != nil, hidOpenAttempted: listening, hidOpenStatus: hidStatus, devices: DeviceDiscovery.list(), hidInventory: HIDCollectionInventory.list(), counts: counts,
 limitations: ["No permission prompt requested; preflight only", "IOHID VersionNumber is metadata, not verified firmware", "Global contact fields unavailable in implemented documented path", "Zero observed events do not prove lack of hardware support", "No device-specific latency/loss or coexistence certification", "Window-server counters are aggregate session traffic; they cannot establish physical origin, contact count or capture loss"])
print(String(data: try encoder.encode(report), encoding: .utf8)!)
