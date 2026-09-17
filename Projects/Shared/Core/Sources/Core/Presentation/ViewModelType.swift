import ThirdParty

/// 화면 입력을 출력 스트림으로 변환하는 ViewModel의 공통 계약입니다.
///
/// `transform`은 전달받은 `DisposeBag`에 구독을 추가할 뿐 스스로 해제하지 않습니다.
/// 따라서 **ViewController 하나당 정확히 한 번만** 호출해야 합니다. 같은 Bag에
/// 두 번 호출하면 구독이 누적되어 요청이 중복 실행됩니다. 화면을 다시 만들 때는
/// ViewController와 함께 Bag도 새로 생성되므로 구독이 쌓이지 않습니다.
@MainActor
public protocol ViewModelType {
    /// ViewController가 전달하는 입력 스트림 묶음입니다.
    associatedtype Input

    /// ViewController가 구독해 화면에 반영하는 출력 스트림 묶음입니다.
    associatedtype Output

    /// 화면 입력을 출력 상태로 변환합니다.
    ///
    /// - Parameters:
    ///   - input: 화면에서 전달한 입력 스트림입니다.
    ///   - disposeBag: ViewModel이 직접 구독하는 동작의 수명을 관리할 Bag입니다.
    /// - Returns: 화면에서 구독할 출력 스트림입니다.
    func transform(
        input: Input,
        disposeBag: DisposeBag
    ) -> Output
}
