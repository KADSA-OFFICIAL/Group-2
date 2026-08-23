extends Node

# 교단의 단일 출처 (autoload).
#
# 교단은 **교주(플레이어)와 스토리에서 합류한 인물들이 모여 있는 본거지**다.
# 교회에 해당하는 조직이며, 이름은 트리아교다.
#
# 지금 이 시스템이 아는 것은 "교단의 정체"뿐이다. **뼈대다.**
# 신도 관리·교리·헌금 같은 기능은 설계가 없어 만들지 않았다.
#
# 단일 출처 원칙:
#   - 교단 이름을 화면에 문자열로 박지 않는다. 화면이 여럿이면 한쪽만 바뀐다.
#   - 교주의 이름·레벨은 PlayerProfile 이 소유한다. 여기서 다시 들지 않는다.
#   - 모인 인원 명부는 CharacterDatabase 가 소유한다. 여기서 다시 들지 않는다.

# 교단 이름. 게임 세계의 고정값이며 플레이어가 바꾸지 않는다.
# (플레이어가 정하는 것은 교주 이름이고 그쪽은 PlayerProfile 이 가진다.)
const ORDER_NAME := "트리아교"

# 교단 우두머리의 직함. 화면이 "교주"를 각자 적지 않도록 여기 둔다.
const LEADER_TITLE := "교주"


func _ready() -> void:
	name = "OrderSystem"
	_load_buildings()


# ===== 조회 (Query) =====

# 교주의 표시 이름. 이름을 아직 정하지 않았으면 대체 문구를 돌려준다.
#
# PlayerProfile 은 기본 이름을 만들지 않는다(이름은 플레이어가 정한다).
# 그 빈 값을 어떻게 보여줄지는 교단 도메인의 지식이므로 여기서 정한다.
# 화면마다 "이름 없음"을 각자 적으면 문구가 갈린다.
func get_leader_display_name() -> String:
	if PlayerProfile.player_name.is_empty():
		return "이름 없는 %s" % LEADER_TITLE
	return PlayerProfile.player_name


# "트리아교의 교주" 처럼 소속을 붙인 한 줄.
func get_leader_title_line() -> String:
	return "%s의 %s" % [ORDER_NAME, LEADER_TITLE]


# 교단에 모인 인원 수. 명부의 출처는 CharacterDatabase 다.
# 스토리 인물·보스(playable = false)는 교단에 합류한 인원이 아니므로 세지 않는다 (#216).
# ===== 본거지 건물 (Buildings) =====
#
# 왜 별도 레지스트리(autoload)를 만들지 않았나: 건물은 교단의 구성물이고 개수가 넷이다.
# 조회하는 곳도 뜰 화면 하나뿐이라, 자기 도메인을 이미 가진 이 시스템이 들고 있는 편이
# 출처가 하나로 남는다. 종류가 늘어 다른 화면도 묻기 시작하면 그때 떼어낸다.

const BUILDING_DIR := "res://data/order/buildings"

var _buildings: Array[OrderBuildingData] = []


# 저작된 건물 전부. spot.y 오름차순(뒤 -> 앞)이라 그리는 쪽이 다시 정렬하지 않는다.
func get_buildings() -> Array[OrderBuildingData]:
	return _buildings


func _load_buildings() -> void:
	_buildings.clear()

	var dir := DirAccess.open(BUILDING_DIR)
	if dir == null:
		# 아직 저작되지 않았을 수 있다(정상). 뜰은 빈 마당으로 열린다.
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir():
			var clean := file_name.trim_suffix(".remap")
			if clean.ends_with(".tres"):
				_load_building(BUILDING_DIR.path_join(clean))
		file_name = dir.get_next()
	dir.list_dir_end()

	# 뒤에 선 건물부터 그리도록 미리 정렬해 둔다.
	_buildings.sort_custom(func(a, b): return a.spot.y < b.spot.y)


func _load_building(path: String) -> void:
	var res := load(path)
	if not (res is OrderBuildingData):
		push_warning("OrderSystem: OrderBuildingData 가 아닙니다(건너뜀): " + path)
		return

	var data: OrderBuildingData = res
	var problems := data.validate()
	if not problems.is_empty():
		push_warning("OrderSystem: 유효하지 않은 건물(" + path + "): " + ", ".join(problems))
		return

	_buildings.append(data)


func get_member_count() -> int:
	return CharacterDatabase.get_playable_count()


# ----- 확장 가이드 -----
# 교단의 기능(신도 관리, 교리, 헌금, 시설 등)이 정해지면 이 시스템에 얹는다.
# 값을 소유하는 곳이 여기이고, 화면은 읽기만 한다.
# "스토리에서 합류했는가"를 구분해야 하면 합류 여부도 여기서 관리하게 된다
# (지금은 그 데이터가 없어 CharacterDatabase 전체를 교단 인원으로 본다).
