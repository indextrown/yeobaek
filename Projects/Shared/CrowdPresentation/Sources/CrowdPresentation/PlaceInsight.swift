import Domain
import Foundation

/// 상세 화면이 원천 값으로 계산하는 표시 규칙입니다.
public enum PlaceInsight {
    /// 최근 30분 대중교통 승하차로 본 사람 흐름입니다.
    public enum Flow: Equatable, Sendable {
        /// 내리는 사람이 타는 사람보다 20% 넘게 많습니다.
        case gathering
        /// 타는 사람이 내리는 사람보다 20% 넘게 많습니다.
        case leaving
        /// 차이가 작습니다.
        case steady
    }

    /// 지하철과 버스의 승하차 합계를 비교합니다.
    ///
    /// - Parameter flow: 최근 30분 승하차 인원입니다.
    /// - Returns: 흐름이며, 승하차 정보가 없으면 `nil`입니다.
    public static func flow(
        _ flow: TransitFlow
    ) -> Flow? {
        let boarding = CrowdFormat.midpoint(flow.subwayBoarding) + CrowdFormat.midpoint(flow.busBoarding)
        let alighting = CrowdFormat.midpoint(flow.subwayAlighting) + CrowdFormat.midpoint(flow.busAlighting)
        guard boarding + alighting > 0 else { return nil }
        if alighting > boarding * 1.2 { return .gathering }
        if boarding > alighting * 1.2 { return .leaving }
        return .steady
    }

    /// 예측 중 인구가 가장 적은 시간대를 찾습니다. 같으면 더 이른 시간입니다.
    ///
    /// - Parameter forecasts: 시간 순서의 예측입니다.
    /// - Returns: 가장 한산한 예측이며, 인구 정보가 없으면 `nil`입니다.
    public static func quietest(
        _ forecasts: [CrowdForecast]
    ) -> CrowdForecast? {
        forecasts
            .filter { $0.population != nil }
            .min { CrowdFormat.midpoint($0.population) < CrowdFormat.midpoint($1.population) }
    }
}
