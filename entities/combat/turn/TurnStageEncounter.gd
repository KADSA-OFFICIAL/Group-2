extends Object
class_name TurnStageEncounter

# 저작된 스테이지를 **턴제 조우**로 번역한다 (#472).
#
# 실시간 전장은 `StageSpawn.enemy_scene`(PackedScene)을 좌표에 인스턴스한다. 턴제는 좌표가
# 없고 랭크만 있으므로, 씬 대신 **정의(`EnemyData`)**가 필요하다.
#
# 이 클래스가 그 번역을 맡는다. 전부 `static` 이라 노드 없이 호출되고, 그래서
# 헤드리스에서 "저작된 스테이지 전부가 적이 있는 조우로 풀리는가"를 직접 검사할 수 있다.
# (`TurnBattle` 안에 두었을 때는 씬을 띄우지 않고는 검증할 수 없었다.)
#
# 참고: docs/turn-combat-design.md §적


## 씬 경로 -> `EnemyData` 해석 결과 캐시. 같은 씬을 웨이브마다 다시 풀지 않는다.
##
## 값이 `null` 인 항목도 캐시한다 — 해석에 실패한 씬을 매번 다시 뒤지지 않게 하려는 것이다.
static var _cache: Dictionary = {}


# 적 씬이 들고 있는 `EnemyData` 를 꺼낸다. 없으면 null.
#
# 씬 경로 -> 적 id 매핑표를 만들지 않는 이유: 적 정의의 단일 출처는 `EnemyData` 이고,
# 실시간 적 씬의 루트(`EnemyBase`)가 이미 `data` 로 그것을 들고 있다. 매핑표를 두면
# 적을 추가할 때 고칠 곳이 두 군데가 되고, 한쪽을 빼먹으면 **조용히 다른 적이 나온다.**
#
# **씬을 인스턴스하지 않는다.** `SceneState` 로 저장된 프로퍼티만 읽는다 — 인스턴스는
# 스프라이트·애니메이션 리소스까지 끌고 오고, 트리에 넣지 않은 노드를 직접 해제해야 한다.
static func enemy_data_of(scene: PackedScene) -> EnemyData:
	if scene == null:
		return null

	var key := scene.resource_path
	if not key.is_empty() and _cache.has(key):
		return _cache[key]

	var data: EnemyData = null
	var state := scene.get_state()
	if state != null and state.get_node_count() > 0:
		for i in state.get_node_property_count(0):
			if state.get_node_property_name(0, i) != &"data":
				continue
			var value = state.get_node_property_value(0, i)
			if value is EnemyData:
				data = value
			break

	if not key.is_empty():
		_cache[key] = data
	return data


# 스폰 목록을 적 정의 목록으로 바꾼다.
#
# `StageSpawn.count` 를 그대로 펼친다 — 실시간에서 3마리가 나오는 자리면 턴제에서도
# 3마리다. 적 랭크가 5개뿐이므로 넘치는 분은 버린다.
static func enemies_from_spawns(spawns: Array[StageSpawn]) -> Array[EnemyData]:
	var out: Array[EnemyData] = []
	for spawn in spawns:
		if spawn == null:
			continue
		var data := enemy_data_of(spawn.enemy_scene)
		if data == null:
			if spawn.enemy_scene != null:
				push_warning("TurnStageEncounter: 적 씬에서 EnemyData 를 찾을 수 없습니다: "
					+ spawn.enemy_scene.resource_path)
			continue
		for _i in maxi(spawn.count, 1):
			if out.size() >= TurnCombat.ENEMY_RANK_COUNT:
				return out
			out.append(data)
	return out


# 스테이지의 웨이브들을 턴제 조우로 번역한다.
#
# 반환: `[{"wave": StageWave | null, "enemies": Array[EnemyData]}, ...]`
#       `wave` 가 null 인 원소는 웨이브가 저작되지 않아 `spawns` 를 한 무리로 본 것이다.
#
# 적이 하나도 없는 웨이브는 **버린다.** 빈 웨이브를 남기면 전투가 그 웨이브에서
# "적 전멸"로 판정해 즉시 다음으로 넘어가고, 화면에는 아무 일도 없이 웨이브 번호만 올라간다.
static func waves_for(stage: StageData) -> Array:
	var out: Array = []
	if stage == null:
		return out

	if not stage.waves.is_empty():
		for wave in stage.waves:
			if wave == null:
				continue
			var enemies := enemies_from_spawns(wave.spawns)
			if enemies.is_empty():
				continue
			out.append({"wave": wave, "enemies": enemies})
		return out

	# 웨이브가 저작되지 않은 스테이지는 `spawns` 전체를 한 웨이브로 본다.
	var single := enemies_from_spawns(stage.spawns)
	if not single.is_empty():
		out.append({"wave": null, "enemies": single})
	return out


# 기본 조우. 스테이지가 없거나 적을 뽑을 수 없을 때 쓴다.
#
# 잡몹 2 + 정예 1 — 설계서 §4.8.1 의 표준 구성이다. 빈 전투를 여는 것보다
# 무언가와 싸우는 편이 낫다(전투 화면을 단독 실행할 때도 이 경로를 탄다).
static func fallback_enemies(ids: Array[StringName] = []) -> Array[EnemyData]:
	var out: Array[EnemyData] = []
	var wanted := ids
	if wanted.is_empty():
		wanted = [&"velociraptor_beastfolk", &"velociraptor_beastfolk_2",
			&"mammoth_beastfolk"]

	var loop := Engine.get_main_loop()
	if not (loop is SceneTree):
		return out
	var database := (loop as SceneTree).root.get_node_or_null("EnemyDatabase")
	if database == null:
		return out

	for id in wanted:
		if out.size() >= TurnCombat.ENEMY_RANK_COUNT:
			break
		var enemy = database.call("get_enemy", id)
		if enemy is EnemyData:
			out.append(enemy)
	return out
