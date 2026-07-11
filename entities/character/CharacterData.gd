extends Resource
class_name CharacterData

# 캐릭터의 단일 정의 출처 (data definition).
# 이름/스텟/스킬/외형을 한 리소스로 묶는다.
# 스텟은 기존 PlayerStats를 재사용하고, 캐릭터별 .tres로 교체 주입한다.

# ===== 분류 (Role) =====
# 캐릭터의 전투 역할 분류. 편성/밸런스/UI 표시 등에서 참고한다.
enum Role {
	MELEE_DEALER,   # 근접 딜러
	RANGED_DEALER,  # 원거리 딜러
	BUFFER,         # 버퍼
}

# 기본값 MELEE_DEALER: 기존/신규 .tres가 누락 시 안전하게 로드되도록 첫 값을 기본으로 둔다.
@export var role: Role = Role.MELEE_DEALER

# ===== 식별 (Identity) =====
@export var character_id: StringName = &""   # 고유 식별자 (예: &"shipduck")
@export var display_name: String = ""         # 화면 표시 이름
@export_multiline var description: String = ""

# ===== 스텟 (Stats) =====
# 캐릭터의 스텟 출처. 비어 있으면 기본값 PlayerStats를 사용한다.
@export var stats: PlayerStats = PlayerStats.new()

# ===== 스킬 (Skills) =====
@export var skills: Array[SkillData] = []

# ===== 외형 (Appearance) =====
@export var sprite_texture: Texture2D = null
@export var tint: Color = Color.WHITE
@export var sprite_scale: Vector2 = Vector2(2, 2)

# ===== 장비 (Equipment) — placeholder =====
# 장비 시스템은 후속 이슈에서 구축한다. 지금은 빈 슬롯만 둔다.
# 전용 EquipmentData 클래스가 생기기 전이라 Resource 배열로 둔다
# (EquipmentData는 Resource 하위 타입이 될 것이므로 호환 유지).
@export var equipment: Array[Resource] = []

# ----- 확장 가이드 (Extensibility) -----
# 새 항목은 위 섹션 중 알맞은 곳에 @export 필드를 "기본값과 함께" 추가한다.
# 기본값이 있으면 기존 .tres는 누락 필드를 기본값으로 로드하므로 호환이 유지된다.
# 후속 이슈에서: equipment 타입을 Array[EquipmentData]로 좁히거나,
# level/exp 등 성장 필드, voice/portrait 등 외형 필드를 같은 방식으로 추가한다.


# 역할의 화면 표시용 한글 이름을 반환한다.
func get_role_name() -> String:
	match role:
		Role.MELEE_DEALER:
			return "근접 딜러"
		Role.RANGED_DEALER:
			return "원거리 딜러"
		Role.BUFFER:
			return "버퍼"
		_:
			return "알 수 없음"

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
func validate() -> Array[String]:
	var problems: Array[String] = []
	if String(character_id).is_empty():
		problems.append("character_id가 비어 있습니다.")
	if display_name.is_empty():
		problems.append("display_name이 비어 있습니다.")
	return problems