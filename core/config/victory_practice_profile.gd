extends RefCounted
## Separate shorter practice encounter. Original demo profile remains80/55.
const BOSS_HP:=40
static func practice_encounter(base: Dictionary) -> Dictionary:
	var result:=base.duplicate(true)
	result.boss_start_hp=BOSS_HP
	result.phase_locks=[{"phase":2,"hp_threshold":26,"shield_gain":5},{"phase":3,"hp_threshold":12,"shield_gain":8}]
	return result
