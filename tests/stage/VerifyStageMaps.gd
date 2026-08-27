extends Node

# 저작된 스테이지가 자기 컨셉의 전장 맵으로 풀리는지 검증 (#438).
#
# 왜 필요한가: 컨셉->맵 대응(StageMaps)과 맵 씬은 #420·#422·#423 에서 다 만들어졌는데,
# 그것을 쓰는 스테이지가 저작되지 않으면 맵은 게임에서 한 번도 인스턴스되지 않는다.
# 해변 맵이 실제로 그런 상태였다 — 대응표만 보면 연결된 것처럼 보인다.
#
# 그래서 대응표를 검사하지 않고 **저작된 스테이지에서 출발해** 맵까지 풀어 본다.
# 폴백으로 물러나는 경우도 함께 잡는다(화면에 "바다"라고 적혀 있는데 초원이 나오는 것).
#
# 파티 시작 자리는 Stage.spawn_party() 가 정한다(100, 100 + i*40). 스폰 거리를
# 여기서 검사하는 이유: 적이 detection_range 밖에 있으면 플레이어가 걸어가기 전까지
# 아무 일도 일어나지 않아 "적이 안 나온다"처럼 보인다.

const PARTY_START := Vector2(100, 140)  # 3인 파티의 가운데 자리

var _failures: Array[String] = []


func _ready() -> void:
	await get_tree().process_frame

	# 2챕터가 저작되었다 — 이 검사의 전제이자 #438 이 한 일이다.
	_expect(StageDatabase.get_authored_chapters() == [1, 2],
		"저작된 챕터는 [1, 2] 여야 한다: " + str(StageDatabase.get_authored_chapters()))
	_expect(StageDatabase.has_stage(&"stage_2_1"), "stage_2_1 이 로드되어야 한다")

	for id in StageDatabase.get_ordered_ids():
		_verify_stage(id)

	# 컨셉별 맵 씬이 실제로 존재하는지. 경로만 맞고 파일이 없으면 전장이 비어 열린다.
	for concept in StageMaps.CONCEPT_SCENE:
		var path: String = StageMaps.CONCEPT_SCENE[concept]
		_expect(ResourceLoader.exists(path),
			"%s 컨셉의 맵 씬이 없다: %s" % [StageData.concept_to_name(concept), path])

	if _failures.is_empty():
		print("PASS: 저작된 스테이지 %d개가 각자 컨셉의 전장 맵으로 풀린다"
			% StageDatabase.get_count())
		get_tree().quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		get_tree().quit(1)


func _verify_stage(id: StringName) -> void:
	var stage := StageDatabase.get_stage(id)
	if stage == null:
		_failures.append("스테이지를 조회할 수 없다: " + String(id))
		return

	_expect(stage.validate().is_empty(),
		"%s 가 유효하지 않다: %s" % [id, ", ".join(stage.validate())])

	var path := StageMaps.resolve_for_stage(stage)
	if stage.has_chapter():
		# 컨셉의 맵이 등록되어 있으면 폴백으로 물러나지 않아야 한다.
		var expected := StageMaps.scene_path_for_concept(stage.get_concept())
		_expect(not expected.is_empty(),
			"%s(%s) 컨셉의 맵이 등록되지 않았다" % [id, stage.get_concept_name()])
		_expect(path == expected,
			"%s(%s) 는 %s 로 풀려야 한다: %s" % [id, stage.get_concept_name(), expected, path])
	else:
		# 챕터 밖 스테이지는 컨셉이 없으므로 폴백이 정상이다.
		_expect(path == StageMaps.FALLBACK_SCENE,
			"챕터 밖 스테이지 %s 는 폴백 맵이어야 한다: %s" % [id, path])

	_verify_spawn_distance(stage)


# 시작하자마자 전투가 벌어지는가.
#
# **한 마리라도** 파티 시작 자리에서 자기 detection_range 안에 있으면 통과다.
# 전부를 요구하지 않는 이유: 뒷줄을 일부러 멀리 두는 배치가 있다(1-2 의 매머드는
# 621px 로 6px 밖이고, 점령 스테이지라 플레이어가 존으로 다가가는 것이 전제다).
# 반대로 **아무도** 범위 안에 없으면 진입 직후 화면에서 아무 일도 일어나지 않아
# "적이 안 나온다"처럼 보인다 — 그것이 잡고 싶은 저작 실수다.
#
# 사거리의 출처는 EnemyData 다 — 여기에 숫자를 적지 않고 씬에서 읽는다.
func _verify_spawn_distance(stage: StageData) -> void:
	if stage.spawns.is_empty():
		return  # 웨이브만 저작된 스테이지(stage_test)는 시작 배치가 없다.

	var nearest := INF
	var nearest_range := 0.0
	for spawn in stage.spawns:
		if spawn == null or spawn.enemy_scene == null:
			continue
		var probe := spawn.enemy_scene.instantiate()
		var data: EnemyData = probe.get("data")
		if data != null:
			for i in range(spawn.count):
				var distance := PARTY_START.distance_to(spawn.get_position(i))
				if distance < nearest:
					nearest = distance
					nearest_range = data.detection_range
		probe.free()

	_expect(nearest <= nearest_range,
		"%s: 가장 가까운 적조차 탐지 범위 밖이다 (%.0f > %.0f) — 진입 직후 아무 일도 일어나지 않는다"
			% [stage.stage_id, nearest, nearest_range])


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
