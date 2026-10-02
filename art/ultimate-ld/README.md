# 오의 LD 공격 애니메이션 원본 (#546)

오의 풀 연출에서 재생되는 캐릭터 6명의 LD(편성 초상 그림체) 2D 공격 애니메이션 원본이다.

| 파일 | 내용 |
|---|---|
| `<id>.mp4` | 원본 클립. 1080×1920, 24fps, 72프레임(3초). 설아·미나·태희·아린은 초록, 하랑·강지는 자홍 배경 |
| `generation_brief.txt` | 생성 지시문(포즈 시트 6컷 규칙, 캐릭터별 동작) |
| `SOURCE_README.txt` | 제작 쪽 설명(제작 방식·한계) |
| `validation.json` | 제작 쪽 검증값(해상도·프레임 수·결정 포즈 유지 시간·여백) |

## 어떻게 만들어졌나

- 아스트라용 프롬프트([docs/ultimate-ld-animation-prompts.md](../../docs/ultimate-ld-animation-prompts.md))를 바탕으로,
  **이미지 생성으로 캐릭터마다 공격 포즈 6장(준비 → 예비 동작 → 최대 젖힘 → 공격 → 여운 → 결정 포즈)**을 그리고,
  로컬 코드로 포즈 전환·몸 기울기·머리카락 움직임을 합성한 **리미티드 애니메이션**이다.
  아스트라(영상 생성)로 뽑은 결과물은 아니다.
- 참조: 편성 초상(그림체·의상) + 전투 프레임 공격 컷(무기). 생성 과정에서 의상·비율·무기·표정에 세부 차이가 있다.
- 1080×1920 은 원화를 키워 렌더링한 크기다(원화 자체가 그 해상도는 아니다).

## 게임 에셋으로 바꾸기

투명 PNG 시퀀스 zip(`<id>_transparent_frames.zip`, 캐릭터당 약 60MB)은 저장소에 넣지 않는다.
zip 이 있는 폴더를 넘겨 변환 스크립트를 돌린다:

```bash
python tools/build_ultimate_videos.py <zip 폴더>
godot --headless --path . --import
```

- `assets/video/ultimate/<id>.ogv` — 알파를 옆에 붙인 Theora(왼쪽 색 / 오른쪽 알파, 810×1440 ×2). 약 2MB
- `assets/sprites/characters/cutins/ult/char_<id>_ult.png` — 마지막 프레임(결정 포즈) 정지 그림

다시 뽑은 클립으로 교체할 때도 같은 이름으로 위 두 파일만 바뀌면 된다(코드 수정 없음).
공격 정점 시점이 크게 다르면 `UltimateCutin.VIDEO_STRIKE`(기술명 타이포가 박히는 시점)를 맞춘다.
