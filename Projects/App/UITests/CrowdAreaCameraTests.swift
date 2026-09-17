import XCTest

/// Mapbox 혼잡도 범례의 전체 영역 보기 버튼이 카메라를 실제로 이동시키는지 검증합니다.
@MainActor
final class CrowdAreaCameraTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchEnvironment["UITEST_LOCATION_SCENARIO"] = "success"
    }

    override func tearDownWithError() throws {
        app = nil
    }

    func testShowCrowdAreasButtonMovesCameraAwayFromCurrentLocation() throws {
        app.launch()

        let mapboxSegment = app.buttons["Mapbox"]
        XCTAssertTrue(mapboxSegment.waitForExistence(timeout: 10))
        mapboxSegment.tap()

        let map = app.descendants(matching: .any)["mapbox-map"]
        XCTAssertTrue(map.waitForExistence(timeout: 10))
        try waitUntilValue(map, equals: "현재 위치 중심")

        let showAreasButton = app.buttons["mapbox-show-crowd-areas-button"]
        XCTAssertTrue(showAreasButton.waitForExistence(timeout: 10))
        try waitUntilEnabled(showAreasButton)
        XCTAssertTrue(showAreasButton.isHittable, "전체 영역 보기 버튼을 탭할 수 없습니다.")

        showAreasButton.tap()

        try waitUntilValue(map, equals: "사용자 이동 위치")
    }

    /// 지정한 요소가 활성화될 때까지 제한된 시간 동안 기다립니다.
    ///
    /// - Parameter element: 활성 상태를 기다릴 접근성 요소입니다.
    /// - Throws: 제한 시간 안에 요소가 활성화되지 않으면 테스트 실패를 던집니다.
    private func waitUntilEnabled(
        _ element: XCUIElement
    ) throws {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "enabled == true"),
            object: element
        )

        if XCTWaiter.wait(for: [expectation], timeout: 15) != .completed {
            XCTFail("제한 시간 안에 버튼이 활성화되지 않았습니다.")
        }
    }

    /// 지정한 요소가 기대한 접근성 값을 가질 때까지 기다립니다.
    ///
    /// - Parameters:
    ///   - element: 접근성 값 변경을 기다릴 요소입니다.
    ///   - expectedValue: 요소가 최종적으로 가져야 할 문자열 값입니다.
    /// - Throws: 제한 시간 안에 기대 값에 도달하지 않으면 테스트 실패를 던집니다.
    private func waitUntilValue(
        _ element: XCUIElement,
        equals expectedValue: String
    ) throws {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", expectedValue),
            object: element
        )

        if XCTWaiter.wait(for: [expectation], timeout: 15) != .completed {
            XCTFail("제한 시간 안에 지도 접근성 값이 \(expectedValue)이 되지 않았습니다. 현재 값은 \(String(describing: element.value))입니다.")
        }
    }
}
