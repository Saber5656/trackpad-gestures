import Testing
import Foundation
@testable import MacPlatform

struct CaptureTests {
    @Test func bluetoothAndUSBAppleVendorNamespaces() {
        #expect(DeviceDiscovery.appleVendorIDs.contains(0x05ac))
        #expect(DeviceDiscovery.appleVendorIDs.contains(0x004c))
    }
    @Test func sampleRecorderIsOptInBoundedAndExpires() {
        var recorder = SampleRecorder()
        recorder.append(.init(timestamp: 0, sessionID: "test", contacts: [], modifiers: []))
        #expect(recorder.samples.isEmpty)
        recorder.start(at: 1)
        for i in 0..<500 { recorder.append(.init(timestamp: 1 + Double(i)/1000, sessionID: "test", contacts: [], modifiers: [])) }
        #expect(recorder.samples.count == 180)
        recorder.append(.init(timestamp: 4.1, sessionID: "test", contacts: [], modifiers: []))
        #expect(!recorder.recording)
        recorder.clear(); #expect(recorder.samples.isEmpty)
    }
    @Test func inputNeverStoresMoreThanTenContacts() {
        var recorder = SampleRecorder(); recorder.start(at: 1)
        let contact = ObservedContact(id: "1", x: 0.5, y: 0.5, phase: "began")
        recorder.append(.init(timestamp: 1, sessionID: "test", contacts: Array(repeating: contact, count: 11), modifiers: []))
        #expect(recorder.samples.isEmpty)
    }
}

struct BoundaryRegressionTests {
    @Test func contactIdentityChurnCannotGrowUnbounded() {
        var map=ContactIdentityMap()
        for _ in 0..<10 { #expect(map.id(for:NSObject()) != nil) }
        #expect(map.id(for:NSObject()) == nil)
        #expect(map.count == 10)
        map.clear(); #expect(map.count == 0)
    }
    @Test func recorderExpiresWithoutFurtherEvents() {
        var recorder=SampleRecorder(); recorder.start(at:1)
        recorder.expire(at:4.01)
        #expect(!recorder.recording)
    }
    @Test func boundedFileReadRejectsOversizeAndDirectories() throws {
        let folder=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
        defer { try? FileManager.default.removeItem(at:folder) }
        let file=folder.appendingPathComponent("input.json")
        try Data(repeating:32,count:256*1024+1).write(to:file)
        #expect(throws:(any Error).self) { try BoundedProfileFile.read(file) }
        #expect(throws:(any Error).self) { try BoundedProfileFile.read(folder) }
        try Data("{}".utf8).write(to:file)
        #expect(try BoundedProfileFile.read(file) == Data("{}".utf8))
    }
}
