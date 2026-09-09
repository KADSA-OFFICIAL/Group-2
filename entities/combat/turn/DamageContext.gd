extends RefCounted
class_name DamageContext

# 피해 계산 한 건의 **입력·중간값·결과·계산 내역** (#450).
#
# 설계서 §5.2.2 의 `DamageContext`에 해당한다. 파이프라인 각 단계가 이 객체를 받아
# 값을 고치고 `log`에 한 줄을 남긴다.
#
# **각 단계가 log에 문자열을 남기게 하면 그대로 플레이어용 전투 로그가 된다.**
# 개발 디버깅과 유저 편의를 동시에 해결하는 설계다 — 두 번 만들지 않는다.

# ===== 입력 (Input) =====
var source: TurnUnit = null
var target: TurnUnit = null
var skill: SkillData = null
var effect: TurnSkillEffect = null

var element: int = TurnCombat.Element.IMPACT
var physical_type: int = TurnCombat.PhysicalType.SLASH

## 확산 인접 등으로 곱해지는 대상별 비율.
var target_ratio: float = 1.0

## 이 계산이 몇 번째 히트인가 (1부터). 다단 히트 로그를 구분한다.
var hit_index: int = 1
var hit_count: int = 1

## 격파 데미지인가. 버킷 F(격파 특화)가 여기서만 걸린다.
var is_break_damage: bool = false
## 초격파 피해인가.
var is_overbreak: bool = false
## 지속 피해(DoT)인가. **치명타가 나지 않고 인성치를 깎지 않는다.**
var is_dot: bool = false
## 추가 피해(Additional DMG)인가. 치명타 불가, 인성치 피해 없음.
var is_additional: bool = false

## 예상 피해를 뽑는 중인가. 랜덤 변동과 치명타 굴림을 끄고 기대값을 쓴다.
## 적 행동 예고의 "예상 피해 840"이 이 모드로 계산된다 — 공개한 수치가 실제와 크게
## 다르면 정보 공개의 값어치가 사라진다.
var preview_mode: bool = false

# ===== 버킷 (Buckets) =====
#
# `Bucket` -> 그 버킷의 합산값. **버킷 안은 가산, 버킷끼리는 곱연산.**
var buckets: Dictionary = {}

# ===== 중간값 / 결과 (Working values) =====
var base_damage: float = 0.0
var damage: float = 0.0
var is_crit: bool = false
var crit_multiplier: float = 1.0
var defense_coefficient: float = 0.0

## 인성치 피해 (물리 타입 배율 적용 후).
var toughness_damage: int = 0
## 약점을 찔렀는가. 약점이 아니면 인성치를 깎지 않는다.
var hits_weakness: bool = false

## 보호막이 흡수한 양.
var shield_absorbed: int = 0
## 실제로 HP에서 깎인 양.
var hp_damage: int = 0
## 이 타격으로 대상이 죽었는가.
var killed: bool = false

## 계산 내역. 각 단계가 한 줄씩 남긴다.
var log: Array[String] = []


func add_bucket(bucket: int, value: float) -> void:
	buckets[bucket] = float(buckets.get(bucket, 0.0)) + value


func get_bucket(bucket: int) -> float:
	return float(buckets.get(bucket, 0.0))


func note(line: String) -> void:
	log.append(line)


# 최종 피해 정수값.
func final_damage() -> int:
	return hp_damage + shield_absorbed


# 전투 로그 한 줄. 플레이어가 보는 형태다.
func summary() -> String:
	if source == null or target == null:
		return "?"

	var tags: Array[String] = []
	if is_crit:
		tags.append("치명타")
	if hits_weakness:
		tags.append("약점")
	if is_break_damage:
		tags.append("격파")
	if is_overbreak:
		tags.append("초격파")
	if is_dot:
		tags.append("지속")

	var tag_text := (" [%s]" % ", ".join(tags)) if not tags.is_empty() else ""
	var hit_text := (" (%d/%d타)" % [hit_index, hit_count]) if hit_count > 1 else ""
	var skill_text := ("「%s」" % skill.display_name) if skill != null else ""

	return "%s → %s %s %d 피해%s%s" \
		% [source.display_name, target.display_name, skill_text,
			final_damage(), hit_text, tag_text]


# 계산 내역 전문. 전투 로그 상세 패널이 띄운다.
func detail() -> String:
	return "%s\n  %s" % [summary(), "\n  ".join(log)]
