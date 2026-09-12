---
title: Git 작업 흐름
description: 별도의 git-flow 도구 없이 Git 기본 명령어로 브랜치 생성부터 PR과 정리까지 진행하는 Yeobaek 가이드다.
---

# Yeobaek Git 작업 흐름

## 이 문서에서 확인할 것

Yeobaek은 `git flow` CLI와 `develop` 브랜치를 사용하지 않는다. `main`에서 작업 브랜치를 만들고, 기본 Git 명령어로 커밋과 push를 수행한 뒤 Pull Request로 `main`에 병합한다.

```text
main
├─ feature/seoul-live-population
├─ fix/mapbox-location-button
├─ refactor/map-session
└─ docs/git-workflow
```

브랜치를 옮길 때는 기존에 사용하던 `git checkout`을 계속 사용할 수 있다. 이 문서에서는 브랜치 이동과 파일 복구의 의미를 구분하기 쉬운 `git switch`를 기본 예시로 사용하고 `checkout` 명령도 함께 안내한다.

## 기본 원칙

- `main`은 언제든 앱을 생성하고 실행할 수 있는 기준 브랜치로 유지한다.
- 기능, 수정, 리팩터링, 문서 작업은 목적에 맞는 짧은 작업 브랜치에서 진행한다.
- 작업 브랜치는 최신 `main`에서 만든다.
- 한 브랜치는 하나의 작업 목적만 가진다.
- 관련 파일만 명시적으로 stage하고 하나의 커밋에는 하나의 논리적 변경을 담는다.
- 원격 브랜치에 push한 뒤 Pull Request에서 변경 이유와 확인 방법을 설명한다.
- GitHub Issue는 선택 사항이다. 사용자가 요청하거나 별도 추적이 필요할 때만 만들며, Issue 없이도 작업 브랜치에서 Pull Request를 생성할 수 있다.
- `git flow init`, `git flow feature start` 같은 별도 확장 명령은 사용하지 않는다.

## 브랜치 이름

| 접두사 | 용도 | 예시 |
|---|---|---|
| `feature/` | 새로운 사용자 기능 | `feature/seoul-live-population` |
| `fix/` | 일반 버그 수정 | `fix/mapbox-location-button` |
| `hotfix/` | 배포 버전의 긴급 수정 | `hotfix/mapbox-launch-crash` |
| `refactor/` | 동작을 유지하는 구조 개선 | `refactor/map-session` |
| `docs/` | README와 개발 문서 변경 | `docs/git-workflow` |
| `test/` | 테스트 추가와 정리 | `test/fetcher` |
| `chore/` | 빌드 설정과 유지보수 | `chore/tuist-settings` |

브랜치 이름은 영문 소문자와 하이픈을 사용한다. 구현 내용보다 해결하려는 목적이 드러나는 이름을 선택한다.

## `switch`와 `checkout`

두 방식 모두 Git 기본 명령어이며 결과는 같다.

| 목적 | 권장 명령 | 익숙한 명령 |
|---|---|---|
| 기존 브랜치로 이동 | `git switch main` | `git checkout main` |
| 새 브랜치를 만들며 이동 | `git switch -c feature/map` | `git checkout -b feature/map` |
| 직전 브랜치로 이동 | `git switch -` | `git checkout -` |

`checkout`은 브랜치 이동과 파일 복구를 모두 담당한다. `switch`는 브랜치 이동만 담당하므로 명령의 의도가 더 분명하다.

## 일반적인 작업 순서

### 1. `main` 최신화

작업을 시작하기 전에 원격 `main`을 받아온다.

```bash
git switch main
git pull --ff-only origin main
```

`checkout`을 사용한다면 다음과 같다.

```bash
git checkout main
git pull --ff-only origin main
```

`--ff-only`는 로컬과 원격 이력이 갈라졌을 때 의도하지 않은 merge commit을 자동으로 만들지 않고 작업을 멈춘다.

### 2. 작업 브랜치 생성

```bash
git switch -c feature/seoul-live-population
```

`checkout` 방식은 다음과 같다.

