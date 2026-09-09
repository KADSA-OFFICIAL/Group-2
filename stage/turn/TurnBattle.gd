extends Node2D

# 턴제 전투 화면 (#450).
#
# 설계서 PART 5 의 **Phase 0 — 감각 검증**에 해당하는 화면이다.
#
# > 사각형 도형만으로 아군 2 vs 적 2 전투 / AV 타임라인 / 3버튼 / 공명 5핍 /
# > 인성치 + 자물쇠 + 격파 판정 / **약점 격파 연출 9단계 완성** ← 도형이어도 좋으니 이건 제대로
# >
# > Phase 0에서 격파 순간이 짜릿하지 않으면 전체 설계를 재검토하라.
# > 아트를 입혀도 재미가 생기지 않는다.
#
# 그래서 이 화면은 **도형과 트윈만 쓴다.** Spine 애니메이션·컷인 일러스트·패럴랙스
# 배경은 Phase 3의 일이고, 여기서 검증할 것은 로직과 **타격 감각**이다.
#
# 이 파일이 하는 일: 로직(`TurnBattleManager`)이 즉시 계산을 끝낸 뒤 쌓아 둔
# 연출 큐(`PresentationQueue`)를 순차 재생한다. 로직과 연출이 분리되어 있어서
# **배속이 재생 시간을 나누기만 하면 된다.**
#
# 실행: 이 씬을 F6으로 실행한다.
#
# 참고: docs/turn-combat-design.md §연출

## **저작된 스테이지를 읽어 전투를 만든다.** 껐을 때만 아래 `party_ids`/`enemy_ids` 를 쓴다.
##
## 켜면: `StageSystem` 의 현재 스테이지에서 웨이브별 적을 뽑고, `forced_party` 를 적용하고,
## 승패를 `EventBus.stage_completed` / `stage_failed` 로 알려 결과 화면·진행도와 이어진다.
## 즉 **출격 흐름이 그대로 턴제 전투로 이어진다** (#472).
@export var use_stage: bool = true

## 이 전투에 출전할 파티. 비우면 편성 파티 → 로스터 순으로 채운다.
@export var party_ids: Array[StringName] = []
## 이 전투의 적. `use_stage` 가 꺼져 있을 때만 쓴다. 비우면 기본 조우를 만든다.
@export var enemy_ids: Array[StringName] = []
## 결정론적 RNG 시드. 0이면 시간으로 정한다.
@export var battle_seed: int = 0
## 선공(1) / 일반(0) / 피습(-1).
@export var ambush: int = 0

# 전투 UI 가 올라가는 CanvasLayer 번호.
#
# 둘 다 `ScreenManager.SCREEN_LAYER`(10) 아래여야 한다 — 메타 화면이 전투 위에 얹히는
# 구조이므로, 이보다 위에 두면 로비 화면에 전투 UI 가 겹쳐 보인다.
# (`main_realtime.tscn` 의 HUD 1 / DebugOverlay 2 와 같은 자리다.)
const HUD_LAYER: int = 1
const FLASH_LAYER: int = 2

# ===== 오의 컷인 구도 (캐릭터 아트 가이드 §4.1) =====
#
# 가이드는 2400×1350 캔버스 기준이고 이 화면은 1280×720 이라 0.533 배로 환산했다.
## 아트 판의 좌단(캔버스 폭 비율). 좌측 40%는 타이포 영역이라 그림이 넘어오지 않게 둔다.
const CUTIN_ART_LEFT_RATIO: float = 0.406
## 아트 판이 화면 우단을 넘겨 나가는 폭. **잘려 나갈 여유 200px**(0.533 환산)이다.
const CUTIN_ART_BLEED: float = 108.0
## 슬라이드 인 거리. 이만큼 오른쪽에서 들어온다.
const CUTIN_SLIDE: float = 130.0
## 엠블럼 한 변. 가이드 §1 은 128px 라 하지만 **타이포 뒤 워터마크로 쓰므로 더 크게**
## 둔다. 128px 단색 도형을 글자 옆에 두면 엠블럼이 아니라 길 잃은 색 판으로 보였다.
const CUTIN_EMBLEM: float = 208.0
## 엠블럼 알파. 글자를 읽는 데 방해가 되지 않는 선.
const CUTIN_EMBLEM_ALPHA: float = 0.17

# ===== 무대 (Stage) =====
## 지면 밴드 높이. 아래에서 이만큼이 바닥이다.
const GROUND_H: float = 420.0
## 유닛 몸 칸. 발밑이 노드 원점이다 (`position = -box * (0.5, 1)`).
## 스프라이트를 저작할 때 이 비율을 맞춘다 — docs/turn-battle-sprite-prompts.md
const ALLY_BODY := Vector2(56.0, 84.0)
const ENEMY_BODY := Vector2(62.0, 78.0)
## 중앙 충돌선의 아래에서 잰 시작 높이.
const DIVIDER_FROM_BOTTOM: float = 540.0

var battle := TurnBattleManager.new()
var hud: TurnBattleHUD = null

## 유닛별 도형. `unit_id` -> Node2D.
var _shapes: Dictionary = {}
## 화면 전체를 덮는 플래시·암전 레이어.
var _flash: ColorRect = null
var _flash_layer: CanvasLayer = null
## 데미지 숫자를 띄우는 레이어.
var _numbers: Node2D = null
## 격파 타이포그래피.
var _banner: Label = null

## 오의 컷인 묶음. 아트·조명·엠블럼·타이포를 한 노드 아래 둬서 통째로 슬라이드시킨다.
var _cutin: Control = null
var _cutin_art: TextureRect = null
var _cutin_light: ColorRect = null
var _cutin_emblem: TextureRect = null
var _cutin_name: Label = null
var _cutin_skill: Label = null

