import ComposableArchitecture
import Domain
import SwiftUI

/// 장소 하나의 혼잡도, 예측, 흐름과 주변 정보를 세로로 보여 주는 상세 화면입니다.
struct PlaceDetailView: View {
    let store: StoreOf<PlaceDetailFeature>

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                DetailHero(place: store.place, snapshot: store.snapshot)

                if let flow = store.detail?.transitFlow, let insight = PlaceInsight.flow(flow) {
                    FlowSection(flow: flow, insight: insight)
                }
                if let snapshot = store.snapshot, !snapshot.forecasts.isEmpty {
                    ForecastSection(snapshot: snapshot)
                }

                if let detail = store.detail {
                    if let demographics = detail.demographics {
                        PeopleSection(demographics: demographics)
                    }
                    if let commerce = detail.commerce {
                        CommerceSection(commerce: commerce)
                    }
                    MoveSection(detail: detail)
                    if let weather = detail.weather {
                        WeatherSection(weather: weather)
                    }
                    if !detail.events.isEmpty {
                        EventsSection(events: detail.events)
                    }
                } else if store.isLoading {
                    ProgressView("주변 정보를 불러오는 중")
                        .frame(maxWidth: .infinity)
                        .padding(32)
                } else if let message = store.errorMessage {
                    DetailErrorView(message: message) { store.send(.retryTapped) }
                }

                Text("출처: 서울특별시 서울 실시간 도시데이터. 인구는 통신 데이터로 추정한 범위예요.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
            }
            .padding(.bottom, 32)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle(store.place.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { store.send(.onAppear) }
    }
}

/// 분류, 이름, 현재 단계, 안내 문구와 추정 인구를 보여 주는 상단 카드입니다.
struct DetailHero: View {
    let place: Place
    let snapshot: CrowdSnapshot?

    var body: some View {
        let level = snapshot?.level ?? .unknown
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(place.category?.rawValue ?? "장소").font(.footnote).foregroundStyle(.secondary)
                Text(place.name).font(.title.weight(.bold))
            }
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    HStack(spacing: 8) {
                        Circle().fill(level.fillColor).frame(width: 12, height: 12)
                        Text(level.title).font(.title3.weight(.bold))
                    }
                    .foregroundStyle(level.textColor)
                    Spacer()
                    if let snapshot {
                        Text("\(CrowdFormat.time(snapshot.observedAt)) 기준")
                            .font(.caption)
                            .foregroundStyle(level.textColor)
                    }
                }
                if let message = snapshot?.message {
                    Text(message).font(.subheadline).lineSpacing(3)
                }
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("추정 인구").font(.footnote)
                    Text(CrowdFormat.population(snapshot?.population)).font(.title2.weight(.bold))
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(level.tintColor, in: RoundedRectangle(cornerRadius: 16))
        }
        .padding(20)
        .background(Color(uiColor: .systemBackground))
    }
}

/// 최근 30분 대중교통 승하차로 사람이 모이는지 빠지는지 보여 줍니다.
struct FlowSection: View {
    let flow: TransitFlow
    let insight: PlaceInsight.Flow

    var body: some View {
        DetailSection("지금 흐름") {
            HStack {
                Text(description).font(.footnote).foregroundStyle(.secondary)
                Spacer()
                Label(title, systemImage: symbol)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.blue)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.12), in: Capsule())
            }
            HStack(spacing: 10) {
                FlowCard(
                    title: "지하철 \(flow.subwayStationCount)개 역",
                    boarding: flow.subwayBoarding,
                    alighting: flow.subwayAlighting
                )
                FlowCard(
                    title: "버스 \(flow.busStopCount)개 정류소",
                    boarding: flow.busBoarding,
                    alighting: flow.busAlighting
                )
            }
        }
    }

    private var title: String {
        switch insight {
        case .gathering: "모이는 중"
        case .leaving: "빠지는 중"
        case .steady: "비슷해요"
        }
    }

    private var symbol: String {
        switch insight {
        case .gathering: "arrow.up"
        case .leaving: "arrow.down"
        case .steady: "equal"
        }
    }

    private var description: String {
        switch insight {
        case .gathering: "최근 30분 동안 내리는 사람이 더 많아요."
        case .leaving: "최근 30분 동안 타는 사람이 더 많아요."
        case .steady: "최근 30분 동안 타고 내리는 사람이 비슷해요."
        }
    }
}

