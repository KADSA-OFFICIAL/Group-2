extends Resource
class_name TurnSkillEffect

# 턴제 스킬이 일으키는 **효과 하나** (#450).
#
# 설계서 §5.2.3 의 스킬 스키마에서 `effects[]` 배열의 원소에 해당한다.
# 스킬 하나가 여러 효과를 순서대로 일으키므로(피해 → 밀치기 → 버프) 배열이 필요하다.
#
# 왜 리소스인가: `.tres`로 저작해야 밸런싱이 코드 편집 없이 끝난다. 효과를 스킬 필드로
# 평면화하면(예: `push_distance`, `buff_stat`, `buff_value` ...) 한 스킬이 밀치기를 두 번
# 하거나 버프를 세 개 주는 순간 필드가 번호로 복제된다(`buff_stat_2`, `buff_stat_3`).
#
# 참고: docs/turn-combat-design.md

# ===== 효과 종류 (Kind) =====
#
# **정수값을 바꾸지 않는다.** `.tres`에 정수로 굳는다. 새 항목은 뒤에 추가한다.
enum Kind {
	DAMAGE,          # 피해 — 배율 x 기준스탯, 인성치 피해 동반
	TOUGHNESS,       # 인성치 전용 피해 (HP 피해 없음). 자물쇠만 해제하는 효과
	HEAL,            # 회복
	SHIELD,          # 보호막
	BUFF,            # 버프 (stat_key + value + bucket)
	DEBUFF,          # 디버프 (확률 판정을 거친다)
	DOT,             # 지속 피해 / 격파 상태이상 부여
	PUSH,            # 밀치기 — 대상을 뒤쪽 랭크로
	PULL,            # 끌어당기기 — 대상을 앞쪽 랭크로
	SHIFT,           # 자리바꿈 — 시전자가 이동
	ADVANCE,         # 행동 앞당김 (%)
	DELAY,           # 행동 지연 (%)
	EXTRA_TURN,      # 추가 턴
	ENERGY,          # 오의 게이지 증감
	RESONANCE,       # 공명 포인트 증감
	TAUNT,           # 도발
	CLEANSE,         # 디버프 해제
	BATON,           # 배턴 — 추가 턴을 아군에게 양도(양도받은 쪽이 강화된다)
	ANCHOR,          # 고정 — 위치 이동 면역
	HEAT,            # 열기 증감
}

# ===== 대상 범위 (Scope) =====
#
# 스킬의 `turn_targeting`이 "누구를 고르는가"를 정하고, 이 값은 **고른 대상을 기준으로
# 이 효과가 실제로 누구에게 가는가**를 정한다. 둘이 다른 이유: 「제련의 방벽」처럼
# 적을 고르지 않고 아군 전체에 보호막을 주는 스킬이 있고, 「부식의 화폭」처럼
# 주 대상에게는 -32%, 인접에는 -16%를 주는 스킬이 있다.
enum Scope {
	TARGET,            # 고른 대상
	TARGET_ADJACENT,   # 고른 대상의 좌우 인접 (확산의 부수 대상)
	SELF,              # 시전자
	ALL_ENEMIES,       # 적 전원
	ALL_ALLIES,        # 아군 전원
	ALLY_SINGLE,       # 아군 1명 (고른 대상이 아군일 때)
	LOWEST_HP_ALLY,    # HP 비율이 가장 낮은 아군
	ALL_BROKEN,        # 격파 상태인 적 전원
}

# ===== 식별 / 표시 =====
## 화면에 띄우는 짧은 설명. 비워 두면 종류와 수치로 자동 생성한다.
@export var label: String = ""

@export var kind: Kind = Kind.DAMAGE
@export var scope: Scope = Scope.TARGET

# ===== 수치 (Numbers) =====

## 배율. `DAMAGE`/`HEAL`/`SHIELD`에서 `배율 x 기준스탯`으로 쓴다.
## 2.40 = 240% (설계서 §4.15 기준선: 딜러 전투 스킬 단일 240%).
@export var multiplier: float = 0.0

## 배율에 곱할 기준 스탯.
@export var scaling: TurnCombat.Scaling = TurnCombat.Scaling.ATTACK

## 배율과 별도로 더하는 고정값. `기본 데미지 = 배율 x 기준스탯 + 고정값`.
@export var flat: int = 0

## 인성치 피해. `DAMAGE`/`TOUGHNESS`에서 쓴다.
## 물리 타입 배율(강타 x1.3 / 관통 x0.85)이 여기에 곱해진다.
@export var toughness_damage: int = 0

