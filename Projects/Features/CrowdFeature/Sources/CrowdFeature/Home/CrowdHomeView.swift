import ComposableArchitecture
import Domain
import SwiftUI

/// 홈 시트 단계와 지도 버튼 배치를 맞추는 크기입니다. 높이는 안전 영역을 뺀 값입니다.
public enum CrowdHomeLayout {
    /// 제목과 요약만 보이는 접힌 높이입니다.
    public static let collapsedHeight: CGFloat = 116

    /// 분포와 붐비는 순 세 곳이 보이는 기본 높이입니다.
    public static let mediumHeight: CGFloat = 330

    /// 펼친 높이의 화면 대비 비율입니다.
    static let largeRatio: CGFloat = 0.82

    /// 시작할 때 지도의 내 위치 버튼을 시트 위에 띄우기 위한 아래 여백입니다.
    public static var mapControlsBottomInset: CGFloat { controlsInset(forSheetHeight: mediumHeight) }

    /// 시트 높이에 맞는 내 위치 버튼 여백입니다. 시트를 펼치면 버튼은 기본 높이에 머물러 시트 아래로 가려집니다.
    ///
    /// - Parameter height: 현재 시트 높이입니다.
    /// - Returns: 화면 아래 안전 영역에서 버튼까지의 거리입니다.
    public static func controlsInset(
        forSheetHeight height: CGFloat
    ) -> CGFloat {
        min(height, mediumHeight) + 16
    }
}

/// 지도 위에 검색, 분류, 기준 시각과 혼잡도 요약 시트를 올리고 목록·상세로 이동하는 홈 화면입니다.
///
/// 지도는 App이 주입합니다. CrowdFeature는 지도 구현을 알지 못합니다.
public struct CrowdHomeView<Map: View>: View {
    @Bindable private var store: StoreOf<CrowdHomeFeature>
    private let map: Map
    private let onSheetHeightChange: (CGFloat) -> Void

    /// 홈 Store와 바탕 지도로 화면을 만듭니다.
    ///
    /// - Parameters:
    ///   - store: 홈과 이동 경로를 관리하는 Store입니다.
    ///   - onSheetHeightChange: 시트 높이가 바뀌면 지도 버튼 여백을 맞출 수 있도록 높이를 전달합니다.
    ///   - map: 시트 아래에 깔 지도 화면입니다.
    public init(
        store: StoreOf<CrowdHomeFeature>,
        onSheetHeightChange: @escaping (CGFloat) -> Void = { _ in },
        @ViewBuilder map: () -> Map
    ) {
        self.store = store
        self.onSheetHeightChange = onSheetHeightChange
        self.map = map()
    }

    public var body: some View {
        NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
            ZStack(alignment: .bottom) {
                map.ignoresSafeArea()

                VStack(alignment: .leading, spacing: 10) {
                    HomeSearchBar(
                        onSearch: { store.send(.searchTapped) },
                        onShowList: { store.send(.showAllTapped) }
                    )
                    .padding(.horizontal, 16)
                    CategoryChips(selected: store.category) { store.send(.categoryTapped($0)) }
                    if let observedAt = store.latestObservedAt {
                        FreshnessPill(observedAt: observedAt)
                            .padding(.horizontal, 16)
                    }
                    Spacer()
                }
                .padding(.top, 8)

                HomeSummarySheet(
                    title: store.category?.rawValue ?? "서울 주요 \(store.places.count)곳",
                    summary: HomeSummaryText.make(
                        counts: store.levelCounts,
                        isLoading: store.isLoading,
                        loadedCount: store.snapshots.count,
                        totalCount: store.places.count,
                        catalogError: store.catalogErrorMessage
                    ),
                    counts: store.levelCounts,
                    rankedPlaces: store.rankedPlaces.map { ($0, store.snapshots[$0.id]) },
                    failedCount: store.failedPlaceIDs.count,
                    onShowAll: { store.send(.showAllTapped) },
                    onSelectPlace: { store.send(.placeTapped($0)) },
                    onRetry: { store.send(.retryTapped) },
                    onHeightChange: onSheetHeightChange
                )
            }
            .toolbar(.hidden, for: .navigationBar)
            .onAppear { store.send(.onAppear) }
        } destination: { store in
            switch store.case {
            case let .list(store):
                PlaceListView(store: store)
            case let .detail(store):
                PlaceDetailView(store: store)
            }
        }
    }
}

