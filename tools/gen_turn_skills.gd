extends SceneTree

## 턴제 스킬 `.tres` 를 저작한다 (#450).
##
## 왜 생성기인가: 스킬 하나가 `SkillData` + 효과 `TurnSkillEffect` 여러 개로 이루어져
## 있어서, 6인 x 4~5스킬 + 적 공용 7스킬을 손으로 쓰면 `ext_resource` id 를 30번 이상
## 맞춰야 한다. 한 글자 틀리면 리소스가 조용히 null 로 로드된다.
##
## **생성된 `.tres` 는 커밋되며, 이후 밸런싱은 Godot 인스펙터에서 한다.** 이 스크립트는
## 초기 저작을 만드는 도구이고 런타임에 쓰이지 않는다. 다시 돌리면 파일을 덮어쓰므로
## 인스펙터로 조정한 값이 사라진다 — 그때는 이 파일의 수치도 함께 고친다.
##
## 수치의 출처: 설계서 §4.14(샘플 캐릭터 3종) · §4.15(밸런스 기준선). 전부 **[임시값]**이다.
##
## 사용법:
##   godot --headless --path . --script res://tools/gen_turn_skills.gd

const OUT_DIR := "res://data/skills/turn"
const ENEMY_DIR := "res://data/skills/turn/enemy"



func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ENEMY_DIR))

	var written := 0
	written += _gen_mina()
	written += _gen_harang()
	written += _gen_arin()
	written += _gen_taehee()
	written += _gen_seola()
	written += _gen_gangji()
	written += _gen_enemy()

	print("gen_turn_skills: %d개 저작 완료" % written)
	quit(0)


# ===== 저작 헬퍼 (Authoring helpers) =====

func _skill(id: String, name: String, action: int, summary_text: String) -> SkillData:
	var skill := SkillData.new()
	skill.skill_id = StringName(id)
	skill.display_name = name
	skill.turn_action = action
	skill.summary = summary_text
	return skill


func _damage(multiplier: float, toughness: int, scaling: int = TurnCombat.Scaling.ATTACK,
		scope: int = TurnSkillEffect.Scope.TARGET) -> TurnSkillEffect:
	var effect := TurnSkillEffect.new()
	effect.kind = TurnSkillEffect.Kind.DAMAGE
	effect.scope = scope
	effect.multiplier = multiplier
	effect.scaling = scaling
	effect.toughness_damage = toughness
	return effect


func _effect(kind: int, scope: int) -> TurnSkillEffect:
	var effect := TurnSkillEffect.new()
	effect.kind = kind
	effect.scope = scope
	return effect


func _save(skill: SkillData, dir: String = OUT_DIR) -> int:
	var problems := skill.validate_turn()
	if not problems.is_empty():
		push_error("gen_turn_skills: %s 저작 오류 — %s"
			% [skill.skill_id, ", ".join(problems)])
		return 0

	var path := "%s/%s.tres" % [dir, String(skill.skill_id)]
	var err := ResourceSaver.save(skill, path)
	if err != OK:
		push_error("gen_turn_skills: 저장 실패 (%d) %s" % [err, path])
		return 0
	print("  " + path)
	return 1


