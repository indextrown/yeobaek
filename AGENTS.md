# Yeobaek 작업 가이드

현재 `Projects/` 소스와 각 `Project.swift`를 프로젝트 동작의 기준으로 사용한다. `docs/architecture/`는 현재 코드를 빠르게 이해하기 위한 요약 문서다. 문서와 코드가 다르면 코드를 기준으로 판단하고 관련 문서를 함께 갱신한다.

`docs/research/`는 API와 구현 가능성을 조사한 기록이며 확정된 제품 동작을 의미하지 않는다. `docs/etc/`는 외부 프로젝트 자료, 원문, 레거시 기록을 보관하는 곳이다. 두 폴더의 문서를 현재 구현의 근거로 사용할 때는 실제 코드와 공식 문서를 다시 확인한다.

## 읽기 순서

| 순서 | 문서 | 읽는 조건 |
| ---: | --- | --- |
| 1 | 이 문서 | 모든 작업을 시작할 때 확인한다. |
| 2 | [`docs/architecture/architecture-overview.md`](docs/architecture/architecture-overview.md) | 기능 위치, 모듈 책임 또는 의존 관계를 판단할 때 확인한다. |
| 3 | [`docs/architecture/app-startup-flow.md`](docs/architecture/app-startup-flow.md) | 앱 진입점, 루트 화면, `AppDIContainer`, Store·세션 생성 위치 또는 앱 설정을 변경할 때 확인한다. |
| 4 | [`docs/architecture/mvvm-clean-architecture-rxswift.md`](docs/architecture/mvvm-clean-architecture-rxswift.md) | Feature, Domain, Data, Repository, MVVM 또는 RxSwift 경계를 변경할 때 확인한다. |

## 역할별 필수 문서

| 작업 영역 | 필수 문서 | 확인할 내용 |
| --- | --- | --- |
| Feature 화면 | [`architecture-overview.md`](docs/architecture/architecture-overview.md), [`mvvm-clean-architecture-rxswift.md`](docs/architecture/mvvm-clean-architecture-rxswift.md) | 화면 책임, Input/Output, 의존 가능한 모듈 |
| UIKit 화면 계약 | [`view-viewmodel-protocols.md`](docs/architecture/view-viewmodel-protocols.md) | `ViewType`, `ViewModelType`, 화면별 프로토콜과 `loadView()` 주입 |
| 앱 시작·객체 조립 | [`app-startup-flow.md`](docs/architecture/app-startup-flow.md), [`dicontainer.md`](docs/architecture/dicontainer.md) | `AppDIContainer`의 Repository·Store·Session 생성, 루트 화면 조립 |
| Domain·Data | [`architecture-overview.md`](docs/architecture/architecture-overview.md), [`mvvm-clean-architecture-rxswift.md`](docs/architecture/mvvm-clean-architecture-rxswift.md) | Entity, DTO, Repository protocol과 구현의 경계 |
| RxSwift·RxCocoa | [`rxswift-guide.md`](docs/development/rxswift-guide.md) | Observable, Relay, Driver, Signal과 UI 바인딩 기준 |
| SwiftUI·TCA | [`tca.md`](docs/architecture/tca.md) | Reducer, Dependency Client, Store 소유 위치, TestStore 테스트 기준 |
| Git 브랜치·커밋·PR | [`gitflow.md`](docs/development/gitflow.md) | 기본 Git 명령어, 브랜치 이름, stage, 커밋, push와 PR 순서 |
| Tuist 모듈 | [`static-and-dynamic-frameworks.md`](docs/architecture/static-and-dynamic-frameworks.md) | static/dynamic 선택과 앱 타깃의 임베딩 책임 |
| Scheme·Preview·xcconfig | [`xcode-target-scheme-bundle-preview.md`](docs/development/xcode-target-scheme-bundle-preview.md) | 실행 호스트, Bundle, API 키 주입, 지원 destination |
| 서울시 API | [`실시간-혼잡도-API-조사.md`](docs/research/실시간-혼잡도-API-조사.md), [`서울-실시간-도시데이터-응답-항목.md`](docs/research/서울-실시간-도시데이터-응답-항목.md) | 응답 범위, 필드 의미, 호출 한도 |

## 모듈 경계

