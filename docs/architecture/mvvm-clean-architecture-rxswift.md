---
title: "MVVM, Clean Architecture, RxSwift 적용하기"
description: "여백 앱의 화면 상태, 비즈니스 규칙, 데이터 구현을 분리하고 RxSwift로 연결하는 아키텍처 기준을 설명해요."
---

# MVVM, Clean Architecture, RxSwift 적용하기

여백은 **MVVM + Clean Architecture + RxSwift**를 앱 아키텍처로 사용해요. MVVM은 화면과 표시 로직을 나누고, Clean Architecture는 모듈의 의존 방향을 정해요. RxSwift는 사용자 입력과 비동기 결과, 화면 상태를 스트림으로 연결해요.

로컬 데이터베이스는 Realm 대신 **GRDB**를 사용해요. GRDB의 Record와 쿼리는 Data 모듈 안에 두고 Domain과 Feature에는 노출하지 않아요.

## 각 기술이 해결하는 문제

| 기술 | 책임 | 이 프로젝트에서 해결하는 문제 |
| --- | --- | --- |
| MVVM | View와 ViewModel 분리 | UIKit과 SwiftUI 화면에서 표시 로직을 분리해요. |
| Clean Architecture | 계층과 의존 방향 정의 | 지도 SDK, 네트워크, GRDB가 Domain 규칙으로 들어오지 않게 해요. |
| RxSwift | 입력과 출력의 비동기 연결 | 버튼 입력, 위치 조회, 로딩 상태, 오류 이벤트를 하나의 흐름으로 다뤄요. |
| GRDB | SQLite 기반 로컬 저장 | 장소, 경계, 혼잡도 캐시를 명시적인 SQL과 migration으로 관리해요. |

MVVM과 Clean Architecture는 서로 대체하지 않아요. MVVM은 Presentation 계층 안의 구조이고, Clean Architecture는 앱 전체 계층의 경계를 다뤄요. RxSwift는 두 구조 사이에서 데이터가 흐르는 방법을 제공해요.

## 계층별 책임

### App

App은 Composition Root예요. 실제 Repository 구현, UseCase, ViewModel, Feature를 조립해요. 구체 타입을 선택하는 코드는 App에 두고 Domain에는 넣지 않아요.

### Features

Feature는 화면과 사용자 상호작용을 관리해요. UIKit ViewController나 SwiftUI View, ViewModel, 화면 전용 상태와 표시 모델을 둬요.

ViewModel은 Input을 받아 Output을 만들어요. View는 Output을 그릴 뿐 비즈니스 규칙이나 데이터 저장 방법을 결정하지 않아요.

### Domain

Domain은 앱의 핵심 규칙을 관리해요. Entity, Repository 프로토콜, UseCase를 둬요.

Domain은 UIKit, SwiftUI, MapKit, Mapbox, RxCocoa, GRDB를 import하지 않아요. 외부 기술을 바꿔도 Domain 규칙이 유지되어야 해요.

### Data

Data는 Domain의 Repository 프로토콜을 구현해요. 공공데이터 API DTO, 네트워크 요청, GRDB Record, 매핑, 캐시 정책을 관리해요.

Data는 외부 응답과 데이터베이스 값을 Domain Entity로 변환해서 반환해요. Feature가 DTO나 GRDB Record를 직접 사용하지 않게 해요.

### Shared

Shared에는 여러 모듈에서 재사용하는 기반 코드를 둬요.

| 모듈 | 책임 |
| --- | --- |
| `Core` | 앱 설정과 범용 UIKit·SwiftUI 도구 |
| `ThirdParty` | 외부 라이브러리 의존성 허브 |
| `RxExtension` | 공통 RxSwift·RxCocoa 확장 |
| `Featcher` | 공통 데이터 조회 도구 |
| `RxLab` | RxSwift 학습과 실험을 위한 독립 Demo |

`RxLab`은 제품 Feature가 의존하는 공용 계층이 아니에요. 실험 코드를 제품 코드와 분리하기 위해 독립적으로 유지해요.

## 의존 방향

의존성은 바깥 계층에서 안쪽 계층으로 향해요.

```text
App
├── Features ──> Domain
└── Data ──────> Domain

Features ──> Shared
Data ──────> Shared
Domain ────> 외부 프레임워크에 의존하지 않음
```

실행 중에는 ViewModel이 UseCase를 호출하고 Repository 결과를 받을 수 있어요. 하지만 소스 코드 의존성은 Feature가 Data의 구체 Repository를 직접 알지 않도록 구성해요. App이 구현체를 생성해서 주입해요.

## MVVM Input과 Output

ViewModel은 UIKit이나 SwiftUI 이벤트를 직접 소유하지 않고 Input으로 받아요. 화면이 필요한 값과 명령은 Output으로 반환해요.

```swift
public struct Input {
    public let viewDidAppear: Observable<Void>
    public let currentLocationTapped: Observable<Void>
}

public struct Output {
    public let state: Driver<State>
    public let cameraCommand: Signal<MapBoxCameraCommand>
    public let alert: Signal<MapBoxAlert>
}
```

