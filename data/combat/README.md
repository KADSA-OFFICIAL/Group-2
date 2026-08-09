# data/combat

전투 튜닝 수치(`CombatTuning`)를 저작하는 곳이다.

- **`combat_tuning.tres`** — 전투 수치의 **단일 출처**.
- 정의 스키마: [`entities/combat/CombatTuning.gd`](../../entities/combat/CombatTuning.gd)
- 코드에서 접근: `CombatConfig.tuning.<필드>` (예: `CombatConfig.tuning.mark_threshold`)

## 밸런싱 방법

Godot 에디터에서 `combat_tuning.tres`를 열고 **인스펙터에서 숫자를 고치면 된다. 코드를 편집할 필요가 없다.**
필드는 역할·단계별로 그룹지어 있다(공통 / 탱커 1단계 / 탱커 3단계 / 원거리 1단계 / 원거리 3단계 / 버퍼 1단계 / 버퍼 3단계 / 점령).

실행 중에 값을 다시 읽으려면 `CombatConfig.reload_tuning()`을 호출한다.

## 값의 성격

**현재 값은 전부 `[임시값]`이다.** 플레이 검증을 거치지 않은 임의 시작점이며 밸런싱 대상이다.

가능한 곳은 **비율(percent)**로 정의했다. 기본 스텟이나 피해 공식이 조정되어도 비율 값은 다시 만질 필요가 적기 때문이다.

> 참고: 현재 `PlayerStats` 기본값으로는 물리 공격력 20 vs 물리 방어력 25라
> 피해 공식 `max(공격력 - 방어력, 1)`에 의해 피해가 1로 눌린다.
> 기본 스텟/피해 공식 재조정은 별도 과제다.

## 폴백

`.tres`가 없거나 손상되면 `CombatConfig`가 경고를 남기고 `CombatTuning.gd`의 기본값으로 폴백한다.
따라서 이 파일이 빠져도 게임이 죽지 않는다. 스크립트 기본값과 `.tres` 값은 현재 동일하다.

수치를 새로 추가할 때는 `CombatTuning.gd`에 **기본값과 함께** `@export`를 추가한다.
기본값이 있으면 기존 `.tres`는 누락 필드를 기본값으로 로드하므로 호환이 유지된다.
