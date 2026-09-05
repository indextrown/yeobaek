import RxLab
import SwiftUI

@main
struct RxLabDemoApp: App {
    var body: some Scene {
        WindowGroup {
            RxLabCounterView()
                .ignoresSafeArea()
        }
    }
}
