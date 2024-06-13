import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    var activeApplicationName: String = "" // 現在アクティブなアプリケーションの名前を保存する変数
    var slackApp: AXUIElement! // SlackアプリケーションのAXUIElementオブジェクト
    var observer: AXObserver? // AXObserverオブジェクト

    // アプリケーションが起動したときに呼び出されるメソッド
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // アクセシビリティの権限を確認するためのオプションを設定
        let trustedCheckOptionPrompt = kAXTrustedCheckOptionPrompt.takeRetainedValue() as NSString
        let options = [trustedCheckOptionPrompt: true] as CFDictionary
        // アクセシビリティの権限が許可されているか確認
        if AXIsProcessTrustedWithOptions(options) {
            setup() // 権限がある場合、初期設定を行う
            monitorActiveApplication() // アクティブなアプリケーションを監視する
        } else {
            // 権限がない場合、権限が許可されるまで待つ
            waitPermissionGranted {
                self.setup()
                self.monitorActiveApplication()
            }
        }
        // アクティブなアプリケーションが変更されたときの通知を登録
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(activeAppDidChange(_:)), name: NSWorkspace.didActivateApplicationNotification, object: nil)
    }

    // アクティブなアプリケーションが変更されたときに呼び出されるメソッド
    @objc func activeAppDidChange(_ notification: Notification) {
        if let activeApp = NSWorkspace.shared.frontmostApplication {
            activeApplicationName = activeApp.localizedName! // 新しいアクティブなアプリケーションの名前を取得
            print("Active app: \(activeApplicationName)") // アクティブなアプリケーションの名前を出力
        }
    }

    // セットアップメソッド
    private func setup() {
        if let slackApp = getSlackApplication() {
            self.slackApp = slackApp // SlackアプリケーションのAXUIElementオブジェクトを保存
            startMonitoringSlack() // Slackの監視を開始
        } else {
            print("Slack is not running.") // Slackが実行されていない場合のメッセージ
        }
    }

    // SlackアプリケーションのAXUIElementオブジェクトを取得するメソッド
    private func getSlackApplication() -> AXUIElement? {
        let workspace = NSWorkspace.shared
        let apps = workspace.runningApplications
        for app in apps {
            if app.localizedName == "Slack" {
                return AXUIElementCreateApplication(app.processIdentifier) // SlackアプリケーションのAXUIElementオブジェクトを返す
            }
        }
        return nil // Slackアプリケーションが見つからない場合はnilを返す
    }

    // Slackからメッセージを取得するメソッド
    private func fetchSlackMessages(from app: AXUIElement) {
        print("Attempting to fetch Slack messages...") // メッセージ取得の試行を出力
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &value)
        if result == .success, let windows = value as? [AXUIElement] {
            for window in windows {
                extractMessagesFromWindow(window) // 各ウィンドウからメッセージを抽出
            }
        } else {
            print("Could not retrieve Slack windows.") // Slackウィンドウが取得できない場合のメッセージ
        }
    }

    // ウィンドウからメッセージを抽出するメソッド
    private func extractMessagesFromWindow(_ window: AXUIElement) {
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(window, kAXChildrenAttribute as CFString, &value)
        if result == .success, let children = value as? [AXUIElement] {
            for child in children {
                extractMessagesFromElement(child) // 各子要素からメッセージを抽出
            }
        } else {
            print("Could not retrieve window children.") // ウィンドウの子要素が取得できない場合のメッセージ
        }
    }

    // 要素からメッセージを抽出するメソッド
    private func extractMessagesFromElement(_ element: AXUIElement) {
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &value)
        if result == .success, let role = value as? String {
            if role == kAXStaticTextRole as String {
                var messageValue: AnyObject?
                let messageResult = AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &messageValue)
                if messageResult == .success, let message = messageValue as? String {
                    print("Message: \(message)") // メッセージの出力
                }
            } else {
                var childValue: AnyObject?
                let childResult = AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childValue)
                if childResult == .success, let children = childValue as? [AXUIElement] {
                    for child in children {
                        extractMessagesFromElement(child) // 各子要素から再帰的にメッセージを抽出
                    }
                }
            }
        }
    }

    // アクティブなアプリケーションを監視するメソッド
    private func monitorActiveApplication() {
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            let workspace = NSWorkspace.shared
            if let activeApp = workspace.frontmostApplication {
                if self.activeApplicationName != activeApp.localizedName {
                    self.activeApplicationName = activeApp.localizedName ?? ""
                    print("Active application: \(self.activeApplicationName)") // アクティブなアプリケーションが変更された場合のメッセージ
                    if self.activeApplicationName == "Slack" {
                        if let slackApp = self.slackApp {
                            self.fetchSlackMessages(from: slackApp) // Slackがアクティブになった場合、メッセージを取得
                        }
                    }
                }
            }
        }
    }

    // Slackの監視を開始するメソッド
    private func startMonitoringSlack() {
        guard let app = NSWorkspace.shared.runningApplications.first(where: { $0.localizedName == "Slack" }) else {
            print("Slack is not running.") // Slackが実行されていない場合のメッセージ
            return
        }

        var observer: AXObserver?
        AXObserverCreate(app.processIdentifier, { (observer, element, notification, refcon) in
            let delegate = Unmanaged<AppDelegate>.fromOpaque(refcon!).takeUnretainedValue()
            delegate.handleAXEvent(element: element, notification: notification as String) // アクセシビリティイベントのハンドリング
        }, &observer)

        if let observer = observer {
            AXObserverAddNotification(observer, slackApp, kAXValueChangedNotification as CFString, UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()))
            CFRunLoopAddSource(CFRunLoopGetCurrent(), AXObserverGetRunLoopSource(observer), .defaultMode)
            self.observer = observer // 監視オブジェクトを保存
        }
    }

    // アクセシビリティイベントをハンドリングするメソッド
    private func handleAXEvent(element: AXUIElement, notification: String) {
        if notification == kAXValueChangedNotification as String {
            fetchSlackMessages(from: slackApp) // AXValueChangedNotificationイベントが発生したときにメッセージを取得
        }
    }

    // アクセシビリティ権限が許可されるまで待つメソッド
    private func waitPermissionGranted(completion: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if AXIsProcessTrusted() {
                completion() // 権限が許可された場合、完了ハンドラを呼び出す
            } else {
                self.waitPermissionGranted(completion: completion) // 権限が許可されていない場合、再試行
            }
        }
    }
}
