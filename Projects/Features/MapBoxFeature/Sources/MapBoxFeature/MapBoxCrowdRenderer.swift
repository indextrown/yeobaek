import CoreLocation
import Domain
import MapboxMaps
import UIKit

/// Domain 경계를 Mapbox의 채움과 테두리로 변환합니다. 카메라는 자동으로 이동하지 않습니다.
@MainActor
final class MapBoxCrowdRenderer {
    /// 반투명 채움 영역을 관리합니다.
    private let polygons: PolygonAnnotationManager

    /// 채움 투명도와 독립적인 선명한 테두리를 관리합니다.
    private let outlines: PolylineAnnotationManager

    /// 사용자가 전체 영역 보기를 선택했을 때 사용할 유효한 외곽 좌표입니다.
    private(set) var coordinates: [CLLocationCoordinate2D] = []

    /// 스타일 로드가 끝난 지도에 혼잡도 레이어를 준비합니다.
    ///
    /// - Parameter mapView: 채움과 테두리를 표시할 Mapbox 지도입니다.
    init(
        mapView: MapView
    ) {
        polygons = mapView.annotations.makePolygonAnnotationManager()
        outlines = mapView.annotations.makePolylineAnnotationManager()
    }

    /// 다중 폴리곤과 내부의 빈 영역을 보존하며 혼잡도 색상을 반영합니다.
    ///
    /// - Parameter areas: 장소 코드로 경계와 혼잡도를 연결한 표시 데이터입니다.
    func render(
        areas: [MapBoxCrowdArea]
    ) {
        var fills: [PolygonAnnotation] = []
        var lines: [PolylineAnnotation] = []
        coordinates = []

        for area in areas {
            let color = StyleColor(MapBoxCrowdStyle.color(for: area.level))
            for (polygonIndex, polygon) in area.geometry.polygons.enumerated() {
                let sourceRings = [polygon.exteriorRing] + polygon.interiorRings
                guard sourceRings.allSatisfy({ ring in
                    ring.count >= 4 && ring.first == ring.last && ring.allSatisfy { coordinate in
                        coordinate.latitude.isFinite && coordinate.longitude.isFinite
                            && (-90...90).contains(coordinate.latitude)
                            && (-180...180).contains(coordinate.longitude)
                    }
                }) else { continue }

                let rings = sourceRings.map { ring in
                    ring.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
                }
                let id = "\(area.geometry.placeID)-\(polygonIndex)"
                var fill = PolygonAnnotation(id: id, polygon: .init(rings))
                fill.fillColor = color
                fill.fillOpacity = 0.22
                fills.append(fill)

                for (ringIndex, ring) in rings.enumerated() {
                    var line = PolylineAnnotation(id: "\(id)-ring-\(ringIndex)", lineCoordinates: ring)
                    line.lineColor = color
                    line.lineWidth = 2
                    lines.append(line)
                }
                coordinates.append(contentsOf: rings[0])
            }
        }

        polygons.annotations = fills
        outlines.annotations = lines
    }
}

/// 지도와 범례가 동일하게 사용하는 화면 전용 혼잡도 표현입니다.
enum MapBoxCrowdStyle {
    /// 혼잡도 단계에 대응하는 지도와 범례 색상을 반환합니다.
    ///
    /// - Parameter level: 데이터가 없으면 `.unknown`인 혼잡도 단계입니다.
    /// - Returns: 단계별 색상이며, 정보 없음은 회색입니다.
    static func color(
        for level: CongestionLevel
    ) -> UIColor {
        switch level {
        case .relaxed: .systemTeal
        case .normal: .systemYellow
        case .busy: .systemOrange
        case .crowded: .systemRed
        case .unknown: .systemGray
        }
    }

    /// 색상만으로 상태를 구분하지 않도록 범례 문구를 반환합니다.
    ///
    /// - Parameter level: 화면에 표시할 혼잡도 단계입니다.
    /// - Returns: 단계에 대응하는 한국어 표시 문구입니다.
    static func title(
        for level: CongestionLevel
    ) -> String {
        switch level {
        case .relaxed: "여유"
        case .normal: "보통"
        case .busy: "약간 붐빔"
        case .crowded: "붐빔"
        case .unknown: "정보 없음"
        }
    }
}
