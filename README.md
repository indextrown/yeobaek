# 여백 (Yeobaek)

붐비는 공간 속, 여유를 찾다.

여백은 장소별 실시간 혼잡도를 지도에서 확인하고, 덜 붐비는 장소와 방문 시간을 찾는 앱입니다.

## 만들고 싶은 기능

- 지도에서 장소별 혼잡도를 한눈에 확인
- 추정 인구와 데이터 기준 시각 확인
- 시간대별 혼잡도 예측을 보고 방문 시간 비교

현재 App 모듈의 기본 실행 구조를 준비한 단계이며, 첫 버전은 서울 주요 장소를 중심으로 준비합니다.

## 기술 스택 (예정)

| 구분 | 기술 | 용도 |
| --- | --- | --- |
| 지도 | MapKit, Mapbox | 두 지도 방식으로 장소별 혼잡도 시각화 |
| UI 프레임워크 | UIKit, SwiftUI | MapBoxFeature는 UIKit + RxSwift로 구현하고, MapFeature만 SwiftUI로 구현 |
| 앱 아키텍처 | MVVM + Clean Architecture + RxSwift | 화면 상태, 비즈니스 규칙, 데이터 구현 분리 |
| 프로젝트 관리 | Tuist | Xcode 프로젝트 생성 및 모듈 의존성 관리 |
| 로컬 DB | GRDB | SQLite 기반 장소와 혼잡도 데이터 저장 및 조회 |
| 백엔드 | FastAPI | 혼잡도 API 연동 및 앱에 필요한 데이터 제공 |
| 실시간 통신 | WebSocket | 백엔드에서 앱으로 혼잡도 갱신 메시지 스트리밍 |

## Feature 모듈 생성

저장소 루트의 `Makefile`로 `Projects` 아래에 새 Feature 모듈을 만들 수 있습니다. 모듈 이름은 대문자로 시작하는 UpperCamelCase Swift 식별자를 사용합니다.

```sh
make module PlaceListFeature
```

독립 실행 가능한 Demo App 타깃도 함께 만들려면 명령 마지막에 `demo`를 붙입니다.

```sh
make module PlaceListFeature demo
```

명령은 Feature 프레임워크와 기본 SwiftUI View를 생성하고, `Workspace.swift`와 App 타깃 의존성에 모듈을 등록합니다. 같은 이름의 디렉터리가 이미 있으면 기존 파일을 덮어쓰지 않고 중단합니다. 생성 후 `mise exec -- tuist generate`를 실행하면 모듈과 선택한 Demo 스킴을 Xcode에서 확인할 수 있습니다.

```sh
make help
```

## 개발 시작

- Tuist: `4.197.0` (`mise.toml`로 버전 고정)
- 앱 타깃: `YeobaekApp`, iPhone·iOS 17 이상, Swift 6
- 개발용 번들 ID: `com.indextrown.yeobaek` (배포 전 확정 필요)

