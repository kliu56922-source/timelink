extends RefCounted
class_name BossTacticalAIPlanner

var _profile: RefCounted


func _init(profile: RefCounted) -> void:
	_profile = profile


func choose_action(snapshot: Dictionary, seed: int = 0) -> Dictionary:
	var ranked := rank_candidates(snapshot, seed)
	if ranked.is_empty():
		var candidates: Array = snapshot.get("candidates", [])
		var reason := "no_legal_action" if candidates.is_empty() else "no_affordable_action"
		return {
			"command_id": "pass",
			"actor_runtime_id": 0,
			"authoritative_cost": 0,
			"score": 0,
			"reason_code": reason,
		}
	return ranked[0].duplicate(true)


func rank_candidates(snapshot: Dictionary, seed: int = 0) -> Array[Dictionary]:
	var zone: String = str(snapshot.get("zone", "Calm"))
	var current_points: int = int(snapshot.get("current_points", 0))
	var result: Array[Dictionary] = []
	for raw in snapshot.get("candidates", []):
		if not raw is Dictionary:
			continue
		var candidate: Dictionary = (raw as Dictionary).duplicate(true)
		if not bool(candidate.get("legal", false)):
			continue
		var cost: int = int(candidate.get("authoritative_cost", 0))
		if cost > current_points:
			continue
		var score := _score_candidate(candidate, zone)
		if score < _profile.get_minimum_score():
			continue
		candidate["score"] = score
		candidate["reason_code"] = "selected"
		candidate["_tie_break"] = _stable_tie_break(candidate, seed)
		# PHASE58_BEGIN_ORDER_KEY
		candidate["_tie_key"] = _stable_choice_key(candidate)
		# PHASE58_END_ORDER_KEY
		result.append(candidate)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_score: int = int(a.get("score", 0))
		var b_score: int = int(b.get("score", 0))
		if a_score != b_score:
			return a_score > b_score
		# PHASE58_BEGIN_COLLISION
		if int(a.get("_tie_break",0))==int(b.get("_tie_break",0)):
			return str(a.get("_tie_key",""))<str(b.get("_tie_key",""))
		# PHASE58_END_COLLISION
		return int(a.get("_tie_break", 0)) < int(b.get("_tie_break", 0))
	)
	for candidate in result:
		candidate.erase("_tie_break")
		# PHASE58_BEGIN_ERASE_KEY
		candidate.erase("_tie_key")
		# PHASE58_END_ERASE_KEY
	return result


func _score_candidate(candidate: Dictionary, zone: String) -> int:
	var command_id: String = str(candidate.get("command_id", ""))
	var weight_key := "skill" if command_id == "active_skill" else command_id
	var score: int = _profile.get_weight(zone, weight_key)
	score -= int(candidate.get("authoritative_cost", 0)) * _profile.get_weight(zone, "cost_penalty")
	if bool(candidate.get("is_lethal", false)):
		score += _profile.get_weight(zone, "lethal")
	if bool(candidate.get("is_kill", false)):
		score += _profile.get_weight(zone, "kill")
	if bool(candidate.get("protects_core", false)):
		score += _profile.get_weight(zone, "protect_core")
	if bool(candidate.get("advances", false)):
		score += _profile.get_weight(zone, "advance")
	if bool(candidate.get("retreats", false)):
		score += _profile.get_weight(zone, "retreat")
	score += int(candidate.get("threat_value", 0)) * _profile.get_weight(zone, "threat")
	score += int(candidate.get("tactical_value", 0))
	return score


func _stable_tie_break(candidate: Dictionary, seed: int) -> int:
	# PHASE58_BEGIN_SPATIAL_HASH
	if not str(candidate.get("actor_stable_key","")).is_empty():
		var stable_text: String=_stable_choice_key(candidate)+"|"+str(seed+_profile.get_seed_salt())
		var stable_checksum := 0
		for byte in stable_text.to_utf8_buffer():stable_checksum=int((stable_checksum*131+int(byte))&0x7fffffff)
		return stable_checksum
	# PHASE58_END_SPATIAL_HASH
	var text := "%s|%s|%s|%s|%d" % [
		str(candidate.get("command_id", "")),
		str(candidate.get("actor_runtime_id", 0)),
		str(candidate.get("target_runtime_id", 0)),
		str(candidate.get("target_cell", Vector2i(-1, -1))),
		seed + _profile.get_seed_salt(),
	]
	var checksum: int = 0
	for byte in text.to_utf8_buffer():
		checksum = int((checksum * 131 + int(byte)) & 0x7fffffff)
	return checksum

# PHASE58_BEGIN_CHOICE_KEY
func _stable_choice_key(candidate: Dictionary) -> String:
	var actor: String=str(candidate.get("actor_stable_key",""))
	if actor.is_empty():actor=str(candidate.get("actor_runtime_id",0))
	var target: String=str(candidate.get("target_stable_key",candidate.get("target_runtime_id",0)))
	return "%s|%s|%s|%s|%s"%[str(candidate.get("command_id","")),actor,target,str(candidate.get("target_cell",Vector2i(-1,-1))),str(candidate.get("target_kind",""))]
# PHASE58_END_CHOICE_KEY
