## res://data/stage_data.gd
## 스테이지 1개의 데이터. 나중에 .tres 로 저장/편집 가능.

class_name StageData
extends Resource

@export var code: String = ""             # "33-9"
@export var index: int = 0                # 챕터 내 1-based 번호
@export var name: String = ""             # "무너진 성소"
@export var recommended_power: int = 0
@export var stamina_cost: int = 0
@export var sweep_ticket_cost: int = 0
## -1 = 잠김, 0 = 미클리어(현재), 1~3 = 클리어(별 개수)
@export var stars: int = -1
@export var is_boss: bool = false

func is_locked() -> bool: return stars == -1
func is_cleared() -> bool: return stars >= 1
func is_current() -> bool: return stars == 0
