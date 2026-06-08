## res://data/chapter_data.gd
## 챕터 1개 = 스테이지 배열.

class_name ChapterData
extends Resource

@export var number_label: String = ""     # "33장"
@export var name: String = ""             # "균열의 새벽"
@export var stages: Array[StageData] = []
