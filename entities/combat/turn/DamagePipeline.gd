extends RefCounted
class_name DamagePipeline

# 데미지 파이프라인 — **시너지 설계의 전부**가 여기 있다 (#450).
#
#   최종 데미지 =
#       기본 데미지
#     x (1 + Σ 피해증가)          [버킷 A]
#     x (1 - 방어계수)             [버킷 B]
#     x (1 - 원소저항 + 저항관통)  [버킷 C]
#     x (1 + Σ 받는피해증가)       [버킷 D]
#     x 치명타 배율                [버킷 E]
#     x (1 + 격파보너스)           [버킷 F]
#     x 열기 보정                  [버킷 G]
#     x 랜덤 (0.97 ~ 1.03)
#
# **왜 버킷을 쪼개는가**: 같은 버킷에 +50%를 3개 몰면 x2.5, 서로 다른 버킷에 나누면
# x3.375다. 35% 차이. 이것이 "왜 저 캐릭 셋을 같이 쓰면 시너지가 폭발하는가"의 수학적
# 정체이며, 버프를 4~6개 버킷으로 쪼개 각 버킷을 다른 역할군이 담당하게 하면 플레이어가
# 자연스럽게 "역할이 겹치지 않는 4명"을 조합한다.
#
# 이 클래스는 **노드가 아니고 연출을 모른다.** 계산만 즉시 끝내고, 연출은 결과를
# `PresentationQueue`에 쌓아 나중에 재생한다 -> 배속 기능이 공짜로 구현된다.
#
# 참고: docs/turn-combat-design.md §데미지

## 결정론적 RNG. 시드 기반이어야 리플레이·재현·버그 재현이 된다(설계서 §5.2.4).
var rng: RandomNumberGenerator = null

## 열기 보정을 읽기 위한 자원 시스템. null이면 열기 보정 없이 계산한다.
var resources: TurnResourceSystem = null


func _init(random: RandomNumberGenerator = null, resource_system: TurnResourceSystem = null) -> void:
	rng = random if random != null else RandomNumberGenerator.new()
	resources = resource_system


func _tuning() -> TurnCombatTuning:
	return PlayerStats.get_tuning_turn()


# ===== 전체 실행 (Resolve) =====

# 1~9 단계를 실행해 피해 수치를 확정한다. HP 반영은 하지 않는다.
#
# 계산과 반영을 나눈 이유: 예상 피해(적 행동 예고)는 **계산만** 필요하고, 실제 타격은
# 둘 다 필요하다. 한 함수로 뭉치면 예상 피해를 뽑을 때마다 대상의 HP가 깎인다.
func compute(ctx: DamageContext) -> DamageContext:
	_collect_buckets(ctx)
	_step_base(ctx)
	_step_damage_bonus(ctx)
	_step_defense(ctx)
	_step_resistance(ctx)
	_step_vulnerability(ctx)
	_step_crit(ctx)
	_step_break_bonus(ctx)
	_step_heat(ctx)
	_step_variance(ctx)
	_step_toughness(ctx)
	return ctx


# 10~11 단계. 보호막 흡수 후 HP에 반영한다.
func commit(ctx: DamageContext) -> DamageContext:
	_step_shields(ctx)
	_step_apply(ctx)
	return ctx


func resolve(ctx: DamageContext) -> DamageContext:
	compute(ctx)
	commit(ctx)
	return ctx


