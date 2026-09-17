import Core
import Domain
import RxCocoa
import RxRelay
import RxSwift

/// 지도 SDK에 의존하지 않는 지역별 표시 데이터입니다.
public struct MapBoxCrowdArea: Equatable, Sendable {
    /// 장소 코드로 혼잡도와 연결한 영역입니다.
    public let geometry: AreaGeometry

    /// 조회에 실패하거나 정보가 없으면 `.unknown`입니다.
    public let level: CongestionLevel

    /// 경계와 혼잡도를 한 쌍으로 묶습니다.
    ///
    /// - Parameters:
    ///   - geometry: 장소 코드와 닫힌 폴리곤을 포함하는 영역입니다.
    ///   - level: 해당 장소의 혼잡도이며, 알 수 없으면 `.unknown`입니다.
    public init(
        geometry: AreaGeometry,
        level: CongestionLevel
    ) {
        self.geometry = geometry
        self.level = level
    }
}

/// 범례와 지도에 함께 반영할 최신 혼잡도 상태입니다.
public struct MapBoxCrowdState: Equatable, Sendable {
    /// 표시할 경계와 혼잡도입니다. 조회 전에도 경계는 유지합니다.
    public let areas: [MapBoxCrowdArea]

    /// 혼잡도 조회가 진행 중인지 나타냅니다.
    public let isLoading: Bool

    /// 조회 실패 또는 장소 코드 불일치로 표시하지 못한 정보의 수입니다.
    public let unavailableCount: Int

    /// 화면에 함께 반영할 혼잡도 상태를 묶습니다.
    ///
    /// - Parameters:
    ///   - areas: 표시할 경계와 장소별 혼잡도입니다.
    ///   - isLoading: 혼잡도 조회가 진행 중이면 `true`입니다.
    ///   - unavailableCount: 표시하지 못한 정보의 수입니다.
    public init(
        areas: [MapBoxCrowdArea],
        isLoading: Bool,
        unavailableCount: Int
    ) {
        self.areas = areas
        self.isLoading = isLoading
        self.unavailableCount = unavailableCount
    }
}

/// 위치 자동 요청 여부와 무관하게 전달받는 화면 생명주기입니다.
public struct MapBoxCrowdInput {
    /// 화면이 표시될 때 미완료 조회를 시작하거나 재시도합니다.
    public let viewDidAppear: Observable<Void>

    /// 화면이 사라지면 진행 중인 조회를 취소합니다.
    public let viewDidDisappear: Observable<Void>

    /// 혼잡도 조회 수명을 제어할 화면 이벤트를 저장합니다.
    ///
    /// - Parameters:
    ///   - viewDidAppear: 최초 등장과 지도 전환 후 재등장을 포함한 이벤트입니다.
    ///   - viewDidDisappear: 지도 전환 등으로 화면이 사라지는 이벤트입니다.
    public init(
        viewDidAppear: Observable<Void>,
        viewDidDisappear: Observable<Void>
    ) {
        self.viewDidAppear = viewDidAppear
        self.viewDidDisappear = viewDidDisappear
    }
}

/// 화면에서 메인 스레드로 구독하는 혼잡도 출력입니다.
public struct MapBoxCrowdOutput {
    /// 새 화면에도 마지막 경계와 혼잡도 상태를 전달합니다.
    public let state: Driver<MapBoxCrowdState>

    /// 화면이 구독할 출력 스트림을 묶습니다.
    ///
    /// - Parameter state: 경계와 혼잡도를 전달하는 스트림입니다.
    public init(
        state: Driver<MapBoxCrowdState>
    ) {
        self.state = state
    }
}

/// 혼잡도 ViewModel의 Input, Output과 목업 표시 정책을 고정합니다.
public protocol MapBoxCrowdViewModelProtocol: ViewModelType
where Input == MapBoxCrowdInput, Output == MapBoxCrowdOutput {
    /// 실제 관측값이 아닌 테스트 데이터이면 `true`입니다.
    var isMockData: Bool { get }
}

/// 위치 조회와 독립적으로 장소 경계와 혼잡도를 연결하는 화면 모델입니다.
public final class MapBoxCrowdViewModel: MapBoxCrowdViewModelProtocol {
    /// 화면 생명주기 입력입니다.
    public typealias Input = MapBoxCrowdInput

    /// 경계와 혼잡도를 전달하는 화면 출력입니다.
    public typealias Output = MapBoxCrowdOutput

    /// 기존 호출부를 유지하기 위한 지역 표시 데이터 별칭입니다.
    public typealias Area = MapBoxCrowdArea

