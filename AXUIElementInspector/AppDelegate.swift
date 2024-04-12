import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    var mailMessageFromTimer: Timer?
    var activeApplicationName: String = ""

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // アクセシビリティの権限チェックを行う
        let trustedCheckOptionPrompt = kAXTrustedCheckOptionPrompt.takeRetainedValue() as NSString
        let options = [trustedCheckOptionPrompt: true] as CFDictionary
        if AXIsProcessTrustedWithOptions(options) {
            // 権限がある場合はsetup()を呼び出す
            setup()
        } else {
            // 権限がない場合は権限が付与されるまで待機し、付与されたらsetup()を呼び出す
            waitPermissionGranted {
                self.setup()
            }
        }

        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(applicationActivated),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
    }

    private func setup() {
        // タイマーを設定し、1秒ごとにアクティブなアプリケーションをチェックする
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            self.checkActiveApplication()
        }
    }

    private func waitPermissionGranted(completion: @escaping () -> Void) {
        // 0.3秒後に権限チェックを行い、権限がある場合はcompletion()を呼び出す
        // 権限がない場合は再度waitPermissionGranted()を呼び出す
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if AXIsProcessTrusted() {
                completion()
            } else {
                self.waitPermissionGranted(completion: completion)
            }
        }
    }

    private func checkActiveApplication() {
        let workspace = NSWorkspace.shared
        let activeApplication = workspace.frontmostApplication
        activeApplicationName = activeApplication?.localizedName ?? "Unknown"
        print("Active application: \(activeApplicationName)")

        if activeApplicationName == "Mail" {
            if mailMessageFromTimer == nil {
                mailMessageFromTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) {
                    _ in
                    self.getMailMessageFrom()
                }
            }
        } else {
            mailMessageFromTimer?.invalidate()
            mailMessageFromTimer = nil
        }
    }

    private func getMailMessageFrom() {
        print("Get message from")
        let workspace = NSWorkspace.shared
        let activeApplication = workspace.frontmostApplication
        let axMailApp = AXUIElementCreateApplication(activeApplication?.processIdentifier ?? 0)
        let axStaticText = findAXStaticText(in: axMailApp, withIdentifier: "message.from.0")
        if let axStaticText = axStaticText {
            var textValue: AnyObject?
            AXUIElementCopyAttributeValue(axStaticText, kAXValueAttribute as CFString, &textValue)
            if let textValue = textValue as? String {
                print("Message From: \(textValue)")
            }
        }
    }
    private func findAXStaticText(in element: AXUIElement, withIdentifier identifier: String)
        -> AXUIElement?
    {
        var result: AXUIElement?
        let childrenCount = getAXChildren(of: element).count
        for index in 0..<childrenCount {
            guard let child = getAXChild(of: element, at: index) else { continue }

            if getAXRole(of: child) == kAXStaticTextRole {
                if getAXIdentifier(of: child) == identifier {
                    result = child
                    break
                }
            }

            result = findAXStaticText(in: child, withIdentifier: identifier)
            if result != nil {
                break
            }
        }
        return result
    }

    private func getAXChildren(of element: AXUIElement) -> [AXUIElement] {
        var children: [AXUIElement] = []
        var childrenCount = CFIndex(0)
        AXUIElementGetAttributeValueCount(element, kAXChildrenAttribute as CFString, &childrenCount)

        var childrenArray: AnyObject?
        AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenArray)
        if let childrenArray = childrenArray as? [AXUIElement] {
            children = childrenArray
        }

        return children
    }

    private func getAXChild(of element: AXUIElement, at index: Int) -> AXUIElement? {
        var children: AnyObject?
        AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &children)
        if let children = children as? [AXUIElement], index >= 0 && index < children.count {
            return children[index]
        }
        return nil
    }

    private func getAXRole(of element: AXUIElement) -> String {
        var role: AnyObject?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role)
        return role as? String ?? ""
    }

    private func getAXIdentifier(of element: AXUIElement) -> String {
        var identifier: AnyObject?
        AXUIElementCopyAttributeValue(element, kAXIdentifierAttribute as CFString, &identifier)
        return identifier as? String ?? ""
    }

    @objc private func applicationActivated(_ notification: Notification) {
        guard
            let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey]
                as? NSRunningApplication
        else {
            return
        }

        if application.localizedName == "Mail" {
            if mailMessageFromTimer == nil {
                mailMessageFromTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) {
                    _ in
                    self.getMailMessageFrom()
                }
            }
        } else {
            mailMessageFromTimer?.invalidate()
            mailMessageFromTimer = nil
        }
    }
}
