extends Node3D
class_name TacticalStructurePresenter
## Read-only structure renderer.  It only accepts copied facts and terrain transforms.

const WRAPPER_SCENE := preload("res://scenes/presentation/structures/greybox_structure_wrapper.tscn")
const REQUIRED_SOCKETS := [&"CoreCenter", &"EdgeNorth", &"EdgeEast", &"EdgeSouth", &"EdgeWest", &"Garrison0", &"VFXOrigin", &"LabelAnchor"]
const REQUIRED_ASSET_FIELDS := [&"asset_id", &"wrapper_scene", &"socket_schema_version", &"bounds_profile", &"preview_mode", &"state_variant_mode", &"lod_policy"]
const WRAPPER_CONTROLLER_PATH := "res://scenes/presentation/structures/greybox_structure_wrapper.gd"

var _terrain: Node3D
var _profile: RefCounted
var _committed: Dictionary = {}
var _warnings: Dictionary = {}
var _force_material_failure := false
var _factory_probe_assets: Dictionary = {}
var _factory_probe_wrapper: Node3D
var _collision_layer: int = 1 << 20
var _semantic_proxy_refs: Dictionary = {}
var _active_tweens: Dictionary = {}
var _transition_generation_by_id: Dictionary = {}
var _superseded_tweens := 0
var _last_transition_kind := &""
var _last_reduced_motion := false
var _last_cleanup_reason := &""
var _last_structure_facts: Array = []
var _last_preview_fact: Dictionary = {}
var _replacement_comparison_visible := false
var _foundation_visual_states: Dictionary = {}

func set_material_failure_for_test(enabled: bool) -> void: _force_material_failure = enabled

func set_factory_probe_for_test(profile_id: StringName, asset_override: Dictionary, wrapper_probe: Node3D = null) -> void:

	_factory_probe_assets[profile_id] = asset_override.duplicate(true)
	_factory_probe_wrapper = wrapper_probe

func clear_factory_probe_for_test() -> void:

	_factory_probe_assets.clear()
	_factory_probe_wrapper = null

func _ready() -> void: _ensure_roots()

func _ensure_roots() -> void:
	for root_name in [&"StructureCommittedRoot", &"StructurePreviewRoot", &"StructureSemanticProxyRoot"]:
		if get_node_or_null(NodePath(root_name)) == null:
			var node := Node3D.new(); node.name = root_name; add_child(node)

func configure(terrain_presenter: Node3D, presentation_profile: RefCounted, collision_layer: int = 1 << 20) -> bool:

	if terrain_presenter == null or presentation_profile == null or not terrain_presenter.has_method("get_surface_anchor") or not terrain_presenter.has_method("get_proposed_surface_transform"):
		return false
	_terrain = terrain_presenter
	_profile = presentation_profile
	_collision_layer = collision_layer
	_ensure_roots()
	return true

func apply_structure_snapshot(snapshot: Dictionary, committed_fact: Dictionary = {}, reduced_motion: bool = false) -> Dictionary:

	if _terrain == null or _profile == null:
		return {"ok": false, "reason_code": &"invalid_snapshot"}
	var raw_structures: Variant = snapshot.get("structures", null)
	if not raw_structures is Array and not raw_structures is Dictionary:
		return {"ok": false, "reason_code": &"invalid_snapshot"}
	var incoming: Dictionary = {}
	var structure_values: Array = (raw_structures as Dictionary).values() if raw_structures is Dictionary else raw_structures as Array
	for raw in structure_values:
		if not raw is Dictionary or not raw.get("structure_id", null) is StringName or not raw.get("cell", null) is Vector2i or not raw.get("profile_id", null) is StringName:
			return {"ok": false, "reason_code": &"invalid_snapshot"}
		incoming[raw["structure_id"]] = raw.duplicate(true)
	_last_reduced_motion = reduced_motion
	_kill_all_tweens(true)
	var root := get_node("StructureCommittedRoot") as Node3D
	for child in root.get_children():
		if not incoming.has(child.get_meta("structure_id", &"")):
			root.remove_child(child); child.queue_free()
	for structure_id in incoming:
		var fact: Dictionary = incoming[structure_id]
		var previous: Dictionary = (_committed.get(structure_id, {}) as Dictionary).duplicate(true)
		var changed := previous.is_empty() or previous != fact
		var view := _find_committed_view(root, structure_id)
		if view == null:
			view = Node3D.new(); view.name = "Structure_%s" % str(structure_id).replace(":", "_"); root.add_child(view)
			var wrapper := _create_wrapper(StringName(fact["profile_id"]), false, _visual_state_from_fact(fact), fact)
			wrapper.name = "Wrapper"; view.add_child(wrapper)
		elif (view.get_node_or_null("Wrapper") as Node3D).has_method("configure_visual"):
			var existing := view.get_node("Wrapper") as Node3D
			var asset: Dictionary = existing.get_meta("structure_asset_contract", {})
			var profile_changed := StringName(existing.get_meta("structure_asset_profile", fact["profile_id"])) != StringName(fact["profile_id"])
			var retry_fallback := false
			if bool(existing.get_meta("structure_asset_fallback", false)):
				var current_asset: Dictionary = _factory_probe_assets.get(fact["profile_id"], _profile.get_asset(fact["profile_id"]))
				retry_fallback = changed or existing.get_meta("structure_asset_context", {}) != _asset_geometry_context(current_asset, fact)
			if profile_changed or retry_fallback or (not asset.is_empty() and not validate_asset_contract(asset, existing, _cell_spacing(), _level_step(), fact).get("ok", false)):
				view.remove_child(existing); existing.queue_free()
				existing = _create_wrapper(StringName(fact["profile_id"]), false, _visual_state_from_fact(fact), fact)
				existing.name = "Wrapper"; view.add_child(existing)
			else:
				existing.call("configure_visual", StringName(fact["profile_id"]), _visual_state_from_fact(fact), _cell_spacing(), _level_step(), false, _profile, fact.duplicate(true))
		var anchor := _terrain.call("get_surface_anchor", fact["cell"]) as Node3D
		if anchor == null: return {"ok": false, "reason_code": &"missing_surface_anchor"}
		view.global_transform = anchor.global_transform
		_sync_footprint_platform(view, fact)
		_apply_snapshot_state(view, fact)
		view.scale = Vector3.ONE
		if changed and not reduced_motion:
			_begin_structure_transition(view, structure_id, _transition_kind(previous, fact, committed_fact))
	_committed = incoming
	_last_structure_facts = structure_values.duplicate(true)
	_foundation_visual_states.clear()
	for structure_id in incoming:
		_foundation_visual_states[structure_id] = _visual_state_from_fact(incoming[structure_id])
	_reconcile_semantic_proxies(incoming, snapshot)
	return {"ok": true, "count": incoming.size()}

