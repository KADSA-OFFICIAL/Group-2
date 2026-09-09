extends RefCounted
class_name TurnIntent

# 적의 **행동 예고** (#450).
#
# 설계 3원칙의 첫 줄이 "모든 정보를 공개한다"이므로, 적이 다음에 무엇을 할지와
# 그것이 얼마나 아플지를 **행동 전에** 전부 보여 준다. 슬레이 더 스파이어의 의도
# 아이콘을 정확한 수치까지 밀어붙인 것이다(설계서 §4.8.2).
#
#   ⚠ 다음 행동: 「멸절의 낙뢰」
#      전체 피해 1,240
#   🔒 봉인 조건:  🔨  ❄  ❄  ⚡
#
# 왜 정확한 수치인가: 플레이어가 "보호막 800짜리를 깔면 막힌다"를 **계산**할 수 있어야
# 성공이 실력이 되고 실패가 납득이 된다. "큰 공격이 온다" 정도만 알려 주면 억울해진다.

## 예고된 스킬.
var skill: SkillData = null

## 노린 대상들의 `unit_id`. 어그로 계산 결과이며, 예고 시점에 확정된다 —
## 예고와 실제 대상이 다르면 공개된 정보가 거짓말이 된다.
var target_ids: Array[StringName] = []

## 대상별 **예상 피해**. `unit_id` -> 피해. 대상의 현재 방어력·보호막·취약을 반영한
## 실제 예상치다(설계서 §4.8.2). 파이프라인을 랜덤 변동 없이 한 번 돌려 얻는다.
var expected_damage: Dictionary = {}

## 이 행동을 봉인하는 자물쇠들.
var locks: Array[TurnLock] = []

## 자물쇠 일부 해제로 깎인 위력 비율. 1.0 = 원래 위력, 0.0 = 무산.
var power_ratio: float = 1.0

## 무산되었는가(자물쇠 전부 해제).
var nullified: bool = false


# 남은 자물쇠 개수.
func remaining_locks() -> int:
	var count := 0
	for lock in locks:
		if not lock.cleared:
			count += 1
	return count


func total_locks() -> int:
	return locks.size()


func cleared_locks() -> int:
	return total_locks() - remaining_locks()


# 자물쇠 상태로부터 위력 비율을 다시 계산한다.
#
# 규칙(설계서 §4.4.2): 전부 해제 → 무산(0.0). 일부 해제 → 남은 비율만큼만.
# 4개 중 3개 해제 = 위력 25%.
func recalculate_power() -> void:
	var total := total_locks()
	if total == 0:
		power_ratio = 1.0
		nullified = false
		return

	var remaining := remaining_locks()
	if remaining == 0:
		power_ratio = 0.0
		nullified = true
		return

	power_ratio = float(remaining) / float(total)
	nullified = false


# 이 공격으로 열 수 있는 자물쇠 하나를 찾는다. 없으면 null.
#
# 같은 타입 자물쇠가 여러 개면 **앞쪽부터** 하나만 연다 — 한 번의 적중이 자물쇠 하나다.
func find_matching_lock(element: int, physical: int) -> TurnLock:
	for lock in locks:
		if lock.matches(element, physical):
			return lock
	return null


# 자물쇠 열을 표시 문자열로 만든다. 해제된 것은 흐리게 그릴 수 있도록 함께 반환한다.
func format_locks() -> String:
	var parts: Array[String] = []
	for lock in locks:
		parts.append(("(%s)" % lock.glyph()) if lock.cleared else lock.glyph())
	return "  ".join(parts)


# 대상 전체에 걸친 예상 피해 총합. HUD 요약이 쓴다.
func total_expected_damage() -> int:
	var total := 0
	for id in expected_damage:
		total += int(expected_damage[id])
	return total


# 한 줄 요약. 정보 표시 단계에 따라 얼마나 공개할지 정한다 (설계서 §4.8.2).
func describe(detail: int = TurnCombat.InfoDetail.VERBOSE) -> String:
	if skill == null:
		return "다음 행동: 없음"

	var title := "「%s」" % skill.display_name
	match detail:
		TurnCombat.InfoDetail.CHALLENGE:
			return "다음 행동: ???"
		TurnCombat.InfoDetail.STANDARD:
			return "다음 행동: %s" % title
		_:
			var damage := total_expected_damage()
			if damage <= 0:
				return "다음 행동: %s" % title
			var hits := maxi(skill.turn_hits, 1)
			if hits > 1:
				return "다음 행동: %s  예상 피해 %d x %d회" % [title, damage / hits, hits]
			return "다음 행동: %s  예상 피해 %d" % [title, damage]
