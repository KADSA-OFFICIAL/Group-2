extends Resource
class_name StageSpawn

# 스테이지의 적 배치 한 줄 (data definition).
#
# 왜 별도 리소스인가: 배치는 "무엇을 / 어디에 / 몇 마리" 세 값의 묶음이다.
# StageData 에 배열 세 개(씬 배열·좌표 배열·수량 배열)로 두면 인덱스가 어긋난
# 저작 실수를 막을 수 없다. 한 줄이 한 리소스면 저작 화면에서도 묶여 보인다.
#
# 적 정의(스텟·AI·외형)의 출처는 EnemyData 이고, 여기서 다시 쓰지 않는다.
# 이 리소스는 **어느 씬을 어디에 몇 개 놓을지**만 정한다.
#
# 참고: entities/stage/StageData.gd, data/stages/README.md

# 스폰할 적 씬. EnemyData 는 씬 안의 노드가 들고 있으므로 여기서는 씬만 가리킨다.
# (적 id -> 씬 대응표를 새로 만들면 씬과 데이터 두 곳이 출처가 된다.)
@export var enemy_scene: PackedScene = null

# 스폰 위치(스테이지 로컬 좌표).
@export var position: Vector2 = Vector2.ZERO

# 같은 씬을 여러 마리 놓을 때 쓴다. 2 이상이면 offset 만큼 밀어서 배치한다.
@export var count: int = 1

# count 가 2 이상일 때 마리마다 더해지는 간격.
# 0 이면 전부 같은 자리에 겹쳐 스폰되므로 기본값을 가로 간격으로 둔다.
@export var offset: Vector2 = Vector2(100, 0)


# i 번째(0부터) 개체의 위치.
func get_position(index: int) -> Vector2:
	return position + offset * index


# ===== 무결성 점검 (Validation) =====
# StageData / EnemyData 와 같은 규약. 문제 메시지 배열을 반환한다.
func validate() -> Array[String]:
	var problems: Array[String] = []
	if enemy_scene == null:
		problems.append("enemy_scene이 비어 있습니다.")
	if count < 1:
		problems.append("count는 1 이상이어야 합니다: %d" % count)
	return problems
