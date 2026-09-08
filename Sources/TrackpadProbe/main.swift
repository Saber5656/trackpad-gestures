import AppKit
import ApplicationServices
import IOKit.hid
import MacPlatform

// Count-only probe. No event payload, key code, serial or raw HID report is retained.
let seconds = min(60.0, max(1.0, Double(CommandLine.arguments.dropFirst().first ?? "8") ?? 8))
let app = NSApplication.shared
app.setActivationPolicy(.prohibited)
var counts: [String: Int] = [:]
func count(_ key: String) { if counts.count < 64 || counts[key] != nil { counts[key, default: 0] += 1 } }
let mask: NSEvent.EventTypeMask = [.gesture, .magnify, .rotate, .swipe, .beginGesture, .endGesture, .scrollWheel, .leftMouseDown, .leftMouseUp, .mouseMoved]
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
let hidStatus = listening ? IOHIDManagerOpen(manager, 0) : kIOReturnNotPermitted
let start = ProcessInfo.processInfo.systemUptime
RunLoop.current.run(until: Date().addingTimeInterval(seconds))
if let local { NSEvent.removeMonitor(local) }; if let global { NSEvent.removeMonitor(global) }
if let tap { CFMachPortInvalidate(tap) }
IOHIDManagerUnscheduleFromRunLoop(manager, CFRunLoopGetCurrent(), CFRunLoopMode.commonModes.rawValue)
IOHIDManagerClose(manager, 0)
let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
struct Report: Codable {
    let os: String; let architecture: String; let durationSeconds: Double
    let accessibility: Bool; let inputMonitoring: Bool; let eventTapCreated: Bool; let hidOpenStatus: Int32
    let devices: [DeviceInfo]; let counts: [String: Int]; let limitations: [String]
}
#if arch(arm64)
let architecture = "arm64"
#else
let architecture = "x86_64"
#endif
let report = Report(os: ProcessInfo.processInfo.operatingSystemVersionString, architecture: architecture,
 durationSeconds: ProcessInfo.processInfo.systemUptime - start, accessibility: AXIsProcessTrusted(), inputMonitoring: listening,
 eventTapCreated: tap != nil, hidOpenStatus: hidStatus, devices: DeviceDiscovery.list(), counts: counts,
 limitations: ["No permission prompt requested; preflight only", "IOHID VersionNumber is metadata, not verified firmware", "Global contact fields unavailable in implemented documented path", "Zero observed events do not prove lack of hardware support", "No device-specific latency/loss or coexistence certification"])
print(String(data: try encoder.encode(report), encoding: .utf8)!)
