import SwiftUI
import AppKit
import TrackpadCore
import MacPlatform

struct CaptureSurface: NSViewRepresentable {
    let view: TouchCaptureView
    func makeNSView(context:Context)->TouchCaptureView { view }
    func updateNSView(_ nsView:TouchCaptureView,context:Context) {}
}
struct ContentView: View {
    @ObservedObject var model:AppModel
    private let accent=Color(red:0.63,green:0.56,blue:1)
    private let muted=Color(red:0.61,green:0.66,blue:0.75)
    var body: some View {
        HStack(spacing:0) {
            sidebar.frame(width:230)
            Divider()
            ScrollView {
                VStack(alignment:.leading,spacing:22) {
                    header
                    HStack(alignment:.top,spacing:20) {
                        VStack(alignment:.leading,spacing:18) { visualizer; capabilities }.frame(minWidth:350,maxWidth:.infinity)
                        editor.frame(width:345)
                    }
                    HStack(alignment:.top,spacing:16) { permissions; decisions }.frame(maxWidth:.infinity)
                    Text(model.status).font(.system(size:13,weight:.medium)).foregroundStyle(accent).textSelection(.enabled)
                        .padding(15).frame(maxWidth:.infinity,alignment:.leading).background(accent.opacity(0.09),in:RoundedRectangle(cornerRadius:12))
                    Text("LOCAL ONLY · No telemetry · No input injection · Schema v1 · Unpublished development build")
                        .font(.system(size:10,weight:.medium,design:.monospaced)).foregroundStyle(muted)
                }.padding(28)
            }.background(Color(red:0.055,green:0.067,blue:0.095))
        }.frame(minWidth:1100,minHeight:760).preferredColorScheme(.dark).tint(accent)
    }
    private var sidebar:some View {
        VStack(alignment:.leading,spacing:22) {
            HStack { Image(systemName:"hand.draw.fill").font(.title2).foregroundStyle(accent); Text("Trackpad\nGestures").font(.system(size:19,weight:.bold)) }.padding(.top,28)
            Text("GESTURE LIBRARY").font(.system(size:10,weight:.semibold,design:.monospaced)).foregroundStyle(muted)
            Picker("Profile",selection:Binding(get:{model.profileIndex},set:{model.selectProfile($0)})) {
                ForEach(Array(model.document.profiles.enumerated()),id:\.offset) { index,p in Text(p.name).tag(index) }
            }.labelsHidden()
            ScrollView {
                VStack(spacing:8) {
                    ForEach(model.definitions,id:\.id) { g in
                        Button { model.select(g) } label: {
                            HStack(alignment:.top) {
                                Image(systemName:g.kind.isRecognizable ? "hand.tap" : "exclamationmark.circle").foregroundStyle(g.enabled ? accent : muted)
                                VStack(alignment:.leading,spacing:5) {
                                    Text(g.name).font(.system(size:13,weight:.semibold)).lineLimit(2)
                                    Text("\(g.fingerCount) fingers · \(g.enabled ? "preview enabled" : "disabled")").font(.system(size:10)).foregroundStyle(muted)
                                }; Spacer(minLength:0)
                            }.padding(12).frame(maxWidth:.infinity,alignment:.leading)
                                .background(model.selectedID==g.id ? accent.opacity(0.16) : Color.white.opacity(0.025),in:RoundedRectangle(cornerRadius:10))
                        }.buttonStyle(.plain)
                    }
                }
            }
            Button { model.newGesture() } label: { Label("New gesture",systemImage:"plus") }.buttonStyle(.bordered).frame(maxWidth:.infinity)
            Spacer(minLength:0)
            VStack(spacing:10) {
                Button { model.importProfile() } label:{ Label("Import profile…",systemImage:"square.and.arrow.down").frame(maxWidth:.infinity,alignment:.leading) }
                Button { model.exportProfile() } label:{ Label("Export profile…",systemImage:"square.and.arrow.up").frame(maxWidth:.infinity,alignment:.leading) }
            }.buttonStyle(.plain).font(.system(size:12)).foregroundStyle(muted)
            Text("Import is data only.\nImported gestures start disabled.").font(.system(size:11)).foregroundStyle(muted).lineSpacing(4)
        }.padding(.horizontal,18).padding(.bottom,22).background(Color(red:0.075,green:0.083,blue:0.12))
    }
    private var header:some View {
        HStack(alignment:.top) {
            VStack(alignment:.leading,spacing:8) {
                Text("Make the gesture yours.").font(.system(size:29,weight:.semibold))
                Text("Define, preview, and understand what will happen.").font(.system(size:13)).foregroundStyle(muted)
            }
            Spacer()
            Text("SIMULATION-ONLY MVP").font(.system(size:10,weight:.bold,design:.monospaced)).foregroundStyle(.orange)
                .padding(.horizontal,12).padding(.vertical,8).background(Color.orange.opacity(0.1),in:Capsule())
        }
    }
    private var visualizer:some View {
        VStack(alignment:.leading,spacing:16) {
            HStack { Label("Input studio",systemImage:"waveform.path").font(.headline); Spacer(); Text(model.live ? "LOCAL LIVE · 30s" : "SYNTHETIC / IDLE").font(.system(size:10,design:.monospaced)).foregroundStyle(model.live ? .green : muted) }
            Picker("Input source",selection:$model.source) { Text("Simulation").tag("simulation"); Text("Local preview · experimental").tag("local") }
                .pickerStyle(.segmented).onChange(of:model.source) { _,_ in model.cancelPreview() }
            ZStack {
                RoundedRectangle(cornerRadius:24).fill(LinearGradient(colors:[Color(red:0.15,green:0.17,blue:0.24),Color(red:0.09,green:0.10,blue:0.15)],startPoint:.topLeading,endPoint:.bottomTrailing))
                RoundedRectangle(cornerRadius:24).stroke(Color.white.opacity(0.13),lineWidth:1)
                GeometryReader { geo in
                    Path { p in
                        for i in 1...3 { let x=geo.size.width*CGFloat(i)/4; p.move(to:.init(x:x,y:0));p.addLine(to:.init(x:x,y:geo.size.height)) }
                        for i in 1...2 { let y=geo.size.height*CGFloat(i)/3;p.move(to:.init(x:0,y:y));p.addLine(to:.init(x:geo.size.width,y:y)) }
                    }.stroke(Color.white.opacity(0.035),style:StrokeStyle(lineWidth:1,dash:[3,5]))
                    ForEach(model.contacts,id:\.id) { c in
                        ZStack { Circle().fill(accent.opacity(0.15)).frame(width:52,height:52); Circle().fill(accent).frame(width:20,height:20); Circle().stroke(.white.opacity(0.6)).frame(width:20,height:20) }
                            .position(x:c.x*geo.size.width,y:(1-c.y)*geo.size.height)
                    }
                }.padding(14)
                if model.contacts.isEmpty {
                    VStack(spacing:10) {
                        Image(systemName:"hand.draw").font(.system(size:38,weight:.ultraLight)).foregroundStyle(accent.opacity(0.7))
                        Text(model.live ? "Pointer here, fingers on trackpad" : "Your gesture, before it acts").font(.system(size:12)).foregroundStyle(muted)
                    }.allowsHitTesting(false)
                }
                CaptureSurface(view:model.capture).opacity(model.source=="local" ? 1 : 0).allowsHitTesting(model.source=="local")
            }.frame(height:215)
            HStack {
                Text("\(model.contacts.count) contacts").font(.system(size:11,design:.monospaced)); Spacer()
                Text(String(format:"Core %.1f µs / last frame",model.processingMicroseconds)).font(.system(size:10,design:.monospaced)).foregroundStyle(muted)
            }
            if model.source=="simulation" {
                HStack {
                    Button { model.simulate() } label: { Label("Preview gesture",systemImage:"play.fill") }.buttonStyle(.borderedProminent)
                    Text("No actions execute").font(.system(size:11)).foregroundStyle(muted)
                }
                TextField("Simulated application bundle ID (optional)",text:$model.previewScope).textFieldStyle(.roundedBorder)
            } else {
                HStack {
                    Button(model.live ? "Stop preview" : "Start 30s preview") { if model.live { model.cancelPreview() } else { model.startLocal() } }.buttonStyle(.borderedProminent)
                    Button("Record 3s") { model.recordSample() }.disabled(!model.live)
                    Button("Export sample…") { model.exportSample() }.disabled(model.sampleCount==0)
                }.font(.system(size:11))
                Text("\(model.sampleCount)/180 samples · \(model.isRecording ? "recording" : (model.sampleCount > 0 ? "frozen" : "not recording")) · pressure and area unavailable · contacts stay in memory").font(.system(size:10)).foregroundStyle(muted)
            }
        }.padding(18).background(Color.white.opacity(0.025),in:RoundedRectangle(cornerRadius:16))
    }
    private var editor:some View {
        VStack(alignment:.leading,spacing:14) {
            HStack { Text("Gesture definition").font(.headline); Spacer(); Toggle("Enabled for preview",isOn:$model.draft.enabled).toggleStyle(.switch).font(.system(size:10)) }
            TextField("Gesture name",text:$model.draft.name).textFieldStyle(.roundedBorder)
            HStack {
                Picker("Trigger",selection:$model.draft.kind) {
                    Text("Tap").tag("tap");Text("Hold on release").tag("hold");Text("Swipe").tag("swipe");Text("Pinch · unsupported").tag("pinch");Text("Rotate · unsupported").tag("rotate")
                }.onChange(of:model.draft.kind) { _,value in
                    if value=="hold" { model.draft.minimum=0.6;model.draft.maximum=2;model.draft.movement=0.06 }
                    else if value=="swipe" { model.draft.minimum=0;model.draft.maximum=1;model.draft.movement=0.15 }
                    else { model.draft.minimum=0;model.draft.maximum=0.35;model.draft.movement=0.06 }
                }
                Picker("Fingers",selection:$model.draft.fingers) { ForEach(2...5,id:\.self) { Text("\($0)").tag($0) } }.frame(width:100)
            }
            if model.draft.kind=="swipe" { Picker("Direction",selection:$model.draft.direction) { ForEach(["up","down","left","right"],id:\.self) { Text($0.capitalized).tag($0) } } }
            Picker("Start zone",selection:$model.draft.zone) { ForEach(["any","left","right","top","bottom","topLeft","topRight","bottomLeft","bottomRight"],id:\.self) { Text($0).tag($0) } }
            VStack(alignment:.leading,spacing:5) {
                HStack { Text(model.draft.kind=="swipe" ? "Minimum travel" : "Maximum movement");Spacer();Text(String(format:"%.2f",model.draft.movement)).monospacedDigit() }.font(.system(size:11))
                Slider(value:$model.draft.movement,in:0.01...0.4,step:0.01)
            }
            HStack {
                number("Min seconds",value:$model.draft.minimum)
                number("Max seconds",value:$model.draft.maximum)
                number("Cooldown",value:$model.draft.cooldown)
            }
            HStack { Text("Modifiers").font(.system(size:11)); Toggle("⌘",isOn:$model.draft.command);Toggle("⌥",isOn:$model.draft.option);Toggle("⇧",isOn:$model.draft.shift);Toggle("⌃",isOn:$model.draft.control) }.toggleStyle(.checkbox)
            TextField("Application bundle ID · empty = all apps",text:$model.draft.appScope).textFieldStyle(.roundedBorder)
            if !model.draft.extraCapabilities.isEmpty { Text("Additional requirements: " + model.draft.extraCapabilities.map(\.rawValue).sorted().joined(separator:", ")).font(.system(size:10)).foregroundStyle(.orange) }
            Stepper("Priority: \(model.draft.priority)",value:$model.draft.priority,in:-100...100).font(.system(size:11))
            Divider()
            Picker("Action",selection:$model.draft.actionKind) {
                Text("System beep").tag("beep");Text("Open HTTP(S) URL").tag("openURL");Text("Launch application").tag("launch");Text("Focus application").tag("focus");Text("Hide application").tag("hide");Text("Run Apple Shortcut").tag("shortcut");Text("Keyboard / imported · unsupported").tag("unsupported")
            }
            if !["beep","unsupported"].contains(model.draft.actionKind) { TextField(model.draft.actionKind=="shortcut" ? "Existing Apple Shortcut name" : (model.draft.actionKind=="openURL" ? "https://example.com" : "com.apple.TextEdit"),text:$model.draft.actionValue).textFieldStyle(.roundedBorder) }
            if model.draft.actionKind=="shortcut" { Text("Manual test runs this existing Shortcut through the system handler. Its own actions may have side effects.").font(.system(size:10)).foregroundStyle(.orange) }
            if model.draft.actionKind=="unsupported" { Text("Keyboard injection is disabled: forced-termination key-up safety has not been proven. Imported actions are preserved.").font(.system(size:10)).foregroundStyle(.orange) }
            HStack { Button("Save definition") { model.saveGesture() }.buttonStyle(.borderedProminent); Button("Test action now") { model.testAction() }.disabled(model.draft.actionKind=="unsupported") }.font(.system(size:12))
            Text("Save enables recognition in preview only. USB global capture is not verified.").font(.system(size:10)).foregroundStyle(muted)
        }.padding(18).background(Color.white.opacity(0.035),in:RoundedRectangle(cornerRadius:16))
    }
    private func number(_ name:String,value:Binding<Double>)->some View {
        VStack(alignment:.leading,spacing:4) { Text(name).font(.system(size:10)).foregroundStyle(muted); TextField(name,value:value,format:.number.precision(.fractionLength(0...2))).textFieldStyle(.roundedBorder) }
    }
    private var capabilities:some View {
        VStack(alignment:.leading,spacing:10) {
            Text("Capability truth").font(.headline)
            capability("USB-C reference capture","UNVERIFIED",.orange)
            capability("Global contacts / finger count / zones","UNSUPPORTED",.orange)
            capability("Tap / hold / swipe core","SYNTHETIC TESTS",accent)
            capability("Pressure / contact area","UNAVAILABLE",muted)
            capability("Pinch / rotate recognition","UNSUPPORTED",.orange)
            if let d=model.devices.first { Text("Observed: \(d.product ?? "Unknown device") · \(d.transport ?? "unknown") · VID \(d.vendorID.map{String(format:"0x%04x",$0)} ?? "unknown") / PID \(d.productID.map{String(format:"0x%04x",$0)} ?? "unknown")").font(.system(size:10)).foregroundStyle(muted) }
            else { Text("No Apple HID device discovered.").font(.system(size:10)).foregroundStyle(muted) }
            Text("Bluetooth is roadmap-only. Discovery does not certify gesture support.").font(.system(size:10)).foregroundStyle(muted)
        }.padding(18).background(Color.white.opacity(0.025),in:RoundedRectangle(cornerRadius:16))
    }
    private func capability(_ name:String,_ state:String,_ color:Color)->some View { HStack { Text(name).font(.system(size:11));Spacer();Text(state).font(.system(size:9,weight:.medium,design:.monospaced)).foregroundStyle(color) } }
    private var permissions:some View {
        VStack(alignment:.leading,spacing:10) {
            Label("Permissions",systemImage:"lock.shield").font(.headline)
            Text("Input Monitoring: \(model.permissions.inputMonitoring ? "granted in this context" : "not granted")").font(.system(size:12,weight:.medium))
            Text("Unused in this build. Global capture is unavailable. This OS permission alone cannot expose missing touch fields.").font(.system(size:11)).foregroundStyle(muted)
            Text("Accessibility: \(model.permissions.accessibility ? "trusted in this context" : "not trusted")").font(.system(size:12,weight:.medium))
            Text("Unused in this build. Local preview and manual handler actions do not need it; input injection remains unsupported.").font(.system(size:11)).foregroundStyle(muted)
            Button("Open Privacy settings…") { NSWorkspace.shared.open(URL(string:"x-apple.systempreferences:com.apple.preference.security")!) }.font(.system(size:11))
        }.padding(18).frame(maxWidth:.infinity,alignment:.leading).background(Color.white.opacity(0.025),in:RoundedRectangle(cornerRadius:16))
    }
    private var decisions:some View {
        VStack(alignment:.leading,spacing:10) {
            Label("Before enabling",systemImage:"arrow.triangle.branch").font(.headline)
            Text("One sequence → at most one winner").font(.system(size:12,weight:.medium))
            Text("Application scope → capability specificity → priority → stable ID. Equal inputs always use the same order.").font(.system(size:11)).foregroundStyle(muted)
            ForEach(model.conflictMessages,id:\.self) { Text($0).font(.system(size:11)).foregroundStyle(.orange) }
            if model.conflictMessages.isEmpty { Text("No potential overlap with other saved definitions.").font(.system(size:11)).foregroundStyle(muted) }
            Text("Native input stays active. Preview does not trigger actions.").font(.system(size:11)).foregroundStyle(accent)
        }.padding(18).frame(maxWidth:.infinity,alignment:.leading).background(Color.white.opacity(0.025),in:RoundedRectangle(cornerRadius:16))
    }
}
