# data/story

스토리 챕터(`StoryChapterData`) 리소스(`*.tres`)를 이 폴더에 저작한다.
`StoryDatabase`(autoload)가 시작 시 이 폴더의 모든 `.tres`를 로드해
`chapter_id`로 조회를 제공한다. 목록 순서는 `number` 를 따른다.

- 정의 스키마: [`entities/story/StoryChapterData.gd`](../../entities/story/StoryChapterData.gd)
- 한 줄 스키마: [`entities/story/StoryLineData.gd`](../../entities/story/StoryLineData.gd)

## 대본은 세 가지로만 이루어진다

| 종류 | 원본 대본의 예 |
|---|---|
| `NARRATION` 지문 | `주인공 골목길에서 소꿉친구를 기다린다.` / `암전` |
| `DIALOGUE` 대사 | `주인공: 소꿉아..기다리고 있었어!` |
| `BATTLE` 전투 | `전투 시작, 주인공이 이김` |

## 화자는 문자열이다

`speaker` 는 `CharacterData` 의 id 가 아니라 **표시 이름 문자열**이다.
대본의 화자 중 상당수가 아직 로스터에 없거나(여신, 마을 사람들, 각종 수인)
이름이 미정이다(`주인공`, `소꿉친구`, `???`).

로스터와의 연결이 정해지면 `character_id` 필드를 함께 두고 이 값은 표시용으로 남긴다.

## 전투 연결은 아직 비어 있다

`BATTLE` 줄의 `stage_id` 가 전부 비어 있다. 저작된 `StageData` 가 없기 때문이다.
지금은 "여기서 전투가 있다"는 표시만 하고, 스테이지가 저작되면 그 id 를 채우면
화면에 출격 버튼이 붙는다.

## 아직 없는 것

- 진행도(어디까지 읽었는가) 저장
- 선택지·분기
- 연출(배경·초상·효과음)

정해지면 `@export` 필드를 **기본값과 함께** 추가한다.