Input을 `Observable`로 받으면 UIKit의 `ControlEvent`와 테스트의 Subject를 같은 인터페이스로 전달할 수 있어요. Output은 UI 동작에 맞는 RxCocoa Trait로 제한해요.

| 상황 | 타입 | 이유 |
| --- | --- | --- |
| 버튼 탭과 화면 생명주기 | `ControlEvent` | 메인 스레드에서 오류 없이 UI 입력을 전달해요. |
| ViewModel Input | `Observable` | UI와 테스트가 서로 다른 입력 소스를 넣을 수 있어요. |
| 현재 화면 상태 | `Driver` | 최신 상태를 공유하고 메인 스레드에서 전달해요. |
| 알림과 카메라 이동 | `Signal` | 과거 명령을 새 구독자에게 다시 전달하지 않아요. |
| ViewModel 내부 상태 | `BehaviorRelay` | 종료 없이 최신 상태를 보관해요. |
| ViewModel 내부 사건 | `PublishRelay` | 종료 없이 새로운 사건만 전달해요. |

Rx 타입과 연산자의 자세한 선택 기준은 [RxSwift와 RxCocoa 타입 및 연산자 가이드](../development/rxswift-guide.md)에서 확인할 수 있어요.

## UseCase와 Repository

ViewModel은 화면에 필요한 UseCase를 호출해요. UseCase는 여러 Repository 호출을 조합하고 Domain 규칙을 적용해요.

```text
View
  -> ViewModel Input
  -> UseCase
  -> Repository Protocol
  -> Data Repository
  -> API 또는 GRDB
  -> Domain Entity
  -> ViewModel Output
  -> View
```

간단한 조회는 초기 단계에서 ViewModel이 Repository 프로토콜을 직접 받을 수 있어요. 조회 규칙이 늘어나거나 여러 Repository를 조합하기 시작하면 UseCase로 옮겨요. 화면마다 이름만 다른 UseCase를 미리 만들지는 않아요.

## GRDB를 Data 경계 안에 둬요

GRDB는 확정한 로컬 데이터베이스 기술이지만 실제 패키지 연결과 schema 구현은 이후 단계에서 추가해요.

```text
Projects/Data/Sources/Data/
├── Local/
│   ├── DatabaseManager.swift
│   ├── Migrations.swift
│   └── Records/
├── DTO/
├── Mapping/
└── Repositories/
```

GRDB를 추가할 때는 아래 규칙을 지켜요.

1. `DatabaseQueue`와 `DatabasePool`은 Data 내부에서만 사용해요.
2. GRDB Record는 Domain Entity와 분리해요.
3. Record와 Entity 변환은 Data의 Mapping 코드가 담당해요.
4. schema 변경은 버전이 있는 migration으로 관리해요.
5. 테스트는 메모리 데이터베이스를 사용해 실제 SQL과 migration을 검증해요.
6. Repository가 원격 API와 로컬 캐시의 선택 정책을 관리해요.

Domain의 `Place`, `AreaGeometry`, `CrowdSnapshot`에는 GRDB 프로토콜을 채택하지 않아요. 저장 방식이 바뀌어도 Domain 모델을 수정하지 않는 것이 기준이에요.

## 모듈 구조

```text
Projects/
├── App/
├── Domain/
│   ├── Entities/
│   ├── Repositories/
│   └── UseCases/
├── Data/
│   ├── DTO/
│   ├── Local/
│   ├── Mapping/
│   └── Repositories/
├── Features/
│   ├── MapFeature/
│   └── MapBoxFeature/
└── Shared/
    ├── Core/
    ├── Featcher/
    ├── RxExtension/
    ├── RxLab/
    └── ThirdParty/
```

폴더 구조를 그대로 계층으로 착각하지 않아요. 실제 경계는 각 Tuist Target의 dependencies로 보장해요.

## 테스트 기준

| 대상 | 검증할 내용 |
| --- | --- |
| ViewModel | Input을 보냈을 때 예상한 Driver 상태와 Signal 명령을 출력하는지 확인해요. |
| UseCase | Repository 테스트 대역으로 Domain 규칙과 호출 순서를 확인해요. |
| Repository | DTO·Record가 올바른 Domain Entity로 변환되는지 확인해요. |
| GRDB | 메모리 데이터베이스에서 migration, 저장, 조회를 확인해요. |
| Feature | 권한 거부, 로딩, 성공, 실패 상태가 화면에 반영되는지 확인해요. |

## 구현 판단 기준

- View가 Repository나 GRDB를 직접 호출하지 않아요.
- ViewModel이 UIKit View나 Mapbox 객체를 Output으로 반환하지 않아요.
- Domain이 RxCocoa, GRDB, 지도 SDK에 의존하지 않아요.
- Data가 DTO와 Record를 Domain Entity로 변환해요.
- 현재 상태는 Driver, 일회성 UI 명령은 Signal로 구분해요.
- 의존 객체 생성과 구현체 선택은 App에서 담당해요.
- 작은 기능에 불필요한 UseCase나 계층을 미리 만들지 않아요.