func _sync_footprint_platform(view: Node3D, fact: Dictionary) -> void:
	var cells: Array = fact.get("footprint_cells", [])
	var wrapper := view.get_node_or_null("Wrapper") as Node3D
	var has_content: bool = String(fact.get("profile_id", "")) == "p13_heat_sink" and wrapper != null and wrapper.has_method("has_authored_geometry") and wrapper.call("has_authored_geometry")
	for index: int in range(1, 4):
		var platform_name := "FootprintPlatform" if index == 1 else "FootprintPlatform%d" % index
		var platform := view.get_node_or_null(NodePath(platform_name)) as MeshInstance3D
		if index >= cells.size():
			if platform != null:
				view.remove_child(platform); platform.queue_free()
			continue
		var anchor := _terrain.call("get_surface_anchor", cells[index]) as Node3D
		if anchor == null: continue
		if platform == null:
			platform = MeshInstance3D.new(); platform.name = platform_name
			var box := BoxMesh.new(); box.size = Vector3(_cell_spacing() * 0.78, 0.08, _cell_spacing() * 0.78)
			platform.mesh = box
			var material := StandardMaterial3D.new(); material.albedo_color = Color(0.13, 0.3, 0.33)
			platform.material_override = material; view.add_child(platform)
		platform.global_transform = anchor.global_transform.translated_local(Vector3(0, _level_step() - 0.04, 0))
		platform.visible = not has_content


func _transition_kind(previous: Dictionary, incoming: Dictionary, committed_fact: Dictionary) -> StringName:

	var explicit := StringName(str(committed_fact.get("event_kind", &"")))
	if explicit != &"":
		return explicit
	if previous.is_empty():
		return &"structure_built"
	var status := StringName(str(incoming.get("status", &"intact")))
	if status == &"destroyed":
		return &"structure_destroyed"
	if status != StringName(str(previous.get("status", &"intact"))) \
			or int(incoming.get("integrity_current", 0)) < int(previous.get("integrity_current", 0)):
		return &"structure_hit"
	return &"structure_updated"

