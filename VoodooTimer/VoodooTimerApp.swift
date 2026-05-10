//  VoodooTimer is owned by Kevin Herro.

import SwiftUI

@main
struct VoodooTimerApp: App {
  init() {
    FontRegistrar.registerBerkeleyMono()
  }

  var body: some Scene {
    WindowGroup {
      ContentView()
    }
  }
}