/// 지하철 또는 버스의 승하차 인원 카드입니다.
struct FlowCard: View {
    let title: String
    let boarding: PopulationRange?
    let alighting: PopulationRange?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.footnote.weight(.semibold))
            Text("승차 \(CrowdFormat.population(boarding))").font(.caption)
            Text("하차 \(CrowdFormat.population(alighting))").font(.caption)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }
}

/// 지금과 앞으로 12시간의 추정 인구 막대와 가장 한산한 시간을 보여 줍니다.
struct ForecastSection: View {
    let snapshot: CrowdSnapshot

    var body: some View {
        DetailSection("앞으로 12시간") {
            if let quietest = PlaceInsight.quietest(snapshot.forecasts) {
                Text("가장 한산한 시간은 \(CrowdFormat.hour(quietest.time)) · \(CrowdFormat.population(quietest.population))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            ForecastBars(snapshot: snapshot)
                .frame(height: 150)
            HStack(spacing: 14) {
                LegendSwatch(color: .primary, title: "지금")
                LegendSwatch(color: CongestionLevel.relaxed.fillColor, title: "예측 · 단계 색")
            }
        }
    }
}

/// 지금 값은 검정, 예측 값은 단계 색으로 그린 막대입니다.
struct ForecastBars: View {
    let snapshot: CrowdSnapshot

    var body: some View {
        let values = [(label: "지금", value: CrowdFormat.midpoint(snapshot.population), color: Color.primary)]
            + snapshot.forecasts.map {
                (label: CrowdFormat.hour($0.time), value: CrowdFormat.midpoint($0.population), color: $0.level.fillColor)
            }
        let maximum = max(1, values.map(\.value).max() ?? 1)
        HStack(alignment: .bottom, spacing: 5) {
            ForEach(Array(values.enumerated()), id: \.offset) { index, item in
                VStack(spacing: 4) {
                    GeometryReader { proxy in
                        VStack {
                            Spacer(minLength: 0)
                            UnevenRoundedRectangle(topLeadingRadius: 4, topTrailingRadius: 4)
                                .fill(item.color)
                                .frame(height: max(4, proxy.size.height * item.value / maximum))
                        }
                    }
                    Text(index == 0 || index % 3 == 0 ? String(item.label.prefix(2)) : " ")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityElement()
        .accessibilityLabel(values.map { "\($0.label) \(Int($0.value))명" }.joined(separator: ", "))
    }
}

/// 범례 색 상자와 이름입니다.
struct LegendSwatch: View {
    let color: Color
    let title: String

    var body: some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 10, height: 10)
            Text(title)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}

/// 성별, 연령대, 비거주자 비율을 보여 줍니다.
struct PeopleSection: View {
    let demographics: PlaceDemographics

    var body: some View {
        DetailSection("지금 있는 사람들") {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("남성 \(percent(demographics.maleRate))")
                    Spacer()
                    Text("여성 \(percent(demographics.femaleRate))")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                GeometryReader { proxy in
                    HStack(spacing: 2) {
                        Rectangle().fill(Color.primary.opacity(0.75))
                            .frame(width: proxy.size.width * demographics.maleRate / 100)
                        Rectangle().fill(Color.secondary.opacity(0.4))
                    }
                }
                .frame(height: 8)
                .clipShape(Capsule())
            }
            let maximum = max(1, demographics.ageRates.map(\.rate).max() ?? 1)
            VStack(spacing: 8) {
                ForEach(demographics.ageRates, id: \.decade) { age in
                    HStack(spacing: 10) {
                        Text(ageTitle(age.decade)).font(.caption).foregroundStyle(.secondary).frame(width: 56, alignment: .leading)
                        GeometryReader { proxy in
                            Capsule().fill(Color.primary.opacity(0.75))
                                .frame(width: proxy.size.width * age.rate / maximum)
                        }
                        .frame(height: 8)
                        Text(percent(age.rate)).font(.caption.weight(.semibold)).frame(width: 44, alignment: .trailing)
                    }
                }
            }
            if let nonResident = demographics.nonResidentRate {
                Text("이 지역에 살지 않는 방문자가 \(percent(nonResident))예요.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// 백분율을 소수 한 자리로 표시합니다.
    ///
    /// - Parameter value: 0~100 사이 값입니다.
    /// - Returns: `23.2%` 형태의 문구입니다.
    private func percent(
        _ value: Double
    ) -> String {
        String(format: "%.1f%%", value)
    }

    /// 연령대 이름을 만듭니다.
    ///
    /// - Parameter decade: 연령대 시작 나이입니다.
    /// - Returns: `10세 미만`, `20대`, `70대 이상` 같은 이름입니다.
    private func ageTitle(
        _ decade: Int
    ) -> String {
        switch decade {
        case 0: "10세 미만"
        case 70: "70대 이상"
        default: "\(decade)대"
        }
    }
}

/// 카드 결제 기반 상권 활성도를 보여 줍니다.
struct CommerceSection: View {
    let commerce: CommerceSummary

    var body: some View {
        DetailSection("주변 상권", trailing: commerce.activity) {
            VStack(spacing: 0) {
                ForEach(Array(commerce.categories.enumerated()), id: \.offset) { index, category in
                    HStack {
                        Text(category.name)
                        Spacer()
                        Text(category.activity).fontWeight(.semibold)
                    }
                    .font(.subheadline)
                    .frame(minHeight: 40)
                    if index < commerce.categories.count - 1 { Divider() }
                }
            }
            Text("카드 결제 데이터 기준").font(.caption).foregroundStyle(.secondary)
        }
    }
}

/// 주변 지하철 도착, 도로 소통, 주차장 수를 보여 줍니다.
struct MoveSection: View {
    let detail: PlaceDetail

    var body: some View {
        DetailSection("가는 방법") {
            ForEach(Array(detail.subwayArrivals.prefix(4).enumerated()), id: \.offset) { _, arrival in
                HStack {
                    Text("\(arrival.stationName) \(arrival.line)").font(.subheadline.weight(.semibold))
                    Text(arrival.direction).font(.footnote).foregroundStyle(.secondary).lineLimit(1)
                    Spacer()
                    Text(arrival.message).font(.footnote.weight(.semibold))
                }
            }
            HStack(spacing: 10) {
                InfoTile(title: "주변 도로", value: detail.roadStatus ?? "정보 없음")
                InfoTile(title: "주차장", value: "\(detail.parkingLotCount)곳")
            }
        }
    }
}

/// 제목과 값 하나를 보여 주는 작은 카드입니다.
struct InfoTile: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.subheadline.weight(.bold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }
}

/// 기온, 하늘, 강수와 미세먼지를 보여 줍니다.
struct WeatherSection: View {
    let weather: WeatherSummary

    var body: some View {
        DetailSection("날씨") {
            HStack(spacing: 16) {
                Text(String(format: "%.1f°", weather.temperature)).font(.largeTitle.weight(.semibold))
                VStack(alignment: .leading, spacing: 2) {
                    Text([weather.sky, weather.precipitationMessage].compactMap { $0 }.joined(separator: " · "))
                        .font(.footnote)
                    Text("미세먼지 \(weather.fineDust ?? "정보 없음") · 초미세먼지 \(weather.ultraFineDust ?? "정보 없음")")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

/// 주변 문화행사를 최대 세 건 보여 줍니다.
struct EventsSection: View {
    let events: [PlaceEvent]

    var body: some View {
        DetailSection("주변 행사", trailing: "\(events.count)건") {
            ForEach(Array(events.prefix(3).enumerated()), id: \.offset) { _, event in
                EventRow(event: event)
            }
        }
    }
}

/// 행사 하나입니다. 링크가 있으면 눌러서 열 수 있습니다.
struct EventRow: View {
    let event: PlaceEvent

    var body: some View {
        let content = VStack(alignment: .leading, spacing: 2) {
            Text(event.name).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
            Text([event.period, event.venue].compactMap { $0 }.joined(separator: " · "))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: 44)
        if let url = event.url {
            Link(destination: url) { content }
        } else {
            content
        }
    }
}

/// 상세 조회 실패 안내와 다시 시도 버튼입니다.
struct DetailErrorView: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Text(message).font(.subheadline).foregroundStyle(.secondary)
            Button("다시 시도", action: onRetry).buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
    }
}
