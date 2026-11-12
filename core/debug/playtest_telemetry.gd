extends RefCounted
class_name PlaytestTelemetry
## PlaytestTelemetry — 轻量 Playtest 数据记录系统
## 记录每局/每回合关键指标，支持 Console Summary + 可选 JSONL 输出

# ============================================================
# Static
# ============================================================
static var _next_run_id: int = 1


# ============================================================
# 每局总表
# ============================================================
var run_id: int = 0
var result: String = "unknown"
var turn_count: int = 0
var player_hp_end: int = 0
var boss_hp_end: int = 0
var max_player_od_layer: int = 1
var max_player_compat_od: int = 0
var max_boss_od: int = 0
var max_depth: int = 0
var backlash_trigger_count: int = 0
var total_cards_played: int = 0
var total_monster_attacks: int = 0
var total_building_replacements: int = 0
var total_building_activations: int = 0
var finishers_played: int = 0
var routes_completed: int = 0
var boss_cards_played: int = 0
var heat_cycle_count: int = 0
var fatigue_trigger_count: int = 0
var total_fatigue_damage: int = 0
var player_graveyard_end: int = 0
var boss_graveyard_end: int = 0

# Phase 26C: Core Command counters
var core_commands_used_total: int = 0
var surge_uses: int = 0
var vent_uses: int = 0
var engine_charge_spent_on_commands: int = 0
var core_command_failures_by_reason: Dictionary = {}

# Phase 26E: Movement telemetry
var total_unit_moves: int = 0
var self_unit_moves: int = 0
var core_redeploy_moves: int = 0
var boss_unit_moves: int = 0
var movement_cancel_count: int = 0
var movement_failures_by_reason: Dictionary = {}
var routes_opened_by_move: int = 0
var direct_boss_attacks_after_move: int = 0

# Phase 27B: Vanguard move/attack telemetry
var vanguard_move_attempts: int = 0
var vanguard_move_successes: int = 0
var vanguard_attack_attempts: int = 0
var vanguard_attack_successes: int = 0
var vanguard_core_attack_attempts: int = 0
var vanguard_core_attack_successes: int = 0
var illegal_cell_click_rejections: int = 0
var boss_vanguard_moves: int = 0
var boss_vanguard_attacks: int = 0
var boss_vanguard_core_attacks: int = 0

# Phase 27C: Core breach / facing / OD breach telemetry
var total_normal_core_breaches: int = 0
var total_od_core_breaches: int = 0
var total_unit_turns: int = 0
var total_engagement_blocks: int = 0
var total_guard_interceptions: int = 0
var boss_core_breaches: int = 0
var boss_unit_turns: int = 0

# Phase 27H-R0: Soft pacing telemetry (schema v2)
const SCHEMA_VERSION: int = 2
var style_id: String = "unclassified"
var seed: int = -1
var run_label: String = ""
var player_turn_count: int = 0
var full_round_count: int = 0
var player_hp_min: int = -1
var boss_hp_min: int = -1
var command_totals: Dictionary = {}
var command_economy: Dictionary = {}
var hero_skill_uses: Dictionary = {}
var monster_deploy_counts: Dictionary = {}
var damage_by_source: Dictionary = {}
var boss_action_totals: Dictionary = {}
var boss_stop_reasons: Dictionary = {}
var boss_turn_summaries: Array[Dictionary] = []
var phase_entry_turns: Dictionary = {}
var invalid_reasons: Dictionary = {}
var od_zone_entries: Dictionary = {}
var depth_recovery_count: int = 0
var depth_recovery_amount: int = 0
var route_start_counts: Dictionary = {}
var route_complete_counts: Dictionary = {}
var route_abandon_count: int = 0

# Phase 27J-R0: short-cycle heat / OD release telemetry.
var heat_gained_total: int = 0
var heat_converted_total: int = 0
var od_release_count: int = 0
var first_release_player_turn: int = -1
var peak_heat: int = 0

# Phase 27K-R1-A: immutable OD feedback source audit.
var od_feedback_last_sequence: int = 0
var od_feedback_event_ids_seen: Dictionary = {}
var od_feedback_events_by_kind: Dictionary = {}
var feedback_events_by_tier: Dictionary = {}
var heat_gain_by_source_family: Dictionary = {}
var raw_heat_by_source_family: Dictionary = {}
var attenuated_heat_by_source_family: Dictionary = {}
var heat_wasted_at_cap: int = 0
var first_heated_player_turn: int = -1
var first_overdrive_player_turn: int = -1
var layer_advance_turns: Array[int] = []
var unclassified_positive_heat_events: int = 0

# ============================================================

