import Foundation
import IOKit.hid

// Static descriptor metadata only: never IOHIDValue payloads or report bytes.
public struct HIDElementDescriptor: Codable, Equatable {
    public let type: UInt32
    public let usagePage: UInt32
    public let usage: UInt32
    public let reportID: UInt32
    public let reportSize: UInt32
    public let reportCount: UInt32
    public let logicalMin: Int
    public let logicalMax: Int
    public let relative: Bool
}
public struct HIDElementInventory: Codable {
    public let elements: [HIDElementDescriptor]
    public let available: Bool
    public let totalElementCount: Int?
    public let truncated: Bool
    // Counts all returned elements, including those outside the bounded sample.
    // A descriptor hint, not proof of decoded contacts or supported gestures.
    public let standardDigitizerInputElements: Int?
    init(elements: [HIDElementDescriptor]) {
        available = true
        totalElementCount = elements.count
        self.elements = Array(elements.prefix(256))
        truncated = elements.count > self.elements.count
        standardDigitizerInputElements = elements.filter { (1...4).contains($0.type) && $0.usagePage == 0x0d }.count
    }
    public static func read(_ device: IOHIDDevice) -> HIDElementInventory {
        guard let elements = IOHIDDeviceCopyMatchingElements(device, nil, 0) as? [IOHIDElement] else { return .unavailable }
        // System API supplies an array. Do not duplicate an unbounded number of descriptors.
        let descriptors = elements.prefix(256).map { element in
            HIDElementDescriptor(type: IOHIDElementGetType(element).rawValue,
                usagePage: IOHIDElementGetUsagePage(element), usage: IOHIDElementGetUsage(element),
                reportID: IOHIDElementGetReportID(element), reportSize: IOHIDElementGetReportSize(element),
                reportCount: IOHIDElementGetReportCount(element), logicalMin: IOHIDElementGetLogicalMin(element),
                logicalMax: IOHIDElementGetLogicalMax(element), relative: IOHIDElementIsRelative(element))
        }
        let digitizerInputs = elements.reduce(0) { count, element in
            count + (((1...4).contains(IOHIDElementGetType(element).rawValue) && IOHIDElementGetUsagePage(element) == 0x0d) ? 1 : 0)
        }
        return HIDElementInventory(descriptors: descriptors, total: elements.count, digitizerInputs: digitizerInputs)
    }
    public static var unavailable: HIDElementInventory { HIDElementInventory() }
    private init() {
        available = false; elements = []; totalElementCount = nil; truncated = false
        standardDigitizerInputElements = nil
    }
    private init(descriptors: [HIDElementDescriptor], total: Int, digitizerInputs: Int) {
        available = true
        elements = descriptors; totalElementCount = total; truncated = total > descriptors.count
        standardDigitizerInputElements = digitizerInputs
    }
}
public struct HIDInventorySnapshot: Codable {
    public let available: Bool
    public let totalCollectionCount: Int?
    public let collectionsTruncated: Bool
    public let collections: [HIDCollectionInventory]
    init(collections: [HIDCollectionInventory], total: Int?) {
        available = total != nil
        totalCollectionCount = total
        let retained = Array(collections.prefix(16))
        self.collections = retained
        collectionsTruncated = total.map { $0 > retained.count } ?? false
    }
}
public struct HIDCollectionInventory: Codable {
    public let vendorID: Int?
    public let productID: Int?
    public let transport: String?
    public let usagePage: Int?
    public let usage: Int?
    public let inventory: HIDElementInventory
    public static func list() -> HIDInventorySnapshot {
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, 0)
        IOHIDManagerSetDeviceMatchingMultiple(manager, DeviceDiscovery.appleVendorIDs.map {
            [kIOHIDVendorIDKey: $0, kIOHIDProductKey: "Magic Trackpad"] as [String: Any]
        } as CFArray)
        guard let devices = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> else { return .init(collections: [], total: nil) }
        let collections = devices.prefix(16).map { device in
            func number(_ key: String) -> Int? { (IOHIDDeviceGetProperty(device, key as CFString) as? NSNumber)?.intValue }
            return HIDCollectionInventory(vendorID: number(kIOHIDVendorIDKey), productID: number(kIOHIDProductIDKey),
                transport: IOHIDDeviceGetProperty(device, kIOHIDTransportKey as CFString) as? String,
                usagePage: number(kIOHIDPrimaryUsagePageKey), usage: number(kIOHIDPrimaryUsageKey), inventory: .read(device))
        }.sorted { ($0.usagePage ?? 0, $0.usage ?? 0) < ($1.usagePage ?? 0, $1.usage ?? 0) }
        return .init(collections: collections, total: devices.count)
    }
}
