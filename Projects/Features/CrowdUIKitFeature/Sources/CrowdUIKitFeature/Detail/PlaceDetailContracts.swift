import Core
import CrowdPresentation
import Domain
import Foundation
import ThirdParty

/// UIKit 버전 상세 화면에 표시할 값입니다. SwiftUI 버전 상세와 같은 섹션을 담습니다.
public struct PlaceDetailViewData: Equatable {
    public struct Hero: Equatable {
        public let category: String
        public let name: String
        public let level: CongestionLevel
        public let observedAt: String?
        public let message: String?
        public let population: String
    }

    public struct Flow: Equatable {
        public let badge: String
        public let symbol: String
        public let description: String
        public let cards: [(title: String, boarding: String, alighting: String)]

        public static func == (
            lhs: Flow,
            rhs: Flow
        ) -> Bool {
            lhs.badge == rhs.badge && lhs.description == rhs.description
                && lhs.cards.map(\.title) == rhs.cards.map(\.title)
                && lhs.cards.map(\.boarding) == rhs.cards.map(\.boarding)
        }
    }

    public struct ForecastBar: Equatable {
        public let label: String?
        public let ratio: Double
        public let isNow: Bool
        public let level: CongestionLevel
    }

    public struct Forecast: Equatable {
        public let quietest: String?
        public let bars: [ForecastBar]
        public let accessibilityLabel: String
    }

    public struct AgeRow: Equatable {
        public let title: String
        public let ratio: Double
        public let value: String
    }

    public struct People: Equatable {
        public let male: String
        public let female: String
        public let maleRatio: Double
        public let ages: [AgeRow]
        public let nonResident: String?
    }

    public struct Commerce: Equatable {
        public let activity: String
        public let rows: [CommerceSummary.Category]
    }

    public struct Arrival: Equatable {
        public let title: String
        public let direction: String
        public let message: String
    }

    public struct Move: Equatable {
        public let arrivals: [Arrival]
        public let road: String
        public let parking: String
    }

    public struct Weather: Equatable {
        public let temperature: String
        public let summary: String
        public let dust: String
    }

    public struct Event: Equatable {
        public let name: String
        public let subtitle: String
        public let url: URL?
    }

    public let title: String
    public let hero: Hero
    public let flow: Flow?
    public let forecast: Forecast?
    public let people: People?
    public let commerce: Commerce?
    public let move: Move?
    public let weather: Weather?
    public let eventCount: String?
    public let events: [Event]
    public let isLoading: Bool
    public let errorMessage: String?
}

/// 상세 화면 View 계약입니다.
@MainActor
public protocol PlaceDetailViewProtocol: ViewType where ViewData == PlaceDetailViewData {
    var retryTapped: Observable<Void> { get }
    var eventTapped: Observable<URL> { get }
}

/// 상세 입력입니다.
public struct PlaceDetailInput {
    public let viewDidAppear: Observable<Void>
    public let retryTapped: Observable<Void>

    /// 상세 입력을 묶습니다.
    ///
    /// - Parameters:
    ///   - viewDidAppear: 화면 등장 이벤트입니다.
    ///   - retryTapped: 다시 시도 이벤트입니다.
    public init(
        viewDidAppear: Observable<Void>,
        retryTapped: Observable<Void>
    ) {
        self.viewDidAppear = viewDidAppear
        self.retryTapped = retryTapped
    }
}

/// 상세 출력입니다.
public struct PlaceDetailOutput {
    public let viewData: Driver<PlaceDetailViewData>
}

/// 상세 ViewModel 계약입니다.
@MainActor
public protocol PlaceDetailViewModelProtocol: ViewModelType where Input == PlaceDetailInput, Output == PlaceDetailOutput {}

/// 상세 조회를 맡고 Domain 값을 상세 표시 데이터로 바꾸는 ViewModel입니다.
public final class PlaceDetailViewModel: PlaceDetailViewModelProtocol {
    private struct State: Equatable {
        var snapshot: CrowdSnapshot?
        var detail: PlaceDetail?
        var isLoading = false
        var errorMessage: String?
    }