# 每回合快照
# ============================================================
var turn_snapshots: Array[Dictionary] = []
var event_log: Array[Dictionary] = []


# ============================================================
# 生命周期
# ============================================================

func start_run(p_style_id: String = "unclassified", p_seed: int = -1, p_run_label: String = "") -> void:
	run_id = _next_run_id
	_next_run_id += 1
	result = "unknown"
	turn_count = 0
	player_hp_end = 0
	boss_hp_end = 0
	max_player_od_layer = 1
	max_player_compat_od = 0
	max_boss_od = 0
	max_depth = 0
	backlash_trigger_count = 0
	total_cards_played = 0
	total_monster_attacks = 0
	total_building_replacements = 0
	total_building_activations = 0
	finishers_played = 0
	routes_completed = 0
	boss_cards_played = 0
	player_graveyard_end = 0
	boss_graveyard_end = 0
	core_commands_used_total = 0; surge_uses = 0; vent_uses = 0; engine_charge_spent_on_commands = 0
	core_command_failures_by_reason.clear()
	total_unit_moves = 0; self_unit_moves = 0; core_redeploy_moves = 0; boss_unit_moves = 0
	movement_cancel_count = 0; movement_failures_by_reason.clear()
	routes_opened_by_move = 0; direct_boss_attacks_after_move = 0
	vanguard_move_attempts = 0; vanguard_move_successes = 0
	vanguard_attack_attempts = 0; vanguard_attack_successes = 0
	vanguard_core_attack_attempts = 0; vanguard_core_attack_successes = 0
	illegal_cell_click_rejections = 0
	boss_vanguard_moves = 0; boss_vanguard_attacks = 0; boss_vanguard_core_attacks = 0
	total_normal_core_breaches = 0; total_od_core_breaches = 0; total_unit_turns = 0
	total_engagement_blocks = 0; total_guard_interceptions = 0
	boss_core_breaches = 0; boss_unit_turns = 0
	# Phase 27H-R0
	style_id = p_style_id
	seed = p_seed
	run_label = p_run_label
	player_turn_count = 0
	full_round_count = 0
	player_hp_min = -1
	boss_hp_min = -1
	command_totals.clear()
	command_economy = {"player": {"spent": 0, "refunded": 0, "unused": 0, "gained": 0}, "boss": {"spent": 0, "refunded": 0, "unused": 0, "gained": 0}}
	hero_skill_uses.clear()
	monster_deploy_counts.clear()
	damage_by_source.clear()
	boss_action_totals.clear()
	boss_stop_reasons.clear()
	boss_turn_summaries.clear()
	phase_entry_turns.clear()
	invalid_reasons.clear()
	od_zone_entries.clear()
	depth_recovery_count = 0
	depth_recovery_amount = 0
	route_start_counts.clear()
	route_complete_counts.clear()
	route_abandon_count = 0
	heat_gained_total = 0
	heat_converted_total = 0
	od_release_count = 0
	first_release_player_turn = -1
	peak_heat = 0
	od_feedback_last_sequence = 0
	od_feedback_event_ids_seen.clear()
	od_feedback_events_by_kind.clear()
	feedback_events_by_tier.clear()
	heat_gain_by_source_family.clear()
	raw_heat_by_source_family.clear()
	attenuated_heat_by_source_family.clear()
	heat_wasted_at_cap = 0
	first_heated_player_turn = -1
	first_overdrive_player_turn = -1
	layer_advance_turns.clear()
	unclassified_positive_heat_events = 0
	turn_snapshots.clear()
	event_log.clear()
	print("[PLAYTEST] Run #%d started style=%s seed=%d label=%s" % [run_id, style_id, seed, run_label])


# ── Phase 26E: Movement Telemetry ──

func record_movement_result(result: Dictionary) -> void:
	if bool(result.get("ok", false)):
		total_unit_moves += 1
		var src := StringName(result.get("source", &""))
		match src:
			&"self": self_unit_moves += 1
			&"core_redeploy": core_redeploy_moves += 1
			&"boss_ai": boss_unit_moves += 1
		if bool(result.get("opened_boss_route", false)):
			routes_opened_by_move += 1
		return
	var reason := StringName(result.get("reason_code", &"unknown"))
	movement_failures_by_reason[reason] = int(movement_failures_by_reason.get(reason, 0)) + 1

func record_movement_cancelled() -> void:
	movement_cancel_count += 1

# ── Phase 27B: Vanguard Move/Attack Telemetry ──

func record_vanguard_move_attempt(ok: bool) -> void:
	vanguard_move_attempts += 1
	if ok: vanguard_move_successes += 1