```bash
git checkout -b feature/seoul-live-population
```

### 3. 변경사항 확인

```bash
git status --short
git diff
```

- `git status --short`로 수정, 추가, 삭제된 파일을 확인한다.
- `git diff`로 아직 stage하지 않은 실제 변경 내용을 확인한다.
- 예상하지 못한 파일이 보이면 바로 stage하지 않고 변경 원인을 먼저 확인한다.

### 4. 관련 파일만 stage

```bash
git add -- \
  Projects/Data/Sources/SeoulPopulationDTO.swift \
  Projects/Domain/Sources/Population.swift
```

문서만 변경했다면 다음처럼 범위를 좁힌다.

```bash
git add -- README.md docs/development/gitflow.md
```

`git add .`은 다른 작업이나 비밀 설정 파일까지 함께 포함할 수 있으므로 기본 방식으로 사용하지 않는다.

### 5. stage 결과 확인

```bash
git diff --staged
git diff --staged --stat
```

커밋에 들어갈 파일과 내용이 현재 작업 목적에 맞는지 확인한다.

### 6. 커밋

Yeobaek은 Conventional Commits 형식과 한국어 설명을 사용한다.

```text
<type>: <변경 내용>
```

```bash
git commit -m "feat: 서울 실시간 인구 조회 추가"
```

| 타입 | 용도 | 예시 |
|---|---|---|
| `feat` | 새로운 기능 | `feat: 혼잡도 지도 화면 추가` |
| `fix` | 버그 수정 | `fix: 현재 위치 버튼 배경 수정` |
| `refactor` | 동작을 유지하는 구조 변경 | `refactor: MapBoxSession 파일 분리` |
| `test` | 테스트 추가와 수정 | `test: Fetcher 응답 테스트 추가` |
| `docs` | 문서 변경 | `docs: Git 작업 흐름 추가` |
| `chore` | 설정과 유지보수 | `chore: Tuist 의존성 설정 변경` |

제목만으로 이유가 충분하지 않으면 본문에 무엇을 왜 변경했는지 작성한다.

```bash
git commit \
  -m "refactor: 지도 세션 책임 분리" \
  -m "ViewModel이 지도 SDK 객체를 직접 소유하지 않도록 세션으로 이동한다."
```

### 7. 원격 브랜치에 push

첫 push에는 upstream을 연결한다.

```bash
git push -u origin feature/seoul-live-population
```

이후 같은 브랜치는 다음 명령만 사용해도 된다.

```bash
git push
```

### 8. Pull Request 생성과 병합

Yeobaek에서는 Pull Request를 만들기 위해 GitHub Issue를 먼저 만들 필요가 없다. 관련 Issue가 이미 있거나 사용자가 Issue 생성을 요청한 경우에만 연결한다. Issue가 없다면 PR의 `Related Issues` 항목에는 `-` 한 줄만 적고 `없음` 등의 설명은 덧붙이지 않는다.

Pull Request에는 다음 내용을 작성한다.

- 무엇을 변경했는지
- 왜 변경했는지
- 어떤 화면이나 모듈에 영향이 있는지
- 직접 확인한 항목과 아직 확인하지 못한 항목
- 관련 Issue가 있다면 Issue 번호

리뷰와 필요한 확인이 끝나면 `main`에 병합한다. 병합 방식은 저장소 설정을 따르되 불필요한 중간 커밋이 많다면 Squash merge를 우선 검토한다.

### 9. 병합된 브랜치 정리

```bash
git switch main
git pull --ff-only origin main
git branch -d feature/seoul-live-population
git push origin --delete feature/seoul-live-population
```

`git branch -d`가 삭제를 거부하면 아직 병합되지 않은 커밋이 있다는 뜻이다. 이유를 확인하지 않고 `-D`로 강제 삭제하지 않는다.

## 작업 중 `main`이 변경됐을 때

작업 브랜치에서 원격 변경을 확인한다.

```bash
git fetch origin
git log --oneline HEAD..origin/main
```

혼자 사용하는 아직 공유되지 않은 브랜치라면 최신 `main` 위로 rebase할 수 있다.

