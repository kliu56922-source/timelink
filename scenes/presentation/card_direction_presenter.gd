extends Node
class_name CardDirectionPresenter
## Read-only adapter from committed card facts to reusable physical VFX primitives.
## It owns no rule state, input, queue, or asynchronous presentation lifecycle.

const SUPPORTED_TEMPLATES: Array[StringName] = [
	&"bishop_blade",
	&"rook_relay",
	&"kingfire_finisher",
]
const SUPPORTED_PHASES: Array[StringName] = [&"commit", &"convey", &"resolve"]

var _profile: RefCounted = null
var _vfx: Node = null
var _nodes_by_generation: Dictionary = {}
var _play_count := 0
var _cancel_count := 0


func configure(profile: RefCounted, vfx: Node) -> void:
	_profile = profile
	_vfx = vfx


func play_phase(
	card_id: StringName,
	_action_kind: StringName,
	phase: StringName,
	facts: Dictionary,
	root: Control,
	generation: int,
	options: Dictionary = {}
) -> Dictionary:
	_prune_node_records()
	if not _is_committed_result(card_id, facts):
		return _unhandled(&"not_committed")
	if _profile == null or not _profile.has_method("get_card_direction_profile"):
		return _unhandled(&"missing_profile")
	if _vfx == null or not is_instance_valid(_vfx):
		return _unhandled(&"missing_vfx")
	if root == null or not is_instance_valid(root):
		return _unhandled(&"missing_root")
	if not phase in SUPPORTED_PHASES:
		return _unhandled(&"unknown_phase")

	var direction: Variant = _profile.call("get_card_direction_profile", card_id)
	if not direction is Dictionary or (direction as Dictionary).is_empty():
		return _unhandled(&"missing_direction_profile")
	var direction_profile: Dictionary = (direction as Dictionary).duplicate(true)
	var template := StringName(direction_profile.get("template", &""))
	var motif := StringName(direction_profile.get("%s_motif" % str(phase), &""))
	if not template in SUPPORTED_TEMPLATES or motif == &"":
		return _unhandled(&"bad_direction_profile")

	var primitive := _primitive_for_phase(phase)
	if primitive == &"" or not _vfx.has_method(primitive):
		return _unhandled(&"missing_primitive")
	var accent := _direction_accent(direction_profile)
	if accent.a <= 0.0:
		return _unhandled(&"bad_direction_profile")
	var duration := maxf(0.01, float(options.get("duration", 0.30)))
	var reduced_motion := bool(options.get("reduced_motion", false))
	var created: Node = null
	match phase:
		&"commit":
			created = _vfx.call(
				"play_material_stamp", root, _commit_center(facts), motif, accent,
				duration, generation, reduced_motion
			) as Node
		&"convey":
			var weighted_points: Array[Vector2] = _build_weighted_points(facts)
			if weighted_points.size() < 2:
				return _unhandled(&"missing_path")
			created = _vfx.call(
				"play_weighted_path", root, weighted_points, motif, accent,
				duration, generation, reduced_motion
			) as Node
		&"resolve":
			created = _vfx.call(
				"play_material_response", root, _resolve_center(facts), motif, accent,
				duration, generation, reduced_motion
			) as Node
	if created == null or not is_instance_valid(created):
		return _unhandled(&"primitive_declined")

	_tag_node(created, card_id, template, motif, phase, generation, reduced_motion)
	var generation_nodes: Array = _nodes_by_generation.get(generation, [])
	generation_nodes.append(created)
	_nodes_by_generation[generation] = generation_nodes
	_play_count += 1
	return {
		"handled": true,
		"template": template,
		"motif": motif,
		"phase": phase,
		"generation": generation,
		"node": created,
	}.duplicate()


func cancel_all(_reason: StringName = &"cancel") -> void:
	_cancel_count += 1
	if _vfx != null and is_instance_valid(_vfx) and _vfx.has_method("cancel_presentation_node"):
		for nodes in _nodes_by_generation.values():
			for raw_node in nodes as Array:
				var node := raw_node as Node if is_instance_valid(raw_node) else null
				if node != null and is_instance_valid(node):
					_vfx.call("cancel_presentation_node", node)
	_nodes_by_generation.clear()


