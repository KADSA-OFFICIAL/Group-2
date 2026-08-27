# data/tutorial

스테이지별 튜토리얼 단계(`TutorialSequenceData`)를 이 폴더에 저작한다.
`TutorialSystem`(autoload)이 시작 시 이 폴더의 모든 `.tres` 를 로드해 `stage_id` 로 조회한다.

- 시퀀스 스키마: [`entities/tutorial/TutorialSequenceData.gd`](../../entities/tutorial/TutorialSequenceData.gd)
- 단계 스키마: [`entities/tutorial/TutorialStepData.gd`](../../entities/tutorial/TutorialStepData.gd)

## 한 단계가 지나가는 방식 — 두 국면

단계는 **읽는 중 → 하는 중** 두 국면을 거친다.

| 국면 | 전투 | 넘어가는 조건 |
|---|---|---|
| 읽는 중 | **멈춘다** | 확인 키(`ui_accept`) |
| 하는 중 | 흐른다 | 저작된 `advance` 조건 |

`advance = CONFIRM` 인 단계는 읽는 국면에서 바로 다음 단계로 간다(하는 국면이 없다).

**두 국면인 이유**: 정지 하나로 끝내면 "대시해 보자" 같은 단계에서 게임이 영영 멈춘다 —
멈춘 채로는 대시도 평타도 할 수 없다. 그래서 먼저 멈춰서 읽히고, 확인하면 전투를 다시
흘려 조건을 기다린다.

## 진행 조건 (`TutorialStepData.Advance`)

| 값 | 조건 | 듣는 신호 | `effect_id` |
|---|---|---|---|
| `CONFIRM` | 확인 키 | (입력) | — |
| `DASH` | 플레이어가 대시했다 | `EventBus.player_dashed` | — |
| `EFFECT_APPLIED` | 적에게 그 효과가 붙었다 | `EventBus.status_effect_applied` | **필수** |
| `EFFECT_BURST` | 그 효과 게이지가 터졌다 | `EventBus.status_effect_burst` | **필수** |
| `EXECUTE` | 처형이 성사됐다 | `EventBus.enemy_executed` | — |

`effect_id` 가 필요한 조건인데 비어 있으면 `validate()` 가 잡는다 — 그 단계는 영원히
넘어가지 않고 전투도 멈춘 채라, 로드 시점에 드러나야 한다.

`required_count` 를 2 이상으로 두면 그 횟수만큼 조건이 성립해야 넘어간다.

## 재사용 원칙 (단일 출처)

- **가르치는 규칙을 여기서 정의하지 않는다.** 시너지 체인·수치의 출처는
  [`docs/combat-screen-design.md`](../../docs/combat-screen-design.md) §8 과 `SynergySystem`·`CombatConfig` 다.
  저작본은 그 규칙을 **설명**할 뿐이므로, 규칙이 바뀌면 문구도 함께 고쳐야 한다.
- **상태 효과 id** 는 `data/status_effects/*.tres`(`StatusEffectDatabase`)가 출처다.
- **완료 기록**은 `TutorialSystem` 이 `SaveSystem` 제공자(`"tutorial"`)로 저장한다.
  한 번 끝낸 스테이지에서는 다시 뜨지 않는다.

## 저작된 시퀀스

| 파일 | 스테이지 | 가르치는 것 |
|---|---|---|
| `stage_1_1.tres` | `stage_1_1` | 역할군 시너지 1단계 3개, 대시 회피, 표식 → 기절 → 처형 체인 |
