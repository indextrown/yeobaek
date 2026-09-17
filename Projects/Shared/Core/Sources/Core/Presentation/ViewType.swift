import UIKit

/// 표시 데이터를 받아 스스로 화면을 갱신하는 UIKit View의 공통 계약입니다.
///
/// `UIView` 제약 덕분에 ViewController가 `loadView()`에서 주입받은 화면을
/// 자신의 `view`로 설치할 수 있습니다. 프로토콜이 View를 대신 생성하지는 않습니다.
public protocol ViewType: UIView {
    /// 화면마다 다르게 정의하는 표시 데이터 타입입니다.
    associatedtype ViewData

    /// 전달받은 표시 데이터를 화면에 반영합니다.
    ///
    /// 표시만 갱신하고 입력 이벤트를 다시 발생시키지 않습니다.
    ///
    /// - Parameter data: 화면에 표시할 값입니다.
    func render(
        _ data: ViewData
    )
}
