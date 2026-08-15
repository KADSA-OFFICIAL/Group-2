extends Resource
class_name StoryLineData

# 스토리 한 줄의 정의 (data definition).
#
# 대본은 세 가지로만 이루어진다. 원본 대본을 그대로 담을 수 있는 최소 구성이다:
#   지문   "주인공 골목길에서 소꿉친구를 기다린다."  / "암전"
#   대사   "주인공: 소꿉아..기다리고 있었어!"
#   전투   "전투 시작, 주인공이 이김"
#
# 실제 대본은 data/story/*.tres 로 저작하고 StoryDatabase 가 로드한다.

enum Kind {
	NARRATION,  # 지문·연출 (화자 없음)
	DIALOGUE,   # 대사 (화자 있음)
	BATTLE,     # 전투가 끼어드는 지점
}

@export var kind: Kind = Kind.NARRATION

# 화자 이름. DIALOGUE 일 때만 쓴다.
#
# CharacterData 의 id 가 아니라 **표시 이름 문자열**이다.
# 대본의 화자 중 상당수가 아직 로스터에 없거나(여신, 마을 사람들, 각종 수인)
# 이름이 미정이기 때문이다("주인공", "소꿉친구", "???").
# 로스터와의 연결이 정해지면 character_id 필드를 함께 두고 이 값을 표시용으로 남긴다.
@export var speaker: String = ""

@export_multiline var text: String = ""

# BATTLE 일 때 어느 스테이지로 갈지. 비어 있으면 "전투가 있다"는 표시만 한다.
# 스테이지 정의의 출처는 StageDatabase 다(여기서 전투를 정의하지 않는다).
@export var stage_id: StringName = &""


func validate() -> Array[String]:
	var problems: Array[String] = []
	match kind:
		Kind.DIALOGUE:
			if speaker.is_empty():
				problems.append("대사인데 speaker가 비어 있습니다.")
			if text.is_empty():
				problems.append("대사인데 text가 비어 있습니다.")
		Kind.NARRATION:
			if text.is_empty():
				problems.append("지문인데 text가 비어 있습니다.")
		Kind.BATTLE:
			pass
	return problems
