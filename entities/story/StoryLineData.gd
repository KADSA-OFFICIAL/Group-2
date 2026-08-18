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


# ===== 연출 (Direction) =====
#
# 연출은 저작물이다. 화면이 본문을 훑어 짐작하지 않고, 대본이 지시한다.
#
# 왜 필드로 옮겼는가 (#135):
#   #133 에서는 화면이 본문에 "암전" 같은 말이 들어 있는지 검사해서 연출을 걸었다.
#   그러면 "눈을 감고 생각했다" 같은 평범한 지문에서 화면이 어두워지고, 반대로 연출이
#   필요한데 그 말이 없는 줄은 아무 일도 일어나지 않는다.
#   무엇보다 대본을 쓰는 사람이 연출을 지시하려면 본문에 키워드를 끼워 넣어야 했다.
#
# 두 필드의 기본값 방침이 다르다:
#   emotion 은 AUTO(문장부호로 추론)가 기본이다. 대사 수백 줄에 감정을 일일이 적는
#   것은 비현실적이고, 부호가 실제로 감정을 담고 있다.
#   screen_effect 는 NONE 이 기본이고 추론이 없다. 화면 전체를 덮는 연출이 저절로
#   일어나면 안 된다. 반드시 지시해야 한다.

# 말하는 인물의 반응.
enum Emotion {
	AUTO,       # 본문 문장부호로 추론한다 (아래 resolve_emotion)
	NORMAL,     # 가벼운 끄덕임
	SURPRISE,   # 놀람 — 튀어오른다
	QUESTION,   # 의문 — 고개를 갸웃한다
	DOWN,       # 머뭇거림·낙담 — 처진다
}

@export var emotion: Emotion = Emotion.AUTO

# 화면 전체 연출.
enum ScreenEffect {
	NONE,
	BLACKOUT,   # 암전 — 어두워졌다 돌아온다
	SHAKE,      # 흔들림 — 충격·전투
}

@export var screen_effect: ScreenEffect = ScreenEffect.NONE


# 이 줄에서 인물이 어떤 반응을 할지 확정한다.
#
# AUTO 추론을 여기 두는 이유: "대본 한 줄을 어떻게 해석할 것인가"는 데이터의 책임이지
# 화면의 책임이 아니다. 화면이 여러 개가 되어도(예: 대사 로그) 해석은 하나여야 한다.
func resolve_emotion() -> Emotion:
	if emotion != Emotion.AUTO:
		return emotion
	if text.contains("!"):
		return Emotion.SURPRISE
	if text.contains("?"):
		return Emotion.QUESTION
	if text.contains("..") or text.contains("…"):
		return Emotion.DOWN
	return Emotion.NORMAL


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

	# 화자가 없는 줄에 인물 반응을 지시해 봐야 반응할 인물이 없다.
	# 저작 실수를 조용히 넘기지 않고 여기서 잡는다.
	if kind != Kind.DIALOGUE and emotion != Emotion.AUTO:
		problems.append("화자가 없는 줄(%s)에 emotion 이 지정되어 있습니다." % _kind_name())
	return problems


func _kind_name() -> String:
	match kind:
		Kind.DIALOGUE:
			return "대사"
		Kind.BATTLE:
			return "전투"
		_:
			return "지문"
