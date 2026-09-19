import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private var windowChannel: FlutterMethodChannel?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController
    self.setContentSize(NSSize(width: 1280, height: 840))
    self.minSize = NSSize(width: 960, height: 640)
    self.title = "LGS+積算"
    self.center()

    RegisterGeneratedPlugins(registry: flutterViewController)

    let channel = FlutterMethodChannel(
      name: "jp.lgsplus.lgsPlus/window",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    windowChannel = channel
    NoticePoller.shared.attach(channel: channel)
    // Dart の start() より先にネイティブ監視を開始（静的時の取りこぼし防止）
    NoticePoller.shared.ensureStarted()

    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "startNoticePoll":
        let args = call.arguments as? [String: Any]
        var lastSeen = 0
        if let v = args?["lastSeenId"] as? Int {
          lastSeen = v
        } else if let v = args?["lastSeenId"] as? NSNumber {
          lastSeen = v.intValue
        }
        NoticePoller.shared.start(lastSeenId: lastSeen)
        result(nil)
      case "stopNoticePoll":
        // ログアウト時だけ止める。ウィンドウ失焦では止めない
        NoticePoller.shared.stop()
        result(nil)
      case "setLastSeenId":
        let args = call.arguments as? [String: Any]
        var id = 0
        if let v = args?["lastSeenId"] as? Int {
          id = v
        } else if let v = args?["lastSeenId"] as? NSNumber {
          id = v.intValue
        }
        NoticePoller.shared.setLastSeenId(id)
        result(nil)
      case "refreshNotices":
        NoticePoller.shared.refreshNow()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(onDidBecomeKey),
      name: NSWindow.didBecomeKeyNotification,
      object: self
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(onAppActivated),
      name: NSApplication.didBecomeActiveNotification,
      object: nil
    )

    super.awakeFromNib()
  }

  deinit {
    NotificationCenter.default.removeObserver(self)
  }

  @objc private func onDidBecomeKey() {
    NoticePoller.shared.refreshNow()
    windowChannel?.invokeMethod("windowBecameKey", arguments: nil)
  }

  @objc private func onAppActivated() {
    NoticePoller.shared.refreshNow()
    windowChannel?.invokeMethod("appActivated", arguments: nil)
  }
}