# =====================================================================
# 미나 — 수호자 / 화염 / 강타 (설계서 §4.14 ① 「재의 파수꾼」)
# =====================================================================
#
# 위치 지배 + 카운터 팀의 축. 밀치기로 적 근접 딜러를 후열로 보내 무력화시키고,
# 도발 + 반격으로 딜과 방어를 동시에 한다. 공명 소비가 적어 하이퍼캐리 팀의
# 생존 슬롯으로도 쓸 수 있다.
func _gen_mina() -> int:
	var count := 0

	var basic := _skill("mina_turn_basic", "진압", TurnCombat.ActionKind.BASIC,
		"단일 대상에 방어력 80% 화염 피해. 인성치 -15. 적을 뒤로 1칸 밀친다.")
	basic.usable_ranks = [1, 2]
	basic.target_ranks = [1, 2]
	basic.turn_targeting = TurnCombat.Targeting.SINGLE
	var push := _effect(TurnSkillEffect.Kind.PUSH, TurnSkillEffect.Scope.TARGET)
	push.distance = 1
	basic.turn_effects = [_damage(0.80, 15, TurnCombat.Scaling.DEFENSE), push]
	count += _save(basic)

	var skill := _skill("mina_turn_skill", "제련의 방벽", TurnCombat.ActionKind.SKILL,
		"아군 전체에 방어력 15% + 200의 보호막을 2턴 부여한다. 자신은 3턴간 도발.")
	skill.rp_cost = 1
	skill.turn_targeting = TurnCombat.Targeting.ALLY_ALL
	var shield := _effect(TurnSkillEffect.Kind.SHIELD, TurnSkillEffect.Scope.ALL_ALLIES)
	shield.multiplier = 0.15
	shield.scaling = TurnCombat.Scaling.DEFENSE
	shield.flat = 200
	shield.duration = 2
	var taunt := _effect(TurnSkillEffect.Kind.TAUNT, TurnSkillEffect.Scope.SELF)
	taunt.duration = 3
	skill.turn_effects = [shield, taunt]
	count += _save(skill)

	var ult := _skill("mina_turn_ult", "종언의 화로", TurnCombat.ActionKind.ULTIMATE,
		"적 전체에 방어력 180% 화염 피해. 인성치 -40. 적 전체를 뒤로 1칸 밀친다. "
		+ "이후 2턴간 아군 전체가 받는 피해 -18%.")
	ult.energy_cost = 120
	ult.turn_targeting = TurnCombat.Targeting.ALL_ENEMIES
	var ult_push := _effect(TurnSkillEffect.Kind.PUSH, TurnSkillEffect.Scope.ALL_ENEMIES)
	ult_push.distance = 1
	var ward := _effect(TurnSkillEffect.Kind.BUFF, TurnSkillEffect.Scope.ALL_ALLIES)
	ward.stat_key = &"vulnerability"
	ward.value = -0.18
	ward.duration = 2
	ward.bucket = TurnCombat.Bucket.VULNERABILITY
	ward.label = "받는 피해 -18%"
	ult.turn_effects = [_damage(1.80, 40, TurnCombat.Scaling.DEFENSE), ult_push, ward]
	count += _save(ult)

	var trait_skill := _skill("mina_turn_trait", "반격의 잔불", TurnCombat.ActionKind.TRAIT,
		"도발 상태에서 피격 시 공격자에게 방어력 60% 화염 피해로 반격 (턴당 최대 2회). 인성치 -10.")
	trait_skill.trait_trigger = SkillData.TraitTrigger.ON_DAMAGE_TAKEN
	trait_skill.trait_per_turn_cap = 2
	trait_skill.trait_require_self_status = true
	trait_skill.trait_self_status_kind = TurnStatus.Kind.TAUNT
	trait_skill.turn_targeting = TurnCombat.Targeting.SINGLE
	trait_skill.turn_effects = [_damage(0.60, 10, TurnCombat.Scaling.DEFENSE)]
	count += _save(trait_skill)

	return count