    private let place: Place
    private let repository: any PlaceDetailRepository
    private let store: CrowdSnapshotStore
    private let relay: BehaviorRelay<State>
    private var loadTask: Task<Void, Never>?

    /// 장소와 상세 저장소로 ViewModel을 만듭니다.
    ///
    /// - Parameters:
    ///   - place: 보여 줄 장소입니다.
    ///   - repository: 상세 정보를 주는 저장소입니다.
    ///   - store: 이미 받은 혼잡도를 읽고 상세의 최신 혼잡도를 반영할 공유 상태입니다.
    public init(
        place: Place,
        repository: any PlaceDetailRepository,
        store: CrowdSnapshotStore
    ) {
        self.place = place
        self.repository = repository
        self.store = store
        relay = BehaviorRelay(value: State(snapshot: store.currentState.snapshots[place.id]))
    }

    deinit {
        loadTask?.cancel()
    }

    /// 상세 입력을 표시 데이터로 바꿉니다.
    ///
    /// - Parameters:
    ///   - input: 상세 화면 입력입니다.
    ///   - disposeBag: 불러오기 구독의 수명을 관리합니다.
    /// - Returns: 상세 표시 데이터입니다.
    public func transform(
        input: PlaceDetailInput,
        disposeBag: DisposeBag
    ) -> PlaceDetailOutput {
        input.viewDidAppear
            .subscribe(onNext: { [weak self] in
                guard let self, self.relay.value.detail == nil, !self.relay.value.isLoading else { return }
                self.load()
            })
            .disposed(by: disposeBag)
        input.retryTapped
            .subscribe(onNext: { [weak self] in self?.load() })
            .disposed(by: disposeBag)

        let place = place
        return PlaceDetailOutput(
            viewData: relay
                .map { Self.viewData(place: place, state: $0) }
                .distinctUntilChanged()
                .asDriver(onErrorDriveWith: .empty())
        )
    }

    /// 상세를 요청합니다.
    private func load() {
        var state = relay.value
        state.isLoading = true
        state.errorMessage = nil
        relay.accept(state)
        let placeID = place.id
        loadTask?.cancel()
        loadTask = Task { [weak self, repository] in
            do {
                let detail = try await repository.fetchDetail(for: placeID)
                guard let self, !Task.isCancelled else { return }
                self.relay.accept(State(snapshot: detail.snapshot, detail: detail))
                self.store.record(detail.snapshot)
            } catch {
                guard let self, !Task.isCancelled else { return }
                var state = self.relay.value
                state.isLoading = false
                state.errorMessage = CrowdCopy.detailFailed
                self.relay.accept(state)
            }
        }
    }

    /// 상태를 상세 표시 데이터로 바꿉니다.
    ///
    /// - Parameters:
    ///   - place: 장소입니다.
    ///   - state: 혼잡도, 상세, 불러오기 상태입니다.
    /// - Returns: 상세 표시 데이터입니다.
    private static func viewData(
        place: Place,
        state: State
    ) -> PlaceDetailViewData {
        let snapshot = state.snapshot
        let detail = state.detail
        return PlaceDetailViewData(
            title: place.name,
            hero: .init(
                category: place.category?.rawValue ?? "장소",
                name: place.name,
                level: snapshot?.level ?? .unknown,
                observedAt: snapshot.map { CrowdCopy.observedAt($0.observedAt) },
                message: snapshot?.message,
                population: CrowdFormat.population(snapshot?.population)
            ),
            flow: detail?.transitFlow.flatMap(flow),
            forecast: snapshot.flatMap(forecast),
            people: detail?.demographics.map(people),
            commerce: detail?.commerce.map { .init(activity: $0.activity, rows: $0.categories) },
            move: detail.map(move),
            weather: detail?.weather.map {
                .init(
                    temperature: CrowdCopy.temperature($0.temperature),
                    summary: CrowdCopy.weatherSummary($0),
                    dust: CrowdCopy.dust($0)
                )
            },
            eventCount: (detail?.events.isEmpty ?? true) ? nil : CrowdCopy.eventCount(detail?.events.count ?? 0),
            events: (detail?.events.prefix(3)).map { events in
                events.map { .init(name: $0.name, subtitle: CrowdCopy.eventSubtitle($0), url: $0.url) }
            } ?? [],
            isLoading: state.isLoading,
            errorMessage: state.errorMessage
        )
    }

