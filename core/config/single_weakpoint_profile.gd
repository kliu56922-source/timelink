extends RefCounted
## 162A initialization only. Not the three-part encounter or a balance release.
static func values() -> Dictionary:
	return {"player_hp":30,"boss_hp":40,"phase_locks":[{"phase":2,"hp_threshold":26,"shield_gain":5},{"phase":3,"hp_threshold":12,"shield_gain":8}]}
