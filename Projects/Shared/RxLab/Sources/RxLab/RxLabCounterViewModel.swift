import ThirdParty

/// 카운터 입력을 화면 상태로 변환하는 Input/Output MVVM 예제입니다.
public final class RxLabCounterViewModel {
    /// ViewController가 ViewModel에 전달하는 사용자 입력입니다.
    public struct Input {
        /// 감소 버튼을 누른 이벤트입니다.
        public let decrementTapped: Observable<Void>

        /// 초기화 버튼을 누른 이벤트입니다.
        public let resetTapped: Observable<Void>

        /// 증가 버튼을 누른 이벤트입니다.
        public let incrementTapped: Observable<Void>

        /// 카운터를 조작하는 사용자 입력 스트림을 만듭니다.
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

    /// ViewController가 화면에 연결하는 상태 출력입니다.
    public struct Output {
        /// 화면에 표시할 카운터 문자열입니다.
        public let countText: Driver<String>

        /// 감소 버튼을 사용할 수 있는지 나타냅니다.
        public let isDecrementEnabled: Driver<Bool>

        /// 초기화 버튼을 사용할 수 있는지 나타냅니다.
        public let isResetEnabled: Driver<Bool>
    }

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

    /// 버튼 입력을 카운터 문자열과 버튼 활성화 상태로 변환합니다.
    ///
    /// - Parameter input: 감소, 초기화, 증가 버튼의 입력 스트림입니다.
    /// - Returns: 화면이 `drive`로 연결할 카운터 상태입니다.
    public func transform(
        input: Input
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
        let countDriver = count.asDriver(onErrorJustReturn: initialCount)

        return Output(
            countText: countDriver.map { String($0) },
            isDecrementEnabled: countDriver.map { $0 > 0 },
            isResetEnabled: countDriver.map { $0 != initialCount }
        )
    }
}
