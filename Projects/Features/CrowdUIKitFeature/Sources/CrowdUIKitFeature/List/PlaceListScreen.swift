import Core
import CrowdPresentation
import Domain
import ThirdParty
import UIKit

// MARK: - Contracts

/// UIKit 버전 목록 화면에 표시할 값입니다.
public struct PlaceListViewData: Equatable {
    public let searchPlaceholder: String
    public let countText: String
    public let sortTitle: String
    public let category: PlaceCategory?
    public let rows: [PlaceRowData]

    /// 목록 표시 값을 묶습니다.
    ///
    /// - Parameters:
    ///   - searchPlaceholder: 검색창 안내 문구입니다.
    ///   - countText: 보이는 장소 수 문구입니다.
    ///   - sortTitle: 현재 정렬 기준 이름입니다.
    ///   - category: 선택한 분류입니다. 전체면 `nil`입니다.
    ///   - rows: 정렬한 장소 행입니다.
    public init(
        searchPlaceholder: String,
        countText: String,
        sortTitle: String,
        category: PlaceCategory?,
        rows: [PlaceRowData]
    ) {
        self.searchPlaceholder = searchPlaceholder
        self.countText = countText
        self.sortTitle = sortTitle
        self.category = category
        self.rows = rows
    }
}

/// 목록 화면 View 계약입니다.
@MainActor
public protocol PlaceListViewProtocol: ViewType where ViewData == PlaceListViewData {
    var searchText: Observable<String> { get }
    var categorySelected: Observable<PlaceCategory?> { get }
    var sortTapped: Observable<Void> { get }
    var placeSelected: Observable<Place.ID> { get }
}

/// 목록 입력입니다.
public struct PlaceListInput {
    public let searchText: Observable<String>
    public let categorySelected: Observable<PlaceCategory?>
    public let sortTapped: Observable<Void>
    public let placeSelected: Observable<Place.ID>

    /// 목록 입력을 묶습니다.
    ///
    /// - Parameters:
    ///   - searchText: 검색어입니다.
    ///   - categorySelected: 분류 선택입니다.
    ///   - sortTapped: 정렬 버튼 입력입니다.
    ///   - placeSelected: 장소 선택입니다.
    public init(
        searchText: Observable<String>,
        categorySelected: Observable<PlaceCategory?>,
        sortTapped: Observable<Void>,
        placeSelected: Observable<Place.ID>
    ) {
        self.searchText = searchText
        self.categorySelected = categorySelected
        self.sortTapped = sortTapped
        self.placeSelected = placeSelected
    }
}

/// 목록 출력입니다.
public struct PlaceListOutput {
    public let viewData: Driver<PlaceListViewData>
    public let route: Signal<CrowdUIKitRoute>
}

/// 목록 ViewModel 계약입니다.
@MainActor
public protocol PlaceListViewModelProtocol: ViewModelType where Input == PlaceListInput, Output == PlaceListOutput {}

// MARK: - ViewModel

/// 분류, 검색, 정렬을 적용해 목록 표시 데이터를 만드는 ViewModel입니다.
public final class PlaceListViewModel: PlaceListViewModelProtocol {
    private let store: CrowdSnapshotStore
    private let initialCategory: PlaceCategory?

    /// 공유 상태와 처음 선택할 분류로 ViewModel을 만듭니다.
    ///
    /// - Parameters:
    ///   - store: 장소와 혼잡도 상태입니다.
    ///   - initialCategory: 처음 선택할 분류입니다. 전체면 `nil`입니다.
    public init(
        store: CrowdSnapshotStore,
        initialCategory: PlaceCategory?
    ) {
        self.store = store
        self.initialCategory = initialCategory
    }

    /// 목록 입력을 표시 데이터와 이동으로 바꿉니다.
    ///
    /// - Parameters:
    ///   - input: 목록 화면 입력입니다.
    ///   - disposeBag: 직접 구독하는 동작이 없어 사용하지 않습니다.
    /// - Returns: 목록 표시 데이터와 상세 이동입니다.
    public func transform(
        input: PlaceListInput,
        disposeBag: DisposeBag
    ) -> PlaceListOutput {
        let category = input.categorySelected.startWith(initialCategory)
        let search = input.searchText.startWith("")
        let sort = input.sortTapped
            .scan(CrowdRanking.Sort.crowding) { current, _ in current == .crowding ? .population : .crowding }
            .startWith(.crowding)

        let viewData = Observable.combineLatest(store.state, category, search, sort)
            .map { state, category, search, sort in
                Self.viewData(state: state, category: category, search: search, sort: sort)
            }
            .distinctUntilChanged()
            .asDriver(onErrorDriveWith: .empty())

        return PlaceListOutput(
            viewData: viewData,
            route: input.placeSelected.map { CrowdUIKitRoute.detail($0) }.asSignal(onErrorSignalWith: .empty())
        )
    }

