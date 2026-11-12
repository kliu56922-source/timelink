extends RefCounted
## 163: keep visible Boss volume and rupture payoff, shorten passive shield cleanup.
static func values() -> Dictionary:
	var result: Dictionary=preload("res://core/config/triple_weakpoint_profile.gd").values()
	result.phase_locks[0].shield_gain=3
	result.phase_locks[1].shield_gain=4
	return result