## 연출을 재생 중인가. 재생 중에는 다음 턴으로 넘어가지 않는다.
var _playing: bool = false
## 일시정지 중인가. 진행 루프와 연출 재생이 여기서 멈춘다.
##
## `get_tree().paused` 를 쓰지 않는 이유: 그쪽은 트리 전체를 멈춰서 HUD 의 `_process`
## 와 입력까지 죽는다. 일시정지를 **풀 수 없는** 일시정지가 된다.
## (`ScreenManager` 가 메타 화면용으로 이미 그 스위치를 쓰고 있기도 하다.)
var _paused: bool = false
## 이 전투가 물고 있는 스테이지. `use_stage` 가 켜져 있을 때만 채워진다.
var _stage: StageData = null
## 스테이지의 웨이브 정의. 번호 -> `StageWave`. `stage_wave_started` 에 실어 보낸다.
var _waves: Array[StageWave] = []
## 승패를 이미 알렸는가. 결과 화면이 두 번 뜨는 것을 막는다.
var _outcome_reported: bool = false
## 캔버스 크기를 따라야 하는 배경 조각들. 창 비율이 16:9 가 아니면 캔버스가
## 1280×720 보다 커지므로 고정 크기로 두면 오른쪽에 덮이지 않은 띠가 남는다.
var _background: ColorRect = null
var _ground: ColorRect = null
var _divider: ColorRect = null

## 카메라 흔들림 상태.
var _shake_amount: float = 0.0
var _shake_time: float = 0.0
var _camera_home := Vector2.ZERO

var _camera: Camera2D = null


func _ready() -> void:
	name = "TurnBattle"
	_build_scene()

	# 출격(스테이지 선택 → 편성 → 출격)이 이 신호를 쏜다. 실시간 `Stage1_1` 과 같은 규약이라
	# 출격 화면은 어느 전장이 떠 있는지 몰라도 된다.
	if use_stage:
		StageSystem.stage_requested.connect(_on_stage_requested)

	_start_battle()


# 다른 스테이지로 출격했다. 전투를 그 스테이지로 다시 만든다.
func _on_stage_requested(_stage_id: StringName) -> void:
	_restart()


# 전투를 처음부터 다시 만든다. 도형과 연출 잔여물을 치우고 새로 시작한다.
func _restart() -> void:
	for child in _numbers.get_children():
		child.queue_free()
	for id in _shapes:
		var shape: Node2D = _shapes[id]
		if shape != null:
			shape.queue_free()
	_shapes.clear()

	var stale := _flash_layer.get_node_or_null("ResultSummary")
	if stale != null:
		stale.queue_free()

	battle = TurnBattleManager.new()
	_outcome_reported = false
	_start_battle()


func _tuning() -> TurnCombatTuning:
	return TurnCombatConfig.tuning


# ===== 화면 구성 (Scene) =====

func _build_scene() -> void:
	# 배경 — Phase 0이므로 단색 + 지면선만 둔다. 패럴랙스 5레이어는 Phase 3다.
	#
	# 크기는 `_fit_backdrop()` 이 캔버스에 맞춘다. 1280×720 으로 고정해 뒀더니
	# 1366×720 캔버스(1920×1012 창)에서 **오른쪽 86px 에 창 배경색 띠가 그대로 보였다.**
	_background = ColorRect.new()
	_background.color = TurnCombat.COLOR_BACKDROP
	_background.z_index = -100
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_background)

	_ground = ColorRect.new()
	_ground.color = TurnCombat.COLOR_STAGE_FLOOR
	_ground.z_index = -99
	_ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ground)

	# 중앙 충돌선 — 아군과 적을 가르는 기준선. 캔버스 가로 중심에 선다.
	var divider := ColorRect.new()
	divider.color = Color(1, 1, 1, 0.05)
	divider.size = Vector2(2, 380)
	_divider = divider
	divider.z_index = -98
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(divider)

	_camera = Camera2D.new()
	add_child(_camera)

	_numbers = Node2D.new()
	_numbers.z_index = 50
	add_child(_numbers)

	# HUD (CanvasLayer 위에 둬야 카메라 흔들림에 함께 흔들리지 않는다).
	#
	# 레이어 번호는 `ScreenManager.SCREEN_LAYER`(10) 보다 **낮아야 한다.** 메타 화면
	# (메인화면/편성/결과)은 게임플레이 위에 얹히는 오버레이라, 전투 HUD 가 그 위로
	# 올라오면 로비에 전투 UI 가 그대로 겹쳐 보인다.
	#
	# 같은 번호(10)로 두는 것도 안 된다. 번호가 같으면 트리 순서가 앞뒤를 정하고,
	# ScreenManager 는 autoload 라 메인 씬보다 **먼저** 붙으므로 전투 HUD 가 위로 온다.
	# 실제로 그렇게 겹쳐 보였다.
	var hud_layer := CanvasLayer.new()
	hud_layer.layer = HUD_LAYER
	add_child(hud_layer)

	hud = TurnBattleHUD.new()
	hud_layer.add_child(hud)
	hud.action_chosen.connect(_on_action_chosen)
	hud.ultimate_requested.connect(_on_ultimate_requested)
	hud.speed_changed.connect(_on_speed_changed)
	hud.pause_toggled.connect(_on_pause_toggled)
	hud.auto_toggled.connect(_on_auto_toggled)

	# 플래시 / 암전 레이어는 HUD 위에 온다 — 격파 순간에는 UI까지 덮어야 한다.
	# 단 메타 화면보다는 아래다(위 HUD 주석과 같은 이유).
	_flash_layer = CanvasLayer.new()
	_flash_layer.layer = FLASH_LAYER
	add_child(_flash_layer)

	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash_layer.add_child(_flash)

	_banner = Label.new()
	_banner.text = ""
	_banner.modulate = Color(1, 1, 1, 0)
	_banner.position = Vector2(300, 300)
	_banner.add_theme_font_size_override("font_size", 84)
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash_layer.add_child(_banner)

	_build_cutin()

	# 캔버스 크기에 맞춘다. 창 비율이 바뀌면 다시 맞춘다 — 배경·지면·중앙선·카메라와
	# 유닛 도형이 모두 캔버스 크기에서 나온 좌표를 쓴다.
	get_viewport().size_changed.connect(_on_canvas_resized)
	_fit_backdrop()