func get_debug_snapshot() -> Dictionary:
	_prune_node_records()
	var temporary_node_count := 0
	var hotspot_count := 0
	for nodes in _nodes_by_generation.values():
		for raw_node in nodes as Array:
			var node := raw_node as Node
			if node == null or not is_instance_valid(node):
				continue
			temporary_node_count += 1
			var control := node as Control
			if control != null and control.mouse_filter != Control.MOUSE_FILTER_IGNORE:
				hotspot_count += 1
	return {
		"busy": false,
		"generation_count": _nodes_by_generation.size(),
		"temporary_node_count": temporary_node_count,
		"hotspot_count": hotspot_count,
		"play_count": _play_count,
		"cancel_count": _cancel_count,
	}.duplicate(true)


func _is_committed_result(card_id: StringName, facts: Dictionary) -> bool:
	if card_id == &"" or StringName(facts.get("card_id", card_id)) != card_id:
		return false
	if not bool(facts.get("ok", false)):
		return false
	if bool(facts.get("cancelled", false)) or bool(facts.get("expired", false)):
		return false
	return StringName(facts.get("status", &"")) == &"committed"


func _primitive_for_phase(phase: StringName) -> StringName:
	match phase:
		&"commit": return &"play_material_stamp"
		&"convey": return &"play_weighted_path"
		&"resolve": return &"play_material_response"
	return &""


func _direction_accent(direction_profile: Dictionary) -> Color:
	if not _profile.has_method("get_world_visual_language"):
		return Color(0, 0, 0, 0)
	var world: Variant = _profile.call("get_world_visual_language")
	if not world is Dictionary:
		return Color(0, 0, 0, 0)
	var colors: Variant = (world as Dictionary).get("function_colors", {})
	var reveal_ratios: Variant = (world as Dictionary).get("crystal_reveal_ratio", {})
	if not colors is Dictionary or not reveal_ratios is Dictionary:
		return Color(0, 0, 0, 0)
	var accent_key := str(direction_profile.get("accent", ""))
	var reveal_key := str(direction_profile.get("reveal_level", ""))
	var encoded_color: Variant = (colors as Dictionary).get(accent_key, null)
	var encoded_ratio: Variant = (reveal_ratios as Dictionary).get(reveal_key, null)
	if not encoded_color is String or encoded_ratio == null:
		return Color(0, 0, 0, 0)
	var color := Color.from_string(str(encoded_color), Color(0, 0, 0, 0))
	color.a = clampf(float(encoded_ratio), 0.0, 0.60)
	return color


func _commit_center(facts: Dictionary) -> Vector2:
	var center: Variant = facts.get("anchor_position", facts.get("source_position", Vector2.ZERO))
	return center as Vector2 if center is Vector2 else Vector2.ZERO


func _resolve_center(facts: Dictionary) -> Vector2:
	var center: Variant = facts.get("target_position", facts.get("anchor_position", Vector2.ZERO))
	return center as Vector2 if center is Vector2 else Vector2.ZERO


func _build_weighted_points(facts: Dictionary) -> Array[Vector2]:
	var points: Array[Vector2] = []
	_append_distinct_point(points, facts.get("source_position", null))
	_append_distinct_point(points, facts.get("anchor_position", null))
	var targets: Variant = facts.get("target_positions", [])
	if targets is Array:
		for target in targets as Array:
			_append_distinct_point(points, target)
	_append_distinct_point(points, facts.get("target_position", null))
	return points


func _append_distinct_point(points: Array[Vector2], candidate: Variant) -> void:
	if not candidate is Vector2:
		return
	var point: Vector2 = candidate
	if points.is_empty() or points[-1] != point:
		points.append(point)


func _tag_node(
	node: Node,
	card_id: StringName,
	template: StringName,
	motif: StringName,
	phase: StringName,
	generation: int,
	reduced_motion: bool
) -> void:
	node.set_meta("card_id", card_id)
	node.set_meta("template", template)
	node.set_meta("motif", motif)
	node.set_meta("phase", phase)
	node.set_meta("generation", generation)
	node.set_meta("reduced_motion", reduced_motion)


func _prune_node_records() -> void:
	for generation in _nodes_by_generation.keys():
		var live_nodes: Array = []
		for raw_node in _nodes_by_generation[generation] as Array:
			if is_instance_valid(raw_node) and raw_node is Node:
				live_nodes.append(raw_node)
		if live_nodes.is_empty():
			_nodes_by_generation.erase(generation)
		else:
			_nodes_by_generation[generation] = live_nodes


func _unhandled(reason: StringName) -> Dictionary:
	return {"handled": false, "reason": reason}.duplicate()
