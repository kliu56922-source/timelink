extends RefCounted
## Opt-in evidence ledger for the GB3F ritual finisher trial.

var _attacker_ids: Array[int] = []
var _garrison_by_unit: Dictionary = {}
var _control_transactions: Dictionary = {}
var _used := false
var _source_names: Dictionary = {}
var _payoff_profile: StringName = &"original"

## Trial configuration freezes as soon as preparation is invested.
func configure_payoff_profile(profile: StringName) -> bool:
	if profile not in [&"original", &"prepared_breach"] or _used or not _attacker_ids.is_empty() or not _garrison_by_unit.is_empty() or not _control_transactions.is_empty():
		return false
	_payoff_profile = profile
	return true

func record_attack(unit_id: int, source_name: String = "") -> void:
	if unit_id > 0 and not _attacker_ids.has(unit_id):
		_attacker_ids.append(unit_id)
		_source_names[unit_id] = source_name

func record_garrison(unit_id: int, structure_id: StringName, source_name: String = "") -> void:
	if unit_id > 0 and structure_id != &"":
		_garrison_by_unit[unit_id] = structure_id
		_source_names[unit_id] = source_name

func record_control(transaction_id: StringName, source_name: String = "") -> void:
	if transaction_id != &"":
		_control_transactions[transaction_id] = source_name

func snapshot(active_unit_ids: Array[int], active_garrison_ids: Array[int], depth: int, max_depth: int) -> Dictionary:
	# Successful preparation remains invested even if its unit later falls.
	# Current participants are reported separately so the presentation can show survivors.
	var attackers: Array[int] = _attacker_ids.duplicate()
	var guards: Array[int] = []
	for unit_id in _garrison_by_unit:
		guards.append(unit_id)
	var living_attackers: Array[int] = []
	for unit_id in attackers:
		if active_unit_ids.has(unit_id):
			living_attackers.append(unit_id)
	var living_guards: Array[int] = []
	for unit_id in guards:
		if active_unit_ids.has(unit_id) and active_garrison_ids.has(unit_id):
			living_guards.append(unit_id)
	var attack_ready := attackers.size() >= 2
	var guard_ready := not guards.is_empty() and not _control_transactions.is_empty()
	var paths: Array[String] = []
	if not _used:
		paths.append("early")
		if attack_ready:
			paths.append("attack")
		if guard_ready:
			paths.append("guard")
	var effects := {
		"early": {"damage": 4, "draw": 1, "unit_damage": 0, "shield": 0, "boss_od_reduce": 0},
		"attack": {"damage": 7, "draw": 2, "unit_damage": 2, "shield": 0, "boss_od_reduce": 0},
		"guard": {"damage": 5, "draw": 2, "unit_damage": 0, "shield": 10, "boss_od_reduce": 3},
	}
	if _payoff_profile == &"prepared_breach":
		for path in ["attack", "guard"]:
			effects[path]["bypass_boss_shield"] = true
	return {"available_paths": paths, "attack_ready": attack_ready, "guard_ready": guard_ready,
		"attack_participants": attackers, "guard_participants": guards,
		"attack_sources": attackers.map(func(id: int): return str(_source_names.get(id, ""))),
		"guard_sources": guards.map(func(id: int): return str(_source_names.get(id, ""))),
		"control_sources": _control_transactions.values(), "guard_structures": _garrison_by_unit.values(),
		"attack_count": attackers.size(), "garrison_count": guards.size(), "control_count": _control_transactions.size(),
		"living_attack_participants": living_attackers, "living_guard_participants": living_guards,
		"path_effects": effects, "payoff_profile": str(_payoff_profile),
		"overcharge_available": not _used and depth >= 0 and depth + 2 <= max_depth,
		"overcharge_depth_after": mini(max_depth, depth + 2), "used": _used}

func mark_used() -> void:
	_used = true