# 배경·지면·중앙선·카메라를 현재 캔버스에 맞춘다.
#
# 지면선은 **아래에서 420** 이고, 이 값이 `TurnBattleHUD` 의 줄 높이
# (`ENEMY_ROW_FROM_BOTTOM` / `ALLY_ROW_FROM_BOTTOM`)와 같은 기준을 쓴다.
func _fit_backdrop() -> void:
	var canvas: Vector2 = get_viewport_rect().size
	if _background != null:
		_background.size = canvas
	if _ground != null:
		_ground.position = Vector2(0.0, canvas.y - GROUND_H)
		_ground.size = Vector2(canvas.x, GROUND_H)
	if _divider != null:
		_divider.position = Vector2(canvas.x * 0.5 - 1.0, canvas.y - DIVIDER_FROM_BOTTOM)
	if _camera != null:
		_camera.position = canvas * 0.5
		_camera_home = _camera.position
	if _flash != null:
		_flash.size = canvas
	if _cutin_light != null:
		_cutin_light.size = canvas
	if _cutin_art != null:
		# 아트 판의 좌단은 캔버스 좌측 40%(타이포 영역) 밖이고, 우단은 화면 밖까지 나간다.
		_cutin_art.position = Vector2(canvas.x * CUTIN_ART_LEFT_RATIO, 0.0)
		_cutin_art.size = Vector2(canvas.x - _cutin_art.position.x + CUTIN_ART_BLEED, canvas.y)


func _on_canvas_resized() -> void:
	_fit_backdrop()
	# 도형 좌표는 HUD 가 캔버스 크기에서 계산한다. 다시 놓지 않으면 UI 만 옮겨간다.
	if hud != null and not _shapes.is_empty():
		_sync_shapes()


# 오의 컷인 판. 한 번 만들어 두고 재생할 때마다 그림과 글자만 갈아 끼운다.
#
# 구도는 캐릭터 아트 가이드 §4.1 규격(2400×1350 기준)을 1280×720 으로 환산한 것이다.
#   · 좌측 40%(x 0~512) — 타이포그래피 영역. **그림을 넣지 않는다**
#   · 캐릭터 55~65%     — 우측에 대각선으로 서고, 화면 밖으로 잘려 나가도 된다
#
# **조명을 그림에 굽지 않는다** (§4.2). 원소색 조명은 여기서 `_cutin_light` 로 합성한다.
# 그림은 중립 조명으로 그려진 투명 PNG 이므로, 속성이 바뀌어도 다시 그릴 필요가 없다.
func _build_cutin() -> void:
	_cutin = Control.new()
	_cutin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cutin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cutin.modulate = Color(1, 1, 1, 0)
	_cutin.visible = false
	_flash_layer.add_child(_cutin)

	# 원소색 조명 판. 그림 뒤에 깔려 인물을 어두운 배경에서 떼어 낸다.
	_cutin_light = ColorRect.new()
	_cutin_light.color = Color(0, 0, 0, 0)
	_cutin_light.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cutin.add_child(_cutin_light)

	# 엠블럼 — 벡터 단색 실루엣. 타이포 뒤에 크게 얹는다.
	_cutin_emblem = TextureRect.new()
	_cutin_emblem.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_cutin_emblem.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_cutin_emblem.size = Vector2(CUTIN_EMBLEM, CUTIN_EMBLEM)
	# 타이포그래피 묶음(y 300~400)의 뒤 가운데. 글자가 엠블럼 위에 얹힌다.
	_cutin_emblem.position = Vector2(88, 244)
	_cutin_emblem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cutin.add_child(_cutin_emblem)

	# 전신 아트. 우측에 두고 잘려 나갈 여유를 위해 화면 오른쪽 밖까지 폭을 준다.
	_cutin_art = TextureRect.new()
	_cutin_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_cutin_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_cutin_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cutin.add_child(_cutin_art)

	# 타이포그래피 — 캐릭터 이름과 오의 이름. 설계서 §4.10.4 의 -9° 기울기를 쓴다.
	_cutin_name = Label.new()
	_cutin_name.add_theme_font_size_override("font_size", 30)
	_cutin_name.position = Vector2(104, 300)
	_cutin_name.rotation = deg_to_rad(-9.0)
	_cutin_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cutin.add_child(_cutin_name)

	_cutin_skill = Label.new()
	_cutin_skill.add_theme_font_size_override("font_size", 62)
	_cutin_skill.position = Vector2(96, 336)
	_cutin_skill.rotation = deg_to_rad(-9.0)
	_cutin_skill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cutin.add_child(_cutin_skill)


# ===== 전투 개시 (Start) =====

func _start_battle() -> void:
	_stage = StageSystem.get_current_stage() if use_stage else null
	_waves.clear()

	# 강제 파티는 파티를 뽑기 **전에** 적용해야 한다 — `PartySystem` 에서 읽어 오므로
	# 순서가 뒤집히면 강제 편성이 다음 전투에나 반영된다.
	if _stage != null and not _stage.forced_party.is_empty():
		PartySystem.set_party(_stage.forced_party)

	var party := _resolve_party()
	var waves := _resolve_waves()

	if party.is_empty() or waves.is_empty():
		push_error("TurnBattle: 파티나 적을 구성할 수 없습니다.")
		return

	var use_seed := battle_seed
	if use_seed == 0:
		use_seed = int(Time.get_unix_time_from_system())

	# 첫 웨이브로 시작하고 나머지는 전투에 맡긴다. 아군 상태는 웨이브 사이에 이어진다.
	battle.pending_waves = waves.slice(1)
	battle.on_wave_started = _on_wave_started
	battle.start(party, waves[0], ambush, use_seed)
	hud.battle = battle

	_build_shapes()

	# 준비 페이즈는 아직 화면이 없다 — 기본 준비(오의 게이지 50%)만 쓰고 넘어간다.
	# 준비 페이즈 UI는 별도 이슈다(Non-goals).
	battle.use_prep("energy")
	battle.begin_battle()

	_play()


func _resolve_party() -> Array[CharacterData]:
	var out: Array[CharacterData] = []

	var ids := party_ids
	if ids.is_empty():
		# `PartySystem` 이 편성한 파티를 우선 쓴다 — 편성이 전투에 이어지는 것이 정상이다.
		for member in PartySystem.get_members():
			if member is CharacterData and member.is_turn_ready():
				out.append(member)
		if out.size() >= 1:
			# 턴제는 4인이므로 부족하면 로스터에서 채운다.
			for id in CharacterDatabase.get_playable_ids():
				if out.size() >= TurnCombat.ALLY_RANK_COUNT:
					break
				var extra: CharacterData = CharacterDatabase.get_character(id)
				if extra != null and extra.is_turn_ready() and not out.has(extra):
					out.append(extra)
			return out
		ids = []
		for id in CharacterDatabase.get_playable_ids():
			ids.append(id)

	for id in ids:
		if out.size() >= TurnCombat.ALLY_RANK_COUNT:
			break
		var character: CharacterData = CharacterDatabase.get_character(id)
		if character != null and character.is_turn_ready():
			out.append(character)
	return out


