# data/goddess_skills

여신의 스킬(`GoddessSkillData`) 리소스(`*.tres`)를 이 폴더에 저작한다.
`GoddessSkillSystem`(autoload)이 시작 시 이 폴더의 모든 `.tres` 를 로드해 `skill_id` 로 조회한다.

- 정의 스키마: [`entities/goddess/GoddessSkillData.gd`](../../entities/goddess/GoddessSkillData.gd)

## 캐릭터 스킬(`SkillData`)과 다른 점

| | 캐릭터 스킬 | 여신의 스킬 |
|---|---|---|
| 소유 | 캐릭터가 배운다(`CharacterData.skills`) | **파티가 하나를 골라 들고 나간다** |
| 제약 | 쿨타임 / 게이지 | **스테이지당 1회** |
| 발동 | Q · E (조종 중인 캐릭터) | **R** (파티 공용) |
| 수치 | `base_power` 등 | 종류마다 다른 파라미터 |

그래서 `SkillData` 를 재사용하지 않는다. 대신 **강화 배수는 같은 것을 쓴다** —
`PlayerStats.get_goddess_skill_boost()`(신앙심 × `faith_to_skill_boost` + 거울)이며,
그 배수의 이름이 가리키는 대상이 바로 이 스킬이다.

## 강화 배수는 파티 최고값

여신 스킬은 파티 공용인데 배수는 캐릭터 스텟·장비에서 나온다. `GoddessSkillSystem.get_boost()`
는 **파티 내 최고값**을 쓴다 — 거울 하나를 한 명에게 끼우면 파티 전체가 이득이 되어
투자 판단이 단순해지고, 시전 직전에 조종 캐릭터를 바꿔 최적화하는 짓을 강요하지 않는다.

## 새 스킬을 추가할 때

1. `GoddessSkillData.Kind` 에 종류를 추가한다.
2. `GoddessSkillSystem.cast()` 의 `match` 에 구현 함수를 한 개 추가한다.
3. 이 폴더에 `.tres` 를 저작한다. 편성 화면과 HUD 는 고치지 않는다(목록을 시스템에서 읽는다).

## 저작된 스킬

| 파일 | 효과 | 기본 수치 |
|---|---|---|
| `time_stop.tres` | 파티원을 제외한 시간 정지 | 3.5초 × 강화 배수 |
| `revive.tres` | 죽은 파티원 1명 부활 | 최대 체력 30% × 강화 배수(상한 100%) |
| `time_haste.tres` | 10초 동안 파티 전원 이속·공속 점증 | 끝에 공속 +50% / 이속 +20% × 강화 배수 (곡선 진행도^2) |

수치는 전부 `[임시값]` 이며 밸런싱 대상이다.
