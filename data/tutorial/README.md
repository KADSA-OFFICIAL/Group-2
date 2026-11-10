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
| `stage_1_1.tres` | `stage_1_1` | (실시간) 역할군 시너지 1단계 3개, 대시 회피, 표식 → 기절 → 처형 체인 |
| `prologue_turn_1_1.tres` | `stage_1_1` | (턴제, 프롤로그 #594) 행동 순서 → 평타 → 약점·자물쇠 → 스킬·공명 → 예고·격파 → 첫 궁극기 → 자유 전투 |

## 턴제 시퀀스 (#594)

`combat = TURN` 인 시퀀스는 턴제 전투(`TurnBattle`)가 쏘는 `EventBus.turn_stage_started` 로 켜진다.
실시간 시퀀스와 같은 `stage_id` 를 써도 되고, 완료 기록은 `turn/<stage_id>` 로 따로 남는다.

### 한 단계가 지나가는 방식

실시간과 같이 **읽는 중 → 하는 중** 두 국면이지만 트리를 멈추지 않는다.

1. 단계가 바뀌면 바로 띄우지 않고 `actor_id` 아군의 차례를 당긴다(`turn_actor_requested` →
   `TimelineSystem.forced_next_id`). 확인 단계는 다음 행동 단계의 아군을 미리 당긴다.
2. 연출이 끝나고 그 아군이 입력을 기다리면 띄운다(읽는 중 — 전투 화면이 진행 루프를 세운다).
3. 확인하면 하는 중이 된다. 화면은 `allows_turn_input()` 관문으로 **시킨 조작만** 받는다
   (행동자·`skill_id`·`target_id`). 배속·자동·일시정지는 `unlock_controls` 단계부터 열린다.

| 값 | 조건 | 듣는 신호 | 필수 필드 |
|---|---|---|---|
| `TURN_BASIC` / `TURN_SKILL` / `TURN_ULTIMATE` | 그 아군이 그 행동을 했다 | `EventBus.turn_action_used` | `actor_id` |
| `TURN_LOCK_CLEARED` | 그 적의 자물쇠가 열렸다 | `EventBus.turn_lock_cleared` | `target_id` |
| `TURN_BREAK` | 그 적이 격파됐다 | `EventBus.turn_weakness_broken` | `target_id` |
| `TURN_VICTORY` | 전투에서 이겼다 | `EventBus.turn_battle_ended` | — |

`highlight` 키: `timeline` · `resonance` · `intent` · `toggles` · `action:<skill_id>` ·
`ultimate:<unit_id>` · `target:<unit_id>`. `a|b` 로 두 영역을 합친다. 자리는 HUD 가 이번 프레임에
실제로 그린 히트존에서 온다(`TurnBattleHUD.tutorial_rect()`).

`showcase` 단계의 궁극기는 컷인 설정과 무관하게 풀 컷인이고 앞에 강조 연출이 붙는다.
`TURN_ULTIMATE` 단계가 뜨면 전투 화면이 그 아군의 게이지를 채운다.

### 저작된 판

안내는 "하랑의 충격이 자물쇠를 연다"처럼 결과를 약속한다. 그래서 판을 고정한다:
`battle_seed`(시드), `ally_hp_floor`(1 이면 지지 않는다), `scripted_locks`(첫 예고의 자물쇠,
`"e<원소>"`/`"p<물리>"`). 적 정의나 키트가 바뀌면 `tests/tutorial/VerifyPrologueTutorial.tscn` 이
저작된 시퀀스를 실제 전투로 끝까지 재생해 어긋남을 잡는다.
