import CrowdPresentation
import Domain
import ThirdParty

/// UIKit 버전 홈의 입력을 상태 저장소와 화면 이동으로 바꾸는 ViewModel입니다.
///
/// SwiftUI 버전의 `CrowdHomeFeature`와 같은 규칙(`CrowdRanking`, `CrowdSummaryText`, `CrowdCopy`)으로 표시 값을 만듭니다.
public final class CrowdHomeViewModel: CrowdHomeViewModelProtocol {
    private let store: CrowdSnapshotStore

    /// 공유 상태 저장소로 ViewModel을 만듭니다.
    ///
    /// - Parameter store: 홈·목록·상세가 함께 보는 장소와 혼잡도 상태입니다.
    public init(
        store: CrowdSnapshotStore
    ) {
        self.store = store
    }

    /// 홈 입력을 표시 데이터와 화면 이동으로 바꿉니다.
    ///
    /// - Parameters:
    ///   - input: 홈 화면 입력입니다.
    ///   - disposeBag: 불러오기와 다시 불러오기 구독의 수명을 관리합니다.
    /// - Returns: 표시 데이터와 화면 이동 출력입니다.
    public func transform(
        input: CrowdHomeInput,
        disposeBag: DisposeBag
    ) -> CrowdHomeOutput {
        let store = store
        input.viewDidAppear
            .subscribe(onNext: { store.loadIfNeeded() })
            .disposed(by: disposeBag)
        input.retryTapped
            .subscribe(onNext: { store.retryFailed() })
            .disposed(by: disposeBag)

        let category = input.categorySelected
            .startWith(nil)
            .share(replay: 1)

        let viewData = Observable.combineLatest(store.state, category)
            .map { state, category in Self.viewData(state: state, category: category) }
            .distinctUntilChanged()
            .asDriver(onErrorDriveWith: .empty())

        let route = Observable.merge(
            Observable.merge(input.searchTapped, input.showListTapped, input.showAllTapped)
                .withLatestFrom(category)
                .map { CrowdUIKitRoute.list($0) },
            input.placeSelected.map { CrowdUIKitRoute.detail($0) }
        )
        .asSignal(onErrorSignalWith: .empty())

        return CrowdHomeOutput(viewData: viewData, route: route)
    }

    /// 상태와 선택한 분류로 홈 표시 데이터를 만듭니다.
    ///
    /// - Parameters:
    ///   - state: 장소와 혼잡도 상태입니다.
    ///   - category: 선택한 분류입니다. 전체면 `nil`입니다.
    /// - Returns: 홈 화면 표시 데이터입니다.
    static func viewData(
        state: CrowdSnapshotStore.State,
        category: PlaceCategory?
    ) -> CrowdHomeViewData {
        let scoped = state.places.filter { category == nil || $0.category == category }
        let counts = CrowdRanking.counts(scoped, snapshots: state.snapshots)
        let ranked = CrowdRanking.sorted(scoped, snapshots: state.snapshots, by: .crowding)
            .filter { state.snapshots[$0.id] != nil }
        return CrowdHomeViewData(
            title: CrowdCopy.homeTitle(category: category, placeCount: state.places.count),
            summary: CrowdSummaryText.make(
                counts: counts,
                isLoading: state.isLoading,
                loadedCount: state.snapshots.count,
                totalCount: state.places.count,
                catalogError: state.catalogErrorMessage
            ),
            counts: counts,
            rankedRows: ranked.map { PlaceRowData(place: $0, snapshot: state.snapshots[$0.id]) },
            failedCount: state.failedPlaceIDs.count,
            freshness: state.latestObservedAt.map(CrowdCopy.freshness),
            category: category
        )
    }
}
