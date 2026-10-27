import Core
import CrowdPresentation
import Domain
import MapboxMaps
import SwiftUI

/// Mapbox SwiftUI 지도에 그릴 장소 하나의 영역과 단계입니다.
struct CrowdMapArea: Identifiable, Equatable {
    let id: Place.ID
    let name: String
    let level: CongestionLevel
    let rings: [[CLLocationCoordinate2D]]
    let labelCoordinate: CLLocationCoordinate2D?

    static func == (
        lhs: CrowdMapArea,
        rhs: CrowdMapArea
    ) -> Bool {
        lhs.id == rhs.id && lhs.level == rhs.level && lhs.rings.count == rhs.rings.count
    }

    /// 장소, 경계, 혼잡도로 지도 영역 목록을 만듭니다. 유효하지 않은 고리는 제외합니다.
    ///
    /// - Parameters:
    ///   - places: 이름과 라벨 좌표를 가진 장소입니다.
    ///   - areas: 장소 코드별 경계입니다.
    ///   - snapshots: 장소 코드별 혼잡도입니다. 없으면 정보 없음으로 그립니다.
    /// - Returns: 다각형마다 하나씩 만든 지도 영역입니다.
    static func make(
        places: [Place],
        areas: [AreaGeometry],
        snapshots: [Place.ID: CrowdSnapshot]
    ) -> [CrowdMapArea] {
        let placesByID = Dictionary(places.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return areas.flatMap { area in
            area.polygons.enumerated().compactMap { index, polygon -> CrowdMapArea? in
                let rings = ([polygon.exteriorRing] + polygon.interiorRings).map { ring in
                    ring.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
                }
                guard rings.allSatisfy({ $0.count >= 4 && $0.first == $0.last }) else { return nil }
                let place = placesByID[area.placeID]
                return CrowdMapArea(
                    id: index == 0 ? area.placeID : "\(area.placeID)-\(index)",
                    name: place?.name ?? area.placeID,
                    level: snapshots[area.placeID]?.level ?? .unknown,
                    rings: rings,
                    labelCoordinate: index == 0 ? place?.labelCoordinate.map {
                        CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
                    } : nil
                )
            }
        }
    }

    /// 지도 영역 식별자에서 장소 코드를 꺼냅니다.
    var placeID: Place.ID {
        String(id.split(separator: "-").first ?? Substring(id))
    }
}

/// 토큰을 확인하고 Mapbox 지도 또는 토큰 안내를 보여 줍니다.
struct CrowdMapLayer: View {
    let areas: [CrowdMapArea]
    let initialCenter: LocationCoordinate
    let initialZoom: Double
    let cameraCommand: LocationCameraCommand?
    let isCenteredOnCurrentLocation: Bool
    let showsLabels: Bool
    let onSelectPlace: (Place.ID) -> Void
    let onCameraIdle: (LocationCoordinate, Double) -> Void

    var body: some View {
        if MapboxAccess.configure() {
            CrowdMapView(
                areas: areas,
                initialCenter: initialCenter,
                initialZoom: initialZoom,
                cameraCommand: cameraCommand,
                isCenteredOnCurrentLocation: isCenteredOnCurrentLocation,
                showsLabels: showsLabels,
                onSelectPlace: onSelectPlace,
                onCameraIdle: onCameraIdle
            )
        } else {
            ContentUnavailableView(
                CrowdCopy.tokenMissingTitle,
                systemImage: "key.horizontal",
                description: Text(CrowdCopy.tokenMissingDescription)
            )
        }
    }
}

/// 121곳 영역, 라벨, 현재 위치 점을 그리는 Mapbox SwiftUI 지도입니다.
///
/// UIKit 버전의 `MapBoxCrowdRenderer`와 같은 표현(24% 채움, 2px 테두리, 줌 13 이상 라벨,
/// 밤 조명 영향 없음)을 Mapbox SwiftUI API로 그립니다.
struct CrowdMapView: View {
    let areas: [CrowdMapArea]
    let cameraCommand: LocationCameraCommand?
    let isCenteredOnCurrentLocation: Bool
    let showsLabels: Bool
    let onSelectPlace: (Place.ID) -> Void
    let onCameraIdle: (LocationCoordinate, Double) -> Void

    @State private var viewport: Viewport
    @Environment(\.colorScheme) private var colorScheme

    /// 마지막 카메라에서 시작하는 지도를 만듭니다.
    ///
    /// - Parameters:
    ///   - areas: 그릴 장소 영역입니다.
    ///   - initialCenter: 처음 보여 줄 중심 좌표입니다.
    ///   - initialZoom: 처음 확대 수준입니다.
    ///   - cameraCommand: 현재 위치로 이동하라는 명령입니다.
    ///   - isCenteredOnCurrentLocation: 카메라가 현재 위치를 중심에 두고 있는지 여부입니다.
    ///   - showsLabels: 장소 이름 라벨을 표시할지 여부입니다.
    ///   - onSelectPlace: 영역을 눌렀을 때 장소 코드를 받습니다.
    ///   - onCameraIdle: 지도가 멈췄을 때 중심과 확대 수준을 받습니다.
    init(
        areas: [CrowdMapArea],
        initialCenter: LocationCoordinate,
        initialZoom: Double,
        cameraCommand: LocationCameraCommand?,
        isCenteredOnCurrentLocation: Bool,
        showsLabels: Bool,
        onSelectPlace: @escaping (Place.ID) -> Void,
        onCameraIdle: @escaping (LocationCoordinate, Double) -> Void
    ) {
        self.areas = areas
        self.cameraCommand = cameraCommand
        self.isCenteredOnCurrentLocation = isCenteredOnCurrentLocation
        self.showsLabels = showsLabels
        self.onSelectPlace = onSelectPlace
        self.onCameraIdle = onCameraIdle
        _viewport = State(initialValue: .camera(
            center: CLLocationCoordinate2D(latitude: initialCenter.latitude, longitude: initialCenter.longitude),
            zoom: initialZoom,
            bearing: 0,
            pitch: 0
        ))
    }