# =====================================================================
# 하랑 — 파괴자 / 충격 / 참격
# =====================================================================
#
# 파괴자 계약: **광역 또는 확산 공격 + 자기 유지 수단.** 확산으로 인성치를 여러 마리에
# 나눠 깎고, 피해의 일부를 자기 회복으로 돌려 생존 슬롯의 부담을 줄인다.
func _gen_harang() -> int:
	var count := 0

	var basic := _skill("harang_turn_basic", "베어내기", TurnCombat.ActionKind.BASIC,
		"단일 대상에 공격력 100% 충격 피해. 인성치 -18.")
	basic.usable_ranks = [1, 2, 3]
	basic.target_ranks = [1, 2]
	basic.turn_targeting = TurnCombat.Targeting.SINGLE
	basic.turn_effects = [_damage(1.00, 18)]
	count += _save(basic)

	var skill := _skill("harang_turn_skill", "분쇄의 호", TurnCombat.ActionKind.SKILL,
		"대상 + 좌우 인접에 공격력 160% / 80% 충격 피해. 인성치 -30 / -15. "
		+ "넣은 피해의 일부만큼 자신을 회복한다.")
	skill.rp_cost = 1
	skill.usable_ranks = [1, 2]
	skill.target_ranks = [1, 2, 3]
	skill.turn_targeting = TurnCombat.Targeting.BLAST
	var self_heal := _effect(TurnSkillEffect.Kind.HEAL, TurnSkillEffect.Scope.SELF)
	self_heal.multiplier = 0.15
	self_heal.scaling = TurnCombat.Scaling.ATTACK
	self_heal.label = "자기 회복 (공격력 15%)"
	skill.turn_effects = [_damage(1.60, 30), self_heal]
	count += _save(skill)

	var ult := _skill("harang_turn_ult", "해일의 일격", TurnCombat.ActionKind.ULTIMATE,
		"적 전체에 공격력 260% 충격 피해. 인성치 -35. 자신을 크게 회복한다.")
	ult.energy_cost = 120
	ult.turn_targeting = TurnCombat.Targeting.ALL_ENEMIES
	var big_heal := _effect(TurnSkillEffect.Kind.HEAL, TurnSkillEffect.Scope.SELF)
	big_heal.multiplier = 0.30
	big_heal.scaling = TurnCombat.Scaling.ATTACK
	big_heal.label = "자기 회복 (공격력 30%)"
	ult.turn_effects = [_damage(2.60, 35), big_heal]
	count += _save(ult)

	var trait_skill := _skill("harang_turn_trait", "파단의 여열", TurnCombat.ActionKind.TRAIT,
		"약점을 찌를 때마다 자신의 오의 게이지 +8. (턴당 최대 2회)")
	trait_skill.trait_trigger = SkillData.TraitTrigger.ON_WEAKNESS_HIT
	trait_skill.trait_per_turn_cap = 2
	var energy := _effect(TurnSkillEffect.Kind.ENERGY, TurnSkillEffect.Scope.SELF)
	energy.amount = 8
	trait_skill.turn_effects = [energy]
	count += _save(trait_skill)

	return count