func record_vanguard_attack_attempt(ok: bool, is_core: bool = false) -> void:
	if is_core:
		vanguard_core_attack_attempts += 1
		if ok: vanguard_core_attack_successes += 1
	else:
		vanguard_attack_attempts += 1
		if ok: vanguard_attack_successes += 1

func record_illegal_cell_click() -> void:
	illegal_cell_click_rejections += 1

func record_boss_vanguard_action(action: StringName) -> void:
	match action:
		&"move": boss_vanguard_moves += 1
		&"attack": boss_vanguard_attacks += 1
		&"core_attack": boss_vanguard_core_attacks += 1

# ── Phase 27C: Core Breach / Facing Telemetry ──

func record_core_breach(is_od: bool = false) -> void:
	if is_od: total_od_core_breaches += 1
	else: total_normal_core_breaches += 1

func record_unit_turn(is_boss: bool = false) -> void:
	total_unit_turns += 1
	if is_boss: boss_unit_turns += 1

func record_engagement_block() -> void:
	total_engagement_blocks += 1

func record_guard_interception() -> void:
	total_guard_interceptions += 1

func record_boss_core_breach() -> void:
	boss_core_breaches += 1

# ── Phase 26C: Core Command Telemetry ──

func record_core_command_result(result: Dictionary) -> void:
	if bool(result.get("ok", false)):
		core_commands_used_total += 1
		var charge_cost: int = int(result.get("charge_before", 0)) - int(result.get("charge_after", 0))
		engine_charge_spent_on_commands += maxi(0, charge_cost)
		match StringName(result.get("command_id", &"")):
			&"surge": surge_uses += 1
			&"vent": vent_uses += 1
		return
	var reason := StringName(result.get("reason_code", &"unknown"))
	core_command_failures_by_reason[reason] = int(core_command_failures_by_reason.get(reason, 0)) + 1


func finish_run(_result: String, context, _battle) -> void:
	result = _result
	if context:
		if context.player:
			if "hp" in context.player: player_hp_end = context.player.hp
			if "graveyard" in context.player: player_graveyard_end = context.player.graveyard.size()
		if context.enemy:
			if "hp" in context.enemy: boss_hp_end = context.enemy.hp
			if "graveyard" in context.enemy: boss_graveyard_end = context.enemy.graveyard.size()
	print_summary()
	_write_jsonl(context)


# ============================================================
# 回合快照
# ============================================================

