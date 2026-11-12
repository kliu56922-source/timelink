extends RefCounted
## Opening-only encounter tuning. Previous practice profiles remain independent.
static func values() -> Dictionary:
	return {"player_hp":30,"boss_hp":10,"phase_locks":[{"phase":2,"hp_threshold":7,"shield_gain":5},{"phase":3,"hp_threshold":3,"shield_gain":8}]}