# =====================================================================
# 아린 — 추격자 / 전격 / 관통
# =====================================================================
#
# 추격자 계약: **단일 대상 배율 300% 이상 스킬.** 오의 420%가 그것이다.
# 관통 타입이라 인성치 배율이 x0.85로 낮은 대신 **다단 히트로 자물쇠를 여러 개 연다** —
# 이것이 관통의 존재 이유다.
#
# 그리고 이 로스터에서 **배턴 축**을 담당한다. 추가 턴을 아군에게 넘기면 넘겨받은 쪽이
# 강해지는 릴레이(페르소나 5 응용)가 「표적 인계」다.
func _gen_arin() -> int:
	var count := 0

	var basic := _skill("arin_turn_basic", "관통 사격", TurnCombat.ActionKind.BASIC,
		"단일 대상에 공격력 100% 전격 피해. 인성치 -20. 관통이라 후열도 노린다.")
	basic.usable_ranks = [2, 3, 4]
	basic.turn_targeting = TurnCombat.Targeting.SINGLE
	basic.turn_effects = [_damage(1.00, 20)]
	count += _save(basic)

	var skill := _skill("arin_turn_skill", "사냥의 표식", TurnCombat.ActionKind.SKILL,
		"단일 대상에 공격력 120% 전격 피해를 2회. 인성치 -18 x 2회. "
		+ "히트당 자물쇠 1개를 열 수 있다.")
	skill.rp_cost = 1
	skill.usable_ranks = [2, 3, 4]
	skill.turn_targeting = TurnCombat.Targeting.SINGLE
	skill.turn_hits = 2
	skill.turn_effects = [_damage(1.20, 18)]
	count += _save(skill)

	var pass_skill := _skill("arin_turn_baton", "표적 인계", TurnCombat.ActionKind.SKILL,
		"아군 1명에게 배턴을 넘긴다. 그 아군은 즉시 추가 턴을 얻고 "
		+ "배턴 중첩당 피해가 20% 증가한다 (최대 3중첩 = +60%). 오의 게이지 +20.")
	pass_skill.rp_cost = 1
	pass_skill.turn_targeting = TurnCombat.Targeting.ALLY_SINGLE
	var baton := _effect(TurnSkillEffect.Kind.BATON, TurnSkillEffect.Scope.TARGET)
	baton.label = "배턴 양도"
	var charge := _effect(TurnSkillEffect.Kind.ENERGY, TurnSkillEffect.Scope.TARGET)
	charge.amount = 20
	pass_skill.turn_effects = [baton, charge]
	count += _save(pass_skill)

	var ult := _skill("arin_turn_ult", "낙뢰 처형", TurnCombat.ActionKind.ULTIMATE,
		"단일 대상에 공격력 420% 전격 피해. 인성치 -45. "
		+ "대상의 HP가 35% 이하면 공격력 150%의 처형 피해를 추가한다.")
	ult.energy_cost = 120
	ult.turn_targeting = TurnCombat.Targeting.SINGLE
	var execute := _damage(1.50, 0)
	execute.require_target_hp_below = 0.35
	execute.label = "처형 (HP 35% 이하)"
	ult.turn_effects = [_damage(4.20, 45), execute]
	count += _save(ult)

	var trait_skill := _skill("arin_turn_trait", "연격", TurnCombat.ActionKind.TRAIT,
		"약점을 찌르면 추가 턴을 얻는다. (턴당 1회, 추가 턴 하드캡 2회에 걸린다)")
	trait_skill.trait_trigger = SkillData.TraitTrigger.ON_WEAKNESS_HIT
	trait_skill.trait_per_turn_cap = 1
	var extra := _effect(TurnSkillEffect.Kind.EXTRA_TURN, TurnSkillEffect.Scope.SELF)
	extra.amount = 1
	trait_skill.turn_effects = [extra]
	count += _save(trait_skill)

	return count


