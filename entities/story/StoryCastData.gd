extends Resource
class_name StoryCastData

# 스토리에만 나오는 화자의 정의 (data definition).
#
# 왜 CharacterData 가 아닌가 (#202):
#   CharacterData 는 **플레이어 로스터**의 정의다. 역할(탱커/원거리/버퍼)·PlayerStats·장비
#   슬롯을 갖고 있고, 로스터를 순회하는 시스템들이 "CharacterDatabase 에 있는 것은 전부
#   내가 다룰 대상"이라는 전제로 쓰여 있다(PlayerProfile 의 성장 배수, EquipmentSystem 의
#   착용 저장 등). 스토리 전용 인물이 그 안에 있으면 그 전제가 조용히 깨진다.
#
#   #216 의 playable 플래그는 **편성 화면에서 걸러 주는 장치**다. 걸러야 한다는 것을
#   기억해야 하고, 실제로 위 두 곳에서 잊혔다. 아예 다른 출처에 두면 기억할 일이 없다.
#
# 그래서 이 리소스는 **의도적으로 최소**다. 역할·스텟·장비·스킬을 두지 않는다.
# 스토리 화면이 화자를 무대에 세우는 데 필요한 것만 갖는다.
# 여기에 전투용 필드를 추가하고 싶어지면, 그 인물은 스토리 전용이 아니라는 뜻이므로
# CharacterData(로스터) 또는 EnemyData(적) 쪽에 저작한다.

# 고유 식별자. 대본의 StoryLineData.character_id 가 이 값을 가리킨다.
# CharacterData.character_id / EnemyData.enemy_id 와 **같은 이름 공간**을 쓴다
# — 한 id 는 세 출처 중 하나에서만 해석되어야 한다.
@export var cast_id: StringName = &""

# ===== 화자 표시 규약 (Speaker display protocol) =====
# 스토리 화면은 화자 정의에서 display_name / tint / portrait 세 가지를 읽는다.
# CharacterData·EnemyData 도 같은 이름의 필드를 갖고 있어 화면이 타입을 가리지 않는다.
# 필드 이름을 바꾸면 story_player_screen 의 화자 표시가 조용히 비어 버린다.

@export var display_name: String = ""

## 무대에서 이 인물의 색. 화면이 팔레트 톤으로 당겨 쓴다(HUDKit.muted).
## 비워 두면 흰색이 되어 톤 조정이 무의미해지므로 인물마다 정해 준다.
@export var tint: Color = Color.WHITE

## 무대에 세울 초상. 비어 있으면 화면이 색 플레이스홀더로 대체한다.
##
## PortraitSystem 을 타지 않는 이유: 그쪽은 **플레이어가 로스터 캐릭터의 초상을 고르는**
## 기능이다(선택 > 저작 기본값). 스토리 인물은 플레이어가 고르는 대상이 아니다.
@export var portrait: Texture2D = null

@export_multiline var description: String = ""


# 데이터베이스가 로드 시점에 부른다. CharacterData/EnemyData 와 같은 규약이다.
func validate() -> Array[String]:
	var problems: Array[String] = []
	if String(cast_id).is_empty():
		problems.append("cast_id가 비어 있습니다.")
	if display_name.is_empty():
		problems.append("display_name이 비어 있습니다.")
	return problems