    /// 상태와 선택 값으로 목록 표시 데이터를 만듭니다.
    ///
    /// - Parameters:
    ///   - state: 장소와 혼잡도 상태입니다.
    ///   - category: 선택한 분류입니다.
    ///   - search: 검색어입니다.
    ///   - sort: 정렬 기준입니다.
    /// - Returns: 목록 표시 데이터입니다.
    static func viewData(
        state: CrowdSnapshotStore.State,
        category: PlaceCategory?,
        search: String,
        sort: CrowdRanking.Sort
    ) -> PlaceListViewData {
        let keyword = search.trimmingCharacters(in: .whitespaces)
        let filtered = state.places.filter { place in
            (category == nil || place.category == category)
                && (keyword.isEmpty || place.name.localizedStandardContains(keyword))
        }
        let sorted = CrowdRanking.sorted(filtered, snapshots: state.snapshots, by: sort)
        return PlaceListViewData(
            searchPlaceholder: CrowdCopy.listSearchPlaceholder(total: state.places.count),
            countText: CrowdCopy.placeCount(sorted.count),
            sortTitle: CrowdCopy.sortTitle(sort),
            category: category,
            rows: sorted.map { PlaceRowData(place: $0, snapshot: state.snapshots[$0.id]) }
        )
    }
}

// MARK: - View

/// 검색창, 분류 칩, 개수와 정렬, 장소 표를 가진 UIKit 목록 화면입니다.
public final class PlaceListScreenView: UIView, PlaceListViewProtocol, UITableViewDataSource, UITableViewDelegate {
    private let searchField = UITextField()
    private let chips = CategoryChipsView()
    private let countLabel = UILabel(text: nil, style: .footnote, color: .secondaryLabel)
    private let sortButton = UIButton(type: .system)
    private let table = UITableView(frame: .zero, style: .plain)
    private let emptyLabel = UILabel(text: nil, style: .body, color: .secondaryLabel)
    private let selectedRelay = PublishRelay<Place.ID>()
    private let sortRelay = PublishRelay<Void>()
    private var rows: [PlaceRowData] = []

    public var searchText: Observable<String> { searchField.rx.text.orEmpty.distinctUntilChanged().asObservable() }
    public var categorySelected: Observable<PlaceCategory?> { chips.categorySelected.asObservable() }
    public var sortTapped: Observable<Void> { sortRelay.asObservable() }
    public var placeSelected: Observable<Place.ID> { selectedRelay.asObservable() }

    /// 목록 화면을 배치합니다.
    ///
    /// - Parameter frame: 초기 크기입니다.
    public override init(
        frame: CGRect
    ) {
        super.init(frame: frame)
        backgroundColor = .systemBackground

        let icon = UIImageView(image: UIImage(systemName: "magnifyingglass"))
        icon.tintColor = .secondaryLabel
        icon.contentMode = .scaleAspectFit
        icon.setContentHuggingPriority(.required, for: .horizontal)
        icon.widthAnchor.constraint(equalToConstant: 17).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 17).isActive = true
        searchField.autocapitalizationType = .none
        searchField.autocorrectionType = .no
        searchField.clearButtonMode = .whileEditing
        searchField.accessibilityIdentifier = CrowdAccessibilityID.listSearchField
        let searchBox = UIStackView(arrangedSubviews: [icon, searchField])
        searchBox.spacing = 10
        searchBox.alignment = .center
        searchBox.isLayoutMarginsRelativeArrangement = true
        searchBox.layoutMargins = UIEdgeInsets(top: 0, left: 14, bottom: 0, right: 14)
        searchBox.backgroundColor = .secondarySystemBackground
        searchBox.layer.cornerRadius = 12