func record_turn_snapshot(side: String, context, battle) -> void:
	turn_count += 1
	if context == null:
		return
	var od_mode = context.od_mode
	var cs = context.chain_system

	# Phase 27H-R0: track player turn count and full rounds
	if side == "player":
		player_turn_count += 1
	if side == "boss":
		full_round_count += 1

	# Track HP mins
	var p_hp: int = context.player.hp if context.player and "hp" in context.player else 0
	var b_hp: int = context.enemy.hp if context.enemy and "hp" in context.enemy else 0
	if player_hp_min < 0 or p_hp < player_hp_min:
		player_hp_min = p_hp
	if boss_hp_min < 0 or b_hp < boss_hp_min:
		boss_hp_min = b_hp

	# Board fingerprints
	var player_fp: String = ""
	if context.player and "field" in context.player:
		var ids: Array[String] = []
		for card in context.player.field:
			if card != null and "card_id" in card:
				var cell: String = ""
				if battle != null and battle.has_method("get_unit_cell"):
					cell = str(battle.get_unit_cell(card))
				else:
					cell = str(card.get_instance_id())
				ids.append(card.card_id + "@" + cell)
			ids.sort()
			player_fp = ",".join(ids)

	var boss_fp: String = ""
	if context.enemy and "field" in context.enemy:
		var ids: Array[String] = []
		for card in context.enemy.field:
			if card != null and "card_id" in card:
				var cell: String = ""
				if battle != null and battle.has_method("get_unit_cell"):
					cell = str(battle.get_unit_cell(card))
				else:
					cell = str(card.get_instance_id())
				ids.append(card.card_id + "@" + cell)
			ids.sort()
			boss_fp = ",".join(ids)

	# Read command economy from authoritative source
	var player_cmd_points: int = 0
	var boss_cmd_points: int = 0
	if battle != null and battle.has_method("get_command_economy_snapshot"):
		var snap = battle.get_command_economy_snapshot("player")
		if not snap.is_empty():
			player_cmd_points = int(snap.get("current_points", 0))
		snap = battle.get_command_economy_snapshot("boss")
		if not snap.is_empty():
			boss_cmd_points = int(snap.get("current_points", 0))

	# Boss phase / OD zones
	var boss_phase: int = context.enemy.combat_phase if context.enemy and "combat_phase" in context.enemy else 1
	var player_od_zone: String = ""
	if od_mode:
		var summary: Dictionary = od_mode.get_engine_summary()
		player_od_zone = str(summary.get("zone", "Calm"))

	var boss_od_zone: String = "Calm"
	if context.enemy and "od" in context.enemy:
		var bod: int = context.enemy.od
		if bod >= 10: boss_od_zone = "Overdrive"
		elif bod >= 5: boss_od_zone = "Heated"

	var snapshot := {
		"run_id": run_id,
		"turn": turn_count,
		"side": side,
		"player_hp": p_hp,
		"boss_hp": b_hp,
		"player_od_layer": od_mode.get_engine_layer() if od_mode else 1,
		"player_od_charge": 0,
		"player_compat_od": 0,
		"boss_od": context.enemy.od if context.enemy and "od" in context.enemy else 0,
		"depth": context.depth_pressure if context else 0,
		"backlash_turns": context.backlash_turns_remaining if context else 0,
		"player_hand_count": context.player.hand.size() if context.player and "hand" in context.player else 0,
		"player_front_count": context.player.field.size() if context.player and "field" in context.player else 0,
		"player_back_count": context.player.traps.size() if context.player and "traps" in context.player else 0,
		"boss_front_count": context.enemy.field.size() if context.enemy and "field" in context.enemy else 0,
		"boss_back_count": context.enemy.traps.size() if context.enemy and "traps" in context.enemy else 0,
		"route_state": cs.current_route_id if cs else "",
		# Phase 27H-R0 additions
		"player_turn": player_turn_count,
		"full_round": full_round_count,
		"player_shield": context.player.shield if context.player and "shield" in context.player else 0,
		"boss_shield": context.enemy.boss_shield if context.enemy and "boss_shield" in context.enemy else 0,
		"boss_phase": boss_phase,
		"player_od_zone": player_od_zone,
		"boss_od_zone": boss_od_zone,
		"player_command": player_cmd_points,
		"boss_command": boss_cmd_points,
		"player_board_fingerprint": player_fp,
		"boss_board_fingerprint": boss_fp,
		"route_step": cs.current_step if cs else 0,
	}

	if od_mode:
		var summary: Dictionary = od_mode.get_engine_summary()
		snapshot["player_od_charge"] = summary.get("charge", 0)
		snapshot["player_compat_od"] = summary.get("compat_od", 0)

	turn_snapshots.append(snapshot)

	# 更新 max 值
	if snapshot["player_od_layer"] > max_player_od_layer:
		max_player_od_layer = snapshot["player_od_layer"]
	if snapshot["player_compat_od"] > max_player_compat_od:
		max_player_compat_od = snapshot["player_compat_od"]
	if snapshot["boss_od"] > max_boss_od:
		max_boss_od = snapshot["boss_od"]
	if snapshot["depth"] > max_depth:
		max_depth = snapshot["depth"]

	# Console 简短快照
	print("[PLAYTEST] T%d %s hp=%d boss=%d L%d charge=%d depth=%d hand=%d front=%d back=%d" % [
		turn_count, side, snapshot["player_hp"], snapshot["boss_hp"],
		snapshot["player_od_layer"], snapshot["player_od_charge"], snapshot["depth"],
		snapshot["player_hand_count"], snapshot["player_front_count"], snapshot["player_back_count"]
	])


# ============================================================
# 事件记录
# ============================================================

