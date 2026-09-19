import Cocoa
import FlutterMacOS

/// macOS ネイティブ側でお知らせ未読を監視（App Nap / フォーカス喪失でも動きやすい）
final class NoticePoller: NSObject {
  static let shared = NoticePoller()

  private static let lastSeenKey = "flutter.lgsplus_notice_last_seen_id"
  private static let unreadKey = "flutter.lgsplus_notice_unread"

  private var timer: Timer?
  private weak var channel: FlutterMethodChannel?
  private let appKey = "lgsplus-ops-sync-2026"
  private let endpoint = URL(string: "https://shopws.infmaxai.com/api/lgsplus/listNotices")!

  private var activity: NSObjectProtocol?
  private var started = false
  private lazy var session: URLSession = {
    let cfg = URLSessionConfiguration.ephemeral
    cfg.timeoutIntervalForRequest = 15
    cfg.waitsForConnectivity = true
    cfg.requestCachePolicy = .reloadIgnoringLocalCacheData
    return URLSession(configuration: cfg)
  }()

  func attach(channel: FlutterMethodChannel) {
    self.channel = channel
  }

  /// Flutter 起動前でも UserDefaults の既読位置でポーリング開始
  func ensureStarted() {
    start(lastSeenId: readLastSeenFromDefaults())
  }

  func start(lastSeenId: Int) {
    writeLastSeenIfHigher(lastSeenId)
    beginActivity()
    started = true
    timer?.invalidate()
    let t = Timer(timeInterval: 6.0, repeats: true) { [weak self] _ in
      self?.fetch()
    }
    RunLoop.main.add(t, forMode: .common)
    timer = t
    log("start lastSeen=\(readLastSeenFromDefaults())")
    fetch()
  }

  func stop() {
    timer?.invalidate()
    timer = nil
    started = false
    endActivity()
    log("stop")
    DispatchQueue.main.async {
      self.applyDock(0)
      self.applyWindowTitle(0)
    }
  }

  func setLastSeenId(_ id: Int) {
    writeLastSeenIfHigher(id)
    log("setLastSeenId=\(id)")
    fetch()
  }

  func refreshNow() {
    if !started {
      ensureStarted()
      return
    }
    fetch()
  }

  private func readLastSeenFromDefaults() -> Int {
    UserDefaults.standard.integer(forKey: Self.lastSeenKey)
  }

  private func writeLastSeenIfHigher(_ id: Int) {
    guard id > 0 else { return }
    let prev = readLastSeenFromDefaults()
    if id > prev {
      UserDefaults.standard.set(id, forKey: Self.lastSeenKey)
      UserDefaults.standard.synchronize()
    }
  }

  private func beginActivity() {
    if activity != nil { return }
    activity = ProcessInfo.processInfo.beginActivity(
      options: [.userInitiatedAllowingIdleSystemSleep, .latencyCritical],
      reason: "LGS+ notice polling"
    )
  }

  private func endActivity() {
    if let activity {
      ProcessInfo.processInfo.endActivity(activity)
      self.activity = nil
    }
  }

  private func fetch() {
    var req = URLRequest(url: endpoint, timeoutInterval: 15)
    req.httpMethod = "POST"
    req.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
    req.setValue(appKey, forHTTPHeaderField: "X-Lgsplus-Key")
    let body: [String: Any] = ["client_app": "mac", "limit": 50]
    req.httpBody = try? JSONSerialization.data(withJSONObject: body)

    let seen = readLastSeenFromDefaults()
    session.dataTask(with: req) { [weak self] data, response, error in
      guard let self else { return }
      if let error {
        self.log("fetch error: \(error.localizedDescription)")
        return
      }
      let code = (response as? HTTPURLResponse)?.statusCode ?? -1
      guard let data else {
        self.log("fetch empty status=\(code)")
        return
      }
      guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        let preview = String(data: data.prefix(120), encoding: .utf8) ?? "?"
        self.log("json fail status=\(code) body=\(preview)")
        return
      }
      let successNum = json["success"] as? NSNumber
      let successOk = (successNum?.intValue == 1) || (json["success"] as? Bool == true)
      guard successOk else {
        self.log("success!=1 raw=\(String(describing: json["success"]))")
        return
      }
      guard let dataMap = json["data"] as? [String: Any],
            let notices = dataMap["notices"] as? [[String: Any]]
      else {
        self.log("no notices array")
        return
      }

      var unread = 0
      var maxId = 0
      for n in notices {
        let id = self.intValue(n["id"])
        if id > maxId { maxId = id }
        if id > seen { unread += 1 }
      }

      self.log("ok seen=\(seen) max=\(maxId) unread=\(unread) n=\(notices.count)")
      DispatchQueue.main.async {
        self.pushUnread(unread)
      }
    }.resume()
  }

  private func intValue(_ raw: Any?) -> Int {
    if let i = raw as? Int { return i }
    if let n = raw as? NSNumber { return n.intValue }
    if let s = raw as? String, let i = Int(s) { return i }
    return 0
  }

  private func pushUnread(_ unread: Int) {
    UserDefaults.standard.set(unread, forKey: Self.unreadKey)
    UserDefaults.standard.synchronize()
    applyDock(unread)
    applyWindowTitle(unread)
    channel?.invokeMethod("unreadUpdated", arguments: ["count": unread])
  }

  private func applyDock(_ unread: Int) {
    NSApp.dockTile.badgeLabel = unread > 0 ? "\(min(unread, 99))" : nil
    NSApp.dockTile.display()
  }

  private func applyWindowTitle(_ unread: Int) {
    let base = "LGS+積算"
    let title = unread > 0 ? "\(base)（未読\(min(unread, 99))）" : base
    for win in NSApp.windows {
      win.title = title
    }
  }

  private func log(_ msg: String) {
    let line = "\(ISO8601DateFormatter().string(from: Date())) \(msg)\n"
    NSLog("[LGS+ notice] %@", msg)
    let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
      ?? URL(fileURLWithPath: NSTemporaryDirectory())
    let folder = dir.appendingPathComponent("jp.lgsplus.lgsPlus.mac", isDirectory: true)
    try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    let path = folder.appendingPathComponent("lgs_notice_poll.log")
    if let data = line.data(using: .utf8) {
      if FileManager.default.fileExists(atPath: path.path),
         let handle = try? FileHandle(forWritingTo: path) {
        defer { try? handle.close() }
        handle.seekToEndOfFile()
        handle.write(data)
      } else {
        try? data.write(to: path, options: .atomic)
      }
    }
  }
}