# =====================================================================
# 태희 — 잠식자 / 침식 / 참격 (설계서 §4.14 ③ 「독무의 화가」)
# =====================================================================
#
# 지속 피해(DoT) 팀의 메인 딜러. 버킷 B(방깎)와 D(취약, 속박 중첩당)를 동시에 담당해
# 팀 전체 딜을 올린다.
#
# **역설적 설계**: 적의 행동이 잦을수록 강해지므로 한기 동결 캐릭터와는 안티 시너지다.
# 오의 코스트 140으로 회전이 느려 오의 회복 효율 서포터와 궁합이 좋다.
func _gen_taehee() -> int:
	var count := 0

	var basic := _skill("taehee_turn_basic", "덧칠", TurnCombat.ActionKind.BASIC,
		"단일 대상에 공격력 90% 침식 피해. 인성치 -18. 60% 확률로 [속박] 1중첩.")
	basic.usable_ranks = [2, 3, 4]
	basic.target_ranks = [1, 2]
	basic.turn_targeting = TurnCombat.Targeting.SINGLE
	var bind := _effect(TurnSkillEffect.Kind.DOT, TurnSkillEffect.Scope.TARGET)
	bind.break_status = TurnCombat.BreakStatus.BIND
	bind.stacks = 1
	bind.duration = 3
	bind.chance = 0.60
	bind.label = "[속박] 1중첩 (60%)"
	basic.turn_effects = [_damage(0.90, 18), bind]
	count += _save(basic)

	var skill := _skill("taehee_turn_skill", "부식의 화폭", TurnCombat.ActionKind.SKILL,
		"대상 + 좌우 인접에 공격력 120% / 60% 침식 피해. 인성치 -30 / -15. "
		+ "대상에게 3턴간 방어력 -32%, 인접에는 -16%.")
	skill.rp_cost = 1
	skill.usable_ranks = [2, 3, 4]
	skill.turn_targeting = TurnCombat.Targeting.BLAST
	var def_down := _effect(TurnSkillEffect.Kind.DEBUFF, TurnSkillEffect.Scope.TARGET)
	def_down.stat_key = &"defense_reduction"
	def_down.value = 0.32
	def_down.duration = 3
	def_down.bucket = TurnCombat.Bucket.DEFENSE
	def_down.label = "방어력 -32%"
	var def_down_adj := _effect(TurnSkillEffect.Kind.DEBUFF, TurnSkillEffect.Scope.TARGET_ADJACENT)
	def_down_adj.stat_key = &"defense_reduction"
	def_down_adj.value = 0.16
	def_down_adj.duration = 3
	def_down_adj.bucket = TurnCombat.Bucket.DEFENSE
	def_down_adj.label = "방어력 -16% (인접)"
	skill.turn_effects = [_damage(1.20, 30), def_down, def_down_adj]
	count += _save(skill)

	var ult := _skill("taehee_turn_ult", "완성된 초상", TurnCombat.ActionKind.ULTIMATE,
		"적 전체에 공격력 200% 침식 피해. 인성치 -45. "
		+ "적 전체의 [속박] 중첩을 즉시 폭발시켜 중첩당 공격력 55% 추가 피해. "
		+ "폭발 후 [속박]을 2중첩 재부여한다.")
	ult.energy_cost = 140
	ult.turn_targeting = TurnCombat.Targeting.ALL_ENEMIES
	var detonate := _effect(TurnSkillEffect.Kind.DOT, TurnSkillEffect.Scope.ALL_ENEMIES)
	detonate.break_status = TurnCombat.BreakStatus.BIND
	detonate.require_status = true
	detonate.require_status_kind = TurnCombat.BreakStatus.BIND
	detonate.consume_status = true
	detonate.per_stack_multiplier = 0.55
	detonate.stacks = 2
	detonate.duration = 3
	detonate.label = "[속박] 폭발 후 2중첩 재부여"
	ult.turn_effects = [_damage(2.00, 45), detonate]
	count += _save(ult)

	var trait_skill := _skill("taehee_turn_trait", "스며드는 안료", TurnCombat.ActionKind.TRAIT,
		"약점을 찌를 때마다 [속박] 1중첩 추가 (최대 6중첩). "
		+ "[속박] 중첩당 대상이 받는 피해 +2.5%.")
	trait_skill.trait_trigger = SkillData.TraitTrigger.ON_WEAKNESS_HIT
	trait_skill.trait_per_turn_cap = 2
	var soak := _effect(TurnSkillEffect.Kind.DOT, TurnSkillEffect.Scope.TARGET)
	soak.break_status = TurnCombat.BreakStatus.BIND
	soak.stacks = 1
	soak.duration = 3
	soak.label = "[속박] 1중첩"
	trait_skill.turn_effects = [soak]
	count += _save(trait_skill)

	return count