/// 장소 검색으로 이동하는 검색창 모양 버튼과 목록 버튼입니다.
struct HomeSearchBar: View {
    let onSearch: () -> Void
    let onShowList: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onSearch) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    Text("장소 이름으로 찾기").foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .frame(height: 48)
                .background(Color(uiColor: .systemBackground), in: RoundedRectangle(cornerRadius: 14))
                .shadow(color: .black.opacity(0.1), radius: 5, y: 2)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("crowd-search-button")

            Button(action: onShowList) {
                Image(systemName: "list.bullet")
                    .font(.body.weight(.semibold))
                    .frame(width: 48, height: 48)
                    .background(Color(uiColor: .systemBackground), in: RoundedRectangle(cornerRadius: 14))
                    .shadow(color: .black.opacity(0.1), radius: 5, y: 2)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("목록으로 보기")
        }
    }
}

/// 원천 데이터 기준 시각과 갱신 주기를 알려 주는 작은 표시입니다.
struct FreshnessPill: View {
    let observedAt: Date

    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(CongestionLevel.relaxed.fillColor).frame(width: 6, height: 6)
                .accessibilityHidden(true)
            Text("\(CrowdFormat.time(observedAt)) 기준 · 5분마다 갱신")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.regularMaterial, in: Capsule())
    }
}

/// 단계별 분포와 붐비는 순을 보여 주는 홈 하단 시트입니다.
///
/// 손잡이와 제목 영역을 끌어 접힘·기본·펼침 세 단계로 바꿉니다.
/// 기본 단계는 붐비는 순 세 곳, 펼침 단계는 받은 장소 전체를 스크롤로 보여 줍니다.
struct HomeSummarySheet: View {
    let title: String
    let summary: String
    let counts: [CrowdRanking.LevelCount]
    let rankedPlaces: [(Place, CrowdSnapshot?)]
    let failedCount: Int
    let onShowAll: () -> Void
    let onSelectPlace: (Place.ID) -> Void
    let onRetry: () -> Void
    let onHeightChange: (CGFloat) -> Void

    @State private var restingHeight = CrowdHomeLayout.mediumHeight
    @GestureState private var dragOffset: CGFloat = 0