# ===== 0단계: 버킷 수집 (Collect) =====
#
# 스텟과 상태 효과에서 각 버킷의 합산값을 모은다. **버킷 안은 가산**이므로 여기서 더한다.
func _collect_buckets(ctx: DamageContext) -> void:
	var t := _tuning()

	# 버킷 A — 피해증가% / 원소 피해 (공격자)
	ctx.add_bucket(TurnCombat.Bucket.DMG_BONUS, ctx.source.stats.get_damage_bonus())

	# 버킷 B — 방어력 감소 (대상에게 걸린 디버프 + 격파 상태)
	ctx.add_bucket(TurnCombat.Bucket.DEFENSE, ctx.target.stats.get_defense_reduction())
	if ctx.target.is_broken:
		ctx.add_bucket(TurnCombat.Bucket.DEFENSE, t.broken_defense_reduction)

	# 버킷 C — 저항 관통 (공격자)
	ctx.add_bucket(TurnCombat.Bucket.RESISTANCE, ctx.source.stats.get_res_penetration())

	# 버킷 D — 받는 피해 증가 (대상)
	ctx.add_bucket(TurnCombat.Bucket.VULNERABILITY, ctx.target.stats.get_vulnerability())
	if ctx.target.is_broken:
		ctx.add_bucket(TurnCombat.Bucket.VULNERABILITY, t.broken_vulnerability)
	elif ctx.target.max_toughness > 0 and ctx.target.toughness > 0:
		# 인성치가 남아 있는 적은 받는 피해가 감소한다 -> **격파 자체가 곧 딜 증폭**이다.
		ctx.add_bucket(TurnCombat.Bucket.VULNERABILITY, -t.unbroken_damage_reduction)

	# 대상이 아군이면 열기의 받는 피해 보정을 함께 넣는다(과열이면 더 아프다).
	if resources != null and ctx.target.is_ally():
		ctx.add_bucket(TurnCombat.Bucket.VULNERABILITY,
			resources.heat_damage_taken_modifier())

	# 버킷 F — 격파 특화. **격파/초격파 피해에만** 걸린다.
	if ctx.is_break_damage or ctx.is_overbreak:
		ctx.add_bucket(TurnCombat.Bucket.BREAK_BONUS, ctx.source.stats.get_break_effect())

	# 배턴 중첩 — 양도받은 쪽의 공격력이 오른다(누적 최대 3회 = +60%).
	# 버킷 A에 넣는다: 페르소나 5의 배턴 터치를 곱연산 구조에 얹은 자리다.
	if ctx.source.baton_stacks > 0:
		ctx.add_bucket(TurnCombat.Bucket.DMG_BONUS, 0.2 * float(ctx.source.baton_stacks))


# ===== 1단계: 기본 데미지 =====
#
#   기본 데미지 = 스킬 배율% x 기준 능력치 + 고정 추가값
func _step_base(ctx: DamageContext) -> void:
	var multiplier := 0.0
	var flat := 0
	var scaling := TurnCombat.Scaling.ATTACK

	if ctx.effect != null:
		multiplier = ctx.effect.multiplier
		flat = ctx.effect.flat
		scaling = ctx.effect.scaling

	var stat_value := ctx.source.get_scaling_value(scaling)
	ctx.base_damage = (multiplier * float(stat_value) + float(flat)) * ctx.target_ratio
	ctx.damage = ctx.base_damage

	ctx.note("1. 기본 %.0f  (배율 %.0f%% x %s %d + 고정 %d, 대상비율 %.2f)"
		% [ctx.base_damage, multiplier * 100.0, _scaling_name(scaling), stat_value,
			flat, ctx.target_ratio])


# ===== 2단계: 버킷 A — 피해증가 =====
func _step_damage_bonus(ctx: DamageContext) -> void:
	var bonus := ctx.get_bucket(TurnCombat.Bucket.DMG_BONUS)
	var factor := maxf(1.0 + bonus, 0.0)
	ctx.damage *= factor
	ctx.note("2. 버킷A 피해증가 x%.3f  (+%.1f%%)" % [factor, bonus * 100.0])


# ===== 3단계: 버킷 B — 방어 계수 =====
#
#   방어계수 = DEF / (DEF + 150 + 8 x 공격자레벨)
#
# 방어력 감소 X%는 이 곡선상에서 **곱연산에 가까운 큰 이득**을 준다. 그래서 방어 감소
# 디버퍼는 항상 1티어 서포터가 된다 — 의도된 설계다.
func _step_defense(ctx: DamageContext) -> void:
	var t := _tuning()
	var reduction := clampf(ctx.get_bucket(TurnCombat.Bucket.DEFENSE), 0.0, 1.0)
	var effective_def := maxf(float(ctx.target.get_defense()) * (1.0 - reduction), 0.0)
	var denominator := effective_def + t.defense_constant \
		+ t.defense_level_coefficient * float(ctx.source.level)

	ctx.defense_coefficient = 0.0 if denominator <= 0.0 else effective_def / denominator
	var factor := 1.0 - ctx.defense_coefficient
	ctx.damage *= factor

	ctx.note("3. 버킷B 방어 x%.3f  (방어력 %d -> %.0f, 감소 %.1f%%, 계수 %.3f)"
		% [factor, ctx.target.get_defense(), effective_def, reduction * 100.0,
			ctx.defense_coefficient])


