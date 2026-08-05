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

# ----- 확장 가이드 (Extensibility) -----
# 새 항목은 위 섹션 중 알맞은 곳에 @export 필드를 "기본값과 함께" 추가한다.
# 기본값이 있으면 기존 .tres는 누락 필드를 기본값으로 로드하므로 호환이 유지된다.
# 후속 이슈에서: AI 행동 파라미터(탐지/공격 범위 등), 드롭·보상 테이블, 스폰/웨이브 규칙을
# 같은 방식으로 추가한다. 공통 튜닝 수치는 CombatConfig가 출처이므로 중복 정의하지 않는다.


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
	return problems
