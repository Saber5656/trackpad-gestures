import Foundation
import IOKit.hid
import ApplicationServices

// Bounded, read-only summary of which HID usage(page,usage) pairs fired input value callbacks
// during the observation window. This counts that a usage was reported, not what value it held;
// it never establishes contact/finger counts, only whether the given usage is exercised at all.
public struct HIDUsageObservation: Codable, Sendable, Equatable {
    public let available: Bool
    public let reason: String?
    public let transport: String?
    public let inputValueEvents: Int?
    public let usageCounts: [String: Int]
    public let digitizerUsageEvents: Int?
    public let distinctUsagesTruncated: Bool
    public let countersSaturated: Bool
    public let openStatus: Int32?
}

public enum HIDUsageStartOutcome: Sendable, Equatable {
    case started(transport: String?)
    case unavailable(reason: String, openStatus: Int32? = nil)
}

public protocol HIDUsageSource: AnyObject {
    // onValue is called with (usagePage, usage) only; never the reported value or report bytes.
    func start(until deadline: Double, onValue: @escaping (Int, Int) -> Void) -> HIDUsageStartOutcome
    func stop()
}

// Opens a non-seizing (options 0), permission-preflight-gated IOHIDManager restricted to the
// USB Magic Trackpad, registers only an input-value callback, and never reads/writes reports or
// feature elements. If any precondition fails, it leaves itself unavailable with a reason instead
// of adopting a broader match, a seize option, or an unapproved privilege path.
public final class PublicHIDUsageSource: HIDUsageSource {
    private var manager: IOHIDManager?
    private var onValue: ((Int, Int) -> Void)?
    private var deadline = 0.0
    static let digitizerUsagePage = 0x0d

    public init() {}

    public func start(until deadline: Double, onValue: @escaping (Int, Int) -> Void) -> HIDUsageStartOutcome {
        stop()
        guard CGPreflightListenEventAccess() else { return .unavailable(reason: "inputMonitoringNotGranted") }
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        IOHIDManagerSetDeviceMatching(manager, [kIOHIDVendorIDKey: 1452, kIOHIDProductIDKey: 804,
            kIOHIDProductKey: "Magic Trackpad", kIOHIDTransportKey: "USB"] as CFDictionary)
        guard let devices = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice>, !devices.isEmpty else {
            return .unavailable(reason: "referenceUSBDeviceNotFound")
        }
        guard devices.count <= 16, devices.allSatisfy(Self.isReference) else {
            return .unavailable(reason: "referenceMatchMismatch")
        }
        self.onValue = onValue; self.deadline = deadline
        let context = Unmanaged.passUnretained(self).toOpaque()
        IOHIDManagerRegisterInputValueCallback(manager, { context, result, _, value in
            guard result == kIOReturnSuccess, let context else { return }
            let instance = Unmanaged<PublicHIDUsageSource>.fromOpaque(context).takeUnretainedValue()
            guard ProcessInfo.processInfo.systemUptime < instance.deadline else { return }
            let element = IOHIDValueGetElement(value)
            let device = IOHIDElementGetDevice(element)
            guard PublicHIDUsageSource.isReference(device) else { return }
            instance.onValue?(Int(IOHIDElementGetUsagePage(element)), Int(IOHIDElementGetUsage(element)))
        }, context)
        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
        let openStatus = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        guard openStatus == kIOReturnSuccess else {
            IOHIDManagerRegisterInputValueCallback(manager, nil, nil)
            IOHIDManagerUnscheduleFromRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
            IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
            self.onValue = nil; self.deadline = 0
            return .unavailable(reason: "openFailed", openStatus: openStatus)
        }
        self.manager = manager
        return .started(transport: "USB")
    }

    static func matchesReference(vendorID: Int?, productID: Int?, product: String?, transport: String?) -> Bool {
        vendorID == 1452 && productID == 804 && product == "Magic Trackpad" && transport == "USB"
    }
    private static func isReference(_ device: IOHIDDevice) -> Bool {
        matchesReference(vendorID: (IOHIDDeviceGetProperty(device, kIOHIDVendorIDKey as CFString) as? NSNumber)?.intValue,
            productID: (IOHIDDeviceGetProperty(device, kIOHIDProductIDKey as CFString) as? NSNumber)?.intValue,
            product: IOHIDDeviceGetProperty(device, kIOHIDProductKey as CFString) as? String,
            transport: IOHIDDeviceGetProperty(device, kIOHIDTransportKey as CFString) as? String)
    }
    public func stop() {
        deadline = 0
        if let manager {
            IOHIDManagerRegisterInputValueCallback(manager, nil, nil)
            IOHIDManagerUnscheduleFromRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
            IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        }
        manager = nil
        onValue = nil
    }

    deinit { stop() }
}

// Bounded (fixed-cap cardinality) accumulator; owned by GlobalInputCheck, not IOKit callbacks.
struct HIDUsageAccumulator {
    static let cardinalityCap = 64
    private(set) var counts: [String: Int] = [:]
    private(set) var eventCount = 0
    private(set) var truncated = false
    private(set) var saturated = false
    private(set) var digitizerUsageEvents = 0
    mutating func record(page: Int, usage: Int) {
        if eventCount < 1_000_000 { eventCount += 1 } else { saturated = true }
        if page == PublicHIDUsageSource.digitizerUsagePage {
            if digitizerUsageEvents < 1_000_000 { digitizerUsageEvents += 1 } else { saturated = true }
        }
        let key = "\(page):\(usage)"
        if let previous = counts[key] {
            if previous < 1_000_000 { counts[key] = previous + 1 } else { saturated = true }
        } else if counts.count < Self.cardinalityCap {
            counts[key] = 1
        } else {
            truncated = true
        }
    }
}