# ===== 4단계: 버킷 C — 원소 저항 / 저항 관통 =====
func _step_resistance(ctx: DamageContext) -> void:
	var resistance := ctx.target.get_element_resistance(ctx.element)
	var penetration := ctx.get_bucket(TurnCombat.Bucket.RESISTANCE)
	# 저항을 100% 이상 뚫어도 피해가 늘어나지는 않는다(상한 1.0).
	var factor := clampf(1.0 - resistance + penetration, 0.0, 1.0)
	ctx.damage *= factor
	ctx.note("4. 버킷C 저항 x%.3f  (%s 저항 %.1f%%, 관통 %.1f%%)"
		% [factor, TurnCombat.element_name(ctx.element), resistance * 100.0,
			penetration * 100.0])


# ===== 5단계: 버킷 D — 받는 피해 증가 =====
func _step_vulnerability(ctx: DamageContext) -> void:
	var vulnerability := ctx.get_bucket(TurnCombat.Bucket.VULNERABILITY)
	var factor := maxf(1.0 + vulnerability, 0.0)
	ctx.damage *= factor
	ctx.note("5. 버킷D 받는피해 x%.3f  (%+.1f%%)" % [factor, vulnerability * 100.0])


# ===== 6단계: 버킷 E — 치명타 =====
#
# **지속 피해와 추가 피해는 치명타가 나지 않는다.** 그래서 DoT 팀은 치명타 축을 통째로
# 버리고 장비 요구사항이 완전히 달라진다 — 의도된 안티테제 설계다.
#
# 치명타 확률이 100%를 넘으면 초과분의 절반이 치명타 피해로 전환된다(설계서 §4.13).
func _step_crit(ctx: DamageContext) -> void:
	if ctx.is_dot or ctx.is_additional or ctx.is_break_damage:
		ctx.crit_multiplier = 1.0
		ctx.note("6. 버킷E 치명타 x1.000  (치명타 불가: %s)"
			% ["지속 피해" if ctx.is_dot else ("추가 피해" if ctx.is_additional else "격파 피해")])
		return

	var t := _tuning()
	var rate := ctx.source.stats.get_crit_rate()
	var crit_damage := ctx.source.stats.get_crit_damage()

	if rate > t.crit_rate_cap:
		var overflow := rate - t.crit_rate_cap
		crit_damage += overflow * t.crit_overflow_to_damage
		rate = t.crit_rate_cap

	if ctx.preview_mode:
		# 예상 피해에는 **기대값**을 쓴다. 굴려서 보여 주면 같은 예고가 매번 달라 보인다.
		ctx.is_crit = false
		ctx.crit_multiplier = 1.0 + rate * crit_damage
		ctx.damage *= ctx.crit_multiplier
		ctx.note("6. 버킷E 치명타 x%.3f  (기대값: 확률 %.1f%% x 피해 %.1f%%)"
			% [ctx.crit_multiplier, rate * 100.0, crit_damage * 100.0])
		return

	ctx.is_crit = rng.randf() < rate
	ctx.crit_multiplier = (1.0 + crit_damage) if ctx.is_crit else 1.0
	ctx.damage *= ctx.crit_multiplier
	ctx.note("6. 버킷E 치명타 x%.3f  (확률 %.1f%%, %s)"
		% [ctx.crit_multiplier, rate * 100.0, "발생" if ctx.is_crit else "미발생"])


# ===== 7단계: 버킷 F — 격파 보너스 =====
func _step_break_bonus(ctx: DamageContext) -> void:
	var bonus := ctx.get_bucket(TurnCombat.Bucket.BREAK_BONUS)
	var factor := maxf(1.0 + bonus, 0.0)
	ctx.damage *= factor
	ctx.note("7. 버킷F 격파보너스 x%.3f  (+%.1f%%)" % [factor, bonus * 100.0])


