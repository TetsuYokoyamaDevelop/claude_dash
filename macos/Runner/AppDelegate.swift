import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  var channel: FlutterMethodChannel?

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  override func applicationDidFinishLaunching(_ notification: Notification) {
    let controller = mainFlutterWindow?.contentViewController as! FlutterViewController
    channel = FlutterMethodChannel(name: "com.tetsuyokoyama.claudedash/shortcuts",
                                   binaryMessenger: controller.engine.binaryMessenger)
    setupMenuShortcuts()
  }

  func setupMenuShortcuts() {
    // Create "Tab" menu
    let tabMenu = NSMenu(title: "Tab")

    // Cmd+1~9
    for i in 1...9 {
      let item = NSMenuItem(title: "Tab \(i)",
                            action: #selector(tabShortcut(_:)),
                            keyEquivalent: "\(i)")
      item.keyEquivalentModifierMask = [.command]
      item.tag = i
      tabMenu.addItem(item)
    }

    tabMenu.addItem(NSMenuItem.separator())

    // Cmd+Shift+] next tab
    let nextItem = NSMenuItem(title: "Next Tab",
                              action: #selector(nextTab),
                              keyEquivalent: "]")
    nextItem.keyEquivalentModifierMask = [.command, .shift]
    tabMenu.addItem(nextItem)

    // Cmd+Shift+[ prev tab
    let prevItem = NSMenuItem(title: "Previous Tab",
                              action: #selector(prevTab),
                              keyEquivalent: "[")
    prevItem.keyEquivalentModifierMask = [.command, .shift]
    tabMenu.addItem(prevItem)

    tabMenu.addItem(NSMenuItem.separator())

    // Cmd+T new tab
    let newItem = NSMenuItem(title: "New Tab",
                             action: #selector(newTab),
                             keyEquivalent: "t")
    newItem.keyEquivalentModifierMask = [.command]
    tabMenu.addItem(newItem)

    // Cmd+W close tab
    let closeItem = NSMenuItem(title: "Close Tab",
                               action: #selector(closeTab),
                               keyEquivalent: "w")
    closeItem.keyEquivalentModifierMask = [.command]
    tabMenu.addItem(closeItem)

    let tabMenuItem = NSMenuItem(title: "Tab", action: nil, keyEquivalent: "")
    tabMenuItem.submenu = tabMenu

    NSApp.mainMenu?.addItem(tabMenuItem)
  }

  @objc func tabShortcut(_ sender: NSMenuItem) {
    channel?.invokeMethod("selectTab", arguments: sender.tag - 1)
  }

  @objc func nextTab() {
    channel?.invokeMethod("nextTab", arguments: nil)
  }

  @objc func prevTab() {
    channel?.invokeMethod("prevTab", arguments: nil)
  }

  @objc func newTab() {
    channel?.invokeMethod("newTab", arguments: nil)
  }

  @objc func closeTab() {
    channel?.invokeMethod("closeTab", arguments: nil)
  }
}
