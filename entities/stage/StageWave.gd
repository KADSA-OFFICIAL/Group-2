extends Resource
class_name StageWave

# 스테이지 한 웨이브. 한 번에 놓이는 적 한 무리다(#375).
#
# 왜 StageData.spawns 를 그냥 나누지 않았는가:
#   spawns 는 "시작 시 한 번에 놓는 배치"라는 뜻이 이미 굳어 있다(StageData 주석).
#   거기에 순서를 얹으면 같은 필드가 두 가지를 뜻하게 되고, 웨이브를 쓰지 않는
#   기존 스테이지의 동작이 조용히 달라진다. 새 개념은 새 자리에 둔다.
#
# 기본 방아쇠는 **앞 웨이브 전멸**이다. 거기에 조건을 더 얹는 필드가 하나 있다:
# requires_capture(#442, 아래). 시간 기반 등장은 아직 넣지 않았다 —
# 스펙이 요구할 때 필드로 만든다(SkillData 가 트리거를 다루는 것과 같은 규약).
# requires_capture 가 그 규약을 처음 따른 사례다.

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

## 이 웨이브가 놓이기 전에 **모든 거점 존이 확보되어야** 하는가 (#442).
##
## 기본 방아쇠(앞 웨이브 전멸)에 조건을 하나 더 얹는다 — 둘 다 채워져야 놓인다.
## 파일 머리 주석이 적어 둔 "스펙이 요구할 때 필드로 만든다"에 해당하는 첫 사례다.
##
## 무엇에 쓰는가: "점령한 뒤에 보스가 나온다"를 데이터로 표현한다. 이것 없이는
## 점령과 웨이브가 서로를 모르고 나란히 흐르기만 해서, 점을 무시하고 보스를 먼저
## 잡은 뒤 아무도 없는 점을 채우는 마무리가 된다(1-3 이 실제로 그랬다).
##
## **기본값 false 인 이유**: 이 필드가 없는 기존 .tres 는 누락 필드를 기본값으로
## 로드한다. true 가 기본이면 저작된 모든 웨이브가 갑자기 멈춘다.
##
## 판정 단위는 "존 전부"다. 일부만 확보하면 되는 조건은 없다 —
## Stage._all_zones_captured() 가 전부를 요구하고, 그것이 점령의 정의다.
##
## 저작 실수 둘은 StageData.validate() 가 막는다(교착 상태가 되기 때문이다):
##   - 점령을 요구하지 않는 type 에서 이 필드를 켜는 것 (존이 없어 영원히 안 놓인다)
##   - spawns 가 비었는데 첫 웨이브에 켜는 것 (진입 시 적이 하나도 놓이지 않는다)
@export var requires_capture: bool = false


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
