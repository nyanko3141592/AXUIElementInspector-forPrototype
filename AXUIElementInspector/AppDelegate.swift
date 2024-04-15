import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    var activeApplicationName: String = ""
    var tap: CFMachPort!

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
    }

    private func setup() {
        // CGEventTapを作成し、マウスイベントを監視
        let mask: CGEventMask = (1 << CGEventType.mouseMoved.rawValue)
        tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { (proxy, type, event, refcon) in
                if let observer = refcon {
                    let this = Unmanaged<AppDelegate>.fromOpaque(observer).takeUnretainedValue()
                    this.mouseMoved()
                }
                return Unmanaged.passUnretained(event)
            },
            userInfo: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        )

        // CGEventTapをRunLoopに追加
        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)

        // CGEventTapを有効化
        CGEvent.tapEnable(tap: tap, enable: true)
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

    private func mouseMoved() {
        let workspace = NSWorkspace.shared
        let activeApplication = workspace.frontmostApplication
        activeApplicationName = activeApplication?.localizedName ?? "Unknown"
        print("Active application: \(activeApplicationName)")

        if activeApplicationName == "Slack" {
            getMailMessageFrom()
        }
    }
    private func getMailMessageFrom() {
        let workspace = NSWorkspace.shared
        let activeApplication = workspace.frontmostApplication
        let axMailApp = AXUIElementCreateApplication(activeApplication?.processIdentifier ?? 0)
        print("Getting message from Mail app...")

        let axButton = findAXButton(in: axMailApp, withTitle: "Takahashi Naoki")
        if let axButton = axButton {
            var textValue: AnyObject?
            AXUIElementCopyAttributeValue(axButton, kAXTitleAttribute as CFString, &textValue)
            if let textValue = textValue as? String {
                print("Button Title: \(textValue)")
            }
        }

        let axStaticTexts = findAXStaticTexts(in: axMailApp, withValues: ["...", "..."])
        for (index, axStaticText) in axStaticTexts.enumerated() {
            var textValue: AnyObject?
            AXUIElementCopyAttributeValue(axStaticText, kAXValueAttribute as CFString, &textValue)
            if let textValue = textValue as? String {
                print("Static Text \(index + 1) Value: \(textValue)")
            }
        }
    }

    private func findAXButton(in element: AXUIElement, withTitle title: String) -> AXUIElement? {
        var result: AXUIElement?
        let childrenCount = getAXChildren(of: element).count
        for index in 0..<childrenCount {
            guard let child = getAXChild(of: element, at: index) else { continue }

            if getAXRole(of: child) == kAXButtonRole {
                if getAXTitle(of: child) == title {
                    result = child
                    break
                }
            }

            result = findAXButton(in: child, withTitle: title)
            if result != nil {
                break
            }
        }
        return result
    }

    private func findAXStaticTexts(in element: AXUIElement, withValues values: [String])
        -> [AXUIElement]
    {
        var results: [AXUIElement] = []
        let childrenCount = getAXChildren(of: element).count
        for index in 0..<childrenCount {
            guard let child = getAXChild(of: element, at: index) else { continue }

            if getAXRole(of: child) == kAXStaticTextRole {
                if values.contains(getAXValue(of: child)) {
                    results.append(child)
                }
            }

            results.append(contentsOf: findAXStaticTexts(in: child, withValues: values))
        }
        return results
    }

    private func getAXValue(of element: AXUIElement) -> String {
        var value: AnyObject?
        AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &value)
        return value as? String ?? ""
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

    private func getAXTitle(of element: AXUIElement) -> String {
        var title: AnyObject?
        AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &title)
        return title as? String ?? ""
    }
}