        var sortConfig = UIButton.Configuration.plain()
        sortConfig.image = UIImage(systemName: "arrow.up.arrow.down")
        sortConfig.imagePlacement = .trailing
        sortConfig.imagePadding = 4
        sortConfig.baseForegroundColor = .label
        sortConfig.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(textStyle: .footnote)
        sortConfig.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var attributes = attributes
            attributes.font = UIFont.preferredFont(forTextStyle: .footnote).bold()
            return attributes
        }
        sortButton.configuration = sortConfig
        sortButton.accessibilityHint = CrowdCopy.sortHint
        sortButton.addAction(UIAction { [weak self] _ in self?.sortRelay.accept(()) }, for: .touchUpInside)
        let countRow = UIStackView(arrangedSubviews: [countLabel, UIView(), sortButton])
        countRow.alignment = .center

        table.dataSource = self
        table.delegate = self
        table.register(PlaceRowCell.self, forCellReuseIdentifier: PlaceRowCell.reuseIdentifier)
        table.separatorInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 0)
        table.clipsToBounds = false
        table.backgroundView = emptyLabel
        emptyLabel.textAlignment = .center

        [searchBox, chips, countRow, table].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            addSubview($0)
        }
        NSLayoutConstraint.activate([
            searchBox.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            searchBox.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            searchBox.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor),
            searchBox.heightAnchor.constraint(equalToConstant: 44),
            chips.leadingAnchor.constraint(equalTo: leadingAnchor),
            chips.trailingAnchor.constraint(equalTo: trailingAnchor),
            chips.topAnchor.constraint(equalTo: searchBox.bottomAnchor, constant: 12),
            chips.heightAnchor.constraint(equalToConstant: 38),
            countRow.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            countRow.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            countRow.topAnchor.constraint(equalTo: chips.bottomAnchor, constant: 8),
            countRow.heightAnchor.constraint(greaterThanOrEqualToConstant: 36),
            table.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            table.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            table.topAnchor.constraint(equalTo: countRow.bottomAnchor),
            table.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    /// Storyboard 생성을 지원하지 않습니다.
    ///
    /// - Parameter coder: Storyboard가 전달하는 디코더입니다.
    @available(*, unavailable)
    required init?(
        coder: NSCoder
    ) {
        fatalError("init(coder:) has not been implemented")
    }

    /// 목록 표시 데이터를 반영합니다.
    ///
    /// - Parameter data: 목록 표시 데이터입니다.
    public func render(
        _ data: PlaceListViewData
    ) {
        searchField.placeholder = data.searchPlaceholder
        countLabel.text = data.countText
        sortButton.configuration?.title = data.sortTitle
        chips.render(selected: data.category)
        emptyLabel.text = data.rows.isEmpty ? CrowdCopy.noSearchResults : nil
        if data.rows != rows {
            rows = data.rows
            table.reloadData()
        }
    }

    public func tableView(
        _ tableView: UITableView,
        numberOfRowsInSection section: Int
    ) -> Int {
        rows.count
    }

    public func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: PlaceRowCell.reuseIdentifier, for: indexPath)
        (cell as? PlaceRowCell)?.render(rows[indexPath.row])
        return cell
    }

    public func tableView(
        _ tableView: UITableView,
        didSelectRowAt indexPath: IndexPath
    ) {
        tableView.deselectRow(at: indexPath, animated: true)
        selectedRelay.accept(rows[indexPath.row].id)
    }
}

// MARK: - ViewController

/// UIKit 목록 화면의 수명 주기와 바인딩을 맡습니다.
public final class PlaceListViewController: UIViewController {
    private let screen: any PlaceListViewProtocol
    private let viewModel: any PlaceListViewModelProtocol
    private let onRoute: (CrowdUIKitRoute) -> Void
    private let disposeBag = DisposeBag()

    /// 목록 View, ViewModel, 이동 처리를 주입받습니다.
    ///
    /// - Parameters:
    ///   - screen: 목록 표시와 입력을 맡는 View입니다.
    ///   - viewModel: 목록 입력을 표시 데이터로 바꾸는 ViewModel입니다.
    ///   - onRoute: 상세로 이동할 때 호출할 동작입니다.
    public init(
        screen: any PlaceListViewProtocol,
        viewModel: any PlaceListViewModelProtocol,
        onRoute: @escaping (CrowdUIKitRoute) -> Void
    ) {
        self.screen = screen
        self.viewModel = viewModel
        self.onRoute = onRoute
        super.init(nibName: nil, bundle: nil)
        title = CrowdCopy.listTitle
        navigationItem.largeTitleDisplayMode = .never
    }

    /// Storyboard 생성을 지원하지 않는 코드 기반 화면입니다.
    ///
    /// - Parameter coder: Storyboard가 전달하는 디코더입니다.
    @available(*, unavailable)
    required init?(
        coder: NSCoder
    ) {
        fatalError("init(coder:) has not been implemented")
    }

    /// 주입받은 목록 View를 루트로 설치합니다.
    public override func loadView() {
        view = screen
    }

    /// Input과 Output을 한 번만 연결합니다.
    public override func viewDidLoad() {
        super.viewDidLoad()
        let output = viewModel.transform(
            input: PlaceListInput(
                searchText: screen.searchText,
                categorySelected: screen.categorySelected,
                sortTapped: screen.sortTapped,
                placeSelected: screen.placeSelected
            ),
            disposeBag: disposeBag
        )
        output.viewData
            .drive(onNext: { [weak self] data in self?.screen.render(data) })
            .disposed(by: disposeBag)
        output.route
            .emit(onNext: { [weak self] route in self?.onRoute(route) })
            .disposed(by: disposeBag)
    }
}
