import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    var activeApplicationName: String = ""
    var slackApp: AXUIElement!

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        let trustedCheckOptionPrompt = kAXTrustedCheckOptionPrompt.takeRetainedValue() as NSString
        let options = [trustedCheckOptionPrompt: true] as CFDictionary
        if AXIsProcessTrustedWithOptions(options) {
            setup()
            monitorActiveApplication()
        } else {
            waitPermissionGranted {
                self.setup()
                self.monitorActiveApplication()
            }
        }
    }

    private func setup() {
        if let slackApp = getSlackApplication() {
            self.slackApp = slackApp
        } else {
            print("Slack is not running.")
        }
    }

    private func getSlackApplication() -> AXUIElement? {
        let workspace = NSWorkspace.shared
        let apps = workspace.runningApplications
        for app in apps {
            if app.localizedName == "Slack" {
                return AXUIElementCreateApplication(app.processIdentifier)
            }
        }
        return nil
    }

    private func fetchSlackMessages(from app: AXUIElement) {
        print("Attempting to fetch Slack messages...")
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &value)
        if result == .success, let windows = value as? [AXUIElement] {
            for window in windows {
                extractMessagesFromWindow(window)
            }
        } else {
            print("Could not retrieve Slack windows.")
        }
    }

    private func extractMessagesFromWindow(_ window: AXUIElement) {
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(window, kAXChildrenAttribute as CFString, &value)
        if result == .success, let children = value as? [AXUIElement] {
            for child in children {
                extractMessagesFromElement(child)
            }
        } else {
            print("Could not retrieve window children.")
        }
    }

    private func extractMessagesFromElement(_ element: AXUIElement) {
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &value)
        if result == .success, let role = value as? String {
            if role == kAXStaticTextRole as String {
                var messageValue: AnyObject?
                let messageResult = AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &messageValue)
                if messageResult == .success, let message = messageValue as? String {
                    print("Message: \(message)")
                }
            } else {
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

    private func monitorActiveApplication() {
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            let workspace = NSWorkspace.shared
            if let activeApp = workspace.frontmostApplication {
                if self.activeApplicationName != activeApp.localizedName {
                    self.activeApplicationName = activeApp.localizedName ?? ""
                    print("Active application: \(self.activeApplicationName)")
                    if self.activeApplicationName == "Slack" {
                        if let slackApp = self.slackApp {
                            self.fetchSlackMessages(from: slackApp)
                        }
                    }
                }
            }
        }
    }

    private func waitPermissionGranted(completion: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if AXIsProcessTrusted() {
                completion()
            } else {
                self.waitPermissionGranted(completion: completion)
            }
        }
    }
}
