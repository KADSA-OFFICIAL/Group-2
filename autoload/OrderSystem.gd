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
func get_member_count() -> int:
	return CharacterDatabase.get_count()


# ----- 확장 가이드 -----
# 교단의 기능(신도 관리, 교리, 헌금, 시설 등)이 정해지면 이 시스템에 얹는다.
# 값을 소유하는 곳이 여기이고, 화면은 읽기만 한다.
# "스토리에서 합류했는가"를 구분해야 하면 합류 여부도 여기서 관리하게 된다
# (지금은 그 데이터가 없어 CharacterDatabase 전체를 교단 인원으로 본다).
