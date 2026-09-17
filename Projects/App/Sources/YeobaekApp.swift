import SwiftUI

@main
struct YeobaekApp: App {
    /// 앱 실행 동안 하나만 유지하는 전역 의존성 컨테이너입니다.
    @State private var container = AppDIContainer()

    var body: some Scene {
        WindowGroup {
            AppRootView(container: container)
        }
    }
}