# 이 전투의 웨이브들. 각 원소가 그 웨이브의 적 목록이다.
#
# 번역은 `TurnStageEncounter` 가 한다 — 노드 없이 호출되므로 헤드리스에서 직접 검증된다.
# 반환 타입이 `Array[Array[EnemyData]]` 가 아닌 이유: GDScript 는 중첩 타입 배열을 지원하지 않는다.
func _resolve_waves() -> Array:
	var out: Array = []

	if _stage != null:
		for entry in TurnStageEncounter.waves_for(_stage):
			out.append(entry["enemies"])
			_waves.append(entry["wave"])
		if not out.is_empty():
			return out
		push_warning("TurnBattle: 스테이지 %s 에서 적을 뽑을 수 없어 기본 조우로 대체합니다."
			% _stage.stage_id)

	var fallback := TurnStageEncounter.fallback_enemies(enemy_ids)
	if fallback.is_empty():
		return out
	_waves.append(null)
	return [fallback]


# 웨이브가 놓였다. 스테이지 도메인의 신호로 옮겨 쏜다.
#
# 전투는 `StageWave` 를 모르고 번호만 알린다 — 그 경계를 지켜야 전투를 스테이지 없이도
# 굴릴 수 있다(헤드리스 테스트와 `use_stage = false` 가 그렇게 쓴다).
func _on_wave_started(index: int, total: int) -> void:
	if _stage == null:
		return
	var wave: StageWave = _waves[index] if index < _waves.size() else null
	EventBus.stage_wave_started.emit(String(_stage.stage_id), index, total, wave)


# 유닛마다 몸을 하나 만든다.
#
# `battle_sprite` 가 저작되어 있으면 그 그림을 세우고, 없으면 `tint` 색 네모를 세운다
# (Phase 0 플레이스홀더). **아트가 들어와도 스크립트를 고칠 필요가 없다** —
# `.tres` 에 텍스처만 넣으면 네모가 그림으로 바뀐다.
# 생성 프롬프트: docs/turn-battle-sprite-prompts.md
func _build_shapes() -> void:
	for unit in battle.units:
		var shape := Node2D.new()
		shape.z_index = 10

		var box := ALLY_BODY if unit.is_ally() else ENEMY_BODY
		var art := _battle_sprite_of(unit)
		if art != null:
			# 늘리지 않는다 — 비율이 다른 그림은 칸 안에서 맞춰 들어간다.
			var picture := TextureRect.new()
			picture.texture = art
			picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			picture.size = box
			picture.position = -box * Vector2(0.5, 1.0)
			picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
			shape.add_child(picture)
		else:
			var body := ColorRect.new()
			var tint := Color("C8402F")
			if unit.is_ally() and unit.character != null:
				tint = unit.character.tint
			elif unit.enemy != null:
				tint = unit.enemy.tint
			body.color = tint
			body.size = box
			body.position = -box * Vector2(0.5, 1.0)
			body.mouse_filter = Control.MOUSE_FILTER_IGNORE
			shape.add_child(body)

		# 접지 그림자 — 없으면 캐릭터가 떠 보인다 (설계서 §4.10.2).
		var shadow := ColorRect.new()
		shadow.color = Color(0, 0, 0, 0.32)
		shadow.size = Vector2(60, 12)
		shadow.position = Vector2(-30, -6)
		shadow.z_index = -1
		shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		shape.add_child(shadow)

		# 원소 문양 — 색맹 대응으로 색과 형태를 함께 쓴다.
		var glyph := Label.new()
		glyph.text = TurnCombat.element_glyph(unit.element)
		glyph.add_theme_font_size_override("font_size", 22)
		glyph.modulate = TurnCombat.element_color(unit.element)
		glyph.position = Vector2(-10, -112)
		glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
		shape.add_child(glyph)

		add_child(shape)
		_shapes[unit.unit_id] = shape

	_sync_shapes()


# 이 유닛의 턴제 전투 정지 스프라이트. 저작되지 않았으면 null (네모로 떨어진다).
func _battle_sprite_of(unit: TurnUnit) -> Texture2D:
	if unit.character != null:
		return unit.character.battle_sprite
	if unit.enemy != null:
		return unit.enemy.battle_sprite
	return null


# 도형을 랭크 위치로 옮긴다. 밀치기·끌기가 실제로 눈에 보여야 위치 전술이 성립한다.
func _sync_shapes(animated: bool = false) -> void:
	for unit in battle.units:
		var shape: Node2D = _shapes.get(unit.unit_id)
		if shape == null:
			continue
		if not unit.alive:
			shape.visible = false
			continue

		var target := hud.unit_position(unit)
		if animated and not shape.position.is_equal_approx(target):
			var tween := create_tween()
			tween.tween_property(shape, "position", target, _scaled(0.25)) \
				.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		else:
			shape.position = target

		# 격파 상태는 도형을 기울여 비틀거림을 표현한다.
		shape.rotation = deg_to_rad(9.0) if unit.is_broken else 0.0
		# 행동 중인 유닛을 살짝 키운다 (턴 대기 강조).
		shape.scale = Vector2(1.08, 1.08) if unit == battle.active_unit else Vector2.ONE


# ===== 진행 (Drive) =====

# 전투를 진행하고 연출을 재생한다.
#
# 로직은 이미 끝나 있다 — 여기서는 큐를 비우고, 아군 차례가 오면 입력을 기다린다.
func _play() -> void:
	if _playing:
		return
	_playing = true

	while true:
		await _await_unpause()
		await _drain_presentation()
		_sync_shapes(true)
		hud.refresh()

		if battle.is_over():
			await _show_result()
			break

		if battle.phase == TurnBattleManager.Phase.AWAITING_INPUT:
			break  # 입력 대기 — 제한시간 없음.

		if battle.phase == TurnBattleManager.Phase.TURN_START \
				or battle.phase == TurnBattleManager.Phase.TURN_END:
			battle.advance()
			continue

		break

	_playing = false


