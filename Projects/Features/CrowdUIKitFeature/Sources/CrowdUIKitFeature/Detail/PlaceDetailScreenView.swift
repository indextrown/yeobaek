import Core
import CrowdPresentation
import Domain
import ThirdParty
import UIKit

/// 장소 상세를 세로 섹션으로 보여 주는 UIKit 화면입니다. SwiftUI 버전 `PlaceDetailView`와 같은 순서입니다.
public final class PlaceDetailScreenView: UIView, PlaceDetailViewProtocol {
    private let scrollView = UIScrollView()
    private let stack = UIStackView()
    private let retryRelay = PublishRelay<Void>()
    private let eventRelay = PublishRelay<URL>()
    private var lastData: PlaceDetailViewData?

    public var retryTapped: Observable<Void> { retryRelay.asObservable() }
    public var eventTapped: Observable<URL> { eventRelay.asObservable() }

    /// 스크롤 영역과 섹션 스택을 배치합니다.
    ///
    /// - Parameter frame: 초기 크기입니다.
    public override init(
        frame: CGRect
    ) {
        super.init(frame: frame)
        backgroundColor = .systemGroupedBackground
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scrollView)
        scrollView.addSubview(stack)
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -32),
            stack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
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

    /// 상세 표시 데이터로 섹션을 다시 그립니다.
    ///
    /// - Parameter data: 상세 표시 데이터입니다.
    public func render(
        _ data: PlaceDetailViewData
    ) {
        guard data != lastData else { return }
        lastData = data
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        stack.addArrangedSubview(DetailHeroView(data.hero))
        if let flow = data.flow { stack.addArrangedSubview(FlowSectionView(flow)) }
        if let forecast = data.forecast { stack.addArrangedSubview(ForecastSectionView(forecast)) }
        if let people = data.people { stack.addArrangedSubview(PeopleSectionView(people)) }
        if let commerce = data.commerce { stack.addArrangedSubview(CommerceSectionView(commerce)) }
        if let move = data.move { stack.addArrangedSubview(MoveSectionView(move)) }
        if let weather = data.weather { stack.addArrangedSubview(WeatherSectionView(weather)) }
        if let eventCount = data.eventCount {
            stack.addArrangedSubview(EventsSectionView(count: eventCount, events: data.events) { [weak self] url in
                self?.eventRelay.accept(url)
            })
        }
        if data.flow == nil && data.people == nil && data.move == nil {
            if data.isLoading {
                let progress = UIActivityIndicatorView(style: .medium)
                progress.startAnimating()
                let label = UILabel(text: CrowdCopy.detailLoading, style: .footnote, color: .secondaryLabel)
                let loading = UIStackView(arrangedSubviews: [progress, label])
                loading.axis = .vertical
                loading.spacing = 8
                loading.isLayoutMarginsRelativeArrangement = true
                loading.layoutMargins = UIEdgeInsets(top: 32, left: 0, bottom: 32, right: 0)
                stack.addArrangedSubview(loading)
            } else if let message = data.errorMessage {
                let label = UILabel(text: message, style: .subheadline, color: .secondaryLabel)
                label.textAlignment = .center
                let button = UIButton(configuration: .bordered())
                button.setTitle(CrowdCopy.retryDetail, for: .normal)
                button.addAction(UIAction { [weak self] _ in self?.retryRelay.accept(()) }, for: .touchUpInside)
                let error = UIStackView(arrangedSubviews: [label, button])
                error.axis = .vertical
                error.alignment = .center
                error.spacing = 12
                error.isLayoutMarginsRelativeArrangement = true
                error.layoutMargins = UIEdgeInsets(top: 24, left: 24, bottom: 24, right: 24)
                stack.addArrangedSubview(error)
            }
        }
        let source = UILabel(text: CrowdCopy.source, style: .caption2, color: .secondaryLabel, lines: 0)
        let sourceBox = UIStackView(arrangedSubviews: [source])
        sourceBox.isLayoutMarginsRelativeArrangement = true
        sourceBox.layoutMargins = UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 20)
        stack.addArrangedSubview(sourceBox)
    }
}

