import ComposableArchitecture
import CrowdPresentation
import Domain
import SwiftUI

/// 121곳을 분류 탭, 검색, 정렬로 살펴보는 목록 화면입니다.
struct PlaceListView: View {
    @Bindable var store: StoreOf<PlaceListFeature>

    var body: some View {
        let places = store.visiblePlaces
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                PlaceSearchField(text: $store.searchText, placeholder: CrowdCopy.listSearchPlaceholder(total: store.places.count))
                CategoryChips(selected: store.category) { store.send(.categoryTapped($0)) }
            }
            .padding(.bottom, 8)

            HStack {
                Text(CrowdCopy.placeCount(places.count))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    store.send(.sortToggled)
                } label: {
                    HStack(spacing: 4) {
                        Text(CrowdCopy.sortTitle(store.sort))
                        Image(systemName: "arrow.up.arrow.down")
                    }
                    .font(.footnote.weight(.semibold))
                    .frame(minHeight: 36)
                }
                .buttonStyle(.plain)
                .accessibilityHint(CrowdCopy.sortHint)
            }
            .padding(.horizontal, 16)

            List(places) { place in
                Button {
                    store.send(.placeTapped(place.id))
                } label: {
                    PlaceRow(place: place, snapshot: store.snapshots[place.id])
                }
                .buttonStyle(.plain)
            }
            .listStyle(.plain)
            .overlay {
                if places.isEmpty {
                    Text(CrowdCopy.noSearchResults)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(CrowdCopy.listTitle)
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// 목록 상단의 장소 검색 입력란입니다.
struct PlaceSearchField: View {
    @Binding var text: String
    let placeholder: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField(placeholder, text: $text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .accessibilityIdentifier(CrowdAccessibilityID.listSearchField)
        }
        .padding(.horizontal, 14)
        .frame(height: 44)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
    }
}