# 연출 큐를 순차 재생한다.
#
# **배속은 여기서만 적용된다.** 로직은 배속을 모른다.
func _drain_presentation() -> void:
	var queue := battle.presentation
	if queue == null:
		return

	while not queue.is_empty():
		await _await_unpause()
		var entry := queue.pop()
		var event: int = entry["event"]
		var data: Dictionary = entry["data"]

		match event:
			PresentationQueue.Event.SKILL_CAST:
				await _play_cast(data)

			PresentationQueue.Event.HIT:
				await _play_hit(data)

			PresentationQueue.Event.LOCK_CLEARED:
				await _play_lock(data)

			PresentationQueue.Event.NULLIFIED:
				await _play_nullified(data)

			PresentationQueue.Event.BREAK:
				await _play_break(data)

			PresentationQueue.Event.ULTIMATE_CUTIN:
				await _play_cutin(data)

			PresentationQueue.Event.DEATH:
				await _play_death(data)

			PresentationQueue.Event.CYCLE_START:
				await _play_banner("%d CYCLE" % int(data.get("cycle", 1)),
					TurnCombat.COLOR_TOUGHNESS, 0.35, 44)

			_:
				pass

		hud.refresh()


func _play_cast(data: Dictionary) -> void:
	var unit: TurnUnit = data.get("unit")
	var shape: Node2D = _shapes.get(unit.unit_id) if unit != null else null
	if shape == null:
		return

	# 시전자가 앞으로 살짝 나갔다 돌아온다. 3D 모션의 2D 대체다.
	var direction := 1.0 if unit.is_ally() else -1.0
	var home := shape.position
	var tween := create_tween()
	tween.tween_property(shape, "position", home + Vector2(direction * 26.0, 0),
		_scaled(0.10)).set_ease(Tween.EASE_OUT)
	tween.tween_property(shape, "position", home, _scaled(0.14)).set_ease(Tween.EASE_IN)
	await tween.finished


# 타격 피드백. 규격표(§4.10.5)의 수치를 그대로 쓴다.
func _play_hit(data: Dictionary) -> void:
	var ctx: DamageContext = data.get("context")
	if ctx == null:
		return

	var feedback: Dictionary = data.get("feedback", {})
	var style: Dictionary = data.get("number", {})
	var target_shape: Node2D = _shapes.get(ctx.target.unit_id)

	# 히트스톱 — 인간의 지각에서 "묵직함"의 90%가 여기서 나온다.
	await _hitstop(int(feedback.get("hitstop_frames", 2)))

	# 넉백 — 방향성 있는 흔들림이 무작위보다 훨씬 좋다.
	if target_shape != null:
		var knock := float(feedback.get("knockback_px", 0.0))
		var direction := -1.0 if ctx.target.is_ally() else 1.0
		var home := target_shape.position
		var tween := create_tween()
		tween.tween_property(target_shape, "position",
			home + Vector2(direction * knock, 0), _scaled(0.06))
		tween.tween_property(target_shape, "position", home, _scaled(0.12))
		# 피격 명멸.
		# 피격 명멸. 네모는 `color`, 그림은 `modulate` 를 흔든다 — 그림의 `color` 를
		# 흰색으로 만들면 그림이 사라진다.
		var body := target_shape.get_child(0)
		var flash_tween := create_tween()
		if body is ColorRect:
			var original: Color = (body as ColorRect).color
			flash_tween.tween_property(body, "color", Color.WHITE, _scaled(0.04))
			flash_tween.tween_property(body, "color", original, _scaled(0.12))
		elif body is CanvasItem:
			flash_tween.tween_property(body, "modulate", Color(3.0, 3.0, 3.0, 1.0),
				_scaled(0.04))
			flash_tween.tween_property(body, "modulate", Color.WHITE, _scaled(0.12))

	_shake(float(feedback.get("shake_px", 0.0)), float(feedback.get("shake_time", 0.0)))
	_screen_flash(Color.WHITE, float(feedback.get("flash", 0.0)), 0.12)
	_spawn_number(ctx, style)

	await _wait(0.10)


func _play_lock(data: Dictionary) -> void:
	var unit: TurnUnit = data.get("unit")
	var lock: TurnLock = data.get("lock")
	if unit == null or lock == null:
		return

	var feedback: Dictionary = data.get("feedback", {})
	await _hitstop(int(feedback.get("hitstop_frames", 3)))
	_shake(float(feedback.get("shake_px", 3.0)), float(feedback.get("shake_time", 0.1)))
	_screen_flash(lock.color(), float(feedback.get("flash", 0.15)), 0.10)

	# 해제된 자물쇠 문양이 위로 튀어오르며 사라진다.
	# 음정(`data["pitch"]`)은 사운드가 붙을 때 그대로 쓴다 — 상승 음계 설계다.
	var label := Label.new()
	label.text = lock.glyph()
	label.modulate = lock.color()
	label.add_theme_font_size_override("font_size", 30)
	label.position = hud.unit_position(unit) + Vector2(-8, -120)
	label.z_index = 60
	_numbers.add_child(label)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position",
		label.position + Vector2(0, -40), _scaled(0.5))
	tween.tween_property(label, "modulate:a", 0.0, _scaled(0.5))
	tween.chain().tween_callback(label.queue_free)

	await _wait(0.08)


func _play_nullified(data: Dictionary) -> void:
	var unit: TurnUnit = data.get("unit")
	if unit == null:
		return
	# 적 행동이 무산됐다 — 자물쇠를 전부 열었다. 가장 통쾌한 순간이므로 크게 알린다.
	await _play_banner("NULLIFIED", TurnCombat.COLOR_ULT_READY, 0.5, 58)


