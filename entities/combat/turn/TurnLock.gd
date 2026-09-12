extends RefCounted
class_name TurnLock

# 자물쇠 한 칸 (#450).
#
# 적이 행동을 예고할 때, 그 행동에 붙는 **봉인 조건** 하나다. 해당 타입의 공격을
# 1회 적중시키면 해제된다.
#
#   🔒 봉인 조건:  🔨  ❄  ❄  ⚡      (강타 1 + 한기 2 + 전격 1)
#
# 이 구조가 하는 일: 매 턴 화면에 **명확한 미니 퍼즐**을 만든다. "이번 턴에 강타 1,
# 한기 2, 전격 1을 넣어야 한다." 자물쇠가 없으면 약점 격파는 "약점 속성 연타"가 되고,
# 판단이 사라진다. (설계서 §4.4.2 — 씨 오브 스타즈의 락 시스템을 인성치에 융합한 것)
#
# 부분 성공에도 보상이 있다: 4개 중 3개를 해제하면 적 행동의 위력이 25%로 떨어진다.
# 그래서 자물쇠를 다 못 열어도 좌절이 적다.

## 원소 자물쇠인가. 꺼져 있으면 물리 타입 자물쇠다.
var is_element: bool = true

## 요구 타입. `is_element`에 따라 `TurnCombat.Element` 또는 `TurnCombat.PhysicalType`.
var value: int = TurnCombat.Element.IMPACT

## 해제되었는가.
var cleared: bool = false


func _init(element_lock: bool = true, lock_value: int = 0) -> void:
	is_element = element_lock
	value = lock_value


# 이 공격이 이 자물쇠를 해제할 수 있는가.
#
# 원소 자물쇠는 원소만 보고, 물리 자물쇠는 물리 타입만 본다 — 두 축이 독립이므로
# "한기 강타"는 한기 자물쇠와 강타 자물쇠를 **각각** 열 수 있다(같은 타격이 둘을
# 동시에 열지는 않는다. 자물쇠 하나당 적중 1회다).
func matches(element: int, physical: int) -> bool:
	if cleared:
		return false
	return value == (element if is_element else physical)


func glyph() -> String:
	return TurnCombat.lock_glyph(is_element, value)


func color() -> Color:
	return TurnCombat.lock_color(is_element, value)


func type_name() -> String:
	return TurnCombat.lock_name(is_element, value)


func duplicate_lock() -> TurnLock:
	var copy := TurnLock.new(is_element, value)
	copy.cleared = cleared
	return copy
