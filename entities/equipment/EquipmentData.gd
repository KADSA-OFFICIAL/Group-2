extends Resource
class_name EquipmentData

# 장비 정의의 단일 출처 (data definition).
# 슬롯/스텟 보너스/제작 비용을 한 리소스로 묶는다.
# 실제 장비 아이템은 data/equipment/*.tres로 저작하고, EquipmentDatabase가 로드한다.

# ===== 슬롯 (Slot) =====
# 방어구는 3부위(투구/갑옷/레깅스)로 나뉘고, 거울은 여신 스킬 강화 전용이다.
enum Slot {
	WEAPON,    # 무기
	HELMET,    # 투구
	CHEST,     # 갑옷
	LEGGINGS,  # 레깅스
	MIRROR,    # 거울
}

# ===== 식별 (Identity) =====
@export var equipment_id: StringName = &""   # 고유 식별자 (예: &"stone_helmet")
@export var display_name: String = ""         # 화면 표시 이름
@export_multiline var description: String = ""

# 장착 슬롯. 슬롯당 1개만 장착된다.
@export var slot: Slot = Slot.WEAPON

# 재료 티어. 밸런스 기준축(1=스톤/청동, 2=철, 3=후다만티움).
# 같은 라인 안에서 티어마다 스탯이 대략 x1.6씩 오른다(#157).
@export var tier: int = 1

# ===== 스텟 보너스 (Stat Bonuses) =====
# 장착 시 PlayerStats 파생 계산에 합산되는 입력값. 모두 기본 0이라
# 값을 지정하지 않은 장비는 해당 스텟에 영향을 주지 않는다.
@export var physical_attack_bonus: int = 0
@export var magic_attack_bonus: int = 0
@export var physical_defense_bonus: int = 0
@export var magic_defense_bonus: int = 0
@export var hp_bonus: int = 0
# 이동속도(비율, 0.05 = +5%) — 레깅스가 제공.
@export var move_speed_bonus: float = 0.0
# 여신 스킬 강화(가산, 0.10 = +10%p) — 거울이 제공.
@export var goddess_skill_boost_bonus: float = 0.0

# ===== 제작 (Crafting) =====
# 제작 비용. 재화 id(String) -> 필요 수량(int).
# 키는 CurrencySystem.DEFAULT_CURRENCIES의 재화 id를 참조한다(단일 출처).
# 비어 있으면 제작 비용이 없는 장비로 취급한다.
@export var craft_cost: Dictionary = {}

# ===== 외형 (Appearance) =====
@export var icon: Texture2D = null

# ----- 확장 가이드 (Extensibility) -----
# 새 스텟 보너스는 위 "스텟 보너스" 섹션에 @export 필드를 "기본값 0"과 함께 추가하고,
# CharacterData.get_equipment_bonuses()의 합산에 한 줄 더한다.
# 기본값이 있으면 기존 .tres는 누락 필드를 기본값으로 로드하므로 호환이 유지된다.


# 슬롯의 화면 표시용 한글 이름을 반환한다.
func get_slot_name() -> String:
	match slot:
		Slot.WEAPON:
			return "무기"
		Slot.HELMET:
			return "투구"
		Slot.CHEST:
			return "갑옷"
		Slot.LEGGINGS:
			return "레깅스"
		Slot.MIRROR:
			return "거울"
		_:
			return "알 수 없음"

# 데이터 무결성 점검. 문제 메시지 배열을 반환한다.
func validate() -> Array[String]:
	var problems: Array[String] = []
	if String(equipment_id).is_empty():
		problems.append("equipment_id가 비어 있습니다.")
	if display_name.is_empty():
		problems.append("display_name이 비어 있습니다.")
	for key in craft_cost:
		if typeof(craft_cost[key]) != TYPE_INT or int(craft_cost[key]) < 0:
			problems.append("craft_cost['%s']는 0 이상의 정수여야 합니다." % str(key))
	return problems
