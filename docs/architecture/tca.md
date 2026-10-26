---
title: SwiftUI Feature에 TCA 적용하기
description: SwiftUI 기반 CrowdFeature와 MapFeature에 The Composable Architecture를 적용한 구조와 작성·테스트 기준을 설명한다.
---

# SwiftUI Feature에 TCA 적용하기

## 이 문서에서 확인할 것

Yeobaek의 지도 화면은 UIKit + RxSwift + MVVM으로 만든다. SwiftUI로 구현하는 `CrowdFeature`(홈 시트, 목록, 상세)와 `MapFeature`는 [The Composable Architecture](https://github.com/pointfreeco/swift-composable-architecture)(TCA)로 상태를 관리한다. 이 문서는 현재 `MapFeature` 코드를 기준으로 TCA 적용 방식을 설명한다.

## 패키지 연결

- `Tuist/Package.swift`에서 `swift-composable-architecture`를 `1.26.0` 이상으로 받는다.
- `Shared/ThirdParty`가 `ComposableArchitecture`를 의존하고, `CrowdFeature`와 `MapFeature`는 `ThirdParty`를 의존한다.
- `ThirdParty`는 TCA를 `@_exported`로 재노출하지 않는다. RxSwift의 `Observable`과 Observation의 `Observable` 같은 이름이 Rx 기반 모듈에서 충돌하지 않도록, TCA를 쓰는 파일에서만 `import ComposableArchitecture`를 작성한다.
- TCA는 매크로를 사용하므로 첫 빌드 때 swift-syntax를 함께 빌드한다. 명령줄 빌드는 `-skipMacroValidation`을 붙이거나 Xcode에서 매크로 사용을 허용한다.
- Xcode 27 SDK보다 낮은 최소 배포 버전을 선언한 외부 타깃은 `Tuist/Package.swift`의 `iOSTargetsBelowXcodeMinimum`, `macOSTargetsBelowXcodeMinimum` 목록으로 올린다. 패키지를 추가한 뒤 같은 오류가 나면 해당 타깃 이름을 목록에 추가한다.

## CrowdFeature 구성

| 타입 | 역할 |
| --- | --- |
| `CrowdHomeFeature` | 121곳 혼잡도, 분류 선택, 붐비는 순, `StackState` 이동 경로를 관리한다. `Path`는 `list`, `detail` 두 화면이다. |
| `PlaceListFeature` | 분류·검색·정렬을 적용한 목록이다. 장소를 고르면 `delegate(.openDetail)`로 홈에 알린다. |
| `PlaceDetailFeature` | 장소 상세(`citydata`)를 열 때 불러오고, 실패하면 다시 시도할 수 있다. |
| `CrowdClient` | `@DependencyClient`. `catalog`, `snapshot`, `detail`을 제공한다. `TestDependencyKey`만 두고 실제 구현은 App이 `CrowdClient.live(places:crowd:details:)`로 주입한다. |
| `CrowdHomeView` | `NavigationStack` 안에 App이 넘긴 지도와 홈 시트를 겹친다. 시트 높이는 `CrowdHomeLayout`으로 지도 버튼 여백과 맞춘다. |

## MapFeature 구성

| 타입 | 역할 |
| --- | --- |
| `MapKitFeature` | `@Reducer`. 위치 요청 상태, 카메라 명령, 마지막 카메라, 자동 요청 여부, 실패 alert를 관리한다. 모듈 이름과 겹치지 않도록 `MapFeature`가 아닌 이름을 사용한다. |
| `MapKitFeature.State` | `@ObservableState`. 기존 ViewModel과 Session이 나눠 갖던 상태를 하나로 합쳤다. |
| `MapKitFeature.Action` | `onAppear`, `onDisappear`, `currentLocationButtonTapped`, `cameraChanged`처럼 View 이벤트와 effect 응답을 표현한다. |
| `LocationClient` | `@DependencyClient`. 권한 상태, 권한 요청, 위치 조회를 제공한다. `liveValue`는 `CoreMapLocationProvider`를 감싸고 UI 테스트 시나리오도 여기서 고른다. |
| `MapFeatureView` | `StoreOf<MapKitFeature>`를 받아 상태를 그리고 사용자 입력을 `store.send`로 전달한다. MapKit의 `MapCameraPosition`만 View의 `@State`로 둔다. |

## 작성 기준

- Store는 화면보다 오래 살아야 하는 곳에서 만든다. 앱에서는 `AppRootView`, Demo에서는 `MapFeatureDemoApp`이 `@State`로 보관한다. 그래서 지도 제공자를 바꿨다가 돌아와도 자동 위치 요청을 반복하지 않고 마지막 카메라를 복원한다.
- 외부 시스템 호출은 Dependency Client로 감싼다. Reducer에서 Core Location, 네트워크, 시간을 직접 호출하지 않는다.
- 시간 제한은 `@Dependency(\.continuousClock)`으로 계산한다. 테스트에서는 `TestClock`으로 시간을 직접 진행한다.
- 진행 중인 요청은 `.cancellable(id:cancelInFlight:)`로 묶고 화면 이탈 시 `.cancel(id:)`로 취소한다. 취소된 effect의 늦은 응답은 상태를 바꾸지 않는다.
- 새 식별자가 필요하면 `@Dependency(\.uuid)`를 사용한다.
- 사용자 안내 alert는 `@Presents var alert: AlertState<...>?`와 `.ifLet(\.$alert, action: \.alert)`로 표현한다.
- Domain Entity를 Feature에서 사용할 때도 DTO는 노출하지 않는다. Repository가 필요하면 Repository protocol을 감싼 Dependency Client를 만든다.

## 테스트 기준

- `CrowdFeature/Tests/CrowdFeatureTests.swift`와 `MapFeature/Tests/MapKitFeatureTests.swift`는 `TestStore`와 Swift Testing으로 Reducer를 검증한다.
- `withDependencies`로 `locationClient`, `continuousClock`, `uuid`를 주입하고 상태 변화를 모두 단언한다.
- 취소 확인이 필요한 위치 요청은 `withTaskCancellationHandler`와 `Task.never()`로 응답하지 않는 요청을 만든다.
- Core Location 변환과 취소 처리는 `CoreMapLocationProviderTests`, `MapFeatureLocationSampleTests`에서 별도로 검증한다.

```sh
xcodebuild -workspace Yeobaek.xcworkspace -scheme MapFeature \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -skipMacroValidation test
```

## 관련 문서

- [프로젝트 아키텍처](architecture-overview.md)
- [앱 시작 및 지도 화면 흐름](app-startup-flow.md)
- [MVVM, Clean Architecture, RxSwift 적용하기](mvvm-clean-architecture-rxswift.md)
