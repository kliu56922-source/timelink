extends RefCounted
class_name ConfigValidator

## Phase 25A: 配置表校验器
## 检查字段、类型、范围、引用、乱码，返回错误列表。

const Registry := preload("res://core/config/config_registry.gd")
const BossCardDeckClass := preload("res://core/deck/boss_card_library.gd")
const TacticalSiegeRuleSnapshotClass := preload("res://core/config/tactical_siege_rule_snapshot.gd")

static var _errors: Array[String] = []

# 常见乱码 marker（UTF-8 被误解释为 GBK/ANSI 后的特征字符）
const MOJIBAKE_MARKERS := ["锟", "鈥", "閳", "鐔", "钃", "\uFFFD"]


# ── 数值帮助方法：Godot JSON.parse 可能将整数解析为 float (1.0) ──

## 检查值是否为整型或可无损转 int 的 float
static func _is_int_like(val) -> bool:
	if val is int:
		return true
	if val is float:
		return val == float(int(val))
	return false

## 安全转为 int
static func _as_int(val, default: int = 0) -> int:
	if val is int:
		return val
	if val is float:
		return int(val)
	return default

## 比较两个数组是否包含相同整数序列
static func _int_array_equals(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i in range(a.size()):
		if _as_int(a[i]) != _as_int(b[i]):
			return false
	return true


static func validate_all() -> Array[String]:
	_errors.clear()
	if not Registry.is_loaded():
		_errors.append("[VALIDATOR] ConfigRegistry not loaded — call load_all() first")
		return _errors.duplicate()

	_validate_battle_rules()
	_validate_od_depth_rules()
	_validate_encounter()
	_validate_boss_deck()
	_validate_monster_combat_rules()
	_validate_combat_presentation()
	_validate_od_core_commands()
	_validate_od_companion_presentation()
	_validate_tactical_grid_rules()
	_validate_tactical_grid_presentation()
	_validate_tactical_unit_patterns()
	_validate_tactical_core_facing_rules()
	_validate_card_piece_traits()
	_errors.append_array(validate_od_release_rules_table(Registry.get_table("od_release_rules")))
	_errors.append_array(validate_od_presentation_rules_table(Registry.get_table("od_presentation_rules")))  # Phase 27K-R0
	_errors.append_array(validate_od_flow_feedback_rules_table(Registry.get_table("od_flow_feedback_rules")))  # Phase 27K-R1-A
	_validate_localization()
	_errors.append_array(validate_boss_tactical_ai_table(Registry.get_table("boss_tactical_ai")))
	_errors.append_array(validate_tactical_structure_rules_table(Registry.get_table("tactical_structure_rules")))  # Phase C
	_errors.append_array(validate_tactical_structure_presentation_table(Registry.get_table("tactical_structure_presentation")))  # Phase C presentation
	_errors.append_array(validate_tactical_garrison_rules_table(Registry.get_table("tactical_garrison_rules")))  # Phase D1

	if _errors.is_empty():
		print_rich("[color=green][CONFIG] Validation PASS[/color]")
	else:
		for e in _errors:
			print_rich("[color=yellow]%s[/color]" % e)
	return _errors.duplicate()


## Called by the E factory, not legacy validate_all (which drives old battle fallback).
static func validate_tactical_siege_rules_table(table: Dictionary) -> Array[String]:
	var snapshot := TacticalSiegeRuleSnapshotClass.new(table)
	var errors: Array[String] = []
	errors.assign(snapshot.get_snapshot().validation_errors)
	return errors


# ── battle_rules ──

static func _validate_battle_rules() -> void:
	var t := Registry.get_table("battle_rules")
	if t.is_empty():
		_errors.append("[battle_rules] Table missing")
		return

	# schema_version
	var sv = t.get("schema_version", null)
	if sv == null or not _is_int_like(sv):
		_errors.append("[battle_rules] schema_version missing or not int")
	else:
		if _as_int(sv) < 1:
			_errors.append("[battle_rules] schema_version must be >= 1")

	# starting_hand_size
	var shs = t.get("starting_hand_size", null)
	if shs == null or not _is_int_like(shs):
		_errors.append("[battle_rules] starting_hand_size missing or not int")
	else:
		if _as_int(shs) < 1:
			_errors.append("[battle_rules] starting_hand_size must be >= 1, got %d" % _as_int(shs))

	# max_hand_size
	var mhs = t.get("max_hand_size", null)
	if mhs == null or not _is_int_like(mhs):
		_errors.append("[battle_rules] max_hand_size missing or not int")
	else:
		if _as_int(mhs) < 1 or _as_int(mhs) > 12:
			_errors.append("[battle_rules] max_hand_size must be 1-12, got %d" % _as_int(mhs))
		# cross-field check
		if _is_int_like(shs) and _as_int(shs) > _as_int(mhs):
			_errors.append("[battle_rules] starting_hand_size (%d) must be <= max_hand_size (%d)" % [_as_int(shs), _as_int(mhs)])

	# player_start_hp
	var pshp = t.get("player_start_hp", null)
	if pshp == null or not _is_int_like(pshp):
		_errors.append("[battle_rules] player_start_hp missing or not int")
	else:
		if _as_int(pshp) <= 0:
			_errors.append("[battle_rules] player_start_hp must be > 0, got %d" % _as_int(pshp))

	# turn_draw_count
	var tdc = t.get("turn_draw_count", null)
	if tdc == null or not _is_int_like(tdc):
		_errors.append("[battle_rules] turn_draw_count missing or not int")
	else:
		if _as_int(tdc) < 0:
			_errors.append("[battle_rules] turn_draw_count must be >= 0, got %d" % _as_int(tdc))

	# fatigue_base_damage
	var fbd = t.get("fatigue_base_damage", null)
	if fbd == null or not _is_int_like(fbd):
		_errors.append("[battle_rules] fatigue_base_damage missing or not int")
	else:
		if _as_int(fbd) < 1:
			_errors.append("[battle_rules] fatigue_base_damage must be >= 1, got %d" % _as_int(fbd))


# ── od_depth_rules ──

const REQUIRED_ZONE_IDS: Array[String] = ["Calm", "Heated", "Overdrive"]

static func _validate_od_depth_rules() -> void:
	var t := Registry.get_table("od_depth_rules")
	if t.is_empty():
		_errors.append("[od_depth_rules] Table missing")
		return

	var sv = t.get("schema_version", null)
	if sv == null or not _is_int_like(sv):
		_errors.append("[od_depth_rules] schema_version missing or not int")

	var od_max = t.get("od_max", null)
	var od_max_int := _as_int(od_max, -1) if _is_int_like(od_max) else -1
	if od_max == null or not _is_int_like(od_max):
		_errors.append("[od_depth_rules] od_max missing or not int")
	else:
		if od_max_int <= 0:
			_errors.append("[od_depth_rules] od_max must be > 0, got %d" % od_max_int)

	# ── zones: Phase 25B 严格校验 ──
	var zones: Array = t.get("zones", [])
	if zones.is_empty():
		_errors.append("[od_depth_rules] zones empty or missing")
	else:
		# 1. 必须恰好 3 个区段
		if zones.size() != 3:
			_errors.append("[od_depth_rules] zones must have exactly 3 entries, got %d" % zones.size())

		var zone_ids: Array[String] = []
		for i in range(zones.size()):
			var z = zones[i]
			if not z is Dictionary:
				_errors.append("[od_depth_rules] zones[%d] is not a Dictionary" % i)
				continue
			var zid: String = z.get("id", "")
			if zid == "":
				_errors.append("[od_depth_rules] zones[%d] missing id" % i)
				continue
			zone_ids.append(zid)

			# 2. ID 必须按顺序匹配 REQUIRED_ZONE_IDS
			if i < REQUIRED_ZONE_IDS.size() and zid != REQUIRED_ZONE_IDS[i]:
				_errors.append("[od_depth_rules] zones[%d] expected id='%s', got '%s'" % [i, REQUIRED_ZONE_IDS[i], zid])

			var zmin = z.get("min", null)
			var zmax = z.get("max", null)
			if zmin == null or not _is_int_like(zmin):
				_errors.append("[od_depth_rules] zones[%d] (%s) min missing or not int" % [i, zid])
			if zmax == null or not _is_int_like(zmax):
				_errors.append("[od_depth_rules] zones[%d] (%s) max missing or not int" % [i, zid])

			if _is_int_like(zmin) and _is_int_like(zmax):
				var zmin_i := _as_int(zmin)
				var zmax_i := _as_int(zmax)

				# 3. min <= max
				if zmin_i > zmax_i:
					_errors.append("[od_depth_rules] zones[%d] (%s) min (%d) > max (%d)" % [i, zid, zmin_i, zmax_i])

				# 4. 第一段 min 必须为 0
				if i == 0 and zmin_i != 0:
					_errors.append("[od_depth_rules] zones[0] min must be 0, got %d" % zmin_i)

				# 5. 相邻段: next.min == previous.max + 1（无空洞无重叠）
				if i > 0:
					var prev_z = zones[i - 1]
					if prev_z is Dictionary and _is_int_like(prev_z.get("max", null)):
						var prev_max_i := _as_int(prev_z["max"])
						if zmin_i != prev_max_i + 1:
							_errors.append("[od_depth_rules] zones[%d] (%s) min=%d, expected prev_max+1=%d (gap or overlap)" % [i, zid, zmin_i, prev_max_i + 1])

			# 6. 检查重复 ID
			if zone_ids.count(zid) > 1:
				if not ("duplicate zone id: %s" % zid) in _errors:
					_errors.append("[od_depth_rules] duplicate zone id: %s" % zid)

		# 7. 末段 max 必须等于 od_max
		if zone_ids.size() >= 3 and od_max_int > 0:
			var last_z = zones[zones.size() - 1]
			if last_z is Dictionary and _is_int_like(last_z.get("max", null)):
				var last_max := _as_int(last_z["max"])
				if last_max != od_max_int:
					_errors.append("[od_depth_rules] zones last max (%d) must equal od_max (%d)" % [last_max, od_max_int])

		# 8. 检查是否缺失必需 ID
		for req_id in REQUIRED_ZONE_IDS:
			if not req_id in zone_ids:
				_errors.append("[od_depth_rules] missing required zone: %s" % req_id)

	# ── depth: Phase 25B 严格校验 ──
	var depth: Dictionary = t.get("depth", {})
	if depth.is_empty():
		_errors.append("[od_depth_rules] depth section missing or empty")
	else:
		var dmax = depth.get("max", null)
		var dmax_int := _as_int(dmax, -1) if _is_int_like(dmax) else -1
		if dmax == null or not _is_int_like(dmax):
			_errors.append("[od_depth_rules] depth.max missing or not int")
		else:
			if dmax_int <= 0:
				_errors.append("[od_depth_rules] depth.max must be > 0, got %d" % dmax_int)

		var drc = depth.get("end_turn_recover", null)
		if drc == null or not _is_int_like(drc):
			_errors.append("[od_depth_rules] depth.end_turn_recover missing or not int")
		else:
			var drc_i := _as_int(drc)
			if drc_i < 0:
				_errors.append("[od_depth_rules] depth.end_turn_recover must be >= 0, got %d" % drc_i)
			elif dmax_int > 0 and drc_i > dmax_int:
				_errors.append("[od_depth_rules] depth.end_turn_recover (%d) must be <= depth.max (%d)" % [drc_i, dmax_int])

		var dbt = depth.get("backlash_threshold", null)
		if dbt == null or not _is_int_like(dbt):
			_errors.append("[od_depth_rules] depth.backlash_threshold missing or not int")
		else:
			var dbt_i := _as_int(dbt)
			if dmax_int > 0 and dbt_i != dmax_int:
				_errors.append("[od_depth_rules] depth.backlash_threshold (%d) must equal depth.max (%d)" % [dbt_i, dmax_int])

		var dcr = depth.get("control_reduce", null)
		if dcr == null or not _is_int_like(dcr):
			_errors.append("[od_depth_rules] depth.control_reduce missing or not int")
		else:
			var dcr_i := _as_int(dcr)
			if dcr_i < 0:
				_errors.append("[od_depth_rules] depth.control_reduce must be >= 0, got %d" % dcr_i)
			elif dmax_int > 0 and dcr_i > dmax_int:
				_errors.append("[od_depth_rules] depth.control_reduce (%d) must be <= depth.max (%d)" % [dcr_i, dmax_int])

	# Phase 26A: stable monster-combat OD feedback.
	var stable_combat_od: Dictionary = t.get("stable_combat_od", {})
	if stable_combat_od.is_empty():
		_errors.append("[od_depth_rules] stable_combat_od section missing or empty")
	else:
		for field_name in [
			"first_unit_damage",
			"first_enemy_destroyed",
			"player_turn_cap",
			"boss_turn_core_damage_comeback",
		]:
			var field_value = stable_combat_od.get(field_name, null)
			if field_value == null or not _is_int_like(field_value):
				_errors.append("[od_depth_rules] stable_combat_od.%s missing or not int" % field_name)
				continue
			var field_int := _as_int(field_value)
			if field_int < 0:
				_errors.append("[od_depth_rules] stable_combat_od.%s must be >= 0, got %d" % [field_name, field_int])


# ── encounter ──

static func _validate_encounter() -> void:
	var t := Registry.get_table("encounter")
	if t.is_empty():
		_errors.append("[encounter] Table missing")
		return

	var sv = t.get("schema_version", null)
	if sv == null or not _is_int_like(sv):
		_errors.append("[encounter] schema_version missing or not int")

	var eid: String = t.get("encounter_id", "")
	if eid == "":
		_errors.append("[encounter] encounter_id empty or missing")

	var bshp = t.get("boss_start_hp", null)
	var bshp_int := _as_int(bshp, -1) if _is_int_like(bshp) else -1
	if bshp == null or not _is_int_like(bshp):
		_errors.append("[encounter] boss_start_hp missing or not int")
	else:
		if bshp_int <= 0:
			_errors.append("[encounter] boss_start_hp must be > 0, got %d" % bshp_int)

	var bso = t.get("boss_start_od", null)
	if bso == null or not _is_int_like(bso):
		_errors.append("[encounter] boss_start_od missing or not int")
	else:
		var od_max_val: int = Registry.get_value("od_depth_rules", "od_max", 10)
		if not _is_int_like(od_max_val):
			od_max_val = 10
		if _as_int(bso) < 0 or _as_int(bso) > _as_int(od_max_val, 10):
			_errors.append("[encounter] boss_start_od (%d) not in range [0, %d]" % [_as_int(bso), _as_int(od_max_val, 10)])

	var bss = t.get("boss_start_shield", null)
	if bss == null or not _is_int_like(bss):
		_errors.append("[encounter] boss_start_shield missing or not int")
	else:
		if _as_int(bss) < 0:
			_errors.append("[encounter] boss_start_shield must be >= 0, got %d" % _as_int(bss))

	# boss_name_key must exist in localization
	var bn_key: String = t.get("boss_name_key", "")
	if bn_key != "":
		var loc_table := Registry.get_table("localization")
		if not loc_table.is_empty() and not loc_table.has(bn_key):
			_errors.append("[encounter] boss_name_key '%s' missing in localization" % bn_key)

	# phase_locks
	var pl: Array = t.get("phase_locks", [])
	if not pl is Array:
		_errors.append("[encounter] phase_locks is not an array")
	else:
		var prev_phase := 0
		for i in range(pl.size()):
			var p = pl[i]
			if not p is Dictionary:
				_errors.append("[encounter] phase_locks[%d] is not a Dictionary" % i)
				continue
			var phase = p.get("phase", null)
			var hp_th = p.get("hp_threshold", null)
			var sg = p.get("shield_gain", null)

			if phase == null or not _is_int_like(phase):
				_errors.append("[encounter] phase_locks[%d] phase missing or not int" % i)
			else:
				var phase_i := _as_int(phase)
				if phase_i <= prev_phase:
					_errors.append("[encounter] phase_locks phases not increasing: %d then %d" % [prev_phase, phase_i])
				prev_phase = phase_i
			if hp_th == null or not _is_int_like(hp_th):
				_errors.append("[encounter] phase_locks[%d] hp_threshold missing or not int" % i)
			else:
				if bshp_int > 0:
					var hp_th_i := _as_int(hp_th)
					if hp_th_i < 1 or hp_th_i >= bshp_int:
						_errors.append("[encounter] phase_locks[%d] hp_threshold (%d) must be in [1, %d]" % [i, hp_th_i, bshp_int - 1])
			if sg == null or not _is_int_like(sg):
				_errors.append("[encounter] phase_locks[%d] shield_gain missing or not int" % i)


# ── boss_deck ──

const REQUIRED_BOSS_POOL_IDS: Array[String] = ["Calm", "Heated", "Overdrive"]


static func validate_boss_deck_table(table: Dictionary, supported_ids: Array[String]) -> Array[String]:
	var errors: Array[String] = []
	var schema = table.get("schema_version", null)
	if schema == null or not _is_int_like(schema) or _as_int(schema) < 1:
		errors.append("[boss_deck] schema_version missing or invalid")

	var deck_id: String = table.get("deck_id", "")
	if deck_id.is_empty():
		errors.append("[boss_deck] deck_id empty or missing")

	var pools = table.get("pools", null)
	if not pools is Dictionary:
		errors.append("[boss_deck] pools missing or not a Dictionary")
		return errors

	for zone_id in REQUIRED_BOSS_POOL_IDS:
		var entries = pools.get(zone_id, null)
		if not entries is Array or entries.is_empty():
			errors.append("[boss_deck] pool '%s' missing or empty" % zone_id)
			continue
		var seen: Array[String] = []
		for i in range(entries.size()):
			var entry = entries[i]
			if not entry is Dictionary:
				errors.append("[boss_deck] %s[%d] is not a Dictionary" % [zone_id, i])
				continue
			var card_id: String = entry.get("card_id", "")
			if card_id.is_empty():
				errors.append("[boss_deck] %s[%d] card_id empty" % [zone_id, i])
			elif card_id in seen:
				errors.append("[boss_deck] duplicate card_id '%s' in %s" % [card_id, zone_id])
			elif not card_id in supported_ids:
				errors.append("[boss_deck] unknown card_id '%s' in %s" % [card_id, zone_id])
			seen.append(card_id)
			var weight = entry.get("weight", null)
			if weight == null or not _is_int_like(weight) or _as_int(weight) < 1:
				errors.append("[boss_deck] %s[%d] weight must be an integer >= 1" % [zone_id, i])
	return errors


static func validate_boss_deck_reference(encounter: Dictionary, boss_deck: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var encounter_deck_id: String = encounter.get("boss_deck_id", "")
	var loaded_deck_id: String = boss_deck.get("deck_id", "")
	if encounter_deck_id.is_empty():
		errors.append("[encounter] boss_deck_id empty or missing")
	elif encounter_deck_id != loaded_deck_id:
		errors.append("[encounter] boss_deck_id '%s' does not resolve to '%s'" % [encounter_deck_id, loaded_deck_id])
	return errors


static func _validate_boss_deck() -> void:
	var table := Registry.get_table("boss_deck")
	_errors.append_array(validate_boss_deck_table(table, BossCardDeckClass.get_supported_card_ids()))
	_errors.append_array(validate_boss_deck_reference(Registry.get_table("encounter"), table))


# ── monster_combat_rules ──

static func validate_monster_combat_rules_table(table: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var schema_version = table.get("schema_version", null)
	if schema_version == null or not _is_int_like(schema_version):
		errors.append("[monster_combat_rules] schema_version must be an integer")
		return errors
	var sv_int: int = _as_int(schema_version)
	if sv_int < 2:
		errors.append("[monster_combat_rules] schema_version must be 2 (got %d)" % sv_int)
		return errors

	var max_attacks = table.get("max_attacks_per_turn", null)
	if max_attacks == null or not _is_int_like(max_attacks):
		errors.append("[monster_combat_rules] max_attacks_per_turn must be an integer")
	elif _as_int(max_attacks) < 1 or _as_int(max_attacks) > 3:
		errors.append("[monster_combat_rules] max_attacks_per_turn must be 1-3")

	if not (table.get("summoning_sickness_enabled", null) is bool):
		errors.append("[monster_combat_rules] summoning_sickness_enabled must be bool")

	var direct_attack = table.get("direct_attack", null)
	if not direct_attack is Dictionary:
		errors.append("[monster_combat_rules] direct_attack must be a Dictionary")
	else:
		if not (direct_attack.get("enabled", null) is bool):
			errors.append("[monster_combat_rules] direct_attack.enabled must be bool")
		var blocker: String = str(direct_attack.get("blocker", ""))
		if not blocker in ["guard_only", "any_enemy", "none", "same_lane"]:
			errors.append("[monster_combat_rules] direct_attack.blocker is unsupported: %s" % blocker)

	var guard = table.get("guard", null)
	if not guard is Dictionary:
		errors.append("[monster_combat_rules] guard must be a Dictionary")
	else:
		if not (guard.get("forces_targeting", null) is bool):
			errors.append("[monster_combat_rules] guard.forces_targeting must be bool")
		var scope: String = str(guard.get("scope", "same_and_adjacent"))
		if not scope in ["same_and_adjacent", "same_lane", "all"]:
			errors.append("[monster_combat_rules] guard.scope is unsupported: %s" % scope)

	var resolution_mode: String = str(table.get("resolution_mode", ""))
	if resolution_mode not in ["simultaneous_hp", "atk_vs_def"]:
		errors.append("[monster_combat_rules] resolution_mode is unsupported: %s" % resolution_mode)

	# ── Phase 26E: schema v2 movement validation ──
	var movement = table.get("movement", null)
	if not movement is Dictionary:
		errors.append("[monster_combat_rules] movement must be a Dictionary")
	else:
		if _as_int(movement.get("lane_count", 0)) != 5:
			errors.append("[monster_combat_rules] movement.lane_count must be 5")

		var lane_count_val: int = _as_int(movement.get("lane_count", 5))

		# actions_per_turn
		var apt = movement.get("actions_per_turn", null)
		if apt == null or not _is_int_like(apt):
			errors.append("[monster_combat_rules] movement.actions_per_turn must be an integer")
		elif _as_int(apt) < 1:
			errors.append("[monster_combat_rules] movement.actions_per_turn must be >= 1")

		# self_move_action_cost
		var smac = movement.get("self_move_action_cost", null)
		if smac == null or not _is_int_like(smac):
			errors.append("[monster_combat_rules] movement.self_move_action_cost must be an integer")
		elif _as_int(smac) < 1:
			errors.append("[monster_combat_rules] movement.self_move_action_cost must be >= 1")

		# default_pattern
		var dp: String = str(movement.get("default_pattern", ""))
		var allowed: Array = movement.get("allowed_patterns", [])
		var allowed_str: Array[String] = []
		for raw in allowed:
			allowed_str.append(str(raw))
		if dp == "":
			errors.append("[monster_combat_rules] movement.default_pattern is empty")
		elif not dp in allowed_str:
			errors.append("[monster_combat_rules] movement.default_pattern '%s' not in allowed_patterns" % dp)

		# spawn_lane_order
		var order: Array = movement.get("spawn_lane_order", [])
		if order.size() != 5:
			errors.append("[monster_combat_rules] movement.spawn_lane_order must contain 5 lanes (got %d)" % order.size())
		else:
			var normalized: Array[int] = []
			for raw_lane in order:
				if not _is_int_like(raw_lane):
					errors.append("[monster_combat_rules] spawn lane must be integer-like (got %s)" % str(raw_lane))
					continue
				normalized.append(_as_int(raw_lane))
			if normalized.size() == 5:
				var all_in_range: bool = true
				for lane in normalized:
					if lane < 0 or lane >= lane_count_val:
						all_in_range = false
						break
				if not all_in_range:
					errors.append("[monster_combat_rules] spawn lanes must be 0..%d" % (lane_count_val - 1))
				var unique_lookup: Dictionary = {}
				for lane in normalized:
					unique_lookup[lane] = true
				if unique_lookup.size() != 5:
					errors.append("[monster_combat_rules] spawn lanes must be unique")

		# mobility_by_card_id — validate every card ID and pattern
		var mob: Dictionary = movement.get("mobility_by_card_id", {})
		for card_id in mob:
			var card_id_str: String = str(card_id)
			if card_id_str == "":
				errors.append("[monster_combat_rules] mobility_by_card_id has empty card ID")
			var pat: String = str(mob[card_id])
			if not pat in allowed_str:
				errors.append("[monster_combat_rules] mobility_by_card_id.%s pattern '%s' not in allowed_patterns" % [card_id_str, pat])

	# ── Phase 26E: boss_movement validation ──
	var boss_move = table.get("boss_movement", null)
	if not boss_move is Dictionary:
		errors.append("[monster_combat_rules] boss_movement must be a Dictionary")
	else:
		if not (boss_move.get("enabled", null) is bool):
			errors.append("[monster_combat_rules] boss_movement.enabled must be bool")
		if not (boss_move.get("move_or_attack", null) is bool):
			errors.append("[monster_combat_rules] boss_movement.move_or_attack must be bool")
		var tb: String = str(boss_move.get("tie_break", ""))
		if not tb in ["nearest_center_then_lower_lane", "nearest_lane", "random"]:
			errors.append("[monster_combat_rules] boss_movement.tie_break is unsupported: %s" % tb)

	return errors


static func _validate_monster_combat_rules() -> void:
	_errors.append_array(validate_monster_combat_rules_table(Registry.get_table("monster_combat_rules")))


# ── combat_presentation ──

static func validate_combat_presentation_table(table: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var schema_version = table.get("version", null)
	if schema_version == null or not _is_int_like(schema_version) or _as_int(schema_version) < 2:
		errors.append("[combat_presentation] version must be an integer >= 2")

	# Validate monster_attack section
	var monster_attack: Dictionary = table.get("monster_attack", {})
	if monster_attack.is_empty():
		errors.append("[combat_presentation] monster_attack section missing or empty")
	else:
		var duration_fields := ["target_lock", "telegraph", "lunge", "hit_pause", "reaction", "return", "destroy"]
		for field_name in duration_fields:
			var val = monster_attack.get(field_name, null)
			if val == null or not (val is float or val is int):
				errors.append("[combat_presentation] monster_attack.%s missing or not a number" % field_name)
			else:
				var fval: float = float(val)
				if fval < 0.05 or fval > 3.0:
					errors.append("[combat_presentation] monster_attack.%s=%.3f out of range [0.05, 3.0]" % [field_name, fval])

		var lunge_dist = monster_attack.get("lunge_distance", null)
		if lunge_dist == null or not (lunge_dist is float or lunge_dist is int):
			errors.append("[combat_presentation] monster_attack.lunge_distance missing or not a number")
		else:
			var ld: float = float(lunge_dist)
			if ld < 0.05 or ld > 1.0:
				errors.append("[combat_presentation] monster_attack.lunge_distance=%.3f out of range [0.05, 1.0]" % ld)

	# Validate spell_activation section
	var spell_activation: Dictionary = table.get("spell_activation", {})
	if spell_activation.is_empty():
		errors.append("[combat_presentation] spell_activation section missing or empty")
	else:
		var spell_fields := ["hand_charge", "stage_travel", "stage_hold", "resolve_hold", "graveyard_travel", "finisher_extra_hold"]
		for field_name in spell_fields:
			var val = spell_activation.get(field_name, null)
			if val == null or not (val is float or val is int):
				errors.append("[combat_presentation] spell_activation.%s missing or not a number" % field_name)
			else:
				var fval: float = float(val)
				if fval < 0.05 or fval > 3.0:
					errors.append("[combat_presentation] spell_activation.%s=%.3f out of range [0.05, 3.0]" % [field_name, fval])

	# Validate ascension section
	var ascension: Dictionary = table.get("ascension", {})
	if ascension.is_empty():
		errors.append("[combat_presentation] ascension section missing or empty")
	else:
		var asc_fields := ["charge", "swap_out", "swap_in", "settle"]
		for field_name in asc_fields:
			var val = ascension.get(field_name, null)
			if val == null or not (val is float or val is int):
				errors.append("[combat_presentation] ascension.%s missing or not a number" % field_name)
			else:
				var fval: float = float(val)
				if fval < 0.05 or fval > 3.0:
					errors.append("[combat_presentation] ascension.%s=%.3f out of range [0.05, 3.0]" % [field_name, fval])

	var orchestration: Dictionary = table.get("orchestration", {})
	var expected_phases := ["select", "commit", "convey", "resolve"]
	var expected_lanes := ["engine_lane", "board_lane", "card_lane", "audio_lane"]
	if orchestration.is_empty():
		errors.append("[combat_presentation] orchestration section missing or empty")
	else:
		if orchestration.get("phase_order", []) != expected_phases:
			errors.append("[combat_presentation] orchestration.phase_order must be select/commit/convey/resolve")
		if orchestration.get("lanes", []) != expected_lanes:
			errors.append("[combat_presentation] orchestration.lanes must be the four read-only presentation lanes")
		_validate_number_range(errors, orchestration, "micro_duration", 0.12, 0.28, "orchestration")
		_validate_number_range(errors, orchestration, "minor_duration", 0.35, 0.75, "orchestration")
		_validate_number_range(errors, orchestration, "major_duration", 0.90, 1.20, "orchestration")
		_validate_number_range(errors, orchestration, "major_hard_timeout", 1.20, 1.40, "orchestration")
		_validate_number_range(errors, orchestration, "coalescing_window", 0.01, 0.20, "orchestration")
		_validate_number_range(errors, orchestration, "fast_mode_multiplier", 0.25, 1.0, "orchestration")
		var auto_fast_threshold = orchestration.get("auto_fast_queue_threshold", null)
		if auto_fast_threshold == null or not _is_int_like(auto_fast_threshold):
			errors.append("[combat_presentation] orchestration.auto_fast_queue_threshold missing or not an integer")
		elif _as_int(auto_fast_threshold) < 2 or _as_int(auto_fast_threshold) > 12:
			errors.append("[combat_presentation] orchestration.auto_fast_queue_threshold out of range [2, 12]")
		_validate_number_range(errors, orchestration, "auto_fast_multiplier", 0.35, 0.90, "orchestration")
		_validate_number_range(errors, orchestration, "reduced_motion_duration_multiplier", 0.30, 0.80, "orchestration")
		if float(orchestration.get("major_duration", 99.0)) > float(orchestration.get("major_hard_timeout", -1.0)):
			errors.append("[combat_presentation] major_duration cannot exceed major_hard_timeout")

	var release: Dictionary = table.get("od_release_choreography", {})
	if release.is_empty():
		errors.append("[combat_presentation] od_release_choreography section missing or empty")
	else:
		var release_fields := ["commit_end", "extract_end", "conduit_end", "sigil_end", "impact_end", "settle_end"]
		var previous := -1.0
		for field_name in release_fields:
			var value = release.get(field_name, null)
			if value == null or not (value is float or value is int):
				errors.append("[combat_presentation] od_release_choreography.%s missing or not a number" % field_name)
				continue
			var time_value := float(value)
			if time_value <= previous:
				errors.append("[combat_presentation] od_release_choreography timeline must be strictly increasing at %s" % field_name)
			previous = time_value
		if previous > float(orchestration.get("major_hard_timeout", 1.40)):
			errors.append("[combat_presentation] od_release_choreography.settle_end exceeds hard timeout")
		_validate_number_range(errors, release, "board_dim_alpha", 0.0, 0.65, "od_release_choreography")

	var summon: Dictionary = table.get("monster_summon", {})
	if summon.is_empty():
		errors.append("[combat_presentation] monster_summon section missing or empty")
	else:
		var summon_fields := ["card_commit_end", "travel_end", "token_land_end", "settle_end"]
		var previous_summon := -1.0
		for field_name in summon_fields:
			var value = summon.get(field_name, null)
			if value == null or not (value is float or value is int):
				errors.append("[combat_presentation] monster_summon.%s missing or not a number" % field_name)
				continue
			var time_value := float(value)
			if time_value <= previous_summon:
				errors.append("[combat_presentation] monster_summon timeline must be strictly increasing at %s" % field_name)
			previous_summon = time_value
		_validate_number_range(errors, summon, "spawn_ring_scale", 1.0, 2.0, "monster_summon")

	var feedback: Dictionary = table.get("result_feedback", {})
	if feedback.is_empty():
		errors.append("[combat_presentation] result_feedback section missing or empty")
	else:
		for field_name in ["damage_badge_duration", "blocked_badge_duration", "status_badge_duration"]:
			_validate_number_range(errors, feedback, field_name, 0.05, 3.0, "result_feedback")
		_validate_number_range(errors, feedback, "float_distance", 0.0, 200.0, "result_feedback")
		_validate_number_range(errors, feedback, "impact_scale", 0.5, 2.0, "result_feedback")

	var sigils: Dictionary = table.get("piece_sigils", {})
	var expected_sigils := {
		"pawn": "forward_fan",
		"knight": "knight_l",
		"bishop": "diagonal_cross",
		"rook": "orthogonal_cross",
	}
	if sigils != expected_sigils:
		errors.append("[combat_presentation] piece_sigils must define only pawn/knight/bishop/rook canonical styles")

	var audio_cues: Dictionary = table.get("audio_cues", {})
	if audio_cues.is_empty():
		errors.append("[combat_presentation] audio_cues section missing or empty")
	else:
		var seen_audio_values := {}
		for raw_key in audio_cues:
			var key := str(raw_key)
			var cue := str(audio_cues[raw_key])
			if not _is_ascii_identifier(key) or not _is_ascii_identifier(cue):
				errors.append("[combat_presentation] audio cue keys and values must be non-empty ASCII identifiers: %s=%s" % [key, cue])
			if seen_audio_values.has(cue):
				errors.append("[combat_presentation] duplicate audio cue value: %s" % cue)
			seen_audio_values[cue] = true

	var accessibility: Dictionary = table.get("accessibility", {})
	if accessibility.is_empty():
		errors.append("[combat_presentation] accessibility section missing or empty")
	else:
		if not (accessibility.get("reduced_motion_default", null) is bool):
			errors.append("[combat_presentation] accessibility.reduced_motion_default must be bool")
		if not (accessibility.get("fast_mode_default", null) is bool):
			errors.append("[combat_presentation] accessibility.fast_mode_default must be bool")
		_validate_number_range(errors, accessibility, "reduced_motion_shake_scale", 0.0, 1.0, "accessibility")

	var allowed_materials := ["dark_iron", "weathered_stone", "oxidized_bronze", "dark_wood", "jade", "crystal"]
	var allowed_color_keys := ["calm", "heated", "overdrive", "finisher", "control", "depth"]
	var allowed_reveal_ratios := ["idle", "cast", "od_layer", "finisher"]
	if table.has("world_visual_language"):
		var raw_world: Variant = table.get("world_visual_language")
		if not raw_world is Dictionary:
			errors.append("[combat_presentation] world_visual_language must be a Dictionary")
		else:
			var world: Dictionary = raw_world
			var allowed_world_keys := ["materials", "function_colors", "crystal_reveal_ratio"]
			for raw_key in world:
				if not raw_key is String or str(raw_key) not in allowed_world_keys:
					errors.append("[combat_presentation] world_visual_language has unknown key '%s'" % str(raw_key))
			for required_key in allowed_world_keys:
				if not world.has(required_key):
					errors.append("[combat_presentation] world_visual_language.%s missing" % required_key)

			var raw_materials: Variant = world.get("materials", null)
			if not raw_materials is Array:
				errors.append("[combat_presentation] world_visual_language.materials must be an Array")
			else:
				var materials: Array = raw_materials
				if materials.size() != allowed_materials.size():
					errors.append("[combat_presentation] world_visual_language.materials must contain all six canonical materials")
				var seen_materials := {}
				for material in materials:
					if not material is String or str(material) not in allowed_materials:
						errors.append("[combat_presentation] world_visual_language.materials has unknown material '%s'" % str(material))
					elif seen_materials.has(str(material)):
						errors.append("[combat_presentation] world_visual_language.materials duplicates '%s'" % str(material))
					else:
						seen_materials[str(material)] = true

			var raw_colors: Variant = world.get("function_colors", null)
			if not raw_colors is Dictionary:
				errors.append("[combat_presentation] world_visual_language.function_colors must be a Dictionary")
			else:
				var colors: Dictionary = raw_colors
				for raw_key in colors:
					if not raw_key is String or str(raw_key) not in allowed_color_keys:
						errors.append("[combat_presentation] world_visual_language.function_colors has unknown key '%s'" % str(raw_key))
				for color_key in allowed_color_keys:
					if not colors.has(color_key):
						errors.append("[combat_presentation] world_visual_language.function_colors.%s missing" % color_key)
					elif not colors[color_key] is String or not _valid_html_rgb(colors[color_key]):
						errors.append("[combat_presentation] world_visual_language.function_colors.%s must be #RRGGBB" % color_key)

			var raw_ratios: Variant = world.get("crystal_reveal_ratio", null)
			if not raw_ratios is Dictionary:
				errors.append("[combat_presentation] world_visual_language.crystal_reveal_ratio must be a Dictionary")
			else:
				var ratios: Dictionary = raw_ratios
				for raw_key in ratios:
					if not raw_key is String or str(raw_key) not in allowed_reveal_ratios:
						errors.append("[combat_presentation] world_visual_language.crystal_reveal_ratio has unknown key '%s'" % str(raw_key))
				for ratio_key in allowed_reveal_ratios:
					if not ratios.has(ratio_key):
						errors.append("[combat_presentation] world_visual_language.crystal_reveal_ratio.%s missing" % ratio_key)
					elif not (ratios[ratio_key] is float or ratios[ratio_key] is int):
						errors.append("[combat_presentation] world_visual_language.crystal_reveal_ratio.%s must be a number" % ratio_key)
					else:
						var numeric_ratio := float(ratios[ratio_key])
						if is_nan(numeric_ratio) or numeric_ratio < 0.0 or numeric_ratio > 0.60:
							errors.append("[combat_presentation] world_visual_language.crystal_reveal_ratio.%s out of range [0.0, 0.60]" % ratio_key)

	var allowed_direction_ids := ["P06", "P08", "P20"]
	var allowed_templates := ["bishop_blade", "rook_relay", "kingfire_finisher"]
	var allowed_accents := ["heated", "control", "finisher"]
	var allowed_motifs := ["royal_seal", "diagonal_blade", "bishop_mark", "foundation_shadow", "orthogonal_oath", "beacon_lock", "crown_seal", "tomb_gate", "kingfire_sweep"]
	var allowed_direction_reveals := ["cast", "finisher"]
	if table.has("card_direction_profiles"):
		var raw_directions: Variant = table.get("card_direction_profiles")
		if not raw_directions is Dictionary:
			errors.append("[combat_presentation] card_direction_profiles must be a Dictionary")
		else:
			var directions: Dictionary = raw_directions
			for raw_id in directions:
				if not raw_id is String or str(raw_id) not in allowed_direction_ids:
					errors.append("[combat_presentation] card_direction_profiles has unknown stable ID '%s'" % str(raw_id))
			for card_id in allowed_direction_ids:
				if not directions.has(card_id):
					errors.append("[combat_presentation] card_direction_profiles.%s missing" % card_id)
					continue
				var raw_profile: Variant = directions[card_id]
				if not raw_profile is Dictionary:
					errors.append("[combat_presentation] card_direction_profiles.%s must be a Dictionary" % card_id)
					continue
				var profile: Dictionary = raw_profile
				var allowed_profile_keys := ["template", "accent", "commit_motif", "convey_motif", "resolve_motif", "reveal_level"]
				for raw_key in profile:
					if not raw_key is String or str(raw_key) not in allowed_profile_keys:
						errors.append("[combat_presentation] card_direction_profiles.%s has unknown key '%s'" % [card_id, str(raw_key)])
				for required_key in allowed_profile_keys:
					if not profile.has(required_key):
						errors.append("[combat_presentation] card_direction_profiles.%s.%s missing" % [card_id, required_key])
				if str(profile.get("template", "")) not in allowed_templates:
					errors.append("[combat_presentation] card_direction_profiles.%s has unknown template" % card_id)
				if str(profile.get("accent", "")) not in allowed_accents:
					errors.append("[combat_presentation] card_direction_profiles.%s has unknown accent" % card_id)
				for motif_key in ["commit_motif", "convey_motif", "resolve_motif"]:
					if str(profile.get(motif_key, "")) not in allowed_motifs:
						errors.append("[combat_presentation] card_direction_profiles.%s.%s has unknown motif" % [card_id, motif_key])
				if str(profile.get("reveal_level", "")) not in allowed_direction_reveals:
					errors.append("[combat_presentation] card_direction_profiles.%s has unknown reveal level" % card_id)

	return errors


static func _validate_number_range(errors: Array[String], section: Dictionary, field_name: String, minimum: float, maximum: float, section_name: String) -> void:
	var value = section.get(field_name, null)
	if value == null or not (value is float or value is int):
		errors.append("[combat_presentation] %s.%s missing or not a number" % [section_name, field_name])
		return
	var numeric := float(value)
	if numeric < minimum or numeric > maximum:
		errors.append("[combat_presentation] %s.%s=%.3f out of range [%.3f, %.3f]" % [section_name, field_name, numeric, minimum, maximum])


static func _is_ascii_identifier(value: String) -> bool:
	if value.is_empty():
		return false
	for index in range(value.length()):
		var code := value.unicode_at(index)
		var valid := (code >= 48 and code <= 57) or (code >= 65 and code <= 90) or (code >= 97 and code <= 122) or code == 95
		if not valid:
			return false
	return true


static func _validate_combat_presentation() -> void:
	_errors.append_array(validate_combat_presentation_table(Registry.get_table("combat_presentation")))


# ── od_core_commands ──

static func validate_od_core_commands_table(table: Dictionary, localization: Dictionary) -> Array[String]:
	var errors: Array[String] = []

	# schema_version
	var sv = table.get("schema_version", null)
	if sv == null or not _is_int_like(sv) or _as_int(sv) != 1:
		errors.append("[od_core_commands] schema_version must be 1")
		return errors

	# uses_per_player_turn
	var upt = table.get("uses_per_player_turn", null)
	if upt == null or not _is_int_like(upt):
		errors.append("[od_core_commands] uses_per_player_turn missing or not int")
	else:
		var upt_val: int = _as_int(upt)
		if upt_val < 1 or upt_val > 3:
			errors.append("[od_core_commands] uses_per_player_turn=%d must be 1..3" % upt_val)

	# commands
	var commands: Array = table.get("commands", [])
	if not commands is Array or commands.is_empty():
		errors.append("[od_core_commands] commands missing or empty")
		return errors

	var seen_ids: Dictionary = {}
	var has_surge := false
	var has_vent := false
	var has_redeploy := false
	var allowed_effects := ["temporary_attack_bonus", "depth_reduce", "forced_lane_move"]

	for cmd in commands:
		if not cmd is Dictionary:
			errors.append("[od_core_commands] non-Dictionary entry in commands")
			continue
		var cmd_id: String = str(cmd.get("id", ""))
		if cmd_id == "":
			errors.append("[od_core_commands] command missing id")
			continue
		if seen_ids.has(cmd_id):
			errors.append("[od_core_commands] duplicate command id: %s" % cmd_id)
		seen_ids[cmd_id] = true
		if cmd_id == "surge":
			has_surge = true
		if cmd_id == "vent":
			has_vent = true
		if cmd_id == "redeploy":
			has_redeploy = true

		# charge_cost
		var cost = cmd.get("charge_cost", null)
		if cost == null or not _is_int_like(cost):
			errors.append("[od_core_commands] %s: charge_cost missing or not int" % cmd_id)
		else:
			var cost_val: int = _as_int(cost)
			if cost_val < 1 or cost_val > 20:
				errors.append("[od_core_commands] %s: charge_cost=%d out of range [1,20]" % [cmd_id, cost_val])

		# name_key / description_key
		var nk: String = str(cmd.get("name_key", ""))
		var dk: String = str(cmd.get("description_key", ""))
		if nk == "":
			errors.append("[od_core_commands] %s: name_key missing or empty" % cmd_id)
		elif not localization.has(nk):
			errors.append("[od_core_commands] %s: name_key '%s' not in localization" % [cmd_id, nk])
		if dk == "":
			errors.append("[od_core_commands] %s: description_key missing or empty" % cmd_id)
		elif not localization.has(dk):
			errors.append("[od_core_commands] %s: description_key '%s' not in localization" % [cmd_id, dk])

		# usable_during_backlash
		var udb = cmd.get("usable_during_backlash", null)
		if not udb is bool:
			errors.append("[od_core_commands] %s: usable_during_backlash must be bool" % cmd_id)

		# effect
		var effect: Dictionary = cmd.get("effect", {})
		if not effect is Dictionary or effect.is_empty():
			errors.append("[od_core_commands] %s: effect missing or empty" % cmd_id)
			continue

		var eff_type: String = str(effect.get("type", ""))
		if eff_type not in allowed_effects:
			errors.append("[od_core_commands] %s: unknown effect type '%s'" % [cmd_id, eff_type])

		if eff_type != "forced_lane_move":
			var eff_amount = effect.get("amount", null)
			if eff_amount == null or not _is_int_like(eff_amount):
				errors.append("[od_core_commands] %s: effect.amount missing or not int" % cmd_id)
			else:
				var amt_val: int = _as_int(eff_amount)
				if amt_val < 1 or amt_val > 10:
					errors.append("[od_core_commands] %s: effect.amount=%d out of range [1,10]" % [cmd_id, amt_val])

		# temporary_attack_bonus requires duration == player_turn
		if eff_type == "temporary_attack_bonus":
			var dur: String = str(effect.get("duration", ""))
			if dur != "player_turn":
				errors.append("[od_core_commands] %s: duration must be 'player_turn', got '%s'" % [cmd_id, dur])

	# shipped v1 must contain surge, vent, and redeploy
	if not has_surge:
		errors.append("[od_core_commands] shipped v1 must contain 'surge' command")
	if not has_vent:
		errors.append("[od_core_commands] shipped v1 must contain 'vent' command")
	if not has_redeploy:
		errors.append("[od_core_commands] shipped v1 must contain 'redeploy' command")

	return errors


static func _validate_od_core_commands() -> void:
	_errors.append_array(validate_od_core_commands_table(
		Registry.get_table("od_core_commands"),
		Registry.get_table("localization")
	))


# ── od_companion_presentation ──

static func validate_od_companion_presentation_table(table: Dictionary) -> Array[String]:
	var errors: Array[String] = []

	# schema_version
	var sv = table.get("schema_version", null)
	if sv == null or not _is_int_like(sv):
		errors.append("[od_companion_presentation] schema_version missing or not int")
		return errors
	var sv_int: int = _as_int(sv)
	if sv_int < 1 or sv_int > 2:
		errors.append("[od_companion_presentation] schema_version must be 1 or 2 (got %d)" % sv_int)
		return errors

	# station_order
	var order: Array = table.get("station_order", [])
	var required_order := ["player_graveyard", "od_companion", "player_deck"]
	if order.size() != 3:
		errors.append("[od_companion_presentation] station_order must have exactly 3 entries (got %d)" % order.size())
	else:
		for i in range(3):
			if str(order[i]) != required_order[i]:
				errors.append("[od_companion_presentation] station_order[%d] expected '%s', got '%s'" % [i, required_order[i], str(order[i])])
		# duplicate check
		var seen: Array[String] = []
		for entry in order:
			var s: String = str(entry)
			if s in seen:
				errors.append("[od_companion_presentation] duplicate station in order: %s" % s)
			seen.append(s)

	# station_scale
	var scale: Dictionary = table.get("station_scale", {})
	for key in required_order:
		var val = scale.get(key, null)
		if val == null:
			errors.append("[od_companion_presentation] station_scale missing key: %s" % key)
		elif not (val is float or val is int):
			errors.append("[od_companion_presentation] station_scale.%s is not numeric" % key)
		else:
			var fval: float = float(val)
			if fval < 0.25 or fval > 2.0:
				errors.append("[od_companion_presentation] station_scale.%s=%.3f out of range [0.25, 2.0]" % [key, fval])

	# hitbox_size
	var hb: Dictionary = table.get("hitbox_size", {})
	if not hb is Dictionary:
		errors.append("[od_companion_presentation] hitbox_size missing or not a Dictionary")
	else:
		for axis in ["x", "y", "z"]:
			var val = hb.get(axis, null)
			if val == null:
				errors.append("[od_companion_presentation] hitbox_size.%s missing" % axis)
			elif not (val is float or val is int):
				errors.append("[od_companion_presentation] hitbox_size.%s is not numeric" % axis)
			else:
				var fval: float = float(val)
				if fval < 0.1 or fval > 4.0:
					errors.append("[od_companion_presentation] hitbox_size.%s=%.3f out of range [0.1, 4.0]" % [axis, fval])

	# label_height
	var lh = table.get("label_height", null)
	if lh == null:
		errors.append("[od_companion_presentation] label_height missing")
	elif not (lh is float or lh is int):
		errors.append("[od_companion_presentation] label_height is not numeric")
	else:
		var fval: float = float(lh)
		if fval < 0.05 or fval > 2.0:
			errors.append("[od_companion_presentation] label_height=%.3f out of range [0.05, 2.0]" % fval)

	# safe_margin_px
	var sm = table.get("safe_margin_px", null)
	if sm == null:
		errors.append("[od_companion_presentation] safe_margin_px missing")
	elif not _is_int_like(sm):
		errors.append("[od_companion_presentation] safe_margin_px is not int-like")
	else:
		var sm_val: int = _as_int(sm)
		if sm_val < 0 or sm_val > 64:
			errors.append("[od_companion_presentation] safe_margin_px=%d out of range [0, 64]" % sm_val)

	# pulse_seconds
	var ps = table.get("pulse_seconds", null)
	if ps == null:
		errors.append("[od_companion_presentation] pulse_seconds missing")
	elif not (ps is float or ps is int):
		errors.append("[od_companion_presentation] pulse_seconds is not numeric")
	else:
		var fval: float = float(ps)
		if fval < 0.05 or fval > 3.0:
			errors.append("[od_companion_presentation] pulse_seconds=%.3f out of range [0.05, 3.0]" % fval)

	# evolution_seconds
	var es = table.get("evolution_seconds", null)
	if es == null:
		errors.append("[od_companion_presentation] evolution_seconds missing")
	elif not (es is float or es is int):
		errors.append("[od_companion_presentation] evolution_seconds is not numeric")
	else:
		var fval: float = float(es)
		if fval < 0.05 or fval > 3.0:
			errors.append("[od_companion_presentation] evolution_seconds=%.3f out of range [0.05, 3.0]" % fval)

	# depth_jitter_amplitude
	var dja = table.get("depth_jitter_amplitude", null)
	if dja == null:
		errors.append("[od_companion_presentation] depth_jitter_amplitude missing")
	elif not (dja is float or dja is int):
		errors.append("[od_companion_presentation] depth_jitter_amplitude is not numeric")
	else:
		var fval: float = float(dja)
		if fval < 0.0 or fval > 0.2:
			errors.append("[od_companion_presentation] depth_jitter_amplitude=%.3f out of range [0.0, 0.2]" % fval)

	# layer_colors
	var colors: Array = table.get("layer_colors", [])
	if colors.size() != 5:
		errors.append("[od_companion_presentation] layer_colors must have exactly 5 entries (got %d)" % colors.size())
	else:
		for i in range(colors.size()):
			var color_str: String = str(colors[i])
			if not color_str.begins_with("#") or color_str.length() != 7:
				errors.append("[od_companion_presentation] layer_colors[%d] is not a valid HTML color: %s" % [i, color_str])
			else:
				# validate hex digits
				var hex_part := color_str.substr(1)
				var valid_hex := true
				for ch in hex_part:
					if not ch in "0123456789ABCDEFabcdef":
						valid_hex = false
						break
				if not valid_hex:
					errors.append("[od_companion_presentation] layer_colors[%d] has invalid hex digits: %s" % [i, color_str])

	# ── Phase 26D-R1: schema v2 新增字段 ──
	if sv_int >= 2:
		# station_visual_offset
		var visual_offset: Dictionary = table.get("station_visual_offset", {})
		if visual_offset.size() != 3:
			errors.append("[od_companion_presentation] station_visual_offset must have exactly 3 entries (got %d)" % visual_offset.size())
		for station_id in required_order:
			var vo: Dictionary = visual_offset.get(station_id, {})
			if vo.is_empty():
				errors.append("[od_companion_presentation] station_visual_offset.%s missing" % station_id)
				continue
			for axis in ["x", "y", "z"]:
				var val = vo.get(axis, null)
				if val == null:
					errors.append("[od_companion_presentation] station_visual_offset.%s.%s missing" % [station_id, axis])
				elif not (val is float or val is int):
					errors.append("[od_companion_presentation] station_visual_offset.%s.%s is not numeric" % [station_id, axis])
				else:
					var fval: float = float(val)
					if axis == "y":
						if fval < -0.25 or fval > 0.50:
							errors.append("[od_companion_presentation] station_visual_offset.%s.y=%.3f out of range [-0.25, 0.50]" % [station_id, fval])
					else:
						if fval < -8.0 or fval > 8.0:
							errors.append("[od_companion_presentation] station_visual_offset.%s.%s=%.3f out of range [-8.0, 8.0]" % [station_id, axis, fval])
		# check for unknown station IDs
		for key in visual_offset:
			if not str(key) in required_order:
				errors.append("[od_companion_presentation] station_visual_offset has unknown station: %s" % str(key))

		# floating_labels_visible
		var flv = table.get("floating_labels_visible", null)
		if not flv is bool:
			errors.append("[od_companion_presentation] floating_labels_visible must be bool (got %s)" % str(flv))

		# surface_plaque_rotation_degrees_x
		var spr = table.get("surface_plaque_rotation_degrees_x", null)
		if spr == null:
			errors.append("[od_companion_presentation] surface_plaque_rotation_degrees_x missing")
		elif not (spr is float or spr is int):
			errors.append("[od_companion_presentation] surface_plaque_rotation_degrees_x is not numeric")
		else:
			var spr_val: float = float(spr)
			if spr_val < -180.0 or spr_val > 180.0:
				errors.append("[od_companion_presentation] surface_plaque_rotation_degrees_x=%.1f out of range [-180, 180]" % spr_val)

		# deck_stack_layers
		var dsl = table.get("deck_stack_layers", null)
		if dsl == null:
			errors.append("[od_companion_presentation] deck_stack_layers missing")
		elif not _is_int_like(dsl):
			errors.append("[od_companion_presentation] deck_stack_layers is not int-like")
		else:
			var dsl_val: int = _as_int(dsl)
			if dsl_val < 1 or dsl_val > 8:
				errors.append("[od_companion_presentation] deck_stack_layers=%d out of range [1, 8]" % dsl_val)

	return errors


static func _validate_od_companion_presentation() -> void:
	_errors.append_array(validate_od_companion_presentation_table(Registry.get_table("od_companion_presentation")))


# ── tactical grid rules (Phase 27A) ──

static func validate_tactical_grid_rules_table(table: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var prefix := "[tactical_grid_rules]"

	# schema_version must be 1
	var sv = table.get("schema_version", null)
	if sv == null or not _is_int_like(sv):
		errors.append("%s schema_version missing or not int" % prefix)
		return errors
	var sv_int: int = _as_int(sv)
	if sv_int != 1:
		errors.append("%s schema_version must be 1 (got %d)" % [prefix, sv_int])
		return errors

	# columns must be 5
	var cols = table.get("columns", null)
	if cols == null or not _is_int_like(cols):
		errors.append("%s columns missing or not int" % prefix)
	elif _as_int(cols) != 5:
		errors.append("%s columns must be 5 (got %d)" % [prefix, _as_int(cols)])

	# ranks must be 5
	var rks = table.get("ranks", null)
	if rks == null or not _is_int_like(rks):
		errors.append("%s ranks missing or not int" % prefix)
	elif _as_int(rks) != 5:
		errors.append("%s ranks must be 5 (got %d)" % [prefix, _as_int(rks)])

	# center_rank must be 2
	var cr = table.get("center_rank", null)
	if cr == null or not _is_int_like(cr):
		errors.append("%s center_rank missing or not int" % prefix)
	elif _as_int(cr) != 2:
		errors.append("%s center_rank must be 2 (got %d)" % [prefix, _as_int(cr)])

	# summon_ranks
	var sr: Dictionary = table.get("summon_ranks", {})
	if not sr is Dictionary:
		errors.append("%s summon_ranks missing or not a Dictionary" % prefix)
	else:
		var player_sr: Array = sr.get("player", [])
		var boss_sr: Array = sr.get("boss", [])
		if not _int_array_equals(player_sr, [3, 4]):
			errors.append("%s summon_ranks.player must be [3,4] (got %s)" % [prefix, str(player_sr)])
		if not _int_array_equals(boss_sr, [0, 1]):
			errors.append("%s summon_ranks.boss must be [0,1] (got %s)" % [prefix, str(boss_sr)])

	# facing_rank_delta
	var frd: Dictionary = table.get("facing_rank_delta", {})
	if not frd is Dictionary:
		errors.append("%s facing_rank_delta missing or not a Dictionary" % prefix)
	else:
		var p_frd = frd.get("player", null)
		if p_frd == null or not _is_int_like(p_frd):
			errors.append("%s facing_rank_delta.player missing or not int" % prefix)
		elif _as_int(p_frd) != -1:
			errors.append("%s facing_rank_delta.player must be -1 (got %d)" % [prefix, _as_int(p_frd)])
		var b_frd = frd.get("boss", null)
		if b_frd == null or not _is_int_like(b_frd):
			errors.append("%s facing_rank_delta.boss missing or not int" % prefix)
		elif _as_int(b_frd) != 1:
			errors.append("%s facing_rank_delta.boss must be 1 (got %d)" % [prefix, _as_int(b_frd)])

	# compatibility_patterns
	var patterns: Dictionary = table.get("compatibility_patterns", {})
	if not patterns is Dictionary:
		errors.append("%s compatibility_patterns missing or not a Dictionary" % prefix)
	else:
		# movement_offsets: exactly three unique integer pairs
		var mv_offsets: Array = patterns.get("movement_offsets", [])
		if mv_offsets.size() != 3:
			errors.append("%s movement_offsets must have exactly 3 entries (got %d)" % [prefix, mv_offsets.size()])
		else:
			var mv_set: Dictionary = {}
			for pair in mv_offsets:
				if not pair is Array or pair.size() != 2:
					errors.append("%s movement_offsets entry is not [int, int]: %s" % [prefix, str(pair)])
				elif not _is_int_like(pair[0]) or not _is_int_like(pair[1]):
					errors.append("%s movement_offsets entry has non-int values: %s" % [prefix, str(pair)])
				else:
					mv_set[Vector2i(_as_int(pair[0]), _as_int(pair[1]))] = true
			if mv_set.size() != 3:
				errors.append("%s movement_offsets must have 3 unique pairs (got %d)" % [prefix, mv_set.size()])

		# attack_offsets: exactly three unique integer pairs
		var atk_offsets: Array = patterns.get("attack_offsets", [])
		if atk_offsets.size() != 3:
			errors.append("%s attack_offsets must have exactly 3 entries (got %d)" % [prefix, atk_offsets.size()])
		else:
			var atk_set: Dictionary = {}
			for pair in atk_offsets:
				if not pair is Array or pair.size() != 2:
					errors.append("%s attack_offsets entry is not [int, int]: %s" % [prefix, str(pair)])
				elif not _is_int_like(pair[0]) or not _is_int_like(pair[1]):
					errors.append("%s attack_offsets entry has non-int values: %s" % [prefix, str(pair)])
				else:
					atk_set[Vector2i(_as_int(pair[0]), _as_int(pair[1]))] = true
			if atk_set.size() != 3:
				errors.append("%s attack_offsets must have 3 unique pairs (got %d)" % [prefix, atk_set.size()])

	# summon_column_order must be a permutation of [0,1,2,3,4]
	var sco: Array = table.get("summon_column_order", [])
	if sco.size() != 5:
		errors.append("%s summon_column_order must have exactly 5 entries (got %d)" % [prefix, sco.size()])
	else:
		var sco_sorted: Array[int] = []
		for v in sco:
			sco_sorted.append(_as_int(v))
		sco_sorted.sort()
		if not _int_array_equals(sco_sorted, [0, 1, 2, 3, 4]):
			errors.append("%s summon_column_order must be a permutation of [0,1,2,3,4] (got %s)" % [prefix, str(sco)])

	return errors


static func _validate_tactical_grid_rules() -> void:
	_errors.append_array(validate_tactical_grid_rules_table(Registry.get_table("tactical_grid_rules")))


# ── tactical_grid_presentation (Phase 27A-R1) ──

static func _valid_html_rgb(value: Variant) -> bool:
	var text := str(value)
	if text.length() != 7 or not text.begins_with("#"):
		return false
	for ch in text.substr(1):
		if not ch in "0123456789ABCDEFabcdef":
			return false
	return true

static func validate_tactical_grid_presentation_table(table: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var prefix := "[tactical_grid_presentation]"
	var version := int(table.get("schema_version", -1))
	if version < 1 or version > 3:
		errors.append("%s schema_version must be 1, 2 or 3" % prefix)
	var grid: Dictionary = table.get("grid", {})
	var marker: Dictionary = table.get("summon_marker", {})
	var timing: Dictionary = table.get("timing", {})
	for pair in [["grid.line_color", grid.get("line_color")], ["summon_marker.color", marker.get("color")]]:
		if not _valid_html_rgb(pair[1]):
			errors.append("%s %s must be #RRGGBB" % [prefix, pair[0]])
	for pair in [["grid.line_alpha", grid.get("line_alpha")], ["summon_marker.fill_alpha", marker.get("fill_alpha")], ["summon_marker.ring_alpha", marker.get("ring_alpha")]]:
		if not (pair[1] is int or pair[1] is float) or float(pair[1]) < 0.0 or float(pair[1]) > 1.0:
			errors.append("%s %s must be numeric in [0,1]" % [prefix, pair[0]])
	var surface = grid.get("surface_offset")
	if not (surface is int or surface is float) or float(surface) < 0.001 or float(surface) > 0.08:
		errors.append("%s grid.surface_offset must be in [0.001,0.08]" % prefix)
	var inset = grid.get("cell_inset_ratio")
	if not (inset is int or inset is float) or float(inset) < 0.55 or float(inset) > 0.90:
		errors.append("%s grid.cell_inset_ratio must be in [0.55,0.90]" % prefix)
	var ratio = marker.get("radius_ratio")
	if not (ratio is int or ratio is float) or float(ratio) < 0.08 or float(ratio) > 0.45:
		errors.append("%s summon_marker.radius_ratio must be in [0.08,0.45]" % prefix)
	var hover = marker.get("hover_scale")
	if not (hover is int or hover is float) or float(hover) < 1.0 or float(hover) > 1.4:
		errors.append("%s summon_marker.hover_scale must be in [1.0,1.4]" % prefix)
	for key in ["confirm_flash_seconds", "overlay_fade_seconds", "reject_pulse_seconds"]:
		var seconds = timing.get(key)
		if not (seconds is int or seconds is float) or float(seconds) < 0.02 or float(seconds) > 0.8:
			errors.append("%s timing.%s must be in [0.02,0.8]" % [prefix, key])

	# ── Phase 27B-R1: camera_framing section ──
	var framing: Dictionary = table.get("camera_framing", {})
	if framing.is_empty():
		errors.append("%s camera_framing section is missing" % prefix)
	else:
		var bw: float = float(framing.get("board_width_ratio", -1.0))
		if bw < 0.70 or bw > 0.90:
			errors.append("%s camera_framing.board_width_ratio must be in [0.70,0.90]; got %.3f" % [prefix, bw])
		var bh: float = float(framing.get("board_height_ratio", -1.0))
		if bh < 0.45 or bh > 0.68:
			errors.append("%s camera_framing.board_height_ratio must be in [0.45,0.68]; got %.3f" % [prefix, bh])
		var fp: float = float(framing.get("fit_padding", -1.0))
		if fp < 1.00 or fp > 1.30:
			errors.append("%s camera_framing.fit_padding must be in [1.00,1.30]; got %.3f" % [prefix, fp])
		var st: float = float(framing.get("safe_top_ratio", -1.0))
		var sb: float = float(framing.get("safe_bottom_ratio", -1.0))
		if st < 0.05 or st > 0.35:
			errors.append("%s camera_framing.safe_top_ratio must be in [0.05,0.35]; got %.3f" % [prefix, st])
		if sb < 0.05 or sb > 0.35:
			errors.append("%s camera_framing.safe_bottom_ratio must be in [0.05,0.35]; got %.3f" % [prefix, sb])
		if st + sb >= 0.60:
			errors.append("%s camera_framing safe_top+ safe_bottom must be < 0.60; got %.3f" % [prefix, st + sb])

	# ── Phase 27B-R1: token_footprint section ──
	var footprint: Dictionary = table.get("token_footprint", {})
	if footprint.is_empty():
		errors.append("%s token_footprint section is missing" % prefix)
	else:
		var nr: float = float(footprint.get("normal_cell_ratio", -1.0))
		if nr < 0.40 or nr > 0.70:
			errors.append("%s token_footprint.normal_cell_ratio must be in [0.40,0.70]; got %.3f" % [prefix, nr])
		var ar: float = float(footprint.get("ascended_cell_ratio", -1.0))
		if ar < nr or ar > 0.75:
			errors.append("%s token_footprint.ascended_cell_ratio must be in [normal,0.75]; got %.3f (normal=%.3f)" % [prefix, ar, nr])
		if ar >= 1.0:
			errors.append("%s token_footprint.ascended_cell_ratio must be < 1.0; got %.3f" % [prefix, ar])
		var af: float = float(footprint.get("art_fill_ratio", -1.0))
		if af < 0.60 or af > 0.90:
			errors.append("%s token_footprint.art_fill_ratio must be in [0.60,0.90]; got %.3f" % [prefix, af])

	var terrain: Dictionary = table.get("terrain", {})
	var feedback: Dictionary = table.get("terrain_feedback", {})
	var terrain_timing: Dictionary = table.get("terrain_timing", {})
	var terrain_camera: Dictionary = table.get("terrain_camera", {})
	var occlusion: Dictionary = table.get("terrain_occlusion", {})
	var glyphs: Dictionary = table.get("surface_glyphs", {})
	for section in [["terrain", terrain], ["terrain_feedback", feedback], ["terrain_timing", terrain_timing], ["terrain_camera", terrain_camera], ["terrain_occlusion", occlusion], ["surface_glyphs", glyphs]]:
		if (section[1] as Dictionary).is_empty():
			errors.append("%s %s section is missing" % [prefix, section[0]])
	for pair in [["terrain.level_step_ratio", terrain.get("level_step_ratio"), 0.05, 0.50], ["terrain.footprint_ratio", terrain.get("footprint_ratio"), 0.50, 0.95], ["terrain.cap_thickness_ratio", terrain.get("cap_thickness_ratio"), 0.01, 0.10], ["terrain_timing.raise_seconds", terrain_timing.get("raise_seconds"), 0.02, 1.0], ["terrain_timing.lower_seconds", terrain_timing.get("lower_seconds"), 0.02, 1.0], ["terrain_timing.feedback_seconds", terrain_timing.get("feedback_seconds"), 0.02, 1.0], ["terrain_camera.elevated_base_pitch", terrain_camera.get("elevated_base_pitch"), 1.0, 89.0], ["terrain_camera.top_pitch", terrain_camera.get("top_pitch"), 1.0, 89.0], ["terrain_camera.focus_pitch", terrain_camera.get("focus_pitch"), 1.0, 89.0], ["terrain_camera.height_fit_padding", terrain_camera.get("height_fit_padding"), 1.0, 2.0], ["terrain_occlusion.alpha_scissor_threshold", occlusion.get("alpha_scissor_threshold"), 0.0, 1.0]]:
		if not (pair[1] is int or pair[1] is float) or float(pair[1]) < float(pair[2]) or float(pair[1]) > float(pair[3]):
			errors.append("%s %s is out of range" % [prefix, pair[0]])
	var checker_size = occlusion.get("checker_size")
	if not (checker_size is int or checker_size is float) or not is_equal_approx(float(checker_size), roundf(float(checker_size))) or int(checker_size) < 1 or int(checker_size) > 16:
		errors.append("%s terrain_occlusion.checker_size must be an integer in [1,16]" % prefix)
	for key in ["body_color", "cap_color", "edge_color", "height_band_color"]:
		if not _valid_html_rgb(terrain.get(key)):
			errors.append("%s terrain.%s must be #RRGGBB" % [prefix, key])
	for key in ["legal_color", "pending_color", "invalid_color", "label_color"]:
		if not _valid_html_rgb(feedback.get(key)):
			errors.append("%s terrain_feedback.%s must be #RRGGBB" % [prefix, key])
	if not occlusion.get("outline_fallback") is bool:
		errors.append("%s terrain_occlusion.outline_fallback must be bool" % prefix)
	var expected_glyphs := {"flat": "single_border", "foundation": "corner_brackets", "high_platform": "double_border", "stable": "corner_clamps", "overheated": "heat_hatch", "ruins": "broken_border", "undermined": "dashed_notch"}
	for key in expected_glyphs:
		if glyphs.get(key) != expected_glyphs[key]:
			errors.append("%s surface_glyphs.%s must be %s" % [prefix, key, expected_glyphs[key]])

	return errors

static func _validate_tactical_grid_presentation() -> void:
	_errors.append_array(validate_tactical_grid_presentation_table(Registry.get_table("tactical_grid_presentation")))




# ── Phase 27B: tactical_unit_patterns ──

static func validate_tactical_unit_patterns_table(table: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var prefix := "[tactical_unit_patterns]"
	if int(table.get("schema_version", -1)) != 1:
		errors.append("%s schema_version must equal 1" % prefix)
	var default_pid: String = str(table.get("default_pattern_id", ""))
	if default_pid == "":
		errors.append("%s default_pattern_id must not be empty" % prefix)
	var pats: Dictionary = table.get("patterns", {})
	if not pats is Dictionary or pats.is_empty():
		errors.append("%s patterns must be a non-empty dict" % prefix)
	else:
		if default_pid != "" and not pats.has(default_pid):
			errors.append("%s default_pattern_id '%s' not found in patterns" % [prefix, default_pid])
		for pid in pats:
			var pat: Dictionary = pats[pid]
			if not pat is Dictionary:
				errors.append("%s patterns.%s must be a dict" % [prefix, pid])
				continue
			# Phase 27I-R1: 主教/战车为动态射线棋路，raycast_directions 存在时允许空 offsets。
			var is_raycast_pattern: bool = pat.get("raycast_directions", []) is Array and not (pat.get("raycast_directions", []) as Array).is_empty()
			var move_offsets: Array = pat.get("movement_offsets", [])
			var atk_offsets: Array = pat.get("attack_offsets", [])
			if move_offsets is Array and not move_offsets.is_empty():
				var e := _validate_offset_array(move_offsets, "%s patterns.%s.movement_offsets" % [prefix, pid])
				errors.append_array(e)
			elif not is_raycast_pattern:
				errors.append("%s patterns.%s.movement_offsets must be non-empty array" % [prefix, pid])
			if atk_offsets is Array and not atk_offsets.is_empty():
				var e := _validate_offset_array(atk_offsets, "%s patterns.%s.attack_offsets" % [prefix, pid])
				errors.append_array(e)
			elif not is_raycast_pattern:
				errors.append("%s patterns.%s.attack_offsets must be non-empty array" % [prefix, pid])
			# Phase 27I-R1: raycast_directions 必须为 Vector2i 数组（存在时）。
			if pat.has("raycast_directions"):
				var ray: Array = pat.get("raycast_directions", [])
				if not ray is Array or ray.is_empty():
					errors.append("%s patterns.%s.raycast_directions must be non-empty array" % [prefix, pid])
				else:
					var re := _validate_offset_array(ray, "%s patterns.%s.raycast_directions" % [prefix, pid])
					errors.append_array(re)
			if not (pat.get("attack_moves_attacker") is bool):
				errors.append("%s patterns.%s.attack_moves_attacker must be bool" % [prefix, pid])
	# Validate card_pattern_overrides
	var overrides: Dictionary = table.get("card_pattern_overrides", {})
	if overrides is Dictionary:
		for card_id in overrides:
			var pid: String = str(overrides[card_id])
			if pid != "" and not pats.has(pid):
				errors.append("%s card_pattern_overrides.%s → '%s' not in patterns" % [prefix, str(card_id), pid])
	else:
		errors.append("%s card_pattern_overrides must be a dict or absent" % prefix)
	return errors


static func _validate_offset_array(offsets: Array, label: String) -> Array[String]:
	var errs: Array[String] = []
	var seen: Dictionary = {}
	var has_nonzero := false
	for i in range(offsets.size()):
		var pair = offsets[i]
		if not (pair is Array and pair.size() == 2):
			errs.append("%s[%d] must be [col, rank]" % [label, i])
			continue
		var dx := _as_int(pair[0])
		var dy := _as_int(pair[1])
		if abs(dx) > 4 or abs(dy) > 4:
			errs.append("%s[%d]=(%d,%d) offset out of plausible range [-4,4]" % [label, i, dx, dy])
		if dx != 0 or dy != 0:
			has_nonzero = true
		var key := "%d,%d" % [dx, dy]
		if seen.has(key):
			errs.append("%s[%d]=(%d,%d) duplicate offset" % [label, i, dx, dy])
		seen[key] = true
	if not has_nonzero:
		errs.append("%s contains only zero offsets" % label)
	return errs


static func _validate_tactical_unit_patterns() -> void:
	_errors.append_array(validate_tactical_unit_patterns_table(Registry.get_table("tactical_unit_patterns")))


# ── Phase 27I-R0: card_piece_traits ──

static func validate_card_piece_traits_table(table: Dictionary, unit_patterns: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var prefix := "[card_piece_traits]"

	if _as_int(table.get("schema_version", 0)) != 1:
		errors.append("%s schema_version must equal 1" % prefix)
		return errors

	# piece_names
	var piece_names: Dictionary = table.get("piece_names", {})
	if not piece_names is Dictionary or piece_names.is_empty():
		errors.append("%s piece_names must be a non-empty dict" % prefix)
	else:
		for pname in piece_names:
			if pname not in ["pawn", "knight", "bishop", "rook", "queen"]:
				errors.append("%s piece_names has unknown piece type '%s'" % [prefix, str(pname)])

	# enhanced_payment
	var pay: Dictionary = table.get("enhanced_payment", {})
	if not pay is Dictionary or pay.is_empty():
		errors.append("%s enhanced_payment missing" % prefix)
	else:
		if _as_int(pay.get("command_cost", 0)) < 1:
			errors.append("%s enhanced_payment.command_cost must be >= 1" % prefix)
		if _as_int(pay.get("depth_cost", 0)) < 1:
			errors.append("%s enhanced_payment.depth_cost must be >= 1" % prefix)
		var dz: String = str(pay.get("depth_zone_required", ""))
		if dz == "":
			errors.append("%s enhanced_payment.depth_zone_required missing" % prefix)

	# profiles
	var profiles: Dictionary = table.get("profiles", {})
	if not profiles is Dictionary or profiles.is_empty():
		errors.append("%s profiles must be a non-empty dict" % prefix)
	else:
		var seen_profiles: Dictionary = {}
		for profile_id in profiles:
			var prof: Dictionary = profiles[profile_id]
			if not prof is Dictionary:
				errors.append("%s profiles.%s must be a dict" % [prefix, str(profile_id)])
				continue
			if seen_profiles.has(profile_id):
				errors.append("%s duplicate profile id '%s'" % [prefix, str(profile_id)])
			seen_profiles[profile_id] = true
			var ptype: String = str(prof.get("piece_type", ""))
			if ptype == "" or not piece_names.has(ptype):
				errors.append("%s profiles.%s unknown piece_type '%s'" % [prefix, str(profile_id), ptype])
			var pattern_id: String = str(prof.get("pattern_id", ""))
			if pattern_id == "":
				errors.append("%s profiles.%s pattern_id missing" % [prefix, str(profile_id)])
			elif not (unit_patterns.get("patterns", {}) is Dictionary) or not (unit_patterns.get("patterns", {}) as Dictionary).has(pattern_id):
				errors.append("%s profiles.%s pattern_id '%s' not found in tactical_unit_patterns" % [prefix, str(profile_id), pattern_id])
			var allowed: Array = prof.get("allowed_families", [])
			if not allowed is Array or allowed.is_empty():
				errors.append("%s profiles.%s allowed_families must be non-empty array" % [prefix, str(profile_id)])
			else:
				for fam in allowed:
					if fam not in ["monster", "spell", "counter", "building"]:
						errors.append("%s profiles.%s unknown family '%s'" % [prefix, str(profile_id), str(fam)])
			var amode: String = str(prof.get("anchor_mode", ""))
			if amode not in ["none", "unit_self", "friendly_anchor", "board_cell", "friendly_unit"]:
				errors.append("%s profiles.%s anchor_mode unsupported '%s'" % [prefix, str(profile_id), amode])
			if not (prof.get("blocks_anchor_cell", false) is bool):
				errors.append("%s profiles.%s blocks_anchor_cell must be bool" % [prefix, str(profile_id)])

	# payloads
	var payloads: Dictionary = table.get("payloads", {})
	if not payloads is Dictionary or payloads.is_empty():
		errors.append("%s payloads must be a non-empty dict" % prefix)
	else:
		var seen_payloads: Dictionary = {}
		var allowed_resolvers := ["p01_formation_shield", "p02_knight_action", "p03_vanguard_formation", "p04_tripwire_watch", "p05_foundation_guard", "p06_bishop_blade", "p08_rook_relay"]
		for payload_id in payloads:
			var pl: Dictionary = payloads[payload_id]
			if not pl is Dictionary:
				errors.append("%s payloads.%s must be a dict" % [prefix, str(payload_id)])
				continue
			if seen_payloads.has(payload_id):
				errors.append("%s duplicate payload id '%s'" % [prefix, str(payload_id)])
			seen_payloads[payload_id] = true
			var rid: String = str(pl.get("resolver_id", ""))
			if rid == "" or not rid in allowed_resolvers:
				errors.append("%s payloads.%s unknown resolver_id '%s'" % [prefix, str(payload_id), rid])
			if not (pl.get("base", {}) is Dictionary):
				errors.append("%s payloads.%s base must be a dict" % [prefix, str(payload_id)])

	# P01–P05 unique mapping: enabled cards must reference an existing profile+payload
	var P01_P05_MAP := {
		"P01": ["pawn", "pawn_anchor_fan", "p01_formation_shield"],
		"P02": ["knight", "knight_unit", "p02_knight_action"],
		"P03": ["pawn", "pawn_unit", "p03_vanguard_formation"],
		"P04": ["pawn", "pawn_counter_watch", "p04_tripwire_watch"],
		"P05": ["pawn", "pawn_building_aura", "p05_foundation_guard"],
	}
	for card_id in P01_P05_MAP:
		var expect: Array = P01_P05_MAP[card_id]
		var profile_id: String = expect[1]
		var payload_id: String = expect[2]
		if not profiles.has(profile_id):
			errors.append("%s P01–P05 mapping: profile '%s' missing for %s" % [prefix, profile_id, card_id])
		if not payloads.has(payload_id):
			errors.append("%s P01–P05 mapping: payload '%s' missing for %s" % [prefix, payload_id, card_id])

	return errors


static func _validate_card_piece_traits() -> void:
	var unit_patterns: Dictionary = Registry.get_table("tactical_unit_patterns")
	_errors.append_array(validate_card_piece_traits_table(Registry.get_table("card_piece_traits"), unit_patterns))


# ── Phase 27J: OD release rules ──

static func validate_od_release_rules_table(table: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var prefix := "[od_release_rules]"
	if _as_int(table.get("schema_version", 0)) != 1:
		errors.append("%s schema_version must equal 1" % prefix)
		return errors
	var readiness := _as_int(table.get("readiness_threshold", 0))
	var heat_cost := _as_int(table.get("release_heat_cost", 0))
	var converted := _as_int(table.get("converted_heat", 0))
	if readiness < 3 or readiness > 10:
		errors.append("%s readiness_threshold must be 3..10" % prefix)
	if heat_cost < 1 or heat_cost > readiness:
		errors.append("%s release_heat_cost must be 1..readiness_threshold" % prefix)
	if converted != heat_cost:
		errors.append("%s converted_heat must equal committed release_heat_cost" % prefix)
	# PHASE62_BEGIN_RITUAL_VALIDATION
	if table.has("ritual_readiness_threshold"):
		var ritual_heat: Variant=table.ritual_readiness_threshold
		if not _is_int_like(ritual_heat) or _as_int(ritual_heat)<readiness or _as_int(ritual_heat)>10 or _as_int(ritual_heat)<heat_cost:
			errors.append("%s ritual_readiness_threshold must be integer readiness_threshold..10 and cover heat_cost" % prefix)
	# PHASE62_END_RITUAL_VALIDATION
	var allowed := {
		"pawn": "pawn_formation_advance",
		"knight": "knight_arc_leap",
		"bishop": "bishop_diagonal_conduction",
		"rook": "rook_orthogonal_relay",
	}
	var releases: Dictionary = table.get("piece_releases", {})
	for piece_type in allowed:
		var entry: Dictionary = releases.get(piece_type, {})
		if entry.is_empty():
			errors.append("%s piece_releases.%s missing" % [prefix, piece_type])
			continue
		if str(entry.get("resolver_id", "")) != str(allowed[piece_type]):
			errors.append("%s piece_releases.%s unknown resolver_id '%s'" % [prefix, piece_type, str(entry.get("resolver_id", ""))])
		if str(entry.get("action_kind", "")) not in ["move", "attack", "control"]:
			errors.append("%s piece_releases.%s action_kind invalid" % [prefix, piece_type])
		if str(entry.get("command_id", "")) not in ["move", "attack", "defend"]:
			errors.append("%s piece_releases.%s command_id invalid" % [prefix, piece_type])
		if _as_int(entry.get("command_cost", 0)) < 1:
			errors.append("%s piece_releases.%s command_cost must be >= 1" % [prefix, piece_type])
		if str(entry.get("chain_event", "")) == "":
			errors.append("%s piece_releases.%s chain_event missing" % [prefix, piece_type])
		if piece_type == "knight" and entry.has("disruption_damage"):
			var damage = entry["disruption_damage"]
			if not _is_int_like(damage) or _as_int(damage) < 1 or _as_int(damage) > 2:
				errors.append("%s piece_releases.knight.disruption_damage must be integer 1..2" % prefix)
	var final_rules: Dictionary = table.get("final_convergence", {})
	if _as_int(final_rules.get("minimum_layer", 0)) < 2:
		errors.append("%s final_convergence.minimum_layer must be >= 2" % prefix)
	if _as_int(final_rules.get("minimum_heat", 0)) < readiness:
		errors.append("%s final_convergence.minimum_heat must be >= readiness_threshold" % prefix)
	if _as_int(final_rules.get("required_boss_phase", 0)) < 2:
		errors.append("%s final_convergence.required_boss_phase must be >= 2" % prefix)
	if str(final_rules.get("resolver_id", "")) != "final_convergence":
		errors.append("%s final_convergence resolver_id invalid" % prefix)
	return errors


# ── Phase 27K-R0: OD presentation rules（纯表现，缺项即降级，不阻断战斗） ──

static func validate_od_presentation_rules_table(table: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var prefix := "[od_presentation_rules]"
	if _as_int(table.get("schema_version", 0)) != 1:
		errors.append("%s schema_version must equal 1" % prefix)
		return errors

	# heat.max_segments 必须为 10
	var heat: Dictionary = table.get("heat", {})
	if not heat is Dictionary or heat.is_empty():
		errors.append("%s heat section missing or empty" % prefix)
		return errors
	if _as_int(heat.get("max_segments", 0)) != 10:
		errors.append("%s heat.max_segments must be 10" % prefix)

	# heat.zones 三区间严格校验
	var zones: Array = heat.get("zones", [])
	if zones.size() != 3:
		errors.append("%s heat.zones must have exactly 3 entries (got %d)" % [prefix, zones.size()])
	else:
		var required_ids: Array[String] = ["Calm", "Heated", "Overdrive"]
		var seen_ids: Dictionary = {}
		var prev_max := -2
		for i in range(zones.size()):
			var z = zones[i]
			if not z is Dictionary:
				errors.append("%s heat.zones[%d] is not a Dictionary" % [prefix, i])
				continue
			var zid: String = str(z.get("id", ""))
			if zid != required_ids[i]:
				errors.append("%s heat.zones[%d] expected id='%s', got '%s'" % [prefix, i, required_ids[i], zid])
			if zid in seen_ids:
				errors.append("%s duplicate zone id '%s'" % [prefix, zid])
			seen_ids[zid] = true
			var zmin := _as_int(z.get("min", -99))
			var zmax := _as_int(z.get("max", -99))
			if zmin < 0 or zmax < zmin:
				errors.append("%s heat.zones[%d] invalid min/max (%d..%d)" % [prefix, i, zmin, zmax])
			if i == 0 and zmin != 0:
				errors.append("%s heat.zones[0] min must be 0" % prefix)
			if i > 0 and zmin != prev_max + 1:
				errors.append("%s heat.zones[%d] min must equal prev_max+1" % [prefix, i])
			prev_max = zmax
			if str(z.get("label_zh", "")).is_empty() or str(z.get("label_en", "")).is_empty():
				errors.append("%s heat.zones[%d] missing label_zh/label_en" % [prefix, i])
			if str(z.get("token_id", "")).is_empty() or str(z.get("token_text", "")).is_empty():
				errors.append("%s heat.zones[%d] missing token_id/token_text" % [prefix, i])
			if not _valid_html_rgb(z.get("color", "")):
				errors.append("%s heat.zones[%d] color must be #RRGGBB" % [prefix, i])
		if zones.size() == 3 and prev_max != 10:
			errors.append("%s heat.zones last max must be 10" % prefix)

	# charge
	var charge: Dictionary = table.get("charge", {})
	if not charge is Dictionary or charge.is_empty():
		errors.append("%s charge section missing or empty" % prefix)
	else:
		var fmt: String = str(charge.get("format", ""))
		if not fmt.contains("{value}") or not fmt.contains("{capacity}"):
			errors.append("%s charge.format must contain {value} and {capacity}" % prefix)
		if str(charge.get("label_zh", "")).is_empty():
			errors.append("%s charge.label_zh missing" % prefix)

	# layers
	var layers: Dictionary = table.get("layers", {})
	if not layers is Dictionary or layers.is_empty():
		errors.append("%s layers section missing or empty" % prefix)
	else:
		if _as_int(layers.get("count", 0)) != 5:
			errors.append("%s layers.count must be 5" % prefix)
		var tokens: Array = layers.get("tokens", [])
		if tokens.size() != 5:
			errors.append("%s layers.tokens must have exactly 5 entries" % prefix)
		else:
			for i in range(tokens.size()):
				if str(tokens[i]).is_empty():
					errors.append("%s layers.tokens[%d] empty" % prefix)
		var names: Array = layers.get("names", [])
		if names.size() != 5:
			errors.append("%s layers.names must have exactly 5 entries" % prefix)

	# release labels
	var release: Dictionary = table.get("release", {})
	if not release is Dictionary or release.is_empty():
		errors.append("%s release section missing or empty" % prefix)
	else:
		var labels: Dictionary = release.get("labels", {})
		var required_labels := ["ready", "insufficient_heat", "insufficient_command_points", "not_player_turn", "no_legal_source", "wrong_side", "release_busy", "source_selection", "target_selection", "unknown"]
		for rk in required_labels:
			if not labels.has(rk):
				errors.append("%s release.labels.%s missing" % [prefix, rk])

	# timing
	var timing: Dictionary = table.get("timing", {})
	if not timing is Dictionary or timing.is_empty():
		errors.append("%s timing section missing or empty" % prefix)
	else:
		for key in ["normal_refresh_seconds", "threshold_change_seconds"]:
			var val = timing.get(key, null)
			if not (val is float or val is int):
				errors.append("%s timing.%s missing or not numeric" % [prefix, key])
			else:
				var fval: float = float(val)
				if fval < 0.05 or fval > 3.0:
					errors.append("%s timing.%s=%.3f out of range [0.05, 3.0]" % [prefix, key, fval])
		if not (timing.get("reduced_motion_enabled", null) is bool):
			errors.append("%s timing.reduced_motion_enabled must be bool" % prefix)
		var rms = timing.get("reduced_motion_seconds", null)
		if not (rms is float or rms is int):
			errors.append("%s timing.reduced_motion_seconds missing or not numeric" % prefix)
		elif float(rms) < 0.0 or float(rms) > 3.0:
			errors.append("%s timing.reduced_motion_seconds out of range [0.0, 3.0]" % prefix)

	return errors


# Phase 27K-R1-A: source classification metadata only. Saturation must remain
# disabled in this phase, so this validator cannot accidentally enable tuning.
static func validate_od_flow_feedback_rules_table(table: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var prefix := "[od_flow_feedback_rules]"
	if _as_int(table.get("schema_version", 0)) != 1:
		errors.append("%s schema_version must equal 1" % prefix)
		return errors
	var capacity := _as_int(table.get("event_buffer_capacity", 0))
	if capacity < 32 or capacity > 2048:
		errors.append("%s event_buffer_capacity must be in [32, 2048]" % prefix)
	var saturation: Dictionary = table.get("saturation", {})
	if not saturation.get("enabled", false) is bool:
		errors.append("%s saturation.enabled must be bool" % prefix)
	elif bool(saturation.get("enabled", false)):
		errors.append("%s saturation.enabled must remain false in R1-A" % prefix)
	var repeat_penalty: Array = saturation.get("repeat_penalty", [])
	if not _int_array_equals(repeat_penalty, [0, 1, 2]):
		errors.append("%s saturation.repeat_penalty must remain [0, 1, 2]" % prefix)

	var allowed_policies := ["saturable", "bounded_existing", "unsaturated_pressure", "conversion", "cooling"]
	var policies: Array = table.get("policies", [])
	if policies.size() != allowed_policies.size():
		errors.append("%s policies must contain exactly the five R1 policies" % prefix)
	for policy in policies:
		if str(policy) not in allowed_policies:
			errors.append("%s unknown policy '%s'" % [prefix, str(policy)])
	for policy in allowed_policies:
		if policy not in policies:
			errors.append("%s missing policy '%s'" % [prefix, policy])

	var active_cards := _load_positive_heat_card_ids()
	var families: Dictionary = table.get("card_base_heat_families", {})
	var family_keys: Array[String] = []
	for key in families:
		family_keys.append(str(key))
		if not str(key).begins_with("P") or not str(key).substr(1).is_valid_int():
			errors.append("%s unknown card id '%s'" % [prefix, str(key)])
		if str(families[key]).strip_edges().is_empty():
			errors.append("%s card '%s' has empty family" % [prefix, str(key)])
	for card_id in active_cards:
		if card_id not in family_keys:
			errors.append("%s active Heat card '%s' missing family" % [prefix, card_id])
	for card_id in family_keys:
		if card_id not in active_cards:
			errors.append("%s card family '%s' is not an active positive-Heat card" % [prefix, card_id])

	var tiers := ["micro", "minor", "major", "critical"]
	var seen_sources := {}
	var system_sources: Array = table.get("system_sources", [])
	for i in range(system_sources.size()):
		var raw = system_sources[i]
		if not raw is Dictionary:
			errors.append("%s system_sources[%d] must be a Dictionary" % [prefix, i])
			continue
		var source_id := str(raw.get("source_id", ""))
		if source_id.is_empty():
			errors.append("%s system_sources[%d] source_id missing" % [prefix, i])
		elif seen_sources.has(source_id):
			errors.append("%s duplicate system source '%s'" % [prefix, source_id])
		seen_sources[source_id] = true
		if str(raw.get("source_kind", "")).is_empty():
			errors.append("%s system source '%s' kind missing" % [prefix, source_id])
		if str(raw.get("source_family", "")).is_empty():
			errors.append("%s system source '%s' family missing" % [prefix, source_id])
		if str(raw.get("source_policy", "")) not in allowed_policies:
			errors.append("%s system source '%s' policy invalid" % [prefix, source_id])
		if str(raw.get("presentation_tier", "")) not in tiers:
			errors.append("%s system source '%s' tier invalid" % [prefix, source_id])

	var dynamic_rules: Dictionary = table.get("dynamic_source_rules", {})
	var hero_rule: Dictionary = dynamic_rules.get("hero_skill", {})
	if str(hero_rule.get("prefix", "")) != "hero_skill:" or str(hero_rule.get("source_family", "")).is_empty():
		errors.append("%s dynamic hero_skill rule invalid" % prefix)
	if str(hero_rule.get("source_policy", "")) != "saturable":
		errors.append("%s dynamic hero_skill policy must be saturable" % prefix)

	var required_events := ["heat_committed", "heat_cooled", "zone_changed", "release_started", "heat_converted", "layer_advanced", "release_committed", "release_cancelled"]
	var event_tiers: Dictionary = table.get("event_tiers", {})
	for event_kind in required_events:
		if str(event_tiers.get(event_kind, "")) not in tiers:
			errors.append("%s event '%s' has missing/unknown tier" % [prefix, event_kind])
	for event_kind in event_tiers:
		if str(event_kind) not in required_events:
			errors.append("%s unknown event kind '%s'" % [prefix, str(event_kind)])
	return errors


static func _load_positive_heat_card_ids() -> Array[String]:
	var ids: Array[String] = []
	var file := FileAccess.open("res://data/cards/player_cards_20.json", FileAccess.READ)
	if file == null:
		return ids
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		return ids
	for raw in parsed.get("cards", []):
		if raw is Dictionary and _as_int(raw.get("engine_gain", 0)) > 0:
			ids.append(str(raw.get("id", "")))
	return ids


# ── localization ──

static func _validate_localization() -> void:
	var t := Registry.get_table("localization")
	if t.is_empty():
		_errors.append("[localization] Table missing")
		return

	var sv = t.get("schema_version", null)
	if sv == null or not _is_int_like(sv):
		_errors.append("[localization] schema_version missing or not int")

	# check for mojibake in values
	for key in t.keys():
		if key == "schema_version":
			continue
		var val = t[key]
		if val is String:
			for marker in MOJIBAKE_MARKERS:
				if marker in val:
					_errors.append("[localization] Mojibake marker '%s' found in '%s': '%s'" % [marker, key, val])
					break


# ── Phase 27C: tactical_core_facing_rules ──

static func _validate_tactical_core_facing_rules() -> void:
	var t := Registry.get_table("tactical_core_facing_rules")
	if t.is_empty():
		_errors.append("[tactical_core_facing_rules] Table missing")
		return
	var errors: Array[String] = validate_tactical_core_facing_rules_table(t)
	for e in errors:
		_errors.append(e)


static func validate_tactical_core_facing_rules_table(table: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var prefix := "[tactical_core_facing_rules]"

	# ── schema_version ──
	var sv = table.get("schema_version", null)
	if sv == null or not _is_int_like(sv) or _as_int(sv) != 1:
		errors.append("%s schema_version must equal 1" % prefix)
		return errors

	# ── core section ──
	var core: Dictionary = table.get("core", {})
	if not core is Dictionary or core.is_empty():
		errors.append("%s core section missing or empty" % prefix)
		return errors

	var required_core_int := ["player_target_virtual_rank", "boss_target_virtual_rank",
		"player_breach_rank", "boss_breach_rank",
		"player_threat_rank", "boss_threat_rank", "guard_intercept_column_radius"]
	for key in required_core_int:
		var val = core.get(key, null)
		if val == null or not _is_int_like(val):
			errors.append("%s core.%s missing or not int" % [prefix, key])

	var required_core_bool := ["core_spans_all_columns", "legacy_lane_fallback_enabled"]
	for key in required_core_bool:
		if not core.get(key, null) is bool:
			errors.append("%s core.%s must be bool" % [prefix, key])

	# Range checks for ranks
	var p_breach := _as_int(core.get("player_breach_rank", -99))
	var b_breach := _as_int(core.get("boss_breach_rank", -99))
	var p_threat := _as_int(core.get("player_threat_rank", -99))
	var b_threat := _as_int(core.get("boss_threat_rank", -99))
	var p_virtual := _as_int(core.get("player_target_virtual_rank", -99))
	var b_virtual := _as_int(core.get("boss_target_virtual_rank", -99))
	var guard_radius := _as_int(core.get("guard_intercept_column_radius", -1))

	# Breach/threat ranks must be inside board 0..4
	for label in [["player_breach_rank", p_breach], ["boss_breach_rank", b_breach],
			["player_threat_rank", p_threat], ["boss_threat_rank", b_threat]]:
		var name: String = label[0]
		var val: int = label[1]
		if val < 0 or val > 4:
			errors.append("%s core.%s=%d must be 0..4" % [prefix, name, val])

	# Cross-field: player breach (0) < player threat (1); boss threat (3) < boss breach (4)
	if p_breach >= p_threat and p_breach != -99 and p_threat != -99:
		errors.append("%s core: player_breach_rank=%d must be < player_threat_rank=%d" % [prefix, p_breach, p_threat])
	if b_threat >= b_breach and b_threat != -99 and b_breach != -99:
		errors.append("%s core: boss_threat_rank=%d must be < boss_breach_rank=%d" % [prefix, b_threat, b_breach])

	# Virtual ranks must be outside board
	if p_virtual >= 0:
		errors.append("%s core.player_target_virtual_rank=%d must be <0 (outside board)" % [prefix, p_virtual])
	if b_virtual <= 4:
		errors.append("%s core.boss_target_virtual_rank=%d must be >4 (outside board)" % [prefix, b_virtual])

	# Guard radius
	if guard_radius < 0 or guard_radius > 2:
		errors.append("%s core.guard_intercept_column_radius=%d must be 0..2" % [prefix, guard_radius])

	# ── facing section ──
	var facing: Dictionary = table.get("facing", {})
	if not facing is Dictionary or facing.is_empty():
		errors.append("%s facing section missing or empty" % prefix)
	else:
		var p_delta := _as_int(facing.get("player_default_rank_delta", 99))
		var b_delta := _as_int(facing.get("boss_default_rank_delta", 99))
		if p_delta != -1 and p_delta != 1:
			errors.append("%s facing.player_default_rank_delta=%d must be -1 or 1" % [prefix, p_delta])
		if b_delta != -1 and b_delta != 1:
			errors.append("%s facing.boss_default_rank_delta=%d must be -1 or 1" % [prefix, b_delta])
		if p_delta == b_delta:
			errors.append("%s facing: player and boss default deltas must be opposite (got %d and %d)" % [prefix, p_delta, b_delta])

		var turn_cost := _as_int(facing.get("turn_action_cost", -1))
		if turn_cost < 1 or turn_cost > 3:
			errors.append("%s facing.turn_action_cost=%d must be 1..3" % [prefix, turn_cost])

		for key in ["turn_blocked_by_summoning_sickness", "redeploy_resets_to_side_default"]:
			if not facing.get(key, null) is bool:
				errors.append("%s facing.%s must be bool" % [prefix, key])

	# ── engagement section ──
	var engagement: Dictionary = table.get("engagement", {})
	if not engagement is Dictionary or engagement.is_empty():
		errors.append("%s engagement section missing or empty" % prefix)
	else:
		for key in ["enabled", "locks_self_move", "forced_effect_ignores_lock"]:
			if not engagement.get(key, null) is bool:
				errors.append("%s engagement.%s must be bool" % [prefix, key])

	# ── overdrive_breach section ──
	var od_breach: Dictionary = table.get("overdrive_breach", {})
	if not od_breach is Dictionary or od_breach.is_empty():
		errors.append("%s overdrive_breach section missing or empty" % prefix)
	else:
		if not od_breach.get("enabled", null) is bool:
			errors.append("%s overdrive_breach.enabled must be bool" % prefix)
		if not od_breach.get("once_per_turn", null) is bool:
			errors.append("%s overdrive_breach.once_per_turn must be bool" % prefix)

		var charge_cost := _as_int(od_breach.get("charge_cost", -1))
		if charge_cost < 1 or charge_cost > 20:
			errors.append("%s overdrive_breach.charge_cost=%d must be 1..20" % [prefix, charge_cost])

		var depth_gain := _as_int(od_breach.get("depth_gain", -1))
		if depth_gain < 0 or depth_gain > 10:
			errors.append("%s overdrive_breach.depth_gain=%d must be 0..10" % [prefix, depth_gain])

		if bool(od_breach.get("enabled", false)):
			if charge_cost < 1 and charge_cost != -99:
				errors.append("%s overdrive_breach enabled but charge_cost=%d is invalid" % [prefix, charge_cost])

	return errors


# ── Phase 27D: tactical_command_economy ──

static func validate_tactical_command_economy(raw: Dictionary) -> Array[String]:
	var errors: Array[String] = []

	# schema_version
	if not raw.has("schema_version") or not (raw["schema_version"] is int or raw["schema_version"] is float):
		errors.append("tactical_command_economy: missing or non-numeric schema_version")
		return errors

	# ── pool section ──
	var pool: Variant = raw.get("pool", null)
	if pool == null or not pool is Dictionary:
		errors.append("tactical_command_economy: pool section missing or not a dictionary")
	else:
		var player_base: Variant = pool.get("player_base_by_od_layer", null)
		if player_base == null or not player_base is Dictionary:
			errors.append("tactical_command_economy: pool.player_base_by_od_layer missing")
		else:
			for i in range(1, 6):
				var val := _as_int(player_base.get(str(i), -1))
				if val < 0:
					errors.append("tactical_command_economy: missing player_base_by_od_layer key '%d'" % i)
				elif val < 1:
					errors.append("tactical_command_economy: player_base_by_od_layer['%d']=%d must be >=1" % [i, val])

		var boss_base: Variant = pool.get("boss_base_by_zone", null)
		if boss_base == null or not boss_base is Dictionary:
			errors.append("tactical_command_economy: pool.boss_base_by_zone missing")
		else:
			for zone in ["Calm", "Heated", "Overdrive"]:
				if not boss_base.has(zone):
					errors.append("tactical_command_economy: missing boss_base_by_zone key '%s'" % zone)
				else:
					var bval := _as_int(boss_base.get(zone, -1))
					if bval < 1:
						errors.append("tactical_command_economy: boss_base_by_zone['%s']=%d must be >=1" % [zone, bval])

		var cap := _as_int(pool.get("total_cap", -1))
		if cap < 1:
			errors.append("tactical_command_economy: pool.total_cap=%d must be >=1" % cap)
		else:
			# Cap must be >= every base value
			if player_base != null:
				for i in range(1, 6):
					var base_val := _as_int(player_base.get(str(i), 0))
					if cap < base_val:
						errors.append("tactical_command_economy: total_cap=%d < player L%d base=%d" % [cap, i, base_val])
			if boss_base != null:
				for zone in ["Calm", "Heated", "Overdrive"]:
					var bval := _as_int(boss_base.get(zone, 0))
					if cap < bval:
						errors.append("tactical_command_economy: total_cap=%d < Boss %s=%d" % [cap, zone, bval])

	# ── costs section ──
	var costs: Variant = raw.get("costs", null)
	if costs == null or not costs is Dictionary:
		errors.append("tactical_command_economy: costs section missing")
	else:
		var cost_keys := ["move", "special_move", "attack", "turn", "defend", "boss_core_attack"]
		for ck in cost_keys:
			var cv := _as_int(costs.get(ck, -1))
			if cv < 0:
				errors.append("tactical_command_economy: costs.%s missing" % ck)
			elif cv < 1:
				errors.append("tactical_command_economy: costs.%s=%d must be >=1" % [ck, cv])

		for section in ["active_skill", "od_finisher"]:
			var sec: Variant = costs.get(section, null)
			if sec == null or not sec is Dictionary:
				errors.append("tactical_command_economy: costs.%s missing" % section)
			else:
				var smin := _as_int(sec.get("min", -1))
				var sdef := _as_int(sec.get("default", -1))
				var smax := _as_int(sec.get("max", -1))
				if smin < 1: errors.append("tactical_command_economy: costs.%s.min=%d < 1" % [section, smin])
				if sdef < 1: errors.append("tactical_command_economy: costs.%s.default=%d < 1" % [section, sdef])
				if smax < 1: errors.append("tactical_command_economy: costs.%s.max=%d < 1" % [section, smax])
				if smin > sdef: errors.append("tactical_command_economy: costs.%s min(%d) > default(%d)" % [section, smin, sdef])
				if sdef > smax: errors.append("tactical_command_economy: costs.%s default(%d) > max(%d)" % [section, sdef, smax])

		var min_paid := _as_int(costs.get("minimum_paid_cost", -1))
		if min_paid < 0: errors.append("tactical_command_economy: costs.minimum_paid_cost missing")
		elif min_paid < 1: errors.append("tactical_command_economy: costs.minimum_paid_cost=%d < 1" % min_paid)

	# ── depth section ──
	var depth: Variant = raw.get("depth", null)
	if depth == null or not depth is Dictionary:
		errors.append("tactical_command_economy: depth section missing")
	else:
		var thresholds_raw: Variant = depth.get("gross_spend_thresholds", null)
		if thresholds_raw == null or not thresholds_raw is Array:
			errors.append("tactical_command_economy: depth.gross_spend_thresholds must be array")
		else:
			if thresholds_raw.size() < 1:
				errors.append("tactical_command_economy: depth.gross_spend_thresholds empty")
			else:
				var last := -1
				for raw_t in thresholds_raw:
					var t := _as_int(raw_t)
					if t <= last:
						errors.append("tactical_command_economy: thresholds must be strictly ascending; %d after %d" % [t, last])
					last = t
				if last > 100:
					errors.append("tactical_command_economy: last threshold %d exceeds reasonable gross-spend range" % last)

		var depth_per := _as_int(depth.get("depth_per_threshold", -1))
		if depth_per < 0:
			errors.append("tactical_command_economy: depth.depth_per_threshold missing")
		elif depth_per < 1:
			errors.append("tactical_command_economy: depth.depth_per_threshold=%d < 1" % depth_per)

		for k in ["warning_skill_surcharge", "backlash_skill_surcharge"]:
			var sv := _as_int(depth.get(k, -1))
			if sv < 0:
				errors.append("tactical_command_economy: depth.%s missing" % k)

		if not depth.get("block_instant_refund_during_backlash", null) is bool:
			errors.append("tactical_command_economy: depth.block_instant_refund_during_backlash must be bool")

	# ── refunds section ──
	var refunds: Variant = raw.get("refunds", null)
	if refunds == null or not refunds is Dictionary:
		errors.append("tactical_command_economy: refunds section missing")
	else:
		for rk in ["default_per_trigger_cap", "total_per_turn_cap"]:
			var rv := _as_int(refunds.get(rk, -1))
			if rv < 0:
				errors.append("tactical_command_economy: refunds.%s must be non-negative, got %d" % [rk, rv])

	# ── turn section ──
	var turn: Variant = raw.get("turn", null)
	if turn == null or not turn is Dictionary:
		errors.append("tactical_command_economy: turn section missing")
	else:
		if not turn.get("clear_unused_points", null) is bool:
			errors.append("tactical_command_economy: turn.clear_unused_points must be bool")
		if not turn.get("normal_gain_applies_next_turn", null) is bool:
			errors.append("tactical_command_economy: turn.normal_gain_applies_next_turn must be bool")

	return errors


# ── Phase 27F: boss_tactical_ai ──

static func validate_boss_tactical_ai_table(table: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if _as_int(table.get("schema_version", 0)) < 1:
		errors.append("boss_tactical_ai: schema_version must be >= 1")
	var max_actions := _as_int(table.get("max_actions_per_turn", 0))
	if max_actions < 1 or max_actions > 12:
		errors.append("boss_tactical_ai: max_actions_per_turn must be 1..12")
	if not table.get("minimum_score", null) is int and not table.get("minimum_score", null) is float:
		errors.append("boss_tactical_ai: minimum_score must be numeric")
	if not table.get("seed_salt", null) is int and not table.get("seed_salt", null) is float:
		errors.append("boss_tactical_ai: seed_salt must be numeric")
		var asd: Variant = table.get("action_step_delay", null)
		if asd != null and not asd is int and not asd is float:
			errors.append("boss_tactical_ai: action_step_delay must be numeric")
		elif asd != null:
			var asd_f: float = float(asd)
			if asd_f < 0.15 or asd_f > 0.80:
				errors.append("boss_tactical_ai: action_step_delay must be 0.15..0.80")
	var weights: Variant = table.get("weights", null)
	if not weights is Dictionary:
		errors.append("boss_tactical_ai: weights must be a dictionary")
		return errors
	var required_keys := [
		"move", "attack", "attack_core", "turn", "skill", "lethal", "kill",
		"protect_core", "advance", "retreat", "threat", "cost_penalty",
	]
	for zone in ["Calm", "Heated", "Overdrive"]:
		var zone_weights: Variant = weights.get(zone, null)
		if not zone_weights is Dictionary:
			errors.append("boss_tactical_ai: weights.%s must be a dictionary" % zone)
			continue
		for key in required_keys:
			var value: Variant = zone_weights.get(key, null)
			if not value is int and not value is float:
				errors.append("boss_tactical_ai: weights.%s.%s must be numeric" % [zone, key])
			elif int(value) < 0:
				errors.append("boss_tactical_ai: weights.%s.%s must be >= 0" % [zone, key])
	return errors


## Phase 27E: 校验怪兽英雄技能表
static func validate_monster_hero_skills_table(table: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	const ALLOWED_RESOLVERS: Array[String] = ["resolve_ignition_leap", "resolve_stream_cannon", "resolve_bulwark_advance", "resolve_spark_assault", "resolve_chain_relay"]
	const ALLOWED_TRIGGERS: Array[String] = ["normal_move_completed", "player_od_gained", "monster_combat_damage_received"]
	const ALLOWED_TARGET_MODES: Array[String] = ["cell", "enemy_unit_or_boss_core", "cell_or_self"]

	var sv: int = _as_int(table.get("schema_version", 0))
	if sv < 1:
		errors.append("monster_hero_skills: missing or invalid schema_version")

	var skills: Variant = table.get("skills", null)
	if skills == null or not skills is Array:
		errors.append("monster_hero_skills: skills array missing")
		return errors

	if (skills as Array).is_empty():
		errors.append("monster_hero_skills: skills array is empty")

	var seen_card_ids: Array[String] = []
	var seen_passive_ids: Array[String] = []
	var seen_active_ids: Array[String] = []

	for i in range((skills as Array).size()):
		var entry: Variant = (skills as Array)[i]
		if not entry is Dictionary:
			errors.append("monster_hero_skills: skills[%d] is not an object" % i)
			continue
		var prefix := "monster_hero_skills[%d]" % i

		var card_id: String = str(entry.get("card_id", ""))
		if card_id.is_empty():
			errors.append(prefix + ": missing card_id")
		elif card_id in seen_card_ids:
			errors.append(prefix + ": duplicate card_id '%s'" % card_id)
		else:
			seen_card_ids.append(card_id)

		# Validate passive
		var passive: Variant = entry.get("passive", null)
		if passive == null or not passive is Dictionary:
			errors.append(prefix + ".passive: missing")
		else:
			var pid: String = str(passive.get("id", ""))
			if pid.is_empty():
				errors.append(prefix + ".passive.id: missing")
			elif pid in seen_passive_ids:
				errors.append(prefix + ".passive.id '%s': duplicate" % pid)
			else:
				seen_passive_ids.append(pid)

			var pstacks: int = _as_int(passive.get("max_stacks", -1))
			if pstacks < 1 or pstacks > 5:
				errors.append(prefix + ".passive.max_stacks=%d: must be 1..5" % pstacks)

			var trigger: String = str(passive.get("trigger", ""))
			if trigger.is_empty():
				errors.append(prefix + ".passive.trigger: missing")
			elif not trigger in ALLOWED_TRIGGERS:
				errors.append(prefix + ".passive.trigger '%s': unknown" % trigger)

		# Validate active
		var active: Variant = entry.get("active", null)
		if active == null or not active is Dictionary:
			errors.append(prefix + ".active: missing")
		else:
			var aid: String = str(active.get("id", ""))
			if aid.is_empty():
				errors.append(prefix + ".active.id: missing")
			elif aid in seen_active_ids:
				errors.append(prefix + ".active.id '%s': duplicate" % aid)
			else:
				seen_active_ids.append(aid)

			var cost: int = _as_int(active.get("base_cost", -1))
			if cost < 1 or cost > 10:
				errors.append(prefix + ".active.base_cost=%d: must be 1..10" % cost)

			var resolver: String = str(active.get("resolver_id", ""))
			if resolver.is_empty():
				errors.append(prefix + ".active.resolver_id: missing")
			elif not resolver in ALLOWED_RESOLVERS:
				errors.append(prefix + ".active.resolver_id '%s': unknown" % resolver)

			var tmode: String = str(active.get("target_mode", ""))
			if tmode.is_empty():
				errors.append(prefix + ".active.target_mode: missing")
			elif not tmode in ALLOWED_TARGET_MODES:
				errors.append(prefix + ".active.target_mode '%s': unknown" % tmode)

	return errors


# ── Phase C: tactical_structure_presentation (visual-only) ──

static func validate_tactical_structure_presentation_table(table: Dictionary) -> Array[String]:

	var errors: Array[String] = []
	var prefix := "[tactical_structure_presentation]"
	if _as_int(table.get("schema_version", 0)) != 1:
		errors.append("%s schema_version must be 1" % prefix)
		return errors
	var forbidden_hits: Array[String] = []
	_collect_structure_presentation_rule_fields(table, "", forbidden_hits)
	for field_path in forbidden_hits:
		errors.append("%s contains rule field '%s'" % [prefix, field_path])
	var assets: Variant = table.get("assets", null)
	if not assets is Dictionary:
		errors.append("%s assets missing" % prefix)
		return errors
	for profile_id in ["p05_foundation", "p08_fortification"]:
		var asset: Variant = assets.get(profile_id, null)
		if not asset is Dictionary:
			errors.append("%s asset '%s' missing" % [prefix, profile_id])
			continue
		for field in ["asset_id", "wrapper_scene", "socket_schema_version", "bounds_profile", "preview_mode", "state_variant_mode", "lod_policy"]:
			if not asset.has(field) or (field != "socket_schema_version" and str(asset[field]).is_empty()): errors.append("%s %s.%s missing" % [prefix, profile_id, field])
		if not _is_int_like(asset.get("socket_schema_version", null)) or _as_int(asset.get("socket_schema_version", 0)) != 1: errors.append("%s %s socket schema invalid" % [prefix, profile_id])
	var preview: Variant = table.get("preview", null)
	if not preview is Dictionary:
		errors.append("%s preview missing" % prefix)
	else:
		for state in ["legal", "replacement", "invalid", "pending", "compatibility_fallback"]:
			if str(preview.get(state, "")).is_empty(): errors.append("%s preview.%s missing" % [prefix, state])
	return errors

static func _collect_structure_presentation_rule_fields(value: Variant, path: String, hits: Array[String]) -> void:

	const FORBIDDEN_EXACT := ["integrity", "blocking", "cost", "reason_code", "reason_codes", "card_condition", "card_conditions", "replacement_permission", "replacement_permissions", "allowed_height", "allowed_heights", "minimum_foundation_height", "auto_raise_from_height"]
	if value is Dictionary:
		for raw_key in (value as Dictionary).keys():
			var key := str(raw_key)
			var lower := key.to_lower()
			var child_path := key if path.is_empty() else "%s.%s" % [path, key]
			if lower in FORBIDDEN_EXACT or lower.begins_with("allowed_height") or lower.contains("integrity") or lower.contains("replacement_permission"):
				hits.append(child_path)
			_collect_structure_presentation_rule_fields((value as Dictionary)[raw_key], child_path, hits)
	elif value is Array:
		for index in range((value as Array).size()):
			_collect_structure_presentation_rule_fields((value as Array)[index], "%s[%d]" % [path, index], hits)


# ── Phase C: tactical_structure_rules ──

static func validate_tactical_structure_rules_table(table: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var prefix := "[tactical_structure_rules]"
	if _as_int(table.get("schema_version", 0)) != 1:
		errors.append("%s schema_version must be 1" % prefix)
		return errors
	var profiles: Dictionary = table.get("profiles", {})
	if not profiles is Dictionary or profiles.is_empty():
		errors.append("%s profiles missing or empty" % prefix)
		return errors
	var required_profiles: Array[String] = [
		"p05_foundation", "p08_fortification", "p13_heat_sink",
		"p16_containment_wall", "p19_core_cathedral",
	]
	for profile_id in required_profiles:
		if not profiles.has(profile_id):
			errors.append("%s missing profile '%s'" % [prefix, profile_id])
			continue
		var profile: Variant = profiles[profile_id]
		if not profile is Dictionary:
			errors.append("%s profile '%s' is not a Dictionary" % [prefix, profile_id])
			continue
		errors.append_array(_validate_structure_profile(prefix, profile_id, profile))
	return errors


static func _validate_structure_profile(prefix: String, profile_id: String, profile: Dictionary) -> Array[String]:
	var errs: Array[String] = []
	var card_id: String = str(profile.get("card_id", ""))
	var allowed_heights: Variant = profile.get("allowed_heights", [])
	var auto_raise: Variant = profile.get("auto_raise_from_height", null)
	var min_foundation: Variant = profile.get("minimum_foundation_height", null)
	var core_integrity: Variant = profile.get("core_integrity", null)
	var reserved_slots: Variant = profile.get("reserved_garrison_slots", null)
	var modules: Variant = profile.get("modules", [])
	var garrison: Variant = profile.get("garrison_slots", [])
	var stabilizes: Variant = profile.get("stabilizes_terrain", null)
	var orientation: Variant = profile.get("orientation_mode", null)
	var requires_replacement: Variant = profile.get("requires_replacement", null)
	var replacement_profiles: Variant = profile.get("replacement_profile_ids", null)
	var requires_stable: Variant = profile.get("requires_stable_replacement", null)
	var requires_empty_garrison: Variant = profile.get("requires_empty_garrison", null)

	if profile_id == "p05_foundation":
		if card_id != "P05":
			errs.append("%s %s.card_id must be P05" % [prefix, profile_id])
		if not _is_array_equals_int(allowed_heights, [0, 1]):
			errs.append("%s %s.allowed_heights must be [0,1] of int-like values" % [prefix, profile_id])
		if not _is_int_like(auto_raise) or _as_int(auto_raise) != 0:
			errs.append("%s %s.auto_raise_from_height must be int-like 0" % [prefix, profile_id])
		if not _is_int_like(min_foundation) or _as_int(min_foundation) != 1:
			errs.append("%s %s.minimum_foundation_height must be int-like 1" % [prefix, profile_id])
		if not _is_int_like(core_integrity) or _as_int(core_integrity) != 2:
			errs.append("%s %s.core_integrity must be int-like 2" % [prefix, profile_id])
		if not _is_int_like(reserved_slots) or _as_int(reserved_slots) != 0:
			errs.append("%s %s.reserved_garrison_slots must be int-like 0" % [prefix, profile_id])
		if not _is_array_empty(modules):
			errs.append("%s %s.modules must be an empty Array" % [prefix, profile_id])
		if profile.has("garrison_slots"):
			if not garrison is Array:
				errs.append("%s %s.garrison_slots must be an Array" % [prefix, profile_id])
			elif not (garrison as Array).is_empty():
				errs.append("%s %s.garrison_slots must be empty" % [prefix, profile_id])
	elif profile_id == "p08_fortification":
		if card_id != "P08":
			errs.append("%s %s.card_id must be P08" % [prefix, profile_id])
		if not _is_array_equals_int(allowed_heights, [1]):
			errs.append("%s %s.allowed_heights must be [1] of int-like values" % [prefix, profile_id])
		if not _is_int_like(auto_raise) or _as_int(auto_raise) != -1:
			errs.append("%s %s.auto_raise_from_height must be int-like -1" % [prefix, profile_id])
		if not _is_int_like(min_foundation) or _as_int(min_foundation) != 1:
			errs.append("%s %s.minimum_foundation_height must be int-like 1" % [prefix, profile_id])
		if not _is_int_like(core_integrity) or _as_int(core_integrity) != 3:
			errs.append("%s %s.core_integrity must be int-like 3" % [prefix, profile_id])
		if not _is_int_like(reserved_slots) or _as_int(reserved_slots) != 1:
			errs.append("%s %s.reserved_garrison_slots must be int-like 1" % [prefix, profile_id])
		errs.append_array(_validate_garrison_profile(prefix, profile_id, garrison))
		errs.append_array(_validate_p08_module_layout(prefix, profile_id, modules))
	elif profile_id == "p13_heat_sink":
		if card_id != "P13":
			errs.append("%s %s.card_id must be P13" % [prefix, profile_id])
		if not _is_array_equals_int(allowed_heights, [0, 1]):
			errs.append("%s %s.allowed_heights must be [0,1] of int-like values" % [prefix, profile_id])
		if not _is_int_like(auto_raise) or _as_int(auto_raise) != -1:
			errs.append("%s %s.auto_raise_from_height must be int-like -1" % [prefix, profile_id])
		if not _is_int_like(min_foundation) or _as_int(min_foundation) != 0:
			errs.append("%s %s.minimum_foundation_height must be int-like 0" % [prefix, profile_id])
		if not _is_int_like(core_integrity) or _as_int(core_integrity) != 2:
			errs.append("%s %s.core_integrity must be int-like 2" % [prefix, profile_id])
		if not stabilizes is bool or not bool(stabilizes):
			errs.append("%s %s.stabilizes_terrain must be true" % [prefix, profile_id])
		if not _is_int_like(reserved_slots) or _as_int(reserved_slots) != 0:
			errs.append("%s %s.reserved_garrison_slots must be int-like 0" % [prefix, profile_id])
		errs.append_array(_validate_empty_structure_garrison(prefix, profile_id, garrison))
		if not _is_array_empty(modules):
			errs.append("%s %s.modules must be an empty Array" % [prefix, profile_id])
	elif profile_id == "p16_containment_wall":
		if card_id != "P16":
			errs.append("%s %s.card_id must be P16" % [prefix, profile_id])
		if not _is_array_equals_int(allowed_heights, [0, 1]):
			errs.append("%s %s.allowed_heights must be [0,1] of int-like values" % [prefix, profile_id])
		if not _is_int_like(auto_raise) or _as_int(auto_raise) != -1:
			errs.append("%s %s.auto_raise_from_height must be int-like -1" % [prefix, profile_id])
		if not _is_int_like(min_foundation) or _as_int(min_foundation) != 0:
			errs.append("%s %s.minimum_foundation_height must be int-like 0" % [prefix, profile_id])
		if not _is_int_like(core_integrity) or _as_int(core_integrity) != 2:
			errs.append("%s %s.core_integrity must be int-like 2" % [prefix, profile_id])
		if not stabilizes is bool or bool(stabilizes):
			errs.append("%s %s.stabilizes_terrain must be false" % [prefix, profile_id])
		if not _is_int_like(reserved_slots) or _as_int(reserved_slots) != 0:
			errs.append("%s %s.reserved_garrison_slots must be int-like 0" % [prefix, profile_id])
		if not orientation is String or str(orientation) != "selected_edge":
			errs.append("%s %s.orientation_mode must be selected_edge" % [prefix, profile_id])
		errs.append_array(_validate_empty_structure_garrison(prefix, profile_id, garrison))
		errs.append_array(_validate_p16_module_layout(prefix, profile_id, modules))
	elif profile_id == "p19_core_cathedral":
		if card_id != "P19":
			errs.append("%s %s.card_id must be P19" % [prefix, profile_id])
		if not _is_array_equals_int(allowed_heights, [1]):
			errs.append("%s %s.allowed_heights must be [1] of int-like values" % [prefix, profile_id])
		if not _is_int_like(auto_raise) or _as_int(auto_raise) != 1:
			errs.append("%s %s.auto_raise_from_height must be int-like 1" % [prefix, profile_id])
		if not _is_int_like(min_foundation) or _as_int(min_foundation) != 2:
			errs.append("%s %s.minimum_foundation_height must be int-like 2" % [prefix, profile_id])
		if not _is_int_like(core_integrity) or _as_int(core_integrity) != 4:
			errs.append("%s %s.core_integrity must be int-like 4" % [prefix, profile_id])
		if not stabilizes is bool or bool(stabilizes):
			errs.append("%s %s.stabilizes_terrain must be false" % [prefix, profile_id])
		if not _is_int_like(reserved_slots) or _as_int(reserved_slots) != 0:
			errs.append("%s %s.reserved_garrison_slots must be int-like 0" % [prefix, profile_id])
		if not requires_replacement is bool or not bool(requires_replacement):
			errs.append("%s %s.requires_replacement must be true" % [prefix, profile_id])
		if not _is_exact_string_array(replacement_profiles, ["p05_foundation", "p08_fortification"]):
			errs.append("%s %s.replacement_profile_ids must be [p05_foundation,p08_fortification]" % [prefix, profile_id])
		if not requires_stable is bool or not bool(requires_stable):
			errs.append("%s %s.requires_stable_replacement must be true" % [prefix, profile_id])
		if not requires_empty_garrison is bool or not bool(requires_empty_garrison):
			errs.append("%s %s.requires_empty_garrison must be true" % [prefix, profile_id])
		errs.append_array(_validate_empty_structure_garrison(prefix, profile_id, garrison))
		if not _is_array_empty(modules):
			errs.append("%s %s.modules must be an empty Array" % [prefix, profile_id])
	else:
		errs.append("%s unknown profile id '%s'" % [prefix, profile_id])
	return errs


static func _is_array_equals_int(raw: Variant, expected: Array) -> bool:
	if not raw is Array:
		return false
	var values: Array = raw
	if values.size() != expected.size():
		return false
	for i in range(expected.size()):
		if not _is_int_like(values[i]) or _as_int(values[i]) != _as_int(expected[i]):
			return false
	return true


static func _is_array_empty(raw: Variant) -> bool:
	return raw is Array and (raw as Array).is_empty()


static func _is_exact_string_array(raw: Variant, expected: Array[String]) -> bool:
	if not raw is Array:
		return false
	var values: Array = raw
	if values.size() != expected.size():
		return false
	for i in range(expected.size()):
		if not values[i] is String or str(values[i]) != expected[i]:
			return false
	return true


static func _validate_empty_structure_garrison(prefix: String, profile_id: String, garrison: Variant) -> Array[String]:
	if not garrison is Array:
		return ["%s %s.garrison_slots must be an Array" % [prefix, profile_id]]
	if not (garrison as Array).is_empty():
		return ["%s %s.garrison_slots must be empty" % [prefix, profile_id]]
	return []


static func _validate_garrison_profile(prefix: String, profile_id: String, garrison: Variant) -> Array[String]:
	var errs: Array[String] = []
	if not garrison is Array:
		errs.append("%s %s.garrison_slots must be an Array" % [prefix, profile_id])
		return errs
	if (garrison as Array).size() != 1:
		errs.append("%s %s.garrison_slots must contain exactly 1 descriptor" % [prefix, profile_id])
		return errs
	var slot: Variant = (garrison as Array)[0]
	if not slot is Dictionary:
		errs.append("%s %s.garrison_slots[0] is not a Dictionary" % [prefix, profile_id])
		return errs
	if str((slot as Dictionary).get("slot_id", "")) != "garrison_0":
		errs.append("%s %s.garrison_slots[0].slot_id must be garrison_0" % [prefix, profile_id])
	if str((slot as Dictionary).get("socket_name", "")) != "Garrison0":
		errs.append("%s %s.garrison_slots[0].socket_name must be Garrison0" % [prefix, profile_id])
	if str((slot as Dictionary).get("slot_role", "")) != "rampart":
		errs.append("%s %s.garrison_slots[0].slot_role must be rampart" % [prefix, profile_id])
	var enabled: Variant = (slot as Dictionary).get("enabled", true)
	if not enabled is bool:
		errs.append("%s %s.garrison_slots[0].enabled must be bool" % [prefix, profile_id])
	elif bool(enabled):
		errs.append("%s %s.garrison_slots[0].enabled must be false" % [prefix, profile_id])
	return errs


static func _validate_p08_module_layout(prefix: String, profile_id: String, modules: Variant) -> Array[String]:
	var errs: Array[String] = []
	if not modules is Array:
		errs.append("%s %s.modules must be an Array" % [prefix, profile_id])
		return errs
	var expected: Array[Dictionary] = [
		{"kind": "gatehouse", "relative_edge": "forward", "integrity": 2},
		{"kind": "wall", "relative_edge": "left", "integrity": 2},
		{"kind": "wall", "relative_edge": "right", "integrity": 2},
		{"kind": "wall", "relative_edge": "rear", "integrity": 2},
	]
	if (modules as Array).size() != expected.size():
		errs.append("%s %s.modules must contain exactly 4 entries" % [prefix, profile_id])
		return errs
	for i in range(expected.size()):
		var module: Variant = (modules as Array)[i]
		var expected_module: Dictionary = expected[i]
		if not module is Dictionary:
			errs.append("%s %s.modules[%d] is not a Dictionary" % [prefix, profile_id, i])
			continue
		for key in expected_module:
			if (module as Dictionary).get(key) != expected_module[key]:
				errs.append("%s %s.modules[%d].%s must be %s" % [prefix, profile_id, i, key, str(expected_module[key])])
	return errs


static func _validate_p16_module_layout(prefix: String, profile_id: String, modules: Variant) -> Array[String]:
	var errs: Array[String] = []
	if not modules is Array:
		return ["%s %s.modules must be an Array" % [prefix, profile_id]]
	if (modules as Array).size() != 1:
		return ["%s %s.modules must contain exactly 1 selected wall" % [prefix, profile_id]]
	var module: Variant = (modules as Array)[0]
	if not module is Dictionary:
		return ["%s %s.modules[0] is not a Dictionary" % [prefix, profile_id]]
	var expected := {"kind": "wall", "relative_edge": "selected", "integrity": 2}
	for key in expected:
		if (module as Dictionary).get(key) != expected[key]:
			errs.append("%s %s.modules[0].%s must be %s" % [prefix, profile_id, key, str(expected[key])])
	return errs


# ── Phase D1: tactical_garrison_rules ──

static func validate_tactical_garrison_rules_table(table: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var prefix := "[tactical_garrison_rules]"
	if not _is_int_like(table.get("schema_version", null)) or _as_int(table.get("schema_version", 0)) != 1:
		errors.append("%s schema_version must be 1" % prefix)
		return errors

	var default_profile: Variant = table.get("default_unit_profile", null)
	if not default_profile is Dictionary:
		errors.append("%s default_unit_profile must be a Dictionary" % prefix)
	else:
		errors.append_array(_validate_garrison_unit_profile(prefix, "default_unit_profile", default_profile, {"can_garrison": true, "size_class": "normal", "range_profile_id": "none"}))

	var denied_tags: Variant = table.get("denied_tags", null)
	if not _garrison_string_array_matches(denied_tags, ["large", "fusion", "siege_beast"], false):
		errors.append("%s denied_tags must contain large, fusion and siege_beast exactly once" % prefix)

	var overrides: Variant = table.get("unit_overrides", null)
	var expected_overrides := {
		"P07": {"can_garrison": true, "size_class": "normal", "range_profile_id": "p07_channeler_high_ground"},
		"P15": {"can_garrison": true, "size_class": "normal", "range_profile_id": "none"},
		"A06": {"can_garrison": false, "size_class": "large", "range_profile_id": "none"},
	}
	if not overrides is Dictionary:
		errors.append("%s unit_overrides must be a Dictionary" % prefix)
	else:
		for card_id in expected_overrides:
			if not (overrides as Dictionary).has(card_id):
				errors.append("%s unit_overrides.%s is missing" % [prefix, card_id])
				continue
			var profile: Variant = (overrides as Dictionary)[card_id]
			if not profile is Dictionary:
				errors.append("%s unit_overrides.%s must be a Dictionary" % [prefix, card_id])
				continue
			errors.append_array(_validate_garrison_unit_profile(prefix, "unit_overrides.%s" % card_id, profile, expected_overrides[card_id]))
		for raw_card_id in (overrides as Dictionary):
			if str(raw_card_id).is_empty():
				errors.append("%s unit_overrides contains an empty card id" % prefix)
				continue
			if expected_overrides.has(str(raw_card_id)):
				continue
			var extra_profile: Variant = (overrides as Dictionary)[raw_card_id]
			if not extra_profile is Dictionary:
				errors.append("%s unit_overrides.%s must be a Dictionary" % [prefix, raw_card_id])
			else:
				errors.append_array(_validate_garrison_unit_profile(prefix, "unit_overrides.%s" % raw_card_id, extra_profile, {}))

	var slots: Variant = table.get("structure_slots", null)
	if not slots is Dictionary:
		errors.append("%s structure_slots must be a Dictionary" % prefix)
	else:
		if not (slots as Dictionary).has("p08_fortification:garrison_0"):
			errors.append("%s structure_slots.p08_fortification:garrison_0 is missing" % prefix)
		for raw_key in (slots as Dictionary):
			var key := str(raw_key)
			if key != "p08_fortification:garrison_0":
				errors.append("%s structure slot key '%s' is unknown" % [prefix, key])
				continue
			errors.append_array(_validate_garrison_slot_profile(prefix, key, (slots as Dictionary)[raw_key]))

	var ranges: Variant = table.get("range_profiles", null)
	if not ranges is Dictionary:
		errors.append("%s range_profiles must be a Dictionary" % prefix)
	else:
		if not (ranges as Dictionary).has("p07_channeler_high_ground"):
			errors.append("%s range_profiles.p07_channeler_high_ground is missing" % prefix)
		for raw_profile_id in (ranges as Dictionary):
			var profile_id := str(raw_profile_id)
			if profile_id != "p07_channeler_high_ground":
				errors.append("%s range profile '%s' is unknown" % [prefix, profile_id])
				continue
			errors.append_array(_validate_garrison_range_profile(prefix, profile_id, (ranges as Dictionary)[raw_profile_id]))

	if not _garrison_string_array_matches(table.get("fallback_landing_relative_order", null), ["rear", "left", "right", "front"], true):
		errors.append("%s fallback_landing_relative_order must be rear,left,right,front" % prefix)
	return errors


static func _validate_garrison_unit_profile(prefix: String, path: String, raw: Variant, expected: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if not raw is Dictionary:
		return ["%s %s must be a Dictionary" % [prefix, path]]
	var profile: Dictionary = raw
	var can_garrison: Variant = profile.get("can_garrison", null)
	var size_class: Variant = profile.get("size_class", null)
	var range_profile_id: Variant = profile.get("range_profile_id", null)
	if not can_garrison is bool:
		errors.append("%s %s.can_garrison must be bool" % [prefix, path])
	if not size_class is String or not str(size_class) in ["normal", "large", "fusion", "siege_beast"]:
		errors.append("%s %s.size_class is invalid" % [prefix, path])
	if not range_profile_id is String or str(range_profile_id).is_empty():
		errors.append("%s %s.range_profile_id must be a non-empty String" % [prefix, path])
	for field in expected:
		var actual: Variant = profile.get(field, null)
		if typeof(actual) != typeof(expected[field]) or actual != expected[field]:
			errors.append("%s %s.%s must be %s" % [prefix, path, field, str(expected[field])])
	return errors


static func _validate_garrison_slot_profile(prefix: String, key: String, raw: Variant) -> Array[String]:
	var errors: Array[String] = []
	if not raw is Dictionary:
		return ["%s structure_slots.%s must be a Dictionary" % [prefix, key]]
	var slot: Dictionary = raw
	var expected := {
		"enabled": true,
		"slot_role": "rampart",
		"socket_name": "Garrison0",
		"platform_height_offset": 1,
		"support_relative_edge": "front",
		"entry_mode": "adjacent_height_or_owner_passage",
	}
	for field in expected:
		var value: Variant = slot.get(field, null)
		if field == "platform_height_offset":
			if not _is_int_like(value) or _as_int(value) != 1:
				errors.append("%s structure_slots.%s.%s must be 1" % [prefix, key, field])
		elif typeof(value) != typeof(expected[field]) or value != expected[field]:
			errors.append("%s structure_slots.%s.%s must be %s" % [prefix, key, field, str(expected[field])])
	return errors


static func _validate_garrison_range_profile(prefix: String, profile_id: String, raw: Variant) -> Array[String]:
	var errors: Array[String] = []
	if not raw is Dictionary:
		return ["%s range_profiles.%s must be a Dictionary" % [prefix, profile_id]]
	var profile: Dictionary = raw
	var applies_to: Variant = profile.get("applies_to", null)
	if not applies_to is String or str(applies_to) != "normal_attack":
		errors.append("%s range_profiles.%s.applies_to must be normal_attack" % [prefix, profile_id])
	var strict_height: Variant = profile.get("requires_strict_height_advantage", null)
	if not strict_height is bool or not bool(strict_height):
		errors.append("%s range_profiles.%s.requires_strict_height_advantage must be true" % [prefix, profile_id])
	if not _garrison_offsets_match(profile.get("extra_attack_offsets", null)):
		errors.append("%s range_profiles.%s.extra_attack_offsets must be [-1,-2],[0,-2],[1,-2]" % [prefix, profile_id])
	var damage_bonus: Variant = profile.get("damage_bonus", null)
	if not _is_int_like(damage_bonus) or _as_int(damage_bonus) != 0:
		errors.append("%s range_profiles.%s.damage_bonus must be 0" % [prefix, profile_id])
	var affects_core: Variant = profile.get("affects_boss_core", null)
	if not affects_core is bool or bool(affects_core):
		errors.append("%s range_profiles.%s.affects_boss_core must be false" % [prefix, profile_id])
	var affects_skill: Variant = profile.get("affects_active_skill", null)
	if not affects_skill is bool or bool(affects_skill):
		errors.append("%s range_profiles.%s.affects_active_skill must be false" % [prefix, profile_id])
	return errors


static func _garrison_offsets_match(raw: Variant) -> bool:
	if not raw is Array or (raw as Array).size() != 3:
		return false
	var expected := [[-1, -2], [0, -2], [1, -2]]
	for index in range(expected.size()):
		var pair: Variant = (raw as Array)[index]
		if not pair is Array or (pair as Array).size() != 2:
			return false
		if not _is_int_like((pair as Array)[0]) or not _is_int_like((pair as Array)[1]):
			return false
		if _as_int((pair as Array)[0]) != expected[index][0] or _as_int((pair as Array)[1]) != expected[index][1]:
			return false
	return true


static func _garrison_string_array_matches(raw: Variant, expected: Array[String], preserve_order: bool) -> bool:
	if not raw is Array or (raw as Array).size() != expected.size():
		return false
	var values: Array[String] = []
	for value in raw as Array:
		if not value is String or str(value).is_empty() or values.has(str(value)):
			return false
		values.append(str(value))
	if preserve_order:
		return values == expected
	for value in expected:
		if not values.has(value):
			return false
	return true


static func get_errors() -> Array[String]:
	return _errors.duplicate()
