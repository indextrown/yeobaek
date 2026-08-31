import Foundation

public struct CrowdSnapshot: Equatable, Sendable {
    public let placeID: Place.ID
    public let level: CongestionLevel
    /// `nil`은 인원이 0명이라는 뜻이 아니라 인구 정보를 제공받지 못했다는 뜻입니다.
    public let population: PopulationRange?
    public let message: String?
    /// 응답을 받은 시각이 아닌, 원천 데이터의 기준 시각입니다.
    public let observedAt: Date
    /// `nil`은 데이터 제공 기관이 대체 데이터 사용 여부를 명시하지 않았다는 뜻입니다.
    public let isReplacementData: Bool?

    /// 원천 데이터의 기준 시각에 해당하는 장소의 혼잡도와 추정 인구를 저장합니다.
    ///
    /// - Parameters:
    ///   - placeID: 혼잡도 정보가 속한 장소의 고유 코드입니다.
    ///   - level: 장소의 혼잡도 단계입니다. 알 수 없는 경우 `.unknown`을 사용합니다.
    ///   - population: 추정 인구 범위입니다. 정보를 제공받지 못하면 `nil`입니다.
    ///   - message: 혼잡도와 함께 제공되는 설명입니다. 설명이 없으면 `nil`입니다.
    ///   - observedAt: 응답 수신 시각이 아닌, 원천 데이터의 기준 시각입니다.
    ///   - isReplacementData: 대체 데이터 사용 여부입니다. 명시되지 않으면 `nil`입니다.
    public init(
        placeID: Place.ID,
        level: CongestionLevel,
        population: PopulationRange?,
        message: String? = nil,
        observedAt: Date,
        isReplacementData: Bool? = nil
    ) {
        self.placeID = placeID
        self.level = level
        self.population = population
        self.message = message
        self.observedAt = observedAt
        self.isReplacementData = isReplacementData
    }
}
