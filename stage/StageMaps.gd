extends RefCounted
class_name StageMaps

# 컨셉(육지/바다/하늘) -> 전장 맵 씬의 유일한 출처 (#420).
#
# #408 이 챕터에서 컨셉을 도출하게 만들었지만, 컨셉이 어떤 맵을 쓰는지는 아직
# 어디에도 없었다 -- 맵이 stage/Stage1_1.tscn 에 박혀 있어서 어떤 스테이지로
# 출격해도 초원이 나왔다. 이 파일이 그 대응을 담는다.
#
# 왜 autoload 가 아닌가: 상태를 갖지 않고 저작 데이터를 로드하지도 않는다.
# 대응표 하나와 정적 함수뿐이라 autoload 로 만들 이유가 없다
# (project.godot 의 [autoload] 는 append 만 하는 곳이므로 더 아끼는 편이 낫다).
#
# 왜 StageData 에 넣지 않는가: StageData 는 **저작 데이터의 스키마**다.
# 씬 경로는 프로젝트 구조에 속하고, .tres 에 저작될 값이 아니다.
# StageData 는 챕터->컨셉까지만 알고, 컨셉->씬은 여기가 안다.
#
# 참고: entities/stage/StageData.gd (챕터->컨셉), data/stages/README.md

# 컨셉 -> 맵 씬 경로.
#
# 세 컨셉이 모두 채워졌다(#423 으로 하늘이 마지막이었다). 컨셉이 늘면 여기에
# 한 줄을 더하면 되고, 전장·스테이지 코드는 고치지 않는다.
#
# 빈 칸을 남겨 두지 않고 키를 아예 두지 않는 이유: 빈 문자열을 넣어 두면
# "등록됐지만 경로가 잘못됨"과 "아직 안 만들어짐"이 구별되지 않는다.
const CONCEPT_SCENE := {
	StageData.Concept.LAND: "res://stage/grassland/GrasslandMap.tscn",
	StageData.Concept.SEA: "res://stage/beach/BeachMap.tscn",
	StageData.Concept.SKY: "res://stage/sky/SkyIslandMap.tscn",
}

# 컨셉이 없거나(챕터 밖 스테이지) 아직 맵이 없는 컨셉일 때 놓을 맵.
#
# 전장을 비워 두지 않는 이유: 저작은 맵보다 먼저 될 수 있다. 맵이 없다고
# 검은 화면이 되면 "적이 안 나온다"처럼 보이고 원인이 드러나지 않는다.
# 물러날 때는 경고를 남긴다(아래 resolve_for_stage).
const FALLBACK_SCENE := "res://stage/grassland/GrasslandMap.tscn"

# 맵을 놓는 위치. 여태 stage/Stage1_1.tscn 의 GrasslandMap 인스턴스에 박혀 있던 값이다
# (position = (-240, -240)). 맵을 런타임에 놓게 되면서 그 값이 갈 곳이 필요해졌다.
#
# 지금은 맵 셋이 이 오프셋 하나를 공유한다. 맵마다 달라져야 하면 CONCEPT_SCENE 를
# 경로 하나에서 경로+오프셋으로 넓힌다 -- 그때까지 쓰이지 않을 필드를 미리 만들지 않는다.
const MAP_OFFSET := Vector2(-240, -240)


# 이 컨셉의 맵 씬 경로. 등록되지 않은 컨셉이면 빈 문자열.
# 물러남을 여기서 하지 않는 이유: "없다"와 "대신 이것"을 한 함수가 둘 다 하면
# 호출부가 맵이 실제로 저작됐는지 알 수 없다.
static func scene_path_for_concept(concept: int) -> String:
	return CONCEPT_SCENE.get(concept, "")


static func has_map_for_concept(concept: int) -> bool:
	return CONCEPT_SCENE.has(concept)


# 이 스테이지가 쓸 맵 씬 경로. 항상 놓을 수 있는 경로를 돌려준다.
#
# stage 가 null 이면(스테이지가 아직 정해지지 않은 진입) 기본 맵이다.
# 등록되지 않은 컨셉이면 기본 맵으로 물러나고 경고를 남긴다 -- 화면에 "바다"라고
# 적혀 있는데 초원이 나오는 것은 조용히 지나갈 일이 아니다.
static func resolve_for_stage(stage: StageData) -> String:
	if stage == null or not stage.has_chapter():
		return FALLBACK_SCENE

	var concept := stage.get_concept()
	if has_map_for_concept(concept):
		return scene_path_for_concept(concept)

	push_warning("StageMaps: '%s' 컨셉의 맵이 아직 없습니다(%s 로 대체): %s"
		% [stage.get_concept_name(), FALLBACK_SCENE.get_file(), String(stage.stage_id)])
	return FALLBACK_SCENE
