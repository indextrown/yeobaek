import SwiftUI

/// UIKit으로 만든 RxLab 카운터를 SwiftUI Demo에서 실행할 수 있게 감쌉니다.
@MainActor
public struct RxLabCounterView: UIViewControllerRepresentable {
    public init() {}

    /// UIKit 카운터 ViewController를 만듭니다.
    ///
    /// - Parameter context: SwiftUI가 전달하는 ViewController 생성 문맥입니다.
    /// - Returns: Input/Output MVVM 카운터를 표시하는 ViewController입니다.
    public func makeUIViewController(
        context: Context
    ) -> RxLabCounterViewController {
        RxLabCounterViewController()
    }

    /// SwiftUI 상태 갱신 시 UIKit 화면에 추가로 반영할 값은 없습니다.
    ///
    /// - Parameters:
    ///   - uiViewController: 현재 표시 중인 카운터 ViewController입니다.
    ///   - context: SwiftUI가 전달하는 ViewController 갱신 문맥입니다.
    public func updateUIViewController(
        _ uiViewController: RxLabCounterViewController,
        context: Context
    ) {}
}
