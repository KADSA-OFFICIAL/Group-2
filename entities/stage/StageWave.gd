extends Resource
class_name StageWave

# 스테이지 한 웨이브. 한 번에 놓이는 적 한 무리다(#375).
#
# 왜 StageData.spawns 를 그냥 나누지 않았는가:
#   spawns 는 "시작 시 한 번에 놓는 배치"라는 뜻이 이미 굳어 있다(StageData 주석).
#   거기에 순서를 얹으면 같은 필드가 두 가지를 뜻하게 되고, 웨이브를 쓰지 않는
#   기존 스테이지의 동작이 조용히 달라진다. 새 개념은 새 자리에 둔다.
#
# 방아쇠는 **앞 웨이브 전멸** 하나뿐이다. 시간 기반 등장은 넣지 않았다 —
# 스펙이 요구할 때 필드로 만든다(SkillData 가 트리거를 다루는 것과 같은 규약).

## 이 웨이브에 놓이는 적. 비어 있으면 저작 실수다(validate 가 잡는다).
@export var spawns: Array[StageSpawn] = []

## 화면에 알릴 이름. 비어 있으면 알리지 않는다.
## 판정에는 쓰이지 않는다 — 순수 표시용이라 연출이 이 값을 읽어 쓴다.
@export var label: String = ""

## 이 웨이브가 보스인가. 승리 조건은 바뀌지 않는다(마지막 웨이브까지 전멸이 조건이다).
##
## 무엇에 쓰는가: 연출·HUD 가 "지금 보스전인가"를 데이터에서 알 수 있어야 한다.
## 마지막 웨이브 == 보스라고 코드가 단정하면, 보스 뒤에 잔당 웨이브를 붙이는 순간 깨진다.
@export var is_boss: bool = false


func validate() -> Array[String]:
	var problems: Array[String] = []
	if spawns.is_empty():
		problems.append("spawns가 비어 있습니다(적 없는 웨이브는 즉시 넘어가 버립니다).")
	for i in range(spawns.size()):
		var spawn := spawns[i]
		if spawn == null:
			problems.append("spawns[%d]가 비어 있습니다." % i)
			continue
		for problem in spawn.validate():
			problems.append("spawns[%d]: %s" % [i, problem])
	return problems
