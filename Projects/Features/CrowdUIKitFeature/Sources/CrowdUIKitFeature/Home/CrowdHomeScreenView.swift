import Core
import CrowdPresentation
import Domain
import ThirdParty
import UIKit

/// UIKit 버전 홈 화면입니다. 지도 자리, 위쪽 검색·분류·기준 시각, 아래쪽 3단계 시트를 겹칩니다.
///
/// SwiftUI 버전의 `CrowdHomeView`와 같은 배치와 문구를 UIKit으로 그립니다.
public final class CrowdHomeScreenView: UIView, CrowdHomeViewProtocol {
    public let mapContainerView = UIView()
    private let topBar = CrowdHomeTopBarView()
    private let sheet = CrowdSheetView()

    public var searchTapped: Observable<Void> { topBar.searchTapped.asObservable() }
    public var showListTapped: Observable<Void> { topBar.showListTapped.asObservable() }
    public var showAllTapped: Observable<Void> { sheet.showAllTapped.asObservable() }
    public var categorySelected: Observable<PlaceCategory?> { topBar.chips.categorySelected.asObservable() }
    public var retryTapped: Observable<Void> { sheet.retryTapped.asObservable() }
    public var placeSelected: Observable<Place.ID> { sheet.placeSelected.asObservable() }
    public var sheetHeightSettled: Observable<CGFloat> { sheet.heightSettled.asObservable() }

