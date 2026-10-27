import ComposableArchitecture
import CrowdPresentation
import Domain
import SwiftUI

/// SwiftUI 버전의 혼잡도 홈입니다. Mapbox 지도, 검색·분류·기준 시각, 내 위치 버튼, 요약 시트를 겹치고
/// 목록·상세로 이동합니다. 화면 전체가 SwiftUI이며 UIKit 화면을 섞지 않습니다.
public struct CrowdHomeView: View {
    @Bindable private var store: StoreOf<CrowdHomeFeature>
    @State private var sheetHeight = CrowdSheetLayout.mediumHeight

    /// 홈 Store로 화면을 만듭니다.
    ///
    /// - Parameter store: 지도, 위치, 시트, 이동 경로를 관리하는 Store입니다.
    public init(
        store: StoreOf<CrowdHomeFeature>
    ) {
        self.store = store
    }

    public var body: some View {
        NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
            ZStack(alignment: .bottom) {
                CrowdMapLayer(
                    areas: CrowdMapArea.make(places: store.places, areas: store.areas, snapshots: store.snapshots),
                    initialCenter: store.location.cameraCoordinate,
                    initialZoom: store.location.cameraZoom,
                    cameraCommand: store.location.cameraCommand,
                    isCenteredOnCurrentLocation: store.location.cameraIsCenteredOnCurrentLocation,
                    showsLabels: store.location.cameraZoom >= CrowdMapStyle.labelMinimumZoom,
                    onSelectPlace: { store.send(.placeTapped($0)) },
                    onCameraIdle: { store.send(.location(.cameraChanged($0, zoom: $1))) }
                )

                HomeTopOverlay(
                    category: store.category,
                    observedAt: store.latestObservedAt,
                    onSearch: { store.send(.searchTapped) },
                    onShowList: { store.send(.showAllTapped) },
                    onSelectCategory: { store.send(.categoryTapped($0)) }
                )

                if MapboxAccess.configure() {
                    LocationControls(
                        authorizationMessage: store.location.authorizationMessage,
                        isLoading: store.location.isLoading,
                        onTap: { store.send(.location(.currentLocationButtonTapped)) }
                    )
                    .padding(.bottom, CrowdSheetLayout.controlsInset(forSheetHeight: sheetHeight))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .animation(.spring(response: 0.35, dampingFraction: 0.85), value: sheetHeight)
                }

                HomeSummarySheet(
                    restingHeight: $sheetHeight,
                    title: CrowdCopy.homeTitle(category: store.category, placeCount: store.places.count),
                    summary: CrowdSummaryText.make(
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
                    onRetry: { store.send(.retryTapped) }
                )
            }
            .toolbar(.hidden, for: .navigationBar)
            .alert($store.scope(state: \.location.alert, action: \.location.alert))
            .onAppear {
                store.send(.onAppear)
                store.send(.location(.onAppear))
            }
            .onDisappear { store.send(.location(.onDisappear)) }
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

/// 검색창, 분류 칩, 기준 시각을 지도 위쪽에 겹칩니다.
struct HomeTopOverlay: View {
    let category: PlaceCategory?
    let observedAt: Date?
    let onSearch: () -> Void
    let onShowList: () -> Void
    let onSelectCategory: (PlaceCategory?) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HomeSearchBar(onSearch: onSearch, onShowList: onShowList)
                .padding(.horizontal, 16)
            CategoryChips(selected: category, onSelect: onSelectCategory)
            if let observedAt {
                FreshnessPill(observedAt: observedAt)
                    .padding(.horizontal, 16)
            }
            Spacer()
        }
        .padding(.top, 8)
    }
}

/// 권한 안내 문구와 내 위치 버튼입니다. 시트 높이에 맞춰 위아래로 움직입니다.
struct LocationControls: View {
    let authorizationMessage: String?
    let isLoading: Bool
    let onTap: () -> Void

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if let authorizationMessage {
                Text(authorizationMessage)
                    .font(.caption)
                    .padding(10)
                    .background(.regularMaterial, in: Capsule())
                    .accessibilityIdentifier(CrowdAccessibilityID.authorizationMessage)
            }
            Button(action: onTap) {
                Group {
                    if isLoading {
                        ProgressView().accessibilityIdentifier(CrowdAccessibilityID.currentLocationProgress)
                    } else {
                        Image(systemName: "location.fill")
                    }
                }
                .frame(width: 52, height: 52)
                .background(Color(uiColor: .secondarySystemBackground), in: Circle())
                .accessibilityHidden(true)
            }
            .disabled(isLoading)
            .accessibilityLabel(CrowdCopy.currentLocation)
            .accessibilityIdentifier(CrowdAccessibilityID.currentLocationButton)
            .buttonStyle(.plain)
            .contentShape(Circle())
        }
        .padding(.trailing, 16)
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
                    Text(CrowdCopy.searchPlaceholder).foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .frame(height: 48)
                .background(Color(uiColor: .systemBackground), in: RoundedRectangle(cornerRadius: 14))
                .shadow(color: .black.opacity(0.1), radius: 5, y: 2)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(CrowdAccessibilityID.searchButton)