func record_od_feedback_event(event: Dictionary) -> bool:
	var event_id := str(event.get("event_id", ""))
	var sequence := int(event.get("sequence", 0))
	if event_id.is_empty() or sequence <= 0:
		invalid_reasons["od_feedback_invalid_identity"] = int(invalid_reasons.get("od_feedback_invalid_identity", 0)) + 1
		return false
	if od_feedback_event_ids_seen.has(event_id):
		invalid_reasons["od_feedback_duplicate"] = int(invalid_reasons.get("od_feedback_duplicate", 0)) + 1
		return false
	if sequence <= od_feedback_last_sequence:
		invalid_reasons["od_feedback_out_of_order"] = int(invalid_reasons.get("od_feedback_out_of_order", 0)) + 1
		return false

	od_feedback_last_sequence = sequence
	od_feedback_event_ids_seen[event_id] = sequence
	var event_kind := str(event.get("event_kind", "unknown"))
	var tier := str(event.get("presentation_tier", "micro"))
	_increment_od_feedback_counter(od_feedback_events_by_kind, event_kind)
	_increment_od_feedback_counter(feedback_events_by_tier, tier)

	match event_kind:
		"heat_committed":
			var family := str(event.get("source_family", "unclassified"))
			var raw := maxi(0, int(event.get("raw_heat_delta", 0)))
			var applied := maxi(0, int(event.get("applied_heat_delta", 0)))
			var attenuated := maxi(0, int(event.get("saturation_penalty", 0)))
			var wasted := maxi(0, int(event.get("wasted_at_cap", 0)))
			_increment_od_feedback_counter(raw_heat_by_source_family, family, raw)
			_increment_od_feedback_counter(heat_gain_by_source_family, family, applied)
			_increment_od_feedback_counter(attenuated_heat_by_source_family, family, attenuated)
			heat_wasted_at_cap += wasted
			heat_gained_total += applied
			peak_heat = maxi(peak_heat, int(event.get("heat_after", 0)))
			if raw > 0 and not bool(event.get("classified", false)):
				unclassified_positive_heat_events += 1
		"heat_converted":
			heat_converted_total += maxi(0, int(event.get("conversion_amount", 0)))
		"layer_advanced":
			var layer_after := int(event.get("layer_after", 1))
			max_player_od_layer = maxi(max_player_od_layer, layer_after)
			layer_advance_turns.append(player_turn_count)
		"release_committed":
			od_release_count += 1
			if first_release_player_turn < 0:
				first_release_player_turn = player_turn_count
		"zone_changed":
			var actor_side := str(event.get("actor_side", "player"))
			var zone_after := str(event.get("zone_after", ""))
			if not actor_side.is_empty() and not zone_after.is_empty():
				var zone_key := actor_side + ":" + zone_after
				_increment_od_feedback_counter(od_zone_entries, zone_key)
			if actor_side == "player" and zone_after == "Heated" and first_heated_player_turn < 0:
				first_heated_player_turn = player_turn_count
			if actor_side == "player" and zone_after == "Overdrive" and first_overdrive_player_turn < 0:
				first_overdrive_player_turn = player_turn_count

	var safe_event: Variant = _od_feedback_json_safe(event)
	if safe_event is Dictionary:
		var audit_entry: Dictionary = safe_event
		audit_entry["event"] = "od_feedback"
		audit_entry["turn"] = turn_count
		event_log.append(audit_entry)
		print("[OD_FLOW_AUDIT] %s" % JSON.stringify(audit_entry))
	return true


func _increment_od_feedback_counter(target: Dictionary, key: String, amount: int = 1) -> void:
	if key.is_empty() or amount == 0:
		return
	target[key] = int(target.get(key, 0)) + amount


func _od_feedback_json_safe(value: Variant) -> Variant:
	if value is Vector2i:
		return {"x": value.x, "y": value.y}
	if value is Vector2:
		return {"x": value.x, "y": value.y}
	if value is StringName:
		return str(value)
	if value is Dictionary:
		var safe_dict: Dictionary = {}
		for key in value:
			safe_dict[str(key)] = _od_feedback_json_safe(value[key])
		return safe_dict
	if value is Array:
		var safe_array: Array = []
		for item in value:
			safe_array.append(_od_feedback_json_safe(item))
		return safe_array
	if value is Object:
		return str(value)
	return value