func _begin_structure_transition(view: Node3D, structure_id: StringName, transition_kind: StringName) -> void:

	var semantic_id := StringName("structure:%s" % structure_id)
	_kill_tween(semantic_id, true)
	var duration := _transition_duration(transition_kind)
	if duration <= 0.0:
		view.scale = Vector3.ONE
		return
	var start_scale := Vector3(0.88, 0.88, 0.88)
	if "damage" in String(transition_kind) or "hit" in String(transition_kind):
		start_scale = Vector3(1.04, 0.96, 1.04)
	elif "destroy" in String(transition_kind):
		start_scale = Vector3(1.05, 0.90, 1.05)
	view.scale = start_scale
	var generation := int(_transition_generation_by_id.get(semantic_id, 0)) + 1
	_transition_generation_by_id[semantic_id] = generation
	var tween := view.create_tween().bind_node(view)
	_active_tweens[semantic_id] = tween
	_last_transition_kind = transition_kind
	tween.tween_property(view, "scale", Vector3.ONE, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.finished.connect(_on_transition_finished.bind(semantic_id, generation, weakref(view)))

func _transition_duration(transition_kind: StringName) -> float:

	if "destroy" in String(transition_kind):
		return float(_profile.get_timing_seconds(&"core_destroy_seconds"))
	if "damage" in String(transition_kind) or "hit" in String(transition_kind):
		return float(_profile.get_timing_seconds(&"hit_seconds"))
	return float(_profile.get_timing_seconds(&"assembly_seconds"))

func _on_transition_finished(semantic_id: StringName, generation: int, view_ref: WeakRef) -> void:

	if int(_transition_generation_by_id.get(semantic_id, -1)) != generation:
		return
	_active_tweens.erase(semantic_id)
	var view := view_ref.get_ref() as Node3D
	if view != null and is_instance_valid(view):
		view.scale = Vector3.ONE

func _kill_tween(semantic_id: StringName, count_as_superseded: bool = false) -> void:

	var tween := _active_tweens.get(semantic_id, null) as Tween
	if tween != null and tween.is_valid():
		if count_as_superseded and tween.is_running():
			_superseded_tweens += 1
		tween.kill()
	_active_tweens.erase(semantic_id)

func _kill_all_tweens(count_as_superseded: bool = false) -> void:

	for semantic_id in _active_tweens.keys():
		_kill_tween(StringName(str(semantic_id)), count_as_superseded)
	for root_name in ["StructureCommittedRoot", "StructurePreviewRoot"]:
		var root := get_node_or_null(NodePath(root_name))
		if root == null:
			continue
		for child in root.get_children():
			if child is Node3D:
				(child as Node3D).scale = Vector3.ONE

func get_active_tween_count() -> int:

	var count := 0
	for tween in _active_tweens.values():
		if tween is Tween and (tween as Tween).is_valid() and (tween as Tween).is_running():
			count += 1
	return count

func cancel_presentations(reason: StringName = &"cancel") -> void:

	_last_cleanup_reason = reason
	_kill_all_tweens(false)
	clear_preview()

func reset_presentation(reason: StringName = &"reset") -> void:

	cancel_presentations(reason)

func get_debug_snapshot() -> Dictionary:

	_ensure_roots()
	return {
		"active_tweens": get_active_tween_count(),
		"active_tween_ids": _active_tweens.keys().duplicate(),
		"superseded_tweens": _superseded_tweens,
		"last_transition_kind": _last_transition_kind,
		"last_reduced_motion": _last_reduced_motion,
		"last_cleanup_reason": _last_cleanup_reason,
		"preview_nodes": get_node("StructurePreviewRoot").get_child_count(),
		"committed_nodes": get_node("StructureCommittedRoot").get_child_count(),
		"semantic_proxy_nodes": get_node("StructureSemanticProxyRoot").get_child_count(),
		"committed_snapshot": _last_structure_facts.duplicate(true),
		"preview_fact": _last_preview_fact.duplicate(true),
		"replacement_comparison_visible": _replacement_comparison_visible,
		"foundation_visual_states": _foundation_visual_states.duplicate(true),
	}


func _visual_state_from_fact(fact: Dictionary) -> StringName:
	if not fact.has("foundation_state"):
		return StringName(str(fact.get("status", &"intact")))
	var foundation_state := StringName(str(fact.get("foundation_state", &"stable")))
	if foundation_state == &"collapse_due":
		return &"collapse_due"
	if foundation_state == &"undermined":
		return &"undermined_active" if StringName(str(fact.get("recovery_window_phase", &""))) == &"active_owner_turn" else &"undermined_waiting"
	var damage_state := StringName(str(fact.get("status", &"intact")))
	return &"stable" if foundation_state == &"stable" and damage_state == &"intact" else damage_state


## Read-only presentation socket lookup for Phase D1. The returned value is a
## copied transform; callers never receive the mutable structure rule state.
func get_structure_socket_global_transform(structure_id: StringName, socket_name: StringName) -> Transform3D:
	var fact: Dictionary = _committed.get(structure_id, {})
	var footprint: Array = fact.get("footprint_cells", [])
	if socket_name == &"Garrison0" and footprint.size() == 2 and is_instance_valid(_terrain):
		var platform := _terrain.call("get_surface_anchor", footprint[1]) as Node3D
		if platform != null:
			return platform.global_transform.translated_local(Vector3(0, _level_step(), 0))

	var root := get_node_or_null("StructureCommittedRoot") as Node3D
	if root == null:
		return Transform3D()
	var view := _find_committed_view(root, structure_id)
	if view == null:
		return Transform3D()
	var wrapper := view.get_node_or_null("Wrapper") as Node3D
	if wrapper == null:
		return Transform3D()
	var socket := wrapper.get_node_or_null(NodePath("Sockets/%s" % socket_name)) as Node3D
	return socket.global_transform if socket != null else Transform3D()


## Presentation-only wrapper access used to activate the greybox slot skin.
## No structure, module or garrison authority is exposed through this method.
func set_garrison_slot_state(
		structure_id: StringName,
		_slot_id: StringName,
		active: bool,
		state: StringName = &"available"
) -> void:

	var wrapper := get_structure_wrapper(structure_id)
	if wrapper != null and wrapper.has_method("set_garrison_slot_active"):
		wrapper.call("set_garrison_slot_active", active, state)


func get_structure_wrapper(structure_id: StringName) -> Node3D:

	var root := get_node_or_null("StructureCommittedRoot") as Node3D
	if root == null:
		return null
	var view := _find_committed_view(root, structure_id)
	return view.get_node_or_null("Wrapper") as Node3D if view != null else null

## Proxies are generated from copied semantic facts, never wrapper geometry or imports.
func get_semantic_proxy_snapshot() -> Dictionary:

	return _semantic_proxy_refs.duplicate(true)

func get_semantic_target_ref(proxy_key: StringName) -> Dictionary:

	var target: Variant = _semantic_proxy_refs.get(proxy_key, {})
	return (target as Dictionary).duplicate(true) if target is Dictionary else {}

func _reconcile_semantic_proxies(structures: Dictionary, snapshot: Dictionary) -> void:

	var root := get_node("StructureSemanticProxyRoot") as Node3D
	var incoming: Dictionary = {}
	var structure_revision := int(snapshot.get("revision", -1))
	var terrain_revisions := _terrain_revision_index(snapshot)
	for structure_id in structures:
		var structure: Dictionary = structures[structure_id] as Dictionary
		var cell: Variant = structure.get("cell", null)
		if not cell is Vector2i:
			continue
		var terrain_revision := int(terrain_revisions.get(cell, structure.get("expected_terrain_revision", structure.get("terrain_revision", -1))))
		var core_key := StringName("%s:core" % structure_id)
		incoming[core_key] = {
			"target_kind": &"structure_core", "structure_id": StringName(str(structure_id)), "module_id": &"",
			"cell": cell, "edge": &"", "canonical_edge": &"", "expected_terrain_revision": terrain_revision,
			"expected_structure_revision": structure_revision, "expected_module_revision": -1,
		}
		#103 solid P13 geometry has one core proxy per occupied tile. Old P08 platforms stay as before.
		if structure.get("profile_id") == &"p13_heat_sink":
			for occupied: Vector2i in structure.get("footprint_cells", [cell]):
				if occupied == cell: continue
				var secondary_key := StringName("%s:core:cell:%d:%d" % [structure_id, occupied.x, occupied.y])
				var secondary: Dictionary = incoming[core_key].duplicate(true)
				secondary.cell = occupied
				secondary.expected_terrain_revision = int(terrain_revisions.get(occupied, -1))
				incoming[secondary_key] = secondary
		for module in _modules_for_structure(structure, snapshot):
			var module_id := StringName(str(module.get("module_id", &"")))
			var edge := StringName(str(module.get("edge", &"")))
			if module_id == &"" or edge == &"":
				continue
			incoming[module_id] = {
				"target_kind": &"structure_module", "structure_id": StringName(str(structure_id)), "module_id": module_id,
				"cell": cell, "edge": edge, "canonical_edge": StringName(str(module.get("canonical_edge", &""))), "expected_terrain_revision": terrain_revision,
				"expected_structure_revision": structure_revision, "expected_module_revision": int(module.get("revision", -1)),
			}
	for child in root.get_children():
		if not incoming.has(StringName(str(child.get_meta("semantic_key", &"")))):
			root.remove_child(child)
			child.queue_free()
	_semantic_proxy_refs = incoming.duplicate(true)
	for key in incoming:
		var target_ref: Dictionary = incoming[key] as Dictionary
		var proxy := _find_semantic_proxy(root, key)
		if proxy == null:
			proxy = _create_semantic_proxy(key, target_ref)
			root.add_child(proxy)
		_update_semantic_proxy(proxy, key, target_ref)

func _terrain_revision_index(snapshot: Dictionary) -> Dictionary:

	var revisions := {}
	var terrain_cells: Variant = snapshot.get("terrain_cells", snapshot.get("cells", []))
	if terrain_cells is Dictionary:
		for raw_cell in terrain_cells:
			var state: Variant = (terrain_cells as Dictionary)[raw_cell]
			if raw_cell is Vector2i and state is Dictionary:
				revisions[raw_cell] = int((state as Dictionary).get("revision", -1))
	elif terrain_cells is Array:
		for raw in terrain_cells:
			if raw is Dictionary and raw.get("cell", null) is Vector2i:
				revisions[raw["cell"]] = int(raw.get("revision", -1))
	return revisions

func _modules_for_structure(structure: Dictionary, snapshot: Dictionary) -> Array[Dictionary]:

	var by_id: Dictionary = {}
	var nested: Variant = structure.get("modules", [])
	if nested is Array:
		for module in nested:
			if module is Dictionary:
				by_id[StringName(str((module as Dictionary).get("module_id", &"")))] = (module as Dictionary).duplicate(true)
	var modules: Variant = snapshot.get("modules", {})
	if modules is Dictionary:
		for module_id in modules:
			var module: Variant = modules[module_id]
			if module is Dictionary and StringName(str((module as Dictionary).get("structure_id", &""))) == StringName(str(structure.get("structure_id", &""))):
				by_id[StringName(str((module as Dictionary).get("module_id", module_id)))] = (module as Dictionary).duplicate(true)
	var result: Array[Dictionary] = []
	for module_id in by_id:
		if module_id != &"":
			result.append((by_id[module_id] as Dictionary).duplicate(true))
	result.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return str(left.get("module_id", "")) < str(right.get("module_id", "")))
	return result

