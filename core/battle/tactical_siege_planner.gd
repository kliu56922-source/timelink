extends RefCounted
class_name TacticalSiegePlanner
## Pure values only. The facade owns identity, readiness, reach and affordability.

static func entry_edges(source_cell: Vector2i, target_cell: Vector2i) -> Array[StringName]:
	var delta := source_cell - target_cell
	var result: Array[StringName] = []
	if delta == Vector2i.ZERO:
		return result
	if absi(delta.x) >= absi(delta.y):
		result.append(&"east" if delta.x > 0 else &"west")
	if absi(delta.y) >= absi(delta.x):
		result.append(&"south" if delta.y > 0 else &"north")
	return result

static func plan_attack(snapshot: Dictionary) -> Dictionary:
	var requested: Dictionary = snapshot.get("requested_target", {}).duplicate(true)
	var result := {"ok": false, "reason_code": &"siege_target_kind_invalid", "actor_runtime_id": 0,
		"requested_target": requested, "resolved_target": requested.duplicate(true), "canonical_edge": &"",
		"cover_reason": &"none", "structure_steps": 0, "unit_damage": 0, "hits": [], "costs": {}, "expectations": {}}
	var kind: StringName = requested.get("target_kind", &"")
	if kind not in [&"structure_core", &"structure_module", &"unit"]:
		return result
	var source: Vector2i = snapshot.get("source_cell", Vector2i(-1, -1))
	var target: Vector2i = snapshot.get("target_cell", Vector2i(-1, -1))
	var edges := entry_edges(source, target)
	if edges.is_empty():
		result.reason_code = &"siege_out_of_reach"
		return result
	if kind == &"structure_module" and not edges.has(requested.get("edge", &"")):
		result.reason_code = &"siege_edge_not_facing_source"
		return result
	var garrison: Dictionary = snapshot.get("garrison", {})
	var can_cover: bool = kind == &"structure_core" or (kind == &"unit" \
		and garrison.get("state") == &"active" and garrison.get("parent_cell") == target \
		and garrison.get("unit_runtime_id") == requested.get("unit_runtime_id") \
		and garrison.get("structure_id") == requested.get("structure_id"))
	var candidates: Array[Dictionary] = []
	for module: Dictionary in snapshot.get("modules", []):
		if module.get("structure_id") != requested.get("structure_id") or int(module.get("integrity_current", 0)) <= 0:
			continue
		if module.get("module_kind") not in [&"wall", &"gatehouse"] or not edges.has(module.get("edge")):
			continue
		if String(module.get("canonical_edge", &"")).is_empty():
			continue
		candidates.append(module)
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return String(a.canonical_edge) < String(b.canonical_edge))
	var bishop_profile: Dictionary = snapshot.get("bishop_profile", {})
	if not bishop_profile.is_empty() and kind == &"structure_module" \
	and (candidates.is_empty() or candidates[0].get("module_id") != requested.get("module_id")):
		result.reason_code = &"siege_edge_not_facing_source"
		return result
	var over_wall: bool = int(snapshot.get("source_height", -1)) > int(snapshot.get("target_height", -1)) + 1
	if can_cover and not over_wall and not candidates.is_empty():
		result.resolved_target = candidates[0].get("target_ref", {}).duplicate(true)
		result.canonical_edge = candidates[0].canonical_edge
		result.cover_reason = &"entry_wall"
	elif kind == &"structure_module":
		result.canonical_edge = requested.get("canonical_edge", &"")
	elif can_cover and over_wall:
		result.cover_reason = &"above_wall"
	result.ok = true
	result.reason_code = &"ok"
	if result.resolved_target.get("target_kind") != &"unit":
		result.structure_steps = int(snapshot.get("profile", {}).get("structure_steps", 0))
		if result.resolved_target.get("target_kind") == &"structure_module" and not bishop_profile.is_empty():
			result.structure_steps = int(bishop_profile.get("structure_steps", 0))
	return result.duplicate(true)


## One cast, one locked secondary identity. No partial damage carries between hits.
## The facade supplies values from validated owners and keeps identity validation.
static func plan_p18_hits(snapshot: Dictionary, hits: Array[int]) -> Dictionary:
	var scale: int = int(snapshot.get("hp_per_integrity", 0))
	var wall: int = int(snapshot.get("wall_integrity", 0))
	var kind: StringName = snapshot.get("secondary_kind", &"none")
	var hp: int = int(snapshot.get("secondary_hp", 0)) if kind == &"unit" else 0
	var core: int = int(snapshot.get("secondary_integrity", 0)) if kind == &"core" else 0
	var result := {"ok": false, "reason_code": &"siege_hit_input_invalid", "wall_after": wall,
		"secondary_hp_after": hp, "secondary_integrity_after": core, "hits": []}
	if scale <= 0 or wall < 0 or hp < 0 or core < 0 or kind not in [&"unit", &"core", &"none"]:
		return result
	for damage: int in hits:
		if damage < 0:
			return result
	var facts: Array[Dictionary] = []
	for damage: int in hits:
		var before_wall := wall
		var wall_damage: int = mini(wall, ceili(float(damage) / scale))
		wall -= wall_damage
		var overflow: int = maxi(0, damage - before_wall * scale) if wall == 0 else 0
		var unit_damage: int = mini(hp, overflow) if kind == &"unit" else 0
		var core_damage: int = mini(core, ceili(float(overflow) / scale)) if kind == &"core" else 0
		hp -= unit_damage
		core -= core_damage
		var reason: StringName = &""
		if damage == 0:
			reason = &"zero_damage"
		elif wall_damage == 0 and unit_damage == 0 and core_damage == 0:
			reason = &"no_secondary" if kind == &"none" else &"secondary_defeated"
		elif overflow == 0:
			reason = &"wall_absorbed"
		facts.append({"damage": damage, "wall_before": before_wall, "wall_damage": wall_damage,
			"wall_after": wall, "overflow": overflow, "unit_damage": unit_damage, "core_damage": core_damage,
			"secondary_hp_after": hp, "secondary_integrity_after": core, "empty_reason": reason})
	result.ok = true
	result.reason_code = &"ok"
	result.wall_after = wall
	result.secondary_hp_after = hp
	result.secondary_integrity_after = core
	result.hits = facts
	return result
