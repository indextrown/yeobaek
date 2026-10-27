import Domain
import Foundation

/// SwiftUI와 UIKit 버전이 함께 쓰는 화면 문구입니다. 두 버전이 같은 화면을 보여 주도록 문구를 한곳에 둡니다.
public enum CrowdCopy {
    // MARK: - 홈

    public static let searchPlaceholder = "장소 이름으로 찾기"
    public static let showListLabel = "목록으로 보기"
    public static let showAll = "전체 보기"
    public static let rankingTitle = "지금 붐비는 순"
    public static let allCategories = "전체"
    public static let sheetHandleLabel = "시트 높이"
    public static let sheetHandleHint = "위아래로 쓸어 펼치거나 접습니다"
    public static let currentLocation = "내 위치로 이동"
    public static let mapCentered = "현재 위치 중심"
    public static let mapMoved = "사용자 이동 위치"
    public static let authorizationDenied = "위치 권한이 없어 현재 위치를 확인할 수 없습니다."
    public static let locationFailureTitle = "위치 조회 실패"
    public static let locationFailureMessage = "현재 위치를 확인하지 못했습니다. 다시 시도해 주세요."
    public static let locationTimeoutMessage = "현재 위치를 확인하는 데 시간이 오래 걸립니다. 다시 시도해 주세요."
    public static let tokenMissingTitle = "Mapbox 토큰이 필요해요"
    public static let tokenMissingDescription = "MAPBOX_ACCESS_TOKEN 빌드 설정에 공개 액세스 토큰을 추가해 주세요."

    /// 홈 시트 제목입니다.
    ///
    /// - Parameters:
    ///   - category: 선택한 분류입니다. 전체면 `nil`입니다.
    ///   - placeCount: 전체 장소 수입니다.
    /// - Returns: 분류 이름 또는 `서울 주요 121곳`입니다.
    public static func homeTitle(
        category: PlaceCategory?,
        placeCount: Int
    ) -> String {
        category?.rawValue ?? "서울 주요 \(placeCount)곳"
    }

    /// 기준 시각 표시 문구입니다.
    ///
    /// - Parameter observedAt: 원천 데이터 기준 시각입니다.
    /// - Returns: `22:45 기준 · 5분마다 갱신` 형태입니다.
    public static func freshness(
        _ observedAt: Date
    ) -> String {
        "\(CrowdFormat.time(observedAt)) 기준 · 5분마다 갱신"
    }

    /// 실패한 장소를 다시 불러오는 버튼 문구입니다.
    ///
    /// - Parameter count: 실패한 장소 수입니다.
    /// - Returns: `3곳 다시 불러오기` 형태입니다.
    public static func retry(
        failedCount count: Int
    ) -> String {
        "\(count)곳 다시 불러오기"
    }

    // MARK: - 목록

    public static let listTitle = "장소 목록"
    public static let noSearchResults = "찾는 장소가 없어요."
    public static let catalogFailed = "장소 목록을 읽지 못했어요."
    public static let sortHint = "정렬 기준을 바꿉니다"

    /// 목록 검색창 안내 문구입니다.
    ///
    /// - Parameter total: 전체 장소 수입니다.
    /// - Returns: `121곳 중에서 찾기` 형태입니다.
    public static func listSearchPlaceholder(
        total: Int
    ) -> String {
        "\(total)곳 중에서 찾기"
    }

    /// 목록 개수 문구입니다.
    ///
    /// - Parameter count: 보이는 장소 수입니다.
    /// - Returns: `12곳` 형태입니다.
    public static func placeCount(
        _ count: Int
    ) -> String {
        "\(count)곳"
    }

    /// 정렬 기준 이름입니다.
    ///
    /// - Parameter sort: 정렬 기준입니다.
    /// - Returns: `붐비는 순` 또는 `인구 많은 순`입니다.
    public static func sortTitle(
        _ sort: CrowdRanking.Sort
    ) -> String {
        sort == .crowding ? "붐비는 순" : "인구 많은 순"
    }