# ===== 8단계: 버킷 G — 열기 보정 =====
func _step_heat(ctx: DamageContext) -> void:
	if resources == null or not ctx.source.is_ally():
		ctx.note("8. 버킷G 열기 x1.000  (해당 없음)")
		return

	var modifier := resources.heat_damage_modifier()
	var factor := maxf(1.0 + modifier, 0.0)
	ctx.damage *= factor
	ctx.note("8. 버킷G 열기 x%.3f  (%s 구간, %+.1f%%)"
		% [factor, resources.heat_zone_name(), modifier * 100.0])


# ===== 9단계: 랜덤 변동 =====
#
# ±3%로 **좁게** 유지한다. 다키스트 던전식 큰 랜덤은 배제한다 —
# "계산 가능한 게임"이 설계 3원칙의 첫 줄이다.
func _step_variance(ctx: DamageContext) -> void:
	if ctx.preview_mode:
		ctx.note("9. 변동 x1.000  (예상 피해는 변동 없이 표시)")
		return

	var spread := _tuning().damage_variance
	if spread <= 0.0:
		ctx.note("9. 변동 x1.000")
		return

	var factor := 1.0 + rng.randf_range(-spread, spread)
	ctx.damage *= factor
	ctx.note("9. 변동 x%.3f  (±%.0f%%)" % [factor, spread * 100.0])


# ===== 인성치 피해 산정 =====
#
# **약점 속성 공격만 인성치를 깎는다.** 비약점 공격은 HP만 깎는다.
# 지속 피해·추가 피해는 인성치를 깎지 않는다.
func _step_toughness(ctx: DamageContext) -> void:
	if ctx.effect == null or not ctx.effect.deals_toughness():
		ctx.toughness_damage = 0
		return
	if ctx.is_dot or ctx.is_additional or ctx.is_break_damage:
		ctx.toughness_damage = 0
		return
	if ctx.target.max_toughness <= 0:
		ctx.toughness_damage = 0
		return

	ctx.hits_weakness = ctx.target.is_weak_to(ctx.element, ctx.physical_type)
	if not ctx.hits_weakness:
		ctx.toughness_damage = 0
		ctx.note("인성치 0  (약점이 아님: %s / %s)"
			% [TurnCombat.element_name(ctx.element),
				TurnCombat.physical_name(ctx.physical_type)])
		return

	var raw := float(ctx.effect.toughness_damage) * ctx.target_ratio
	raw *= TurnCombat.physical_toughness_multiplier(ctx.physical_type)
	raw *= ctx.source.stats.get_toughness_damage_multiplier()
	ctx.toughness_damage = maxi(int(round(raw)), 1)

	ctx.note("인성치 -%d  (기본 %d x 물리 %.2f x 배율 %.2f)"
		% [ctx.toughness_damage, ctx.effect.toughness_damage,
			TurnCombat.physical_toughness_multiplier(ctx.physical_type),
			ctx.source.stats.get_toughness_damage_multiplier()])


# ===== 10단계: 보호막 흡수 =====
func _step_shields(ctx: DamageContext) -> void:
	var total := maxi(int(round(ctx.damage)), _tuning().damage_min)
	var remaining := total
	ctx.shield_absorbed = 0

	for status in ctx.target.statuses:
		if remaining <= 0:
			break
		if status.kind != TurnStatus.Kind.SHIELD or status.shield_amount <= 0:
			continue
		var absorbed := mini(status.shield_amount, remaining)
		status.shield_amount -= absorbed
		remaining -= absorbed
		ctx.shield_absorbed += absorbed

	# 다 쓴 보호막은 만료시킨다. 0짜리 보호막 아이콘이 남으면 화면이 거짓말을 한다.
	ctx.target.statuses = ctx.target.statuses.filter(
		func(s: TurnStatus) -> bool:
			return not (s.kind == TurnStatus.Kind.SHIELD and s.shield_amount <= 0))

	ctx.hp_damage = remaining
	if ctx.shield_absorbed > 0:
		ctx.note("10. 보호막 흡수 %d, HP 피해 %d" % [ctx.shield_absorbed, ctx.hp_damage])
	else:
		ctx.note("10. 보호막 없음, HP 피해 %d" % ctx.hp_damage)