    /// 승하차 흐름 섹션 값을 만듭니다.
    ///
    /// - Parameter flow: 최근 30분 승하차 인원입니다.
    /// - Returns: 흐름 섹션이며, 판단할 수 없으면 `nil`입니다.
    private static func flow(
        _ flow: TransitFlow
    ) -> PlaceDetailViewData.Flow? {
        guard let insight = PlaceInsight.flow(flow) else { return nil }
        return .init(
            badge: CrowdCopy.flowBadge(insight),
            symbol: CrowdCopy.flowSymbol(insight),
            description: CrowdCopy.flowDescription(insight),
            cards: [
                (CrowdCopy.subwayCard(stationCount: flow.subwayStationCount), CrowdCopy.boarding(flow.subwayBoarding), CrowdCopy.alighting(flow.subwayAlighting)),
                (CrowdCopy.busCard(stopCount: flow.busStopCount), CrowdCopy.boarding(flow.busBoarding), CrowdCopy.alighting(flow.busAlighting)),
            ]
        )
    }

    /// 지금과 12시간 예측 막대 값을 만듭니다.
    ///
    /// - Parameter snapshot: 예측을 포함한 혼잡도입니다.
    /// - Returns: 예측 섹션이며, 예측이 없으면 `nil`입니다.
    private static func forecast(
        _ snapshot: CrowdSnapshot
    ) -> PlaceDetailViewData.Forecast? {
        guard !snapshot.forecasts.isEmpty else { return nil }
        let values = [(label: CrowdCopy.nowLegend, value: CrowdFormat.midpoint(snapshot.population), level: snapshot.level, isNow: true)]
            + snapshot.forecasts.map {
                (label: CrowdFormat.hour($0.time), value: CrowdFormat.midpoint($0.population), level: $0.level, isNow: false)
            }
        let maximum = max(1, values.map(\.value).max() ?? 1)
        return .init(
            quietest: PlaceInsight.quietest(snapshot.forecasts).map(CrowdCopy.quietest),
            bars: values.enumerated().map { index, item in
                .init(
                    label: index == 0 || index % 3 == 0 ? String(item.label.prefix(2)) : nil,
                    ratio: item.value / maximum,
                    isNow: item.isNow,
                    level: item.level
                )
            },
            accessibilityLabel: values.map { "\($0.label) \(Int($0.value))명" }.joined(separator: ", ")
        )
    }

    /// 방문자 구성 섹션 값을 만듭니다.
    ///
    /// - Parameter demographics: 성별·연령대·비거주자 비율입니다.
    /// - Returns: 방문자 구성 섹션입니다.
    private static func people(
        _ demographics: PlaceDemographics
    ) -> PlaceDetailViewData.People {
        let maximum = max(1, demographics.ageRates.map(\.rate).max() ?? 1)
        return .init(
            male: "남성 \(CrowdCopy.percent(demographics.maleRate))",
            female: "여성 \(CrowdCopy.percent(demographics.femaleRate))",
            maleRatio: demographics.maleRate / 100,
            ages: demographics.ageRates.map {
                .init(title: CrowdCopy.ageTitle($0.decade), ratio: $0.rate / maximum, value: CrowdCopy.percent($0.rate))
            },
            nonResident: demographics.nonResidentRate.map(CrowdCopy.nonResident)
        )
    }

    /// 가는 방법 섹션 값을 만듭니다.
    ///
    /// - Parameter detail: 장소 상세입니다.
    /// - Returns: 지하철 도착, 도로, 주차장 값입니다.
    private static func move(
        _ detail: PlaceDetail
    ) -> PlaceDetailViewData.Move {
        .init(
            arrivals: detail.subwayArrivals.prefix(4).map {
                .init(title: "\($0.stationName) \($0.line)", direction: $0.direction, message: $0.message)
            },
            road: detail.roadStatus ?? CrowdCopy.unknown,
            parking: CrowdCopy.placeCount(detail.parkingLotCount)
        )
    }
}