    /// 장소 행의 보조 문구입니다.
    ///
    /// - Parameters:
    ///   - place: 장소입니다.
    ///   - snapshot: 받은 혼잡도입니다. 아직 없으면 `nil`입니다.
    /// - Returns: `인구밀집지역 · 추정 16,000~18,000명` 형태입니다.
    public static func placeSubtitle(
        _ place: Place,
        snapshot: CrowdSnapshot?
    ) -> String {
        let category = place.category?.rawValue ?? "장소"
        guard let snapshot else { return "\(category) · 불러오는 중" }
        return "\(category) · 추정 \(CrowdFormat.population(snapshot.population))"
    }

    // MARK: - 상세

    public static let flowTitle = "지금 흐름"
    public static let forecastTitle = "앞으로 12시간"
    public static let peopleTitle = "지금 있는 사람들"
    public static let commerceTitle = "주변 상권"
    public static let commerceFootnote = "카드 결제 데이터 기준"
    public static let moveTitle = "가는 방법"
    public static let roadTitle = "주변 도로"
    public static let parkingTitle = "주차장"
    public static let weatherTitle = "날씨"
    public static let eventsTitle = "주변 행사"
    public static let populationTitle = "추정 인구"
    public static let nowLegend = "지금"
    public static let forecastLegend = "예측 · 단계 색"
    public static let detailLoading = "주변 정보를 불러오는 중"
    public static let detailFailed = "상세 정보를 불러오지 못했어요."
    public static let retryDetail = "다시 시도"
    public static let unknown = "정보 없음"
    public static let source = "출처: 서울특별시 서울 실시간 도시데이터. 인구는 통신 데이터로 추정한 범위예요."

    /// 기준 시각 문구입니다.
    ///
    /// - Parameter date: 원천 데이터 기준 시각입니다.
    /// - Returns: `20:10 기준` 형태입니다.
    public static func observedAt(
        _ date: Date
    ) -> String {
        "\(CrowdFormat.time(date)) 기준"
    }

    /// 흐름 배지 문구입니다.
    ///
    /// - Parameter flow: 사람 흐름입니다.
    /// - Returns: `모이는 중`, `빠지는 중`, `비슷해요` 중 하나입니다.
    public static func flowBadge(
        _ flow: PlaceInsight.Flow
    ) -> String {
        switch flow {
        case .gathering: "모이는 중"
        case .leaving: "빠지는 중"
        case .steady: "비슷해요"
        }
    }

    /// 흐름 설명 문구입니다.
    ///
    /// - Parameter flow: 사람 흐름입니다.
    /// - Returns: 최근 30분 승하차 비교 설명입니다.
    public static func flowDescription(
        _ flow: PlaceInsight.Flow
    ) -> String {
        switch flow {
        case .gathering: "최근 30분 동안 내리는 사람이 더 많아요."
        case .leaving: "최근 30분 동안 타는 사람이 더 많아요."
        case .steady: "최근 30분 동안 타고 내리는 사람이 비슷해요."
        }
    }

    /// 흐름 배지의 SF Symbol 이름입니다.
    ///
    /// - Parameter flow: 사람 흐름입니다.
    /// - Returns: 화살표 또는 등호 기호 이름입니다.
    public static func flowSymbol(
        _ flow: PlaceInsight.Flow
    ) -> String {
        switch flow {
        case .gathering: "arrow.up"
        case .leaving: "arrow.down"
        case .steady: "equal"
        }
    }

    /// 지하철 승하차 카드 제목입니다.
    ///
    /// - Parameter count: 집계한 역 수입니다.
    /// - Returns: `지하철 4개 역` 형태입니다.
    public static func subwayCard(
        stationCount count: Int
    ) -> String {
        "지하철 \(count)개 역"
    }

    /// 버스 승하차 카드 제목입니다.
    ///
    /// - Parameter count: 집계한 정류소 수입니다.
    /// - Returns: `버스 41개 정류소` 형태입니다.
    public static func busCard(
        stopCount count: Int
    ) -> String {
        "버스 \(count)개 정류소"
    }