```bash
git rebase origin/main
```

여러 사람이 함께 push하는 브랜치는 rebase로 공개 이력을 바꾸지 않고 merge를 사용한다.

```bash
git merge origin/main
```

충돌이 발생하면 각 파일을 직접 정리하고 관련 동작을 확인한 뒤 계속한다. 충돌을 이해하지 못한 상태에서 `ours` 또는 `theirs` 전체를 선택하지 않는다.

## 긴급 수정

배포 버전의 치명적인 문제는 최신 `main`에서 `hotfix/` 브랜치를 만든다.

```bash
git switch main
git pull --ff-only origin main
git switch -c hotfix/mapbox-launch-crash
```

수정, 확인, 커밋, push, PR 순서는 일반 작업과 같다. 별도의 `develop` 브랜치에 다시 병합하는 과정은 없다.

## 버전 태그

릴리스 커밋이 `main`에 병합된 뒤 해당 커밋에 태그를 만든다.

```bash
git switch main
git pull --ff-only origin main
git tag -a v0.1.0 -m "Release 0.1.0"
git push origin v0.1.0
```

버전은 `MAJOR.MINOR.PATCH` 형식을 사용한다.

| 구분 | 증가 기준 | 예시 |
|---|---|---|
| Major | 호환되지 않는 큰 변경 | `1.0.0` → `2.0.0` |
| Minor | 하위 호환되는 기능 추가 | `1.0.0` → `1.1.0` |
| Patch | 하위 호환되는 버그 수정 | `1.0.0` → `1.0.1` |

## 커밋하지 않은 변경이 있을 때

브랜치를 옮기기 전에 현재 변경을 어떻게 처리할지 결정한다.

현재 작업에 필요한 변경이면 작업 브랜치에서 커밋한다. 잠시 보관해야 한다면 설명을 붙여 stash한다.

```bash
git stash push -u -m "지도 화면 작업 중"
git switch main
```

다시 적용할 때는 목록을 확인한 뒤 원하는 stash를 선택한다.

```bash
git stash list
git stash apply stash@{0}
```

`git stash pop`은 적용과 동시에 stash를 제거한다. 충돌 상황에서도 원본을 남기려면 먼저 `apply`를 사용한다.

## 금지하거나 주의할 명령

- `git reset --hard`는 커밋하지 않은 변경을 잃을 수 있으므로 사용하지 않는다.
- `git checkout -- <파일>`과 `git restore <파일>`은 로컬 변경을 버리므로 복구 대상이 명확할 때만 사용한다.
- `git push --force`를 `main`이나 공유 브랜치에 사용하지 않는다.
- 예상하지 못한 변경이 섞인 상태에서 `git add .` 또는 `git commit -a`를 사용하지 않는다.
- 이미 다른 사람이 사용한 커밋을 임의로 amend하거나 rebase하지 않는다.
- API 키, 토큰, 개인 xcconfig 파일을 커밋하지 않는다.

## 커밋 전 체크리스트

- [ ] 현재 브랜치가 작업 목적에 맞는가
- [ ] `git status --short`에 예상한 파일만 보이는가
- [ ] `git diff --staged`가 하나의 논리적 변경만 포함하는가
- [ ] 비밀값과 개인 파일이 제외됐는가
- [ ] 관련 빌드나 테스트를 실행했다면 결과를 PR에 기록했는가
- [ ] 실행하지 못한 확인 항목을 숨기지 않고 기록했는가

## 명령어 요약

```bash
# main 최신화
git switch main
git pull --ff-only origin main

# 브랜치 생성
git switch -c feature/seoul-live-population

# 변경 확인과 커밋
git status --short
git diff
git add -- <관련 파일>
git diff --staged
git commit -m "feat: 서울 실시간 인구 조회 추가"

# 원격 push
git push -u origin feature/seoul-live-population

# PR 병합 후 정리
git switch main
git pull --ff-only origin main
git branch -d feature/seoul-live-population
git push origin --delete feature/seoul-live-population
```
