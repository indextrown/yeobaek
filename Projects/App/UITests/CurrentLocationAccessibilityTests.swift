import XCTest

/// 두 지도 화면이 합의된 내 위치 접근성 계약을 제공하는지 검증합니다.
@MainActor
final class CurrentLocationAccessibilityTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchEnvironment["UITEST_LOCATION_SCENARIO"] = "success"
    }

    override func tearDownWithError() throws {
        app = nil
    }

    func testInitialProviderIsMapKitAndCurrentLocationControlIsAccessible() throws {
        app.launch()
        let mapKitSegment = app.buttons["MapKit"]
        let currentLocationButton = app.buttons["mapkit-current-location-button"]

        XCTAssertTrue(mapKitSegment.waitForExistence(timeout: 10))
        XCTAssertTrue(mapKitSegment.isSelected)
        XCTAssertTrue(app.descendants(matching: .any)["mapkit-map"].waitForExistence(timeout: 10))
        XCTAssertTrue(currentLocationButton.waitForExistence(timeout: 10))
        XCTAssertEqual(currentLocationButton.label, "내 위치로 이동")
        try waitUntilEnabled(currentLocationButton)
        XCTAssertTrue(currentLocationButton.isEnabled)

        let map = app.descendants(matching: .any)["mapkit-map"]
        try waitUntilValue(map, equals: "현재 위치 중심")
        map.swipeLeft()
        try waitUntilValue(map, equals: "사용자 이동 위치")
        currentLocationButton.tap()
        try waitUntilEnabled(currentLocationButton)
        try waitUntilValue(map, equals: "현재 위치 중심")
    }

    func testSwitchingToMapboxExposesItsCurrentLocationControlWhenTokenIsValid() throws {
        app.launch()
        let mapboxSegment = app.buttons["Mapbox"]

        XCTAssertTrue(mapboxSegment.waitForExistence(timeout: 10))
        mapboxSegment.tap()
        XCTAssertTrue(mapboxSegment.isSelected)

        let currentLocationButton = app.buttons["mapbox-current-location-button"]
        XCTAssertTrue(app.descendants(matching: .any)["mapbox-map"].waitForExistence(timeout: 10))
        XCTAssertTrue(currentLocationButton.waitForExistence(timeout: 10))
        XCTAssertEqual(currentLocationButton.label, "내 위치로 이동")
        try waitUntilEnabled(currentLocationButton)
        XCTAssertTrue(currentLocationButton.isEnabled)
        assertDoesNotOverlapAnotherButton(currentLocationButton)

        let map = app.descendants(matching: .any)["mapbox-map"]
        try waitUntilValue(map, equals: "현재 위치 중심")
        map.swipeLeft()
        try waitUntilValue(map, equals: "사용자 이동 위치")
        currentLocationButton.tap()
        try waitUntilEnabled(currentLocationButton)
        try waitUntilValue(map, equals: "현재 위치 중심")
    }

    func testMapboxWithoutTokenKeepsGuideAndDoesNotExposeLocationControl() {
        app.launchEnvironment["UITEST_MAPBOX_ACCESS_TOKEN"] = ""
        app.launch()
        let mapboxSegment = app.buttons["Mapbox"]

        XCTAssertTrue(mapboxSegment.waitForExistence(timeout: 10))
        mapboxSegment.tap()

        let tokenGuide = app.staticTexts["Mapbox 토큰이 필요해요"]
        XCTAssertTrue(tokenGuide.waitForExistence(timeout: 10))

        XCTAssertFalse(app.buttons["mapbox-current-location-button"].exists)
        XCTAssertFalse(app.progressIndicators["mapbox-current-location-progress"].exists)
        XCTAssertFalse(app.staticTexts["mapbox-location-authorization-message"].exists)
    }

    func testCurrentLocationControlsUseTheSamePlacement() throws {
        app.launch()
        let mapKitButton = app.buttons["mapkit-current-location-button"]

        XCTAssertTrue(mapKitButton.waitForExistence(timeout: 10))
        try waitUntilEnabled(mapKitButton)
        let mapKitFrame = mapKitButton.frame

        let mapboxSegment = app.buttons["Mapbox"]
        XCTAssertTrue(mapboxSegment.waitForExistence(timeout: 10))
        mapboxSegment.tap()

        let mapboxButton = app.buttons["mapbox-current-location-button"]
        XCTAssertTrue(mapboxButton.waitForExistence(timeout: 10))
        try waitUntilEnabled(mapboxButton)
        let mapboxFrame = mapboxButton.frame

        XCTAssertEqual(mapKitFrame.minX, mapboxFrame.minX, accuracy: 1)
        XCTAssertEqual(mapKitFrame.minY, mapboxFrame.minY, accuracy: 1)
        XCTAssertEqual(mapKitFrame.width, mapboxFrame.width, accuracy: 1)
        XCTAssertEqual(mapKitFrame.height, mapboxFrame.height, accuracy: 1)
    }

    func testReturningToMapKitDoesNotRestartAutomaticLocationRequest() throws {
        app.launchEnvironment["UITEST_MAPBOX_ACCESS_TOKEN"] = ""
        app.launch()
        let mapKitSegment = app.buttons["MapKit"]
        let mapboxSegment = app.buttons["Mapbox"]
        let currentLocationButton = app.buttons["mapkit-current-location-button"]

        XCTAssertTrue(currentLocationButton.waitForExistence(timeout: 10))
        try waitUntilEnabled(currentLocationButton)
        let map = app.descendants(matching: .any)["mapkit-map"]
        map.swipeLeft()
        try waitUntilValue(map, equals: "사용자 이동 위치")

        mapboxSegment.tap()
        XCTAssertTrue(mapboxSegment.isSelected)
        mapKitSegment.tap()

        XCTAssertTrue(mapKitSegment.isSelected)
        XCTAssertTrue(currentLocationButton.waitForExistence(timeout: 10))
        XCTAssertTrue(currentLocationButton.isEnabled)
        try assertRemainsAbsent(
            app.progressIndicators["mapkit-current-location-progress"],
            duration: 1
        )
        XCTAssertEqual(map.value as? String, "사용자 이동 위치")
    }

    func testReturningToMapboxDoesNotRestartAutomaticLocationRequest() throws {
        app.launch()
        let mapKitSegment = app.buttons["MapKit"]
        let mapboxSegment = app.buttons["Mapbox"]
        let currentLocationButton = app.buttons["mapbox-current-location-button"]

        XCTAssertTrue(mapboxSegment.waitForExistence(timeout: 10))
        mapboxSegment.tap()
        XCTAssertTrue(currentLocationButton.waitForExistence(timeout: 10))
        try waitUntilEnabled(currentLocationButton)
        let map = app.descendants(matching: .any)["mapbox-map"]
        map.swipeLeft()
        try waitUntilValue(map, equals: "사용자 이동 위치")

        mapKitSegment.tap()
        XCTAssertTrue(mapKitSegment.isSelected)
        mapboxSegment.tap()

        XCTAssertTrue(mapboxSegment.isSelected)
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
