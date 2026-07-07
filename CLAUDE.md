# Group-2 Claude Harness

이 저장소는 issue-first workflow를 사용합니다. Claude Code는 새 기능, 버그 수정, 개선, 리팩터링, 동작 변경을 시작하기 전에 이 하네스를 따라야 합니다.

## Issue-First Rule

- 기능, 버그 수정, 개선, 리팩터링 작업은 GitHub 이슈 없이 구현을 시작하지 않습니다.
- 사용자가 이슈 없이 작업을 요청하면 GitHub 접근 권한이 있을 때 먼저 이슈를 만듭니다.
- GitHub 접근 권한이 없으면 사용자에게 이슈 없이 진행해도 되는지 확인하고, 최종 응답에 이슈 생성이 막혔다는 점을 남깁니다.
- 이슈 번호는 브랜치 이름, 커밋 메시지, PR 본문에 포함합니다.
- 관련 없는 정리 작업은 별도 이슈와 별도 브랜치로 분리합니다.

## Required Issue Detail

모든 기능, 개선, 버그 이슈에는 아래 항목이 있어야 합니다.

- Summary: 무엇이 바뀌어야 하는지.
- Motivation or Problem: 왜 필요한지.
- Current Behavior: 현재 어떻게 동작하는지.
- Expected Behavior: 완료 후 어떻게 동작해야 하는지.
- Scope: 영향을 받을 게임 시스템, 씬, 스크립트, 에셋, 문서.
- Acceptance Criteria: 완료를 증명할 구체적인 기준.
- Verification Plan: 실행할 명령이나 수동 확인 방법.

버그 수정 이슈에는 추가로 아래 항목이 필요합니다.

- Reproduction Steps.
- Actual Result.
- Expected Result.
- Environment, when relevant.

새 기능 이슈에는 추가로 아래 항목이 필요합니다.

- Player Flow.
- Non-goals.
- UX, input, balance, or settings expectations, when relevant.

## Branching

- 이슈 하나당 브랜치 하나를 만듭니다.
- 브랜치 이름은 짧고 이슈 번호를 포함합니다.
- 권장 형식:
  - `issue-<number>-short-topic`
  - `fix-<number>-short-topic`
  - `feat-<number>-short-topic`

## Implementation

- 파일을 수정하기 전에 이슈를 읽고 의도한 동작을 확인합니다.
- 변경 범위는 이슈에 적힌 내용으로 제한합니다.
- 기존 프로젝트 패턴을 우선합니다.
- 큰 구조 변경이나 폴더 정리는 해당 이슈가 직접 요구할 때만 합니다.

## System Conventions

시스템(재화, 스텟, 캐릭터, autoload 등)을 만들거나 수정하기 전에 [SYSTEM_CONVENTIONS.md](SYSTEM_CONVENTIONS.md)를 읽고 따릅니다.

- 기존 코어 시스템(`CurrencySystem`, `PlayerStats`, `CharacterData`/`CharacterDatabase`, `SaveSystem`, `EventBus` 등)을 먼저 확인하고, 있으면 덮어쓰지 말고 재사용/참조합니다.
- 단일 출처 원칙: 재화는 `CurrencySystem.DEFAULT_CURRENCIES`, 스텟은 `PlayerStats`, 캐릭터는 `CharacterData`/`CharacterDatabase`가 유일한 출처입니다. 같은 데이터를 복제·병렬 정의하지 않습니다.
- `project.godot`의 `[autoload]`는 기존 항목을 삭제하지 않고 append만 합니다. 같은 이름/책임이 중복되면 §2에 따라 출처 하나로 수렴시킵니다.
- 큰 통합/머지 전에는 핵심 파일 회귀 여부를 `git diff`로 확인합니다 (`-s ours`류 통합 지양). "MERGEABLE" 표시가 "회귀 없음"을 뜻하지 않습니다.

## Verification

변경한 파일과 게임 엔진 상태에 맞춰 가장 작은 의미 있는 검증부터 실행합니다.

- Godot 프로젝트 설정 확인
- 변경한 씬 또는 스크립트 수동 실행
- 플레이어 입력, UI, 충돌, 게임 흐름 확인
- 사용 가능한 테스트나 빌드 명령이 생기면 해당 명령 실행

PR 본문에는 실제로 확인한 내용을 기록합니다.

## Pull Requests

- PR 제목은 이슈에서 해결한 결과를 요약합니다.
- PR 본문에는 `Closes #<issue-number>`를 포함합니다.
- PR 본문에는 summary, verification, residual risks를 포함합니다.
- 검증 내용이 기록되기 전에는 머지하지 않습니다.

## Merge Flow

- 이슈를 해결하고 검증을 마친 뒤 이슈 브랜치에 커밋합니다.
- 로컬 이슈 브랜치를 원격 저장소에 푸시합니다.
- 이슈 브랜치에서 `dev`로 첫 번째 PR을 엽니다.
- 코드 충돌, 예상하지 못한 파일 변경, 누락된 검증을 확인한 뒤 `dev`에 머지합니다.
- `dev`에서 문제가 없으면 같은 원격 이슈 브랜치에서 `main`으로 두 번째 PR을 엽니다.
- `main` 대상 PR에서도 충돌과 검증 내용을 다시 확인한 뒤 머지합니다.
- `main` 머지가 끝나면 원격 이슈 브랜치를 삭제합니다.
- 정리 후 로컬 저장소는 삭제된 이슈 브랜치가 아니라 `main` 또는 `dev`에 둡니다.