# ===== 약점 격파 9단계 (설계서 §4.10.7) =====
#
# **이 9단계가 게임의 첫인상을 결정한다.**
# 단계 목록은 `PresentationQueue.break_steps()`가 데이터로 돌려주고, 여기서는 재생만 한다 —
# 단계를 늘릴 때 재생기를 고치지 않아도 되게 하려는 것이다.
func _play_break(data: Dictionary) -> void:
	var unit: TurnUnit = data.get("unit")
	var color: Color = data.get("color", Color.WHITE)
	var ctx: DamageContext = data.get("context")
	var steps: Array = data.get("steps", [])
	var shape: Node2D = _shapes.get(unit.unit_id) if unit != null else null

	for step in steps:
		var index := int(step.get("step", 0))
		var duration := float(step.get("duration", 0.0))

		match index:
			1:
				pass  # 감지 — 즉시.

			2:
				# 전 게임 정지 12프레임.
				await _hitstop(12)

			3:
				# 인성치 바 파열 + 유리 파편.
				_shake(20.0, 0.45)
				_spawn_shards(unit, color)
				await _wait(duration)

			4:
				# 시간 감속 0.25초 @ 0.15배속.
				Engine.time_scale = float(step.get("time_scale", 0.15))
				await _wait_real(duration)
				Engine.time_scale = 1.0

			5:
				# 화면 전체 원소 색 플래시 70% -> 0%.
				_screen_flash(color, 0.70, duration)
				await _wait(duration * 0.5)

			6:
				# 원소별 전용 대형 이펙트. Phase 0은 도형 파티클로 대체한다.
				_spawn_element_burst(unit, color)
				await _wait(duration * 0.5)

			7:
				# "BREAK!" 타이포그래피가 화면을 가로지른다.
				await _play_banner("BREAK!", color, duration, 96)

			8:
				# 적 비틀거림 + 붉은 실루엣 명멸.
				if shape != null:
					var tween := create_tween()
					tween.tween_property(shape, "rotation", deg_to_rad(14.0), _scaled(0.12))
					tween.tween_property(shape, "rotation", deg_to_rad(6.0), _scaled(0.12))
					tween.tween_property(shape, "rotation", deg_to_rad(9.0), _scaled(0.10))
				await _wait(duration * 0.5)

			9:
				# 격파 데미지 대형 숫자 + 상태이상 아이콘 부착.
				if ctx != null:
					var style := battle.presentation.number_style_for(ctx)
					_spawn_number(ctx, style)
				_spawn_status_badge(unit, int(data.get("status", 0)), color)
				await _wait(duration * 0.4)

	hud.refresh()


func _play_cutin(data: Dictionary) -> void:
	var unit: TurnUnit = data.get("unit")
	var skill: SkillData = data.get("skill")
	if unit == null or skill == null:
		return

	var color := TurnCombat.element_color(unit.element)

	# 0.00s 암전.
	_screen_flash(Color.BLACK, 0.9, 0.08)
	await _wait(0.08)

	# 0.08s 스피드라인 — Phase 0은 색 띠로 대체한다.
	_screen_flash(color, 0.45, 0.12)

	# 0.45s 컷인. 아트가 있으면 전신 일러스트 + 엠블럼 + 타이포, 없으면 예전 배너로 떨어진다.
	# **타이밍은 어느 쪽이든 같다** — 0.55s 를 쓴다.
	if _setup_cutin(unit, skill, color):
		# 컷인은 화면을 통째로 쓰는 순간이다. HUD 를 남겨 두면 초상 카드와 스킬 목록이
		# 일러스트 위에 겹쳐 컷인이 "그림이 뜬 전투 화면"으로 보인다.
		_fade_hud(0.0, 0.18)
		await _play_cutin_slide(0.55)
	else:
		await _play_banner("%s / %s" % [unit.display_name, skill.display_name],
			color, 0.55, 52)

	# 1.10s 오의 모션 — 시전자를 크게 키웠다 되돌린다.
	var shape: Node2D = _shapes.get(unit.unit_id)
	if shape != null:
		var tween := create_tween()
		tween.tween_property(shape, "scale", Vector2(1.35, 1.35), _scaled(0.18)) \
			.set_ease(Tween.EASE_OUT)
		tween.tween_property(shape, "scale", Vector2.ONE, _scaled(0.22))
	_camera_zoom(1.6, 0.25)
	await _wait(0.25)
	_camera_zoom(1.0, 0.25)
	_hide_cutin(0.25)
	_fade_hud(1.0, 0.25)


# 컷인에 이 오의의 그림·색·글자를 채운다. 쓸 아트가 없으면 false.
func _setup_cutin(unit: TurnUnit, skill: SkillData, color: Color) -> bool:
	if _cutin == null or unit.character == null:
		return false

	# 어떤 그림을 쓸지는 PortraitSystem 이 정한다. 여기서 character.portrait 를 직접
	# 읽으면 편성 화면에서 고른 초상과 컷인이 어긋난다.
	var art := PortraitSystem.get_portrait(unit.character)
	if art == null:
		return false
	# 투명 여백을 잘라 낸 판을 쓴다. 여백째로 넣으면 인물이 화면에서 작아진다.
	_cutin_art.texture = HUDKit.trimmed_texture(art)

	# 원소색 조명을 **코드로** 합성한다. 그림에는 구워 넣지 않는다 (가이드 §4.2).
	_cutin_light.color = Color(color.r, color.g, color.b, 0.16)

	var emblem_path := UITheme.role_emblem_path(unit.character.role)
	_cutin_emblem.texture = load(emblem_path) if not emblem_path.is_empty() else null
	# 단색 실루엣이므로 색은 여기서 입힌다. 흰 도형에 곱해야 원소색 그대로 나온다.
	_cutin_emblem.modulate = Color(color.r, color.g, color.b, CUTIN_EMBLEM_ALPHA)

	_cutin_name.text = unit.display_name
	_cutin_name.modulate = TurnCombat.COLOR_TEXT_DIM
	_cutin_skill.text = skill.display_name
	_cutin_skill.modulate = color
	return true


# 컷인을 오른쪽에서 밀어 넣는다. 글자와 그림이 같은 시간에 자리를 잡는다.
func _play_cutin_slide(duration: float) -> void:
	_cutin.visible = true
	_cutin.modulate = Color(1, 1, 1, 0)
	var home := _cutin_art.position
	_cutin_art.position = home + Vector2(CUTIN_SLIDE, 0.0)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_cutin, "modulate:a", 1.0, _scaled(duration * 0.28))
	tween.tween_property(_cutin_art, "position", home,
		_scaled(duration)).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	await _wait(duration)


# HUD 를 부드럽게 내리거나 올린다. 노드를 숨기지 않고 알파만 건드린다 —
# `visible` 을 끄면 `_draw()` 가 멈춰 히트존이 비고, 컷인이 끝난 첫 프레임에 클릭이 샌다.
func _fade_hud(target_alpha: float, duration: float) -> void:
	if hud == null:
		return
	var tween := create_tween()
	tween.tween_property(hud, "modulate:a", target_alpha, _scaled(duration))


func _hide_cutin(duration: float) -> void:
	if _cutin == null or not _cutin.visible:
		return
	var tween := create_tween()
	tween.tween_property(_cutin, "modulate:a", 0.0, _scaled(duration))
	await tween.finished
	_cutin.visible = false


