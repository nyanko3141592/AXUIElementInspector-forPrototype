import AppKit

class OverlayWindow: NSPanel {
  init() {
    super.init(
      contentRect: .zero,
      styleMask: [.closable, .fullSizeContentView, .nonactivatingPanel],
      backing: .buffered,
      defer: false
    )

    // ウィンドウをフローティングパネルに設定
    isFloatingPanel = true
    level = .floating

    // フルスクリーン時にウィンドウを表示するように設定
    collectionBehavior.insert(.fullScreenAuxiliary)

    // タイトルバーを非表示に設定
    titleVisibility = .hidden
    titlebarAppearsTransparent = true

    // ウィンドウ背景でのドラッグ移動を無効化
    isMovableByWindowBackground = false

    // ウィンドウを閉じてもメモリから解放されないように設定
    isReleasedWhenClosed = false

    // ウィンドウが非アクティブになっても非表示にしないように設定
    hidesOnDeactivate = false

    // 標準のウィンドウボタンを非表示に設定
    standardWindowButton(.closeButton)?.isHidden = true
    standardWindowButton(.miniaturizeButton)?.isHidden = true
    standardWindowButton(.zoomButton)?.isHidden = true

    // マウスイベントを無視するように設定
    ignoresMouseEvents = true

    // ウィンドウを透明に設定
    isOpaque = false
    backgroundColor = .clear

    // カスタムコンテンツビューを設定
    contentView = OverlayContentView()
  }

  override var canBecomeKey: Bool {
    return false
  }

  override var canBecomeMain: Bool {
    return false
  }
}

class OverlayContentView: NSView {
  override func draw(_ dirtyRect: NSRect) {
    super.draw(dirtyRect)

    // 背景色を半透明の青に設定
    let backgroundColor = NSColor(red: 0.7, green: 0.85, blue: 1, alpha: 0.5)
    backgroundColor.setFill()
    dirtyRect.fill()

    // 枠線の色を設定
    let borderColor = NSColor(red: 0, green: 0.53, blue: 0.87, alpha: 1)
    // 枠線のパスを作成
    let borderPath = NSBezierPath(rect: dirtyRect)
    // 枠線の太さを設定
    borderPath.lineWidth = 2
    // 枠線の色を設定
    borderColor.setStroke()
    // 枠線を描画
    borderPath.stroke()
  }
}
