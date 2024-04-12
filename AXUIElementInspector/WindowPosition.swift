import AppKit

extension NSWindow {
    struct Position {
        static let defaultPadding: CGFloat = 16

        var vertical: Vertical
        var horizontal: Horizontal
        var padding = Self.defaultPadding
    }
}

extension NSWindow.Position {
    enum Horizontal {
        case left, center, right
    }

    enum Vertical {
        case top, center, bottom
    }
}

extension NSWindow.Position {
    func value(forWindow windowRect: CGRect, inScreen screenRect: CGRect) -> CGPoint {
        // 画面の幅に対するウィンドウの水平位置を計算
        let xPosition = horizontal.valueFor(
            screenRange: screenRect.minX..<screenRect.maxX,
            width: windowRect.width,
            padding: padding
        )

        // 画面の高さに対するウィンドウの垂直位置を計算
        let yPosition = vertical.valueFor(
            screenRange: screenRect.minY..<screenRect.maxY,
            height: windowRect.height,
            padding: padding
        )

        return CGPoint(x: xPosition, y: yPosition)
    }
}

extension NSWindow.Position.Horizontal {
    func valueFor(
        screenRange: Range<CGFloat>,
        width: CGFloat,
        padding: CGFloat
    )
        -> CGFloat
    {
        switch self {
        case .left: return screenRange.lowerBound + padding
        case .center: return (screenRange.upperBound + screenRange.lowerBound - width) / 2
        case .right: return screenRange.upperBound - width - padding
        }
    }
}

extension NSWindow.Position.Vertical {
    func valueFor(
        screenRange: Range<CGFloat>,
        height: CGFloat,
        padding: CGFloat
    )
        -> CGFloat
    {
        switch self {
        case .top: return screenRange.upperBound - height - padding
        case .center: return (screenRange.upperBound + screenRange.lowerBound - height) / 2
        case .bottom: return screenRange.lowerBound + padding
        }
    }
}

extension NSWindow {
    func setPosition(_ position: Position, in screen: NSScreen?) {
        // 指定されたスクリーンの表示可能な領域を取得
        guard let visibleFrame = (screen ?? self.screen)?.visibleFrame else { return }
        // ウィンドウの位置を計算
        let origin = position.value(forWindow: frame, inScreen: visibleFrame)
        // ウィンドウの位置を設定
        setFrameOrigin(origin)
    }

    func setPosition(
        vertical: Position.Vertical,
        horizontal: Position.Horizontal,
        padding: CGFloat = Position.defaultPadding,
        screen: NSScreen? = nil
    ) {
        // 垂直位置、水平位置、パディング、スクリーンを指定してウィンドウの位置を設定
        setPosition(
            Position(vertical: vertical, horizontal: horizontal, padding: padding),
            in: screen
        )
    }
}