# =====================================================================
# 설아 — 조율자 / 한기 / 관통 (설계서 §4.14 ② 「서리 계측관」)
# =====================================================================
#
# 조율자 계약: **서로 다른 버킷의 버프 2개 이상.** 버킷 E(치명타 피해)와 버킷 D(취약)를
# 동시에 담당하는 곱연산 2축 조율자다.
#
# 게다가 **공명 생산형**이라 하이퍼캐리 팀의 공명 파산을 막는다. 속도 143은
# 3사이클 6회 구간에 정확히 걸치는 값이다(설계서 §4.2.3 속도 구간표).
func _gen_seola() -> int:
	var count := 0

	var basic := _skill("seola_turn_basic", "측정 사격", TurnCombat.ActionKind.BASIC,
		"단일 대상에 공격력 70% 한기 피해. 인성치 -20. 관통이라 후열 타격이 가능하다.")
	basic.usable_ranks = [3, 4]
	basic.turn_targeting = TurnCombat.Targeting.SINGLE
	basic.turn_effects = [_damage(0.70, 20)]
	count += _save(basic)

	var skill := _skill("seola_turn_skill", "좌표 재정렬", TurnCombat.ActionKind.SKILL,
		"아군 1명의 행동을 40% 앞당기고, 3턴간 치명타 피해 +32%를 부여한다.")
	skill.rp_cost = 1
	skill.usable_ranks = [3, 4]
	skill.turn_targeting = TurnCombat.Targeting.ALLY_SINGLE
	var advance := _effect(TurnSkillEffect.Kind.ADVANCE, TurnSkillEffect.Scope.TARGET)
	advance.value = 0.40
	var crit := _effect(TurnSkillEffect.Kind.BUFF, TurnSkillEffect.Scope.TARGET)
	crit.stat_key = &"crit_damage"
	crit.value = 0.32
	crit.duration = 3
	crit.bucket = TurnCombat.Bucket.CRIT
	crit.label = "치명타 피해 +32%"
	skill.turn_effects = [advance, crit]
	count += _save(skill)

	var ult := _skill("seola_turn_ult", "절대 영도 관측", TurnCombat.ActionKind.ULTIMATE,
		"적 전체의 인성치 -35 (한기). 3턴간 적 전체가 받는 피해 +15%. "
		+ "이미 격파된 적에게는 인성치 피해가 초격파 피해로 전환된다.")
	ult.energy_cost = 100
	ult.turn_targeting = TurnCombat.Targeting.ALL_ENEMIES
	var shatter := _effect(TurnSkillEffect.Kind.TOUGHNESS, TurnSkillEffect.Scope.ALL_ENEMIES)
	shatter.toughness_damage = 35
	shatter.label = "인성치 -35"
	var vuln := _effect(TurnSkillEffect.Kind.DEBUFF, TurnSkillEffect.Scope.ALL_ENEMIES)
	vuln.stat_key = &"vulnerability"
	vuln.value = 0.15
	vuln.duration = 3
	vuln.bucket = TurnCombat.Bucket.VULNERABILITY
	vuln.label = "받는 피해 +15%"
	ult.turn_effects = [shatter, vuln]
	count += _save(ult)

	var trait_skill := _skill("seola_turn_trait", "연산 보조", TurnCombat.ActionKind.TRAIT,
		"자신의 턴 시작 시 공명 포인트 +1 (2턴마다 1회).")
	trait_skill.trait_trigger = SkillData.TraitTrigger.TURN_START
	trait_skill.trait_turn_period = 2
	var rp := _effect(TurnSkillEffect.Kind.RESONANCE, TurnSkillEffect.Scope.SELF)
	rp.amount = 1
	trait_skill.turn_effects = [rp]
	count += _save(trait_skill)

	return count