func _play_death(data: Dictionary) -> void:
	var unit: TurnUnit = data.get("unit")
	var shape: Node2D = _shapes.get(unit.unit_id) if unit != null else null
	if shape == null:
		return

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(shape, "modulate:a", 0.0, _scaled(0.35))
	tween.tween_property(shape, "rotation", deg_to_rad(-70.0), _scaled(0.35))
	await tween.finished
	shape.visible = false


func _show_result() -> void:
	var summary := battle.result_summary()
	var victory := bool(summary["victory"])

	# **승패를 스테이지 도메인으로 알린다.** 이 신호로 결과 화면(`stage_result_launcher`)과
	# 진행도·보상(`StageProgress`)이 굴러간다 — 실시간 `Stage1_1` 과 같은 규약이라
	# 그 두 시스템은 어느 전장이 떠 있었는지 몰라도 된다.
	#
	# `stage_started` 는 **쏘지 않는다.** 그 신호로 `TutorialSystem` 이 활성화되는데,
	# 저작된 튜토리얼 단계의 진행 조건이 대시·처형 같은 **실시간 행동**이라 턴제에서는
	# 영원히 충족되지 않고 진행 불가로 멈춘다 (#472 Consequences 1).
	if _stage != null and not _outcome_reported:
		_outcome_reported = true
		var stage_name := String(_stage.stage_id)
		if victory:
			EventBus.stage_completed.emit(stage_name)
		else:
			EventBus.stage_failed.emit(stage_name)

	await _play_banner("VICTORY" if victory else "DEFEAT",
		TurnCombat.COLOR_ULT_READY if victory else TurnCombat.COLOR_DANGER, 1.2, 88)

	# 전투 결과 요약 — 캐릭터별 딜량 / 격파 횟수 / 사이클 수 (설계서 §11.4).
	var lines: Array[String] = []
	lines.append("%d/%d 웨이브  ·  %d 사이클  ·  %d턴  ·  격파 %d회  ·  자물쇠 %d개 해제  ·  무산 %d회"
		% [int(summary["waves"]), int(summary["wave_total"]),
			int(summary["cycles"]), int(summary["turns"]), int(summary["breaks"]),
			int(summary["locks_cleared"]), int(summary["nullified"])])
	var damage: Dictionary = summary["damage"]
	for name_key in damage:
		lines.append("%s  %d" % [name_key, int(damage[name_key])])

	var panel := Label.new()
	panel.name = "ResultSummary"
	panel.text = "\n".join(lines)
	panel.add_theme_font_size_override("font_size", 20)
	var canvas: Vector2 = get_viewport_rect().size
	panel.position = Vector2(canvas.x * 0.5 - 220.0, canvas.y * 0.5 - 110.0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash_layer.add_child(panel)

	print("[TurnBattle] " + "\n".join(lines))


# ===== 입력 (Input) =====

func _on_action_chosen(skill: SkillData, target: TurnUnit) -> void:
	if battle.phase != TurnBattleManager.Phase.AWAITING_INPUT:
		return
	var result := battle.act(skill, target)
	if not bool(result["ok"]):
		print("[TurnBattle] 행동 실패: %s" % result["reason"])
		hud.refresh()
		return
	_play()


func _on_ultimate_requested(unit: TurnUnit) -> void:
	# **오의는 턴 순서와 무관하게 언제든 발동한다.** 입력 대기 중이 아니어도 받는다.
	var result := battle.use_ultimate(unit)
	if not bool(result["ok"]):
		print("[TurnBattle] 오의 실패: %s" % result["reason"])
		return
	_play()


func _on_speed_changed(new_speed: float) -> void:
	# **로직을 건드리지 않는다.** 연출 큐의 재생 시간만 나눈다.
	if battle.presentation != null:
		battle.presentation.speed = new_speed


# 일시정지가 풀릴 때까지 붙잡는다.
#
# 연출 한 조각이 끝난 **경계**에서만 멈춘다. 트윈 도중에 끊으면 캐릭터가 어중간한
# 위치에 남고, 재개 시 그 트윈이 이미 끝나 있어 연출이 한 칸 건너뛴다.
func _await_unpause() -> void:
	while _paused:
		await get_tree().process_frame


func _on_pause_toggled(enabled: bool) -> void:
	_paused = enabled
	if not enabled:
		# 멈춘 사이에 턴이 넘어가 있을 수 있다. 루프가 이미 돌고 있으면 `_play()` 가
		# 스스로 빠져나오므로 중복 실행되지 않는다.
		_play()


func _on_auto_toggled(enabled: bool) -> void:
	battle.auto_battle = enabled
	if enabled and battle.phase == TurnBattleManager.Phase.AWAITING_INPUT:
		# 자동으로 켜면 대기 중인 턴부터 바로 굴린다.
		battle.advance()
		_play()


# ===== 연출 원시 함수 (Primitives) =====

# 히트스톱. 프레임 수만큼 게임 전체를 정지시킨다.
func _hitstop(frames: int) -> void:
	if frames <= 0:
		return
	var seconds := float(frames) / 60.0
	Engine.time_scale = 0.0001
	await _wait_real(seconds)
	Engine.time_scale = 1.0


# 카메라 흔들림. 진폭·지속의 2파라미터에 감쇠를 준다.
func _shake(amount: float, duration: float) -> void:
	if amount <= 0.0 or duration <= 0.0:
		return
	_shake_amount = amount
	_shake_time = _scaled(duration)


func _screen_flash(color: Color, strength: float, duration: float) -> void:
	if strength <= 0.0 or _flash == null:
		return
	_flash.color = Color(color.r, color.g, color.b, strength)
	var tween := create_tween()
	tween.tween_property(_flash, "color:a", 0.0, _scaled(duration))


func _camera_zoom(target: float, duration: float) -> void:
	if _camera == null:
		return
	var tween := create_tween()
	tween.tween_property(_camera, "zoom", Vector2(target, target), _scaled(duration)) \
		.set_ease(Tween.EASE_OUT)


func _play_banner(text: String, color: Color, duration: float, size: int) -> void:
	if _banner == null:
		return
	_banner.text = text
	_banner.add_theme_font_size_override("font_size", size)
	_banner.modulate = Color(color.r, color.g, color.b, 0)
	# 비스듬한 각도 — 설계서 §4.10.4 의 타이포그래피 규격(-8° ~ -12°).
	_banner.rotation = deg_to_rad(-9.0)
	_banner.pivot_offset = Vector2.ZERO
	# 캔버스 중심 기준. 1280 기준 (360, 320) 과 같은 자리다 — 절대 좌표로 두면
	# 넓은 창에서 배너가 화면 왼쪽으로 치우친다.
	var canvas: Vector2 = get_viewport_rect().size
	_banner.position = Vector2(canvas.x * 0.5 - 280.0, canvas.y * 0.5 - 40.0)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_banner, "modulate:a", 1.0, _scaled(duration * 0.25))
	tween.tween_property(_banner, "position",
		_banner.position + Vector2(60, -14), _scaled(duration))
	tween.chain().tween_property(_banner, "modulate:a", 0.0, _scaled(duration * 0.35))
	await tween.finished


