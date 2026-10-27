import Core
import CrowdPresentation
import Domain
import SwiftUI

extension CongestionLevel {
    /// 지도 영역과 막대에 쓰는 채움색입니다.
    var fillColor: Color { Color(uiColor: CongestionPalette.fill(self)) }

    /// 배지 배경색입니다.
    var tintColor: Color { Color(uiColor: CongestionPalette.tint(self)) }

    /// 배지 글자색입니다.
    var textColor: Color { Color(uiColor: CongestionPalette.text(self)) }

    /// 한국어 표시 문구입니다.
    var title: String { CongestionPalette.title(self) }
}

/// 혼잡도 단계를 색과 글자로 함께 보여 주는 배지입니다.
struct LevelBadge: View {
    let level: CongestionLevel

    var body: some View {
        Text(level.title)
            .font(.caption.weight(.bold))
            .foregroundStyle(level.textColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .frame(minWidth: 64)
            .background(level.tintColor, in: RoundedRectangle(cornerRadius: 8))
    }
}

/// 장소 분류를 고르는 가로 칩 목록입니다. `nil`은 전체입니다.
struct CategoryChips: View {
    let selected: PlaceCategory?
    let onSelect: (PlaceCategory?) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                CategoryChip(title: CrowdCopy.allCategories, isSelected: selected == nil) { onSelect(nil) }
                ForEach(PlaceCategory.allCases, id: \.self) { category in
                    CategoryChip(title: category.rawValue, isSelected: selected == category) { onSelect(category) }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 2)
        }
    }
}

/// 분류 칩 하나입니다.
struct CategoryChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(isSelected ? Color(uiColor: .systemBackground) : Color.primary)
                .padding(.horizontal, 14)
                .frame(minHeight: 34)
                .background(isSelected ? Color.primary : Color(uiColor: .systemBackground), in: Capsule())
                .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// 장소 이름, 분류, 인구 범위와 단계를 한 줄로 보여 줍니다.
struct PlaceRow: View {
    let place: Place
    let snapshot: CrowdSnapshot?

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 2)
                .fill((snapshot?.level ?? .unknown).fillColor)
                .frame(width: 4, height: 32)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(place.name)
                    .font(.body.weight(.semibold))
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            LevelBadge(level: snapshot?.level ?? .unknown)
        }
        .frame(minHeight: 56)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private var subtitle: String {
        CrowdCopy.placeSubtitle(place, snapshot: snapshot)
    }
}

/// 상세 화면의 흰색 섹션 카드입니다.
struct DetailSection<Content: View>: View {
    let title: String
    let trailing: String?
    @ViewBuilder let content: Content

    /// 제목과 내용을 받아 섹션을 만듭니다.
    ///
    /// - Parameters:
    ///   - title: 섹션 제목입니다.
    ///   - trailing: 제목 오른쪽 보조 문구입니다. 없으면 `nil`입니다.
    ///   - content: 섹션 내용입니다.
    init(
        _ title: String,
        trailing: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.trailing = trailing
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(title).font(.headline)
                Spacer()
                if let trailing {
                    Text(trailing).font(.footnote).foregroundStyle(.secondary)
                }
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color(uiColor: .systemBackground))
    }
}
