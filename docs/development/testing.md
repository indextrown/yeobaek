---
title: 테스트 실행 방법
description: Yeobaek에서 실제로 실행해 확인한 테스트 타깃과 xcodebuild 명령을 기록한다.
---

# Yeobaek 테스트 안내

이 문서의 명령은 실제로 실행해 통과를 확인한 것만 적는다. 새 타깃을 추가하면 먼저 실행해 보고 결과를 확인한 뒤 표에 추가한다.

## 테스트 타깃

| 타깃 | 위치 | 검증 대상 |
| --- | --- | --- |
| `MapBoxFeatureTests` | `Projects/Features/MapBoxFeature/Tests` | 위치 요청 상태 전이, 카메라 명령, 알림, Session 기록, 지도 위치 점 연동 |
| `MapFeatureTests` | `Projects/Features/MapFeature/Tests` | MapKit 화면의 위치 요청과 좌표 유효성 |
| `FeatcherTests` | `Projects/Shared/Featcher/Tests` | 네트워크 요청 유틸리티 |
| `YeobaekAppUITests` | `Projects/App/UITests` | 두 지도 화면의 내 위치 접근성 계약과 지도 전환 동작 |

## 실행 전 준비

Tuist가 생성한 워크스페이스가 필요하다. `Project.swift`를 바꿨다면 먼저 다시 생성한다.

```bash
tuist generate --no-open
```

## 단위 테스트

`MapBoxFeature` Scheme은 framework, Demo 앱, 테스트 타깃을 함께 빌드한다.

```bash
xcodebuild -workspace Yeobaek.xcworkspace -scheme MapBoxFeature -destination 'platform=iOS Simulator,name=iPhone 16 Pro Max' test CODE_SIGNING_ALLOWED=NO
```

## UI 테스트

`YeobaekApp` Scheme에 `YeobaekAppUITests`가 연결되어 있다.

```bash
xcodebuild -workspace Yeobaek.xcworkspace -scheme YeobaekApp -destination 'platform=iOS Simulator,name=iPhone 16 Pro Max' test CODE_SIGNING_ALLOWED=NO
```

UI 테스트는 `UITEST_LOCATION_SCENARIO=success` 환경 변수를 실행 시 주입해 실제 센서 대신 고정 좌표를 사용한다. 이 분기는 `MapBoxFeatureViewModel`의 `init(screenProvider:)`와 `MapFeatureViewModel`에 있으므로, 조립 계층은 환경 변수를 직접 확인하지 않는다.

Mapbox 화면 테스트는 `Projects/App/Secrets.xcconfig`의 `MAPBOX_ACCESS_TOKEN`이 `pk.`로 시작해야 지도를 표시한다. 토큰이 없으면 안내 화면만 표시되며, 그 경우를 검증하는 테스트도 함께 있다.

## 전체 빌드 확인

테스트 없이 모든 타깃의 컴파일만 확인할 때 사용한다.

```bash
xcodebuild -workspace Yeobaek.xcworkspace -scheme Yeobaek-Workspace -destination 'generic/platform=iOS Simulator' -configuration Debug build CODE_SIGNING_ALLOWED=NO
```

## 시뮬레이터에서 직접 확인할 때

시뮬레이터에 위치가 설정되어 있지 않으면 Mapbox 화면의 자동 위치 요청이 제한 시간까지 기다린 뒤 시간 초과 알림을 표시한다. 기능 결함이 아니므로 위치를 먼저 지정한다.

```bash
xcrun simctl location booted set 37.5665,126.9780
```

## 관련 문서

- [프로젝트 작업 안내](../../AGENTS.md)에서 문서 적용 기준을 확인한다.
- [Scheme과 Preview 구성](xcode-target-scheme-bundle-preview.md)에서 실행 호스트와 xcconfig 연결을 확인한다.
