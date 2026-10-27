import Core
import ThirdParty

/// 카운터 화면이 표시할 값만 담은 표시 데이터입니다.
///
/// UIKit 객체나 Repository를 담지 않습니다. 문자열과 버튼 활성화 판단은
/// ViewModel에서 끝내고 View는 전달받은 값을 그대로 표시합니다.
public struct RxLabCounterViewData: Equatable {
    /// 카운터 값을 표시할 문구입니다.
    public let countText: String

    /// 감소 버튼을 사용할 수 있는지 나타냅니다.
    public let isDecrementEnabled: Bool

    /// 초기화 버튼을 사용할 수 있는지 나타냅니다.
    public let isResetEnabled: Bool

    /// 카운터 화면에 표시할 값을 묶습니다.
    ///
    /// - Parameters:
    ///   - countText: 카운터 값을 표시할 문구입니다.
    ///   - isDecrementEnabled: 감소 버튼을 사용할 수 있으면 `true`입니다.
    ///   - isResetEnabled: 초기화 버튼을 사용할 수 있으면 `true`입니다.
    public init(
        countText: String,
        isDecrementEnabled: Bool,
        isResetEnabled: Bool
    ) {
        self.countText = countText
        self.isDecrementEnabled = isDecrementEnabled
        self.isResetEnabled = isResetEnabled
    }
}

/// 카운터 화면 View가 공개하는 입력 이벤트와 표시 데이터 타입을 고정합니다.
///
/// `UIButton`이나 `UILabel`을 노출하지 않으므로 ViewController는 내부 레이아웃을
/// 몰라도 됩니다. 같은 계약을 구현하면 레이아웃만 다른 View로 교체할 수 있습니다.
public protocol RxLabCounterViewProtocol: ViewType where ViewData == RxLabCounterViewData {
    /// 감소 버튼을 누른 이벤트입니다.
    var decrementTapped: Observable<Void> { get }

    /// 초기화 버튼을 누른 이벤트입니다.
    var resetTapped: Observable<Void> { get }

    /// 증가 버튼을 누른 이벤트입니다.
    var incrementTapped: Observable<Void> { get }
}

/// ViewController가 ViewModel에 전달하는 카운터 입력입니다.
public struct RxLabCounterInput {
    /// 감소 버튼을 누른 이벤트입니다.
    public let decrementTapped: Observable<Void>

    /// 초기화 버튼을 누른 이벤트입니다.
    public let resetTapped: Observable<Void>

    /// 증가 버튼을 누른 이벤트입니다.
    public let incrementTapped: Observable<Void>

    /// 카운터를 조작하는 사용자 입력 스트림을 묶습니다.
    ///
    /// - Parameters:
    ///   - decrementTapped: 감소 버튼을 누른 이벤트입니다.
    ///   - resetTapped: 초기화 버튼을 누른 이벤트입니다.
    ///   - incrementTapped: 증가 버튼을 누른 이벤트입니다.
    public init(
        decrementTapped: Observable<Void>,
        resetTapped: Observable<Void>,
        incrementTapped: Observable<Void>
    ) {
        self.decrementTapped = decrementTapped
        self.resetTapped = resetTapped
        self.incrementTapped = incrementTapped
    }
}

/// ViewController가 구독해 View에 전달하는 카운터 출력입니다.
public struct RxLabCounterOutput {
    /// 화면에 표시할 카운터 상태입니다.
    public let viewData: Driver<RxLabCounterViewData>

    /// 화면이 구독할 출력 스트림을 묶습니다.
    ///
    /// - Parameter viewData: 화면에 표시할 카운터 상태입니다.
    public init(
        viewData: Driver<RxLabCounterViewData>
    ) {
        self.viewData = viewData
    }
}

/// 카운터 ViewModel의 Input과 Output 타입을 고정합니다.
///
/// 이 계약이 있어야 ViewController가 `any RxLabCounterViewModelProtocol`을 통해
/// `transform`을 호출할 수 있습니다.
public protocol RxLabCounterViewModelProtocol: ViewModelType
where Input == RxLabCounterInput, Output == RxLabCounterOutput {}