/// 분류, 이름, 단계, 안내 문구, 추정 인구를 보여 주는 상단 카드입니다.
final class DetailHeroView: UIView {
    /// 상단 카드를 만듭니다.
    ///
    /// - Parameter hero: 상단 카드 값입니다.
    init(
        _ hero: PlaceDetailViewData.Hero
    ) {
        super.init(frame: .zero)
        backgroundColor = .systemBackground
        let category = UILabel(text: hero.category, style: .footnote, color: .secondaryLabel)
        let name = UILabel(text: hero.name, style: .title1, isBold: true, lines: 0)

        let dot = UIView()
        dot.backgroundColor = CongestionPalette.fill(hero.level)
        dot.layer.cornerRadius = 6
        dot.widthAnchor.constraint(equalToConstant: 12).isActive = true
        dot.heightAnchor.constraint(equalToConstant: 12).isActive = true
        let level = UILabel(text: CongestionPalette.title(hero.level), style: .title3, color: CongestionPalette.text(hero.level), isBold: true)
        let time = UILabel(text: hero.observedAt, style: .caption1, color: CongestionPalette.text(hero.level))
        let levelRow = UIStackView(arrangedSubviews: [dot, level, UIView(), time])
        levelRow.spacing = 8
        levelRow.alignment = .center

        let populationTitle = UILabel(text: CrowdCopy.populationTitle, style: .footnote)
        let population = UILabel(text: hero.population, style: .title2, isBold: true)
        let populationRow = UIStackView(arrangedSubviews: [populationTitle, population, UIView()])
        populationRow.spacing = 6
        populationRow.alignment = .firstBaseline

        let card = UIStackView(arrangedSubviews: [levelRow])
        if let message = hero.message {
            card.addArrangedSubview(UILabel(text: message, style: .subheadline, lines: 0))
        }
        card.addArrangedSubview(populationRow)
        card.axis = .vertical
        card.spacing = 12
        card.isLayoutMarginsRelativeArrangement = true
        card.layoutMargins = UIEdgeInsets(top: 18, left: 18, bottom: 18, right: 18)
        card.backgroundColor = CongestionPalette.tint(hero.level)
        card.layer.cornerRadius = 16

        let titles = UIStackView(arrangedSubviews: [category, name])
        titles.axis = .vertical
        titles.spacing = 4
        let stack = UIStackView(arrangedSubviews: [titles, card])
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 20),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -20),
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
}

/// 최근 30분 승하차로 본 사람 흐름 섹션입니다.
final class FlowSectionView: SectionCardView {
    /// 흐름 섹션을 만듭니다.
    ///
    /// - Parameter flow: 흐름 섹션 값입니다.
    init(
        _ flow: PlaceDetailViewData.Flow
    ) {
        super.init(title: CrowdCopy.flowTitle)
        var badgeConfig = UIButton.Configuration.filled()
        badgeConfig.title = flow.badge
        badgeConfig.image = UIImage(systemName: flow.symbol)
        badgeConfig.imagePadding = 4
        badgeConfig.cornerStyle = .capsule
        badgeConfig.baseBackgroundColor = UIColor.systemBlue.withAlphaComponent(0.12)
        badgeConfig.baseForegroundColor = .systemBlue
        badgeConfig.buttonSize = .mini
        let badge = UIButton(configuration: badgeConfig)
        badge.isUserInteractionEnabled = false
        let description = UILabel(text: flow.description, style: .footnote, color: .secondaryLabel, lines: 0)
        let row = UIStackView(arrangedSubviews: [description, badge])
        row.alignment = .center
        row.spacing = 8
        let cards = UIStackView(arrangedSubviews: flow.cards.map { card in
            let stack = UIStackView(arrangedSubviews: [
                UILabel(text: card.title, style: .footnote, isBold: true),
                UILabel(text: card.boarding, style: .caption1),
                UILabel(text: card.alighting, style: .caption1),
            ])
            stack.axis = .vertical
            stack.spacing = 8
            stack.isLayoutMarginsRelativeArrangement = true
            stack.layoutMargins = UIEdgeInsets(top: 14, left: 14, bottom: 14, right: 14)
            stack.backgroundColor = .secondarySystemBackground
            stack.layer.cornerRadius = 12
            return stack
        })
        cards.distribution = .fillEqually
        cards.spacing = 10
        content.addArrangedSubview(row)
        content.addArrangedSubview(cards)
    }
}

