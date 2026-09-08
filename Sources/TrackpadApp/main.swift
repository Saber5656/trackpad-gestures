import AppKit
import SwiftUI

final class AppDelegate:NSObject,NSApplicationDelegate {
    var window:NSWindow?
    var model:AppModel?
    func applicationDidFinishLaunching(_ notification:Notification) {
        let model=AppModel(); self.model=model
        let window=NSWindow(contentRect:NSRect(x:0,y:0,width:1200,height:860),styleMask:[.titled,.closable,.miniaturizable,.resizable],backing:.buffered,defer:false)
        window.title="Trackpad Gestures — Local Studio"
        window.contentView=NSHostingView(rootView:ContentView(model:model))
        window.minSize=NSSize(width:1100,height:760); window.center(); window.makeKeyAndOrderFront(nil)
        self.window=window
        NSApp.activate(ignoringOtherApps:true)
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender:NSApplication)->Bool { true }
    func applicationWillTerminate(_ notification:Notification) { model?.shutdown() }
}
let app=NSApplication.shared
let delegate=AppDelegate()
app.delegate=delegate
app.setActivationPolicy(.regular)
let menu=NSMenu(); let appItem=NSMenuItem(); let appMenu=NSMenu()
appMenu.addItem(withTitle:"Quit Trackpad Gestures",action:#selector(NSApplication.terminate(_:)),keyEquivalent:"q")
appItem.submenu=appMenu; menu.addItem(appItem)
let editItem=NSMenuItem(); let editMenu=NSMenu(title:"Edit")
for (title,selector,key) in [("Cut",#selector(NSText.cut(_:)),"x"),("Copy",#selector(NSText.copy(_:)),"c"),("Paste",#selector(NSText.paste(_:)),"v"),("Select All",#selector(NSText.selectAll(_:)),"a")] { editMenu.addItem(withTitle:title,action:selector,keyEquivalent:key) }
editItem.submenu=editMenu; menu.addItem(editItem); app.mainMenu=menu
app.run()
