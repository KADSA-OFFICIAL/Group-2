extends RefCounted
class_name TurnStatus

# 유닛에 붙은 **턴 단위** 버프/디버프/지속피해 하나 (#450).
#
# 기존 `StatusEffectSystem`(초 단위)과 **별개 축**이다. 하나로 합치지 않은 이유:
# 초 단위 효과는 `_process(delta)`로 줄고 턴 단위 효과는 "턴 시작에 1 감소"로 줄어,
# 같은 컨테이너에 넣으면 만료 판정이 두 갈래로 갈린다. 실시간 전투가 살아 있는 동안
# 그 시스템을 건드리면 회귀 위험만 크다.
#
# 지속시간의 의미: `turns_left`는 **자신의 턴 시작마다 1 감소**한다. 그래서 "3턴"은
# 자기 턴 3번을 뜻하고, 속도가 빠른 유닛에게 걸린 디버프가 실제 시간으로 더 빨리
# 끝난다 — 속도가 이득인 축과 일관된다.

# ===== 종류 (Kind) =====
enum Kind {
	BUFF,      # 스탯 증감 (stat_key + value)
	DEBUFF,    # 스탯 감소 (BUFF와 계산은 같고, 정화/저항 대상이라는 점이 다르다)
	DOT,       # 지속 피해 / 격파 상태이상
	SHIELD,    # 보호막
	TAUNT,     # 도발
	ANCHOR,    # 고정 (위치 이동 면역)
	STUN,      # 행동 불가 (동결, 격파 기절)
	BATON,     # 배턴 (양도받은 강화)
}

## 이 효과의 식별자. 같은 id는 갱신(중첩/지속시간 연장)된다.
var id: StringName = &""

var kind: Kind = Kind.BUFF

## 남은 턴 수. 0 이하가 되면 만료된다. -1은 무기한(격파 회복 대기 등).
var turns_left: int = 0

## 중첩 수.
var stacks: int = 1

## 최대 중첩. 0이면 무제한.
var max_stacks: int = 1

# ===== 버프/디버프 =====
## 건드리는 스탯 키. `PlayerStats.set_turn_buff_bonuses()`의 키를 쓴다.
var stat_key: StringName = &""
## 증감값. 중첩당 값이며, 합산 시 `value x stacks`가 들어간다.
var value: float = 0.0
## 가산 채널인가.
var is_flat: bool = false
## 어느 데미지 버킷에 속하는가. UI 표시용.
var bucket: int = TurnCombat.Bucket.BASE

## 추가 스탯 변화. `[{"key": StringName, "value": float, "flat": bool}, ...]`.
##
## 왜 필요한가: 격파 상태이상 하나가 여러 스탯을 건드린다(각인 = 속도 -20% + 받는피해 +12%).
## 스탯 하나만 담으면 각인을 상태 두 개로 쪼개야 하고, 그러면 아이콘이 두 개 뜨고
## 정화가 절반만 걸린다. 상태이상은 **하나**이고 변화가 여러 개인 것이 맞다.
var mods: Array[Dictionary] = []

# ===== 지속 피해 =====
## 어떤 격파 상태이상인가.
var break_status: int = TurnCombat.BreakStatus.BLEED
## 턴당 피해 배율. 기준 스탯은 `dot_scaling`.
var dot_multiplier: float = 0.0
var dot_scaling: int = TurnCombat.Scaling.ATTACK
## 이 효과를 건 유닛의 `unit_id`. 지속 피해는 **건 쪽의 공격력**을 기준으로 계산해야
## 하므로(설계서: 연소 = 공격력 60%/턴) 출처를 기억한다.
var source_id: StringName = &""

## 기준 스탯을 **대상**에서 읽는가. 열상(적 최대HP 2%/턴)이 이 경로를 쓴다.
var dot_from_target: bool = false

