import AppKit
import SwiftUI
import UniformTypeIdentifiers
import TrackpadCore
import MacPlatform

struct GestureDraft {
    var id = UUID().uuidString
    var name = "Three-finger tap"
    var kind = "tap"
    var direction = "right"
    var fingers = 3
    var zone = "any"
    var movement = 0.06
    var minimum = 0.0
    var maximum = 0.35
    var cooldown = 0.5
    var priority = 0
    var appScope = ""
    var command = false; var option = false; var shift = false; var control = false
    var actionKind = "beep"
    var actionValue = ""
    var enabled = true
    var extraCapabilities: Set<Capability> = []
    var extraModifiers: Set<Modifier> = []
    init() {}
    init(_ g: GestureDefinition, action: ActionDefinition?) {
        id = g.id; name = g.name; fingers = g.fingerCount; zone = g.zone.rawValue
        switch g.kind { case .tap: kind="tap"; case .hold: kind="hold"; case .swipe(let d): kind="swipe"; direction=d.rawValue; case .pinch: kind="pinch"; case .rotate: kind="rotate" }
        movement=g.movementThreshold; minimum=g.minDuration ?? (g.kind == .hold ? 0.5 : 0); maximum=g.maxDuration ?? (g.kind == .tap ? 0.35 : 2)
        cooldown=g.cooldown; priority=g.priority; appScope=g.applicationScope ?? ""; enabled=g.enabled
        command=g.modifiers.contains(.command); option=g.modifiers.contains(.option); shift=g.modifiers.contains(.shift); control=g.modifiers.contains(.control)
        extraModifiers=g.modifiers.subtracting([.command,.option,.shift,.control]); extraCapabilities=g.requiredCapabilities
        if let action {
            switch action.kind {
            case .openURL(let value): actionKind="openURL"; actionValue=value
            case .launch(let value): actionKind="launch"; actionValue=value
            case .focusApp(let value): actionKind="focus"; actionValue=value
            case .hideApp(let value): actionKind="hide"; actionValue=value
            case .appleShortcut(let value): actionKind="shortcut"; actionValue=value
            case .systemAction(.beep): actionKind="beep"
            default: actionKind="unsupported"
            }
        }
    }
    var definition: GestureDefinition {
        let trigger: GestureKind
        switch kind { case "hold": trigger = .hold; case "swipe": trigger = .swipe(Direction(rawValue: direction) ?? .right); case "pinch": trigger = .pinch; case "rotate": trigger = .rotate; default: trigger = .tap }
        var mods=extraModifiers
        if command { mods.insert(.command) }; if option { mods.insert(.option) }; if shift { mods.insert(.shift) }; if control { mods.insert(.control) }
        return .init(id: id, name: name, kind: trigger, actionID: "action-"+id, fingerCount: fingers,
                     zone: Zone(rawValue: zone) ?? .any, movementThreshold: movement,
                     minDuration: minimum, maxDuration: maximum, modifiers: mods,
                     applicationScope: appScope.isEmpty ? nil : appScope, priority: priority, cooldown: cooldown,
                     requiredCapabilities: extraCapabilities, enabled: enabled)
    }
    var action: ActionDefinition {
        let value: ActionKind
        switch actionKind {
        case "openURL": value = .openURL(actionValue)
        case "launch": value = .launch(bundleID: actionValue)
        case "focus": value = .focusApp(bundleID: actionValue)
        case "hide": value = .hideApp(bundleID: actionValue)
        case "shortcut": value = .appleShortcut(name: actionValue)
        case "unsupported": value = .keyboardShortcut(keycode: 0, modifiers: [])
        default: value = .systemAction(.beep)
        }
        return .init(id: "action-"+id, kind: value)
    }
    var safeAction: SafeAction {
        switch actionKind {
        case "openURL": return .openURL(actionValue)
        case "launch": return .launchApp(actionValue)
        case "focus": return .focusApp(actionValue)
        case "hide": return .hideApp(actionValue)
        case "shortcut": return .appleShortcut(actionValue)
        case "unsupported": return .keyboardShortcut
        default: return .beep
        }
    }
}

