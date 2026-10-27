import Core
import CrowdPresentation
import Domain
import ThirdParty
import UIKit

/// UIKit 버전 홈 화면에 표시할 값입니다. SwiftUI 버전 홈과 같은 정보를 담습니다.
public struct CrowdHomeViewData: Equatable {
    public let title: String
    public let summary: String
    public let counts: [CrowdRanking.LevelCount]
    public let rankedRows: [PlaceRowData]
    public let failedCount: Int
    public let freshness: String?
    public let category: PlaceCategory?

    /// 홈 화면 표시 값을 묶습니다.
    ///
    /// - Parameters:
    ///   - title: 시트 제목입니다.
    ///   - summary: 시트 요약 문구입니다.
    ///   - counts: 단계별 장소 수입니다.
    ///   - rankedRows: 붐비는 순서의 장소 행입니다.
    ///   - failedCount: 불러오지 못한 장소 수입니다.
    ///   - freshness: 기준 시각 문구입니다. 아직 받은 혼잡도가 없으면 `nil`입니다.
    ///   - category: 선택한 분류입니다. 전체면 `nil`입니다.
    public init(
        title: String,
        summary: String,
        counts: [CrowdRanking.LevelCount],
        rankedRows: [PlaceRowData],
        failedCount: Int,
        freshness: String?,
        category: PlaceCategory?
    ) {
        self.title = title
        self.summary = summary
        self.counts = counts
        self.rankedRows = rankedRows
        self.failedCount = failedCount
        self.freshness = freshness
        self.category = category
    }
}

/// UIKit 버전의 화면 이동입니다.
public enum CrowdUIKitRoute: Equatable, Sendable {
    case list(PlaceCategory?)
    case detail(Place.ID)
}

/// 홈 화면 View가 공개하는 입력 이벤트와 표시 데이터 타입입니다.
@MainActor
public protocol CrowdHomeViewProtocol: ViewType where ViewData == CrowdHomeViewData {
    /// 지도 화면을 넣을 바탕 영역입니다.
    var mapContainerView: UIView { get }
    var searchTapped: Observable<Void> { get }
    var showListTapped: Observable<Void> { get }
    var showAllTapped: Observable<Void> { get }
    var categorySelected: Observable<PlaceCategory?> { get }
    var retryTapped: Observable<Void> { get }
    var placeSelected: Observable<Place.ID> { get }
    /// 시트가 접힘·기본·펼침 단계에 자리 잡았을 때의 높이입니다. 안전 영역은 뺀 값입니다.
    var sheetHeightSettled: Observable<CGFloat> { get }
}

/// ViewController가 ViewModel에 전달하는 홈 입력입니다.
public struct CrowdHomeInput {
    public let viewDidAppear: Observable<Void>
    public let searchTapped: Observable<Void>
    public let showListTapped: Observable<Void>
    public let showAllTapped: Observable<Void>
    public let categorySelected: Observable<PlaceCategory?>
    public let retryTapped: Observable<Void>
    public let placeSelected: Observable<Place.ID>

    /// 홈 입력을 묶습니다.
    ///
    /// - Parameters:
    ///   - viewDidAppear: 화면 등장 이벤트입니다.
    ///   - searchTapped: 검색창 버튼 이벤트입니다.
    ///   - showListTapped: 목록 버튼 이벤트입니다.
    ///   - showAllTapped: 시트의 전체 보기 이벤트입니다.
    ///   - categorySelected: 분류 칩 선택 이벤트입니다.
    ///   - retryTapped: 다시 불러오기 이벤트입니다.
    ///   - placeSelected: 시트나 지도에서 장소를 고른 이벤트입니다.
    public init(
        viewDidAppear: Observable<Void>,
        searchTapped: Observable<Void>,
        showListTapped: Observable<Void>,
        showAllTapped: Observable<Void>,
        categorySelected: Observable<PlaceCategory?>,
        retryTapped: Observable<Void>,
        placeSelected: Observable<Place.ID>
    ) {
        self.viewDidAppear = viewDidAppear
        self.searchTapped = searchTapped
        self.showListTapped = showListTapped
        self.showAllTapped = showAllTapped
        self.categorySelected = categorySelected
        self.retryTapped = retryTapped
        self.placeSelected = placeSelected
    }
}

/// 홈 ViewModel의 출력입니다.
public struct CrowdHomeOutput {
    public let viewData: Driver<CrowdHomeViewData>
    public let route: Signal<CrowdUIKitRoute>
}

/// 홈 ViewModel 계약입니다.
@MainActor
public protocol CrowdHomeViewModelProtocol: ViewModelType where Input == CrowdHomeInput, Output == CrowdHomeOutput {}