    /// 기존 호출부를 유지하기 위한 혼잡도 상태 별칭입니다.
    public typealias State = MapBoxCrowdState

    /// 실제 관측값과 목업을 화면에서 구분하기 위한 표시 정책입니다.
    public let isMockData: Bool

    /// 앱 조립 계층에서 전달한 장소 경계입니다.
    private let areas: [AreaGeometry]

    /// 구체적인 API나 목업 구현을 알지 못하는 조회 경계입니다.
    private let repository: any CrowdRepository

    /// 지도 전환 후에도 마지막 표시 결과를 보관합니다.
    private let stateRelay: BehaviorRelay<MapBoxCrowdState>

    /// 화면 종료 시 취소할 비동기 조회입니다.
    private var loadTask: Task<Void, Never>?

    /// 성공한 목업 데이터를 화면 전환마다 다시 조회하지 않도록 기록합니다.
    private var didLoad = false

    /// 장소 경계와 교체 가능한 혼잡도 저장소를 주입합니다.
    ///
    /// - Parameters:
    ///   - areas: 고유 장소 코드와 닫힌 폴리곤을 포함하는 목록입니다.
    ///   - repository: 각 장소의 혼잡도를 Domain Entity로 반환하는 저장소입니다.
    ///   - isMockData: 실제 경계나 관측값이 아닌 테스트 데이터이면 `true`입니다.
    public init(
        areas: [AreaGeometry],
        repository: any CrowdRepository,
        isMockData: Bool
    ) {
        self.areas = areas
        self.repository = repository
        self.isMockData = isMockData
        self.stateRelay = BehaviorRelay(value: MapBoxCrowdState(
            areas: areas.map { MapBoxCrowdArea(geometry: $0, level: .unknown) },
            isLoading: false,
            unavailableCount: 0
        ))
    }

    deinit {
        loadTask?.cancel()
    }

    /// 화면 이벤트를 혼잡도 조회에 연결합니다.
    ///
    /// 전달받은 Bag에 구독을 추가하므로 ViewController 하나당 한 번만 호출합니다.
    ///
    /// - Parameters:
    ///   - input: 화면 등장과 종료 이벤트입니다.
    ///   - disposeBag: 화면 생명주기 구독의 수명을 관리할 Bag입니다.
    /// - Returns: 경계, 조회 상태와 혼잡도를 전달하는 화면 출력입니다.
    public func transform(
        input: Input,
        disposeBag: DisposeBag
    ) -> Output {
        cancelLoading()

        input.viewDidAppear
            .observe(on: MainScheduler.instance)
            .bind(onNext: { [weak self] in self?.loadIfNeeded() })
            .disposed(by: disposeBag)

        input.viewDidDisappear
            .observe(on: MainScheduler.instance)
            .bind(onNext: { [weak self] in self?.cancelLoading() })
            .disposed(by: disposeBag)

        return Output(state: stateRelay.asDriver().distinctUntilChanged())
    }

    /// 장소별 조회 실패를 회색 영역으로 바꾸고 나머지 지역은 계속 표시합니다.
    private func loadIfNeeded() {
        guard !didLoad, loadTask == nil else { return }
        stateRelay.accept(MapBoxCrowdState(
            areas: stateRelay.value.areas,
            isLoading: true,
            unavailableCount: 0
        ))

        loadTask = Task { @MainActor [weak self, areas, repository] in
            var result: [MapBoxCrowdArea] = []
            var unavailableCount = 0
            for area in areas {
                guard !Task.isCancelled else { return }
                var level = CongestionLevel.unknown
                do {
                    let snapshot = try await repository.fetchSnapshot(for: area.placeID)
                    if snapshot.placeID == area.placeID {
                        level = snapshot.level
                    } else {
                        unavailableCount += 1
                    }
                } catch {
                    unavailableCount += 1
                }
                guard !Task.isCancelled else { return }
                result.append(MapBoxCrowdArea(geometry: area, level: level))
            }

            guard !Task.isCancelled, let self else { return }
            self.loadTask = nil
            self.didLoad = unavailableCount == 0
            self.stateRelay.accept(MapBoxCrowdState(
                areas: result,
                isLoading: false,
                unavailableCount: unavailableCount
            ))
        }
    }

    /// 늦게 도착한 결과를 무시하고 마지막 지도 데이터는 유지합니다.
    private func cancelLoading() {
        loadTask?.cancel()
        loadTask = nil
        let current = stateRelay.value
        if current.isLoading {
            stateRelay.accept(MapBoxCrowdState(
                areas: current.areas,
                isLoading: false,
                unavailableCount: current.unavailableCount
            ))
        }
    }
}