    /// 승차 인원 문구입니다.
    ///
    /// - Parameter range: 승차 인원 범위입니다.
    /// - Returns: `승차 700~750명` 형태입니다.
    public static func boarding(
        _ range: PopulationRange?
    ) -> String {
        "승차 \(CrowdFormat.population(range))"
    }

    /// 하차 인원 문구입니다.
    ///
    /// - Parameter range: 하차 인원 범위입니다.
    /// - Returns: `하차 100~150명` 형태입니다.
    public static func alighting(
        _ range: PopulationRange?
    ) -> String {
        "하차 \(CrowdFormat.population(range))"
    }

    /// 가장 한산한 시간 문구입니다.
    ///
    /// - Parameter forecast: 가장 한산한 예측입니다.
    /// - Returns: `가장 한산한 시간은 03시 · 2,000~2,500명` 형태입니다.
    public static func quietest(
        _ forecast: CrowdForecast
    ) -> String {
        "가장 한산한 시간은 \(CrowdFormat.hour(forecast.time)) · \(CrowdFormat.population(forecast.population))"
    }

    /// 백분율을 소수 한 자리로 표시합니다.
    ///
    /// - Parameter value: 0~100 사이 값입니다.
    /// - Returns: `23.2%` 형태입니다.
    public static func percent(
        _ value: Double
    ) -> String {
        String(format: "%.1f%%", value)
    }

    /// 연령대 이름입니다.
    ///
    /// - Parameter decade: 연령대 시작 나이입니다.
    /// - Returns: `10세 미만`, `20대`, `70대 이상` 같은 이름입니다.
    public static func ageTitle(
        _ decade: Int
    ) -> String {
        switch decade {
        case 0: "10세 미만"
        case 70: "70대 이상"
        default: "\(decade)대"
        }
    }

    /// 비거주 방문자 비율 문구입니다.
    ///
    /// - Parameter rate: 비거주자 백분율입니다.
    /// - Returns: `이 지역에 살지 않는 방문자가 56.1%예요.` 형태입니다.
    public static func nonResident(
        _ rate: Double
    ) -> String {
        "이 지역에 살지 않는 방문자가 \(percent(rate))예요."
    }

    /// 날씨 요약 문구입니다.
    ///
    /// - Parameter weather: 날씨 정보입니다.
    /// - Returns: 하늘 상태와 강수 안내를 이은 문구입니다.
    public static func weatherSummary(
        _ weather: WeatherSummary
    ) -> String {
        [weather.sky, weather.precipitationMessage].compactMap { $0 }.joined(separator: " · ")
    }

    /// 미세먼지 문구입니다.
    ///
    /// - Parameter weather: 날씨 정보입니다.
    /// - Returns: `미세먼지 좋음 · 초미세먼지 좋음` 형태입니다.
    public static func dust(
        _ weather: WeatherSummary
    ) -> String {
        "미세먼지 \(weather.fineDust ?? unknown) · 초미세먼지 \(weather.ultraFineDust ?? unknown)"
    }

    /// 기온 문구입니다.
    ///
    /// - Parameter temperature: 섭씨 기온입니다.
    /// - Returns: `16.1°` 형태입니다.
    public static func temperature(
        _ temperature: Double
    ) -> String {
        String(format: "%.1f°", temperature)
    }

    /// 행사 보조 문구입니다.
    ///
    /// - Parameter event: 행사입니다.
    /// - Returns: 기간과 장소를 이은 문구입니다.
    public static func eventSubtitle(
        _ event: PlaceEvent
    ) -> String {
        [event.period, event.venue].compactMap { $0 }.joined(separator: " · ")
    }

    /// 행사 개수 문구입니다.
    ///
    /// - Parameter count: 행사 수입니다.
    /// - Returns: `15건` 형태입니다.
    public static func eventCount(
        _ count: Int
    ) -> String {
        "\(count)건"
    }
}
