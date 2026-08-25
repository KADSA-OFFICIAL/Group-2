# assets/sprites/backgrounds

스토리 재생 화면의 **배경 아트**. 챕터 기본 배경(`StoryChapterData.background`)과 줄 단위 장면 전환(`StoryLineData.background`)에 쓴다.

| 파일 | 장면 |
|---|---|
| `city_night.png` | 현대 도시 거리 (챕터 1 도입 — 고백) |
| `forest.png` | 숲길 (챕터 1 등산, 챕터 3 이동) |
| `village.png` | 원시 부락 (챕터 2·3) |

## 규격

- **가로 16:11 내외**(현재 1216x832). 화면은 `KEEP_ASPECT_COVERED` 로 채우므로 비율이 조금 달라도 되지만, 세로로 긴 그림은 좌우가 크게 잘린다.
- **불투명 PNG**. 배경이므로 알파가 필요 없다.
- **아래쪽 1/3 은 인물과 대사 상자가 덮는다.** 중요한 것을 그 자리에 두지 않는다.
- 인물이 그 앞에 서므로 **사람은 그리지 않는다.**

## 새 배경을 넣는 법

1. 파일을 이 폴더에 둔다.
2. 챕터 기본 배경이면 `data/story/chapter_*.tres` 의 `background` 에, 도중 전환이면 그 줄(`StoryLineData`)의 `background` 에 건다.
3. 코드는 고치지 않는다. 배경이 없으면 화면이 챕터 번호로 만든 그라데이션으로 떨어진다.