func record_event(event_name: String, data: Dictionary = {}) -> void:
	var entry := data.duplicate()
	entry["event"] = event_name
	entry["turn"] = turn_count
	event_log.append(entry)

	match event_name:
		"card_played":
			total_cards_played += 1
			var cid: String = str(data.get("card_id", ""))
			if cid != "" and data.get("is_monster", false):
				monster_deploy_counts[cid] = int(monster_deploy_counts.get(cid, 0)) + 1
		"monster_attack":      total_monster_attacks += 1
		"building_replaced":   total_building_replacements += 1
		"building_activated":  total_building_activations += 1
		"finisher_played":     finishers_played += 1
		"route_completed":     routes_completed += 1
		"backlash_triggered":  backlash_trigger_count += 1
		"boss_card_played":    boss_cards_played += 1
		"heat_cycle_triggered":  heat_cycle_count += 1
		"fatigue_triggered":     fatigue_trigger_count += 1; total_fatigue_damage += int(data.get("damage", 0))
		"unit_moved":            total_unit_moves += 1
		"direct_boss_attack":    direct_boss_attacks_after_move += 1
		"core_breach":           total_normal_core_breaches += 1
		"od_core_breach":        total_od_core_breaches += 1
		"unit_turn":             total_unit_turns += 1
		"engagement_blocked":    total_engagement_blocks += 1
		"guard_intercepted":     total_guard_interceptions += 1
		"boss_core_breach":      boss_core_breaches += 1
		# Phase 27H-R0 new event handlers
		"command_result":
			_aggregate_command_result(data)
		"command_turn_opened":
			_aggregate_command_economy("gained", data)
		"command_turn_closed":
			_aggregate_command_economy("unused", data, "unused_cleared")
		"skill_used":
			var sid: String = str(data.get("card_id", ""))
			if sid != "": hero_skill_uses[sid] = int(hero_skill_uses.get(sid, 0)) + 1
		"damage":
			var st: String = str(data.get("source_type", "unknown"))
			damage_by_source[st] = int(damage_by_source.get(st, 0)) + int(data.get("amount", 0))
		"boss_action":
			_aggregate_boss_action(data)
		"boss_turn_stopped":
			var br: String = str(data.get("reason_code", "unknown"))
			boss_stop_reasons[br] = int(boss_stop_reasons.get(br, 0)) + 1
			boss_turn_summaries.append(data.duplicate())
		"phase_entered":
			var ph: int = int(data.get("phase", 0))
			if ph > 0: phase_entry_turns[str(ph)] = int(data.get("player_turn", 0))
		"invalid_action":
			var ir: String = str(data.get("reason_code", "unknown"))
			invalid_reasons[ir] = int(invalid_reasons.get(ir, 0)) + 1
		"depth_recovered":
			depth_recovery_count += 1
			depth_recovery_amount += int(data.get("amount", 0))
		"route_started":
			var rs: String = str(data.get("route_id", ""))
			if rs != "": route_start_counts[rs] = int(route_start_counts.get(rs, 0)) + 1
		"route_completed":
			var rc: String = str(data.get("route_id", ""))
			if rc != "": route_complete_counts[rc] = int(route_complete_counts.get(rc, 0)) + 1
			routes_completed += 1
		"route_abandoned":
			route_abandon_count += 1
		"od_zone_entered":
			var oz_side: String = str(data.get("side", ""))
			var oz_zone: String = str(data.get("new_zone", ""))
			if oz_side != "" and oz_zone != "":
				var oz_key: String = oz_side + ":" + oz_zone
				od_zone_entries[oz_key] = int(od_zone_entries.get(oz_key, 0)) + 1
		"heat_gained":
			var gained: int = maxi(0, int(data.get("amount", 0)))
			heat_gained_total += gained
			peak_heat = maxi(peak_heat, int(data.get("new_heat", 0)))
		"heat_converted":
			heat_converted_total += maxi(0, int(data.get("amount", 0)))
		"od_release":
			if bool(data.get("ok", false)):
				od_release_count += 1
				if first_release_player_turn < 0:
					first_release_player_turn = int(data.get("player_turn", player_turn_count))

	print("[PLAYTEST] Event: %s | %s" % [event_name, var_to_str(data)])


# ============================================================
# Phase 27H-R0: Event Aggregation Helpers (read-only)
# ============================================================

func _aggregate_command_result(data: Dictionary) -> void:
	var side: String = str(data.get("side", ""))
	var cmd: String = str(data.get("command_id", "unknown"))
	var ok: bool = bool(data.get("ok", false))
	var cost: int = int(data.get("cost", 0))
	var refund: int = int(data.get("refund", 0))

	# per-command totals
	if not command_totals.has(side):
		command_totals[side] = {}
	if not command_totals[side].has(cmd):
		command_totals[side][cmd] = {"success": 0, "failure": 0, "spent": 0, "refunded": 0}
	if ok:
		command_totals[side][cmd]["success"] = int(command_totals[side][cmd].get("success", 0)) + 1
	else:
		command_totals[side][cmd]["failure"] = int(command_totals[side][cmd].get("failure", 0)) + 1
	command_totals[side][cmd]["spent"] = int(command_totals[side][cmd].get("spent", 0)) + cost
	command_totals[side][cmd]["refunded"] = int(command_totals[side][cmd].get("refunded", 0)) + refund

	# command economy aggregation
	if command_economy.has(side):
		command_economy[side]["spent"] = int(command_economy[side].get("spent", 0)) + cost
		command_economy[side]["refunded"] = int(command_economy[side].get("refunded", 0)) + refund

func _aggregate_command_economy(field: String, data: Dictionary, src_key: String = "total") -> void:
	var side: String = str(data.get("side", ""))
	var value: int = int(data.get(src_key, 0))
	if command_economy.has(side):
		command_economy[side][field] = int(command_economy[side].get(field, 0)) + value

func _aggregate_boss_action(data: Dictionary) -> void:
	var cmd: String = str(data.get("command_id", "unknown"))
	var ok: bool = bool(data.get("ok", false))
	if not boss_action_totals.has(cmd):
		boss_action_totals[cmd] = {"success": 0, "failure": 0}
	if ok:
		boss_action_totals[cmd]["success"] = int(boss_action_totals[cmd].get("success", 0)) + 1
	else:
		boss_action_totals[cmd]["failure"] = int(boss_action_totals[cmd].get("failure", 0)) + 1


