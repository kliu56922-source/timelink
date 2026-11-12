extends RefCounted
## Opt-in audit choice only. Holding sacrifices current heat conversion/layer gain.
const LandingSelector := preload("res://battle/analysis/od_current_hit_choice.gd")

func inspect(b: Variant) -> Dictionary:
	var result := {"hold": false, "reason": "unavailable", "source_runtime_id": 0,
		"od_cost": 0, "command_cost": 0, "known_empty_cells": 0, "cells": []}
	if b == null or b.context == null: return result
	if b.context.is_abyss_locked(): result.reason = "recovery_priority"; return result
	var reward: Dictionary = b.get_final_convergence_status("player")
	if not reward.get("used",false) and reward.get("ok",false) and (reward.get("attack_ready",false) or reward.get("guard_ready",false)):
		result.reason = "prepared_reward_priority"; return result
	var ordinary: Dictionary = b.get_od_release_status("player")
	if not ordinary.get("ok",false): return result
	for source: CardData in ordinary.get("sources",[]):
		var plan: Dictionary = b.get_od_release_source_status(source)
		if not plan.get("ok",false): continue
		var targets: Array = plan.get("legal_targets",[]).duplicate()
		if targets.is_empty():
			targets = plan.get("legal_cells",[]).duplicate()
			targets.sort_custom(func(a,b): return a.y < b.y if a.y != b.y else a.x < b.x)
		if targets.is_empty(): continue
		var selected: Variant = targets[0]
		if source.piece_type == &"knight": selected = LandingSelector.new().choose(b,source,targets,&"current-hit")
		var target_status: Dictionary = b.get_od_release_target_status(source,selected)
		if not target_status.get("ok",false): continue
		result.source_runtime_id = source.get_instance_id()
		result.od_cost = int(target_status.get("od_cost",0))
		result.command_cost = int(target_status.get("command_cost",0))
		if source.piece_type != &"knight": result.reason = "other_source_first"; return result
		for cell: Vector2i in targets:
			var q: Dictionary = b.get_knight_od_landing_preview(source,cell)
			var known: bool = bool(q.get("ok",false)) and bool(q.get("prediction_available",false))
			var has_target: bool = is_instance_valid(q.get("target"))
			result.cells.append({"cell":[cell.x,cell.y],"known":known,"target_runtime_id":q.target.get_instance_id() if has_target else 0})
			if not known: result.reason = "unknown_current_effect"; return result
			if has_target: result.reason = "known_hit"; return result
			result.known_empty_cells += 1
		result.hold = result.known_empty_cells > 0
		result.reason = "known_empty_conversion_tradeoff"
		return result
	return result