            Button(action: onShowList) {
                Image(systemName: "list.bullet")
                    .font(.body.weight(.semibold))
                    .frame(width: 48, height: 48)
                    .background(Color(uiColor: .systemBackground), in: RoundedRectangle(cornerRadius: 14))
                    .shadow(color: .black.opacity(0.1), radius: 5, y: 2)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(CrowdCopy.showListLabel)
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
            Text(CrowdCopy.freshness(observedAt))
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
    @Binding var restingHeight: CGFloat
    let title: String
    let summary: String
    let counts: [CrowdRanking.LevelCount]
    let rankedPlaces: [(Place, CrowdSnapshot?)]
    let failedCount: Int
    let onShowAll: () -> Void
    let onSelectPlace: (Place.ID) -> Void
    let onRetry: () -> Void

    @GestureState private var dragOffset: CGFloat = 0

    var body: some View {
        GeometryReader { proxy in
            let largeHeight = max(CrowdSheetLayout.mediumHeight, proxy.size.height * CrowdSheetLayout.largeRatio)
            let height = min(max(restingHeight - dragOffset, CrowdSheetLayout.collapsedHeight), largeHeight)
            let isExpanded = height > CrowdSheetLayout.mediumHeight + 40

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

                if height > CrowdSheetLayout.collapsedHeight + 60 {
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
        .accessibilityIdentifier(CrowdAccessibilityID.summarySheet)
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
        let detents = [CrowdSheetLayout.collapsedHeight, CrowdSheetLayout.mediumHeight, largeHeight]
        let nearest = detents.min { abs($0 - projectedHeight) < abs($1 - projectedHeight) } ?? CrowdSheetLayout.mediumHeight
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            restingHeight = nearest
        }
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
        let detents = [CrowdSheetLayout.collapsedHeight, CrowdSheetLayout.mediumHeight, largeHeight]
        let current = detents.enumerated().min { abs($0.element - restingHeight) < abs($1.element - restingHeight) }?.offset ?? 1
        let next = min(max(current + direction, 0), detents.count - 1)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            restingHeight = detents[next]
        }
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
                .accessibilityLabel(CrowdCopy.sheetHandleLabel)
                .accessibilityHint(CrowdCopy.sheetHandleHint)
                .accessibilityAdjustableAction { direction in
                    onStep(direction == .increment ? 1 : -1)
                }
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.title3.weight(.bold))
                    Text(summary).font(.footnote).foregroundStyle(.secondary)
                }
                Spacer()
                Button(CrowdCopy.showAll, action: onShowAll)
                    .font(.subheadline.weight(.semibold))
                    .accessibilityIdentifier(CrowdAccessibilityID.showAllButton)
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
                Text(CrowdCopy.rankingTitle).font(.footnote.weight(.semibold)).foregroundStyle(.secondary)
                Spacer()
                if failedCount > 0 {
                    Button(CrowdCopy.retry(failedCount: failedCount), action: onRetry)
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