# 데미지 숫자. 규격표(§4.10.6)의 색·크기·애니메이션을 쓴다.
func _spawn_number(ctx: DamageContext, style: Dictionary) -> void:
	if _numbers == null or ctx.target == null:
		return

	var label := Label.new()
	label.text = str(ctx.final_damage())
	if not String(style.get("label", "")).is_empty():
		label.text = "%s\n%s" % [String(style["label"]), label.text]
	label.modulate = style.get("color", Color.WHITE)
	label.add_theme_font_size_override("font_size",
		int(20.0 * float(style.get("scale", 1.0))))
	label.position = hud.unit_position(ctx.target) + Vector2(
		randf_range(-18.0, 18.0), -96.0)
	label.z_index = 60
	_numbers.add_child(label)

	var tween := create_tween()
	# 치명타는 스케일 팝(0 -> 1.3 -> 1.0).
	if ctx.is_crit or ctx.is_break_damage:
		label.scale = Vector2.ZERO
		tween.tween_property(label, "scale", Vector2(1.3, 1.3), _scaled(0.09))
		tween.tween_property(label, "scale", Vector2.ONE, _scaled(0.07))
	tween.set_parallel(true)
	tween.tween_property(label, "position", label.position + Vector2(0, -46),
		_scaled(0.7))
	tween.tween_property(label, "modulate:a", 0.0, _scaled(0.7))
	tween.chain().tween_callback(label.queue_free)


# 인성치 바 파열의 유리 파편.
func _spawn_shards(unit: TurnUnit, color: Color) -> void:
	var origin := hud.unit_position(unit) + Vector2(0, -80)
	for i in 18:
		var shard := ColorRect.new()
		shard.color = color
		shard.size = Vector2(randf_range(3, 8), randf_range(3, 8))
		shard.position = origin
		shard.z_index = 55
		shard.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_numbers.add_child(shard)

		var angle := TAU * float(i) / 18.0 + randf_range(-0.2, 0.2)
		var distance := randf_range(60.0, 150.0)
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(shard, "position",
			origin + Vector2.RIGHT.rotated(angle) * distance, _scaled(0.5))
		tween.tween_property(shard, "modulate:a", 0.0, _scaled(0.5))
		tween.tween_property(shard, "rotation", randf_range(-6.0, 6.0), _scaled(0.5))
		tween.chain().tween_callback(shard.queue_free)


# 원소별 대형 이펙트. Phase 0은 방사형 링으로 대체한다 (전용 이펙트는 Phase 3).
func _spawn_element_burst(unit: TurnUnit, color: Color) -> void:
	var origin := hud.unit_position(unit) + Vector2(0, -44)
	for i in 3:
		var ring := ColorRect.new()
		ring.color = Color(color.r, color.g, color.b, 0.45)
		ring.size = Vector2(24, 24)
		ring.position = origin - ring.size * 0.5
		ring.pivot_offset = ring.size * 0.5
		ring.z_index = 54
		ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_numbers.add_child(ring)

		var tween := create_tween()
		tween.tween_interval(_scaled(0.06 * float(i)))
		tween.set_parallel(true)
		tween.tween_property(ring, "scale", Vector2(9, 9), _scaled(0.45))
		tween.tween_property(ring, "modulate:a", 0.0, _scaled(0.45))
		tween.tween_property(ring, "rotation", randf_range(-1.2, 1.2), _scaled(0.45))
		tween.chain().tween_callback(ring.queue_free)


# 상태이상 아이콘 부착 애니메이션 (격파 9단계의 마지막).
func _spawn_status_badge(unit: TurnUnit, status: int, color: Color) -> void:
	var label := Label.new()
	label.text = "[%s]" % TurnCombat.break_status_name(status)
	label.modulate = color
	label.add_theme_font_size_override("font_size", 22)
	label.position = hud.unit_position(unit) + Vector2(-30, -140)
	label.scale = Vector2(2.2, 2.2)
	label.z_index = 60
	_numbers.add_child(label)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "scale", Vector2.ONE, _scaled(0.25)) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(label, "position",
		label.position + Vector2(0, 44), _scaled(0.35))
	tween.chain().tween_property(label, "modulate:a", 0.0, _scaled(0.4))
	tween.chain().tween_callback(label.queue_free)


# ===== 시간 (Timing) =====

# 배속이 적용된 지속시간.
func _scaled(duration: float) -> float:
	if battle.presentation == null:
		return duration
	return battle.presentation.scaled(duration)


# 배속을 반영해 기다린다.
func _wait(duration: float) -> void:
	var scaled := _scaled(duration)
	if scaled <= 0.0:
		return
	await get_tree().create_timer(scaled).timeout


# `Engine.time_scale`을 무시하고 실제 시간으로 기다린다.
# 히트스톱과 슬로모션은 `time_scale`을 건드리므로 일반 타이머로는 풀리지 않는다.
func _wait_real(duration: float) -> void:
	var scaled := _scaled(duration)
	if scaled <= 0.0:
		return
	await get_tree().create_timer(scaled, true, false, true).timeout


func _process(delta: float) -> void:
	if _camera == null:
		return

	if _shake_time > 0.0:
		_shake_time -= delta
		# 감쇠 — 진폭이 시간에 따라 줄어든다.
		var decay := maxf(_shake_time, 0.0)
		_camera.position = _camera_home + Vector2(
			randf_range(-_shake_amount, _shake_amount),
			randf_range(-_shake_amount, _shake_amount)) * decay * 6.0
		if _shake_time <= 0.0:
			_camera.position = _camera_home
	elif not _camera.position.is_equal_approx(_camera_home):
		_camera.position = _camera_home