func _find_semantic_proxy(root: Node3D, key: StringName) -> Area3D:

	for child in root.get_children():
		if StringName(str(child.get_meta("semantic_key", &""))) == key:
			return child as Area3D
	return null

func _create_semantic_proxy(key: StringName, target_ref: Dictionary) -> Area3D:

	var area := Area3D.new()
	area.name = "Semantic_%s" % str(key).replace(":", "_")
	area.collision_layer = _collision_layer
	area.collision_mask = 0
	area.monitoring = false
	area.monitorable = false
	var shape := CollisionShape3D.new()
	shape.name = "SafeBounds"
	area.add_child(shape)
	return area

func _update_semantic_proxy(area: Area3D, key: StringName, target_ref: Dictionary) -> void:

	var anchor := _terrain.call("get_surface_anchor", target_ref["cell"]) as Node3D
	if anchor == null:
		return
	var spacing := _cell_spacing()
	var level := _level_step()
	var is_module := StringName(str(target_ref.get("target_kind", &""))) == &"structure_module"
	var edge := StringName(str(target_ref.get("edge", &"")))
	var size := Vector3(spacing * 0.74, maxf(level * 0.70, 0.18), spacing * 0.74)
	var offset := Vector3(0.0, size.y * 0.5, 0.0)
	if is_module:
		var long := spacing * 0.88
		var thick := spacing * 0.12
		size = Vector3(long, maxf(level * 0.90, 0.22), thick) if edge in [&"north", &"south"] else Vector3(thick, maxf(level * 0.90, 0.22), long)
		offset = Vector3(0.0, size.y * 0.5, 0.0)
		if edge == &"north": offset.z = -spacing * 0.44
		elif edge == &"east": offset.x = spacing * 0.44
		elif edge == &"south": offset.z = spacing * 0.44
		elif edge == &"west": offset.x = -spacing * 0.44
	area.global_transform = anchor.global_transform * Transform3D(Basis.IDENTITY, offset)
	var collision := area.get_node_or_null("SafeBounds") as CollisionShape3D
	if collision != null:
		var box := BoxShape3D.new(); box.size = size; collision.shape = box
	area.set_meta("semantic_key", key)
	area.set_meta("target_kind", target_ref.get("target_kind", &""))
	area.set_meta("target_ref", target_ref.duplicate(true))

