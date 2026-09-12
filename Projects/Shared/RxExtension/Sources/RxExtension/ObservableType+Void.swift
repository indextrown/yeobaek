import ThirdParty

public extension ObservableType {
    /// 모든 Element를 `Void`로 변환합니다.
    ///
    /// - Returns: 원본 값은 버리고 이벤트 발생 시점만 유지한 Observable입니다.
    func mapToVoid() -> Observable<Void> {
        map { _ in () }
    }
}
