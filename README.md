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
| 지도 | Mapbox | 지도 표시 및 장소별 혼잡도 시각화 |
| UI 프레임워크 | SwiftUI | 앱 화면과 사용자 인터페이스 구현 |
| 앱 아키텍처 | VIPER | 화면별 역할 분리 및 모듈 구성 |
| 프로젝트 관리 | Tuist | Xcode 프로젝트 생성 및 모듈 의존성 관리 |
| 로컬 DB | Realm | 앱 내 데이터의 로컬 저장 및 조회 |
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

[팝팡의 Tuist 구성](https://github.com/team-PopPang/PopPang-iOS)을 참고해 루트 워크스페이스와 `Projects/App` 프로젝트를 분리했습니다. 현재는 App 모듈 하나만 있으며, 앱 이름과 소개 문구를 표시합니다. 지도·Realm·네트워크 SDK와 VIPER 기능 모듈은 아직 연결하지 않았습니다. AppIcon은 이미지가 없는 자리표시자입니다.

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

## 문서

- [Xcode Target, Scheme, Bundle과 SwiftUI Preview 이해하기](docs/xcode-target-scheme-bundle-preview.md)
- [Static Framework와 Dynamic Framework 이해하기](docs/static-and-dynamic-frameworks.md)
- [실시간 혼잡도 API 조사 및 비교](docs/실시간-혼잡도-API-조사.md)
- [VIPER 아키텍처 이해와 여백 앱 적용](docs/viper.md)