## 인접 대상(확산의 부수 대상)에 적용할 배율 비율. 0이면 튜닝의 기본값을 쓴다.
@export var adjacent_ratio: float = 0.0

## 비율/증감값. `BUFF`/`DEBUFF`(0.32 = +32%), `ADVANCE`/`DELAY`(0.40 = 40%),
## `PUSH`/`PULL`/`SHIFT`(칸 수는 `distance`), `ENERGY`/`RESONANCE`/`HEAT`(증감량은 `amount`).
@export var value: float = 0.0

## 정수 증감량. `ENERGY`(+8), `RESONANCE`(+1), `HEAT`(-10), `EXTRA_TURN`(1회) 등.
@export var amount: int = 0

## 위치 이동 칸 수. `PUSH`/`PULL`/`SHIFT`.
@export var distance: int = 1

## 지속 턴 수. 0이면 즉발(지속되지 않음).
@export var duration: int = 0

## 중첩 수. `DOT`에서 한 번에 쌓는 중첩.
@export var stacks: int = 1

## 부여 확률(0.0~1.0). `DEBUFF`/`DOT`에서만 쓴다. 0이면 확정 부여.
## 효과 적중/저항과 Pity 보정은 `TurnStatusSystem`이 적용한다.
@export var chance: float = 0.0

# ===== 버프/디버프 (Buff / Debuff) =====

## 어느 스탯을 건드리는가. `PlayerStats.set_turn_buff_bonuses()`의 키를 그대로 쓴다.
##
## 가산: `speed`
## 배율: `speed`, `crit_rate`, `crit_damage`, `break_effect`, `effect_hit`, `effect_res`,
##       `energy_recharge`, `heal_boost`, `element_damage_bonus`,
##       `vulnerability`(버킷 D), `damage_bonus`(버킷 A),
##       `defense_reduction`(버킷 B), `res_penetration`(버킷 C)
## 실시간 채널과 공유하는 키: `physical_attack`, `magic_attack`, `physical_defense`,
##       `magic_defense`, `max_hp`, `damage_taken`
@export var stat_key: StringName = &""

## 가산 채널인가. 꺼져 있으면 배율 채널(percent)로 들어간다.
@export var stat_is_flat: bool = false

## 이 버프가 속하는 데미지 버킷. UI가 "어느 버킷을 채우는 버프인가"를 보여 주고,
## 편성 화면이 버킷 중복(안티 시너지)을 경고하는 데 쓴다.
@export var bucket: TurnCombat.Bucket = TurnCombat.Bucket.BASE

# ===== 격파 상태이상 (Break status) =====

## `DOT`이 부여하는 상태이상. 원소 격파가 자동으로 거는 것과 같은 목록이다.
@export var break_status: TurnCombat.BreakStatus = TurnCombat.BreakStatus.BLEED

# ===== 조건 (Condition) =====

## 대상이 격파 상태일 때만 발동한다.
@export var require_broken: bool = false
## 대상이 이 상태이상을 갖고 있을 때만 발동한다(중첩 폭발 등).
@export var require_status: bool = false
@export var require_status_kind: TurnCombat.BreakStatus = TurnCombat.BreakStatus.BIND
## 대상의 HP 비율이 이 값 이하일 때만 발동한다(처형). 0이면 조건 없음.
@export var require_target_hp_below: float = 0.0
## 요구 상태이상의 **중첩당** 추가 배율. 「완성된 초상」의 "중첩당 공격력 55%"가 이 필드다.
@export var per_stack_multiplier: float = 0.0
## 발동 후 요구 상태이상을 소모(폭발)시키는가.
@export var consume_status: bool = false


# ===== 조회 (Accessors) =====

# 이 효과가 피해를 넣는가. 파이프라인을 태울 필요가 있는지 판정한다.
func deals_damage() -> bool:
	return kind == Kind.DAMAGE or (kind == Kind.DOT and multiplier > 0.0)


# 이 효과가 인성치를 깎는가.
func deals_toughness() -> bool:
	return toughness_damage > 0 and (kind == Kind.DAMAGE or kind == Kind.TOUGHNESS)


# 이 효과가 위치를 옮기는가.
func moves_position() -> bool:
	return kind == Kind.PUSH or kind == Kind.PULL or kind == Kind.SHIFT


