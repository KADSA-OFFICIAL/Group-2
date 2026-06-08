# Stone Age Shipduck Game

KADSA Group-2에서 공동개발하는 Godot 4 게임 프로젝트입니다.

## 요구 사항

- [Godot Engine 4.6](https://godotengine.org/download/) (Forward Plus 렌더러 사용)

## 프로젝트 시작하기

```bash
# 저장소 클론
git clone https://github.com/KADSA-OFFICIAL/Group-2.git
cd Group-2
```

Godot을 실행한 뒤 **Import** → 클론한 폴더의 `project.godot` 파일을 선택합니다.

## 폴더 구조

```
├── scenes/       # 게임 씬 (.tscn)
├── scripts/      # GDScript 파일 (.gd)
├── assets/
│   ├── sprites/  # 이미지, 스프라이트
│   ├── audio/    # 사운드, 음악
│   └── fonts/    # 폰트
├── autoload/     # 싱글톤 시스템 (EventBus, GameManager, SaveSystem 등)
├── icon.svg
└── project.godot
```

## GitHub 작업 흐름

이 프로젝트는 `issue -> branch -> commit -> PR to dev -> PR to main` 흐름으로 작업합니다.

- 안정 버전은 `main` 브랜치에 둡니다.
- 새 기능, 개선, 버그 수정은 `dev`에서 작업 브랜치를 만들어 진행합니다.
- 작업 브랜치 이름은 `feat-12-player-jump`, `fix-18-camera-bug`, `issue-20-folder-cleanup`처럼 이슈 번호를 포함합니다.
- 작업 PR은 먼저 `dev`로 올립니다.
- `dev`에서 문제가 없으면 같은 작업 브랜치에서 `main`으로 PR을 올립니다.

자세한 규칙과 로컬 명령은 [docs/github-workflow.md](docs/github-workflow.md)를 확인하세요.

## 협업 규칙

- 작업 전 최신 변경사항을 `git pull`로 받아오세요.
- 기능 하나당 브랜치 하나 (`feat-<번호>-설명` 형식).
- 씬 파일(.tscn)을 동시에 수정하면 충돌이 나기 쉬우니 담당자를 나눠서 작업하세요.
- PR은 `dev` → `main` 순서로 머지합니다.

## 팀원

- KADSA-OFFICIAL/Group-2 contributors
