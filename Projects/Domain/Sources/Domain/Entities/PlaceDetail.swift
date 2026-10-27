import Foundation

/// 장소 상세 화면에 필요한 실시간 정보를 한곳에 모은 값입니다.
///
/// 하위 정보마다 제공 여부가 다르므로 없는 정보는 `nil` 또는 빈 배열로 표현합니다.
public struct PlaceDetail: Equatable, Sendable {
    public let placeID: Place.ID
    public let snapshot: CrowdSnapshot
    public let demographics: PlaceDemographics?
    public let transitFlow: TransitFlow?
    public let commerce: CommerceSummary?
    public let subwayArrivals: [SubwayArrival]
    /// 원천 데이터의 도로 소통 문구입니다. 예: 원활, 서행, 정체
    public let roadStatus: String?
    public let parkingLotCount: Int
    public let weather: WeatherSummary?
    public let events: [PlaceEvent]

    /// 장소 상세 정보를 저장합니다.
    ///
    /// - Parameters:
    ///   - placeID: 정보가 속한 장소의 고유 코드입니다.
    ///   - snapshot: 현재 혼잡도, 추정 인구와 예측입니다.
    ///   - demographics: 성별·연령대·거주 여부 비율입니다. 없으면 `nil`입니다.
    ///   - transitFlow: 주변 지하철·버스의 최근 승하차 인원입니다. 없으면 `nil`입니다.
    ///   - commerce: 카드 결제 기반 상권 현황입니다. 없으면 `nil`입니다.
    ///   - subwayArrivals: 주변 역의 열차 도착 정보입니다.
    ///   - roadStatus: 주변 도로 소통 문구입니다. 없으면 `nil`입니다.
    ///   - parkingLotCount: 주변 주차장 수입니다.
    ///   - weather: 현재 날씨와 대기 정보입니다. 없으면 `nil`입니다.
    ///   - events: 주변 문화행사 목록입니다.
    public init(
        placeID: Place.ID,
        snapshot: CrowdSnapshot,
        demographics: PlaceDemographics?,
        transitFlow: TransitFlow?,
        commerce: CommerceSummary?,
        subwayArrivals: [SubwayArrival],
        roadStatus: String?,
        parkingLotCount: Int,
        weather: WeatherSummary?,
        events: [PlaceEvent]
    ) {
        self.placeID = placeID
        self.snapshot = snapshot
        self.demographics = demographics
        self.transitFlow = transitFlow
        self.commerce = commerce
        self.subwayArrivals = subwayArrivals
        self.roadStatus = roadStatus
        self.parkingLotCount = parkingLotCount
        self.weather = weather
        self.events = events
    }
}

/// 장소에 있는 사람들의 구성 비율입니다. 값은 0~100 사이의 백분율입니다.
public struct PlaceDemographics: Equatable, Sendable {
    public let maleRate: Double
    public let femaleRate: Double
    /// 10세 단위 연령대 비율입니다. `decade`가 0이면 10세 미만, 70이면 70세 이상입니다.
    public let ageRates: [AgeRate]
    public let nonResidentRate: Double?

    /// 연령대 하나의 비율입니다.
    public struct AgeRate: Equatable, Sendable {
        public let decade: Int
        public let rate: Double

        /// 연령대 시작 나이와 비율을 저장합니다.
        ///
        /// - Parameters:
        ///   - decade: 연령대 시작 나이입니다. 0, 10, …, 70을 사용합니다.
        ///   - rate: 해당 연령대의 백분율입니다.
        public init(
            decade: Int,
            rate: Double
        ) {
            self.decade = decade
            self.rate = rate
        }
    }

    /// 성별·연령대·비거주자 비율을 저장합니다.
    ///
    /// - Parameters:
    ///   - maleRate: 남성 비율입니다.
    ///   - femaleRate: 여성 비율입니다.
    ///   - ageRates: 연령대별 비율입니다.
    ///   - nonResidentRate: 비거주자 비율입니다. 없으면 `nil`입니다.
    public init(
        maleRate: Double,
        femaleRate: Double,
        ageRates: [AgeRate],
        nonResidentRate: Double?
    ) {
        self.maleRate = maleRate
        self.femaleRate = femaleRate
        self.ageRates = ageRates
        self.nonResidentRate = nonResidentRate
    }
}

/// 장소 주변 대중교통의 최근 30분 승하차 인원입니다.
public struct TransitFlow: Equatable, Sendable {
    public let subwayStationCount: Int
    public let subwayBoarding: PopulationRange?
    public let subwayAlighting: PopulationRange?
    public let busStopCount: Int
    public let busBoarding: PopulationRange?
    public let busAlighting: PopulationRange?