    var body: some View {
        MapReader { proxy in
            Map(viewport: $viewport) {
                Puck2D()

                PolygonAnnotationGroup(areas) { area in
                    PolygonAnnotation(id: area.id, polygon: Polygon(area.rings))
                        .fillColor(CongestionPalette.fill(area.level))
                        .fillOpacity(CrowdMapStyle.fillOpacity)
                        .onTapGesture { onSelectPlace(area.placeID) }
                }
                .fillEmissiveStrength(1)

                PolylineAnnotationGroup(outlines) { outline in
                    PolylineAnnotation(id: outline.id, lineCoordinates: outline.coordinates)
                        .lineColor(CongestionPalette.fill(outline.level))
                        .lineWidth(CrowdMapStyle.lineWidth)
                        .lineJoin(.miter)
                }
                .lineEmissiveStrength(1)

                if showsLabels {
                    PointAnnotationGroup(labels) { label in
                        PointAnnotation(id: label.id, coordinate: label.coordinate)
                            .textField(label.name)
                            .textSize(CrowdMapStyle.labelTextSize)
                            .textColor(labelColor(label.level))
                            .textHaloColor(colorScheme == .dark ? .black : .white)
                            .textHaloWidth(CrowdMapStyle.labelHaloWidth)
                    }
                    .textAllowOverlap(false)
                    .textEmissiveStrength(1)
                }
            }
            .mapStyle(.standard(lightPreset: colorScheme == .dark ? .night : .day))
            .ornamentOptions(OrnamentOptions(scaleBar: ScaleBarViewOptions(visibility: .hidden)))
            .onMapIdle { _ in
                guard let camera = proxy.map?.cameraState else { return }
                onCameraIdle(
                    LocationCoordinate(latitude: camera.center.latitude, longitude: camera.center.longitude),
                    camera.zoom
                )
            }
        }
        .ignoresSafeArea()
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier(CrowdAccessibilityID.map)
        .accessibilityValue(isCenteredOnCurrentLocation ? CrowdCopy.mapCentered : CrowdCopy.mapMoved)
        .onChange(of: cameraCommand) { _, command in
            guard let command else { return }
            withViewportAnimation(.easeInOut(duration: 0.35)) {
                viewport = .camera(
                    center: CLLocationCoordinate2D(
                        latitude: command.coordinate.latitude,
                        longitude: command.coordinate.longitude
                    ),
                    zoom: CurrentLocationPolicy.cameraZoom,
                    bearing: 0,
                    pitch: 0
                )
            }
        }
    }

    /// 다각형 고리마다 만든 테두리입니다.
    private var outlines: [Outline] {
        areas.flatMap { area in
            area.rings.enumerated().map { index, ring in
                Outline(id: "\(area.id)-ring-\(index)", level: area.level, coordinates: ring)
            }
        }
    }

    /// 라벨 좌표가 있는 장소의 이름 라벨입니다.
    private var labels: [Label] {
        areas.compactMap { area in
            area.labelCoordinate.map { Label(id: "\(area.id)-label", name: area.name, level: area.level, coordinate: $0) }
        }
    }

    /// 화면 모드에 맞는 라벨 글자색입니다.
    ///
    /// - Parameter level: 장소의 혼잡도 단계입니다.
    /// - Returns: 라이트·다크 모드에서 읽을 수 있는 단계 글자색입니다.
    private func labelColor(
        _ level: CongestionLevel
    ) -> UIColor {
        CongestionPalette.text(level).resolvedColor(
            with: UITraitCollection(userInterfaceStyle: colorScheme == .dark ? .dark : .light)
        )
    }

    private struct Outline: Identifiable {
        let id: String
        let level: CongestionLevel
        let coordinates: [CLLocationCoordinate2D]
    }

    private struct Label: Identifiable {
        let id: String
        let name: String
        let level: CongestionLevel
        let coordinate: CLLocationCoordinate2D
    }
}

/// Mapbox 공개 토큰을 확인하고 SDK에 설정합니다.
enum MapboxAccess {
    /// 공개 토큰이 있으면 Mapbox에 설정합니다.
    ///
    /// - Returns: `pk.`로 시작하는 토큰을 설정했으면 `true`입니다.
    @MainActor
    static func configure() -> Bool {
        guard let token = AppConfiguration.mapboxAccessToken, token.hasPrefix("pk.") else { return false }
        if MapboxOptions.accessToken != token {
            MapboxOptions.accessToken = token
        }
        return true
    }
}
