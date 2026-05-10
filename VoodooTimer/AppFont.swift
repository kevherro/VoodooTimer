//  VoodooTimer is owned by Kevin Herro.

import CoreText
import Foundation
import SwiftUI

enum AppFont {
  static func medium(_ size: CGFloat) -> Font {
    .custom("BerkeleyMono-Medium", size: size)
  }

  static func semiBold(_ size: CGFloat) -> Font {
    .custom("BerkeleyMono-SemiBold", size: size)
  }
}

enum FontRegistrar {
  private static let fontNames = [
    "BerkeleyMono-Regular",
    "BerkeleyMono-Medium",
    "BerkeleyMono-SemiBold",
  ]

  static func registerBerkeleyMono() {
    for name in fontNames {
      registerFont(named: name)
    }
  }

  private static func registerFont(named name: String) {
    let url =
      Bundle.main.url(forResource: name, withExtension: "ttf")
      ?? Bundle.main.url(
        forResource: name, withExtension: "ttf", subdirectory: "Fonts")

    guard let url else { return }

    var error: Unmanaged<CFError>?
    CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
  }
}