# =====================================================================
# 강지 — 치유자 / 광휘 / 강타
# =====================================================================
#
# 치유자 계약: **단일 힐 + 전체 힐.**
#
# 실시간 전투에서 강지의 정체성은 "평타로 들어간 피해의 비율만큼 아군을 회복시킨다"였다
# (수혈). 그 성질을 턴제에서도 특성으로 유지한다 — **강지가 딜을 넣지 않으면 파티가
# 회복되지 않는다.** 뒤에 서서 버튼만 누르는 힐러가 아니다.
func _gen_gangji() -> int:
	var count := 0

	var basic := _skill("gangji_turn_basic", "타격 진단", TurnCombat.ActionKind.BASIC,
		"단일 대상에 공격력 100% 광휘 피해. 인성치 -16.")
	basic.usable_ranks = [3, 4]
	basic.target_ranks = [1, 2]
	basic.turn_targeting = TurnCombat.Targeting.SINGLE
	basic.turn_effects = [_damage(1.00, 16)]
	count += _save(basic)

	var party_heal := _skill("gangji_turn_skill", "수혈 처방", TurnCombat.ActionKind.SKILL,
		"아군 전체를 마법 공격력 60%만큼 회복시킨다.")
	party_heal.rp_cost = 1
	party_heal.turn_targeting = TurnCombat.Targeting.ALLY_ALL
	var heal_all := _effect(TurnSkillEffect.Kind.HEAL, TurnSkillEffect.Scope.ALL_ALLIES)
	heal_all.multiplier = 0.60
	heal_all.scaling = TurnCombat.Scaling.MAGIC
	heal_all.label = "전체 회복 (마공 60%)"
	party_heal.turn_effects = [heal_all]
	count += _save(party_heal)

	var single_heal := _skill("gangji_turn_cleanse", "불가침", TurnCombat.ActionKind.SKILL,
		"아군 1명을 마법 공격력 120%만큼 회복시키고 디버프 2개를 해제한다.")
	single_heal.rp_cost = 1
	single_heal.turn_targeting = TurnCombat.Targeting.ALLY_SINGLE
	var heal_one := _effect(TurnSkillEffect.Kind.HEAL, TurnSkillEffect.Scope.TARGET)
	heal_one.multiplier = 1.20
	heal_one.scaling = TurnCombat.Scaling.MAGIC
	heal_one.label = "단일 회복 (마공 120%)"
	var cleanse := _effect(TurnSkillEffect.Kind.CLEANSE, TurnSkillEffect.Scope.TARGET)
	cleanse.amount = 2
	single_heal.turn_effects = [heal_one, cleanse]
	count += _save(single_heal)

	var ult := _skill("gangji_turn_ult", "여명의 각인", TurnCombat.ActionKind.ULTIMATE,
		"아군 전체를 마법 공격력 130%만큼 회복시키고, 2턴간 아군 전체의 피해 +20%.")
	ult.energy_cost = 120
	ult.turn_targeting = TurnCombat.Targeting.ALLY_ALL
	var ult_heal := _effect(TurnSkillEffect.Kind.HEAL, TurnSkillEffect.Scope.ALL_ALLIES)
	ult_heal.multiplier = 1.30
	ult_heal.scaling = TurnCombat.Scaling.MAGIC
	ult_heal.label = "전체 회복 (마공 130%)"
	var dawn := _effect(TurnSkillEffect.Kind.BUFF, TurnSkillEffect.Scope.ALL_ALLIES)
	dawn.stat_key = &"damage_bonus"
	dawn.value = 0.20
	dawn.duration = 2
	dawn.bucket = TurnCombat.Bucket.DMG_BONUS
	dawn.label = "피해 +20%"
	ult.turn_effects = [ult_heal, dawn]
	count += _save(ult)

	var trait_skill := _skill("gangji_turn_trait", "수혈", TurnCombat.ActionKind.TRAIT,
		"자신이 피해를 넣으면 그 피해의 35%만큼 가장 위태로운 아군을 회복시킨다.")
	trait_skill.trait_trigger = SkillData.TraitTrigger.ON_DAMAGE_DEALT
	trait_skill.trait_damage_ratio = 0.35
	trait_skill.trait_per_turn_cap = 3
	var transfuse := _effect(TurnSkillEffect.Kind.HEAL, TurnSkillEffect.Scope.LOWEST_HP_ALLY)
	transfuse.label = "넣은 피해의 35% 회복"
	trait_skill.turn_effects = [transfuse]
	count += _save(trait_skill)

	return count


