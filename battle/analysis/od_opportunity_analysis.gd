extends RefCounted
## Current public geometry and real eligibility, kept separate. Never executes.
const Resolver := preload("res://core/battle/od_release_resolver.gd")

func inspect(b: Variant) -> Dictionary:
	var result := {"turn_open": false, "heat": 0, "threshold": 0, "points": 0, "knights": []}
	if b == null or b.context == null: return result
	var economy: Dictionary = b.get_command_economy_snapshot("player")
	result.turn_open = bool(economy.get("turn_open", false))
	result.heat = b.context.od_mode.current_od
	result.threshold = b.od_release_rules.get_readiness_threshold()
	result.points = int(economy.get("current_points", 0))
	if not result.turn_open: return result
	var resolver := Resolver.new()
	for actor: CardData in b.context.player.field:
		if not is_instance_valid(actor) or not actor.piece_enabled or actor.piece_type != &"knight": continue
		var plan: Dictionary = resolver.build_source_plan(b, actor, b.od_release_rules)
		var live: Dictionary = b.get_od_release_source_status(actor)
		var row := {"id": actor.card_id, "runtime_id": actor.get_instance_id(), "name": actor.get_display_name(),
			"release_ready": bool(live.get("ok", false)), "release_reason": str(live.get("reason_code", &"")),
			"geometry_ready": bool(plan.get("ok", false)), "geometry_reason": str(plan.get("reason_code", &"")),
			"heat_gap": maxi(0, result.threshold - result.heat), "command_cost": int(plan.get("command_cost", 0)),
			"command_gap": maxi(0, int(plan.get("command_cost", 0)) - result.points),
			"category": "source_unavailable", "hit_cells": 0, "unknown_cells": 0, "landings": []}
		if plan.get("ok", false):
			var special: bool = b.get_garrison_state_for_unit(actor).get("state") == &"active" or not b._get_bishop_enchant(actor).is_empty()
			for cell: Vector2i in plan.get("legal_cells", []):
				var targets: Array = [] if special else b.get_legal_attack_targets(actor, cell, false)
				var target: CardData = targets[0] if not targets.is_empty() else null
				row.landings.append({"cell": [cell.x, cell.y], "prediction_available": not special,
					"target_runtime_id": target.get_instance_id() if target != null else 0,
					"target_name": target.get_display_name() if target != null else ""})
				if target != null: row.hit_cells += 1
				if special: row.unknown_cells += 1
			if special: row.category = "special_range_unknown"
			elif row.hit_cells == 0: row.category = "movement_only"
			elif row.release_ready: row.category = "hit_ready"
			elif row.heat_gap > 0 and row.command_gap > 0: row.category = "hit_blocked_both"
			elif row.heat_gap > 0: row.category = "hit_blocked_heat"
			elif row.command_gap > 0: row.category = "hit_blocked_commands"
			else: row.category = "hit_blocked_other"
		result.knights.append(row)
	return result