# ============================================================
# Console Summary
# ============================================================

func print_summary() -> void:
	print("[PLAYTEST] ══════════════════════════════════════")
	print("[PLAYTEST] Run #%d Summary" % run_id)
	print("[PLAYTEST] ══════════════════════════════════════")
	print("[PLAYTEST] result=%s turns=%d" % [result, turn_count])
	print("[PLAYTEST] player_hp=%d boss_hp=%d" % [player_hp_end, boss_hp_end])
	print("[PLAYTEST] max_layer=%d max_compat_od=%d max_boss_od=%d max_depth=%d" % [max_player_od_layer, max_player_compat_od, max_boss_od, max_depth])
	print("[PLAYTEST] backlash=%d attacks=%d replacements=%d finishers=%d" % [backlash_trigger_count, total_monster_attacks, total_building_replacements, finishers_played])
	print("[PLAYTEST] cards=%d buildings_used=%d routes=%d boss_cards=%d" % [total_cards_played, total_building_activations, routes_completed, boss_cards_played])
	print("[PLAYTEST] player_gy=%d boss_gy=%d events=%d" % [player_graveyard_end, boss_graveyard_end, event_log.size()])
	print("[PLAYTEST] heat_cycles=%d fatigue=%d fatigue_dmg=%d" % [heat_cycle_count, fatigue_trigger_count, total_fatigue_damage])
	print("[PLAYTEST] moves: total=%d self=%d redeploy=%d boss=%d cancel=%d opened_boss=%d direct_after=%d" % [total_unit_moves, self_unit_moves, core_redeploy_moves, boss_unit_moves, movement_cancel_count, routes_opened_by_move, direct_boss_attacks_after_move])
	print("[PLAYTEST] ══════════════════════════════════════")


# ============================================================
# Phase 27H-R0: build_summary — centralized read-only summary
# ============================================================

func build_summary() -> Dictionary:
	var pacing_adv: Dictionary = classify_advisory_pacing(style_id, player_turn_count)
	var no_prog: Array = analyze_no_progress_rounds()
	return {
		# Legacy fields
		"run_id": run_id,
		"result": result,
		"turn_count": turn_count,
		"player_hp_end": player_hp_end,
		"boss_hp_end": boss_hp_end,
		"max_player_od_layer": max_player_od_layer,
		"max_player_compat_od": max_player_compat_od,
		"max_boss_od": max_boss_od,
		"max_depth": max_depth,
		"backlash_trigger_count": backlash_trigger_count,
		"total_cards_played": total_cards_played,
		"total_monster_attacks": total_monster_attacks,
		"total_building_replacements": total_building_replacements,
		"total_building_activations": total_building_activations,
		"finishers_played": finishers_played,
		"routes_completed": routes_completed,
		"boss_cards_played": boss_cards_played,
		"player_graveyard_end": player_graveyard_end,
		"boss_graveyard_end": boss_graveyard_end,
		# Phase 27H-R0 additions
		"schema_version": SCHEMA_VERSION,
		"style_id": style_id,
		"seed": seed,
		"run_label": run_label,
		"player_turn_count": player_turn_count,
		"full_round_count": full_round_count,
		"player_hp_min": player_hp_min,
		"boss_hp_min": boss_hp_min,
		"command_totals": command_totals.duplicate(true),
		"command_economy": command_economy.duplicate(true),
		"hero_skill_uses": hero_skill_uses.duplicate(true),
		"monster_deploy_counts": monster_deploy_counts.duplicate(true),
		"damage_by_source": damage_by_source.duplicate(true),
		"boss_action_totals": boss_action_totals.duplicate(true),
		"boss_stop_reasons": boss_stop_reasons.duplicate(true),
		"boss_turn_summaries": boss_turn_summaries.duplicate(true),
		"phase_entry_turns": phase_entry_turns.duplicate(true),
		"invalid_reasons": invalid_reasons.duplicate(true),
		"od_zone_entries": od_zone_entries.duplicate(true),
		"depth_recovery_count": depth_recovery_count,
		"depth_recovery_amount": depth_recovery_amount,
		"route_start_counts": route_start_counts.duplicate(true),
		"route_complete_counts": route_complete_counts.duplicate(true),
		"route_abandon_count": route_abandon_count,
		"heat_gained_total": heat_gained_total,
		"heat_converted_total": heat_converted_total,
		"od_release_count": od_release_count,
		"first_release_player_turn": first_release_player_turn,
		"peak_heat": peak_heat,
		"od_feedback_last_sequence": od_feedback_last_sequence,
		"od_feedback_event_ids_seen": od_feedback_event_ids_seen.duplicate(true),
		"od_feedback_events_by_kind": od_feedback_events_by_kind.duplicate(true),
		"feedback_events_by_tier": feedback_events_by_tier.duplicate(true),
		"heat_gain_by_source_family": heat_gain_by_source_family.duplicate(true),
		"raw_heat_by_source_family": raw_heat_by_source_family.duplicate(true),
		"attenuated_heat_by_source_family": attenuated_heat_by_source_family.duplicate(true),
		"heat_wasted_at_cap": heat_wasted_at_cap,
		"first_heated_player_turn": first_heated_player_turn,
		"first_overdrive_player_turn": first_overdrive_player_turn,
		"layer_advance_turns": layer_advance_turns.duplicate(),
		"unclassified_positive_heat_events": unclassified_positive_heat_events,
		"no_progress_rounds": no_prog,
		"pacing_advisory": pacing_adv,
		"turn_snapshots": turn_snapshots.duplicate(true),
		"event_log": event_log.duplicate(true),
	}


