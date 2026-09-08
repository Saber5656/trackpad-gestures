import Foundation
import IOKit.hid

public struct DeviceInfo: Codable, Equatable {
    public let vendorID: Int?
    public let productID: Int?
    public let version: Int?
    public let transport: String?
    public let product: String?
    public let usagePage: Int?
    public let usage: Int?
}

public enum DeviceDiscovery {
    public static let appleVendorIDs = [0x05ac, 0x004c]
    // Metadata allowlist intentionally excludes serial, registry path, location and unique IDs.
    public static func list() -> [DeviceInfo] {
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        IOHIDManagerSetDeviceMatchingMultiple(manager, appleVendorIDs.map { [kIOHIDVendorIDKey: $0] } as CFArray)
        guard let devices = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> else { return [] }
        return devices.map { device in
            func number(_ key: String) -> Int? { (IOHIDDeviceGetProperty(device, key as CFString) as? NSNumber)?.intValue }
            func string(_ key: String) -> String? { IOHIDDeviceGetProperty(device, key as CFString) as? String }
            return DeviceInfo(vendorID: number(kIOHIDVendorIDKey), productID: number(kIOHIDProductIDKey),
                              version: number(kIOHIDVersionNumberKey), transport: string(kIOHIDTransportKey),
                              product: string(kIOHIDProductKey), usagePage: number(kIOHIDPrimaryUsagePageKey), usage: number(kIOHIDPrimaryUsageKey))
        }.sorted { ($0.productID ?? 0, $0.usagePage ?? 0, $0.usage ?? 0) < ($1.productID ?? 0, $1.usagePage ?? 0, $1.usage ?? 0) }
    }
}
