import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {
  // OverlayWindowとInspectorWindowのインスタンスを生成
  lazy var overlayWindow = OverlayWindow()
  lazy var inspectorWindow = InspectorWindow()

  // 現在インスペクションが有効かどうかを管理するプロパティ
  var isInspectingEnabled: Bool = false {
    didSet {
      // インスペクションの有効/無効状態をinspectorWindowに伝える
      inspectorWindow.isInspectingEnabled = isInspectingEnabled
    }
  }

  // CGEventTapを管理するプロパティ
  var tap: CFMachPort!

  func applicationDidFinishLaunching(_ aNotification: Notification) {
    // InspectorWindowのinspectボタンクリック時の処理を設定
    inspectorWindow.inspectButtonClicked = {
      self.isInspectingEnabled.toggle()
    }

    // InspectorWindowのサイズと位置を設定
    inspectorWindow.setContentSize(CGSize(width: 600, height: 800))
    inspectorWindow.setPosition(vertical: .bottom, horizontal: .right)

    // InspectorWindowを前面に表示
    inspectorWindow.orderFront(nil)
    
    // アクセシビリティの権限チェックを行う
    let trustedCheckOptionPrompt = kAXTrustedCheckOptionPrompt.takeRetainedValue() as NSString
    let options = [trustedCheckOptionPrompt: true] as CFDictionary
    if AXIsProcessTrustedWithOptions(options) {
      // 権限がある場合はsetup()を呼び出す
      setup()
    } else {
      // 権限がない場合は権限が付与されるまで待機し、付与されたらsetup()を呼び出す
      waitPermisionGranted {
        self.setup()
      }
    }
  }

  private func setup() {
    // CGEventTapを作成し、マウスイベントを監視
    let mask: CGEventMask = (1 << CGEventType.leftMouseDown.rawValue) | (1 << CGEventType.mouseMoved.rawValue)
    tap = CGEvent.tapCreate(
      tap: .cgSessionEventTap,
      place: .headInsertEventTap,
      options: .defaultTap,
      eventsOfInterest: mask,
      callback: { (proxy, type, event, refcon) in
        if let observer = refcon {
          let this = Unmanaged<AppDelegate>.fromOpaque(observer).takeUnretainedValue()

          switch event.type {
          case .leftMouseDown:
            // インスペクション中に左クリックされた場合はインスペクションを無効化
            if this.isInspectingEnabled {
              this.isInspectingEnabled.toggle()
              return nil
            }
          case .mouseMoved:
            // マウス移動時の処理を行う
            this.mouseMoved()
          case .tapDisabledByTimeout:
            // タップが無効になった場合は再度有効化
            this.enableTap()
          default:
            break
          }
        }
        return Unmanaged.passUnretained(event)
      },
      userInfo: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
    )

    // CGEventTapをRunLoopに追加
    let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
    CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)

    // CGEventTapを有効化
    enableTap()
  }

  private func enableTap() {
    // CGEventTapを有効化する
    CGEvent.tapEnable(tap: tap, enable: true)
  }

  private func mouseMoved() {
    // インスペクションが有効でない場合は処理を終了
    guard isInspectingEnabled else {
      return
    }

    // システム全体のAXUIElementを取得
    let systemWideElement = AXUIElementCreateSystemWide()

    // マウスの位置を取得
    let mouseLocation = carbonScreenPointFromCocoaScreenPoint(NSEvent.mouseLocation)

    var element: AXUIElement?
    // マウスの位置にあるAXUIElementを取得
    let copyElementError = AXUIElementCopyElementAtPosition(
      systemWideElement,
      Float(mouseLocation.x),
      Float(mouseLocation.y),
      &element
    )

    // エラーチェック
    guard let element, copyElementError == .success else {
      return
    }

    var attributeValue: AnyObject?
    // AXUIElementの"AXFrame"属性を取得
    let attributeValueError = AXUIElementCopyAttributeValue(
      element,
      "AXFrame" as CFString,
      &attributeValue
    )

    // エラーチェック
    guard let attributeValue, attributeValueError == .success else {
      return
    }

    let value = attributeValue as! AXValue

    var rect = CGRect()
    // AXValueからCGRectを取得
    guard AXValueGetValue(value, .cgRect, &rect) else {
      return
    }

    var origin = cocoaScreenPointFromCarbonScreenPoint(rect.origin)
    origin.y -= rect.height

    // OverlayWindowの位置とサイズを設定
    overlayWindow.setFrameOrigin(origin)
    overlayWindow.setContentSize(rect.size)

    // OverlayWindowを前面に表示
    overlayWindow.orderFront(nil)

    // InspectorWindowにAXUIElementの情報を表示
    inspectorWindow.elementTitle = title(of: element)
    inspectorWindow.attributedText = inspect(element: element)
  }

  private func waitPermisionGranted(completion: @escaping () -> Void) {
    // 0.3秒後に権限チェックを行い、権限がある場合はcompletion()を呼び出す
    // 権限がない場合は再度waitPermisionGranted()を呼び出す
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
      if AXIsProcessTrusted() {
        completion()
      } else {
        self.waitPermisionGranted(completion: completion)
      }
    }
  }
}
