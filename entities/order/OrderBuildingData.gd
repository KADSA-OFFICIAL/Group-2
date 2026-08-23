extends Resource
class_name OrderBuildingData

# 본거지 뜰에 놓이는 건물 하나의 정의 (data definition).
#
# 건물은 **기능으로 들어가는 문**이다. 제조소를 누르면 제조 화면이 열린다.
# 그래서 이 리소스가 아는 것은 "무엇처럼 보이고, 어디에 서 있고, 어디로 가는가" 뿐이다.
# 제조·상점의 규칙은 각 시스템이 소유한다(여기서 재정의하지 않는다).
#
# CharacterData / StageData 와 같은 규약을 따른다: 식별 필드 + @export + validate().
#
# 참고: data/order/README.md, screens/order/order_yard.gd

# ===== 식별 (Identity) =====
@export var building_id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""

# ===== 외형 (Appearance) =====

## 건물 그림. 아직 없으면 비워 둔다 — 뜰이 아이콘 + 이름표 플레이스홀더로 대신 세운다.
@export var art: Texture2D = null

## 플레이스홀더에 쓸 아이콘 이름(UITheme.icon_path 가 경로를 푼다).
## 그림이 들어오면 쓰이지 않지만 지우지 않는다 — 아트를 다시 뺄 수도 있다.
@export var icon_name: String = ""

## 그림이 없을 때 플레이스홀더 판을 칠할 색.
@export var tint: Color = Color(0.85, 0.78, 0.62)

# ===== 배치 (Placement) =====

## 뜰 안에서의 자리. **비율(0~1)** 이다 — 창 크기가 바뀌어도 같은 곳에 서 있어야 한다.
## 기준점은 건물의 **바닥 가운데**다. 건물은 이 점 위로 세워진다(발이 땅에 붙는다).
@export var spot: Vector2 = Vector2(0.5, 0.8)

## 건물 폭. 뜰 **가로**에 대한 비율이다.
@export var width_ratio: float = 0.22

# ===== 연결 (Link) =====

## 누르면 열 화면. 비어 있으면 눌리지 않는 장식 건물이다.
## 화면끼리 preload 하지 않는 이 프로젝트의 규약대로 경로 문자열로 둔다.
@export_file("*.tscn") var screen_path: String = ""


func is_enterable() -> bool:
	return not screen_path.is_empty()


# ===== 무결성 점검 (Validation) =====
func validate() -> Array[String]:
	var problems: Array[String] = []
	if String(building_id).is_empty():
		problems.append("building_id가 비어 있습니다.")
	if display_name.is_empty():
		problems.append("display_name이 비어 있습니다.")
	if width_ratio <= 0.0 or width_ratio > 1.0:
		problems.append("width_ratio는 0보다 크고 1 이하여야 합니다: %f" % width_ratio)
	if spot.x < 0.0 or spot.x > 1.0 or spot.y < 0.0 or spot.y > 1.0:
		problems.append("spot은 0~1 비율이어야 합니다: %s" % str(spot))
	# 열 수 없는 화면을 가리키면 눌렀을 때 아무 일도 일어나지 않는다. 저작 시점에 잡는다.
	if not screen_path.is_empty() and not ResourceLoader.exists(screen_path):
		problems.append("screen_path 를 찾을 수 없습니다: %s" % screen_path)
	return problems