- `App`은 SwiftUI `@main` 진입점과 최종 객체 조립을 담당한다. 구체 타입 생성은 `AppDIContainer` 한곳에서 하고, `AppRootView`는 컨테이너에서 Store, Session과 화면만 받는다. 비즈니스 규칙이나 네트워크 구현을 두지 않는다.
- `Features`는 사용자 화면과 화면 상태를 담당한다. 다른 Feature를 직접 의존하기보다 `Domain` 또는 필요한 `Shared` 모듈을 통해 협력한다.
- 같은 화면을 **완전 SwiftUI 버전**(`CrowdSwiftUIFeature`, SwiftUI + TCA)과 **완전 UIKit 버전**(`CrowdUIKitFeature`, UIKit + RxSwift + MVVM)으로 각각 만든다. 한 Feature 안에서 SwiftUI와 UIKit을 섞지 않는다. 지도도 각 버전이 자기 기술로 그린다(Mapbox SwiftUI `Map` / Mapbox `MapView`).
- 앱 기본값은 SwiftUI 버전이다. `UI_IMPLEMENTATION` 빌드 설정(`swiftui`·`uikit`)이나 디버그 실행 환경 변수로 UIKit 버전을 고르면, App이 UIKit 루트 `UINavigationController` 하나만 `Core`의 `UIViewControllerRepresentableContainer`로 감싸 끼운다. 두 기술이 만나는 곳은 이 한 군데뿐이다.
- 화면을 바꾸거나 추가할 때는 두 버전을 함께 바꾼다. 문구, 접근성 식별자, 정렬·요약·흐름 규칙, 시트·지도 수치는 `Shared/CrowdPresentation`에 두고 두 버전이 같이 쓴다. UI 테스트(`CrowdHomeUITests`)는 두 버전에 같은 시나리오를 실행한다.
- `Domain`은 Entity, Repository protocol, UseCase와 비즈니스 규칙을 담당한다. UIKit, MapKit, Mapbox, RxSwift, GRDB 같은 구현 기술에 의존하지 않는다.
- `Data`는 DTO, 외부 응답 변환, Repository 구현을 담당하고 `Domain`을 의존한다.
- `Shared/Core`는 여러 모듈에서 재사용하는 기반 코드와 앱 설정 접근을 담당한다. 특정 Feature의 화면 정책을 넣지 않는다.
- `Shared/CrowdPresentation`은 혼잡도 화면의 SwiftUI·UIKit 공통 규칙(문구, 식별자, 정렬·요약, 레이아웃 수치)만 담는다. SwiftUI·UIKit·지도 SDK를 import하지 않는다.
- `Shared/ThirdParty`는 외부 패키지 연결 지점이다. Feature는 실제로 사용하는 라이브러리와 Shared 모듈만 의존한다.
- `Shared/RxExtension`은 범용 Rx 확장만 제공한다. 특정 화면이나 서비스의 상태를 보관하지 않는다.
- `Shared/RxLab`과 각 Demo 앱은 학습·실험용 실행 환경이다. 제품 앱의 기능 구현을 이 모듈에 의존시키지 않는다.

## 구현 기준

- MVVM의 입력과 출력은 가능한 한 `Input`과 `Output`으로 명시하고, ViewController는 이벤트 전달과 렌더링에 집중한다. UIKit 화면은 `Core`의 `ViewType`·`ViewModelType`을 채택하고, View를 `UIView`로 분리해 `loadView()`에서 주입받는다.
- UI 이벤트는 RxCocoa의 `ControlEvent`, 화면 출력은 `Driver` 또는 `Signal`을 우선 검토한다.
- SwiftUI 하위 화면은 `some View`를 반환하는 계산 속성이나 메서드로 만들지 않고 별도 `View` 구조체로 분리한다. 하위 구조체에는 Store 대신 필요한 값과 액션 클로저만 전달한다.
- API 응답 DTO를 Feature에 직접 노출하지 않는다. Data에서 Domain Entity로 변환한다.
- API 키를 Swift 코드에 직접 작성하지 않는다. xcconfig와 Info.plist 치환을 거쳐 `AppConfiguration`으로 읽는다.
- GitHub Issue는 선택 사항이며 브랜치 생성이나 Pull Request의 필수 조건이 아니다. 사용자가 요청하지 않으면 Issue를 만들지 않고 작업 브랜치에서 바로 Pull Request를 생성한다.
- GRDB는 선택된 로컬 DB 기술이지만 아직 실제 패키지, 스키마, 마이그레이션이 연결되지 않았다. 도입 전까지 현재 구현처럼 설명하지 않는다.
- 매개변수가 있는 Swift 함수와 생성자는 여는 괄호 뒤에서 줄을 바꾸고 매개변수를 한 줄씩 작성한다.
- 매개변수가 있는 함수와 생성자에는 역할과 각 매개변수를 설명하는 한국어 `///` 문서화 주석을 작성한다.

## 문서 갱신 기준

- 모듈 책임, 제품 타입 또는 의존 방향이 바뀌면 `architecture-overview.md`를 갱신한다.
- `YeobaekApp`, `AppRootView`, `AppDIContainer`, Store·세션 생성 위치 또는 앱 시작 초기화가 바뀌면 `app-startup-flow.md`와 `dicontainer.md`를 갱신한다.
- MVVM, Clean Architecture, Repository 또는 GRDB 적용 원칙이 바뀌면 `mvvm-clean-architecture-rxswift.md`를 갱신한다.
- Scheme, Demo 앱, Preview 호스트, Bundle 또는 xcconfig 연결이 바뀌면 `xcode-target-scheme-bundle-preview.md`를 갱신한다.
- 한 화면에서만 쓰이는 임시 실험은 별도 문서로 만들지 않는다. 여러 작업에서 반복해서 확인할 정보만 문서로 남긴다.
- 외부 프로젝트 문서나 원문은 `docs/etc/`에 출처와 참고 목적을 적어 보관하고 현재 아키텍처 문서와 섞지 않는다.
