import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    // Set initial window size
    self.setContentSize(NSSize(width: 1200, height: 800))
    self.minSize = NSSize(width: 600, height: 400)
    self.title = "Claude Dash"
    if let screen = self.screen {
      let screenFrame = screen.visibleFrame
      let x = screenFrame.midX - 600
      let y = screenFrame.midY - 400
      self.setFrameOrigin(NSPoint(x: x, y: y))
    }

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
