import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController

    if let screenFrame = NSScreen.main?.visibleFrame {
      let topHeight: CGFloat = 360
      let newFrame = NSRect(
        x: 0,
        y: screenFrame.maxY - topHeight,
        width: screenFrame.width,
        height: topHeight)
      self.setFrame(newFrame, display: true)
    }

    self.titleVisibility = .hidden
    self.titlebarAppearsTransparent = true
    self.styleMask.insert(.fullSizeContentView)
    self.level = .floating
    self.isOpaque = false
    self.backgroundColor = .clear

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