    var body: some View {
        GeometryReader { proxy in
            let largeHeight = max(CrowdHomeLayout.mediumHeight, proxy.size.height * CrowdHomeLayout.largeRatio)
            let height = min(max(restingHeight - dragOffset, CrowdHomeLayout.collapsedHeight), largeHeight)
            let isExpanded = height > CrowdHomeLayout.mediumHeight + 40

            VStack(alignment: .leading, spacing: 16) {
                SheetHeader(
                    title: title,
                    summary: summary,
                    onShowAll: onShowAll,
                    onStep: { step(by: $0, largeHeight: largeHeight) }
                )
                .gesture(
                    // 시트가 손가락을 따라 움직이므로 시트 기준 좌표로 재면 이동 거리가 흔들립니다. 화면 기준으로 잽니다.
                    DragGesture(coordinateSpace: .global)
                        .updating($dragOffset) { value, offset, _ in offset = value.translation.height }
                        .onEnded { value in
                            settle(projectedHeight: restingHeight - value.predictedEndTranslation.height, largeHeight: largeHeight)
                        }
                )

                if height > CrowdHomeLayout.collapsedHeight + 60 {
                    LevelDistribution(counts: counts)
                    RankingList(
                        places: isExpanded ? rankedPlaces : Array(rankedPlaces.prefix(3)),
                        isScrollable: isExpanded,
                        failedCount: failedCount,
                        onSelectPlace: onSelectPlace,
                        onRetry: onRetry
                    )
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .frame(height: height, alignment: .top)
            .frame(maxWidth: .infinity)
            .clipped()
            .background(
                UnevenRoundedRectangle(topLeadingRadius: 24, topTrailingRadius: 24)
                    .fill(Color(uiColor: .systemBackground))
                    .shadow(color: .black.opacity(0.1), radius: 10, y: -4)
                    .ignoresSafeArea(edges: .bottom)
            )
            .frame(maxHeight: .infinity, alignment: .bottom)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("crowd-summary-sheet")
    }

    /// 끌기를 마친 위치에서 가장 가까운 단계로 맞춥니다.
    ///
    /// - Parameters:
    ///   - projectedHeight: 손을 뗀 뒤 관성까지 반영한 예상 높이입니다.
    ///   - largeHeight: 현재 화면의 펼침 높이입니다.
    private func settle(
        projectedHeight: CGFloat,
        largeHeight: CGFloat
    ) {
        let detents = [CrowdHomeLayout.collapsedHeight, CrowdHomeLayout.mediumHeight, largeHeight]
        let nearest = detents.min { abs($0 - projectedHeight) < abs($1 - projectedHeight) } ?? CrowdHomeLayout.mediumHeight
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            restingHeight = nearest
        }
        // 끄는 동안이 아니라 단계에 자리 잡을 때 한 번만 지도 버튼을 옮깁니다.
        onHeightChange(CrowdHomeLayout.controlsInset(forSheetHeight: nearest))
    }

    /// 접근성 조절 동작으로 한 단계씩 펼치거나 접습니다.
    ///
    /// - Parameters:
    ///   - direction: 1이면 펼치고 -1이면 접습니다.
    ///   - largeHeight: 현재 화면의 펼침 높이입니다.
    private func step(
        by direction: Int,
        largeHeight: CGFloat
    ) {
        let detents = [CrowdHomeLayout.collapsedHeight, CrowdHomeLayout.mediumHeight, largeHeight]
        let current = detents.enumerated().min { abs($0.element - restingHeight) < abs($1.element - restingHeight) }?.offset ?? 1
        let next = min(max(current + direction, 0), detents.count - 1)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            restingHeight = detents[next]
        }
        onHeightChange(CrowdHomeLayout.controlsInset(forSheetHeight: detents[next]))
    }
}

/// 손잡이, 제목, 요약, 전체 보기 버튼입니다. 이 영역을 끌어 시트 높이를 바꿉니다.
struct SheetHeader: View {
    let title: String
    let summary: String
    let onShowAll: () -> Void
    let onStep: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Capsule()
                .fill(Color(uiColor: .systemGray4))
                .frame(width: 36, height: 4)
                .frame(maxWidth: .infinity)
                .accessibilityElement()
                .accessibilityLabel("시트 높이")
                .accessibilityHint("위아래로 쓸어 펼치거나 접습니다")
                .accessibilityAdjustableAction { direction in
                    onStep(direction == .increment ? 1 : -1)
                }
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.title3.weight(.bold))
                    Text(summary).font(.footnote).foregroundStyle(.secondary)
                }
                Spacer()
                Button("전체 보기", action: onShowAll)
                    .font(.subheadline.weight(.semibold))
                    .accessibilityIdentifier("crowd-show-all-button")
            }
        }
        .contentShape(Rectangle())
    }
}

