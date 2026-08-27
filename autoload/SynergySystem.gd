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
#   **효과를 적용하지는 않는다** — 적용은 Player 가 한다. Player 가 평타·피격 시점에
#   _is_role_active() / _is_role_tier3() 로 여기에 물어보고, 켜져 있을 때만 자기 효과를
#   실행한다. 판정과 적용을 나눠 두면 효과가 늘어도 이 파일은 그대로다.
#
# 지금 붙어 있는 효과 (전부 Player.gd, 위 두 조회로 게이트된다):
#   탱커     1단계  표식 부여 -> 기절            try_attack()
#   원거리   1단계  평타 스택(공속·이속)         _gain_stack() / _decay_stack()
#   버퍼     1단계  처형                          _try_execute()
#   탱커     3단계  반사 피해                     _reflect_damage()
#   탱커     3단계  기절 시 회복                  _on_stunned_enemy()
#   원거리   3단계  피흡 -> 초과분 보호막         _apply_lifesteal()
#   버퍼     3단계  제공한 힐/보호막 -> 추가 피해  _credit_support_provided()
#
# 효과 6종이 전부 붙었다(#369). 버퍼 3단계는 마지막까지 비어 있었는데, §8.1 이 그것을
# **캐릭터 고유 스킬의 힐/보호막**에 기대게 확정해 둔 반면 그때는 skills 가 0개였기 때문이다.
# 지금은 네 채널이 저작되어 있다: 미나 보호막 폭발, 설아 3타 응급처치·퍼지는 파동, 강지 수혈.
#
# 추가 피해가 **언제 어디로** 들어가는지는 §8.1 이 정하지 않아 #369 에서 정했다 —
# 보류에 쌓아 두고 그 멤버의 **다음 평타가 적중할 때** 얹는다. 근거는 Player.gd 의
# _buffer_pending_damage 주석에 있다.

# ===== 활성화 카운트 =====
# [확정] 시너지는 **정확히 1개** 또는 **3개**일 때만 활성화된다.
# 2카운트는 "죽은 구간"으로 아무 효과도 켜지지 않는다(임계치 방식이 아니다).
# 3카운트일 때 3단계는 1단계를 대체하지 않고 **추가 누적**된다.
const TIER1_COUNT: int = 1
const TIER3_COUNT: int = 3

# 활성화 단계.
enum Tier {
	NONE,      # 0 또는 2카운트 - 비활성
	TIER1,     # 정확히 1카운트 - 1단계만
	TIER1_3,   # 3카운트 - 1단계 + 3단계 (추가 누적)
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
# 주의: "이상(>=)"이 아니라 **정확히 1개 또는 3개**일 때만 활성화된다.
#       2카운트는 비활성이다(반쯤 모으면 아무것도 얻지 못한다).
# 3카운트 초과는 파티 3명 구조상 나올 수 없지만, 방어적으로 3단계로 취급한다.
#
# 이 함수는 카운트만 보는 저수준 헬퍼로, **배타 규칙(3단계 시 나머지 비활성)을 모른다.**
# 파티의 실제 활성 상태는 반드시 get_active_tiers()로 판단한다.
func get_tier_for_count(count: int) -> Tier:
	if count >= TIER3_COUNT:
		return Tier.TIER1_3
	if count == TIER1_COUNT:
		return Tier.TIER1
	return Tier.NONE

# 파티의 역할별 활성화 단계를 반환한다.
# 반환: CharacterData.Role -> Tier
#
# 배타 규칙: 어떤 역할이 3단계를 발동하면 **나머지 역할의 1단계는 켜지지 않는다.**
# 3단계 역할 자신은 1단계 + 3단계를 그대로 유지한다.
# 몰빵의 대가를 만들어 "하나를 깊게 vs 셋을 얕게"가 실제 선택이 되게 한다.
#
# 1단계가 곧 역할 메커니즘이므로(docs §2), 이 규칙은 단순한 버프 손실이 아니라
# 다른 역할의 메커니즘(스택·처형 등)이 파티에서 사라진다는 뜻이다.
func get_active_tiers(party: Array) -> Dictionary:
	var counts := get_role_counts(party)
	var tiers := {}
	for r in counts:
		tiers[r] = get_tier_for_count(counts[r])

	# 3단계를 발동한 역할을 찾는다.
	# 한 파티가 두 역할을 동시에 3카운트로 만들 수는 없으므로(docs §8.2 전수 검증)
	# 이 역할은 있어도 하나뿐이다.
	var tier3_role: int = -1
	for r in tiers:
		if tiers[r] == Tier.TIER1_3:
			tier3_role = r
			break

	if tier3_role == -1:
		return tiers

	# 3단계 역할만 남기고 나머지는 비활성으로 만든다.
	for r in tiers:
		if r != tier3_role:
			tiers[r] = Tier.NONE
	return tiers

# 특정 역할의 1단계가 켜졌는지.
# 3카운트면 1단계도 유지되므로 true, 2카운트면 false다.
# **다른 역할이 3단계를 발동했다면 배타 규칙에 따라 false다.**
# (카운트에서 직접 계산하지 않고 get_active_tiers()를 거쳐 배타 규칙을 반영한다.)
func is_tier1_active(party: Array, role: CharacterData.Role) -> bool:
	return get_active_tiers(party).get(role, Tier.NONE) != Tier.NONE

# 특정 역할의 3단계가 켜졌는지.
func is_tier3_active(party: Array, role: CharacterData.Role) -> bool:
	return get_active_tiers(party).get(role, Tier.NONE) == Tier.TIER1_3

# ===== 조회 편의 (UI/디버그) =====

# UI 표시용 요약. 역할별 카운트·단계·표시 이름을 한 번에 준다.
# 반환: [{ "role": Role, "name": String, "count": int, "tier": Tier, "tier_name": String }, ...]
func get_summary(party: Array) -> Array:
	var counts := get_role_counts(party)
	# 배타 규칙이 반영된 결과를 쓴다(카운트에서 직접 계산하지 않는다).
	var tiers := get_active_tiers(party)
	var result: Array = []
	for r in counts:
		var count: int = counts[r]
		var tier: Tier = tiers.get(r, Tier.NONE)
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
			return "비활성"   # 0카운트 또는 2카운트
		Tier.TIER1:
			return "1단계"
		Tier.TIER1_3:
			return "1단계+3단계"
		_:
			return "알 수 없음"
