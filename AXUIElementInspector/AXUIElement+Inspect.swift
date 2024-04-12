import Cocoa

func inspect(element: AXUIElement, level: Int = 0) -> NSAttributedString {
  let description = NSMutableAttributedString()

  var roleValue: AnyObject?
  // AXUIElementのrole属性を取得
  let roleValueError = AXUIElementCopyAttributeValue(
    element,
    kAXRoleAttribute as CFString,
    &roleValue
  )
  if let roleValue, roleValueError == .success {
    // roleの値を太字のモノスペースフォントで表示
    description.append(
      NSAttributedString(
        string: "\(String(repeating: " ", count: level * 2))\(roleValue)\n",
        attributes: [.font: NSFont.monospacedSystemFont(ofSize: 11, weight: .bold)]
      )
    )
  }

  var attributeNames = CFArrayCreate(nil, nil, 0, nil)
  // AXUIElementの属性名一覧を取得
  AXUIElementCopyAttributeNames(element, &attributeNames)

  if let attributeNames = attributeNames as? [String] {
    for attributeName in attributeNames {
      var attributeValue: AnyObject?

      // 各属性の値を取得
      let attributeValueError = AXUIElementCopyAttributeValue(
        element,
        attributeName as CFString,
        &attributeValue
      )
      if attributeValueError == .success {
        // 属性名を太字のモノスペースフォントで表示
        description.append(
          NSAttributedString(
            string: "\(String(repeating: " ", count: (level + 1) * 2))\(attributeName): ",
            attributes: [.font: NSFont.monospacedSystemFont(ofSize: 11, weight: .bold)]
          )
        )

        let value = attributeValue as! AXValue
        // 属性値の型に応じて表示方法を切り替える
        if AXValueGetType(value) == .cgPoint {
          var p = CGPoint()
          AXValueGetValue(value, .cgPoint, &p)
          description.append(
            NSAttributedString(
              string: "\(NSStringFromPoint(p))\n",
              attributes: [.font: NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)]
            )
          )
        } else if AXValueGetType(value) == .cgSize {
          var s = CGSize()
          AXValueGetValue(value, .cgSize, &s)
          description.append(
            NSAttributedString(
              string: "\(NSStringFromSize(s))\n",
              attributes: [.font: NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)]
            )
          )
        } else if AXValueGetType(value) == .cgRect {
          var r = CGRect()
          AXValueGetValue(value, .cgRect, &r)
          description.append(
            NSAttributedString(
              string: "\(NSStringFromRect(r))\n",
              attributes: [.font: NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)]
            )
          )
        } else if AXValueGetType(value) == .cfRange {
          var r = CFRange()
          AXValueGetValue(value, .cfRange, &r)
          description.append(
            NSAttributedString(
              string: "\(NSStringFromRange(NSRange(location: r.location, length: r.length)))\n",
              attributes: [.font: NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)]
            )
          )
        } else {
          if attributeName == "AXValue" {
            description.append(
              NSAttributedString(
                string: "...\n",
                attributes: [.font: NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)]
              )
            )
          } else {
            if attributeName == kAXParentAttribute {
              var parentValue: AnyObject?
              // 親要素のAXUIElementを取得
              let parentValueError = AXUIElementCopyAttributeValue(
                element,
                kAXParentAttribute as CFString,
                &parentValue
              )
              if let parentValue, parentValueError == .success {
                var roleValue: AnyObject?
                // 親要素のrole属性を取得
                let roleValueError = AXUIElementCopyAttributeValue(
                  parentValue as! AXUIElement,
                  kAXRoleAttribute as CFString,
                  &roleValue
                )
                if let roleValue, roleValueError == .success {
                  description.append(
                    NSAttributedString(
                      string: "\(roleValue)\n",
                      attributes: [.font: NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)]
                    )
                  )
                }
              }
            } else if attributeName == kAXTopLevelUIElementAttribute {
              var topLevelUIElementValue: AnyObject?
              // トップレベルのAXUIElementを取得
              let topLevelUIElementValueError = AXUIElementCopyAttributeValue(
                element,
                kAXTopLevelUIElementAttribute as CFString,
                &topLevelUIElementValue
              )
              if let topLevelUIElementValue, topLevelUIElementValueError == .success {
                var roleValue: AnyObject?
                // トップレベル要素のrole属性を取得
                let roleValueError = AXUIElementCopyAttributeValue(
                  topLevelUIElementValue as! AXUIElement,
                  kAXRoleAttribute as CFString,
                  &roleValue
                )
                if let roleValue, roleValueError == .success {
                  description.append(
                    NSAttributedString(
                      string: "\(roleValue)\n",
                      attributes: [.font: NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)]
                    )
                  )
                }
              }
            } else {
              if let children = attributeValue as? [AXUIElement] {
                // 子要素の配列からrole属性の値を取得し、表示
                let roles = children.compactMap { (child) in
                  var roleValue: AnyObject?
                  let roleValueError = AXUIElementCopyAttributeValue(
                    child,
                    kAXRoleAttribute as CFString,
                    &roleValue
                  )
                  if let roleValue, roleValueError == .success {
                    return roleValue
                  } else {
                    return nil
                  }
                }
                description.append(
                  NSAttributedString(
                    string: "\(roles)\n",
                    attributes: [.font: NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)]
                  )
                )
                if level < 1 {
                  // レベルが1未満の場合、再帰的に子要素を探索
                  for child in children {
                    let subDescription = inspect(element: child, level: level + 2)
                    description.append(subDescription)
                  }
                }
              } else {
                description.append(
                  NSAttributedString(
                    string: "\(value)\n",
                    attributes: [.font: NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)]
                  )
                )
              }
            }
          }
        }
      }
    }
  }

  return description
}

func title(of element: AXUIElement) -> String {
  var components = [String]()

  var titleValue: AnyObject?
  // AXUIElementのtitle属性を取得
  let titleValueError = AXUIElementCopyAttributeValue(
    element,
    kAXTitleAttribute as CFString,
    &titleValue
  )
  if let titleValue, titleValueError == .success {
    let title = "\(titleValue)"
    if !title.isEmpty {
      components.append(title)
    }
  }

  var descriptionValue: AnyObject?
  // AXUIElementのdescription属性を取得
  let descriptionValueError = AXUIElementCopyAttributeValue(
    element,
    kAXDescription as CFString,
    &descriptionValue
  )
  if let descriptionValue, descriptionValueError == .success {
    let description = "\(descriptionValue)"
    if !description.isEmpty {
      components.append(description)
    }
  }

  var roleDescriptionValue: AnyObject?
  // AXUIElementのroleDescription属性を取得
  let roleDescriptionValueError = AXUIElementCopyAttributeValue(
    element,
    kAXRoleDescriptionAttribute as CFString,
    &roleDescriptionValue
  )
  if let roleDescriptionValue, roleDescriptionValueError == .success {
    let roleDescription = "\(roleDescriptionValue)"
    if !roleDescription.isEmpty {
      components.append(roleDescription)
    }
  }

  // title, description, roleDescriptionを", "で連結して返す
  return components.joined(separator: ", ")
}