/// 지금과 12시간 예측 막대 섹션입니다. 지금은 검정, 예측은 단계 색입니다.
final class ForecastSectionView: SectionCardView {
    /// 예측 섹션을 만듭니다.
    ///
    /// - Parameter forecast: 예측 섹션 값입니다.
    init(
        _ forecast: PlaceDetailViewData.Forecast
    ) {
        super.init(title: CrowdCopy.forecastTitle)
        if let quietest = forecast.quietest {
            content.addArrangedSubview(UILabel(text: quietest, style: .footnote, color: .secondaryLabel, lines: 0))
        }
        let bars = UIStackView()
        bars.distribution = .fillEqually
        bars.alignment = .bottom
        bars.spacing = 5
        bars.heightAnchor.constraint(equalToConstant: 130).isActive = true
        let labels = UIStackView()
        labels.distribution = .fillEqually
        labels.spacing = 5
        for bar in forecast.bars {
            let column = UIView()
            let fill = UIView()
            fill.backgroundColor = bar.isNow ? .label : CongestionPalette.fill(bar.level)
            fill.layer.cornerRadius = 4
            fill.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
            fill.translatesAutoresizingMaskIntoConstraints = false
            column.addSubview(fill)
            NSLayoutConstraint.activate([
                fill.leadingAnchor.constraint(equalTo: column.leadingAnchor),
                fill.trailingAnchor.constraint(equalTo: column.trailingAnchor),
                fill.bottomAnchor.constraint(equalTo: column.bottomAnchor),
                fill.heightAnchor.constraint(equalTo: column.heightAnchor, multiplier: max(0.03, bar.ratio)),
                column.heightAnchor.constraint(equalToConstant: 130),
            ])
            bars.addArrangedSubview(column)
            let label = UILabel(text: bar.label ?? " ", style: .caption2, color: .secondaryLabel)
            label.textAlignment = .center
            labels.addArrangedSubview(label)
        }
        bars.isAccessibilityElement = true
        bars.accessibilityLabel = forecast.accessibilityLabel
        let chart = UIStackView(arrangedSubviews: [bars, labels])
        chart.axis = .vertical
        chart.spacing = 4
        content.addArrangedSubview(chart)
        content.addArrangedSubview(LegendRow(items: [(.label, CrowdCopy.nowLegend), (CongestionPalette.fill(.relaxed), CrowdCopy.forecastLegend)]))
    }
}

/// 범례 색 상자와 이름들입니다.
final class LegendRow: UIStackView {
    /// 범례 줄을 만듭니다.
    ///
    /// - Parameter items: 색과 이름 목록입니다.
    init(
        items: [(UIColor, String)]
    ) {
        super.init(frame: .zero)
        spacing = 14
        for (color, title) in items {
            let swatch = UIView()
            swatch.backgroundColor = color
            swatch.layer.cornerRadius = 2
            swatch.widthAnchor.constraint(equalToConstant: 10).isActive = true
            swatch.heightAnchor.constraint(equalToConstant: 10).isActive = true
            let item = UIStackView(arrangedSubviews: [swatch, UILabel(text: title, style: .caption1, color: .secondaryLabel)])
            item.spacing = 5
            item.alignment = .center
            addArrangedSubview(item)
        }
        addArrangedSubview(UIView())
    }

    /// Storyboard 생성을 지원하지 않습니다.
    ///
    /// - Parameter coder: Storyboard가 전달하는 디코더입니다.
    @available(*, unavailable)
    required init(
        coder: NSCoder
    ) {
        fatalError("init(coder:) has not been implemented")
    }
}

/// 비율만큼 채운 가로 막대입니다.
final class RatioBarView: UIView {
    /// 막대를 만듭니다.
    ///
    /// - Parameters:
    ///   - ratio: 0~1 사이 채움 비율입니다.
    ///   - color: 채움색입니다.
    ///   - trackColor: 빈 부분 색입니다.
    init(
        ratio: Double,
        color: UIColor,
        trackColor: UIColor = .clear
    ) {
        super.init(frame: .zero)
        backgroundColor = trackColor
        layer.cornerRadius = 4
        clipsToBounds = true
        let fill = UIView()
        fill.backgroundColor = color
        fill.layer.cornerRadius = 4
        fill.translatesAutoresizingMaskIntoConstraints = false
        addSubview(fill)
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 8),
            fill.leadingAnchor.constraint(equalTo: leadingAnchor),
            fill.topAnchor.constraint(equalTo: topAnchor),
            fill.bottomAnchor.constraint(equalTo: bottomAnchor),
            fill.widthAnchor.constraint(equalTo: widthAnchor, multiplier: max(0.01, min(1, ratio))),
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
}

