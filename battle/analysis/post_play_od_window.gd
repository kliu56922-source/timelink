extends RefCounted
## Current facts only. The caller must establish an actual completed card play.
const Tradeoff := preload("res://battle/analysis/empty_knight_od_tradeoff.gd")

func inspect(b: Variant, successful_play := false) -> Dictionary:
	var result := {"eligible": false, "reason": "unsuccessful_play", "source_runtime_id": 0,
		"target_runtime_id": 0, "cell": [], "od_cost": 0, "command_cost": 0}
	if not successful_play: return result
	var q: Dictionary = Tradeoff.new().inspect(b)
	for key in ["reason", "source_runtime_id", "od_cost", "command_cost"]: result[key] = q[key]
	if q.reason != "known_hit": return result
	var hit: Dictionary = q.cells[-1]
	result.eligible = true
	result.target_runtime_id = hit.target_runtime_id
	result.cell = hit.cell.duplicate()
	return result