## 만료될 때 터지는 피해 배율. 동결의 "해제 시 피해", 속박의 "해제 시 폭발"이 쓴다.
## 0이면 만료 시 아무 일도 없다.
var expire_burst_multiplier: float = 0.0
## 만료 폭발이 중첩당 배율인가. 속박은 중첩 비례로 터진다.
var expire_burst_per_stack: bool = false

# ===== 보호막 =====
var shield_amount: int = 0

## 색상/아이콘 표시용 원소. 격파 상태이상은 원소 색을 그대로 쓴다.
var element: int = -1

## 화면 표시 이름.
var display_name: String = ""


func _init(status_id: StringName = &"", status_kind: Kind = Kind.BUFF, turns: int = 1) -> void:
	id = status_id
	kind = status_kind
	turns_left = turns


# 만료되었는가. -1(무기한)은 만료되지 않는다.
func is_expired() -> bool:
	return turns_left == 0


# 턴 시작 감소. 무기한은 줄지 않는다.
func tick_down() -> void:
	if turns_left > 0:
		turns_left -= 1


# 같은 효과를 다시 받았을 때. 중첩을 올리고 지속시간을 갱신한다.
#
# 지속시간을 **연장이 아니라 갱신**으로 둔 이유: 연장은 무한히 쌓여 "한 번 걸면 영구"가
# 되고, 그러면 재부여가 의미를 잃는다. 갱신은 계속 걸어 줘야 유지된다.
func refresh(added_stacks: int, turns: int) -> void:
	if max_stacks > 0:
		stacks = mini(stacks + added_stacks, max_stacks)
	else:
		stacks += added_stacks
	turns_left = maxi(turns_left, turns)


func is_stat_modifier() -> bool:
	if kind == Kind.BUFF or kind == Kind.DEBUFF:
		return true
	# 격파 상태이상도 스탯을 건드릴 수 있다(각인 = 속도 -20%).
	return not (String(stat_key).is_empty() and mods.is_empty())


# 합산에 들어갈 실효값 (중첩 반영).
func effective_value() -> float:
	return value * float(stacks)


# 이 상태가 만드는 스탯 변화 전부. 주 변화(`stat_key`)와 `mods`를 합쳐 돌려준다.
#
# 반환: `[{"key": StringName, "value": float, "flat": bool}, ...]` — value 는 중첩이 반영된 값이다.
func all_mods() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not String(stat_key).is_empty():
		out.append({"key": stat_key, "value": effective_value(), "flat": is_flat})
	for mod in mods:
		out.append({
			"key": StringName(mod.get("key", &"")),
			"value": float(mod.get("value", 0.0)) * float(stacks),
			"flat": bool(mod.get("flat", false)),
		})
	return out


# 스탯 변화를 하나 추가한다.
func add_mod(key: StringName, mod_value: float, flat: bool = false) -> void:
	mods.append({"key": key, "value": mod_value, "flat": flat})


func get_display_name() -> String:
	if not display_name.is_empty():
		return display_name
	if kind == Kind.DOT:
		return TurnCombat.break_status_name(break_status)
	if not String(stat_key).is_empty():
		return String(stat_key)
	return String(id)


# 아이콘 옆에 띄우는 짧은 라벨. 지속 턴 수를 숫자로 표기한다(설계서 §11.2 (E)).
func format_badge() -> String:
	var name_text := get_display_name()
	if stacks > 1:
		name_text += " %d" % stacks
	if turns_left > 0:
		name_text += " (%d)" % turns_left
	return name_text


func color() -> Color:
	if element >= 0:
		return TurnCombat.element_color(element)
	match kind:
		Kind.DEBUFF, Kind.DOT, Kind.STUN:
			return TurnCombat.COLOR_DEBUFF
		Kind.SHIELD, Kind.ANCHOR, Kind.BATON, Kind.BUFF:
			return TurnCombat.COLOR_BUFF
		_:
			return TurnCombat.COLOR_NEUTRAL
