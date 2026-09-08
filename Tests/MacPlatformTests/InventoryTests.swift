import Testing
import Foundation
@testable import MacPlatform

struct InventoryTests {
    @Test func collectionLimitIsExplicitAndFailureIsNotZeroDevices() {
        let c = HIDCollectionInventory(vendorID: 1452, productID: 804, transport: "USB", usagePage: 1, usage: 2, inventory: .unavailable)
        let snapshot = HIDInventorySnapshot(collections: Array(repeating: c, count: 17), total: 17)
        #expect(snapshot.collections.count == 16)
        #expect(snapshot.totalCollectionCount == 17)
        #expect(snapshot.collectionsTruncated)
        let missing = HIDInventorySnapshot(collections: [], total: nil)
        #expect(missing.totalCollectionCount == nil)
        #expect(!missing.available)
    }
    @Test func unavailableElementsAreNotAnEmptySuccessfulEnumeration() {
        let inventory = HIDElementInventory.unavailable
        #expect(!inventory.available)
        #expect(inventory.totalElementCount == nil)
        #expect(inventory.standardDigitizerInputElements == nil)
    }
    @Test func inventoryBoundsAndReportsTruncation() throws {
        let element = HIDElementDescriptor(type: 2, usagePage: 1, usage: 48, reportID: 1, reportSize: 8, reportCount: 1, logicalMin: -127, logicalMax: 127, relative: true)
        let inventory = HIDElementInventory(elements: Array(repeating: element, count: 600))
        #expect(inventory.elements.count == 256)
        #expect(inventory.totalElementCount == 600)
        #expect(inventory.truncated)
        #expect(inventory.standardDigitizerInputElements == 0)
        let json = String(data: try JSONEncoder().encode(inventory), encoding: .utf8)!
        #expect(!json.contains("serial"))
        #expect(!json.contains("value"))
    }
    @Test func digitizerSummaryIncludesElementsBeyondSampleLimit() {
        let vendor = HIDElementDescriptor(type: 2, usagePage: 65280, usage: 1, reportID: 1, reportSize: 8, reportCount: 1, logicalMin: 0, logicalMax: 255, relative: false)
        let contact = HIDElementDescriptor(type: 2, usagePage: 13, usage: 81, reportID: 2, reportSize: 8, reportCount: 1, logicalMin: 0, logicalMax: 255, relative: false)
        let inventory = HIDElementInventory(elements: Array(repeating: vendor, count: 300) + [contact])
        #expect(inventory.standardDigitizerInputElements == 1)
        #expect(inventory.elements.count == 256)
    }
    @Test func digitizerCollectionOrFeatureIsNotInput() {
        func descriptor(_ type: UInt32, _ page: UInt32) -> HIDElementDescriptor {
            .init(type: type, usagePage: page, usage: 81, reportID: 1, reportSize: 8, reportCount: 1, logicalMin: 0, logicalMax: 255, relative: false)
        }
        let inventory = HIDElementInventory(elements: [descriptor(513,13), descriptor(257,13), descriptor(2,13), descriptor(2,65280)])
        #expect(inventory.standardDigitizerInputElements == 1)
        #expect(!inventory.truncated)
    }
}
