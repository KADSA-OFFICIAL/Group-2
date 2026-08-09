extends Node

# 시너지 시스템 (autoload).
# 책임: 파티 구성에서 **역할군 카운트**를 세고, **활성화 단계**를 판정한다.
#
# 단일 출처 원칙:
#   - 역할 정보는 CharacterData.get_roles()가 유일한 출처다. 여기서 역할을 재정의하지 않는다.
#   - 겸직 캐릭터는 자신이 가진 두 역할 카운트에 각각 +1 기여한다(get_roles()가 2개를 반환).
#
# 범위 (docs/combat-screen-design.md §8):
#   이 시스템은 "몇 카운트인지 / 몇 단계가 켜졌는지"까지만 판정한다.
#   **시너지의 구체 효과는 아직 [미정]**이므로 효과 적용은 하지 않는다.
#   효과가 정해지면 후속 이슈에서 StatusEffectData/PlayerStats 버프 채널로 연결한다.

# ===== 활성화 임계치 =====
# [확정] 1카운트에서 1단계, 3카운트에서 3단계가 켜진다.
# 3단계는 1단계를 대체하지 않고 **추가 누적**된다.
const TIER1_THRESHOLD: int = 1
const TIER3_THRESHOLD: int = 3

# 활성화 단계. 비트 조합이 아니라 "켜진 단계 목록"으로 다룬다.
enum Tier {
	NONE,      # 0카운트 - 비활성
	TIER1,     # 1~2카운트 - 1단계만
	TIER1_3,   # 3카운트 이상 - 1단계 + 3단계 (추가 누적)
}

func _ready() -> void:
	name = "SynergySystem"

# ===== 카운트 (Role Counts) =====

# 파티(CharacterData 배열)의 역할군 카운트를 센다.
# 반환: CharacterData.Role -> 카운트(int). 0인 역할도 키로 포함한다(UI가 0을 표시할 수 있도록).
# 겸직자는 get_roles()가 2개를 반환하므로 두 역할에 각각 +1 된다.
func get_role_counts(party: Array) -> Dictionary:
	var counts := {
		CharacterData.Role.TANK: 0,
		CharacterData.Role.RANGED_DEALER: 0,
		CharacterData.Role.BUFFER: 0,
	}
	for member in party:
		if member == null:
			continue
		if not (member is CharacterData):
			push_warning("SynergySystem: CharacterData가 아닌 파티원(건너뜀): " + str(member))
			continue
		for r in member.get_roles():
			if counts.has(r):
				counts[r] += 1
	return counts

# ===== 활성화 판정 (Activation) =====

# 카운트 하나를 활성화 단계로 변환한다.
func get_tier_for_count(count: int) -> Tier:
	if count >= TIER3_THRESHOLD:
		return Tier.TIER1_3
	if count >= TIER1_THRESHOLD:
		return Tier.TIER1
	return Tier.NONE

# 파티의 역할별 활성화 단계를 반환한다.
# 반환: CharacterData.Role -> Tier
func get_active_tiers(party: Array) -> Dictionary:
	var counts := get_role_counts(party)
	var tiers := {}
	for r in counts:
		tiers[r] = get_tier_for_count(counts[r])
	return tiers

# 특정 역할의 1단계가 켜졌는지 (3카운트여도 1단계는 유지되므로 true).
func is_tier1_active(party: Array, role: CharacterData.Role) -> bool:
	return get_tier_for_count(get_role_counts(party).get(role, 0)) != Tier.NONE

# 특정 역할의 3단계가 켜졌는지.
func is_tier3_active(party: Array, role: CharacterData.Role) -> bool:
	return get_tier_for_count(get_role_counts(party).get(role, 0)) == Tier.TIER1_3

# ===== 조회 편의 (UI/디버그) =====

# UI 표시용 요약. 역할별 카운트·단계·표시 이름을 한 번에 준다.
# 반환: [{ "role": Role, "name": String, "count": int, "tier": Tier, "tier_name": String }, ...]
func get_summary(party: Array) -> Array:
	var counts := get_role_counts(party)
	var result: Array = []
	for r in counts:
		var count: int = counts[r]
		var tier := get_tier_for_count(count)
		result.append({
			"role": r,
			"name": CharacterData.role_to_name(r),
			"count": count,
			"tier": tier,
			"tier_name": tier_to_name(tier),
		})
	return result

# 단계의 화면 표시용 이름.
func tier_to_name(tier: Tier) -> String:
	match tier:
		Tier.NONE:
			return "비활성"
		Tier.TIER1:
			return "1단계"
		Tier.TIER1_3:
			return "1단계+3단계"
		_:
			return "알 수 없음"