# ============================================================
# Phase 27H-R0: No-Progress Diagnostic Analysis (read-only)
# ============================================================

func analyze_no_progress_rounds() -> Array[Dictionary]:
	var flags: Array[Dictionary] = []
	var player_snaps: Array[Dictionary] = []
	for snap in turn_snapshots:
		if str(snap.get("side", "")) == "player":
			player_snaps.append(snap)

	if player_snaps.size() < 3:
		return flags

	var consecutive_no_progress: int = 0
	var start_turn: int = -1

	for i in range(1, player_snaps.size()):
		var prev := player_snaps[i - 1]
		var cur := player_snaps[i]
		if _snapshots_identical_for_progress(prev, cur):
			if consecutive_no_progress == 0:
				start_turn = int(cur.get("player_turn", 0))
			consecutive_no_progress += 1
			if consecutive_no_progress >= 2:
				flags.append({
					"start_player_turn": start_turn,
					"end_player_turn": int(cur.get("player_turn", 0)),
					"reason_code": "two_rounds_no_progress",
					"forces_runtime_penalty": false,
				})
		else:
			consecutive_no_progress = 0
			start_turn = -1

	return flags

func _snapshots_identical_for_progress(a: Dictionary, b: Dictionary) -> bool:
	var keys := ["player_hp", "boss_hp", "player_shield", "boss_shield",
		"player_front_count", "player_back_count", "boss_front_count", "boss_back_count",
		"player_board_fingerprint", "boss_board_fingerprint",
		"boss_phase", "route_state", "route_step",
		"player_compat_od", "boss_od", "depth"]
	for key in keys:
		if str(a.get(key, "")) != str(b.get(key, "")):
			return false
	return true


# ============================================================
# Phase 27H-R0: Advisory Pacing Classification (read-only)
# ============================================================

func classify_advisory_pacing(p_style: String = "", p_turns: int = -1) -> Dictionary:
	var style := p_style if p_style != "" else style_id
	var turns := p_turns if p_turns >= 0 else player_turn_count
	var ranges := {
		"heat_burst": Vector2i(4, 7),
		"control": Vector2i(9, 12),
		"hero_synergy": Vector2i(6, 10),
		"unclassified": Vector2i(6, 10),
	}
	var band: Vector2i = ranges.get(style, ranges["unclassified"])
	var label := "within_observation_band"
	if turns < band.x:
		label = "faster_than_observation_band"
	elif turns > band.y:
		label = "slower_than_observation_band"
	return {"style_id": style, "player_turns": turns, "observed_min": band.x, "observed_max": band.y, "label": label}


# ============================================================
# JSONL 输出（可选，写文件失败不影响游戏）
# ============================================================

func _write_jsonl(_context) -> void:
	var summary := build_summary()
	var json_str: String = JSON.stringify(summary)
	if json_str == "" or json_str == "{}":
		return

	var path: String = "user://playtest_runs.jsonl"
	if style_id != "unclassified":
		path = "user://phase27h_playtest_runs.jsonl"

	var file := FileAccess.open(path, FileAccess.READ_WRITE)
	if file == null:
		file = FileAccess.open(path, FileAccess.WRITE)
		if file == null:
			print("[PLAYTEST] Cannot open %s for writing — skip" % path)
			return
	file.seek_end()
	file.store_line(json_str)
	file.close()
	print("[PLAYTEST] JSONL written to %s (globalized: %s)" % [path, ProjectSettings.globalize_path(path)])