/// 성별, 연령대, 비거주자 비율 섹션입니다.
final class PeopleSectionView: SectionCardView {
    /// 방문자 구성 섹션을 만듭니다.
    ///
    /// - Parameter people: 방문자 구성 값입니다.
    init(
        _ people: PlaceDetailViewData.People
    ) {
        super.init(title: CrowdCopy.peopleTitle)
        let genderLabels = UIStackView(arrangedSubviews: [
            UILabel(text: people.male, style: .caption1, color: .secondaryLabel),
            UIView(),
            UILabel(text: people.female, style: .caption1, color: .secondaryLabel),
        ])
        let gender = UIStackView(arrangedSubviews: [
            genderLabels,
            RatioBarView(ratio: people.maleRatio, color: UIColor.label.withAlphaComponent(0.75), trackColor: UIColor.secondaryLabel.withAlphaComponent(0.4)),
        ])
        gender.axis = .vertical
        gender.spacing = 6
        content.addArrangedSubview(gender)
        let ages = UIStackView(arrangedSubviews: people.ages.map { age in
            let title = UILabel(text: age.title, style: .caption1, color: .secondaryLabel)
            title.widthAnchor.constraint(equalToConstant: 64).isActive = true
            let value = UILabel(text: age.value, style: .caption1, isBold: true)
            value.textAlignment = .right
            value.widthAnchor.constraint(equalToConstant: 48).isActive = true
            let row = UIStackView(arrangedSubviews: [title, RatioBarView(ratio: age.ratio, color: UIColor.label.withAlphaComponent(0.75)), value])
            row.spacing = 10
            row.alignment = .center
            return row
        })
        ages.axis = .vertical
        ages.spacing = 8
        content.addArrangedSubview(ages)
        if let nonResident = people.nonResident {
            content.addArrangedSubview(UILabel(text: nonResident, style: .footnote, color: .secondaryLabel, lines: 0))
        }
    }
}

/// 카드 결제 기반 상권 섹션입니다.
final class CommerceSectionView: SectionCardView {
    /// 상권 섹션을 만듭니다.
    ///
    /// - Parameter commerce: 상권 섹션 값입니다.
    init(
        _ commerce: PlaceDetailViewData.Commerce
    ) {
        super.init(title: CrowdCopy.commerceTitle, trailing: commerce.activity)
        let rows = UIStackView(arrangedSubviews: commerce.rows.map { category in
            let row = UIStackView(arrangedSubviews: [
                UILabel(text: category.name, style: .subheadline),
                UIView(),
                UILabel(text: category.activity, style: .subheadline, isBold: true),
            ])
            row.heightAnchor.constraint(greaterThanOrEqualToConstant: 40).isActive = true
            return row
        })
        rows.axis = .vertical
        content.addArrangedSubview(rows)
        content.addArrangedSubview(UILabel(text: CrowdCopy.commerceFootnote, style: .caption1, color: .secondaryLabel))
    }
}

/// 지하철 도착, 도로, 주차장 섹션입니다.
final class MoveSectionView: SectionCardView {
    /// 가는 방법 섹션을 만듭니다.
    ///
    /// - Parameter move: 가는 방법 값입니다.
    init(
        _ move: PlaceDetailViewData.Move
    ) {
        super.init(title: CrowdCopy.moveTitle)
        for arrival in move.arrivals {
            let direction = UILabel(text: arrival.direction, style: .footnote, color: .secondaryLabel)
            direction.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            content.addArrangedSubview(UIStackView(arrangedSubviews: [
                UILabel(text: arrival.title, style: .subheadline, isBold: true),
                direction,
                UIView(),
                UILabel(text: arrival.message, style: .footnote, isBold: true),
            ]).spaced(8))
        }
        let tiles = UIStackView(arrangedSubviews: [
            InfoTileView(title: CrowdCopy.roadTitle, value: move.road),
            InfoTileView(title: CrowdCopy.parkingTitle, value: move.parking),
        ])
        tiles.distribution = .fillEqually
        tiles.spacing = 10
        content.addArrangedSubview(tiles)
    }
}

