import XCTest

/// 혼잡도 홈의 지도, 요약 시트, 목록·상세 이동과 내 위치 접근성 계약을 검증합니다.
@MainActor
final class CurrentLocationAccessibilityTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchEnvironment["UITEST_LOCATION_SCENARIO"] = "success"
        app.launchEnvironment["UITEST_CROWD_SCENARIO"] = "sample"
    }

    override func tearDownWithError() throws {
        app = nil
    }

    func testHomeShowsSummarySheetAndMapboxLocationControl() throws {
        app.launch()
        let sheet = app.descendants(matching: .any)["crowd-summary-sheet"]
        let currentLocationButton = app.buttons["mapbox-current-location-button"]

        XCTAssertTrue(sheet.waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["서울 주요 121곳"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.descendants(matching: .any)["mapbox-map"].waitForExistence(timeout: 10))
        XCTAssertTrue(currentLocationButton.waitForExistence(timeout: 10))
        XCTAssertEqual(currentLocationButton.label, "내 위치로 이동")
        try waitUntilEnabled(currentLocationButton)
        XCTAssertLessThan(currentLocationButton.frame.maxY, sheet.frame.minY, "내 위치 버튼이 홈 시트에 가려졌습니다.")
        assertDoesNotOverlapAnotherButton(currentLocationButton)

        let map = app.descendants(matching: .any)["mapbox-map"]
        try waitUntilValue(map, equals: "현재 위치 중심")
        map.swipeLeft()
        try waitUntilValue(map, equals: "사용자 이동 위치")
        currentLocationButton.tap()
        try waitUntilEnabled(currentLocationButton)
        try waitUntilValue(map, equals: "현재 위치 중심")
    }

    func testShowAllOpensListAndPlaceDetail() {
        app.launch()
        let showAll = app.buttons["crowd-show-all-button"]

        XCTAssertTrue(showAll.waitForExistence(timeout: 10))
        showAll.tap()
        XCTAssertTrue(app.navigationBars["장소 목록"].waitForExistence(timeout: 10))

        let searchField = app.textFields["crowd-list-search-field"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 10))
        searchField.tap()
        searchField.typeText("광화문")
        let row = app.buttons.containing(NSPredicate(format: "label CONTAINS %@", "광화문·덕수궁")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        row.tap()

        XCTAssertTrue(app.navigationBars["광화문·덕수궁"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["앞으로 12시간"].waitForExistence(timeout: 10))
    }

    func testMapboxWithoutTokenKeepsGuideAndSummarySheet() {
        app.launchEnvironment["UITEST_MAPBOX_ACCESS_TOKEN"] = ""
        app.launch()

        let tokenGuide = app.staticTexts["Mapbox 토큰이 필요해요"]
        XCTAssertTrue(tokenGuide.waitForExistence(timeout: 10))
        XCTAssertTrue(app.descendants(matching: .any)["crowd-summary-sheet"].exists)
        XCTAssertFalse(app.buttons["mapbox-current-location-button"].exists)
        XCTAssertFalse(app.progressIndicators["mapbox-current-location-progress"].exists)
        XCTAssertFalse(app.staticTexts["mapbox-location-authorization-message"].exists)
    }

    func testReturningFromListDoesNotRestartAutomaticLocationRequest() throws {
        app.launch()
        let currentLocationButton = app.buttons["mapbox-current-location-button"]

        XCTAssertTrue(currentLocationButton.waitForExistence(timeout: 10))
        try waitUntilEnabled(currentLocationButton)
        let map = app.descendants(matching: .any)["mapbox-map"]
        map.swipeLeft()
        try waitUntilValue(map, equals: "사용자 이동 위치")

        app.buttons["crowd-show-all-button"].tap()
        XCTAssertTrue(app.navigationBars["장소 목록"].waitForExistence(timeout: 10))
        app.navigationBars.buttons.element(boundBy: 0).tap()

        XCTAssertTrue(currentLocationButton.waitForExistence(timeout: 10))
        XCTAssertTrue(currentLocationButton.isEnabled)
        try assertRemainsAbsent(
            app.progressIndicators["mapbox-current-location-progress"],
            duration: 1
        )
        XCTAssertEqual(map.value as? String, "사용자 이동 위치")
    }

    /// 지정한 요소가 활성화될 때까지 제한된 시간 동안 기다립니다.
    ///
    /// - Parameter element: 활성 상태를 기다릴 접근성 요소입니다.
    /// - Throws: 제한 시간 안에 요소가 활성화되지 않으면 테스트 실패를 던집니다.
    private func waitUntilEnabled(
        _ element: XCUIElement
    ) throws {
        let predicate = NSPredicate(format: "enabled == true")
        let expectation = XCTNSPredicateExpectation(
            predicate: predicate,
            object: element
        )
        let result = XCTWaiter.wait(
            for: [expectation],
            timeout: 15
        )

        if result != .completed {
            XCTFail("제한 시간 안에 위치 요청이 종료되지 않아 버튼이 활성화되지 않았습니다.")
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
        let predicate = NSPredicate(
            format: "value == %@",
            expectedValue
        )
        let expectation = XCTNSPredicateExpectation(
            predicate: predicate,
            object: element
        )
        let result = XCTWaiter.wait(
            for: [expectation],
            timeout: 15
        )

        if result != .completed {
            XCTFail("제한 시간 안에 카메라 상태가 \(expectedValue)(으)로 바뀌지 않았습니다.")
        }
    }

    /// 지정한 버튼이 지도 SDK를 포함한 다른 버튼의 접근성 프레임을 가리지 않는지 검증합니다.
    ///
    /// - Parameter element: 다른 버튼과 겹치지 않아야 하는 앱 버튼입니다.
    private func assertDoesNotOverlapAnotherButton(
        _ element: XCUIElement
    ) {
        let overlappingButton = app.buttons.allElementsBoundByIndex.first { candidate in
            candidate.identifier != element.identifier
                && !candidate.frame.isEmpty
                && candidate.frame.intersects(element.frame)
        }

        XCTAssertNil(
            overlappingButton,
            "내 위치 버튼이 다른 버튼의 접근성 프레임과 겹칩니다."
        )
    }

    /// 지정한 관찰 시간 동안 요소가 한 번도 나타나지 않는지 확인합니다.
    ///
    /// - Parameters:
    ///   - element: 나타나지 않아야 하는 접근성 요소입니다.
    ///   - duration: 요소 부재를 연속 관찰할 초 단위 시간입니다.
    /// - Throws: 관찰 도중 요소가 나타나면 테스트 실패를 기록합니다.
    private func assertRemainsAbsent(
        _ element: XCUIElement,
        duration: TimeInterval
    ) throws {
        let deadline = Date().addingTimeInterval(duration)
        while Date() < deadline {
            if element.exists {
                XCTFail("재진입 뒤 자동 위치 요청의 진행 표시가 다시 나타났습니다.")
                return
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
    }
}
