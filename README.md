# Stone Age Shipduck Game

Godot 4로 제작 중인 공동개발 게임 프로젝트입니다.

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
├── icon.svg
└── project.godot
```

## 협업 규칙

- 작업 전 최신 변경사항을 `git pull`로 받아오세요.
- 기능 하나당 브랜치 하나 (`feat-<번호>-설명` 형식).
- 씬 파일(.tscn)을 동시에 수정하면 충돌이 나기 쉬우니 담당자를 나눠서 작업하세요.
- PR은 `dev` → `main` 순서로 머지합니다.

## 팀원

- KADSA-OFFICIAL/Group-2 contributors