# ===== 11단계: HP 반영 =====
func _step_apply(ctx: DamageContext) -> void:
	if ctx.hp_damage <= 0:
		ctx.note("11. HP 변화 없음 (%d/%d)"
			% [ctx.target.current_hp, ctx.target.get_max_hp()])
		return

	ctx.target.current_hp = maxi(ctx.target.current_hp - ctx.hp_damage, 0)
	if ctx.target.current_hp <= 0:
		ctx.target.alive = false
		ctx.killed = true

	ctx.note("11. HP %d/%d%s"
		% [ctx.target.current_hp, ctx.target.get_max_hp(),
			"  전투 불능" if ctx.killed else ""])


# ===== 격파 데미지 (Break damage) =====
#
#   격파 데미지 = 기준값 x 원소배율 x (0.5 + 최대인성치/40) x (1 + 격파특화)
#                 x 방어계수 x 저항계수 x 받는피해 계수
#
# 여기서 절묘한 밸런싱이 보인다: **격파 데미지가 낮은 원소(침식·광휘)는 상태이상이
# 강력하다.** 데미지와 유틸리티를 트레이드오프시킨 것이다.
func build_break_context(source: TurnUnit, target: TurnUnit, element: int) -> DamageContext:
	var t := _tuning()
	var ctx := DamageContext.new()
	ctx.source = source
	ctx.target = target
	ctx.element = element
	ctx.physical_type = source.physical_type
	ctx.is_break_damage = true

	var base := break_base_value(source.level)
	var element_multiplier := TurnCombat.element_break_multiplier(element)
	var toughness_multiplier := t.break_toughness_offset \
		+ float(target.max_toughness) / t.break_toughness_divisor

	# 격파 데미지는 스킬 배율이 아니라 자기 공식으로 기본값을 만든다. 그래서 효과를
	# 만들어 넣지 않고 고정값으로 채운다(파이프라인의 나머지 단계는 그대로 태운다).
	var effect := TurnSkillEffect.new()
	effect.kind = TurnSkillEffect.Kind.DAMAGE
	effect.multiplier = 0.0
	effect.flat = int(round(base * element_multiplier * toughness_multiplier))
	effect.toughness_damage = 0
	ctx.effect = effect

	ctx.note("격파 기준값 %.0f x 원소 %.1f x 인성치 %.2f = %d"
		% [base, element_multiplier, toughness_multiplier, effect.flat])

	return ctx


# 레벨별 격파 데미지 기준값.
#
# 설계서 §4.15 표(Lv20:480, Lv40:1750, Lv60:4200, Lv80:8600)를 지수 곡선으로 근사한다.
# 표를 그대로 박아 두면 표에 없는 레벨에서 값이 튄다.
func break_base_value(level: int) -> float:
	var t := _tuning()
	return t.break_base_at_1 * pow(float(maxi(level, 1)), t.break_base_exponent)


# ===== 초격파 (Overbreak) =====
#
# 이미 격파된 적에게 추가로 넣은 인성치 피해가 **별도의 데미지로 전환**된다.
# "격파 특화" 스탯 하나만으로 굴러가는 완전히 새로운 딜링 축이다.
#
# 출시 시점엔 비주류로 두었다가 나중에 전용 서포터/장비를 추가해 **파워 인플레 없는
# 메타 전환 카드**로 쓰는 것이 설계 의도다(설계서 §4.4.4).
func build_overbreak_context(source: TurnUnit, target: TurnUnit, element: int,
		toughness_damage: int) -> DamageContext:
	var ctx := DamageContext.new()
	ctx.source = source
	ctx.target = target
	ctx.element = element
	ctx.physical_type = source.physical_type
	ctx.is_overbreak = true

	var effect := TurnSkillEffect.new()
	effect.kind = TurnSkillEffect.Kind.DAMAGE
	effect.multiplier = 0.0
	effect.flat = int(round(float(toughness_damage) * _tuning().overbreak_conversion))
	ctx.effect = effect

	ctx.note("초격파 전환: 인성치 %d x %.1f = %d"
		% [toughness_damage, _tuning().overbreak_conversion, effect.flat])

	return ctx


func _scaling_name(scaling: int) -> String:
	match scaling:
		TurnCombat.Scaling.DEFENSE:
			return "방어력"
		TurnCombat.Scaling.MAX_HP:
			return "최대HP"
		TurnCombat.Scaling.MAGIC:
			return "마법공격력"
		_:
			return "공격력"