/// 제목과 값 하나를 보여 주는 작은 카드입니다.
final class InfoTileView: UIStackView {
    /// 작은 카드를 만듭니다.
    ///
    /// - Parameters:
    ///   - title: 제목입니다.
    ///   - value: 값입니다.
    init(
        title: String,
        value: String
    ) {
        super.init(frame: .zero)
        axis = .vertical
        spacing = 4
        addArrangedSubview(UILabel(text: title, style: .caption1, color: .secondaryLabel))
        addArrangedSubview(UILabel(text: value, style: .subheadline, isBold: true))
        isLayoutMarginsRelativeArrangement = true
        layoutMargins = UIEdgeInsets(top: 12, left: 14, bottom: 12, right: 14)
        backgroundColor = .secondarySystemBackground
        layer.cornerRadius = 12
    }

    /// Storyboard 생성을 지원하지 않습니다.
    ///
    /// - Parameter coder: Storyboard가 전달하는 디코더입니다.
    @available(*, unavailable)
    required init(
        coder: NSCoder
    ) {
        fatalError("init(coder:) has not been implemented")
    }
}

/// 기온, 하늘, 미세먼지 섹션입니다.
final class WeatherSectionView: SectionCardView {
    /// 날씨 섹션을 만듭니다.
    ///
    /// - Parameter weather: 날씨 값입니다.
    init(
        _ weather: PlaceDetailViewData.Weather
    ) {
        super.init(title: CrowdCopy.weatherTitle)
        let texts = UIStackView(arrangedSubviews: [
            UILabel(text: weather.summary, style: .footnote, lines: 0),
            UILabel(text: weather.dust, style: .footnote, color: .secondaryLabel, lines: 0),
        ])
        texts.axis = .vertical
        texts.spacing = 2
        content.addArrangedSubview(UIStackView(arrangedSubviews: [
            UILabel(text: weather.temperature, style: .largeTitle, isBold: true),
            texts,
        ]).spaced(16))
    }
}

/// 주변 행사 섹션입니다. 링크가 있으면 눌러서 엽니다.
final class EventsSectionView: SectionCardView {
    /// 행사 섹션을 만듭니다.
    ///
    /// - Parameters:
    ///   - count: 전체 행사 수 문구입니다.
    ///   - events: 보여 줄 행사입니다.
    ///   - onOpen: 링크를 눌렀을 때 호출할 동작입니다.
    init(
        count: String,
        events: [PlaceDetailViewData.Event],
        onOpen: @escaping (URL) -> Void
    ) {
        super.init(title: CrowdCopy.eventsTitle, trailing: count)
        for event in events {
            let row = UIStackView(arrangedSubviews: [
                UILabel(text: event.name, style: .subheadline, color: event.url == nil ? .label : .tintColor, isBold: true, lines: 0),
                UILabel(text: event.subtitle, style: .caption1, color: .secondaryLabel, lines: 0),
            ])
            row.axis = .vertical
            row.spacing = 2
            if let url = event.url {
                row.isUserInteractionEnabled = true
                row.accessibilityTraits = .link
                row.addGestureRecognizer(EventTapGesture(url: url, onOpen: onOpen))
            }
            content.addArrangedSubview(row)
        }
    }
}

/// 행사 링크를 여는 탭 제스처입니다.
final class EventTapGesture: UITapGestureRecognizer {
    private let url: URL
    private let onOpen: (URL) -> Void

    /// 탭하면 링크를 전달하는 제스처를 만듭니다.
    ///
    /// - Parameters:
    ///   - url: 열 링크입니다.
    ///   - onOpen: 링크를 받을 동작입니다.
    init(
        url: URL,
        onOpen: @escaping (URL) -> Void
    ) {
        self.url = url
        self.onOpen = onOpen
        super.init(target: nil, action: nil)
        addTarget(self, action: #selector(handleTap))
    }

    @objc private func handleTap() {
        onOpen(url)
    }
}

extension UIStackView {
    /// 가로 간격과 가운데 정렬을 적용합니다.
    ///
    /// - Parameter spacing: 하위 View 사이 간격입니다.
    /// - Returns: 같은 스택입니다.
    func spaced(
        _ spacing: CGFloat
    ) -> UIStackView {
        self.spacing = spacing
        alignment = .center
        return self
    }
}
