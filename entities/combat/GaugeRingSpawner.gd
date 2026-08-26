extends Node2D
class_name GaugeRingSpawner

const GAUGE_RING_SCENE: PackedScene = preload("res://entities/combat/GaugeRing.tscn")

var _refresh_queued: bool = false


func _ready() -> void:
	if not EventBus.stage_started.is_connected(_on_stage_started):
		EventBus.stage_started.connect(_on_stage_started)
	if not EventBus.party_changed.is_connected(_on_party_changed):
		EventBus.party_changed.connect(_on_party_changed)
	_schedule_refresh()


func _exit_tree() -> void:
	if EventBus.stage_started.is_connected(_on_stage_started):
		EventBus.stage_started.disconnect(_on_stage_started)
	if EventBus.party_changed.is_connected(_on_party_changed):
		EventBus.party_changed.disconnect(_on_party_changed)


func _on_stage_started(_stage_name: Variant) -> void:
	_schedule_refresh()


func _on_party_changed(_members: Variant) -> void:
	_schedule_refresh()


func _schedule_refresh() -> void:
	if _refresh_queued:
		return
	_refresh_queued = true
	call_deferred("_refresh")


func _refresh() -> void:
	_refresh_queued = false
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()

	for member: Node in get_tree().get_nodes_in_group(PartySystem.MEMBER_GROUP):
		var target: Node2D = member as Node2D
		if target == null or not is_instance_valid(target):
			continue
		if not target.has_method("has_skill_gauge") or not bool(target.call("has_skill_gauge")):
			continue
		# character_id를 묻지 않아 같은 capability를 가진 다음 캐릭터도 자동으로 붙는다(#303).
		var ring: GaugeRing = GAUGE_RING_SCENE.instantiate() as GaugeRing
		if ring == null:
			continue
		add_child(ring)
		ring.setup(target)
