import Domain
import Foundation

/// 네트워크 없이 실제 장소 코드에 정해진 예시 혼잡도를 돌려주는 저장소입니다.
///
/// UI 테스트와 Preview처럼 결과가 매번 같아야 하는 곳에서만 사용합니다. 실제 관측값이 아닙니다.
public struct SampleCrowdRepository: CrowdRepository, PlaceDetailRepository {
    private let observedAt: Date

    /// 예시 값의 기준 시각을 지정해 저장소를 만듭니다.
    ///
    /// - Parameter observedAt: 예시 혼잡도의 기준 시각입니다.
    public init(
        observedAt: Date = Date(timeIntervalSince1970: 1_793_029_500)
    ) {
        self.observedAt = observedAt
    }

    /// 장소 코드 숫자로 단계를 정해 예시 혼잡도를 만듭니다.
    ///
    /// - Parameter placeID: 장소 코드입니다.
    /// - Returns: 예시 혼잡도입니다. 코드 숫자가 7의 배수면 약간 붐빔, 13의 배수면 붐빔입니다.
    /// - Throws: 요청이 취소되면 `CancellationError`가 발생합니다.
    public func fetchSnapshot(
        for placeID: Place.ID
    ) async throws -> CrowdSnapshot {
        try Task.checkCancellation()
        let number = Int(placeID.filter(\.isNumber)) ?? 0
        let level: CongestionLevel = number % 13 == 0 ? .crowded : number % 7 == 0 ? .busy : number % 5 == 0 ? .normal : .relaxed
        let minimum = 1_000 + (number * 523) % 30_000
        return CrowdSnapshot(
            placeID: placeID,
            level: level,
            population: PopulationRange(minimum: minimum, maximum: minimum + 2_000),
            message: "예시 데이터입니다.",
            observedAt: observedAt,
            forecasts: (1...12).map { hour in
                CrowdForecast(
                    time: observedAt.addingTimeInterval(Double(hour) * 3_600),
                    level: .relaxed,
                    population: PopulationRange(minimum: minimum / (hour + 1), maximum: minimum / (hour + 1) + 500)
                )
            }
        )
    }

    /// 예시 혼잡도만 담은 상세를 만듭니다.
    ///
    /// - Parameter placeID: 장소 코드입니다.
    /// - Returns: 주변 정보가 비어 있는 예시 상세입니다.
    /// - Throws: 요청이 취소되면 `CancellationError`가 발생합니다.
    public func fetchDetail(
        for placeID: Place.ID
    ) async throws -> PlaceDetail {
        PlaceDetail(
            placeID: placeID,
            snapshot: try await fetchSnapshot(for: placeID),
            demographics: nil,
            transitFlow: nil,
            commerce: nil,
            subwayArrivals: [],
            roadStatus: nil,
            parkingLotCount: 0,
            weather: nil,
            events: []
        )
    }
}