# 인접 대상 배율. 저작하지 않았으면 튜닝의 기본값(0.5)을 쓴다.
func get_adjacent_ratio() -> float:
	if adjacent_ratio > 0.0:
		return adjacent_ratio
	return PlayerStats.get_tuning_turn().blast_adjacent_ratio


# 화면에 띄울 설명. 저작된 `label`이 있으면 그것을 쓰고, 없으면 수치로 만든다.
#
# 자동 생성이 있는 이유: 프로토타입에서 효과를 수십 개 저작하는 동안 라벨을 매번
# 적는 것은 낭비인데, 라벨이 비면 UI가 빈칸이 되어 무슨 효과인지 알 수 없다.
func get_label() -> String:
	if not label.is_empty():
		return label

	match kind:
		Kind.DAMAGE:
			return "피해 %d%%" % int(round(multiplier * 100.0))
		Kind.TOUGHNESS:
			return "인성치 -%d" % toughness_damage
		Kind.HEAL:
			return "회복 %d%%" % int(round(multiplier * 100.0))
		Kind.SHIELD:
			return "보호막 %d%% (%d턴)" % [int(round(multiplier * 100.0)), duration]
		Kind.BUFF, Kind.DEBUFF:
			var sign_text := "+" if value >= 0.0 else ""
			if stat_is_flat:
				return "%s %s%d (%d턴)" % [String(stat_key), sign_text, int(value), duration]
			return "%s %s%d%% (%d턴)" % [String(stat_key), sign_text, int(round(value * 100.0)), duration]
		Kind.DOT:
			return "%s %d중첩 (%d턴)" \
				% [TurnCombat.break_status_name(break_status), stacks, duration]
		Kind.PUSH:
			return "밀치기 %d칸" % distance
		Kind.PULL:
			return "끌어당기기 %d칸" % distance
		Kind.SHIFT:
			return "자리바꿈 %d칸" % distance
		Kind.ADVANCE:
			return "행동 앞당김 %d%%" % int(round(value * 100.0))
		Kind.DELAY:
			return "행동 지연 %d%%" % int(round(value * 100.0))
		Kind.EXTRA_TURN:
			return "추가 턴 %d회" % maxi(amount, 1)
		Kind.ENERGY:
			return "오의 게이지 %+d" % amount
		Kind.RESONANCE:
			return "공명 포인트 %+d" % amount
		Kind.TAUNT:
			return "도발 (%d턴)" % duration
		Kind.CLEANSE:
			return "디버프 해제 %d개" % maxi(amount, 1)
		Kind.BATON:
			return "배턴 양도"
		Kind.ANCHOR:
			return "고정 (%d턴)" % duration
		Kind.HEAT:
			return "열기 %+d" % amount
		_:
			return "?효과"


func validate() -> Array[String]:
	var problems: Array[String] = []

	if kind == Kind.DAMAGE and multiplier <= 0.0 and flat <= 0:
		problems.append("DAMAGE 효과에 배율도 고정값도 없습니다(피해가 0입니다).")
	if kind == Kind.TOUGHNESS and toughness_damage <= 0:
		problems.append("TOUGHNESS 효과에 toughness_damage가 없습니다.")
	if (kind == Kind.BUFF or kind == Kind.DEBUFF) and String(stat_key).is_empty():
		problems.append("BUFF/DEBUFF 효과에 stat_key가 없습니다.")
	if (kind == Kind.BUFF or kind == Kind.DEBUFF) and duration <= 0:
		problems.append("BUFF/DEBUFF 효과의 duration이 0입니다(즉시 사라집니다).")
	if kind == Kind.DOT and duration <= 0:
		problems.append("DOT 효과의 duration이 0입니다(한 번도 발동하지 않습니다).")
	if moves_position() and distance <= 0:
		problems.append("위치 이동 효과의 distance가 0입니다.")
	if (kind == Kind.ADVANCE or kind == Kind.DELAY) and value <= 0.0:
		problems.append("ADVANCE/DELAY 효과의 value가 0입니다.")
	if kind == Kind.ADVANCE and value > 1.0:
		problems.append("ADVANCE의 value가 1.0을 넘습니다(100% = 즉시 행동이 상한입니다).")
	if chance < 0.0 or chance > 1.0:
		problems.append("chance는 0과 1 사이여야 합니다.")
	if stacks < 1:
		problems.append("stacks는 1 이상이어야 합니다.")
	if require_target_hp_below < 0.0 or require_target_hp_below > 1.0:
		problems.append("require_target_hp_below는 0과 1 사이여야 합니다.")

	return problems
