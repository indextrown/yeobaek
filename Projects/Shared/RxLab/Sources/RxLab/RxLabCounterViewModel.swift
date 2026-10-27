import ThirdParty

/// 카운터 입력을 화면 표시 데이터로 변환하는 Input/Output MVVM 예제입니다.
public final class RxLabCounterViewModel: RxLabCounterViewModelProtocol {
    /// ViewController가 전달하는 사용자 입력입니다.
    public typealias Input = RxLabCounterInput

    /// ViewController가 View에 전달하는 화면 출력입니다.
    public typealias Output = RxLabCounterOutput

    /// 카운터 값을 바꾸는 사용자 동작입니다.
    private enum Action {
        case decrement
        case reset
        case increment
    }

    /// 카운터가 시작하고 초기화될 기준값입니다.
    private let initialCount: Int

    /// 지정한 초기값으로 카운터 ViewModel을 만듭니다.
    ///
    /// - Parameter initialCount: 카운터가 시작하고 초기화될 값입니다. 음수는 0으로 바꿉니다.
    public init(
        initialCount: Int = 0
    ) {
        self.initialCount = max(0, initialCount)
    }

    /// 버튼 입력을 카운터 표시 데이터로 변환합니다.
    ///
    /// - Parameters:
    ///   - input: 감소, 초기화, 증가 버튼의 입력 스트림입니다.
    ///   - disposeBag: 화면 밖에서 직접 구독하는 동작이 없어 사용하지 않습니다.
    /// - Returns: 화면이 `drive`로 연결할 카운터 표시 데이터입니다.
    public func transform(
        input: Input,
        disposeBag: DisposeBag
    ) -> Output {
        let initialCount = self.initialCount
        let actions = Observable.merge(
            input.decrementTapped.map { Action.decrement },
            input.resetTapped.map { Action.reset },
            input.incrementTapped.map { Action.increment }
        )
        let count = actions
            .scan(initialCount) { currentCount, action in
                switch action {
                case .decrement:
                    return max(0, currentCount - 1)
                case .reset:
                    return initialCount
                case .increment:
                    return currentCount + 1
                }
            }
            .startWith(initialCount)
            .distinctUntilChanged()
            .share(replay: 1, scope: .whileConnected)

        let viewData = count
            .map { count in
                RxLabCounterViewData(
                    countText: String(count),
                    isDecrementEnabled: count > 0,
                    isResetEnabled: count != initialCount
                )
            }
            .asDriver(
                onErrorJustReturn: RxLabCounterViewData(
                    countText: String(initialCount),
                    isDecrementEnabled: initialCount > 0,
                    isResetEnabled: false
                )
            )

        return Output(viewData: viewData)
    }
}
