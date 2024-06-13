import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    // 現在アクティブなアプリケーションの名前を保持する変数
    var activeApplicationName: String = ""
    // Slackアプリケーションを表すAXUIElement
    var slackApp: AXUIElement!

    // アプリケーションの起動時に呼ばれるメソッド
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // AXIsProcessTrustedWithOptionsのオプションを設定（アクセス許可のプロンプトを表示）
        let trustedCheckOptionPrompt = kAXTrustedCheckOptionPrompt.takeRetainedValue() as NSString
        let options = [trustedCheckOptionPrompt: true] as CFDictionary
        if AXIsProcessTrustedWithOptions(options) {
            // アクセス許可が与えられている場合、セットアップとアクティブアプリのモニタリングを開始
            setup()
            monitorActiveApplication()
        } else {
            // アクセス許可が与えられていない場合、許可が与えられるまで待つ
            waitPermissionGranted {
                self.setup()
                self.monitorActiveApplication()
            }
        }
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(activeAppDidChange(_:)), name: NSWorkspace.didActivateApplicationNotification, object: nil)
                startMouseClickMonitoring()
    }

    @objc func activeAppDidChange(_ notification: Notification) {
           if let activeApp = NSWorkspace.shared.frontmostApplication {
               activeApplicationName = activeApp.localizedName!
               print("Active app: \(activeApplicationName)")
           }
       }

    func startMouseClickMonitoring() {
        let mask = (1 << CGEventType.leftMouseDown.rawValue) | (1 << CGEventType.rightMouseDown.rawValue)
        if let eventTap = CGEvent.tapCreate(tap: .cghidEventTap, place: .headInsertEventTap, options: .defaultTap, eventsOfInterest: CGEventMask(mask), callback: { (proxy, type, event, refcon) in
            let delegate = Unmanaged<AppDelegate>.fromOpaque(refcon!).takeUnretainedValue()
            delegate.mouseClicked()
            return Unmanaged.passUnretained(event)
        }, userInfo: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())) {
            let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
            CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
            CGEvent.tapEnable(tap: eventTap, enable: true)
        } else {
            print("Failed to create event tap.")
        }
    }

    func mouseClicked() {
        if activeApplicationName == "Slack" {
            fetchSlackMessages(from: slackApp)
        }
    }

    // セットアップメソッド
    private func setup() {
        // Slackアプリケーションを取得し、変数にセット
        if let slackApp = getSlackApplication() {
            self.slackApp = slackApp
        } else {
            // Slackが起動していない場合のエラーメッセージ
            print("Slack is not running.")
        }
    }

    // SlackアプリケーションのAXUIElementを取得するメソッド
    private func getSlackApplication() -> AXUIElement? {
        let workspace = NSWorkspace.shared
        let apps = workspace.runningApplications
        for app in apps {
            // アプリケーションの名前が「Slack」の場合、そのプロセスIDを使ってAXUIElementを作成
            if app.localizedName == "Slack" {
                return AXUIElementCreateApplication(app.processIdentifier)
            }
        }
        return nil
    }

    // Slackメッセージを取得するメソッド
    private func fetchSlackMessages(from app: AXUIElement) {
        print("Attempting to fetch Slack messages...")
        var value: AnyObject?
        // Slackアプリのウィンドウを取得
        let result = AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &value)
        if result == .success, let windows = value as? [AXUIElement] {
            for window in windows {
                // 各ウィンドウからメッセージを抽出
                extractMessagesFromWindow(window)
            }
        } else {
            print("Could not retrieve Slack windows.")
        }
    }

    // ウィンドウからメッセージを抽出するメソッド
    private func extractMessagesFromWindow(_ window: AXUIElement) {
        var value: AnyObject?
        // ウィンドウの子要素を取得
        let result = AXUIElementCopyAttributeValue(window, kAXChildrenAttribute as CFString, &value)
        if result == .success, let children = value as? [AXUIElement] {
            for child in children {
                // 各子要素からメッセージを抽出
                extractMessagesFromElement(child)
            }
        } else {
            print("Could not retrieve window children.")
        }
    }

    // 要素からメッセージを抽出するメソッド
    private func extractMessagesFromElement(_ element: AXUIElement) {
        var value: AnyObject?
        // 要素の役割を取得
        let result = AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &value)
        if result == .success, let role = value as? String {
            if role == kAXStaticTextRole as String {
                // 要素が静的テキストの場合、その値を取得
                var messageValue: AnyObject?
                let messageResult = AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &messageValue)
                if messageResult == .success, let message = messageValue as? String {
                    print("Message: \(message)")
                }
            } else {
                // 要素に子要素がある場合、それらを再帰的に処理
                var childValue: AnyObject?
                let childResult = AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childValue)
                if childResult == .success, let children = childValue as? [AXUIElement] {
                    for child in children {
                        extractMessagesFromElement(child)
                    }
                }
            }
        }
    }

    // アクティブなアプリケーションをモニタリングするメソッド
    private func monitorActiveApplication() {
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            let workspace = NSWorkspace.shared
            if let activeApp = workspace.frontmostApplication {
                // アクティブアプリケーションが変わった場合、その名前を更新
                if self.activeApplicationName != activeApp.localizedName {
                    self.activeApplicationName = activeApp.localizedName ?? ""
                    print("Active application: \(self.activeApplicationName)")
                    // アクティブアプリがSlackの場合、メッセージを取得
                    if self.activeApplicationName == "Slack" {
                        if let slackApp = self.slackApp {
                            self.fetchSlackMessages(from: slackApp)
                        }
                    }
                }
            }
        }
    }

    // アクセス許可が与えられるまで待つメソッド
    private func waitPermissionGranted(completion: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if AXIsProcessTrusted() {
                completion()
            } else {
                // 許可が与えられるまで再帰的に呼び出す
                self.waitPermissionGranted(completion: completion)
            }
        }
    }
}
