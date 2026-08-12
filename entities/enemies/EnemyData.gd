extends Resource
class_name EnemyData

# 적의 단일 정의 출처 (data definition).
# 이름/스텟/스킬/외형을 한 리소스로 묶는다.
#
# 재사용 원칙 (SYSTEM_CONVENTIONS 단일 출처):
#   - 스텟은 기존 PlayerStats를 그대로 재사용한다. 적 전용 스텟 체계를 새로 정의하지 않는다.
#     (EnemyBase도 이미 stats: PlayerStats를 쓰고 있어 캐릭터와 같은 출처를 공유한다.)
#   - 스킬은 기존 SkillData를 그대로 재사용한다.
#   - 따라서 버프/디버프·피해 계산 등 PlayerStats를 대상으로 하는 시스템이 적에게도 그대로 적용된다.
#
# CharacterData와 의도적으로 다른 점:
#   - role(브루저/원거리/버퍼) 없음: 파티 편성과 티어1 역할 구성 시너지 전용 의미이므로 적에게 부적합하다.
#   - 장비 3슬롯/착탈 없음: 설계상 적은 제작·착탈을 하지 않는다.
#   - 별도 레지스트리(EnemyDatabase)를 쓴다: CharacterDatabase의 로스터(9명) 조회가 오염되지 않도록.
#
# 참고: docs/combat-screen-design.md, SYSTEM_CONVENTIONS.md

# ===== 식별 (Identity) =====
@export var enemy_id: StringName = &""    # 고유 식별자 (예: &"training_goblin")
@export var display_name: String = ""      # 화면 표시 이름
@export_multiline var description: String = ""

# ===== 스텟 (Stats) =====
# 적의 스텟 출처. 비어 있으면 기본값 PlayerStats를 사용한다.
# (faith/intelligence는 적에게 미사용이며 기본값을 유지한다.)
@export var stats: PlayerStats = PlayerStats.new()

# ===== 스킬 (Skills) =====
@export var skills: Array[SkillData] = []

# ===== 외형 (Appearance) =====
# 아트는 추후 결정 단계이므로 지금은 도형 플레이스홀더용 값만 둔다.
@export var sprite_texture: Texture2D = null
@export var tint: Color = Color.WHITE
@export var sprite_scale: Vector2 = Vector2(2, 2)

# ===== AI 행동 (AI Behavior) =====
# 적의 행동 파라미터. EnemyBase의 추적/공격 AI가 이 값을 읽는다.
# 모두 기본값이 있어 기존 .tres는 그대로 로드된다(하위 호환).
#
# 수치 출처의 분리 (SYSTEM_CONVENTIONS §2):
#   - 이동속도·평타 쿨다운의 **기준값**은 CombatConfig.tuning이 소유한다
#     (base_move_speed / base_attack_cooldown). 여기에는 그 기준값에 곱할 **배수만** 둔다.
#     절대값을 적마다 다시 정의하면 기준값을 바꿔도 반영되지 않기 때문이다.
#   - 탐지/공격 **범위**는 공통 기준값이 없는 적 고유 값이므로 여기가 출처다.
@export_group("AI 행동")
## AI 활성 여부. false면 스텟/외형만 쓰고 움직이지 않는다(샌드백 용도).
## 참고: EnemyBase는 data가 아예 없는 적도 정지 상태로 둔다.
@export var ai_enabled: bool = true
## 이 거리 안에 살아 있는 파티 멤버가 있으면 추적을 시작한다(px).
## 대상이 이 범위를 벗어나면 추적을 놓는다(무한 추격 방지).
@export var detection_range: float = 300.0
## 이 거리 안에 들어오면 이동을 멈추고 평타를 넣는다(px).
@export var attack_range: float = 45.0
## 이동속도 배수. 최종 이동속도 = base_move_speed x 이 값 x 버프 이속 배수.
@export var move_speed_multiplier: float = 1.0
## 공격속도 배수. 최종 쿨다운 = base_attack_cooldown / (이 값 x 버프 공속 배수).
## 클수록 빠르다. PlayerStats의 공속 배수와 같은 방향(클수록 빠름)으로 맞췄다.
@export var attack_speed_multiplier: float = 1.0

# ----- 확장 가이드 (Extensibility) -----
# 새 항목은 위 섹션 중 알맞은 곳에 @export 필드를 "기본값과 함께" 추가한다.
# 기본값이 있으면 기존 .tres는 누락 필드를 기본값으로 로드하므로 호환이 유지된다.
# 후속 이슈에서: 드롭·보상 테이블, 스폰/웨이브 규칙, 원거리 공격·스킬 사용 파라미터를
# 같은 방식으로 추가한다. 공통 튜닝 수치는 CombatConfig가 출처이므로 중복 정의하지 않는다.
# (AI 행동 파라미터는 위 "AI 행동" 그룹에 추가되었다.)


# 안전한 스텟 접근: stats가 비어 있으면 기본 PlayerStats를 반환한다.
func get_stats() -> PlayerStats:
	if stats == null:
		stats = PlayerStats.new()
	return stats

# skill_id로 스킬을 찾는다. 없으면 null.
func find_skill(id: StringName) -> SkillData:
	for skill in skills:
		if skill != null and skill.skill_id == id:
			return skill
	return null


# 데이터 무결성 점검 (id가 비었는지 등). 문제 메시지 배열을 반환한다.
# CharacterData/EquipmentData의 validate()와 같은 규약.
func validate() -> Array[String]:
	var problems: Array[String] = []
	if String(enemy_id).is_empty():
		problems.append("enemy_id가 비어 있습니다.")
	if display_name.is_empty():
		problems.append("display_name이 비어 있습니다.")

	# AI 파라미터 점검. 저작 실수로 적이 아무것도 하지 않게 되는 경우를 잡는다.
	if attack_range <= 0.0:
		problems.append("attack_range는 0보다 커야 합니다.")
	# 탐지 범위가 공격 범위보다 짧으면 추적을 시작하기 전에 사거리에 들어와야 하므로
	# 사실상 접근하지 못한다.
	if detection_range < attack_range:
		problems.append("detection_range가 attack_range보다 짧습니다.")
	if move_speed_multiplier < 0.0:
		problems.append("move_speed_multiplier는 0 이상이어야 합니다.")
	# 0 이하면 쿨다운 계산에서 0으로 나누게 된다.
	if attack_speed_multiplier <= 0.0:
		problems.append("attack_speed_multiplier는 0보다 커야 합니다.")

	return problems
