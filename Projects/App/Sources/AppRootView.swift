import ComposableArchitecture
import CrowdFeature
import MapBoxFeature
import SwiftUI

/// Mapbox 지도 위에 혼잡도 홈 시트를 올리고 목록·상세 이동을 연결하는 루트 화면입니다.
struct AppRootView: View {
    @State private var store: StoreOf<CrowdHomeFeature>
    @State private var mapSession: MapBoxSession

    /// 저장소를 조립해 홈 Store와 지도 세션을 만듭니다.
    init() {
        let dependencies = AppDependencies.make()
        let store = Store(initialState: CrowdHomeFeature.State()) {
            CrowdHomeFeature()
        } withDependencies: {
            $0.crowdClient = dependencies.crowdClient
        }
        let session = MapBoxSession(
            crowdViewModel: MapBoxCrowdViewModel(
                areas: dependencies.catalog.areas,
                places: dependencies.catalog.places,
                repository: dependencies.crowdRepository,
                isMockData: false
            ),
            showsCrowdPanel: false,
            controlsBottomInset: CrowdHomeLayout.mapControlsBottomInset
        )
        session.onSelectPlace = { placeID in
            store.send(.placeTapped(placeID))
        }
        _store = State(initialValue: store)
        _mapSession = State(initialValue: session)
    }

    var body: some View {
        CrowdHomeView(store: store) {
            MapBoxFeatureView(session: mapSession)
        }
    }
}

#Preview {
    AppRootView()
}