    /// 지도 자리, 위쪽 겹침, 시트를 배치합니다.
    ///
    /// - Parameter frame: 초기 크기입니다.
    public override init(
        frame: CGRect
    ) {
        super.init(frame: frame)
        backgroundColor = .systemBackground
        [mapContainerView, topBar, sheet].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            addSubview($0)
        }
        NSLayoutConstraint.activate([
            mapContainerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            mapContainerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            mapContainerView.topAnchor.constraint(equalTo: topAnchor),
            mapContainerView.bottomAnchor.constraint(equalTo: bottomAnchor),
            topBar.leadingAnchor.constraint(equalTo: leadingAnchor),
            topBar.trailingAnchor.constraint(equalTo: trailingAnchor),
            topBar.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 8),
            sheet.leadingAnchor.constraint(equalTo: leadingAnchor),
            sheet.trailingAnchor.constraint(equalTo: trailingAnchor),
            sheet.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        sheet.install(in: self)
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

    /// 홈 표시 데이터를 위쪽 겹침과 시트에 반영합니다.
    ///
    /// - Parameter data: 홈 표시 데이터입니다.
    public func render(
        _ data: CrowdHomeViewData
    ) {
        topBar.render(category: data.category, freshness: data.freshness)
        sheet.render(data)
    }
}

/// 검색창 모양 버튼, 목록 버튼, 분류 칩, 기준 시각 표시입니다.
final class CrowdHomeTopBarView: UIView {
    let searchTapped = PublishRelay<Void>()
    let showListTapped = PublishRelay<Void>()
    let chips = CategoryChipsView()
    private let freshnessLabel = UILabel(text: nil, style: .caption1, color: .secondaryLabel)
    private let freshnessPill = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterial))

    /// 위쪽 겹침을 배치합니다.
    ///
    /// - Parameter frame: 초기 크기입니다.
    override init(
        frame: CGRect
    ) {
        super.init(frame: frame)
        let searchButton = UIButton(type: .system)
        var searchConfig = UIButton.Configuration.plain()
        searchConfig.image = UIImage(systemName: "magnifyingglass")
        searchConfig.imagePadding = 10
        searchConfig.title = CrowdCopy.searchPlaceholder
        searchConfig.baseForegroundColor = .secondaryLabel
        searchConfig.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16)
        searchButton.configuration = searchConfig
        searchButton.contentHorizontalAlignment = .leading
        searchButton.accessibilityIdentifier = CrowdAccessibilityID.searchButton
        searchButton.addAction(UIAction { [weak self] _ in self?.searchTapped.accept(()) }, for: .touchUpInside)
        Self.styleFloating(searchButton)

        let listButton = UIButton(type: .system)
        listButton.setImage(UIImage(systemName: "list.bullet"), for: .normal)
        listButton.tintColor = .label
        listButton.accessibilityLabel = CrowdCopy.showListLabel
        listButton.addAction(UIAction { [weak self] _ in self?.showListTapped.accept(()) }, for: .touchUpInside)
        Self.styleFloating(listButton)

        let searchRow = UIStackView(arrangedSubviews: [searchButton, listButton])
        searchRow.spacing = 8

        let dot = UIView()
        dot.backgroundColor = CongestionPalette.fill(.relaxed)
        dot.layer.cornerRadius = 3
        let pillContent = UIStackView(arrangedSubviews: [dot, freshnessLabel])
        pillContent.spacing = 6
        pillContent.alignment = .center
        pillContent.translatesAutoresizingMaskIntoConstraints = false
        freshnessPill.contentView.addSubview(pillContent)
        freshnessPill.layer.cornerRadius = 14
        freshnessPill.clipsToBounds = true

        [searchRow, chips, freshnessPill].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            addSubview($0)
        }
        NSLayoutConstraint.activate([
            searchRow.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            searchRow.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            searchRow.topAnchor.constraint(equalTo: topAnchor),
            searchButton.heightAnchor.constraint(equalToConstant: 48),
            listButton.widthAnchor.constraint(equalToConstant: 48),
            listButton.heightAnchor.constraint(equalToConstant: 48),
            chips.leadingAnchor.constraint(equalTo: leadingAnchor),
            chips.trailingAnchor.constraint(equalTo: trailingAnchor),
            chips.topAnchor.constraint(equalTo: searchRow.bottomAnchor, constant: 10),
            chips.heightAnchor.constraint(equalToConstant: 38),
            freshnessPill.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            freshnessPill.topAnchor.constraint(equalTo: chips.bottomAnchor, constant: 10),
            freshnessPill.bottomAnchor.constraint(equalTo: bottomAnchor),
            dot.widthAnchor.constraint(equalToConstant: 6),
            dot.heightAnchor.constraint(equalToConstant: 6),
            pillContent.leadingAnchor.constraint(equalTo: freshnessPill.contentView.leadingAnchor, constant: 12),
            pillContent.trailingAnchor.constraint(equalTo: freshnessPill.contentView.trailingAnchor, constant: -12),
            pillContent.topAnchor.constraint(equalTo: freshnessPill.contentView.topAnchor, constant: 6),
            pillContent.bottomAnchor.constraint(equalTo: freshnessPill.contentView.bottomAnchor, constant: -6),
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

    /// 버튼이 아닌 빈 영역의 터치는 아래 지도로 넘깁니다.
    ///
    /// - Parameters:
    ///   - point: 터치 위치입니다.
    ///   - event: 터치 이벤트입니다.
    /// - Returns: 터치를 받을 하위 View이며, 빈 영역이면 `nil`입니다.
    override func hitTest(
        _ point: CGPoint,
        with event: UIEvent?
    ) -> UIView? {
        let hit = super.hitTest(point, with: event)
        return hit === self ? nil : hit
    }

    /// 선택한 분류와 기준 시각을 표시합니다.
    ///
    /// - Parameters:
    ///   - category: 선택한 분류입니다. 전체면 `nil`입니다.
    ///   - freshness: 기준 시각 문구입니다. 없으면 표시를 숨깁니다.
    func render(
        category: PlaceCategory?,
        freshness: String?
    ) {
        chips.render(selected: category)
        freshnessLabel.text = freshness
        freshnessPill.isHidden = freshness == nil
    }

    /// 지도 위 흰색 둥근 버튼 모양을 적용합니다.
    ///
    /// - Parameter view: 꾸밀 버튼입니다.
    private static func styleFloating(
        _ view: UIView
    ) {
        view.backgroundColor = .systemBackground
        view.layer.cornerRadius = 14
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOpacity = 0.1
        view.layer.shadowRadius = 5
        view.layer.shadowOffset = CGSize(width: 0, height: 2)
    }
}

/// 손잡이와 제목 영역을 끌어 접힘·기본·펼침으로 바꾸는 홈 시트입니다.
final class CrowdSheetView: UIView, UITableViewDataSource, UITableViewDelegate {
    let showAllTapped = PublishRelay<Void>()
    let retryTapped = PublishRelay<Void>()
    let placeSelected = PublishRelay<Place.ID>()
    let heightSettled = PublishRelay<CGFloat>()

    private let handle = SheetHandleView()
    private let titleLabel = UILabel(text: nil, style: .title3, isBold: true)
    private let summaryLabel = UILabel(text: nil, style: .footnote, color: .secondaryLabel, lines: 2)
    private let distribution = LevelDistributionView()
    private let rankingTitle = UILabel(text: CrowdCopy.rankingTitle, style: .footnote, color: .secondaryLabel, isBold: true)
    private let retryButton = UIButton(type: .system)
    private let table = UITableView(frame: .zero, style: .plain)
    private let header = UIStackView()
    private var heightConstraint: NSLayoutConstraint?
    private var restingHeight = CrowdSheetLayout.mediumHeight
    private var rows: [PlaceRowData] = []
    private var visibleRows: [PlaceRowData] = []

    /// 시트 내용을 배치합니다.
    ///
    /// - Parameter frame: 초기 크기입니다.
    override init(
        frame: CGRect
    ) {
        super.init(frame: frame)
        backgroundColor = .systemBackground
        layer.cornerRadius = 24
        layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.1
        layer.shadowRadius = 10
        layer.shadowOffset = CGSize(width: 0, height: -4)
        accessibilityIdentifier = CrowdAccessibilityID.summarySheet

        let showAll = UIButton(type: .system)
        showAll.setTitle(CrowdCopy.showAll, for: .normal)
        showAll.titleLabel?.font = .preferredFont(forTextStyle: .subheadline).bold()
        showAll.accessibilityIdentifier = CrowdAccessibilityID.showAllButton
        showAll.addAction(UIAction { [weak self] _ in self?.showAllTapped.accept(()) }, for: .touchUpInside)
        showAll.setContentHuggingPriority(.required, for: .horizontal)

        let titles = UIStackView(arrangedSubviews: [titleLabel, summaryLabel])
        titles.axis = .vertical
        titles.spacing = 2
        let titleRow = UIStackView(arrangedSubviews: [titles, showAll])
        titleRow.alignment = .firstBaseline
        header.axis = .vertical
        header.spacing = 16
        header.addArrangedSubview(handle)
        header.addArrangedSubview(titleRow)
        handle.onStep = { [weak self] direction in self?.step(by: direction) }

        retryButton.titleLabel?.font = .preferredFont(forTextStyle: .footnote).bold()
        retryButton.addAction(UIAction { [weak self] _ in self?.retryTapped.accept(()) }, for: .touchUpInside)
        let rankingHeader = UIStackView(arrangedSubviews: [rankingTitle, UIView(), retryButton])

        table.dataSource = self
        table.delegate = self
        table.register(SheetPlaceRowCell.self, forCellReuseIdentifier: SheetPlaceRowCell.reuseIdentifier)
        table.backgroundColor = .clear
        table.separatorInset = .zero
        table.isScrollEnabled = false

        // 표가 숨겨지는 접힘 단계에서는 빈 공간이 남은 높이를 채웁니다.
        let spacer = UIView()
        spacer.setContentHuggingPriority(UILayoutPriority(251), for: .vertical)
        table.setContentHuggingPriority(UILayoutPriority(250), for: .vertical)
        let stack = UIStackView(arrangedSubviews: [header, distribution, rankingHeader, table, spacer])
        stack.axis = .vertical
        stack.spacing = 16
        stack.setCustomSpacing(4, after: rankingHeader)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            // SwiftUI 버전처럼 표가 아래 안전 영역까지 내려가 붐비는 순 세 곳이 모두 보이게 합니다.
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
        ])
        clipsToBounds = false

        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        header.addGestureRecognizer(pan)
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

    /// 상위 화면에 높이 제약을 설치합니다. 높이는 안전 영역 위쪽 기준입니다.
    ///
    /// - Parameter container: 시트를 담은 화면입니다.
    func install(
        in container: UIView
    ) {
        let constraint = topAnchor.constraint(
            equalTo: container.safeAreaLayoutGuide.bottomAnchor,
            constant: -restingHeight
        )
        constraint.isActive = true
        heightConstraint = constraint
        applyHeight(restingHeight)
    }

    /// 홈 표시 데이터를 반영합니다.
    ///
    /// - Parameter data: 홈 표시 데이터입니다.
    func render(
        _ data: CrowdHomeViewData
    ) {
        titleLabel.text = data.title
        summaryLabel.text = data.summary
        distribution.render(data.counts)
        retryButton.setTitle(data.failedCount > 0 ? CrowdCopy.retry(failedCount: data.failedCount) : nil, for: .normal)
        retryButton.isHidden = data.failedCount == 0
        rows = data.rankedRows
        applyHeight(currentHeight)
    }

    // MARK: - Table

    func tableView(
        _ tableView: UITableView,
        numberOfRowsInSection section: Int
    ) -> Int {
        visibleRows.count
    }

    func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: SheetPlaceRowCell.reuseIdentifier, for: indexPath)
        (cell as? PlaceRowCell)?.render(visibleRows[indexPath.row])
        return cell
    }

    func tableView(
        _ tableView: UITableView,
        didSelectRowAt indexPath: IndexPath
    ) {
        tableView.deselectRow(at: indexPath, animated: true)
        placeSelected.accept(visibleRows[indexPath.row].id)
    }

    // MARK: - Height

    private var currentHeight: CGFloat {
        -(heightConstraint?.constant ?? -restingHeight)
    }

    private var largeHeight: CGFloat {
        let available = superview?.safeAreaLayoutGuide.layoutFrame.height ?? 700
        return max(CrowdSheetLayout.mediumHeight, available * CrowdSheetLayout.largeRatio)
    }

    /// 높이를 바꾸고 단계에 맞는 내용만 보여 줍니다.
    ///
    /// - Parameter height: 안전 영역 위쪽 시트 높이입니다.
    private func applyHeight(
        _ height: CGFloat
    ) {
        heightConstraint?.constant = -height
        let showsContent = height > CrowdSheetLayout.collapsedHeight + 60
        let isExpanded = height > CrowdSheetLayout.mediumHeight + 40
        distribution.isHidden = !showsContent
        rankingTitle.superview?.isHidden = !showsContent
        table.isHidden = !showsContent
        table.isScrollEnabled = isExpanded
        let newRows = isExpanded ? rows : Array(rows.prefix(3))
        if newRows != visibleRows {
            visibleRows = newRows
            table.reloadData()
        }
    }

    /// 손잡이와 제목 영역을 끄는 동작을 처리합니다.
    ///
    /// - Parameter gesture: 끌기 제스처입니다.
    @objc private func handlePan(
        _ gesture: UIPanGestureRecognizer
    ) {
        let translation = gesture.translation(in: window).y
        switch gesture.state {
        case .changed:
            let height = min(max(restingHeight - translation, CrowdSheetLayout.collapsedHeight), largeHeight)
            applyHeight(height)
        case .ended, .cancelled:
            let projected = restingHeight - translation - gesture.velocity(in: window).y * 0.2
            settle(at: nearestDetent(to: projected))
        default:
            break
        }
    }

    /// 접근성 조절 동작으로 한 단계씩 펼치거나 접습니다.
    ///
    /// - Parameter direction: 1이면 펼치고 -1이면 접습니다.
    private func step(
        by direction: Int
    ) {
        let detents = [CrowdSheetLayout.collapsedHeight, CrowdSheetLayout.mediumHeight, largeHeight]
        let current = detents.enumerated().min { abs($0.element - restingHeight) < abs($1.element - restingHeight) }?.offset ?? 1
        settle(at: detents[min(max(current + direction, 0), detents.count - 1)])
    }

    /// 예상 높이에서 가장 가까운 단계를 고릅니다.
    ///
    /// - Parameter height: 손을 뗀 뒤 관성까지 반영한 예상 높이입니다.
    /// - Returns: 가장 가까운 단계 높이입니다.
    private func nearestDetent(
        to height: CGFloat
    ) -> CGFloat {
        [CrowdSheetLayout.collapsedHeight, CrowdSheetLayout.mediumHeight, largeHeight]
            .min { abs($0 - height) < abs($1 - height) } ?? CrowdSheetLayout.mediumHeight
    }

    /// 단계에 자리 잡고 높이를 알립니다.
    ///
    /// - Parameter height: 자리 잡을 단계 높이입니다.
    private func settle(
        at height: CGFloat
    ) {
        restingHeight = height
        UIView.animate(withDuration: 0.35, delay: 0, usingSpringWithDamping: 0.85, initialSpringVelocity: 0) {
            self.applyHeight(height)
            self.superview?.layoutIfNeeded()
        }
        heightSettled.accept(height)
    }
}

