# data/story

스토리 챕터(`StoryChapterData`) 리소스(`*.tres`)를 이 폴더에 저작한다.
`StoryDatabase`(autoload)가 시작 시 이 폴더의 모든 `.tres`를 로드해
`chapter_id`로 조회를 제공한다. 목록 순서는 `number` 를 따른다.

- 정의 스키마: [`entities/story/StoryChapterData.gd`](../../entities/story/StoryChapterData.gd)
- 한 줄 스키마: [`entities/story/StoryLineData.gd`](../../entities/story/StoryLineData.gd)
- 스토리 전용 화자: [`cast/`](cast) — 아래 "화자는 id 로 해석하고" 참고

## 대본은 세 가지로만 이루어진다

| 종류 | 원본 대본의 예 |
|---|---|
| `NARRATION` 지문 | `주인공 골목길에서 소꿉친구를 기다린다.` / `암전` |
| `DIALOGUE` 대사 | `주인공: 소꿉아..기다리고 있었어!` |
| `BATTLE` 전투 | `전투 시작, 주인공이 이김` |

## 화자는 id 로 해석하고, 없으면 문자열로 떨어진다

`speaker` 는 **표시 이름 문자열**이고 `character_id` 가 인물의 정체성이다.
문자열이 정체성이면 오타가 곧 다른 인물이 된다(`마을사람들` / `마을 사람들` 이 서로 다른
색으로 무대에 섰던 일이 실제로 있다). `character_id` 가 있으면 이름·초상·색이 한 출처에서
나오고, 이름을 바꿔도 대본을 고칠 필요가 없다.

해석 순서는 세 출처다 (`StoryLineData.get_character()`):

| 순서 | 출처 | 무엇 |
|---|---|---|
| 1 | `CharacterDatabase` | 플레이어 로스터 6명 (`data/characters`) |
| 2 | `EnemyDatabase` | 적 (`data/enemies`) — 적도 대사를 한다 |
| 3 | `StoryCastDatabase` | **스토리 전용 화자** (`data/story/cast`) |

**cast 가 맨 뒤인 것이 중요하다.** 여신은 지금 cast 에서 해석되지만 나중에 적으로 저작될
인물이다. 그때 `EnemyData` 를 만들면 2번에서 먼저 잡히므로 대본도 cast 도 고칠 것이 없다
(cast 파일만 지우면 된다).

스토리 전용 화자를 `CharacterData` 로 저작하면 **그 인물이 로스터의 일원이 되어 역할·스텟·
장비 슬롯을 갖는다.** 그래서 `data/story/cast` 를 따로 둔다 (#202) — 정의 스키마는
[`entities/story/StoryCastData.gd`](../../entities/story/StoryCastData.gd).

`character_id` 를 비워 두는 것도 정상이다. 군중처럼 정의를 둘 만큼 정체성이 없는 화자
(`마을 사람들`, `???`)는 `speaker` 문자열이 그대로 이름이 되고 화면은 이름 해시로 색을 고른다.

## 연출은 필드로 지시한다

연출은 저작물이다. 화면이 본문을 훑어 짐작하지 않는다.

### `emotion` — 인물 반응 (대사 줄에만)

| 값 | 언제 | 몸짓 |
|---|---|---|
| `AUTO` (기본) | 대부분의 줄 | 문장부호로 추론한다 (아래) |
| `NORMAL` | 평범한 대사 | 가볍게 끄덕인다 |
| `SURPRISE` | 놀람·강조 | 튀어오른다 |
| `QUESTION` | 의문 | 고개를 갸웃한다 |
| `DOWN` | 머뭇거림·낙담 | 처진다 |

`AUTO` 추론 규칙 (`StoryLineData.resolve_emotion()`):
`!` 있으면 `SURPRISE` → `?` 있으면 `QUESTION` → `..` 또는 `…` 있으면 `DOWN` → 그 외 `NORMAL`.

**대사 수백 줄에 감정을 일일이 적을 필요는 없다.** 부호로 안 맞는 줄만 명시하면 된다.
부호와 다른 감정을 원할 때가 그런 경우다 — 예를 들어 `"그래…!"` 를 낙담이 아니라
놀람으로 연기시키고 싶을 때.

화자가 없는 줄(지문·전투)에 `emotion` 을 지정하면 `validate()` 가 잡는다.
반응할 인물이 없기 때문이다.

### `screen_effect` — 화면 연출

| 값 | 효과 |
|---|---|
| `NONE` (기본) | 없음 |
| `BLACKOUT` | 어두워졌다 돌아온다 |
| `SHAKE` | 배경과 인물이 흔들린다 (대사 상자는 흔들리지 않는다) |

**`screen_effect` 에는 자동 추론이 없다.** 화면 전체를 덮는 연출이 저절로 일어나면
안 되므로 반드시 지시해야 한다. 지금 `chapter_1` 의 암전 3줄이 이렇게 저작되어 있다.

`BATTLE` 줄은 지시하지 않아도 흔들린다. 그건 본문 추측이 아니라 **줄 종류**가 정하는
것이라 저작 실수로 잘못 걸릴 여지가 없다. 명시한 값이 있으면 그쪽이 이긴다.

## 전투 연결은 아직 비어 있다

`BATTLE` 줄의 `stage_id` 가 전부 비어 있다. 저작된 `StageData` 가 없기 때문이다.
지금은 "여기서 전투가 있다"는 표시만 하고, 스테이지가 저작되면 그 id 를 채우면
화면에 출격 버튼이 붙는다.

## 아직 없는 것

- 선택지·분기
- 인물 등·퇴장 지시 (지금은 무대 정원에 따라 자동으로 정해진다)
- 배경 지정, 카메라, 효과음·BGM
- 대사별 표시 속도·대기 시간

정해지면 `@export` 필드를 **기본값과 함께** 추가한다.
기본값이 있으면 기존 `.tres` 는 그 필드 없이도 그대로 로드된다.
