import Foundation

/// 앱이 그릴 화면 구현입니다. 같은 화면을 SwiftUI 버전과 UIKit 버전으로 각각 만들어 두고 하나를 고릅니다.
enum UIImplementation: String {
    /// SwiftUI + TCA 버전입니다. 기본값입니다.
    case swiftUI = "swiftui"

    /// UIKit + RxSwift 버전입니다. App 루트에서 `UIViewControllerRepresentable`로 감싸 끼웁니다.
    case uiKit = "uikit"

    /// 실행할 구현을 고릅니다.
    ///
    /// 디버그 빌드에서는 실행 환경 변수 `UI_IMPLEMENTATION`이 빌드 설정보다 우선합니다.
    ///
    /// - Parameters:
    ///   - environment: 실행 환경 변수입니다.
    ///   - bundle: `UIImplementation` 빌드 설정을 읽을 실행 Bundle입니다.
    /// - Returns: 고른 구현이며, 값이 없거나 알 수 없으면 SwiftUI 버전입니다.
    static func resolve(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        bundle: Bundle = .main
    ) -> UIImplementation {
#if DEBUG
        if let override = environment["UI_IMPLEMENTATION"].flatMap({ UIImplementation(rawValue: $0.lowercased()) }) {
            return override
        }
#endif
        let configured = (bundle.object(forInfoDictionaryKey: "UIImplementation") as? String)?.lowercased()
        return configured.flatMap(UIImplementation.init(rawValue:)) ?? .swiftUI
    }
}