/// 시트 손잡이입니다. VoiceOver에서 위아래로 쓸어 시트 높이를 바꿀 수 있습니다.
final class SheetHandleView: UIView {
    var onStep: ((Int) -> Void)?

    /// 손잡이 막대를 배치합니다.
    ///
    /// - Parameter frame: 초기 크기입니다.
    override init(
        frame: CGRect
    ) {
        super.init(frame: frame)
        let bar = UIView()
        bar.backgroundColor = .systemGray4
        bar.layer.cornerRadius = 2
        bar.translatesAutoresizingMaskIntoConstraints = false
        addSubview(bar)
        NSLayoutConstraint.activate([
            bar.centerXAnchor.constraint(equalTo: centerXAnchor),
            bar.topAnchor.constraint(equalTo: topAnchor),
            bar.bottomAnchor.constraint(equalTo: bottomAnchor),
            bar.widthAnchor.constraint(equalToConstant: 36),
            bar.heightAnchor.constraint(equalToConstant: 4),
        ])
        isAccessibilityElement = true
        accessibilityLabel = CrowdCopy.sheetHandleLabel
        accessibilityHint = CrowdCopy.sheetHandleHint
        accessibilityTraits = .adjustable
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

    override func accessibilityIncrement() {
        onStep?(1)
    }

    override func accessibilityDecrement() {
        onStep?(-1)
    }
}