# =====================================================================
# 적 공용 행동표
# =====================================================================
#
# **적 스킬을 공용으로 쓸 수 있는 이유**: 원소와 물리 타입은 스킬이 아니라 **시전자**에게서
# 온다(`SkillData.resolve_element()`). 그래서 같은 「돌진」이 벨로시랩터에게는 충격·참격,
# 매머드에게는 화염·강타로 나간다. 적을 늘릴 때마다 스킬을 복제하지 않는다.
#
# 적에게는 인성치 피해를 넣지 않는다(`toughness_damage = 0`) — 아군에게 인성치가 없다.
func _gen_enemy() -> int:
	var count := 0

	var strike := _skill("enemy_turn_strike", "돌진", TurnCombat.ActionKind.BASIC,
		"전열 아군 1명에게 공격력 100% 피해.")
	strike.target_ranks = [1, 2]
	strike.turn_targeting = TurnCombat.Targeting.SINGLE
	strike.turn_effects = [_damage(1.00, 0)]
	count += _save(strike, ENEMY_DIR)

	var ranged := _skill("enemy_turn_ranged", "원거리 사격", TurnCombat.ActionKind.BASIC,
		"아군 1명에게 공격력 90% 피해. 후열도 노린다.")
	ranged.turn_targeting = TurnCombat.Targeting.SINGLE
	ranged.turn_effects = [_damage(0.90, 0)]
	count += _save(ranged, ENEMY_DIR)

	var cleave := _skill("enemy_turn_cleave", "휘두르기", TurnCombat.ActionKind.SKILL,
		"대상 + 좌우 인접에 공격력 140% / 70% 피해.")
	cleave.target_ranks = [1, 2, 3]
	cleave.turn_targeting = TurnCombat.Targeting.BLAST
	cleave.turn_effects = [_damage(1.40, 0)]
	count += _save(cleave, ENEMY_DIR)

	# 대형 파괴형 패턴 (설계서 §4.8.3 5번).
	#
	# 후열 아군을 끌어내면 그 아군은 자기 스킬의 사용 랭크 조건을 잃는다 —
	# 치유자를 A1으로 끌어내면 힐을 쓸 수 없고 어그로가 폭증한다. 아군은 자리바꿈으로
	# 대형을 복구해야 한다. HSR에 없는 긴장감이 여기서 나온다.
	var drag := _skill("enemy_turn_drag", "낚아채기", TurnCombat.ActionKind.SKILL,
		"후열 아군 1명에게 공격력 80% 피해를 주고 앞으로 1칸 끌어당긴다.")
	drag.target_ranks = [3, 4]
	drag.turn_targeting = TurnCombat.Targeting.SINGLE
	var pull := _effect(TurnSkillEffect.Kind.PULL, TurnSkillEffect.Scope.TARGET)
	pull.distance = 1
	drag.turn_effects = [_damage(0.80, 0), pull]
	count += _save(drag, ENEMY_DIR)

	var shove := _skill("enemy_turn_shove", "밀어내기", TurnCombat.ActionKind.SKILL,
		"전열 아군 1명에게 공격력 100% 피해를 주고 뒤로 1칸 밀친다.")
	shove.target_ranks = [1, 2]
	shove.turn_targeting = TurnCombat.Targeting.SINGLE
	var shove_push := _effect(TurnSkillEffect.Kind.PUSH, TurnSkillEffect.Scope.TARGET)
	shove_push.distance = 1
	shove.turn_effects = [_damage(1.00, 0), shove_push]
	count += _save(shove, ENEMY_DIR)

	# 디버프 압박형 패턴 (설계서 §4.8.3 7번) — 치유자를 강제한다.
	var curse := _skill("enemy_turn_curse", "쇠약의 낙인", TurnCombat.ActionKind.SKILL,
		"아군 1명에게 공격력 70% 피해. 3턴간 그 아군의 받는 피해 +20%.")
	curse.turn_targeting = TurnCombat.Targeting.SINGLE
	var mark := _effect(TurnSkillEffect.Kind.DEBUFF, TurnSkillEffect.Scope.TARGET)
	mark.stat_key = &"vulnerability"
	mark.value = 0.20
	mark.duration = 3
	mark.chance = 0.85
	mark.bucket = TurnCombat.Bucket.VULNERABILITY
	mark.label = "받는 피해 +20%"
	curse.turn_effects = [_damage(0.70, 0), mark]
	count += _save(curse, ENEMY_DIR)

	var wipe := _skill("enemy_turn_wipe", "멸절의 낙뢰", TurnCombat.ActionKind.ULTIMATE,
		"아군 전체에 공격력 180% 피해.")
	wipe.energy_cost = 100
	wipe.turn_targeting = TurnCombat.Targeting.ALL_ENEMIES
	wipe.turn_effects = [_damage(1.80, 0)]
	count += _save(wipe, ENEMY_DIR)

	return count