    /// 지하철과 버스의 최근 30분 승하차 인원을 저장합니다.
    ///
    /// - Parameters:
    ///   - subwayStationCount: 집계한 주변 지하철역 수입니다.
    ///   - subwayBoarding: 지하철 승차 인원 범위입니다.
    ///   - subwayAlighting: 지하철 하차 인원 범위입니다.
    ///   - busStopCount: 집계한 주변 버스 정류소 수입니다.
    ///   - busBoarding: 버스 승차 인원 범위입니다.
    ///   - busAlighting: 버스 하차 인원 범위입니다.
    public init(
        subwayStationCount: Int,
        subwayBoarding: PopulationRange?,
        subwayAlighting: PopulationRange?,
        busStopCount: Int,
        busBoarding: PopulationRange?,
        busAlighting: PopulationRange?
    ) {
        self.subwayStationCount = subwayStationCount
        self.subwayBoarding = subwayBoarding
        self.subwayAlighting = subwayAlighting
        self.busStopCount = busStopCount
        self.busBoarding = busBoarding
        self.busAlighting = busAlighting
    }
}

/// 카드 결제 데이터로 본 상권 활성도입니다. 활성도는 원천 데이터의 문구를 그대로 사용합니다.
public struct CommerceSummary: Equatable, Sendable {
    public let activity: String
    public let categories: [Category]

    /// 업종 하나의 활성도입니다.
    public struct Category: Equatable, Sendable {
        public let name: String
        public let activity: String

        /// 업종 이름과 활성도를 저장합니다.
        ///
        /// - Parameters:
        ///   - name: 업종 중분류 이름입니다.
        ///   - activity: 업종 활성도 문구입니다.
        public init(
            name: String,
            activity: String
        ) {
            self.name = name
            self.activity = activity
        }
    }

    /// 상권 전체 활성도와 업종별 활성도를 저장합니다.
    ///
    /// - Parameters:
    ///   - activity: 상권 전체 활성도 문구입니다.
    ///   - categories: 업종별 활성도 목록입니다.
    public init(
        activity: String,
        categories: [Category]
    ) {
        self.activity = activity
        self.categories = categories
    }
}

/// 주변 지하철역에 도착하는 열차 한 대의 정보입니다.
public struct SubwayArrival: Equatable, Sendable {
    public let stationName: String
    public let line: String
    public let direction: String
    public let message: String

    /// 역, 호선, 방면과 도착 안내 문구를 저장합니다.
    ///
    /// - Parameters:
    ///   - stationName: 역 이름입니다.
    ///   - line: 호선 표시입니다. 예: 3호선
    ///   - direction: 행선지와 방면입니다.
    ///   - message: 도착 안내 문구입니다.
    public init(
        stationName: String,
        line: String,
        direction: String,
        message: String
    ) {
        self.stationName = stationName
        self.line = line
        self.direction = direction
        self.message = message
    }
}

/// 장소의 현재 날씨와 대기 정보입니다.
public struct WeatherSummary: Equatable, Sendable {
    public let temperature: Double
    public let sky: String?
    public let precipitationMessage: String?
    public let fineDust: String?
    public let ultraFineDust: String?

    /// 날씨와 대기 정보를 저장합니다.
    ///
    /// - Parameters:
    ///   - temperature: 섭씨 기온입니다.
    ///   - sky: 하늘 상태 문구입니다. 없으면 `nil`입니다.
    ///   - precipitationMessage: 강수 안내 문구입니다. 없으면 `nil`입니다.
    ///   - fineDust: 미세먼지 단계 문구입니다. 없으면 `nil`입니다.
    ///   - ultraFineDust: 초미세먼지 단계 문구입니다. 없으면 `nil`입니다.
    public init(
        temperature: Double,
        sky: String?,
        precipitationMessage: String?,
        fineDust: String?,
        ultraFineDust: String?
    ) {
        self.temperature = temperature
        self.sky = sky
        self.precipitationMessage = precipitationMessage
        self.fineDust = fineDust
        self.ultraFineDust = ultraFineDust
    }
}

/// 장소 주변의 문화행사입니다.
public struct PlaceEvent: Equatable, Sendable {
    public let name: String
    public let period: String
    public let venue: String?
    public let url: URL?

    /// 행사 이름, 기간, 장소와 상세 링크를 저장합니다.
    ///
    /// - Parameters:
    ///   - name: 행사 이름입니다.
    ///   - period: 원천 데이터의 기간 문구입니다.
    ///   - venue: 행사 장소입니다. 없으면 `nil`입니다.
    ///   - url: 상세 정보 링크입니다. 없으면 `nil`입니다.
    public init(
        name: String,
        period: String,
        venue: String?,
        url: URL?
    ) {
        self.name = name
        self.period = period
        self.venue = venue
        self.url = url
    }
}