func show_preview(preview_fact: Dictionary, reduced_motion: bool = false) -> Dictionary:

	if _terrain == null or _profile == null:
		return {"ok": false, "reason_code": &"not_configured"}
	var preview_id: Variant = preview_fact.get("preview_id", null)
	var cell: Variant = preview_fact.get("cell", null)
	var height: Variant = preview_fact.get("target_height", null)
	var profile_id: Variant = preview_fact.get("profile_id", null)
	var visual_state: Variant = preview_fact.get("visual_state", null)
	if preview_id == null or not cell is Vector2i or not height is int or not profile_id is StringName or not visual_state is StringName:
		return {"ok": false, "reason_code": &"invalid_preview_fact"}
	clear_preview()
	_last_preview_fact = preview_fact.duplicate(true)
	var preview := Node3D.new(); preview.name = String(preview_id)
	if StringName(str(preview_fact.get("placement_kind", &""))) == &"same_cell_upgrade" \
			and preview_fact.get("foundation_before", {}) is Dictionary \
			and not (preview_fact.get("foundation_before", {}) as Dictionary).is_empty():
		var before: Dictionary = (preview_fact.get("foundation_before", {}) as Dictionary).duplicate(true)
		var old_profile := StringName(str(before.get("profile_id", &"p05_foundation")))
		var old_wrapper := _create_wrapper(old_profile, true, &"replacement_before", before)
		old_wrapper.name = "ReplacementBeforeGhost"
		preview.add_child(old_wrapper)
		_replacement_comparison_visible = true
	var wrapper := _create_wrapper(profile_id, true, visual_state, preview_fact); wrapper.name = "Wrapper"; preview.add_child(wrapper)
	(get_node("StructurePreviewRoot") as Node3D).add_child(preview)
	preview.global_transform = _terrain.call("get_proposed_surface_transform", cell, height) as Transform3D
	preview.set_meta("presentation_token", _profile.get_preview_token(visual_state))
	if not reduced_motion:
		var duration := float(_profile.get_timing_seconds(&"hover_snap_seconds"))
		if duration > 0.0:
			preview.scale = Vector3(0.94, 0.94, 0.94)
			var semantic_id := &"preview"
			var generation := int(_transition_generation_by_id.get(semantic_id, 0)) + 1
			_transition_generation_by_id[semantic_id] = generation
			var tween := preview.create_tween().bind_node(preview)
			_active_tweens[semantic_id] = tween
			tween.tween_property(preview, "scale", Vector3.ONE, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tween.finished.connect(_on_transition_finished.bind(semantic_id, generation, weakref(preview)))
	return {"ok": true, "token": _profile.get_preview_token(visual_state)}

func clear_preview() -> void:

	_ensure_roots()
	_kill_tween(&"preview", false)
	var root := get_node("StructurePreviewRoot")
	for child in root.get_children(): root.remove_child(child); child.queue_free()
	_last_preview_fact.clear()
	_replacement_comparison_visible = false

func _exit_tree() -> void:

	_kill_all_tweens(false)

func _create_wrapper(profile_id: StringName, preview: bool, visual_state: StringName = &"intact", presentation_fact: Dictionary = {}) -> Node3D:

	var asset: Dictionary = (_factory_probe_assets.get(profile_id, _profile.get_asset(profile_id)) as Dictionary).duplicate(true)
	var wrapper: Node3D = null
	if _asset_is_safe(asset, presentation_fact):
		wrapper = _instantiate_asset_wrapper(asset)
		if wrapper != null: wrapper.set_meta("structure_asset_contract", asset.duplicate(true))
	if wrapper == null:
		_warn_once(&"fallback:" + profile_id, "Structure art contract rejected; using procedural greybox.")
		wrapper = WRAPPER_SCENE.instantiate() as Node3D
		wrapper.set_meta("structure_asset_fallback", true)
	wrapper.set_meta("structure_asset_profile", profile_id)
	wrapper.set_meta("structure_asset_context", _asset_geometry_context(asset, presentation_fact))
	wrapper.set_meta("force_material_failure", _force_material_failure)
	if wrapper.has_method("configure_visual"):
		wrapper.call("configure_visual", profile_id, visual_state, _cell_spacing(), _level_step(), preview, _profile, presentation_fact.duplicate(true))
	if preview: _disable_preview_runtime_nodes(wrapper)
	return wrapper

func _asset_geometry_context(asset: Dictionary, fact: Dictionary) -> Dictionary:
	var spacing := _cell_spacing()
	return {"extent":_footprint_extent(fact, asset, spacing), "spacing":spacing, "level_step":_level_step()}

func _asset_is_safe(asset: Dictionary, presentation_fact: Dictionary = {}) -> bool:

	for field in REQUIRED_ASSET_FIELDS:
		if not asset.has(field) or str(asset[field]).is_empty(): return false
	if int(asset.get("socket_schema_version", 0)) != 1: return false
	var path := str(asset.get("wrapper_scene", ""))
	if not path.begins_with("res://") or not ResourceLoader.exists(path): return false
	var probe := _instantiate_asset_wrapper(asset)
	if probe == null: return false
	var result := validate_asset_contract(asset, probe, _cell_spacing(), _level_step(), presentation_fact)
	probe.free()
	return bool(result.get("ok", false))

func _instantiate_asset_wrapper(asset: Dictionary) -> Node3D:

	if _factory_probe_wrapper != null:
		return _factory_probe_wrapper.duplicate() as Node3D
	var packed := load(str(asset.get("wrapper_scene", ""))) as PackedScene
	return packed.instantiate() as Node3D if packed != null else null

func validate_asset_contract(asset: Dictionary, wrapper: Node3D, cell_spacing: float, level_step: float, presentation_fact: Dictionary = {}) -> Dictionary:

	for field in REQUIRED_ASSET_FIELDS:
		if not asset.has(field) or str(asset[field]).is_empty(): return {"ok": false, "fallback": true, "reason": &"asset_field"}
	if int(asset.get("socket_schema_version", 0)) != 1: return {"ok": false, "fallback": true, "reason": &"socket_schema"}
	if not String(asset.get("bounds_profile", "")) in ["foundation", "fortification", "heat_sink", "containment_wall", "core_cathedral"]: return {"ok": false, "fallback": true, "reason": &"bounds_profile"}
	if wrapper == null: return {"ok": false, "fallback": true, "reason": &"wrapper"}
	if wrapper.top_level or not wrapper.transform.is_equal_approx(Transform3D.IDENTITY): return {"ok": false, "fallback": true, "reason": &"root_transform"}
	if wrapper.get_script() == null or wrapper.get_script().resource_path != WRAPPER_CONTROLLER_PATH: return {"ok": false, "fallback": true, "reason": &"root_script"}
	for socket_name in REQUIRED_SOCKETS:
		if wrapper.get_node_or_null(NodePath("Sockets/%s" % socket_name)) == null: return {"ok": false, "fallback": true, "reason": &"socket"}
	var art_root := wrapper.get_node_or_null("ArtRoot") as Node3D
	if art_root == null: return {"ok": false, "fallback": true, "reason": &"art_root"}
	if _has_unsafe_import(wrapper, wrapper): return {"ok": false, "fallback": true, "reason": &"unsafe_import"}
	var extent := _footprint_extent(presentation_fact, asset, cell_spacing)
	if not extent.get("ok", false): return {"ok": false, "fallback": true, "reason": &"footprint_context"}
	var measured := _measure_art_bounds(art_root)
	if not measured.get("has_mesh", false): return {"ok": true, "fallback": false}
	if measured.get("invalid", false) or not (measured["min"] as Vector3).is_finite() or not (measured["max"] as Vector3).is_finite(): return {"ok": false, "fallback": true, "reason": &"non_finite_bounds"}
	var span: Vector3 = measured["max"] - measured["min"]
	var horizontal_half := cell_spacing * 0.45
	var multi: bool = extent.get("multi", false)
	if multi:
		var lo: Vector3 = extent.min
		var hi: Vector3 = extent.max
		if (measured["min"] as Vector3).x < lo.x or (measured["max"] as Vector3).x > hi.x or (measured["min"] as Vector3).z < lo.z or (measured["max"] as Vector3).z > hi.z: return {"ok": false, "fallback": true, "reason": &"horizontal_envelope"}
	elif span.x > cell_spacing * 0.90 or span.z > cell_spacing * 0.90 or (measured["min"] as Vector3).x < -horizontal_half or (measured["max"] as Vector3).x > horizontal_half or (measured["min"] as Vector3).z < -horizontal_half or (measured["max"] as Vector3).z > horizontal_half: return {"ok": false, "fallback": true, "reason": &"horizontal_envelope"}
	var compact_profile := String(asset["bounds_profile"]) in ["foundation", "heat_sink"]
	var zones := _validated_socket_zones(wrapper, cell_spacing)
	if zones.is_empty(): return {"ok": false, "fallback": true, "reason": &"socket_layout"}
	for mesh_bounds in measured["meshes"]:
		var mesh_data: Dictionary = mesh_bounds as Dictionary
		var mesh_span: Vector3 = mesh_data["max"] - mesh_data["min"]
		if not multi and _mesh_zone(mesh_data, zones) == &"": return {"ok": false, "fallback": true, "reason": &"zone_bounds"}
		var ground_span: float = float(extent.get("floor_max", 0.0)) - float(extent.get("floor_min", 0.0)) if multi else 0.0
		if mesh_span.y > level_step * (0.70 if compact_profile else 1.65) + ground_span + 0.001: return {"ok": false, "fallback": true, "reason": &"height_bounds"}
		if multi and ((mesh_data["min"] as Vector3).y < float(extent.floor_min) - 0.001 or (mesh_data["max"] as Vector3).y > float(extent.floor_max) + level_step * 0.70 + 0.001): return {"ok": false, "fallback": true, "reason": &"height_bounds"}
	return {"ok": true, "fallback": false}

func _footprint_extent(presentation_fact: Dictionary, asset: Dictionary, spacing: float) -> Dictionary:
	# Only current copied P13 facts may enlarge the envelope. Asset metadata grants nothing.
	var core: Variant = presentation_fact.get("core", presentation_fact)
	if not core is Dictionary: return {"ok": false}
	var cells: Variant = core.get("footprint_cells", [])
	if not cells is Array: return {"ok": false}
	var origin: Variant = core.get("cell", presentation_fact.get("cell", null))
	var profile_id := String(core.get("profile_id", presentation_fact.get("profile_id", "")))
	var bounds := {"p05_foundation":"foundation", "p08_fortification":"fortification", "p13_heat_sink":"heat_sink", "p16_containment_wall":"containment_wall", "p19_core_cathedral":"core_cathedral"}
	if bounds.has(profile_id) and str(asset.get("bounds_profile", "")) != bounds[profile_id]: return {"ok": false}
	if cells.size() == 1:
		var only: Variant = cells[0]
		if not only is Vector2i or not origin is Vector2i: return {"ok": false}
		if only != origin or only.x < 0 or only.x >= 5 or only.y < 0 or only.y >= 5: return {"ok": false}
	if cells.size() <= 1: return {"ok": true, "multi": false}
	# Legacy P08 uses a second support tile, but its imported core keeps the old single-cell budget.
	if profile_id == "p08_fortification" and cells.size() == 2 and origin is Vector2i and cells[0] is Vector2i and cells[1] is Vector2i:
		if cells[0] == origin and cells[0] != cells[1] and absi(cells[0].x - cells[1].x) + absi(cells[0].y - cells[1].y) == 1:
			for cell: Vector2i in cells:
				if cell.x < 0 or cell.y < 0 or cell.x >= 5 or cell.y >= 5: return {"ok": false}
			return {"ok": true, "multi": false}
		return {"ok": false}
	if _terrain == null or profile_id != "p13_heat_sink" or str(asset.get("bounds_profile", "")) != "heat_sink": return {"ok": false}
	if cells.size() not in [2, 4]: return {"ok": false}
	if not origin is Vector2i or not cells[0] is Vector2i: return {"ok": false}
	if cells[0] != origin: return {"ok": false}
	var seen: Dictionary = {}
	var minimum: Vector2i = origin; var maximum: Vector2i = origin
	for cell in cells:
		if not cell is Vector2i or seen.has(cell) or cell.x < 0 or cell.y < 0 or cell.x >= 5 or cell.y >= 5: return {"ok": false}
		seen[cell] = true; minimum = minimum.min(cell); maximum = maximum.max(cell)
	var size := maximum - minimum + Vector2i.ONE
	if size not in [Vector2i(1,2), Vector2i(2,1), Vector2i(2,2)] or size.x * size.y != cells.size(): return {"ok": false}
	var anchor := _terrain.call("get_surface_anchor", origin) as Node3D
	if anchor == null: return {"ok": false}
	var inverse := anchor.global_transform.affine_inverse()
	var base := _terrain.call("get_proposed_surface_transform", origin, 0) as Transform3D
	var level_offset := anchor.global_position.y - base.origin.y
	var lo := Vector3(INF,0,INF); var hi := Vector3(-INF,0,-INF)
	for cell in cells:
		var other := _terrain.call("get_surface_anchor", cell) as Node3D
		if other == null: return {"ok": false}
		var local := inverse * other.global_position
		var other_base := _terrain.call("get_proposed_surface_transform", cell, 0) as Transform3D
		# V03 has calibrated, slightly uneven base anchors even at equal logical height.
		if not local.is_finite() or absf(other.global_position.y - other_base.origin.y - level_offset) > 0.001: return {"ok": false}
		lo = lo.min(local - Vector3(spacing * 0.45,0,spacing * 0.45))
		hi = hi.max(local + Vector3(spacing * 0.45,0,spacing * 0.45))
	return {"ok": true, "multi": true, "min": lo, "max": hi, "floor_min": lo.y, "floor_max": hi.y}

func _has_unsafe_import(node: Node, wrapper: Node3D, generated_context: bool = false) -> bool:

	for child in node.get_children():
		if child is Area3D or child is CollisionObject3D or child is CollisionShape3D or child is Camera3D or child is Light3D: return true
		if child.get_script() != null: return true
		var tag: Variant = child.get_meta(&"_structure_generated_art", 0)
		var generated: bool = generated_context or (tag is int and tag == wrapper.get_instance_id())
		if child is Node3D and child.top_level: return true # Content must inherit the validated terrain anchor.
		if child is AnimationPlayer or child is Skeleton3D: return true # Static content only until a pose contract is verified.
		if child is MeshInstance3D:
			if child.skin != null: return true
			if not child.skeleton.is_empty() and child.get_node_or_null(child.skeleton) is Skeleton3D: return true
		if child is GeometryInstance3D and not child is MeshInstance3D and not (generated and child is Label3D): return true
		if child is MeshInstance3D and not generated and not wrapper.get_node("ArtRoot").is_ancestor_of(child): return true
		if _has_unsafe_import(child, wrapper, generated): return true
	return false

func _validated_socket_zones(wrapper: Node3D, cell_spacing: float) -> Dictionary:

	var sockets := {}
	for socket_name in [&"CoreCenter", &"EdgeNorth", &"EdgeEast", &"EdgeSouth", &"EdgeWest"]:
		var socket := wrapper.get_node_or_null(NodePath("Sockets/%s" % socket_name)) as Node3D
		if socket == null: return {}
		sockets[socket_name] = _transform_relative_to(wrapper, socket).origin
	var core := sockets[&"CoreCenter"] as Vector3
	var core_half := cell_spacing * 0.37
	var edge_half := cell_spacing * 0.45
	var strip_half := cell_spacing * 0.06
	var epsilon := maxf(cell_spacing * 0.002, 0.001)
	if absf(core.x) > epsilon or absf(core.z) > epsilon: return {}
	var definitions := [
		{"name":&"EdgeNorth", "axis":&"z", "sign":-1.0},
		{"name":&"EdgeEast", "axis":&"x", "sign":1.0},
		{"name":&"EdgeSouth", "axis":&"z", "sign":1.0},
		{"name":&"EdgeWest", "axis":&"x", "sign":-1.0}
	]
	for definition in definitions:
		var position := sockets[definition["name"]] as Vector3
		var primary := (position.z - core.z) if definition["axis"] == &"z" else (position.x - core.x)
		var lateral := (position.x - core.x) if definition["axis"] == &"z" else (position.z - core.z)
		if absf(lateral) > epsilon or float(definition["sign"]) * primary < core_half - epsilon or absf(primary) + strip_half > edge_half + epsilon: return {}
		for other in sockets:
			if other != definition["name"] and position.distance_to(sockets[other] as Vector3) <= epsilon: return {}
	var length_half := cell_spacing * 0.44
	return {
		&"core": {"min":Vector3(-core_half, -INF, -core_half), "max":Vector3(core_half, INF, core_half)},
		&"north": {"min":Vector3(-length_half, -INF, (sockets[&"EdgeNorth"] as Vector3).z - strip_half), "max":Vector3(length_half, INF, (sockets[&"EdgeNorth"] as Vector3).z + strip_half)},
		&"east": {"min":Vector3((sockets[&"EdgeEast"] as Vector3).x - strip_half, -INF, -length_half), "max":Vector3((sockets[&"EdgeEast"] as Vector3).x + strip_half, INF, length_half)},
		&"south": {"min":Vector3(-length_half, -INF, (sockets[&"EdgeSouth"] as Vector3).z - strip_half), "max":Vector3(length_half, INF, (sockets[&"EdgeSouth"] as Vector3).z + strip_half)},
		&"west": {"min":Vector3((sockets[&"EdgeWest"] as Vector3).x - strip_half, -INF, -length_half), "max":Vector3((sockets[&"EdgeWest"] as Vector3).x + strip_half, INF, length_half)}
	}

func _transform_relative_to(root_node: Node3D, node: Node3D) -> Transform3D:

	var transforms: Array[Transform3D] = []
	var current: Node = node
	while current != null and current != root_node:
		if current is Node3D: transforms.push_front((current as Node3D).transform)
		current = current.get_parent()
	var result := Transform3D.IDENTITY
	for transform in transforms: result *= transform
	return result

func _mesh_zone(mesh_data: Dictionary, zones: Dictionary) -> StringName:

	var matches: Array[StringName] = []
	for zone_name in zones:
		var zone: Dictionary = zones[zone_name] as Dictionary
		var minimum := mesh_data["min"] as Vector3
		var maximum := mesh_data["max"] as Vector3
		var zone_min := zone["min"] as Vector3
		var zone_max := zone["max"] as Vector3
		if minimum.x >= zone_min.x and maximum.x <= zone_max.x and minimum.z >= zone_min.z and maximum.z <= zone_max.z:
			matches.append(StringName(zone_name))
	return matches[0] if matches.size() == 1 else &""

func _measure_art_bounds(art_root: Node3D) -> Dictionary:

	var result := {"has_mesh": false, "min": Vector3(INF, INF, INF), "max": Vector3(-INF, -INF, -INF), "meshes": []}
	_collect_art_bounds(art_root, art_root.transform, result, art_root.get_parent().get_instance_id())
	return result

func _collect_art_bounds(node: Node, parent_transform: Transform3D, result: Dictionary, generated_owner: int = 0) -> void:

	for child in node.get_children():
		if result.get("invalid", false): return
		var tag: Variant = child.get_meta(&"_structure_generated_art", 0)
		if generated_owner != 0 and tag is int and tag == generated_owner: continue
		var local_transform := parent_transform * ((child as Node3D).transform if child is Node3D else Transform3D.IDENTITY)
		if not local_transform.origin.is_finite() or not local_transform.basis.is_finite():
			result["invalid"] = true; result["has_mesh"] = true; result["min"] = Vector3(NAN,NAN,NAN); result["max"] = Vector3(NAN,NAN,NAN); return
		if child is MeshInstance3D and (child as MeshInstance3D).mesh != null:
			var mesh_node := child as MeshInstance3D
			var aabb := mesh_node.mesh.get_aabb()
			result["has_mesh"] = true
			var mesh_min := Vector3(INF, INF, INF)
			var mesh_max := Vector3(-INF, -INF, -INF)
			for x in [aabb.position.x, aabb.end.x]:
				for y in [aabb.position.y, aabb.end.y]:
					for z in [aabb.position.z, aabb.end.z]:
						var point := local_transform * Vector3(x, y, z)
						result["min"] = (result["min"] as Vector3).min(point)
						result["max"] = (result["max"] as Vector3).max(point)
						mesh_min = mesh_min.min(point); mesh_max = mesh_max.max(point)
			result["meshes"].append({"min": mesh_min, "max": mesh_max, "center": (mesh_min + mesh_max) * 0.5})
		_collect_art_bounds(child, local_transform, result, generated_owner)

func _disable_preview_runtime_nodes(node: Node) -> void:

	node.process_mode = Node.PROCESS_MODE_DISABLED
	node.set_process(false); node.set_physics_process(false); node.set_process_input(false); node.set_process_unhandled_input(false); node.set_process_unhandled_key_input(false)
	for child in node.get_children():
		if child is AnimationPlayer: (child as AnimationPlayer).stop()
		if child is GPUParticles3D: (child as GPUParticles3D).emitting = false
		if child is CPUParticles3D: (child as CPUParticles3D).emitting = false
		if child is GPUParticles3D or child is CPUParticles3D: (child as Node3D).visible = false
		if child is Node3D and (String(child.name).contains("VFX") or String(child.name).contains("StateRoot")): (child as Node3D).visible = false
		_disable_preview_runtime_nodes(child)

func _cell_spacing() -> float:

	var origin := _terrain.call("get_surface_world_position", Vector2i(0, 0)) as Vector3
	var next := _terrain.call("get_surface_world_position", Vector2i(1, 0)) as Vector3
	return maxf(Vector2(origin.x - next.x, origin.z - next.z).length(), 0.1)

func _level_step() -> float:

	var h0 := _terrain.call("get_proposed_surface_transform", Vector2i(0, 0), 0) as Transform3D
	var h1 := _terrain.call("get_proposed_surface_transform", Vector2i(0, 0), 1) as Transform3D
	return maxf(absf(h1.origin.y - h0.origin.y), 0.001)

func _apply_snapshot_state(view: Node3D, fact: Dictionary) -> void:

	view.set_meta("structure_id", fact["structure_id"])
	view.set_meta("source_runtime_id", fact.get("source_runtime_id", 0))
	view.set_meta("visual_status", fact.get("status", &"intact"))

func _find_committed_view(root: Node3D, structure_id: StringName) -> Node3D:

	for child in root.get_children():
		if child.get_meta("structure_id", &"") == structure_id: return child as Node3D
	return null

func _warn_once(key: StringName, text: String) -> void:

	if _warnings.has(key): return
	_warnings[key] = true
	push_warning("[STRUCTURE PRESENTATION] %s" % text)