/// 붐비는 순 장소 목록입니다. 펼친 시트에서는 스크롤합니다.
struct RankingList: View {
    let places: [(Place, CrowdSnapshot?)]
    let isScrollable: Bool
    let failedCount: Int
    let onSelectPlace: (Place.ID) -> Void
    let onRetry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("지금 붐비는 순").font(.footnote.weight(.semibold)).foregroundStyle(.secondary)
                Spacer()
                if failedCount > 0 {
                    Button("\(failedCount)곳 다시 불러오기", action: onRetry)
                        .font(.footnote.weight(.semibold))
                }
            }
            .padding(.bottom, 4)
            if isScrollable {
                ScrollView {
                    RankingRows(places: places, onSelectPlace: onSelectPlace)
                }
            } else {
                RankingRows(places: places, onSelectPlace: onSelectPlace)
            }
        }
    }
}

/// 붐비는 순 장소 행들입니다.
struct RankingRows: View {
    let places: [(Place, CrowdSnapshot?)]
    let onSelectPlace: (Place.ID) -> Void

    var body: some View {
        LazyVStack(spacing: 0) {
            ForEach(places, id: \.0.id) { place, snapshot in
                Button { onSelectPlace(place.id) } label: {
                    PlaceRow(place: place, snapshot: snapshot)
                }
                .buttonStyle(.plain)
                Divider()
            }
        }
    }
}

/// 단계별 장소 수를 막대와 범례로 보여 줍니다.
struct LevelDistribution: View {
    let counts: [CrowdRanking.LevelCount]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            GeometryReader { proxy in
                let visible = counts.filter { $0.count > 0 }
                let available = proxy.size.width - CGFloat(max(0, visible.count - 1)) * 2
                HStack(spacing: 2) {
                    ForEach(visible, id: \.level) { item in
                        Rectangle()
                            .fill(item.level.fillColor)
                            .frame(width: max(3, available * CGFloat(item.count) / CGFloat(max(1, total))))
                    }
                }
            }
            .frame(height: 10)
            .clipShape(Capsule())
            .accessibilityElement()
            .accessibilityLabel(counts.map { "\($0.level.title) \($0.count)곳" }.joined(separator: ", "))

            HStack(spacing: 12) {
                ForEach(counts.filter { $0.level != .unknown || $0.count > 0 }, id: \.level) { item in
                    HStack(spacing: 5) {
                        Circle().fill(item.level.fillColor).frame(width: 8, height: 8)
                        Text(item.level.title).foregroundStyle(.secondary)
                        Text("\(item.count)").fontWeight(.semibold)
                    }
                    .font(.caption)
                }
            }
            .accessibilityHidden(true)
        }
    }

    private var total: Int { counts.reduce(0) { $0 + $1.count } }
}

/// 홈 시트 제목 아래 요약 문구를 만듭니다.
enum HomeSummaryText {
    /// 분포와 불러오기 상태로 한 줄 요약을 만듭니다.
    ///
    /// - Parameters:
    ///   - counts: 단계별 장소 수입니다.
    ///   - isLoading: 아직 받는 중인 장소가 있는지 여부입니다.
    ///   - loadedCount: 받은 장소 수입니다.
    ///   - totalCount: 전체 장소 수입니다.
    ///   - catalogError: 장소 목록 오류 문구입니다. 없으면 `nil`입니다.
    /// - Returns: 시트에 보여 줄 요약 문구입니다.
    static func make(
        counts: [CrowdRanking.LevelCount],
        isLoading: Bool,
        loadedCount: Int,
        totalCount: Int,
        catalogError: String?
    ) -> String {
        if let catalogError { return catalogError }
        if isLoading { return "혼잡도를 불러오는 중이에요 (\(loadedCount)/\(totalCount))" }
        let count = { (level: CongestionLevel) in counts.first { $0.level == level }?.count ?? 0 }
        if count(.crowded) > 0 { return "붐비는 곳이 \(count(.crowded))곳 있어요." }
        if count(.busy) > 0 { return "대부분 한산해요. \(count(.busy))곳이 약간 붐벼요." }
        if count(.normal) > 0 { return "붐비는 곳은 없고 \(count(.normal))곳이 보통이에요." }
        if count(.relaxed) > 0 { return "모두 한산해요." }
        return "혼잡도 정보를 받지 못했어요."
    }
}
