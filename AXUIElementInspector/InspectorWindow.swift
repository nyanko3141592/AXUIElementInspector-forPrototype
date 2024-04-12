import AppKit


class InspectorWindow: NSPanel {
    
    var activeApplicationName: String = "" {
       didSet {
         activeApplicationNameLabel.stringValue = activeApplicationName
       }
     }
    
  var elementTitle: String {
    get {
      elementTitleLabel.stringValue
    }
    set {
      elementTitleLabel.stringValue = newValue
    }
  }

  var text: String {
    get {
      documentView.string
    }
    set {
      documentView.string = newValue
    }
  }

  var attributedText: NSAttributedString {
    get {
      documentView.attributedString()
    }
    set {
      documentView.textStorage?.setAttributedString(newValue)
    }
  }

  var isInspectingEnabled: Bool = false {
    didSet {
      // インスペクトボタンの状態をisInspectingEnabledに応じて更新
      inspectButton.state = isInspectingEnabled ? .on : .off
    }
  }

  var inspectButtonClicked: () -> () = {}

  // インスペクト対象の要素セクションのラベル
  private let inspectedElementSectionLabel = NSTextField(labelWithString: "Inspected Element:")
  // インスペクト対象の要素のタイトルラベル
  private let elementTitleLabel = NSTextField(labelWithString: "")
  // インスペクトボタン
  private let inspectButton = NSButton(image: NSImage(named: "crosshair")!, target: nil, action: nil)

  // スクロール可能なテキストビュー
  private let textView = NSTextView.scrollableTextView()
  // テキストビューのドキュメントビュー
  private var documentView: NSTextView {
    textView.documentView as! NSTextView
  }

    
    private let activeApplicationNameLabel = NSTextField(labelWithString: "")
    
  init() {
    super.init(
      contentRect: .zero,
      styleMask: [.titled, .closable, .resizable, .utilityWindow, .nonactivatingPanel],
      backing: .buffered,
      defer: false
    )

    // フローティングパネルに設定
    isFloatingPanel = true
    level = .floating

    // フルスクリーン時にパネルを表示するように設定
    collectionBehavior.insert(.fullScreenAuxiliary)

    let rootView = NSView()
    contentView = rootView

    // インスペクト対象の要素セクションのラベルを設定
    inspectedElementSectionLabel.translatesAutoresizingMaskIntoConstraints = false
    inspectedElementSectionLabel.font = NSFont.controlContentFont(ofSize: 12)
    inspectedElementSectionLabel.textColor = NSColor.secondaryLabelColor
    rootView.addSubview(inspectedElementSectionLabel)

    // インスペクト対象の要素のタイトルラベルを設定
    elementTitleLabel.translatesAutoresizingMaskIntoConstraints = false
    elementTitleLabel.font = NSFont.boldSystemFont(ofSize: 12)
    rootView.addSubview(elementTitleLabel)

    // インスペクトボタンを設定
    inspectButton.translatesAutoresizingMaskIntoConstraints = false
    inspectButton.setContentHuggingPriority(.required, for: .horizontal)
    inspectButton.bezelStyle = .flexiblePush
    inspectButton.imageScaling = .scaleNone
    inspectButton.setButtonType(.onOff)

    inspectButton.target = self
    inspectButton.action = #selector(inspectButtonAction)

    rootView.addSubview(inspectButton)

    // セパレーターを作成
    let separator = NSBox()
    separator.translatesAutoresizingMaskIntoConstraints = false
    separator.boxType = .separator
    rootView.addSubview(separator)

    // テキストビューを設定
    textView.translatesAutoresizingMaskIntoConstraints = false
    textView.scrollerStyle = .overlay

    documentView.drawsBackground = false
    documentView.isEditable = false
    documentView.isSelectable = true
    documentView.textContainerInset = NSSize(width: 8, height: 0)
    documentView.textContainer?.widthTracksTextView = false

    rootView.addSubview(textView)
      
      activeApplicationNameLabel.translatesAutoresizingMaskIntoConstraints = false
        activeApplicationNameLabel.font = NSFont.systemFont(ofSize: 12)
        activeApplicationNameLabel.textColor = NSColor.secondaryLabelColor
        rootView.addSubview(activeApplicationNameLabel)
        
        NSLayoutConstraint.activate([
          activeApplicationNameLabel.topAnchor.constraint(equalTo: inspectedElementSectionLabel.topAnchor),
          activeApplicationNameLabel.trailingAnchor.constraint(equalTo: inspectButton.leadingAnchor, constant: -12),
        ])
    // Auto Layoutを設定
    NSLayoutConstraint.activate([
      inspectedElementSectionLabel.topAnchor.constraint(equalTo: rootView.topAnchor, constant: 12),
      inspectedElementSectionLabel.leadingAnchor.constraint(equalTo: rootView.leadingAnchor, constant: 12),
      inspectedElementSectionLabel.trailingAnchor.constraint(equalTo: inspectButton.leadingAnchor, constant: -12),

      elementTitleLabel.topAnchor.constraint(equalTo: inspectedElementSectionLabel.bottomAnchor, constant: 2),
      elementTitleLabel.leadingAnchor.constraint(equalTo: rootView.leadingAnchor, constant: 12),
      elementTitleLabel.trailingAnchor.constraint(equalTo: inspectButton.leadingAnchor, constant: -8),

      inspectButton.topAnchor.constraint(equalTo: rootView.topAnchor, constant: 12),
      inspectButton.trailingAnchor.constraint(equalTo: rootView.trailingAnchor, constant: -12),
      inspectButton.widthAnchor.constraint(equalToConstant: 32),
      inspectButton.heightAnchor.constraint(equalToConstant: 30),

      separator.topAnchor.constraint(equalTo: elementTitleLabel.bottomAnchor, constant: 12),
      separator.leadingAnchor.constraint(equalTo: rootView.leadingAnchor, constant: 12),
      separator.trailingAnchor.constraint(equalTo: rootView.trailingAnchor, constant: -12),

      textView.topAnchor.constraint(equalTo: separator.bottomAnchor, constant: 10),
      textView.leadingAnchor.constraint(equalTo: rootView.leadingAnchor, constant: 0),
      textView.trailingAnchor.constraint(equalTo: rootView.trailingAnchor, constant: 0),
      textView.bottomAnchor.constraint(equalTo: rootView.bottomAnchor, constant: 0),
    ])
  }

  override var canBecomeKey: Bool {
    return true
  }

  override var canBecomeMain: Bool {
    return true
  }

  @objc
  func inspectButtonAction() {
    // インスペクトボタンがクリックされた時の処理を呼び出す
    inspectButtonClicked()
  }
}
