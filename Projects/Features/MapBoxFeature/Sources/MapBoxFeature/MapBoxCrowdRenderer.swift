import Core
import CoreLocation
import Domain
import MapboxMaps
import UIKit

/// Domain 경계를 Mapbox의 채움, 테두리, 라벨로 변환합니다. 카메라는 자동으로 이동하지 않습니다.
///
/// 디자인 기준은 영역 안 건물만 단계 색으로 칠하는 것이지만, Mapbox의 `within` 필터는
/// 점과 선에만 동작해 건물 다각형을 고를 수 없습니다. 그래서 채움을 조금 진하게 해
/// 아래 건물까지 물든 것처럼 보이게 하고 2px 실선 테두리로 경계를 드러냅니다.
@MainActor
final class MapBoxCrowdRenderer {
    /// 반투명 채움 영역과 탭을 관리합니다.
    private let polygons: PolygonAnnotationManager

    /// 채움 투명도와 독립적인 선명한 테두리를 관리합니다.
    private let outlines: PolylineAnnotationManager

    /// 장소 이름 라벨을 관리합니다. 겹치는 라벨은 Mapbox가 숨깁니다.
    private let labels: PointAnnotationManager

    /// 영역을 눌렀을 때 장소 코드를 전달합니다.
    private let onSelectPlace: (@MainActor (Place.ID) -> Void)?

    /// 사용자가 전체 영역 보기를 선택했을 때 사용할 유효한 외곽 좌표입니다.
    private(set) var coordinates: [CLLocationCoordinate2D] = []

    /// 라벨을 보여 줄 최소 확대 수준입니다. 더 넓게 보면 기본 지도 라벨과 겹쳐 숨깁니다.
    private static let labelMinimumZoom = 13.0

    /// 마지막으로 만든 장소 라벨입니다. 확대 수준에 따라 표시하거나 숨깁니다.
    private var labelAnnotations: [PointAnnotation] = []

    /// 현재 라벨을 표시하고 있는지 여부입니다.
    private var showsLabels: Bool

    /// 스타일 로드가 끝난 지도에 혼잡도 레이어를 준비합니다.
    ///
    /// - Parameters:
    ///   - mapView: 채움과 테두리를 표시할 Mapbox 지도입니다.
    ///   - onSelectPlace: 영역을 눌렀을 때 호출할 동작입니다. `nil`이면 탭을 처리하지 않습니다.
    init(
        mapView: MapView,
        onSelectPlace: (@MainActor (Place.ID) -> Void)?
    ) {
        polygons = mapView.annotations.makePolygonAnnotationManager()
        outlines = mapView.annotations.makePolylineAnnotationManager()
        labels = mapView.annotations.makePointAnnotationManager()
        labels.textAllowOverlap = false
        showsLabels = mapView.mapboxMap.cameraState.zoom >= Self.labelMinimumZoom
        self.onSelectPlace = onSelectPlace
    }

    /// 다중 폴리곤과 내부의 빈 영역을 보존하며 혼잡도 색상을 반영합니다.
    ///
    /// - Parameter areas: 장소 코드로 경계와 혼잡도를 연결한 표시 데이터입니다.
    func render(
        areas: [MapBoxCrowdViewModel.Area]
    ) {
        var fills: [PolygonAnnotation] = []
        var lines: [PolylineAnnotation] = []
        var points: [PointAnnotation] = []
        coordinates = []

        for area in areas {
            let fillColor = StyleColor(CongestionPalette.fill(area.level))
            let placeID = area.geometry.placeID
            for (polygonIndex, polygon) in area.geometry.polygons.enumerated() {
                let sourceRings = [polygon.exteriorRing] + polygon.interiorRings
                guard sourceRings.allSatisfy(Self.isValidRing) else { continue }

                let rings = sourceRings.map { ring in
                    ring.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
                }
                let id = "\(placeID)-\(polygonIndex)"
                var fill = PolygonAnnotation(id: id, polygon: .init(rings))
                fill.fillColor = fillColor
                fill.fillOpacity = 0.24
                if let onSelectPlace {
                    fill.tapHandler = { _ in
                        MainActor.assumeIsolated { onSelectPlace(placeID) }
                        return true
                    }
                }
                fills.append(fill)

                for (ringIndex, ring) in rings.enumerated() {
                    var line = PolylineAnnotation(id: "\(id)-ring-\(ringIndex)", lineCoordinates: ring)
                    line.lineColor = fillColor
                    line.lineWidth = 2
                    line.lineJoin = .miter
                    lines.append(line)
                }
                coordinates.append(contentsOf: rings[0])
            }

            if let place = area.place, let label = place.labelCoordinate {
                var point = PointAnnotation(
                    id: "\(placeID)-label",
                    coordinate: CLLocationCoordinate2D(latitude: label.latitude, longitude: label.longitude)
                )
                point.textField = place.name
                point.textSize = 11
                point.textColor = StyleColor(CongestionPalette.text(area.level).resolvedColor(with: .init(userInterfaceStyle: .light)))
                point.textHaloColor = StyleColor(.white)
                point.textHaloWidth = 1.5
                points.append(point)
            }
        }

        polygons.annotations = fills
        outlines.annotations = lines
        labelAnnotations = points
        labels.annotations = showsLabels ? points : []
    }

    /// 확대 수준이 기준을 넘나들 때만 라벨을 표시하거나 숨깁니다.
    ///
    /// - Parameter zoom: 현재 지도 확대 수준입니다.
    func updateLabelVisibility(
        zoom: Double
    ) {
        let shouldShow = zoom >= Self.labelMinimumZoom
        guard shouldShow != showsLabels else { return }
        showsLabels = shouldShow
        labels.annotations = shouldShow ? labelAnnotations : []
    }

    /// 닫혀 있고 유효한 위경도로만 이루어진 고리인지 확인합니다.
    ///
    /// - Parameter ring: 확인할 좌표 고리입니다.
    /// - Returns: 점이 4개 이상이고 처음과 끝이 같으며 모든 좌표가 유효하면 `true`입니다.
    private static func isValidRing(
        _ ring: [GeoCoordinate]
    ) -> Bool {
        ring.count >= 4 && ring.first == ring.last && ring.allSatisfy { coordinate in
            coordinate.latitude.isFinite && coordinate.longitude.isFinite
                && (-90...90).contains(coordinate.latitude)
                && (-180...180).contains(coordinate.longitude)
        }
    }
}

/// 지도와 범례가 동일하게 사용하는 화면 전용 혼잡도 표현입니다.
@MainActor
enum MapBoxCrowdStyle {
    /// 혼잡도 단계에 대응하는 지도와 범례 색상을 반환합니다.
    ///
    /// - Parameter level: 데이터가 없으면 `.unknown`인 혼잡도 단계입니다.
    /// - Returns: 단계별 채움색입니다.
    static func color(
        for level: CongestionLevel
    ) -> UIColor {
        CongestionPalette.fill(level)
    }

    /// 색상만으로 상태를 구분하지 않도록 범례 문구를 반환합니다.
    ///
    /// - Parameter level: 화면에 표시할 혼잡도 단계입니다.
    /// - Returns: 단계에 대응하는 한국어 표시 문구입니다.
    static func title(
        for level: CongestionLevel
    ) -> String {
        CongestionPalette.title(level)
    }
}
