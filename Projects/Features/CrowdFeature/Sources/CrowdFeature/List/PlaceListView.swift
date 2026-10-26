import ComposableArchitecture
import Domain
import SwiftUI

/// 121곳을 분류 탭, 검색, 정렬로 살펴보는 목록 화면입니다.
struct PlaceListView: View {
    @Bindable var store: StoreOf<PlaceListFeature>

    var body: some View {
        let places = store.visiblePlaces
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                PlaceSearchField(text: $store.searchText)
                CategoryChips(selected: store.category) { store.send(.categoryTapped($0)) }
            }
            .padding(.bottom, 8)

            HStack {
                Text("\(places.count)곳")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    store.send(.sortToggled)
                } label: {
                    HStack(spacing: 4) {
                        Text(store.sort == .crowding ? "붐비는 순" : "인구 많은 순")
                        Image(systemName: "arrow.up.arrow.down")
                    }
                    .font(.footnote.weight(.semibold))
                    .frame(minHeight: 36)
                }
                .buttonStyle(.plain)
                .accessibilityHint("정렬 기준을 바꿉니다")
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
                    ContentUnavailableView.search(text: store.searchText)
                }
            }
        }
        .navigationTitle("장소 목록")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// 목록 상단의 장소 검색 입력란입니다.
struct PlaceSearchField: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("121곳 중에서 찾기", text: $text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .accessibilityIdentifier("crowd-list-search-field")
        }
        .padding(.horizontal, 14)
        .frame(height: 44)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
    }
}
