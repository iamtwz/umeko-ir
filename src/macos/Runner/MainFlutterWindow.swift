import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController

    let visibleFrame = NSScreen.main?.visibleFrame ?? self.frame
    let defaultWidth = min(1280, visibleFrame.width * 0.9)
    let defaultHeight = min(840, visibleFrame.height * 0.9)
    let origin = NSPoint(
      x: visibleFrame.midX - defaultWidth / 2,
      y: visibleFrame.midY - defaultHeight / 2)
    self.setFrame(
      NSRect(origin: origin, size: NSSize(width: defaultWidth, height: defaultHeight)),
      display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