final class AppModel: ObservableObject {
    @Published var document: ProfileDocument
    @Published var profileIndex=0
    @Published var selectedID: String?
    @Published var draft=GestureDraft()
    @Published var source="simulation"
    @Published var contacts: [ObservedContact]=[]
    @Published var status="Preview a gesture to see its recognition result."
    @Published var permissions=PermissionSnapshot.current()
    @Published var devices=DeviceDiscovery.list()
    @Published var live=false
    @Published var sampleCount=0
    @Published var isRecording=false
    @Published var processingMicroseconds=0.0
    @Published var previewScope=""
    @Published var diagnostics=SafeDiagnostics()
    let capture=TouchCaptureView(frame: .zero)
    private var recorder=SampleRecorder()
    private var engine: GestureEngine
    private let backend=WorkspaceActionBackend()
    private lazy var executor=SafeActionExecutor(backend: backend)
    private var timer: Timer?
    private var replayTimers: [Timer]=[]
    private var observers: [NSObjectProtocol]=[]
    private var workspaceObservers: [NSObjectProtocol]=[]
    private var generation=0
    private var expiry=0.0
    private var lastPublish=0.0
    private var tick=0
    private lazy var lifecycle=CaptureLifecycle { [weak self] in self?.cancelPreview() }
    var profile: Profile { document.profiles[profileIndex] }
    var definitions: [GestureDefinition] { profile.gestures }
    private let storageOverride: URL?
    var storageURL: URL {
        if let storageOverride { return storageOverride }
        return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("TrackpadGestures", isDirectory: true).appendingPathComponent("profiles.json")
    }
    init(storage: URL? = nil) {
        storageOverride=storage
        let defaultDraft=GestureDraft()
        document = .init(profiles: [.init(id:"local", name:"My gestures", gestures:[defaultDraft.definition], actions:[defaultDraft.action])])
        engine = GestureEngine(definitions: [defaultDraft.definition])
        selectedID=defaultDraft.id; draft=defaultDraft
        if let data=try? BoundedProfileFile.read(storageURL), let decoded=try? ProfileCodec.decode(data), !decoded.document.profiles.isEmpty {
            document=decoded.document; selectProfile(0)
            status="Local profile restored. Global execution remains unavailable."
        }
        capture.onCaptureFailure = { [weak self] in self?.cancelPreview(); self?.status="Capture cancelled: invalid or excessive contact identities." }
        capture.onObservation = { [weak self] sample in self?.acceptObservation(sample) }
        capture.onNativeGesture = { [weak self] kind in
            guard let self, self.live else { return }
            self.engine.cancel()
            self.status="Native \(kind) observed — sequence cancelled."
            self.diagnostics.record(.cancelled)
        }
        backend.completion = { [weak self] success in
            self?.status = success ? "Action dispatched to its system handler. Completion is not monitored." : "System handler could not dispatch the action."
        }
        let nc=NSWorkspace.shared.notificationCenter
        for (name,event) in [(NSWorkspace.willSleepNotification,LifecycleEvent.sleep),(NSWorkspace.didWakeNotification,LifecycleEvent.resume),(NSWorkspace.sessionDidResignActiveNotification,LifecycleEvent.lock),(NSWorkspace.sessionDidBecomeActiveNotification,LifecycleEvent.unlock)] {
            workspaceObservers.append(nc.addObserver(forName:name,object:nil,queue:.main) { [weak self] _ in self?.lifecycle.handle(event) })
        }
        workspaceObservers.append(nc.addObserver(forName:NSWorkspace.didActivateApplicationNotification,object:nil,queue:.main) { [weak self] _ in
            guard let self, self.live else { return }; self.lifecycle.handle(.appChanged)
        })
        observers.append(NotificationCenter.default.addObserver(forName:NSApplication.willTerminateNotification,object:nil,queue:.main) { [weak self] _ in self?.shutdown() })
        timer=Timer.scheduledTimer(withTimeInterval:1,repeats:true) { [weak self] _ in self?.refresh() }
        lifecycle.permissionsChanged(permissions)
    }
    func refresh() {
        let next=PermissionSnapshot.current()
        if next != permissions { permissions=next; lifecycle.permissionsChanged(next); diagnostics.record(.permissionChanged); status="Permissions changed. Preview cancelled; restart explicitly." }
        tick += 1
        if tick % 5 == 0 {
            let nextDevices=DeviceDiscovery.list()
            if nextDevices != devices { devices=nextDevices; lifecycle.handle(.disconnect); diagnostics.record(.deviceChanged); status="Device list changed. Preview cancelled." }
        }
        if live && ProcessInfo.processInfo.systemUptime >= expiry { lifecycle.handle(.captureExpired); status="30-second preview finished. No raw stream was saved." }
        recorder.expire(at:ProcessInfo.processInfo.systemUptime)
        if isRecording && !recorder.active {
            isRecording=false
            if recorder.samples.isEmpty { status="No fresh contact within 10 seconds. Press Record 3s to try again." }
            else { status += " Sample ready; export before the preview ends." }
        }
    }
    func selectProfile(_ index:Int) {
        guard document.profiles.indices.contains(index) else { return }
        cancelPreview(); profileIndex=index
        if let g=profile.gestures.first { select(g) } else { newGesture() }
    }
    func select(_ g:GestureDefinition) {
        cancelPreview(); selectedID=g.id
        draft=GestureDraft(g,action:profile.actions.first { $0.id == g.actionID })
        previewScope=g.applicationScope ?? ""
    }
    func newGesture() { cancelPreview(); selectedID=nil; draft=GestureDraft(); draft.name="New gesture" }
    func cancelPreview() {
        generation += 1; replayTimers.forEach { $0.invalidate() }; replayTimers=[]
        capture.stop(); live=false; contacts=[]; recorder.clear(); sampleCount=0; isRecording=false
        engine=GestureEngine(definitions: document.profiles.indices.contains(profileIndex) ? definitions : [])
        diagnostics.record(.cancelled)
    }
    func shutdown() {
        cancelPreview(); timer?.invalidate(); timer=nil
        observers.forEach { NotificationCenter.default.removeObserver($0) }; observers=[]
        workspaceObservers.forEach { NSWorkspace.shared.notificationCenter.removeObserver($0) }; workspaceObservers=[]
    }
    func saveGesture() {
        do {
            // Unsupported imported action is preserved verbatim until the user explicitly chooses another action.
            let old=profile.gestures.first { $0.id==selectedID }
            let oldAction=profile.actions.first { $0.id==old?.actionID }
            var newAction=draft.action
            if draft.actionKind=="unsupported", let oldAction { newAction = .init(id: draft.definition.actionID, kind:oldAction.kind) }
            var gestures=profile.gestures
            if let i=gestures.firstIndex(where:{$0.id==draft.id}) { gestures[i]=draft.definition } else { gestures.append(draft.definition) }
            var actions=profile.actions.filter { $0.id != newAction.id }; actions.append(newAction)
            let referenced=Set(gestures.map(\.actionID)); actions=actions.filter { referenced.contains($0.id) }
            var profiles=document.profiles; profiles[profileIndex] = .init(id:profile.id,name:profile.name,gestures:gestures,actions:actions)
            let next=ProfileDocument(profiles:profiles); let data=try ProfileCodec.encode(next)
            try persist(data); document=next; selectedID=draft.id; cancelPreview(); status="Saved locally. Enabled applies to preview only; global capture is unsupported."
        } catch { status="Not saved: invalid definition or local file could not be written." }
    }
    private func persist(_ data:Data) throws {
        guard data.count <= BoundedProfileFile.maximumBytes else { throw ActionFailure.invalid }
        try FileManager.default.createDirectory(at:storageURL.deletingLastPathComponent(),withIntermediateDirectories:true)
        try data.write(to:storageURL,options:.atomic)
    }
    func importData(_ data: Data) throws {
            let decoded=try ProfileCodec.decode(data)
            guard !decoded.document.profiles.isEmpty else { throw ActionFailure.invalid }
            let profiles=decoded.document.profiles.map { p in Profile(id:p.id,name:p.name,gestures:p.gestures.map { g in
                GestureDefinition(id:g.id,name:g.name,kind:g.kind,actionID:g.actionID,fingerCount:g.fingerCount,zone:g.zone,movementThreshold:g.movementThreshold,minDuration:g.minDuration,maxDuration:g.maxDuration,modifiers:g.modifiers,applicationScope:g.applicationScope,priority:g.priority,cooldown:g.cooldown,requiredCapabilities:g.requiredCapabilities,enabled:false)
            },actions:p.actions) }
            let next=ProfileDocument(profiles:profiles); try persist(ProfileCodec.encode(next)); cancelPreview(); document=next; selectProfile(0)
            status="Imported data only. All definitions disabled for review." + (decoded.migration.migrated ? " Migrated to schema v1." : "")
    }
    func importProfile() {
        let panel=NSOpenPanel(); panel.allowedContentTypes=[.json]; panel.canChooseDirectories=false; panel.allowsMultipleSelection=false
        guard panel.runModal() == .OK, let url=panel.url else { return }
        do {
            try importData(BoundedProfileFile.read(url))
        } catch { status="Import rejected: invalid/unknown/executable data, oversized file or unsupported version." }
    }
    func exportProfile() {
        do { try saveData(ProfileCodec.encode(document),name:"trackpad-profile-v1.json") }
        catch { status="Export failed. Profile was not changed." }
    }
    private func saveData(_ data:Data,name:String) throws {
        let panel=NSSavePanel(); panel.allowedContentTypes=[.json]; panel.nameFieldStringValue=name
        if panel.runModal() == .OK, let url=panel.url { try data.write(to:url,options:.atomic); status="Exported local JSON." }
    }
    func testAction() {
        do { try executor.execute(draft.safeAction,origin:.manualTest,now:ProcessInfo.processInfo.systemUptime); diagnostics.record(.actionDispatched) }
        catch { diagnostics.record(.actionFailed); status=(error as? LocalizedError)?.errorDescription ?? "Action unavailable." }
    }
    func startLocal() {
        cancelPreview(); source="local"; lifecycle.start(); live=true
        expiry=ProcessInfo.processInfo.systemUptime+30; capture.start()
        status="Place the pointer over the pad, then use the trackpad. View-local capture only; physical transport unknown."
    }
    func recordSample() {
        guard live else { return }; recorder.arm(at:ProcessInfo.processInfo.systemUptime); isRecording=true; sampleCount=0
        status="Ready: return the pointer to the pad and lift your fingers. The next fresh touch (within 10 seconds) records one gesture, up to 3 seconds. Recording freezes when all fingers end."
    }
    func sampleDataForExport(at time: Double = ProcessInfo.processInfo.systemUptime) throws -> Data {
        guard !recorder.samples.isEmpty else { throw ActionFailure.invalid }
        recorder.finishForExport(at: time); isRecording=false
        struct SampleFile: Encodable {
            let schemaVersion=2
            let source="appkit-local-unverified"
            let transport="unknown"
            let pressureAvailable=false
            let areaAvailable=false
            let recording: SampleRecordingMetadata
            let samples: [TouchObservation]
        }
        let encoder=JSONEncoder(); encoder.outputFormatting=[.prettyPrinted,.sortedKeys]
        return try encoder.encode(SampleFile(recording:recorder.metadata,samples:recorder.samples))
    }
    func exportSample() {
        guard !recorder.samples.isEmpty else { status="No observed contact samples to export."; return }
        do { try saveData(sampleDataForExport(),name:"local-touch-sample.json") }
        catch { status="Sample export failed." }
    }
    func acceptObservation(_ observation:TouchObservation) {
        guard live else { return }
        let wasWaiting=recorder.waitingForContact
        let wasRecording=recorder.active
        recorder.append(observation); sampleCount=recorder.samples.count; isRecording=recorder.active
        if wasWaiting && recorder.recording { status="Recording up to 3 seconds / 180 samples from first contact. Lift fingers to finish the gesture." }
        let frame=NormalizedFrame(timestamp:observation.timestamp,sessionID:observation.sessionID,transport:.unknown,
                                  capabilities:[.multiTouch,.contactIdentity,.normalizedCoordinates],contacts:observation.contacts.compactMap { c in
            guard let phase=ContactPhase(rawValue:c.phase) else { return nil }; return Contact(id:c.id,x:c.x,y:c.y,phase:phase)
        },appScope:Bundle.main.bundleIdentifier,modifiers:Set(observation.modifiers.compactMap(Modifier.init(rawValue:))))
        process(frame)
        if observation.timestamp-lastPublish>1.0/60 || observation.contacts.allSatisfy({ $0.phase=="ended" || $0.phase=="cancelled" }) {
            contacts=observation.contacts.filter { $0.phase != "ended" && $0.phase != "cancelled" }; lastPublish=observation.timestamp
        }
        if observation.contacts.allSatisfy({ $0.phase=="ended" || $0.phase=="cancelled" }) { engine.confirmEmptyBoundary() }
        if wasRecording && !recorder.active {
            let result = status.hasPrefix("Recognized in preview:") ? status + " " : ""
            switch recorder.metadata.finishReason {
            case .sequenceEnded:
                status = result + "Sample frozen after all contacts ended. Move to Export sample to save; later movement is not recorded."
            case .sequenceCancelled:
                status = "Sample frozen after cancellation. Export for diagnosis; this is not a completed gesture."
            case .invalidSequence:
                status = "Sample frozen: inconsistent contact sequence. Export for diagnosis."
            default:
                status = result + "Recording stopped. Sample frozen; export before the preview ends."
            }
        }
    }
    private func process(_ frame:NormalizedFrame) {
        let start=ProcessInfo.processInfo.systemUptime
        let result=engine.process(frame)
        processingMicroseconds=(ProcessInfo.processInfo.systemUptime-start)*1_000_000
        diagnostics.record(.frame)
        if !result.events.isEmpty { diagnostics.record(.recognized); status="Recognized in preview: " + result.events.map { event in (definitions.first { $0.id == event.gestureID }?.name ?? draft.name) }.joined(separator: ", ") + ". No action executed." }
    }
    func simulate() {
        cancelPreview(); source="simulation"
        // Test unsaved editor parameters alongside the other saved definitions.
        var candidates=definitions.filter { $0.id != draft.id }; candidates.append(draft.definition)
        engine=GestureEngine(definitions:candidates)
        let g=draft.definition
        guard g.kind.isRecognizable else { status="Unsupported recognizer: pinch/rotate are not implemented."; return }
        let duration=max(0.1,g.kind == .hold ? draft.minimum+0.1 : min(0.2,draft.maximum))
        let count=min(120,max(3,Int(duration*30)))
        let session=UUID().uuidString; let base=ProcessInfo.processInfo.systemUptime; let epoch=generation
        var x=0.4; var y=0.4
        if draft.zone.lowercased().contains("left") { x=0.08 }; if draft.zone.lowercased().contains("right") { x=0.85 }
        if draft.zone.lowercased().contains("top") { y=0.85 }; if draft.zone.lowercased().contains("bottom") { y=0.08 }
        status="Synthetic replay — enabled definitions compete on release."
        for step in 0...count {
            let fraction=Double(step)/Double(count); var dx=0.0; var dy=0.0
            if case .swipe(let d)=g.kind {
                let move=min(0.4,g.movementThreshold+0.04)*fraction
                switch d { case .right: dx=move; case .left: dx = -move; case .up: dy=move; case .down: dy = -move }
            }
            let samples=(0..<g.fingerCount).map { i in Contact(id:String(i),x:min(0.99,max(0.01,x+Double(i)*0.06+dx)),y:min(0.99,max(0.01,y+dy)),phase:step==0 ? .began : (step==count ? .ended : .moved)) }
            let frame=NormalizedFrame(timestamp:base+fraction*duration,sessionID:session,transport:.simulation,capabilities:[.multiTouch,.contactIdentity,.normalizedCoordinates],contacts:samples,appScope:previewScope.isEmpty ? nil : previewScope,modifiers:g.modifiers)
            let timer=Timer.scheduledTimer(withTimeInterval:max(0.001,fraction*duration),repeats:false) { [weak self] _ in
                guard let self, self.generation==epoch else { return }
                self.contacts=samples.filter { $0.phase != .ended && $0.phase != .cancelled }.map { .init(id:$0.id,x:$0.x,y:$0.y,phase:$0.phase.rawValue) }; self.process(frame)
                if step==count && !self.status.hasPrefix("Recognized") { self.status="No gesture won. Check enabled state, thresholds, scope and required capabilities." }
            }
            replayTimers.append(timer)
        }
    }
    var conflictMessages:[String] {
        let candidates=definitions.filter{$0.id != draft.id}+[draft.definition]
        return candidates.filter { g in g.id != draft.id && GestureOrdering.potentiallyOverlaps(g,draft.definition) }.map { g in
            let first=GestureOrdering.precedes(g,draft.definition) ? g.name : draft.name
            return "Potential overlap with “\(g.name)”. If both qualify, “\(first)” wins."
        }
    }
}