Xcode와 [mise](https://mise.jdx.dev/getting-started.html)를 준비한 뒤 저장소 루트에서 실행합니다.

```sh
mise trust ./mise.toml
mise install
mise exec -- tuist generate
```

생성된 `Yeobaek.xcworkspace`에서 `YeobaekApp` 스킴과 iPhone 시뮬레이터를 선택해 실행합니다. 실기기 실행 시에는 App 타깃에 본인의 개발 팀과 서명 설정이 필요합니다.

[팝팡의 Tuist 구성](https://github.com/team-PopPang/PopPang-iOS)을 참고해 루트 워크스페이스와 프로젝트를 모듈별로 분리했습니다. 현재 App, Domain, Data, Features, Shared 계층과 MapKit·Mapbox 지도 화면, RxSwift Input/Output ViewModel을 구성했습니다. GRDB와 실제 공공데이터 네트워크 연동은 이후 단계에서 추가합니다. AppIcon은 이미지가 없는 자리표시자입니다.

```text
Tuist.swift
Workspace.swift
Projects/
  App/
    Project.swift
    Sources/
    Resources/
```

Xcode 프로젝트·워크스페이스와 `Derived` 등 생성물은 Git에서 제외합니다. 프로젝트 설정은 Tuist 매니페스트를 수정한 뒤 다시 생성합니다.

## 엔티티와 데이터 모델

`Domain`에는 MapKit과 Mapbox에서 함께 사용할 데이터 모델을 정의해요. 지도 SDK의 객체나 화면 색상을 넣지 않고, 장소와 혼잡도를 표현하는 값만 관리해요.

`Place`는 고유 코드로 식별하는 장소 엔티티예요. 좌표, 경계, 인구 범위 등은 장소를 설명하는 값 타입이며, 각각을 별도 DB 테이블로 만든다는 뜻은 아니에요.

| 타입 | 역할 | 주요 필드 |
|---|---|---|
| [Place](Projects/Domain/Sources/Domain/Entities/Place.swift) | 장소 자체를 식별하고 이름과 라벨 위치를 보관해요. | `id`, `name`, `labelCoordinate` |
| [GeoCoordinate](Projects/Domain/Sources/Domain/Entities/GeoCoordinate.swift) | 지도 SDK에 의존하지 않는 WGS84 좌표를 표현해요. | `latitude`, `longitude` |
| [AreaGeometry](Projects/Domain/Sources/Domain/Entities/AreaGeometry.swift) | 한 장소의 전체 경계를 보관해요. 여러 조각으로 떨어진 영역도 표현할 수 있어요. | `placeID`, `polygons` |
| [GeoPolygon](Projects/Domain/Sources/Domain/Entities/AreaGeometry.swift) | 하나의 다각형을 표현해요. 외곽 경계와 내부에서 제외할 빈 공간의 경계를 구분해요. | `exteriorRing`, `interiorRings` |
| [CongestionLevel](Projects/Domain/Sources/Domain/Entities/CongestionLevel.swift) | 혼잡도 단계를 나타내요. 색상과 표시 문구는 화면 계층에서 정해요. | `relaxed`(여유), `normal`(보통), `busy`(약간 붐빔), `crowded`(붐빔), `unknown`(알 수 없음) |
| [PopulationRange](Projects/Domain/Sources/Domain/Entities/PopulationRange.swift) | 추정 인구의 최소·최대 범위를 표현해요. 최소값이 음수이거나 최대값보다 크면 생성자가 `nil`을 반환해요. | `minimum`, `maximum` |
| [CrowdSnapshot](Projects/Domain/Sources/Domain/Entities/CrowdSnapshot.swift) | 특정 시각의 장소 혼잡도와 추정 인구를 보관해요. 장소 정보와 분리해서 갱신할 수 있어요. | `placeID`, `level`, `population`, `message`, `observedAt`, `isReplacementData` |

### 모델 간 연결

장소 이름이 아니라 고유 장소 코드로 경계와 혼잡도를 연결해요. 서울시 데이터에서는 `AREA_CD`를 이 코드로 사용해요.

```text
Place.id
  -> AreaGeometry.placeID : 해당 장소의 경계
  -> CrowdSnapshot.placeID : 해당 장소의 특정 시각 혼잡도
```

- `Place.labelCoordinate`는 라벨을 표시할 대표 좌표예요. 영역의 모양은 `AreaGeometry`가 담당하며, 대표 좌표가 없으면 `nil`로 유지해요.
- `CrowdSnapshot.population == nil`은 인구 정보가 없다는 뜻이지, 사람이 0명이라는 뜻이 아니에요.
- `CrowdSnapshot.observedAt`은 응답을 받은 시각이 아니라 원천 데이터의 기준 시각이에요. 요청에 성공했다고 데이터가 방금 측정된 것으로 표시하지 않아요.
- `CrowdSnapshot.isReplacementData == nil`은 제공 기관이 대체 데이터 사용 여부를 명시하지 않았다는 뜻이에요.
- `.unknown`은 혼잡도를 알 수 없다는 뜻이에요. 네트워크 실패나 오래된 데이터 여부는 혼잡도 단계와 별도로 다뤄요.

### 엔티티, DTO, Repository의 역할

- [CrowdRepository](Projects/Domain/Sources/Domain/Repositories/CrowdRepository.swift)는 `Domain`의 조회 프로토콜이에요. 장소 코드를 받아 `CrowdSnapshot`을 반환하는 계약만 정의해요.
- [SeoulPopulationDTO](Projects/Data/Sources/Data/DTO/SeoulPopulationDTO.swift)와 [SeoulPopulationResponseDTO](Projects/Data/Sources/Data/DTO/SeoulPopulationResponseDTO.swift)는 `Core`에서 서울시 API의 항목과 전체 응답 형식을 받아요. 문자열을 숫자·시각·혼잡도 타입으로 바꾸는 작업은 [변환 코드](Projects/Data/Sources/Data/Mapping/SeoulPopulationDTO+Mapping.swift)가 맡아요.
- [MockCrowdRepository](Projects/Data/Sources/Data/Repositories/MockCrowdRepository.swift)는 현재 `Core`에 있는 목업 구현이에요. [CrowdMockData](Projects/Data/Sources/Data/Mocks/CrowdMockData.swift)의 가상 장소와 혼잡도 정보를 사용하며, 목업 장소 코드는 실제 API 요청에 사용하지 않아요.

현재는 모델, DTO 변환, 목업 조회까지 준비되어 있어요. 실제 장소 경계 리소스, API 네트워크 호출, 지도 화면과의 데이터 연결은 이후 단계에서 추가해요.

## 모듈 디렉터리 구성

`Data`는 Demo 앱이 없는 dynamic framework예요. DTO, Domain 모델로의 매핑, Repository 구현, 목업 데이터를 관리해요. Repository 프로토콜과 엔티티는 `Domain`에 유지하고, 의존성은 `App → Data → Domain`으로 연결해요. `AppConfiguration` 등 공통 코드는 `Shared/Core`에 남겨요.

```text
Projects/
├── App/
├── Data/
├── Domain/
├── Features/
│   ├── MapFeature/
│   └── MapBoxFeature/
└── Shared/
    ├── Core/
    │   └── Sources/Core/Configuration/AppConfiguration.swift
    ├── Featcher/
    ├── RxExtension/
    ├── RxLab/
    └── ThirdParty/
```

`Features`와 `Shared`는 모듈이 아닌 분류용 디렉터리예요. 두 지도 Feature는 `Features` 아래에 두고, 공통으로 사용하는 `Core`, `Featcher`, `RxExtension`, `ThirdParty`는 `Shared` 아래에서 관리해요. `RxLab`도 Shared 아래에 있지만 제품 모듈이 의존하지 않는 독립 실험용 모듈이에요.

기존 `Shared` 모듈은 제거했어요. `AppConfiguration`은 `Core`의 `Configuration` 폴더로 옮겼으며, 사용하는 곳에서는 `import Core`로 접근해요. 실제 키 파일은 기존 `Projects/App/Secrets.xcconfig`를 그대로 사용하고, 실행 중인 App 또는 Demo의 `Info.plist`를 `Bundle.main`으로 읽는 방식도 유지해요.

`make module SampleFeature`는 `Projects/Features/SampleFeature`를 만들어요. `make module SampleFeature demo`로 Demo 앱을 함께 생성할 수 있어요. 기존 모듈의 이름, static/dynamic 설정과 Demo 앱은 유지해요.

## 문서

### 아키텍처

- [MVVM, Clean Architecture, RxSwift 적용하기](docs/architecture/mvvm-clean-architecture-rxswift.md)
- [Static Framework와 Dynamic Framework 이해하기](docs/architecture/static-and-dynamic-frameworks.md)

### 개발 가이드

- [RxSwift와 RxCocoa 타입 및 연산자 가이드](docs/development/rxswift-guide.md)
- [Xcode Target, Scheme, Bundle과 SwiftUI Preview 이해하기](docs/development/xcode-target-scheme-bundle-preview.md)

### 기술 조사

- [실시간 혼잡도 API 조사 및 비교](docs/research/실시간-혼잡도-API-조사.md)
