extends Node
class_name BattleSystem

## 场地容量上限 — Phase 4B-5（玩家/Boss 共用）
const MAX_FIELD_SIZE: int = 5
const MAX_TRAP_SIZE: int = 5

# Phase 5B-2: 建筑自动触发信号
signal building_auto_triggered(card_name: String, message: String)
signal back_row_triggered(card: CardData, receipt: Dictionary)
## Published only after a genuine hand construction and its spatial commit.
signal hand_structure_build_committed(card: CardData, fact: Dictionary)

signal unit_combat_state_changed(card: CardData, state_snapshot: Dictionary)
signal unit_destroyed(card: CardData, owner_side: StringName, reason: String)
signal garrison_transaction_committed(fact: Dictionary)
# Phase 26E: five-lane movement
signal unit_lane_changed(card: CardData, owner_side: StringName, from_lane: int, to_lane: int, source: StringName)

var edge_fortification_trial: RefCounted
var building_footprint_trial: RefCounted
var context: BattleContext
var field_system: FieldSystem
var graveyard_system: GraveyardSystem
var hub: SystemHub
var _heat_cycle_rng := RandomNumberGenerator.new()

# ===== Phase 5B-1: 建筑运行时状态管理 =====
# key = card.instance_id (int), value = {charge, charge_max, used_this_turn, interface_enabled}
var building_states: Dictionary = {}

# ============================================================
# 条件预检（出牌前调用，不消耗卡牌）
# ============================================================

# Phase 6A: 检索触发信号
signal card_tutored(source_card_name: String, found_card: CardData, message: String)
signal tutor_failed(source_card_name: String, reason: String)

const MonsterCombatRuleSnapshotClass := preload("res://core/config/monster_combat_rule_snapshot.gd")
const UnitCombatStateClass := preload("res://core/battle/unit_combat_state.gd")
const SkillResolverClass := preload("res://core/battle/monster_skill_resolver.gd")  # Phase 27E
const ODCoreCommandRuleSnapshotClass := preload("res://core/config/od_core_command_rule_snapshot.gd")

const TacticalGridRuleSnapshotClass := preload("res://core/config/tactical_grid_rule_snapshot.gd")
const TacticalUnitPatternSnapshotClass := preload("res://core/config/tactical_unit_pattern_snapshot.gd")
const TacticalCoreFacingRuleSnapshotClass := preload("res://core/config/tactical_core_facing_rule_snapshot.gd")
const TacticalCommandEconomySnapshotClass := preload("res://core/config/tactical_command_economy_snapshot.gd")
const BossTacticalAIProfileClass := preload("res://core/config/boss_tactical_ai_profile.gd")
const BossTacticalAIPlannerClass := preload("res://core/battle/boss_tactical_ai_planner.gd")
const CardPieceTraitSnapshotClass := preload("res://core/config/card_piece_trait_snapshot.gd")  # Phase 27I-R0
const TacticalStructureRuleSnapshotClass := preload("res://core/config/tactical_structure_rule_snapshot.gd")  # Phase C
const TacticalGarrisonRuleSnapshotClass := preload("res://core/config/tactical_garrison_rule_snapshot.gd")  # Phase D1
const TacticalSiegeRuleSnapshotClass := preload("res://core/config/tactical_siege_rule_snapshot.gd")
const TacticalSiegePlannerClass := preload("res://core/battle/tactical_siege_planner.gd")
const ODReleaseRuleSnapshotClass := preload("res://core/config/od_release_rule_snapshot.gd")  # Phase 27J
const ODReleaseResolverClass := preload("res://core/battle/od_release_resolver.gd")  # Phase 27J
const RitualFinisherTrialClass := preload("res://core/battle/ritual_finisher_trial.gd")
const INVALID_GRID_CELL := Vector2i(-1, -1)
# GB3J enables existing entry-search promises; earlier trials keep their baseline.
var on_play_tutors_enabled: bool = false
var steam_package_trial = null
var engineering_trial = null
func configure_engineering_trial(enabled: bool) -> void:
	engineering_trial=preload("res://core/battle/engineering_trial.gd").new(self) if enabled else null
func _engineering_card_play_status(card: CardData) -> Dictionary:
	if card==null or card.card_id not in ["E01","E02"]: return {"ok":true}
	if engineering_trial==null: return {"ok":false,"reason":"此入口未启用工程牌"}
	return engineering_trial.status(card)
func get_engineering_cast_status(card: CardData, selection: Variant) -> Dictionary:
	if engineering_trial==null: return {"ok":false,"reason":"此入口未启用工程牌"}
	return engineering_trial.cast_status(card,selection)

var basic_card_trial = null

func configure_basic_card_trial(enabled: bool) -> void:
	basic_card_trial=preload("res://core/battle/basic_card_trial.gd").new(self) if enabled else null

func _basic_card_play_status(card: CardData) -> Dictionary:
	if card==null or card.card_id not in ["B01","B02","B03","B04","B05"]: return {"ok":true,"reason":""}
	if basic_card_trial==null: return {"ok":false,"reason":"此入口未启用公共基础牌"}
	return basic_card_trial.status(card)

func configure_steam_package_trial(enabled: bool) -> void:
	steam_package_trial = preload("res://core/battle/steam_package_trial.gd").new(self) if enabled else null

func _steam_card_play_status(card: CardData) -> Dictionary:
	if card.card_id not in ["S01", "S02", "S03"]: return {"ok":true,"reason":""}
	if steam_package_trial == null: return {"ok":false,"reason":"此入口未启用蒸汽补强包"}
	return steam_package_trial.get_play_status(card)

# ── Phase 27I-R0: 棋子支付模式 ──
const PIECE_PAY_NONE: StringName = &"none"
const PIECE_PAY_COMMAND: StringName = &"command"
const PIECE_PAY_DEPTH: StringName = &"depth"

# ===== Phase 25D: 不可变规则快照（每场战斗注入一次）=====
var monster_combat_rules = MonsterCombatRuleSnapshotClass.default_snapshot()

# ===== Phase 27A: 5×5 Grid Authority =====
signal unit_cell_changed(card: CardData, owner_side: StringName, from_cell: Vector2i, to_cell: Vector2i, source: StringName)

var tactical_grid_rules = TacticalGridRuleSnapshotClass.default_snapshot()
var unit_cell_by_runtime_id: Dictionary = {}
var unit_by_cell: Dictionary = {}

func configure_tactical_grid_rules(snapshot) -> void:
	tactical_grid_rules = snapshot if snapshot != null else TacticalGridRuleSnapshotClass.default_snapshot()
	_ensure_tactical_board_state()


func _ensure_tactical_board_state() -> bool:
	if context == null or not context.has_method("configure_tactical_cells"):
		return false
	if context.get_tactical_cell_states().is_empty():
		context.configure_tactical_cells(tactical_grid_rules.get_all_cells())
	return not context.get_tactical_cell_states().is_empty()


func get_cell_state(cell: Vector2i) -> Dictionary:
	if not _ensure_tactical_board_state():
		return {}
	return context.get_tactical_cell_state(cell)


func get_all_cell_states() -> Dictionary:
	if not _ensure_tactical_board_state():
		return {}
	return context.get_tactical_cell_states()


func get_cell_height(cell: Vector2i) -> int:
	var state: Dictionary = get_cell_state(cell)
	return int(state.get("height", -1))


func get_cell_state_change_status(changes: Array[Dictionary], options: Dictionary = {}) -> Dictionary:
	if not _ensure_tactical_board_state():
		return {"ok": false, "reason_code": &"board_state_missing"}
	var terrain_status: Dictionary = context.tactical_board_state.get_change_status(changes)
	if not bool(terrain_status.get("ok", false)):
		return terrain_status.duplicate(true)
	var structure_status: Dictionary = get_terrain_structure_impact_status(changes, options)
	if not bool(structure_status.get("ok", false)):
		return structure_status.duplicate(true)
	var result: Dictionary = terrain_status.duplicate(true)
	result["structure_impact"] = structure_status.duplicate(true)
	return result


func commit_cell_state_changes(changes: Array[Dictionary], source: StringName = &"", options: Dictionary = {}) -> Dictionary:
	return _commit_cell_state_changes_composed(changes, source, options, [])


func _commit_cell_state_changes_composed(
	changes: Array[Dictionary],
	source: StringName,
	options: Dictionary,
	skipped_structure_ids: Array[StringName],
) -> Dictionary:
	if not _ensure_tactical_board_state():
		return {"ok": false, "reason_code": &"board_state_missing"}
	var initial_status: Dictionary = get_cell_state_change_status(changes, options)
	if not bool(initial_status.get("ok", false)):
		return initial_status.duplicate(true)
	var initial_terrain_preview: Dictionary = _project_terrain_fact(changes, source)
	var initial_foundation: Dictionary = _prepare_foundation_reconcile_from_terrain_fact(
		initial_terrain_preview, options, skipped_structure_ids, false
	)
	if not bool(initial_foundation.get("ok", false)):
		return initial_foundation.duplicate(true)
	# Repeat the composed terrain + structure preflight at the final synchronous
	# boundary. No callback or await may occur between the locked terrain and
	# foundation plans or their two authority commits below.
	var final_status: Dictionary = get_cell_state_change_status(changes, options)
	if not bool(final_status.get("ok", false)):
		return final_status.duplicate(true)
	var final_terrain_preview: Dictionary = _project_terrain_fact(changes, source)
	var final_foundation: Dictionary = _prepare_foundation_reconcile_from_terrain_fact(
		final_terrain_preview, options, skipped_structure_ids, false
	)
	if not bool(final_foundation.get("ok", false)):
		return final_foundation.duplicate(true)
	var terrain_fact: Dictionary = context.tactical_board_state.commit_changes(changes, source, options)
	if not bool(terrain_fact.get("ok", false)):
		return terrain_fact.duplicate(true)
	var foundation_fact: Dictionary = context.tactical_structure_board_state.commit_foundation_reconcile(
		final_foundation.get("plan", {}), options
	)
	if not bool(foundation_fact.get("ok", false)):
		return {
			"ok": false,
			"reason_code": foundation_fact.get("reason_code", &"foundation_reconcile_stale"),
			"terrain": terrain_fact.duplicate(true),
			"foundation": foundation_fact.duplicate(true),
		}
	var result: Dictionary = terrain_fact.duplicate(true)
	result["terrain"] = terrain_fact.duplicate(true)
	result["foundation"] = foundation_fact.duplicate(true)
	result["foundation_before"] = foundation_fact.get("foundation_before", []).duplicate(true)
	result["foundation_after"] = foundation_fact.get("foundation_after", []).duplicate(true)
	result["turn_side"] = final_foundation.get("turn_side", &"")
	return result.duplicate(true)


func _project_terrain_fact(changes: Array[Dictionary], source: StringName) -> Dictionary:
	var projected_changes: Array[Dictionary] = []
	for change: Dictionary in changes:
		var cell: Vector2i = change.get("cell", INVALID_GRID_CELL)
		var before: Dictionary = get_cell_state(cell)
		var after: Dictionary = before.duplicate(true)
		after["height"] = int(change.get("target_height", before.get("height", 0)))
		after["surface"] = StringName(str(change.get("target_surface", before.get("surface", &"flat"))))
		after["revision"] = int(before.get("revision", 0)) + 1
		projected_changes.append({
			"cell": cell,
			"before": before.duplicate(true),
			"after": after.duplicate(true),
		})
	return {
		"ok": true,
		"reason_code": &"ok",
		"source": source,
		"changes": projected_changes,
	}


func _foundation_transaction_id_from_terrain_fact(terrain_fact: Dictionary) -> StringName:
	var coordinates: Array[String] = []
	for change_value: Variant in terrain_fact.get("changes", []):
		if not change_value is Dictionary:
			continue
		var change: Dictionary = change_value
		var cell: Vector2i = change.get("cell", INVALID_GRID_CELL)
		var after: Dictionary = change.get("after", {})
		coordinates.append("%d,%d@%d" % [cell.x, cell.y, int(after.get("revision", -1))])
	return StringName("terrain:%s:%s" % [str(terrain_fact.get("source", &"")), ";".join(coordinates)])


func _prepare_foundation_reconcile_from_terrain_fact(
	terrain_fact: Dictionary,
	options: Dictionary,
	skipped_structure_ids: Array[StringName],
	verify_committed_terrain: bool,
) -> Dictionary:
	if context == null or context.tactical_structure_board_state == null:
		return {"ok": false, "reason_code": &"board_state_missing"}
	var skipped: Dictionary = {}
	for structure_id: StringName in skipped_structure_ids:
		skipped[structure_id] = true
	var reconcile_changes: Array[Dictionary] = []
	for change_value: Variant in terrain_fact.get("changes", []):
		if not change_value is Dictionary:
			return {"ok": false, "reason_code": &"foundation_reconcile_invalid"}
		var change: Dictionary = change_value
		var cell_value: Variant = change.get("cell", null)
		var after_value: Variant = change.get("after", null)
		if not cell_value is Vector2i or not after_value is Dictionary:
			return {"ok": false, "reason_code": &"foundation_reconcile_invalid"}
		var cell: Vector2i = cell_value
		var after: Dictionary = after_value
		if verify_committed_terrain and get_cell_state(cell) != after:
			return {"ok": false, "reason_code": &"foundation_reconcile_stale"}
		var structure: Dictionary = get_structure_at_cell(cell)
		if structure.is_empty():
			continue
		# A passable platform shares durability, but the core tile owns foundation stability.
		if structure.get("cell", cell) != cell:
			continue
		var structure_id := StringName(str(structure.get("structure_id", &"")))
		if structure_id == &"" or skipped.has(structure_id):
			continue
		reconcile_changes.append({
			"structure_id": structure_id,
			"observed_height": int(after.get("height", -1)),
		})
	var current_structure_revision: int = int(context.tactical_structure_board_state.get_revision())
	var expected_structure_revision: int = int(options.get("expected_structure_revision", current_structure_revision))
	var turn_side := StringName(str(options.get("turn_side", &"")))
	var plan := {
		"expected_structure_revision": expected_structure_revision,
		"transaction_id": _foundation_transaction_id_from_terrain_fact(terrain_fact),
		"cause": StringName(str(options.get("foundation_cause", &"terrain_lowered"))),
		"changes": reconcile_changes.duplicate(true),
	}
	var preview: Dictionary = context.tactical_structure_board_state.get_foundation_reconcile_status(plan)
	if not bool(preview.get("ok", false)):
		return preview.duplicate(true)
	var starts_cycle := false
	for transition_value: Variant in preview.get("transitions", []):
		if not transition_value is Dictionary:
			continue
		var transition: Dictionary = transition_value
		var before: Dictionary = transition.get("before", {})
		var after: Dictionary = transition.get("after", {})
		if StringName(str(before.get("foundation_state", &"stable"))) == &"stable" \
		and StringName(str(after.get("foundation_state", &"stable"))) == &"undermined":
			starts_cycle = true
			break
	if starts_cycle and turn_side not in [&"player", &"boss"]:
		return {"ok": false, "reason_code": &"foundation_window_not_ready"}
	return {
		"ok": true,
		"reason_code": &"ok",
		"turn_side": turn_side,
		"starts_cycle": starts_cycle,
		"plan": plan.duplicate(true),
		"preview": preview.duplicate(true),
	}


func reconcile_foundations_from_terrain_fact(terrain_fact: Dictionary, options: Dictionary = {}) -> Dictionary:
	var prepared: Dictionary = _prepare_foundation_reconcile_from_terrain_fact(terrain_fact, options, [], true)
	if not bool(prepared.get("ok", false)):
		return prepared.duplicate(true)
	var result: Dictionary = context.tactical_structure_board_state.commit_foundation_reconcile(prepared.get("plan", {}))
	result["turn_side"] = prepared.get("turn_side", &"")
	return result.duplicate(true)


func resolve_foundation_turn_begin(owner_side: StringName) -> Dictionary:
	return _resolve_foundation_turn_window(owner_side, &"turn_begin")


func resolve_foundation_turn_end(owner_side: StringName) -> Dictionary:
	var window_fact: Dictionary = _resolve_foundation_turn_window(owner_side, &"turn_end")
	if not bool(window_fact.get("ok", false)):
		return window_fact
	var collapse_ids: Array = window_fact.get("collapse_structure_ids", []).duplicate()
	collapse_ids.sort_custom(func(a: Variant, b: Variant) -> bool: return str(a) < str(b))
	var collapse_facts: Array[Dictionary] = []
	var garrison_aftermath: Array[Dictionary] = []
	for structure_id_value: Variant in collapse_ids:
		var structure_id := StringName(str(structure_id_value))
		var structure: Dictionary = context.tactical_structure_board_state.get_foundation_status(structure_id)
		if structure.is_empty() or StringName(str(structure.get("foundation_state", &""))) != &"collapse_due":
			continue
		# Test-only or stale non-card structures have no authoritative card
		# lifecycle to consume, so leave their due fact available for inspection.
		var source_card: CardData = _structure_card_for_owner(int(structure.get("source_runtime_id", 0)), owner_side)
		if StringName(str(structure.get("source_kind", &""))) == &"card" and source_card == null:
			continue
		var cell: Vector2i = structure.get("cell", INVALID_GRID_CELL)
		var terrain: Dictionary = get_cell_state(cell)
		if terrain.is_empty():
			continue
		var target_ref: Dictionary = context.tactical_structure_board_state.make_core_target_ref(
			cell, int(terrain.get("revision", -1))
		)
		var integrity: int = int(structure.get("integrity_current", 0))
		var preview: Dictionary = get_structure_damage_status(target_ref, integrity)
		if not bool(preview.get("ok", false)) or not bool(preview.get("core_destroyed", false)):
			continue
		var collapse_fact: Dictionary = _commit_structure_core_cleanup(
			preview, &"foundation_collapse", {}, &"foundation_collapse"
		)
		if not bool(collapse_fact.get("ok", false)):
			continue
		collapse_facts.append(collapse_fact.duplicate(true))
		for aftermath_value: Variant in collapse_fact.get("garrison_aftermath", []):
			if aftermath_value is Dictionary:
				garrison_aftermath.append((aftermath_value as Dictionary).duplicate(true))
	window_fact["collapse_facts"] = collapse_facts.duplicate(true)
	window_fact["destruction_facts"] = collapse_facts.duplicate(true)
	window_fact["garrison_aftermath"] = garrison_aftermath.duplicate(true)
	return window_fact.duplicate(true)


func _resolve_foundation_turn_window(owner_side: StringName, event_kind: StringName) -> Dictionary:
	if context == null or context.tactical_structure_board_state == null:
		return {"ok": false, "reason_code": &"board_state_missing"}
	if owner_side not in [&"player", &"boss"]:
		return {"ok": false, "reason_code": &"foundation_window_not_ready"}
	var turn_serial: int = int(context.get_turn_number()) if context.has_method("get_turn_number") else 0
	var event_plan := {
		"owner_side": owner_side,
		"turn_side": owner_side,
		"event_kind": event_kind,
		"turn_serial": turn_serial,
		"expected_structure_revision": int(context.tactical_structure_board_state.get_revision()),
	}
	return context.tactical_structure_board_state.commit_owner_turn_window(event_plan).duplicate(true)


## Read-only composition query. Structure state remains owned by the existing
## TacticalStructureBoardState and current height remains owned by terrain.
func get_structure_foundation_status(target: Variant) -> Dictionary:
	if not _ensure_tactical_board_state() or not _ensure_structure_board():
		return {"ok": false, "reason_code": &"structure_target_stale"}
	var structure_id := StringName("")
	if target is CardData:
		structure_id = context.tactical_structure_board_state.get_source_structure_id((target as CardData).get_instance_id())
	elif target is Dictionary:
		var target_data: Dictionary = target
		structure_id = StringName(str(target_data.get("structure_id", &"")))
		if structure_id == &"" and int(target_data.get("source_runtime_id", 0)) > 0:
			structure_id = context.tactical_structure_board_state.get_source_structure_id(int(target_data.get("source_runtime_id", 0)))
		if structure_id == &"" and target_data.get("cell", null) is Vector2i:
			structure_id = StringName(str(get_structure_at_cell(target_data.get("cell", INVALID_GRID_CELL)).get("structure_id", &"")))
	elif target is String or target is StringName:
		structure_id = StringName(str(target))
	if structure_id == &"":
		return {"ok": false, "reason_code": &"structure_target_stale"}
	var structure: Dictionary = context.tactical_structure_board_state.get_foundation_status(structure_id)
	if structure.is_empty():
		return {"ok": false, "reason_code": &"structure_target_stale", "structure_id": structure_id}
	var cell: Vector2i = structure.get("cell", INVALID_GRID_CELL)
	var terrain: Dictionary = get_cell_state(cell)
	if terrain.is_empty():
		return {"ok": false, "reason_code": &"structure_target_stale", "structure_id": structure_id}
	var result: Dictionary = structure.duplicate(true)
	var current_height: int = int(terrain.get("height", -1))
	var minimum_height: int = int(structure.get("minimum_foundation_height", 0))
	result["ok"] = true
	result["reason_code"] = &"ok"
	result["reason_text"] = ""
	result["current_height"] = current_height
	result["required_foundation_delta"] = maxi(0, minimum_height - current_height)
	result["terrain_revision"] = int(terrain.get("revision", -1))
	result["structure_revision"] = int(get_structure_snapshot().get("revision", -1))
	result["garrison_revision"] = int(context.tactical_structure_board_state.get_garrison_snapshot().get("revision", -1))
	return result.duplicate(true)


## Phase D2 reserves the repair read model without exposing a free mutation.
const TacticalRepairRulesClass := preload("res://core/config/tactical_repair_rule_snapshot.gd")
var tactical_repair_rules: RefCounted = TacticalRepairRulesClass.new()

func configure_tactical_repair_rules(snapshot: RefCounted) -> void:
	tactical_repair_rules = snapshot if snapshot is TacticalRepairRulesClass else TacticalRepairRulesClass.new()

func get_structure_repair_status(target: Variant) -> Dictionary:
	if tactical_repair_rules.is_enabled():
		if not target is Dictionary or not _ensure_structure_board():
			return {"ok": false, "reason_code": &"repair_module_required"}
		var normalized := _normalize_structure_damage_target(target, {})
		if not normalized.get("ok", false):
			return normalized
		var status: Dictionary = context.tactical_structure_board_state.get_repair_status(normalized.target, 1)
		if not status.get("ok", false):
			return status
		if status.target.get("owner_side") != &"player":
			return {"ok": false, "reason_code": &"repair_target_hostile"}
		status.repair_available = true
		status.repair_interface_reserved = false
		status.foundation = get_structure_foundation_status(target)
		return status
	var foundation: Dictionary = get_structure_foundation_status(target)
	if not bool(foundation.get("ok", false)):
		return foundation
	var result: Dictionary = foundation.duplicate(true)
	result["ok"] = false
	result["reason_code"] = &"repair_content_not_implemented"
	result["reason_text"] = "维修内容尚未实现"
	result["repair_interface_reserved"] = true
	result["repair_available"] = false
	result["repair_reason_code"] = &"repair_content_not_implemented"
	return result.duplicate(true)


func get_height_traversal_status(
	from_cell: Vector2i,
	to_cell: Vector2i,
	options: Dictionary = {}
) -> Dictionary:
	if not _ensure_tactical_board_state():
		return {"ok": false, "reason_code": &"board_state_missing"}
	if not tactical_grid_rules.is_cell_in_bounds(from_cell) or not tactical_grid_rules.is_cell_in_bounds(to_cell):
		return {"ok": false, "reason_code": &"cell_out_of_bounds", "from_cell": from_cell, "to_cell": to_cell}
	var from_height: int = get_cell_height(from_cell)
	var to_height: int = get_cell_height(to_cell)
	if from_height < 0 or to_height < 0:
		return {"ok": false, "reason_code": &"board_state_missing", "from_cell": from_cell, "to_cell": to_cell}
	var height_delta: int = absi(to_height - from_height)
	if height_delta > 1 and not bool(options.get("ignore_height_gap", false)):
		return {
			"ok": false,
			"reason_code": &"height_gap_too_large",
			"from_cell": from_cell,
			"to_cell": to_cell,
			"from_height": from_height,
			"to_height": to_height,
			"height_delta": height_delta,
		}
	return {
		"ok": true,
		"reason_code": &"ok",
		"from_cell": from_cell,
		"to_cell": to_cell,
		"from_height": from_height,
		"to_height": to_height,
		"height_delta": height_delta,
		"height_gap_ignored": height_delta > 1,
	}

# ===== Phase C: Structure board read-only façade =====

var tactical_structure_rules: RefCounted = TacticalStructureRuleSnapshotClass.default_snapshot()
var tactical_garrison_rules: RefCounted = TacticalGarrisonRuleSnapshotClass.disabled_snapshot()
var _garrison_transaction_serial: int = 0


func configure_tactical_structure_rules(snapshot: RefCounted) -> void:
	tactical_structure_rules = snapshot if snapshot != null else TacticalStructureRuleSnapshotClass.default_snapshot()
	_ensure_structure_board()


func configure_tactical_garrison_rules(snapshot: RefCounted) -> void:
	tactical_garrison_rules = snapshot if snapshot != null else TacticalGarrisonRuleSnapshotClass.disabled_snapshot()
	_ensure_structure_board()

func _ensure_structure_board() -> bool:
	if context == null or not context.has_method("configure_tactical_cells"):
		return false
	if context.tactical_structure_board_state.get_snapshot().get("cells", []).is_empty():
		if context.get_tactical_cell_states().is_empty():
			return false
		context.tactical_structure_board_state.configure_cells(tactical_grid_rules.get_all_cells())
	return not context.tactical_structure_board_state.get_snapshot().get("cells", []).is_empty()


func get_structure_snapshot() -> Dictionary:
	if not _ensure_structure_board():
		return {"revision": 0, "structures": {}, "modules": {}, "cells": []}
	return context.tactical_structure_board_state.get_snapshot()


func get_structure_at_cell(cell: Vector2i) -> Dictionary:
	if not _ensure_structure_board():
		return {}
	return context.tactical_structure_board_state.get_structure_at_cell(cell)


func get_structure_module(cell: Vector2i, edge: StringName) -> Dictionary:
	if not _ensure_structure_board():
		return {}
	return context.tactical_structure_board_state.get_module_at_edge(cell, edge)


# ===== Elevated Grid Phase D1: authoritative garrison transactions =====

# Phase E Task2: query-only siege facade. No command dispatch or damage mutation.
var tactical_siege_rules: RefCounted = TacticalSiegeRuleSnapshotClass.new()


func configure_tactical_siege_rules(snapshot: RefCounted) -> void:
	tactical_siege_rules = snapshot if snapshot is TacticalSiegeRuleSnapshotClass else TacticalSiegeRuleSnapshotClass.new()


var _siege_command_in_progress: bool = false
var _defer_unit_registration_notifications: bool = false


func _siege_query_failure(reason: StringName, actor: CardData, target: Dictionary, text: String) -> Dictionary:
	return {"ok": false, "reason_code": reason, "reason_text": text,
		"actor_runtime_id": actor.get_instance_id() if actor != null else 0,
		"requested_target": target.duplicate(true), "resolved_target": {}, "canonical_edge": &"",
		"cover_reason": &"none", "structure_steps": 0, "unit_damage": 0, "hits": [], "costs": {}, "expectations": {}}


func get_siege_attack_status(actor: CardData, target_ref: Dictionary, options: Dictionary = {}) -> Dictionary:
	if edge_fortification_trial != null and target_ref.get("target_kind") == &"edge_fortification":
		return edge_fortification_trial.attack_status(actor, target_ref)
	return _get_siege_attack_status(actor, target_ref, options)


func _get_siege_attack_status(actor: CardData, target_ref: Dictionary, _options: Dictionary = {}, boss_announcement: bool = false) -> Dictionary:
	if not tactical_siege_rules.is_enabled():
		return _siege_query_failure(&"siege_disabled", actor, target_ref, "攻城模式未启用")
	var profile: Dictionary = tactical_siege_rules.get_profile(&"normal_structure_attack")
	var bishop_profile: Dictionary = tactical_siege_rules.get_profile(&"bishop_breach")
	if profile.is_empty() and bishop_profile.is_empty():
		return _siege_query_failure(&"siege_profile_invalid", actor, target_ref, "攻城配置不可用")
	# Do not call lazy board creation from a query on an uninitialized battle.
	if context == null or context.get_tactical_cell_states().is_empty():
		return _siege_query_failure(REASON_STATE_MISSING, actor, target_ref, "战斗未准备好")
	var state: Variant = _state_for_card(actor)
	if state == null or state.is_dead() or get_unit_cell(actor) == INVALID_GRID_CELL:
		return _siege_query_failure(REASON_STATE_MISSING, actor, target_ref, "单位不在有效棋盘上")
	# B-07's announced action is always the ordinary adjacent one-step profile.
	if state.owner_side == &"boss":
		bishop_profile = {}
	var readiness: Dictionary = can_monster_attack(actor)
	if not boss_announcement and not bool(readiness.get("ok", false)):
		return _siege_query_failure(StringName(readiness.get("reason_code", &"attack_locked")), actor, target_ref, str(readiness.get("reason", "不能攻击")))
	var unit_state: Dictionary = get_unit_combat_state(actor)
	if not boss_announcement and (state.summoned_this_turn or not bool(unit_state.get("action_available", false)) or get_monster_attacks_remaining(actor) <= 0):
		return _siege_query_failure(&"attack_locked", actor, target_ref, "本回合没有可用攻击行动")
	var kind: Variant = target_ref.get("target_kind", &"")
	if kind not in [&"structure_core", &"structure_module"]:
		return _siege_query_failure(&"siege_target_kind_invalid", actor, target_ref, "请选择敌方墙体或建筑核心")
	var cell_value: Variant = target_ref.get("cell")
	if not cell_value is Vector2i or not tactical_grid_rules.is_cell_in_bounds(cell_value):
		return _siege_query_failure(&"siege_target_stale", actor, target_ref, "目标格不可用")
	for field in ["expected_terrain_revision", "expected_structure_revision", "expected_module_revision"]:
		if not target_ref.get(field) is int:
			return _siege_query_failure(&"siege_target_stale", actor, target_ref, "目标版本不可用")
	var cell: Vector2i = cell_value
	var board: Variant = context.tactical_structure_board_state
	var structure: Dictionary = board.get_structure_at_cell(cell)
	if structure.is_empty() or structure.get("structure_id") != target_ref.get("structure_id") or int(structure.get("integrity_current", 0)) <= 0:
		return _siege_query_failure(&"siege_target_stale", actor, target_ref, "原建筑已不存在")
	if structure.owner_side == state.owner_side:
		return _siege_query_failure(&"siege_target_friendly", actor, target_ref, "不能攻击己方建筑")
	# Task6 will authorize only the internally resolved, publicly announced action.
	if state.owner_side == &"boss" and not boss_announcement and not _boss_siege_attack_authorized(actor, target_ref):
		return _siege_query_failure(&"boss_siege_requires_intent", actor, target_ref, "攻城需要完整玩家窗口的公开预告")
	if target_ref.has("owner_side") and target_ref.owner_side != structure.owner_side:
		return _siege_query_failure(&"siege_target_stale", actor, target_ref, "目标归属已变化")
	if kind == &"structure_core" and target_ref.get("edge", &"") != &"":
		return _siege_query_failure(&"siege_target_stale", actor, target_ref, "核心引用含无效格边")
	var source_card: CardData = null
	var traps: Array = context.player.traps if structure.owner_side == &"player" else context.enemy.traps
	for raw in traps:
		if raw is CardData and raw.get_instance_id() == int(structure.source_runtime_id):
			source_card = raw
			break
	if structure.get("source_kind") != &"card" or source_card == null or StringName(str(source_card.card_id)) != structure.source_card_id:
		return _siege_query_failure(&"siege_target_stale", actor, target_ref, "建筑来源已离场")
	# Existing board/terrain revision and module-membership validation, without source redirection.
	var durability: Dictionary = get_structure_damage_status(target_ref, int(profile.get("structure_steps", bishop_profile.get("structure_steps", 0))))
	if not bool(durability.get("ok", false)):
		return _siege_query_failure(&"siege_target_stale", actor, target_ref, "目标或耐久已变化，请重新选择")
	var origin: Vector2i = get_unit_cell(actor)
	var delta := origin - cell
	var normal_reach: bool = not profile.is_empty() \
		and absi(delta.x) + absi(delta.y) == int(profile.max_manhattan) \
		and absi(get_cell_height(origin) - get_cell_height(cell)) <= int(profile.max_height_delta) \
		and _get_base_legal_attack_cells(actor).has(cell)
	var bishop_reach: bool = not bishop_profile.is_empty() and _bishop_siege_ray_reaches(actor, cell)
	if not normal_reach and not bishop_reach:
		return _siege_query_failure(&"siege_out_of_reach", actor, target_ref, "目标不在原棋型的相邻攻击范围")
	for guard: CardData in _living_guards_in_scope(actor):
		if bool(get_unit_attack_cell_status(actor, guard).get("ok", false)):
			return _siege_query_failure(&"siege_guard_priority", actor, target_ref, "必须先处理可攻击的守卫")
	var side := String(state.owner_side)
	var economy: Dictionary = get_command_economy_snapshot(side)
	var cost: int = get_action_command_cost(actor, "attack", target_ref)
	if not boss_announcement and (not bool(economy.get("turn_open", false)) or cost < 0 or not can_pay_command_cost(side, cost)):
		return _siege_query_failure(REASON_INSUFFICIENT_POINTS, actor, target_ref, "当前没有可用的攻击指令点")
	var terrain: Dictionary = get_cell_state(cell)
	var requested: Dictionary = _siege_enrich_ref(target_ref, structure, board)
	var modules: Array[Dictionary] = []
	var structure_snapshot: Dictionary = board.get_snapshot()
	for module_id in structure.get("module_ids", []):
		var module: Dictionary = structure_snapshot.modules.get(module_id, {}).duplicate(true)
		if module.is_empty():
			continue
		module["target_ref"] = _siege_enrich_ref(board.make_module_target_ref(cell, module.edge, int(terrain.revision)), structure, board)
		modules.append(module)
	var result: Dictionary = TacticalSiegePlannerClass.plan_attack({
		"source_cell": origin, "source_height": get_unit_effective_board_height(actor),
		"target_cell": cell, "target_height": int(terrain.height), "requested_target": requested,
		"modules": modules, "garrison": {}, "profile": profile,
		"bishop_profile": bishop_profile if bishop_reach else {}})
	if profile.is_empty() and result.get("resolved_target", {}).get("target_kind") == &"structure_core":
		return _siege_query_failure(&"siege_profile_invalid", actor, target_ref, "普通核心攻击配置不可用")
	result.actor_runtime_id = actor.get_instance_id()
	result.reason_text = "可以攻击此目标" if result.ok else "只能攻击朝向来源的墙体"
	result.costs = {"command": cost, "current_points": economy.get("current_points", 0), "economy": economy.duplicate(true)}
	result.expectations = {"actor": unit_state.duplicate(true), "source_cell": origin,
		"source_terrain": get_cell_state(origin), "target_terrain": terrain.duplicate(true), "structure": structure.duplicate(true),
		"structure_board_revision": board.get_revision(), "modules": modules.duplicate(true),
		"garrison": board.get_garrison_snapshot(), "command_modifier": state.get_command_cost_modifier(), "free_action": state.has_free_action(),
		"turn": context.get_turn_number(), "turn_depth": context.turn_depth, "depth_pressure": context.depth_pressure,
		"od": context.od_mode.current_od if context.od_mode != null else 0, "echo_bonus": context.echo_damage_bonus}
	return result.duplicate(true)


## Reuse the original bishop direction/height contracts and occupancy lookup.
## Only this structure-mode ray also stops at every intermediate structure cell.
func _bishop_siege_ray_reaches(actor: CardData, target_cell: Vector2i) -> bool:
	if _get_bishop_enchant(actor).is_empty():
		return false
	var origin: Vector2i = get_unit_cell(actor)
	var delta: Vector2i = target_cell - origin
	if delta.x == 0 or absi(delta.x) != absi(delta.y):
		return false
	var direction := Vector2i(signi(delta.x), signi(delta.y))
	if not tactical_pattern_snapshot.get_raycast_directions(&"piece_bishop").has(direction) \
	or not bool(get_height_traversal_status(origin, target_cell).get("ok", false)):
		return false
	for distance in range(1, absi(delta.x)):
		var cell: Vector2i = origin + direction * distance
		if not _ray_occupant_at(cell).is_empty() or not get_structure_at_cell(cell).is_empty():
			return false
	return true


func _siege_enrich_ref(target: Dictionary, structure: Dictionary, board: RefCounted) -> Dictionary:
	var result := target.duplicate(true)
	var value: Dictionary = structure
	if target.get("target_kind") == &"structure_module":
		value = board.get_module_at_edge(target.cell, target.edge)
	result["canonical_edge"] = value.get("canonical_edge", &"")
	result["source_runtime_id"] = structure.source_runtime_id
	result["owner_side"] = structure.owner_side
	result["integrity_current"] = value.get("integrity_current", 0)
	result["integrity_max"] = value.get("integrity_max", 0)
	return result


## Existing legal unit attacks keep their original reach. Only active garrison
## cover changes the recipient; the planner never grants a new attack cell.
func _get_covered_unit_siege_status(actor: CardData, target: CardData) -> Dictionary:
	var normal_profile: Dictionary = tactical_siege_rules.get_profile(&"normal_structure_attack")
	var bishop_profile: Dictionary = tactical_siege_rules.get_profile(&"bishop_breach")
	if not tactical_siege_rules.is_enabled() or (normal_profile.is_empty() and bishop_profile.is_empty()):
		return {}
	if not bool(can_monster_attack_target(actor, target).get("ok", false)):
		return {}
	var assignment: Dictionary = get_garrison_state_for_unit(target)
	if assignment.get("state") != &"active":
		return {}
	var cell: Vector2i = get_unit_cell(target)
	var structure: Dictionary = get_structure_at_cell(cell)
	if structure.is_empty() or structure.structure_id != assignment.get("structure_id"):
		return {}
	var board: Variant = context.tactical_structure_board_state
	var terrain: Dictionary = get_cell_state(cell)
	var modules: Array[Dictionary] = []
	for edge: StringName in [&"north", &"east", &"south", &"west"]:
		var module: Dictionary = board.get_module_at_edge(cell, edge)
		if module.get("structure_id") == structure.structure_id:
			module["target_ref"] = _siege_enrich_ref(board.make_module_target_ref(cell, edge, terrain.revision), structure, board)
			modules.append(module)
	var requested := {"target_kind": &"unit", "unit_runtime_id": target.get_instance_id(), "structure_id": structure.structure_id, "cell": cell}
	var bishop_reach: bool = not bishop_profile.is_empty() and _bishop_siege_ray_reaches(actor, cell)
	var plan: Dictionary = TacticalSiegePlannerClass.plan_attack({"requested_target": requested,
		"source_cell": get_unit_cell(actor), "source_height": get_unit_effective_board_height(actor),
		"target_cell": cell, "target_height": terrain.height, "garrison": assignment,
		"modules": modules, "profile": normal_profile, "bishop_profile": bishop_profile if bishop_reach else {}})
	if plan.get("cover_reason") != &"entry_wall":
		return {}
	var delta: Vector2i = cell - get_unit_cell(actor)
	if not bishop_profile.is_empty() and not _get_bishop_enchant(actor).is_empty() and delta.x != 0 and absi(delta.x) == absi(delta.y) and not bishop_reach:
		return _siege_query_failure(&"siege_out_of_reach", actor, requested, "斜线破垒路径被阻挡或能力不可用")
	if normal_profile.is_empty() and not bishop_reach:
		return _siege_query_failure(&"siege_profile_invalid", actor, requested, "普通攻城配置不可用")
	if _state_for_card(actor).owner_side == &"boss":
		return _siege_query_failure(&"boss_siege_requires_intent", actor, requested, "攻城需要完整玩家窗口的公开预告")
	if get_monster_attacks_remaining(actor) <= 0 or not bool(get_unit_combat_state(actor).get("action_available", false)):
		return _siege_query_failure(&"attack_locked", actor, requested, "本回合没有可用攻击行动")
	if not bool(get_command_economy_snapshot("player").get("turn_open", false)):
		return _siege_query_failure(REASON_INSUFFICIENT_POINTS, actor, requested, "当前不是可用的行动窗口")
	plan.actor_runtime_id = actor.get_instance_id()
	plan.costs = {"command": get_action_command_cost(actor, "attack", target)}
	plan.expectations = {"actor": get_unit_combat_state(actor), "target": get_unit_combat_state(target),
		"terrain": terrain, "source_terrain": get_cell_state(get_unit_cell(actor)), "structure": structure,
		"modules": modules, "garrison": assignment, "economy": get_command_economy_snapshot("player"),
		"turn": context.get_turn_number(), "depth": context.depth_pressure, "od": context.od_mode.current_od,
		"free_action": _state_for_card(actor).has_free_action(), "modifier": _state_for_card(actor).get_command_cost_modifier()}
	return plan.duplicate(true)


## Called only by execute_unit_command after its final query and tentative debit.
## No signals/await until the outer command has committed gross, Depth and modifiers.
func _resolve_siege_attack(actor: CardData, plan: Dictionary, payload: Dictionary) -> Dictionary:
	if edge_fortification_trial != null and plan.get("edge_fortification", false):
		return edge_fortification_trial.resolve_attack(actor, plan)
	var options := {"defer_signal": true}
	for flag: String in ["phase_c_force_structure_commit_failure", "phase_c_force_terrain_commit_failure", "phase_e_force_resolver_failure"]:
		if bool(payload.get(flag, false)):
			options[flag] = true
	var fact: Dictionary = commit_structure_damage(plan.resolved_target, int(plan.structure_steps), &"unit_siege_attack", options)
	if not bool(fact.get("ok", false)):
		return fact
	mark_monster_attacked(actor, true)
	_bishop_consume(actor)
	var target: Dictionary = plan.resolved_target
	return {"ok": true, "result": "structure_hit", "source_kind": &"unit_attack",
		"transaction_id": StringName("siege:%d:%s:%d" % [actor.get_instance_id(), str(target.get("structure_id", &"")), int(fact.get("revision", 0))]),
		"actor_runtime_id": actor.get_instance_id(), "requested_target": plan.requested_target.duplicate(true),
		"resolved_target": target.duplicate(true), "canonical_edge": plan.canonical_edge, "cover_reason": plan.cover_reason,
		"structure_steps": int(fact.get("actual_steps", plan.structure_steps)), "unit_damage": 0,
		"hits": [fact.duplicate(true)], "before": fact.get("before", {}).duplicate(true), "after": fact.get("after", {}).duplicate(true),
		"destroyed_units": [], "structure_cleanup": [fact.duplicate(true)] if fact.get("core_destroyed", false) else [],
		"garrison_aftermath": fact.get("garrison_aftermath", []).duplicate(true), "costs": plan.costs.duplicate(true),
		"structure_fact": fact.duplicate(true)}


func get_legal_siege_targets(actor: CardData) -> Array[Dictionary]:
	var targets: Array[Dictionary] = []
	if context == null or not tactical_siege_rules.is_enabled() or _state_for_card(actor) == null:
		return targets
	var board: Variant = context.tactical_structure_board_state
	for cell: Vector2i in tactical_grid_rules.get_all_cells():
		var structure: Dictionary = board.get_structure_at_cell(cell)
		if structure.is_empty():
			continue
		var terrain: Dictionary = context.get_tactical_cell_state(cell)
		var refs: Array[Dictionary] = [board.make_core_target_ref(cell, int(terrain.get("revision", -1)))]
		for edge: StringName in [&"north", &"east", &"south", &"west"]:
			var module: Dictionary = board.get_module_at_edge(cell, edge)
			if module.get("structure_id") == structure.structure_id:
				refs.append(board.make_module_target_ref(cell, edge, int(terrain.get("revision", -1))))
		for target: Dictionary in refs:
			var status: Dictionary = get_siege_attack_status(actor, target)
			if bool(status.get("ok", false)):
				targets.append(status.requested_target.duplicate(true))
	if edge_fortification_trial != null:
		targets.append_array(edge_fortification_trial.targets_for(actor))
	return targets

func get_garrison_state_for_unit(unit: CardData) -> Dictionary:
	if unit == null or not _ensure_structure_board():
		return {}
	return context.tactical_structure_board_state.get_garrison_for_unit(unit.get_instance_id())


## Phase D1 Task 5: live board height used by strict-height range checks.
## Ordinary units read their occupied terrain. Active garrisons add the slot's
## platform offset; displaced units deliberately lose that benefit.
func get_unit_effective_board_height(unit: CardData) -> int:
	if unit == null:
		return -1
	var cell: Vector2i = get_unit_cell(unit)
	if cell == INVALID_GRID_CELL:
		return -1
	var assignment: Dictionary = get_garrison_state_for_unit(unit)
	var assignment_state := StringName(str(assignment.get("state", &"")))
	if assignment_state in [&"active", &"displaced_pending_exit"]:
		var parent_cell: Vector2i = assignment.get("parent_cell", cell)
		var parent_height: int = get_cell_height(parent_cell)
		if parent_height < 0:
			return -1
		if assignment_state == &"active":
			return parent_height + int(assignment.get("platform_height_offset", 0))
		return parent_height
	return get_cell_height(cell)


## Copied query model for UI/AI. Bonus cells are target-aware: an empty second
## rank never becomes generic range, and no mutation or presentation state is
## consulted here.
func get_garrison_range_preview(unit: CardData) -> Dictionary:
	var base_cells: Array[Vector2i] = _get_base_legal_attack_cells(unit)
	var extended_cells: Array[Vector2i] = _extend_garrison_normal_attack_cells(unit, base_cells)
	var bonus_cells: Array[Vector2i] = []
	for cell in extended_cells:
		if not base_cells.has(cell):
			bonus_cells.append(cell)
	var assignment: Dictionary = get_garrison_state_for_unit(unit)
	var occupied_cell: Vector2i = get_unit_cell(unit) if unit != null else INVALID_GRID_CELL
	var terrain_cell: Vector2i = assignment.get("parent_cell", occupied_cell)
	var terrain_state: Dictionary = get_cell_state(terrain_cell) if terrain_cell != INVALID_GRID_CELL else {}
	var garrison_revision: int = -1
	if _ensure_structure_board():
		garrison_revision = int(context.tactical_structure_board_state.get_garrison_snapshot().get("revision", -1))
	return {
		"ok": unit != null and _state_for_card(unit) != null and occupied_cell != INVALID_GRID_CELL,
		"unit_runtime_id": unit.get_instance_id() if unit != null else 0,
		"base_cells": base_cells.duplicate(),
		"bonus_cells": bonus_cells.duplicate(),
		"effective_height": get_unit_effective_board_height(unit),
		"requires_strict_height_advantage": true,
		"damage_bonus": 0,
		"garrison_revision": garrison_revision,
		"terrain_revision": int(terrain_state.get("revision", -1)),
	}.duplicate(true)


func get_garrison_enter_status(
	unit: CardData,
	structure_id: StringName,
	slot_id: StringName = &"garrison_0"
) -> Dictionary:
	var result: Dictionary = _garrison_status_base(unit, structure_id, slot_id)
	if unit == null:
		return _garrison_reject(result, &"garrison_unit_missing")
	if not _garrison_rules_enabled():
		return _garrison_reject(result, &"garrison_rules_unavailable")
	if not _ensure_tactical_board_state() or not _ensure_structure_board():
		return _garrison_reject(result, &"garrison_target_stale")

	var state: Variant = _state_for_card(unit)
	if state == null:
		return _garrison_reject(result, &"garrison_unit_missing")
	if state.is_dead():
		return _garrison_reject(result, &"garrison_unit_dead")
	if not _is_valid_front_field_unit(unit, state.owner_side):
		return _garrison_reject(result, &"garrison_unit_not_on_board")
	if unit.card_family != "monster" and unit.card_type != CardData.CardType.UNIT:
		return _garrison_reject(result, &"garrison_unit_ineligible")
	var unit_tags: Array[String] = []
	unit_tags.assign(unit.search_tags)
	if not tactical_garrison_rules.is_unit_eligible(StringName(str(unit.card_id)), unit_tags):
		return _garrison_reject(result, &"garrison_unit_ineligible")
	if not get_garrison_state_for_unit(unit).is_empty():
		return _garrison_reject(result, &"garrison_unit_already_assigned")

	var structures: Dictionary = get_structure_snapshot().get("structures", {})
	var structure_value: Variant = structures.get(structure_id, null)
	if not structure_value is Dictionary:
		return _garrison_reject(result, &"garrison_structure_missing")
	var structure: Dictionary = (structure_value as Dictionary).duplicate(true)
	var owner_side := StringName(str(state.owner_side))
	if StringName(str(structure.get("owner_side", &""))) != owner_side:
		return _garrison_reject(result, &"garrison_structure_hostile")
	if StringName(str(structure.get("profile_id", &""))) != &"p08_fortification":
		return _garrison_reject(result, &"garrison_structure_missing")
	if StringName(str(structure.get("foundation_state", &"stable"))) != &"stable":
		return _garrison_reject(result, &"garrison_structure_undermined")

	var slot_profile: Dictionary = tactical_garrison_rules.get_slot_profile(&"p08_fortification", slot_id)
	if slot_profile.is_empty():
		return _garrison_reject(result, &"garrison_slot_missing")
	if not bool(slot_profile.get("enabled", false)):
		return _garrison_reject(result, &"garrison_slot_disabled")
	if not _garrison_structure_has_slot(structure, slot_id, slot_profile):
		return _garrison_reject(result, &"garrison_slot_missing")
	if not context.tactical_structure_board_state.get_garrison_for_slot(structure_id, slot_id).is_empty():
		return _garrison_reject(result, &"garrison_slot_occupied")

	var parent_cell: Vector2i = structure.get("cell", INVALID_GRID_CELL)
	var footprint: Array = structure.get("footprint_cells", [parent_cell])
	if footprint.size() == 2:
		parent_cell = footprint[1]
		var occupant: CardData = get_unit_at_cell(parent_cell)
		if occupant != null and occupant != unit: return _garrison_reject(result, &"garrison_slot_occupied")
	var support: Dictionary = _garrison_support_module(structure, slot_profile)
	if support.is_empty() or int(support.get("integrity_current", 0)) <= 0 \
	or StringName(str(support.get("status", &""))) == &"destroyed":
		return _garrison_reject(result, &"garrison_support_destroyed")
	var from_cell: Vector2i = get_unit_cell(unit)
	result.from_cell = from_cell
	result.parent_cell = parent_cell
	result.target_cell = parent_cell
	if from_cell == INVALID_GRID_CELL:
		return _garrison_reject(result, &"garrison_unit_not_on_board")
	if _garrison_manhattan_distance(from_cell, parent_cell) != 1 and not (footprint.size() == 2 and from_cell == parent_cell):
		return _garrison_reject(result, &"garrison_not_adjacent")

	var action_reason: StringName = _garrison_action_block_reason(unit, state)
	if action_reason != &"ok":
		return _garrison_reject(result, action_reason)

	var source_terrain: Dictionary = get_cell_state(from_cell)
	var parent_terrain: Dictionary = get_cell_state(parent_cell)
	if source_terrain.is_empty() or parent_terrain.is_empty():
		return _garrison_reject(result, &"garrison_target_stale")
	var source_height: int = int(source_terrain.get("height", -1))
	var target_height: int = int(parent_terrain.get("height", -1)) + int(slot_profile.get("platform_height_offset", 0))
	var owner_passage: bool = _garrison_edge_allows_owner_passage(parent_cell, from_cell, structure_id)
	if absi(target_height - source_height) > 1 and not owner_passage:
		return _garrison_reject(result, &"garrison_height_or_passage_blocked")

	var structure_revision: int = int(get_structure_snapshot().get("revision", -1))
	var garrison_revision: int = int(context.tactical_structure_board_state.get_garrison_snapshot().get("revision", -1))
	var entered_turn: int = int(context.get_turn_number()) if context != null else 0
	var assignment_plan := {
		"structure_id": structure_id,
		"slot_id": slot_id,
		"unit_runtime_id": unit.get_instance_id(),
		"owner_side": owner_side,
		"parent_cell": parent_cell,
		"socket_name": slot_profile.get("socket_name", &""),
		"slot_role": slot_profile.get("slot_role", &""),
		"support_module_id": support.get("module_id", &""),
		"platform_height_offset": int(slot_profile.get("platform_height_offset", 0)),
		"entered_turn": entered_turn,
		"expected_structure_revision": structure_revision,
		"expected_garrison_revision": garrison_revision,
	}
	var board_status: Dictionary = context.tactical_structure_board_state.get_garrison_assign_status(assignment_plan)
	if not bool(board_status.get("ok", false)):
		return _garrison_reject(result, _garrison_public_board_reason(board_status.get("reason_code", &"")))

	result.ok = true
	result.reason_code = &"ok"
	result.reason_text = _garrison_reason_text(&"ok")
	result.source_effective_height = source_height
	result.target_effective_height = target_height
	result.terrain_revision = int(parent_terrain.get("revision", -1))
	result.source_terrain_revision = int(source_terrain.get("revision", -1))
	result.structure_revision = structure_revision
	result.garrison_revision = garrison_revision
	result.action_revision = int(state.actions_used)
	result.action_cost = int(monster_combat_rules.self_move_action_cost)
	result.entered_turn = entered_turn
	result.owner_passage = owner_passage
	result.assignment_plan = assignment_plan.duplicate(true)
	return result.duplicate(true)


func commit_garrison_enter(
	unit: CardData,
	structure_id: StringName,
	slot_id: StringName = &"garrison_0",
	options: Dictionary = {}
) -> Dictionary:
	var status: Dictionary = get_garrison_enter_status(unit, structure_id, slot_id)
	if not bool(status.get("ok", false)):
		return status
	if not _garrison_expectations_match(status, options):
		return _garrison_reject(status, &"garrison_target_stale")
	var state: Variant = _state_for_card(unit)
	if state == null:
		return _garrison_reject(status, &"garrison_target_stale")
	var rollback: Dictionary = _capture_garrison_unit_rollback(unit, state)
	var unit_before: Dictionary = state.snapshot(monster_combat_rules.max_attacks_per_turn, monster_combat_rules.actions_per_turn)
	var cell_write: Dictionary = _assign_unit_cell_atomic(unit, status.get("parent_cell", INVALID_GRID_CELL), &"garrison_enter", false)
	if not bool(cell_write.get("ok", false)):
		_restore_garrison_unit_rollback(unit, state, rollback)
		return _garrison_reject(status, &"garrison_commit_failed")
	if bool(options.get("phase_d_force_garrison_assign_failure", false)):
		_restore_garrison_unit_rollback(unit, state, rollback)
		return _garrison_reject(status, &"garrison_commit_failed")
	var assignment_fact: Dictionary = context.tactical_structure_board_state.apply_garrison_assign(status.get("assignment_plan", {}))
	if not bool(assignment_fact.get("ok", false)):
		_restore_garrison_unit_rollback(unit, state, rollback)
		return _garrison_reject(status, &"garrison_commit_failed")
	state.actions_used = clampi(
		state.actions_used + int(status.get("action_cost", 0)),
		0,
		monster_combat_rules.actions_per_turn
	)
	state.moves_used += 1
	state.last_action = &"garrison_enter"
	_emit_unit_state(unit)
	var unit_after: Dictionary = state.snapshot(monster_combat_rules.max_attacks_per_turn, monster_combat_rules.actions_per_turn)
	var fact: Dictionary = status.duplicate(true)
	fact["transaction_kind"] = &"garrison_enter"
	fact["transaction_id"] = _next_garrison_transaction_id(&"enter", unit.get_instance_id())
	fact["before"] = {"unit": unit_before.duplicate(true), "garrison": rollback.get("garrison", {}).duplicate(true)}
	fact["after"] = {"unit": unit_after.duplicate(true), "garrison": assignment_fact.get("after", {}).duplicate(true)}
	fact["unit_state_before"] = unit_before.duplicate(true)
	fact["unit_state_after"] = unit_after.duplicate(true)
	fact["assignment_fact"] = assignment_fact.duplicate(true)
	fact["cleanup_facts"] = []
	fact["displacement_facts"] = []
	fact.erase("assignment_plan")
	if _ritual_trial != null and state.owner_side == &"player":
		_ritual_trial.record_garrison(unit.get_instance_id(), structure_id, unit.get_display_name())
	garrison_transaction_committed.emit(fact.duplicate(true))
	return fact.duplicate(true)


func get_garrison_exit_status(unit: CardData, target_cell: Vector2i) -> Dictionary:
	var assignment: Dictionary = get_garrison_state_for_unit(unit)
	var structure_id := StringName(str(assignment.get("structure_id", &"")))
	var slot_id := StringName(str(assignment.get("slot_id", &"garrison_0")))
	var result: Dictionary = _garrison_status_base(unit, structure_id, slot_id)
	result.target_cell = target_cell
	if unit == null:
		return _garrison_reject(result, &"garrison_unit_missing")
	if not _garrison_rules_enabled():
		return _garrison_reject(result, &"garrison_rules_unavailable")
	if assignment.is_empty():
		return _garrison_reject(result, &"garrison_target_stale")
	var assignment_state := StringName(str(assignment.get("state", &"")))
	if assignment_state not in [&"active", &"displaced_pending_exit"]:
		return _garrison_reject(result, &"garrison_target_stale")
	var state: Variant = _state_for_card(unit)
	if state == null:
		return _garrison_reject(result, &"garrison_unit_missing")
	if state.is_dead():
		return _garrison_reject(result, &"garrison_unit_dead")
	if not _is_valid_front_field_unit(unit, state.owner_side):
		return _garrison_reject(result, &"garrison_unit_not_on_board")
	if int(assignment.get("unit_runtime_id", 0)) != unit.get_instance_id():
		return _garrison_reject(result, &"garrison_target_stale")

	var structures: Dictionary = get_structure_snapshot().get("structures", {})
	var structure_value: Variant = structures.get(structure_id, null)
	if not structure_value is Dictionary:
		return _garrison_reject(result, &"garrison_target_stale")
	var structure: Dictionary = structure_value
	var parent_cell: Vector2i = assignment.get("parent_cell", INVALID_GRID_CELL)
	result.from_cell = parent_cell
	result.parent_cell = parent_cell
	if not tactical_grid_rules.is_cell_in_bounds(target_cell):
		return _garrison_reject(result, &"garrison_exit_cell_invalid")
	var occupant: CardData = get_unit_at_cell(target_cell)
	if occupant != null and occupant != unit:
		return _garrison_reject(result, &"garrison_exit_cell_occupied")
	if is_cell_blocked_by_structure(target_cell):
		return _garrison_reject(result, &"garrison_exit_cell_invalid")
	if _garrison_manhattan_distance(parent_cell, target_cell) != 1:
		return _garrison_reject(result, &"garrison_not_adjacent")
	var action_reason: StringName = _garrison_action_block_reason(unit, state)
	if action_reason != &"ok":
		return _garrison_reject(result, action_reason)

	var parent_terrain: Dictionary = get_cell_state(parent_cell)
	var target_terrain: Dictionary = get_cell_state(target_cell)
	if parent_terrain.is_empty() or target_terrain.is_empty():
		return _garrison_reject(result, &"garrison_target_stale")
	var source_height: int = int(parent_terrain.get("height", -1))
	if assignment_state == &"active":
		source_height += int(assignment.get("platform_height_offset", 0))
	var target_height: int = int(target_terrain.get("height", -1))
	var owner_passage: bool = _garrison_edge_allows_owner_passage(parent_cell, target_cell, structure_id)
	if absi(target_height - source_height) > 1 and not owner_passage:
		return _garrison_reject(result, &"garrison_height_or_passage_blocked")

	var clear_plan := {
		"structure_id": structure_id,
		"slot_id": slot_id,
		"unit_runtime_id": unit.get_instance_id(),
		"expected_assignment_revision": int(assignment.get("assignment_revision", -1)),
		"expected_garrison_revision": int(context.tactical_structure_board_state.get_garrison_snapshot().get("revision", -1)),
	}
	var board_status: Dictionary = context.tactical_structure_board_state.get_garrison_clear_status(clear_plan)
	if not bool(board_status.get("ok", false)) or not bool(board_status.get("changed", false)):
		return _garrison_reject(result, &"garrison_target_stale")

	result.ok = true
	result.reason_code = &"ok"
	result.reason_text = _garrison_reason_text(&"ok")
	result.source_effective_height = source_height
	result.target_effective_height = target_height
	result.terrain_revision = int(target_terrain.get("revision", -1))
	result.source_terrain_revision = int(parent_terrain.get("revision", -1))
	result.structure_revision = int(get_structure_snapshot().get("revision", -1))
	result.garrison_revision = int(clear_plan.get("expected_garrison_revision", -1))
	result.action_revision = int(state.actions_used)
	result.action_cost = int(monster_combat_rules.self_move_action_cost)
	result.entered_turn = int(assignment.get("entered_turn", 0))
	result.owner_passage = owner_passage
	result.assignment = assignment.duplicate(true)
	result.clear_plan = clear_plan.duplicate(true)
	return result.duplicate(true)


func commit_garrison_exit(unit: CardData, target_cell: Vector2i, options: Dictionary = {}) -> Dictionary:
	var status: Dictionary = get_garrison_exit_status(unit, target_cell)
	if not bool(status.get("ok", false)):
		return status
	if not _garrison_expectations_match(status, options):
		return _garrison_reject(status, &"garrison_target_stale")
	var state: Variant = _state_for_card(unit)
	if state == null:
		return _garrison_reject(status, &"garrison_target_stale")
	var rollback: Dictionary = _capture_garrison_unit_rollback(unit, state)
	var unit_before: Dictionary = state.snapshot(monster_combat_rules.max_attacks_per_turn, monster_combat_rules.actions_per_turn)
	var clear_fact: Dictionary = context.tactical_structure_board_state.apply_garrison_clear(status.get("clear_plan", {}))
	if not bool(clear_fact.get("ok", false)) or not bool(clear_fact.get("changed", false)):
		return _garrison_reject(status, &"garrison_commit_failed")
	var cell_write: Dictionary = _assign_unit_cell_atomic(unit, target_cell, &"garrison_exit", false)
	if not bool(cell_write.get("ok", false)):
		_restore_garrison_assignment(rollback.get("garrison", {}))
		_restore_garrison_unit_rollback(unit, state, rollback)
		return _garrison_reject(status, &"garrison_commit_failed")
	state.actions_used = clampi(
		state.actions_used + int(status.get("action_cost", 0)),
		0,
		monster_combat_rules.actions_per_turn
	)
	state.moves_used += 1
	state.last_action = &"garrison_exit"
	_emit_unit_state(unit)
	var unit_after: Dictionary = state.snapshot(monster_combat_rules.max_attacks_per_turn, monster_combat_rules.actions_per_turn)
	var fact: Dictionary = status.duplicate(true)
	fact["transaction_kind"] = &"garrison_exit"
	fact["transaction_id"] = _next_garrison_transaction_id(&"exit", unit.get_instance_id())
	fact["before"] = {"unit": unit_before.duplicate(true), "garrison": rollback.get("garrison", {}).duplicate(true)}
	fact["after"] = {"unit": unit_after.duplicate(true), "garrison": {}}
	fact["unit_state_before"] = unit_before.duplicate(true)
	fact["unit_state_after"] = unit_after.duplicate(true)
	fact["clear_fact"] = clear_fact.duplicate(true)
	fact["cleanup_facts"] = []
	fact["displacement_facts"] = []
	fact.erase("clear_plan")
	fact.erase("assignment")
	garrison_transaction_committed.emit(fact.duplicate(true))
	return fact.duplicate(true)


## Resolves only consequences of a structure fact that has already committed.
## The structure authority remains the damage writer; this coordinator only
## clears, displaces or lands relations held by that same structure board.
func resolve_garrison_aftermath(committed_structure_fact: Dictionary, defer_signal: bool = false) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	if not bool(committed_structure_fact.get("ok", false)) or not _ensure_structure_board():
		return results
	var target: Dictionary = committed_structure_fact.get("target", {})
	var structure_id := StringName(str(target.get("structure_id", &"")))
	if structure_id == &"":
		structure_id = StringName(str((committed_structure_fact.get("before", {}) as Dictionary).get("structure_id", &"")))
	if structure_id == &"":
		return results
	var core_destroyed: bool = bool(committed_structure_fact.get("core_destroyed", false))
	var support_destroyed: bool = StringName(str(target.get("target_kind", &""))) == &"structure_module" \
		and StringName(str((committed_structure_fact.get("after", {}) as Dictionary).get("status", &""))) == &"destroyed" \
		and StringName(str((committed_structure_fact.get("before", {}) as Dictionary).get("status", &""))) != &"destroyed"
	if not core_destroyed and not support_destroyed:
		return results

	var support_module_id := StringName(str(target.get("module_id", &"")))
	var cleanup_cause := StringName(str(committed_structure_fact.get("cleanup_cause", &"structure_damage")))
	var assignments: Dictionary = context.tactical_structure_board_state.get_garrison_snapshot().get("assignments", {})
	var slot_keys: Array = assignments.keys()
	slot_keys.sort()
	for slot_key: Variant in slot_keys:
		var assignment_value: Variant = assignments.get(slot_key, null)
		if not assignment_value is Dictionary:
			continue
		var assignment: Dictionary = (assignment_value as Dictionary).duplicate(true)
		if StringName(str(assignment.get("structure_id", &""))) != structure_id:
			continue
		if support_destroyed and StringName(str(assignment.get("support_module_id", &""))) != support_module_id:
			continue
		var fact: Dictionary
		if core_destroyed and cleanup_cause == &"foundation_collapse":
			fact = _resolve_support_loss_for_assignment(assignment, &"foundation_collapse", defer_signal)
		elif core_destroyed:
			fact = _clear_garrison_assignment(assignment, &"structure_core_destroyed", &"garrison_core_cleanup", not defer_signal)
		else:
			fact = _resolve_support_loss_for_assignment(assignment, &"garrison_support_destroyed", defer_signal)
		if not fact.is_empty():
			results.append(fact.duplicate(true))
	return results


## Battle/showcase reset entry point. It does not touch units, structures or
## terrain and is idempotent when no relations remain.
func reset_garrison_relations(reason: StringName = &"battle_reset") -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	if not _ensure_structure_board():
		return results
	var assignments: Dictionary = context.tactical_structure_board_state.get_garrison_snapshot().get("assignments", {})
	var slot_keys: Array = assignments.keys()
	slot_keys.sort()
	for slot_key: Variant in slot_keys:
		var assignment_value: Variant = assignments.get(slot_key, null)
		if not assignment_value is Dictionary:
			continue
		var fact: Dictionary = _clear_garrison_assignment(
			(assignment_value as Dictionary).duplicate(true), reason, &"garrison_reset_cleanup"
		)
		if not fact.is_empty():
			results.append(fact.duplicate(true))
	return results


func _resolve_support_loss_for_assignment(
	assignment: Dictionary,
	cleanup_reason: StringName = &"garrison_support_destroyed",
	defer_signal: bool = false,
) -> Dictionary:
	var unit_runtime_id: int = int(assignment.get("unit_runtime_id", 0))
	var owner_side := StringName(str(assignment.get("owner_side", &"player")))
	var unit: CardData = _find_field_card_by_runtime_id(unit_runtime_id, owner_side)
	if unit == null:
		return _clear_garrison_assignment(assignment, &"unit_missing", &"garrison_unit_cleanup", not defer_signal)
	var parent_cell: Vector2i = assignment.get("parent_cell", INVALID_GRID_CELL)
	var landing_cell: Vector2i = _first_garrison_landing_cell(parent_cell, owner_side, unit)
	if landing_cell == INVALID_GRID_CELL:
		var displaced_plan := {
			"structure_id": assignment.get("structure_id", &""),
			"slot_id": assignment.get("slot_id", &""),
			"unit_runtime_id": unit_runtime_id,
			"expected_assignment_revision": int(assignment.get("assignment_revision", -1)),
			"expected_garrison_revision": int(context.tactical_structure_board_state.get_garrison_snapshot().get("revision", -1)),
		}
		var displaced: Dictionary = context.tactical_structure_board_state.mark_garrison_displaced(displaced_plan)
		if not bool(displaced.get("ok", false)):
			return {
				"ok": false,
				"reason_code": &"garrison_commit_failed",
				"transaction_kind": &"garrison_displace",
				"unit_runtime_id": unit_runtime_id,
			}
		var displaced_fact: Dictionary = displaced.duplicate(true)
		displaced_fact["unit_runtime_id"] = unit_runtime_id
		displaced_fact["structure_id"] = assignment.get("structure_id", &"")
		displaced_fact["slot_id"] = assignment.get("slot_id", &"")
		displaced_fact["from_cell"] = parent_cell
		displaced_fact["target_cell"] = INVALID_GRID_CELL
		displaced_fact["cleanup_reason"] = cleanup_reason
		if bool(displaced_fact.get("changed", false)) and not defer_signal:
			garrison_transaction_committed.emit(displaced_fact.duplicate(true))
		return displaced_fact

	var move_fact: Dictionary = _assign_unit_cell_atomic(unit, landing_cell, &"garrison_support_eject", not defer_signal, defer_signal)
	if not bool(move_fact.get("ok", false)):
		return {
			"ok": false,
			"reason_code": &"garrison_commit_failed",
			"transaction_kind": &"garrison_forced_landing",
			"unit_runtime_id": unit_runtime_id,
		}
	var clear_fact: Dictionary = _clear_garrison_assignment(
		assignment, cleanup_reason, &"garrison_forced_landing", false
	)
	if not bool(clear_fact.get("ok", false)):
		_assign_unit_cell_atomic(unit, parent_cell, &"garrison_support_eject_rollback", false, defer_signal)
		return clear_fact
	clear_fact["from_cell"] = parent_cell
	clear_fact["target_cell"] = landing_cell
	clear_fact["move_fact"] = move_fact.duplicate(true)
	if not defer_signal:
		garrison_transaction_committed.emit(clear_fact.duplicate(true))
	return clear_fact


func _first_garrison_landing_cell(parent_cell: Vector2i, owner_side: StringName, unit: CardData) -> Vector2i:
	for relative_direction: StringName in tactical_garrison_rules.get_fallback_relative_order():
		var absolute_edge: StringName = tactical_structure_rules.normalize_relative_edge(
			owner_side, &"forward" if relative_direction == &"front" else relative_direction
		)
		var candidate: Vector2i = parent_cell + _garrison_edge_delta(absolute_edge)
		if not tactical_grid_rules.is_cell_in_bounds(candidate):
			continue
		var occupant: CardData = get_unit_at_cell(candidate)
		if occupant != null and occupant != unit:
			continue
		if is_cell_blocked_by_structure(candidate):
			continue
		return candidate
	return INVALID_GRID_CELL


func _garrison_edge_delta(edge: StringName) -> Vector2i:
	match edge:
		&"north": return Vector2i(0, -1)
		&"east": return Vector2i(1, 0)
		&"south": return Vector2i(0, 1)
		&"west": return Vector2i(-1, 0)
	return Vector2i.ZERO


func _clear_garrison_assignment(
	assignment: Dictionary,
	reason: StringName,
	transaction_kind: StringName,
	emit_fact: bool = true
) -> Dictionary:
	if assignment.is_empty():
		return {}
	var clear_plan := {
		"structure_id": assignment.get("structure_id", &""),
		"slot_id": assignment.get("slot_id", &""),
		"unit_runtime_id": int(assignment.get("unit_runtime_id", 0)),
		"expected_assignment_revision": int(assignment.get("assignment_revision", -1)),
		"expected_garrison_revision": int(context.tactical_structure_board_state.get_garrison_snapshot().get("revision", -1)),
	}
	var clear_fact: Dictionary = context.tactical_structure_board_state.apply_garrison_clear(clear_plan)
	if not bool(clear_fact.get("ok", false)):
		return clear_fact
	if not bool(clear_fact.get("changed", false)):
		return {}
	var fact: Dictionary = clear_fact.duplicate(true)
	fact["transaction_kind"] = transaction_kind
	fact["cleanup_reason"] = reason
	fact["structure_id"] = assignment.get("structure_id", &"")
	fact["slot_id"] = assignment.get("slot_id", &"")
	fact["unit_runtime_id"] = int(assignment.get("unit_runtime_id", 0))
	fact["from_cell"] = assignment.get("parent_cell", INVALID_GRID_CELL)
	fact["target_cell"] = assignment.get("parent_cell", INVALID_GRID_CELL)
	if emit_fact:
		garrison_transaction_committed.emit(fact.duplicate(true))
	return fact


func _clear_garrison_for_unit(unit: CardData, reason: StringName) -> Dictionary:
	if unit == null or not _ensure_structure_board():
		return {}
	var assignment: Dictionary = context.tactical_structure_board_state.get_garrison_for_unit(unit.get_instance_id())
	return _clear_garrison_assignment(assignment, reason, &"garrison_unit_cleanup")


func _garrison_status_base(unit: CardData, structure_id: StringName, slot_id: StringName) -> Dictionary:
	return {
		"ok": false,
		"reason_code": &"garrison_target_stale",
		"reason_text": _garrison_reason_text(&"garrison_target_stale"),
		"unit_runtime_id": unit.get_instance_id() if unit != null else 0,
		"structure_id": structure_id,
		"slot_id": slot_id,
		"from_cell": get_unit_cell(unit),
		"parent_cell": INVALID_GRID_CELL,
		"target_cell": INVALID_GRID_CELL,
		"source_effective_height": -1,
		"target_effective_height": -1,
		"action_cost": int(monster_combat_rules.self_move_action_cost),
		"entered_turn": int(context.get_turn_number()) if context != null else 0,
		"terrain_revision": -1,
		"source_terrain_revision": -1,
		"structure_revision": -1,
		"garrison_revision": -1,
		"action_revision": -1,
	}


func _garrison_reject(result: Dictionary, reason_code: StringName) -> Dictionary:
	var rejected: Dictionary = result.duplicate(true)
	rejected.ok = false
	rejected.reason_code = reason_code
	rejected.reason_text = _garrison_reason_text(reason_code)
	rejected.erase("assignment_plan")
	rejected.erase("clear_plan")
	return rejected


func _garrison_rules_enabled() -> bool:
	return tactical_garrison_rules != null \
	and tactical_garrison_rules.has_method("to_snapshot") \
	and bool(tactical_garrison_rules.to_snapshot().get("enabled", false))


func _garrison_structure_has_slot(structure: Dictionary, slot_id: StringName, slot_profile: Dictionary) -> bool:
	for value: Variant in structure.get("reserved_garrison_slot_defs", []):
		if not value is Dictionary:
			continue
		var definition: Dictionary = value
		if StringName(str(definition.get("slot_id", &""))) == slot_id \
		and StringName(str(definition.get("socket_name", &""))) == StringName(str(slot_profile.get("socket_name", &""))) \
		and StringName(str(definition.get("slot_role", &""))) == StringName(str(slot_profile.get("slot_role", &""))):
			return true
	return false


func _garrison_support_module(structure: Dictionary, slot_profile: Dictionary) -> Dictionary:
	var relative_edge := StringName(str(slot_profile.get("support_relative_edge", &"")))
	if relative_edge == &"front":
		relative_edge = &"forward"
	var owner_side := StringName(str(structure.get("owner_side", &"player")))
	var absolute_edge: StringName = tactical_structure_rules.normalize_relative_edge(owner_side, relative_edge)
	var footprint: Array = structure.get("footprint_cells", [])
	if relative_edge == &"forward" and footprint.size() == 2:
		absolute_edge = _garrison_edge_from_parent(footprint[0], footprint[1])
	return get_structure_module(structure.get("cell", INVALID_GRID_CELL), absolute_edge)


func _garrison_edge_allows_owner_passage(parent_cell: Vector2i, adjacent_cell: Vector2i, structure_id: StringName) -> bool:
	var edge: StringName = _garrison_edge_from_parent(parent_cell, adjacent_cell)
	if edge == &"":
		return false
	var module: Dictionary = get_structure_module(parent_cell, edge)
	return not module.is_empty() \
	and StringName(str(module.get("structure_id", &""))) == structure_id \
	and int(module.get("integrity_current", 0)) > 0 \
	and StringName(str(module.get("status", &""))) != &"destroyed" \
	and bool(module.get("allows_owner_passage", false))


func _garrison_edge_from_parent(parent_cell: Vector2i, adjacent_cell: Vector2i) -> StringName:
	var delta: Vector2i = adjacent_cell - parent_cell
	match delta:
		Vector2i(0, -1): return &"north"
		Vector2i(1, 0): return &"east"
		Vector2i(0, 1): return &"south"
		Vector2i(-1, 0): return &"west"
	return &""


func _garrison_manhattan_distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


func _garrison_action_block_reason(unit: CardData, state: Variant) -> StringName:
	if not monster_combat_rules.movement_enabled:
		return &"garrison_action_unavailable"
	if _normalize_owner_side(state.owner_side) == &"player" and not _core_command_player_turn_open:
		return &"garrison_action_unavailable"
	if monster_combat_rules.summoning_sickness_blocks_self_move and state.summoned_this_turn:
		return &"garrison_action_unavailable"
	var action_cost: int = int(monster_combat_rules.self_move_action_cost)
	if state.actions_used + action_cost > monster_combat_rules.actions_per_turn:
		return &"garrison_action_unavailable"
	var pattern_id: StringName = get_unit_tactical_pattern(unit)
	var ignores_engagement: bool = tactical_pattern_snapshot.ignores_engagement_for_move(pattern_id)
	if not ignores_engagement and tactical_core_facing_rules.engagement_locks_self_move() and is_unit_engaged(unit):
		return &"garrison_action_unavailable"
	return &"ok"


func _garrison_public_board_reason(reason_code: Variant) -> StringName:
	match StringName(str(reason_code)):
		&"garrison_slot_occupied": return &"garrison_slot_occupied"
		&"garrison_unit_already_assigned": return &"garrison_unit_already_assigned"
		&"garrison_support_destroyed", &"garrison_support_missing": return &"garrison_support_destroyed"
		&"garrison_owner_mismatch": return &"garrison_structure_hostile"
		&"garrison_slot_missing": return &"garrison_slot_missing"
	return &"garrison_target_stale"


func _garrison_expectations_match(status: Dictionary, options: Dictionary) -> bool:
	var expected: Dictionary = options.get("expected_status", options)
	if expected.is_empty():
		return true
	for key in [
		"unit_runtime_id", "structure_id", "slot_id", "from_cell", "parent_cell", "target_cell",
		"terrain_revision", "source_terrain_revision", "structure_revision", "garrison_revision", "action_revision",
	]:
		if expected.has(key) and expected.get(key) != status.get(key):
			return false
	return true


func _capture_garrison_unit_rollback(unit: CardData, state: Variant) -> Dictionary:
	return {
		"cell": get_unit_cell(unit),
		"actions_used": int(state.actions_used),
		"moves_used": int(state.moves_used),
		"last_action": state.last_action,
		"garrison": get_garrison_state_for_unit(unit).duplicate(true),
	}


func _restore_garrison_unit_rollback(unit: CardData, state: Variant, rollback: Dictionary) -> void:
	var original_cell: Vector2i = rollback.get("cell", INVALID_GRID_CELL)
	if original_cell != INVALID_GRID_CELL and get_unit_cell(unit) != original_cell:
		_assign_unit_cell_atomic(unit, original_cell, &"garrison_rollback", false)
	state.actions_used = int(rollback.get("actions_used", state.actions_used))
	state.moves_used = int(rollback.get("moves_used", state.moves_used))
	state.last_action = StringName(str(rollback.get("last_action", state.last_action)))
	_emit_unit_state(unit)


func _restore_garrison_assignment(assignment: Dictionary) -> bool:
	if assignment.is_empty():
		return true
	var plan := {
		"structure_id": assignment.get("structure_id", &""),
		"slot_id": assignment.get("slot_id", &""),
		"unit_runtime_id": int(assignment.get("unit_runtime_id", 0)),
		"owner_side": assignment.get("owner_side", &"player"),
		"parent_cell": assignment.get("parent_cell", INVALID_GRID_CELL),
		"socket_name": assignment.get("socket_name", &""),
		"slot_role": assignment.get("slot_role", &""),
		"support_module_id": assignment.get("support_module_id", &""),
		"platform_height_offset": int(assignment.get("platform_height_offset", 0)),
		"entered_turn": int(assignment.get("entered_turn", 0)),
		"expected_structure_revision": int(get_structure_snapshot().get("revision", -1)),
		"expected_garrison_revision": int(context.tactical_structure_board_state.get_garrison_snapshot().get("revision", -1)),
	}
	var restored: Dictionary = context.tactical_structure_board_state.apply_garrison_assign(plan)
	if not bool(restored.get("ok", false)):
		return false
	if StringName(str(assignment.get("state", &"active"))) == &"displaced_pending_exit":
		var current: Dictionary = context.tactical_structure_board_state.get_garrison_for_unit(int(assignment.get("unit_runtime_id", 0)))
		var displaced: Dictionary = context.tactical_structure_board_state.mark_garrison_displaced({
			"structure_id": current.get("structure_id", &""),
			"slot_id": current.get("slot_id", &""),
			"unit_runtime_id": int(current.get("unit_runtime_id", 0)),
			"expected_assignment_revision": int(current.get("assignment_revision", -1)),
			"expected_garrison_revision": int(context.tactical_structure_board_state.get_garrison_snapshot().get("revision", -1)),
		})
		return bool(displaced.get("ok", false))
	return true


func _next_garrison_transaction_id(kind: StringName, unit_runtime_id: int) -> StringName:
	_garrison_transaction_serial += 1
	return StringName("garrison:%s:%d:turn:%d:%d" % [
		kind,
		unit_runtime_id,
		int(context.get_turn_number()) if context != null else 0,
		_garrison_transaction_serial,
	])


func _garrison_reason_text(reason_code: StringName) -> String:
	match reason_code:
		&"ok": return "可以驻防／撤离"
		&"garrison_rules_unavailable": return "驻防规则当前不可用"
		&"garrison_unit_missing": return "单位状态不存在"
		&"garrison_unit_ineligible": return "该单位不能驻防"
		&"garrison_unit_dead": return "单位已经离场"
		&"garrison_unit_not_on_board": return "单位不在棋盘上"
		&"garrison_unit_already_assigned": return "单位已经驻防"
		&"garrison_structure_missing": return "目标堡垒不存在"
		&"garrison_structure_hostile": return "不能进入敌方堡垒"
		&"garrison_structure_undermined": return "堡垒地基失稳，暂时不能进入"
		&"garrison_slot_missing": return "堡垒没有可用驻防位"
		&"garrison_slot_disabled": return "驻防位尚未启用"
		&"garrison_slot_occupied": return "驻防位已被占用"
		&"garrison_support_destroyed": return "驻防托座的支持构件已损毁"
		&"garrison_not_adjacent": return "单位必须位于堡垒相邻格"
		&"garrison_height_or_passage_blocked": return "高度差过大且没有己方通道"
		&"garrison_action_unavailable": return "本回合没有可用移动行动"
		&"garrison_entered_this_turn": return "本回合刚进入驻防，不能攻击"
		&"garrison_exit_cell_invalid": return "撤离目标格不可用"
		&"garrison_exit_cell_occupied": return "撤离目标格已被占用"
		&"garrison_forced_move_blocked": return "驻防单位不能被普通位移"
		&"garrison_commit_failed": return "驻防事务提交失败"
	return "当前无法驻防／撤离"


## Phase C Task 5: rule-only durability query. This does not authorize any
## existing attack/card route; Phase E owns permission-bearing attack plans.
func get_structure_damage_status(target_ref: Dictionary, steps: int, options: Dictionary = {}) -> Dictionary:
	if not _ensure_tactical_board_state() or not _ensure_structure_board():
		return {"ok": false, "reason_code": &"structure_target_stale"}
	var normalized: Dictionary = _normalize_structure_damage_target(target_ref, options)
	if not bool(normalized.get("ok", false)):
		return normalized
	return context.tactical_structure_board_state.get_damage_status(normalized.get("target", {}), steps)


## Core destruction is the only durability path that crosses card, terrain and
## structure authorities. Its preflight has no await, then all mutations occur
## in the specification's fixed order.
func commit_structure_damage(target_ref: Dictionary, steps: int, source: StringName, options: Dictionary = {}) -> Dictionary:
	var preview: Dictionary = get_structure_damage_status(target_ref, steps, options)
	if not bool(preview.get("ok", false)):
		return preview
	var normalized_target: Dictionary = preview.get("target", {})
	if not bool(preview.get("core_destroyed", false)):
		var module_fact: Dictionary = context.tactical_structure_board_state.commit_damage(normalized_target, steps, {"defer_signal": true})
		if bool(module_fact.get("ok", false)):
			if bool(options.get("phase_e_force_resolver_failure", false)):
				context.tactical_structure_board_state.rollback_damage(module_fact)
				return {"ok": false, "reason_code": &"structure_transaction_failed"}
			module_fact["source"] = source
			module_fact["garrison_aftermath"] = [] if bool(options.get("defer_aftermath", false)) else resolve_garrison_aftermath(module_fact, bool(options.get("defer_signal", false))).duplicate(true)
			if not bool(options.get("defer_signal", false)):
				context.tactical_structure_board_state.publish_damage_fact(module_fact)
		return module_fact
	return _commit_structure_core_cleanup(preview, source, options, &"structure_damage")


## Shared deterministic lifecycle for ordinary core destruction and foundation
## collapse. The caller supplies a real lethal preview; this never invents damage.
func _commit_structure_core_cleanup(
	preview: Dictionary,
	source: StringName,
	options: Dictionary = {},
	cleanup_cause: StringName = &"structure_damage",
) -> Dictionary:
	if not bool(preview.get("ok", false)) or not bool(preview.get("core_destroyed", false)):
		return {"ok": false, "reason_code": &"structure_transaction_failed"}
	var normalized_target: Dictionary = preview.get("target", {}).duplicate(true)
	var before: Dictionary = preview.get("before", {}).duplicate(true)
	var owner_side: StringName = before.get("owner_side", &"player")
	var source_card: CardData = _structure_card_for_owner(int(before.get("source_runtime_id", 0)), owner_side)
	if StringName(str(before.get("source_kind", &""))) == &"card" and source_card == null:
		return {"ok": false, "reason_code": &"structure_target_stale"}
	var cell: Vector2i = before.get("cell", INVALID_GRID_CELL)
	var terrain_before: Dictionary = get_cell_state(cell)
	if terrain_before.is_empty() or int(normalized_target.get("expected_terrain_revision", -1)) != int(terrain_before.get("revision", -2)):
		return {"ok": false, "reason_code": &"structure_target_stale"}
	var terrain_changes: Array[Dictionary] = [{
		"cell": cell,
		"expected_height": int(terrain_before.get("height", -1)),
		"expected_revision": int(terrain_before.get("revision", -1)),
		"target_height": int(terrain_before.get("height", -1)),
		"target_surface": &"ruins",
	}]
	var terrain_preflight: Dictionary = get_cell_state_change_status(terrain_changes)
	var actual_steps: int = int(preview.get("actual_steps", 0))
	var structure_preflight: Dictionary = context.tactical_structure_board_state.get_damage_status(normalized_target, actual_steps)
	if not bool(terrain_preflight.get("ok", false)) or not bool(structure_preflight.get("ok", false)):
		return {"ok": false, "reason_code": &"structure_transaction_failed"}
	var rollback: Dictionary = _capture_core_destruction_rollback(source_card)
	# Card cleanup precedes structure deletion. The shared helper clears legacy
	# building/P05/P08 state and is idempotent in both graveyard stores.
	if source_card != null:
		if owner_side == &"boss":
			context.enemy.traps.erase(source_card)
			cleanup_building_state(source_card)
			_cleanup_piece_runtime(source_card)
			_add_enemy_card_to_graveyard(source_card)
		else:
			context.player.traps.erase(source_card)
			move_card_to_graveyard_once(source_card)
	if bool(options.get("phase_c_force_structure_commit_failure", false)):
		_restore_core_destruction_rollback(rollback)
		return {"ok": false, "reason_code": &"structure_transaction_failed"}
	var destruction_fact: Dictionary = context.tactical_structure_board_state.commit_damage(normalized_target, actual_steps, {"defer_signal": true})
	if not bool(destruction_fact.get("ok", false)):
		_restore_core_destruction_rollback(rollback)
		return {"ok": false, "reason_code": &"structure_transaction_failed"}
	if bool(options.get("phase_c_force_terrain_commit_failure", false)) or bool(options.get("phase_e_force_resolver_failure", false)):
		context.tactical_structure_board_state.rollback_damage(destruction_fact)
		_restore_core_destruction_rollback(rollback)
		return {"ok": false, "reason_code": &"structure_transaction_failed"}
	var terrain_source := &"phase_d2_foundation_collapse" if cleanup_cause == &"foundation_collapse" else &"phase_c_structure_core_destroyed"
	var terrain_fact: Dictionary = commit_cell_state_changes(terrain_changes, terrain_source, options)
	if not bool(terrain_fact.get("ok", false)):
		context.tactical_structure_board_state.rollback_damage(destruction_fact)
		_restore_core_destruction_rollback(rollback)
		return {"ok": false, "reason_code": &"structure_transaction_failed"}
	destruction_fact["source"] = source
	destruction_fact["cleanup_cause"] = cleanup_cause
	destruction_fact["core_destroyed"] = true
	destruction_fact["before"] = before
	destruction_fact["before_modules"] = preview.get("before_modules", []).duplicate(true)
	destruction_fact["terrain"] = terrain_fact.duplicate(true)
	destruction_fact["destroyed_card_runtime_id"] = source_card.get_instance_id() if source_card != null else 0
	destruction_fact["garrison_aftermath"] = [] if bool(options.get("defer_aftermath", false)) else resolve_garrison_aftermath(destruction_fact, bool(options.get("defer_signal", false))).duplicate(true)
	if not bool(options.get("defer_signal", false)):
		context.tactical_structure_board_state.publish_damage_fact(destruction_fact)
	return destruction_fact


## Only the synchronous transaction owner calls this, once after finalizing
## payment/action state. Receipts contain values; publishing never mutates rules.
func publish_structure_damage_notifications(fact: Dictionary) -> void:
	if not bool(fact.get("ok", false)):
		return
	var terrain: Dictionary = fact.get("terrain", {})
	if not terrain.is_empty():
		context.tactical_board_state.publish_changes_fact(terrain.get("terrain", terrain))
		var foundation: Dictionary = terrain.get("foundation", {})
		if not foundation.get("transitions", []).is_empty():
			context.tactical_structure_board_state.publish_damage_fact(foundation)
	for aftermath: Dictionary in fact.get("garrison_aftermath", []):
		var move: Dictionary = aftermath.get("move_fact", {})
		if not move.is_empty():
			var unit: CardData = _find_field_card_by_runtime_id(int(aftermath.get("unit_runtime_id", 0)), &"player")
			if unit == null:
				unit = _find_field_card_by_runtime_id(int(aftermath.get("unit_runtime_id", 0)), &"boss")
			if unit != null:
				var side: StringName = _state_for_card(unit).owner_side
				var from_cell: Vector2i = move.from_cell
				var to_cell: Vector2i = move.to_cell
				_emit_unit_state(unit)
				unit_cell_changed.emit(unit, side, from_cell, to_cell, &"garrison_support_eject")
				unit_lane_changed.emit(unit, side, from_cell.x, to_cell.x, &"garrison_support_eject")
		garrison_transaction_committed.emit(aftermath.duplicate(true))
	context.tactical_structure_board_state.publish_damage_fact(fact)


func _capture_core_destruction_rollback(source_card: CardData) -> Dictionary:
	var relay_target_bonuses: Array[Dictionary] = []
	if source_card != null:
		var relay_entry: Dictionary = _rook_relay_by_source.get(source_card.get_instance_id(), {})
		var source_key: StringName = relay_entry.get("source_key", &"")
		for target_id: int in relay_entry.get("targets", []):
			var state = unit_combat_states.get(target_id, null)
			if state == null or source_key == &"":
				continue
			var sources: Dictionary = state.get_temporary_max_hp_sources()
			if sources.has(source_key):
				relay_target_bonuses.append({
					"target_id": target_id,
					"source_key": source_key,
					"amount": int(sources.get(source_key, 0)),
					"max_hp": int(state.max_hp),
					"current_hp": int(state.current_hp),
				})
	return {
		"traps": context.player.traps.duplicate(),
		"graveyard": context.player.graveyard.duplicate(),
		"graveyard_mirror": graveyard_system.player_graveyard.duplicate() if graveyard_system != null else [],
		"enemy_traps": context.enemy.traps.duplicate(),
		"enemy_graveyard": context.enemy.graveyard.duplicate(),
		"boss_deck_graveyard": context.boss_deck.graveyard.duplicate() if context.boss_deck != null and "graveyard" in context.boss_deck else [],
		"building_states": building_states.duplicate(true),
		"anchors": _piece_anchor_by_runtime_id.duplicate(true),
		"piece_runtime": _piece_runtime_state_by_runtime_id.duplicate(true),
		"rook_sources": _rook_relay_by_source.duplicate(true),
		"rook_targets": _rook_relay_by_target.duplicate(true),
		"relay_target_bonuses": relay_target_bonuses,
	}


func _restore_core_destruction_rollback(snapshot: Dictionary) -> void:
	context.player.traps = snapshot.get("traps", []).duplicate()
	context.player.graveyard = snapshot.get("graveyard", []).duplicate()
	context.enemy.traps = snapshot.get("enemy_traps", []).duplicate()
	context.enemy.graveyard = snapshot.get("enemy_graveyard", []).duplicate()
	if context.boss_deck != null and "graveyard" in context.boss_deck:
		context.boss_deck.graveyard = snapshot.get("boss_deck_graveyard", []).duplicate()
	if graveyard_system != null:
		graveyard_system.player_graveyard = snapshot.get("graveyard_mirror", []).duplicate()
	building_states = snapshot.get("building_states", {}).duplicate(true)
	_piece_anchor_by_runtime_id = snapshot.get("anchors", {}).duplicate(true)
	_piece_runtime_state_by_runtime_id = snapshot.get("piece_runtime", {}).duplicate(true)
	_rook_relay_by_source = snapshot.get("rook_sources", {}).duplicate(true)
	_rook_relay_by_target = snapshot.get("rook_targets", {}).duplicate(true)
	for bonus: Dictionary in snapshot.get("relay_target_bonuses", []):
		var state = unit_combat_states.get(int(bonus.get("target_id", 0)), null)
		if state != null:
			state.set_temporary_max_hp_bonus(StringName(str(bonus.get("source_key", &""))), int(bonus.get("amount", 0)))
			state.max_hp = int(bonus.get("max_hp", state.max_hp))
			state.current_hp = int(bonus.get("current_hp", state.current_hp))


func _normalize_structure_damage_target(target_ref: Dictionary, options: Dictionary) -> Dictionary:
	if target_ref.is_empty():
		return {"ok": false, "reason_code": &"structure_target_required"}
	var cell_value: Variant = target_ref.get("cell", null)
	if not cell_value is Vector2i:
		return {"ok": false, "reason_code": &"structure_target_stale"}
	var cell: Vector2i = cell_value
	var terrain: Dictionary = get_cell_state(cell)
	if terrain.is_empty() or int(target_ref.get("expected_terrain_revision", -1)) != int(terrain.get("revision", -2)):
		return {"ok": false, "reason_code": &"structure_target_stale"}
	var target: Dictionary = target_ref.duplicate(true)
	var structure: Dictionary = get_structure_at_cell(cell)
	if target.get("target_kind") == &"structure_core" and not structure.is_empty() and structure.cell != cell:
		if target.get("structure_id") != structure.structure_id:
			return {"ok": false, "reason_code": &"structure_target_stale"}
		target.cell = structure.cell
		target.expected_terrain_revision = get_cell_state(structure.cell).revision
		return {"ok": true, "reason_code": &"ok", "target": target}
	if not options.has("source_cell"):
		return {"ok": true, "reason_code": &"ok", "target": target}
	var source_value: Variant = options.get("source_cell", null)
	if not source_value is Vector2i:
		return {"ok": false, "reason_code": &"structure_target_stale"}
	var source_cell: Vector2i = source_value
	if StringName(str(target.get("target_kind", &""))) != &"structure_core":
		return {"ok": true, "reason_code": &"ok", "target": target}
	var delta: Vector2i = source_cell - cell
	if absi(delta.x) + absi(delta.y) != 1:
		return {"ok": true, "reason_code": &"ok", "target": target}
	var crossed_edge: StringName = &""
	if delta == Vector2i(0, -1):
		crossed_edge = &"north"
	elif delta == Vector2i(1, 0):
		crossed_edge = &"east"
	elif delta == Vector2i(0, 1):
		crossed_edge = &"south"
	else:
		crossed_edge = &"west"
	var module: Dictionary = get_structure_module(cell, crossed_edge)
	if not module.is_empty() and StringName(str(module.get("structure_id", &""))) == StringName(str(target.get("structure_id", &""))) and int(module.get("integrity_current", 0)) > 0:
		target = context.tactical_structure_board_state.make_module_target_ref(cell, crossed_edge, int(terrain.get("revision", -1)))
	return {"ok": true, "reason_code": &"ok", "target": target}


## 只读结构占用查询。不读取 Presenter、模型节点、Mesh bounds 或 collision。
## source_runtime_id 为未来同源 anchor/core 豁免预留；Task 2 不实现建设、支付或伤害。
func is_cell_blocked_by_structure(cell: Vector2i, source_runtime_id: int = 0) -> bool:
	if not _ensure_structure_board():
		return false
	var structure: Dictionary = context.tactical_structure_board_state.get_structure_at_cell(cell)
	if structure.is_empty():
		return false
	if source_runtime_id != 0 and int(structure.get("source_runtime_id", 0)) == source_runtime_id:
		return false
	return (building_footprint_trial != null and building_footprint_trial.owns_solid_source(int(structure.get("source_runtime_id", 0)))) or structure.get("cell", cell) == cell


## Phase D2 Task 3: pure cross-authority terrain impact query. Terrain remains
## authoritative for cell height; this only composes the live P13 stability
## contract into the existing terrain preflight.
func get_terrain_structure_impact_status(terrain_plan: Array[Dictionary], options: Dictionary = {}) -> Dictionary:
	if not _ensure_tactical_board_state() or not _ensure_structure_board():
		return {"ok": false, "reason_code": &"board_state_missing"}
	var terrain_snapshot: Dictionary = get_all_cell_states()
	var impacts: Array[Dictionary] = []
	for index in range(terrain_plan.size()):
		var change: Dictionary = terrain_plan[index]
		var cell_value: Variant = change.get("cell", null)
		if not cell_value is Vector2i or typeof(change.get("target_height", null)) != TYPE_INT:
			return {"ok": false, "reason_code": &"structure_transaction_failed", "failed_index": index}
		var cell: Vector2i = cell_value
		var structure: Dictionary = get_structure_at_cell(cell)
		if structure.is_empty():
			continue
		var source_runtime_id: int = int(structure.get("source_runtime_id", 0))
		var current_terrain: Dictionary = terrain_snapshot.get(cell, {})
		var current_height: int = int(current_terrain.get("height", -1))
		var target_height: int = int(change.get("target_height", current_height))
		var impact := {
			"cell": cell,
			"structure_id": structure.get("structure_id", &""),
			"profile_id": structure.get("profile_id", &""),
			"source_runtime_id": source_runtime_id,
			"current_height": current_height,
			"target_height": target_height,
			"foundation_state": structure.get("foundation_state", &"stable"),
		}
		impacts.append(impact.duplicate(true))
		var is_live_stable_p13: bool = StringName(str(structure.get("profile_id", &""))) == &"p13_heat_sink" \
			and StringName(str(structure.get("foundation_state", &"stable"))) == &"stable" \
			and int(structure.get("integrity_current", 0)) > 0
		if is_live_stable_p13 and target_height < current_height:
			return {
				"ok": false,
				"reason_code": &"terrain_cell_stabilized_by_structure",
				"failed_index": index,
				"cell": cell,
				"structure_id": structure.get("structure_id", &""),
				"source_runtime_id": source_runtime_id,
				"impacts": impacts.duplicate(true),
			}.duplicate(true)
	return {
		"ok": true,
		"reason_code": &"ok",
		"impacts": impacts.duplicate(true),
	}.duplicate(true)


func _structure_build_result(card: CardData, cell: Vector2i) -> Dictionary:
	return {
		"ok": false,
		"reason_code": &"structure_profile_missing",
		"awaiting_replacement": false,
		"card_runtime_id": card.get_instance_id() if card != null else 0,
		"profile_id": &"",
		"cell": cell,
		"placement_kind": &"new_build",
		"orientation_edge": &"",
		"replacement_structure_id": &"",
		"replacement_source_runtime_id": 0,
		"terrain_before": {},
		"terrain_after": {},
		"foundation_before": {},
		"foundation_after": {},
		"terrain_changes": [],
		"core": {},
		"modules": [],
		"piece_anchor_cell": cell,
		"piece_anchor_runtime_id": card.get_instance_id() if card != null else 0,
		"anchor_binding": &"same_source_same_cell",
		"expected_terrain_revision": -1,
		"expected_structure_revision": -1,
		"expected_garrison_revision": -1,
	}


func _typed_structure_terrain_plan(raw: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if raw is Array:
		for item in raw:
			if item is Dictionary:
				result.append((item as Dictionary).duplicate(true))
	return result


## Phase C Task 3: pure P05 construction query. It prepares copied terrain and
## structure plans but never mutates the hand, board, resources or anchors.
func get_structure_build_status(card: CardData, cell: Vector2i, options: Dictionary = {}) -> Dictionary:
	return _get_structure_build_status(card, cell, options, false)


## Phase 100: pure geometry for opt-in engineering orders, never a card-play bypass.
## Completion/payment belongs to BuildingEngineeringTrial; ordinary API stays hand-only.
func get_engineering_structure_layout_status(card: CardData, cell: Vector2i, options: Dictionary = {}) -> Dictionary:
	if card == null or card.card_id not in ["P13", "P16"] or options.has("replacement_old_card"):
		return {"ok": false, "reason_code": &"engineering_profile_not_supported"}
	return _get_structure_build_status(card, cell, options, true)


## Phase101: completion can replace only this transaction's own live construction body.
func get_engineering_site_completion_status(card: CardData, cell: Vector2i, transaction_id: String, edge: StringName) -> Dictionary:
	if card == null or card.card_id not in ["P13", "P16"] or context == null or card not in context.player.traps:
		return {"ok": false, "reason_code": &"site_source_missing"}
	var current: Dictionary = get_structure_at_cell(cell)
	if str(card.get_meta("engineering_site_tx", "")) != transaction_id or transaction_id.is_empty() or current.is_empty() or int(current.get("source_runtime_id", 0)) != card.get_instance_id() or current.get("owner_side") != &"player" or int(current.get("integrity_current", 0)) <= 0:
		return {"ok": false, "reason_code": &"site_identity_changed"}
	if current.get("foundation_state", &"stable") != &"stable":
		return {"ok": false, "reason_code": &"site_foundation_unstable"}
	var result: Dictionary = _get_structure_build_status(card, cell, {"replacement_old_card": card, "orientation_edge": edge}, true)
	if result.get("ok", false):
		var terrain: Dictionary = get_cell_state(cell)
		if terrain.height != result.terrain_after.height or terrain.surface != result.terrain_after.surface:
			return {"ok": false, "reason_code": &"site_foundation_changed"}
	return result


func _get_structure_build_status(card: CardData, cell: Vector2i, options: Dictionary, engineering_layout: bool) -> Dictionary:
	var result: Dictionary = _structure_build_result(card, cell)
	if card == null:
		return result
	if context == null or context.player == null or (not engineering_layout and not card in context.player.hand):
		result.reason_code = &"structure_source_not_in_hand"
		return result
	if tactical_structure_rules == null:
		return result
	var profile: Dictionary = tactical_structure_rules.get_profile(str(card.card_id))
	if profile.is_empty():
		return result
	var profile_id := StringName(str(profile.get("profile_id", &"")))
	result.profile_id = profile_id
	if profile_id not in [&"p05_foundation", &"p08_fortification", &"p13_heat_sink", &"p16_containment_wall", &"p19_core_cathedral"]:
		result.reason_code = &"structure_profile_invalid"
		return result
	var is_p08: bool = profile_id == &"p08_fortification"
	var is_p19: bool = profile_id == &"p19_core_cathedral"
	var is_generic_d2_build: bool = profile_id in [&"p13_heat_sink", &"p16_containment_wall", &"p19_core_cathedral"]
	if is_generic_d2_build:
		result.erase("piece_anchor_cell")
		result.erase("piece_anchor_runtime_id")
		result.erase("anchor_binding")
	var pending_old: CardData = options.get("replacement_old_card") as CardData if options.has("replacement_old_card") else null
	if not _ensure_tactical_board_state() or not _ensure_structure_board():
		result.reason_code = &"structure_transaction_failed"
		return result
	if not tactical_grid_rules.is_cell_in_bounds(cell):
		result.reason_code = &"structure_cell_out_of_bounds"
		return result
	if not tactical_grid_rules.is_normal_summon_cell(&"player", cell) and (frontline_trial == null or not frontline_trial.can_build_forward(cell)):
		result.reason_code = &"frontline_support_required" if frontline_trial != null else &"structure_wrong_territory"
		return result
	var existing_structure: Dictionary = get_structure_at_cell(cell)
	var is_recovery_replacement := false
	if pending_old != null and profile_id in [&"p13_heat_sink", &"p16_containment_wall"] \
	and not existing_structure.is_empty() \
	and int(existing_structure.get("source_runtime_id", 0)) == pending_old.get_instance_id():
		if StringName(str(existing_structure.get("owner_side", &""))) != &"player" \
		or int(existing_structure.get("integrity_current", 0)) <= 0:
			result.reason_code = &"structure_target_stale"
			return result
		var existing_foundation := StringName(str(existing_structure.get("foundation_state", &"stable")))
		if existing_foundation == &"undermined":
			var recovery_garrison: Dictionary = context.tactical_structure_board_state.get_garrison_snapshot()
			for assignment_value: Variant in (recovery_garrison.get("assignments", {}) as Dictionary).values():
				if assignment_value is Dictionary and StringName(str((assignment_value as Dictionary).get("structure_id", &""))) == StringName(str(existing_structure.get("structure_id", &""))):
					result.reason_code = &"structure_replacement_garrison_occupied"
					result.expected_garrison_revision = int(recovery_garrison.get("revision", -1))
					return result
			is_recovery_replacement = true
			result.placement_kind = &"same_cell_replacement"
			result.replacement_structure_id = existing_structure.get("structure_id", &"")
			result.replacement_source_runtime_id = int(existing_structure.get("source_runtime_id", 0))
			result.foundation_before = existing_structure.duplicate(true)
			result.expected_garrison_revision = int(recovery_garrison.get("revision", -1))
		elif existing_foundation == &"collapse_due":
			result.reason_code = &"structure_replacement_not_stable"
			return result
	var p19_garrison_snapshot: Dictionary = {}
	if is_p19 and not existing_structure.is_empty():
		p19_garrison_snapshot = context.tactical_structure_board_state.get_garrison_snapshot()
		for assignment_value: Variant in (p19_garrison_snapshot.get("assignments", {}) as Dictionary).values():
			if assignment_value is Dictionary and StringName(str((assignment_value as Dictionary).get("structure_id", &""))) == StringName(str(existing_structure.get("structure_id", &""))):
				result.reason_code = &"structure_replacement_garrison_occupied"
				result.expected_garrison_revision = int(p19_garrison_snapshot.get("revision", -1))
				return result
	if get_unit_at_cell(cell) != null:
		result.reason_code = &"structure_cell_occupied_by_unit"
		return result
	if is_p19:
		if existing_structure.is_empty():
			result.reason_code = &"structure_replacement_required"
			return result
		var allowed_replacements: Array = profile.get("replacement_profile_ids", [])
		if StringName(str(existing_structure.get("profile_id", &""))) not in allowed_replacements:
			result.reason_code = &"structure_replacement_profile_invalid"
			return result
		if StringName(str(existing_structure.get("owner_side", &""))) != &"player" or int(existing_structure.get("integrity_current", 0)) <= 0:
			result.reason_code = &"structure_target_stale"
			return result
		if StringName(str(existing_structure.get("foundation_state", &"stable"))) != &"stable":
			result.reason_code = &"structure_replacement_not_stable"
			return result
		var authoritative_old: CardData = _player_trap_by_runtime_id(int(existing_structure.get("source_runtime_id", 0)))
		if authoritative_old == null:
			result.reason_code = &"structure_target_stale"
			return result
		if pending_old != null and pending_old != authoritative_old:
			result.reason_code = &"structure_target_stale"
			return result
		pending_old = authoritative_old
		result.placement_kind = &"same_cell_upgrade"
		result.replacement_structure_id = existing_structure.get("structure_id", &"")
		result.replacement_source_runtime_id = int(existing_structure.get("source_runtime_id", 0))
		result.foundation_before = existing_structure.duplicate(true)
		result.expected_garrison_revision = int(p19_garrison_snapshot.get("revision", -1))
	elif is_p08 and pending_old == null and StringName(str(existing_structure.get("profile_id", &""))) == &"p05_foundation":
		pending_old = _player_trap_by_runtime_id(int(existing_structure.get("source_runtime_id", 0)))
	if pending_old != null and (context.player == null or not pending_old in context.player.traps or not pending_old.is_building_card()):
		result.reason_code = &"structure_target_stale"
		return result
	var replacement_runtime_id: int = pending_old.get_instance_id() if pending_old != null else 0
	if not existing_structure.is_empty() and int(existing_structure.get("source_runtime_id", 0)) != replacement_runtime_id:
		result.reason_code = &"structure_cell_occupied_by_core"
		return result
	var replacement_anchor_here: bool = replacement_runtime_id != 0 and _anchor_cell_of_rid(replacement_runtime_id) == cell
	if (_get_blocking_piece_cells().has(cell) or _is_cell_used_by_anchor(cell, card.get_instance_id())) and not replacement_anchor_here:
		result.reason_code = &"structure_cell_occupied_by_anchor"
		return result

	var terrain_before: Dictionary = get_cell_state(cell)
	if terrain_before.is_empty():
		result.reason_code = &"structure_transaction_failed"
		return result
	var height: int = int(terrain_before.get("height", -1))
	var allowed_heights: Array = profile.get("allowed_heights", [])
	if not height in allowed_heights:
		result.reason_code = &"structure_cell_wrong_height"
		return result
	var surface := StringName(str(terrain_before.get("surface", &"")))
	if surface not in [&"flat", &"foundation"]:
		result.reason_code = &"structure_surface_invalid"
		return result

	var terrain_after: Dictionary = terrain_before.duplicate(true)
	var auto_raise_from_height: int = int(profile.get("auto_raise_from_height", -1))
	var result_height: int = int(profile.get("minimum_foundation_height", height)) \
		if auto_raise_from_height >= 0 and height == auto_raise_from_height else height
	terrain_after["height"] = result_height
	terrain_after["surface"] = &"foundation"
	if is_p19 or is_recovery_replacement:
		result.foundation_after = {
			"foundation_state": &"stable",
			"foundation_observed_height": result_height,
			"recovery_window_phase": &"none",
			"recovery_owner_turns_remaining": 0,
		}.duplicate(true)
	var terrain_change := {
		"cell": cell,
		"expected_height": height,
		"expected_revision": int(terrain_before.get("revision", -1)),
		"target_height": int(terrain_after.height),
		"target_surface": &"foundation",
	}
	var layout_owner_side := StringName(str(options.get("layout_owner_side", &"player")))
	if layout_owner_side not in [&"player", &"boss"]:
		layout_owner_side = &"player"
	result["layout_query_only"] = layout_owner_side == &"boss"
	var orientation_edge: StringName = &""
	if profile_id == &"p16_containment_wall":
		var requested_orientation := StringName(str(options.get("orientation_edge", &"")))
		if requested_orientation == &"":
			result.reason_code = &"structure_orientation_required"
			return result
		orientation_edge = tactical_structure_rules.normalize_relative_edge(layout_owner_side, requested_orientation)
		if orientation_edge not in [&"north", &"east", &"south", &"west"]:
			result.reason_code = &"structure_orientation_invalid"
			return result
		result.orientation_edge = orientation_edge
	var module_plan: Array[Dictionary] = []
	for descriptor: Dictionary in profile.get("modules", []):
		var relative_edge := StringName(str(descriptor.get("relative_edge", &"")))
		var edge: StringName = orientation_edge if relative_edge == &"selected" else tactical_structure_rules.normalize_relative_edge(
			layout_owner_side, relative_edge)
		var module_kind := StringName(str(descriptor.get("kind", &"wall")))
		var integrity: int = int(descriptor.get("integrity", 1))
		var module_preview := {
			"module_kind": module_kind,
			"edge": edge,
			"integrity_current": integrity,
			"integrity_max": integrity,
			"blocks_hostile_path": module_kind != &"gatehouse",
			"allows_owner_passage": module_kind == &"gatehouse",
		}
		if profile_id == &"p16_containment_wall":
			module_preview["canonical_edge"] = context.tactical_structure_board_state.canonical_edge_key(cell, edge)
		module_plan.append(module_preview)
	if edge_fortification_trial != null:
		for descriptor: Dictionary in module_plan:
			if int(edge_fortification_trial.get_edge(cell, descriptor.edge).get("hp", 0)) > 0:
				result.reason_code = &"structure_edge_occupied_by_fortification"
				return result
	var structure_plan := {
		"structure": {
			"profile_id": profile_id,
			"owner_side": layout_owner_side,
			"source_kind": &"card",
			"source_runtime_id": card.get_instance_id(),
			"source_card_id": StringName(str(card.card_id)),
			"cell": cell,
			"minimum_foundation_height": int(profile.get("minimum_foundation_height", 1)),
			"foundation_observed_height": result_height,
			"integrity_current": int(profile.get("core_integrity", 1)),
			"integrity_max": int(profile.get("core_integrity", 1)),
			"reserved_garrison_slots": int(profile.get("reserved_garrison_slots", 0)),
			"reserved_garrison_slot_defs": (profile.get("garrison_slots", []) as Array).duplicate(true),
		},
		"modules": module_plan,
	}
	var replacement_source_kind: StringName = &"none"
	if pending_old != null:
		var old_structure_id: StringName = context.tactical_structure_board_state.get_source_structure_id(replacement_runtime_id)
		if old_structure_id != &"":
			structure_plan["remove_source_runtime_ids"] = [replacement_runtime_id]
			replacement_source_kind = &"spatial"
			if is_p19:
				result.placement_kind = &"same_cell_upgrade"
				result.replacement_structure_id = old_structure_id
				result.replacement_source_runtime_id = replacement_runtime_id
			else:
				var old_structure: Dictionary = (get_structure_snapshot().get("structures", {}) as Dictionary).get(old_structure_id, {})
				result.placement_kind = &"same_cell_replacement" if old_structure.get("cell", INVALID_GRID_CELL) == cell else &"dual_target_replacement"
				if result.placement_kind == &"same_cell_replacement":
					result.replacement_structure_id = old_structure_id
					result.replacement_source_runtime_id = replacement_runtime_id
		else:
			if is_p19:
				result.reason_code = &"structure_target_stale"
				return result
			replacement_source_kind = &"legacy"
			result.placement_kind = &"dual_target_replacement"
		result["replacement_old_card"] = pending_old
		result["replacement_source_kind"] = replacement_source_kind
	if frontline_trial != null and is_p08:
		for current: Dictionary in get_structure_snapshot().get("structures", {}).values():
			if current.get("profile_id") == &"p08_fortification" and int(current.get("source_runtime_id", 0)) != replacement_runtime_id:
				result.reason_code = &"frontline_large_limit"
				return result
		var footprint_edge: StringName = &"north"
		if frontline_trial.rotation_enabled:
			footprint_edge = StringName(options.get("footprint_edge", frontline_trial.build_edge))
		if footprint_edge not in frontline_trial.BUILD_EDGES:
			result.reason_code = &"structure_orientation_invalid"
			return result
		result["footprint_edge"] = footprint_edge
		var platform: Vector2i = cell + frontline_trial.build_offset(footprint_edge)
		result["preview_footprint_cells"] = [cell, platform]
		if not tactical_grid_rules.is_cell_in_bounds(platform):
			result.reason_code = &"structure_cell_out_of_bounds"
			return result
		if get_unit_at_cell(platform) != null or not get_structure_at_cell(platform).is_empty() or _is_cell_used_by_anchor(platform, card.get_instance_id()):
			result.reason_code = &"frontline_platform_occupied"
			return result
		var platform_terrain: Dictionary = get_cell_state(platform)
		if absi(int(platform_terrain.get("height", 0)) - height) > 1 or StringName(str(platform_terrain.get("surface", &""))) not in [&"flat", &"foundation"]:
			result.reason_code = &"frontline_platform_height"
			return result
		structure_plan.structure["footprint_cells"] = [cell, platform]
		for module: Dictionary in module_plan:
			module.edge = frontline_trial.rotate_module_edge(module.edge, footprint_edge)
	var typed_terrain_plan: Array[Dictionary] = [terrain_change]
	if engineering_layout and building_footprint_trial != null:
		var footprint_status: Dictionary = building_footprint_trial.augment_layout(card, cell, structure_plan, typed_terrain_plan, result)
		if not footprint_status.ok:
			result.reason_code = footprint_status.reason_code
			return result
	var terrain_status: Dictionary = get_cell_state_change_status(typed_terrain_plan)
	var structure_status: Dictionary = context.tactical_structure_board_state.get_change_status(structure_plan)
	if not bool(terrain_status.get("ok", false)) or not bool(structure_status.get("ok", false)):
		var failure_reason := StringName(str(structure_status.get("reason_code", terrain_status.get("reason_code", &"structure_transaction_failed"))))
		result.reason_code = &"structure_edge_conflict" if profile_id == &"p16_containment_wall" and failure_reason == &"duplicate_canonical_edge" else failure_reason
		if structure_status.has("failed_index"):
			var failed_index: int = int(structure_status.get("failed_index", -1))
			result["conflicting_module"] = module_plan[failed_index].duplicate(true) if failed_index >= 0 and failed_index < module_plan.size() else {}
		if result.reason_code == &"structure_edge_conflict":
			var legal_orientation_edges: Array[StringName] = []
			for candidate_edge: StringName in [&"north", &"east", &"south", &"west"]:
				var candidate_plan: Dictionary = structure_plan.duplicate(true)
				var candidate_modules: Array = candidate_plan.get("modules", [])
				if candidate_modules.size() != 1:
					continue
				(candidate_modules[0] as Dictionary)["edge"] = candidate_edge
				(candidate_modules[0] as Dictionary)["canonical_edge"] = context.tactical_structure_board_state.canonical_edge_key(cell, candidate_edge)
				if bool(context.tactical_structure_board_state.get_change_status(candidate_plan).get("ok", false)):
					legal_orientation_edges.append(candidate_edge)
			result["legal_orientation_edges"] = legal_orientation_edges.duplicate()
		return result

	var current_structure_revision: int = int(get_structure_snapshot().get("revision", -1))
	var current_garrison_revision: int = int(context.tactical_structure_board_state.get_garrison_snapshot().get("revision", -1))
	if options.has("expected_terrain_revision") and int(options.get("expected_terrain_revision", -1)) != int(terrain_before.get("revision", -1)):
		result.reason_code = &"structure_target_stale"
		return result
	if options.has("expected_structure_revision") and int(options.get("expected_structure_revision", -1)) != current_structure_revision:
		result.reason_code = &"structure_target_stale"
		return result
	if options.has("expected_garrison_revision") and int(options.get("expected_garrison_revision", -1)) != current_garrison_revision:
		result.reason_code = &"structure_target_stale"
		return result

	var play_status: Dictionary = get_card_play_status(card, pending_old != null, pending_old != null)
	if not engineering_layout and not bool(play_status.get("ok", false)):
		if bool(options.get("allow_replacement_selection", false)) and needs_building_replacement(card):
			result.awaiting_replacement = true
			result.reason_code = &"structure_replacement_required"
			return result
		result.reason_code = &"piece_base_action_blocked"
		result["reason"] = play_status.get("reason", "")
		return result

	result.terrain_before = terrain_before.duplicate(true)
	result.terrain_after = terrain_after.duplicate(true)
	result.terrain_changes = [terrain_change.duplicate(true)]
	result.core = (structure_plan.structure as Dictionary).duplicate(true)
	result.modules = module_plan.duplicate(true)
	result.expected_terrain_revision = int(terrain_before.get("revision", -1))
	result.expected_structure_revision = current_structure_revision
	result.expected_garrison_revision = current_garrison_revision
	result["_terrain_plan"] = typed_terrain_plan.duplicate(true)
	result["_structure_plan"] = structure_plan.duplicate(true)
	result.ok = true
	result.reason_code = &"ok"
	return result.duplicate(true)


func get_legal_structure_build_targets(card: CardData, options: Dictionary = {}) -> Array[Dictionary]:
	var legal: Array[Dictionary] = []
	if card == null or tactical_structure_rules == null:
		return legal
	var profile: Dictionary = tactical_structure_rules.get_profile(str(card.card_id))
	var profile_id := StringName(str(profile.get("profile_id", &"")))
	var cells: Array[Vector2i] = tactical_grid_rules.get_all_cells() if frontline_trial != null else tactical_grid_rules.get_ordered_summon_cells(&"player")
	for cell in cells:
		if profile_id == &"p16_containment_wall":
			for orientation_edge: StringName in [&"north", &"east", &"south", &"west"]:
				var oriented_options: Dictionary = options.duplicate(true)
				oriented_options["orientation_edge"] = orientation_edge
				var oriented_status: Dictionary = get_structure_build_status(card, cell, oriented_options)
				if bool(oriented_status.get("ok", false)):
					legal.append(oriented_status.duplicate(true))
			continue
		var status: Dictionary = get_structure_build_status(card, cell, options)
		if bool(status.get("ok", false)):
			legal.append(status.duplicate(true))
	return legal.duplicate(true)


func get_legal_structure_build_cells(card: CardData, options: Dictionary = {}) -> Array[Vector2i]:
	var legal: Array[Vector2i] = []
	for target: Dictionary in get_legal_structure_build_targets(card, options):
		var cell_value: Variant = target.get("cell", null)
		if cell_value is Vector2i and cell_value not in legal:
			legal.append(cell_value)
	return legal


func commit_structure_build_or_upgrade(card: CardData, cell: Vector2i, options: Dictionary = {}) -> Dictionary:
	var preview: Dictionary = get_structure_build_status(card, cell, options)
	if not bool(preview.get("ok", false)):
		return preview.duplicate(true)
	return _commit_prevalidated_structure_build(card, cell, options, preview)


## Shared synchronous commit boundary for P05/P08 piece builds and generic D2
## BUILD cards. All fallible cross-authority checks happen before play_card() or
## replace_building_and_play() is invoked exactly once.
func _commit_prevalidated_structure_build(
	card: CardData,
	cell: Vector2i,
	options: Dictionary,
	locked_preview: Dictionary,
) -> Dictionary:
	if card == null or context == null or context.player == null or not card in context.player.hand:
		return {"ok": false, "reason_code": &"structure_source_not_in_hand"}
	if int(locked_preview.get("card_runtime_id", 0)) != card.get_instance_id() or locked_preview.get("cell", INVALID_GRID_CELL) != cell:
		return {"ok": false, "reason_code": &"structure_target_stale"}
	var fresh: Dictionary = get_structure_build_status(card, cell, options)
	if not bool(fresh.get("ok", false)):
		return fresh.duplicate(true)
	if bool(fresh.get("layout_query_only", false)):
		return {"ok": false, "reason_code": &"structure_transaction_failed"}
	var typed_terrain_plan: Array[Dictionary] = _typed_structure_terrain_plan(fresh.get("_terrain_plan", []))
	var terrain_preflight: Dictionary = get_cell_state_change_status(typed_terrain_plan)
	var structure_preflight: Dictionary = context.tactical_structure_board_state.get_change_status(fresh.get("_structure_plan", {}))
	if not bool(terrain_preflight.get("ok", false)) or not bool(structure_preflight.get("ok", false)):
		return {"ok": false, "reason_code": &"structure_target_stale"}
	if bool(options.get("phase_c_force_commit_failure", false)) or bool(options.get("phase_d2_force_commit_failure", false)):
		return {
			"ok": false,
			"reason_code": &"structure_transaction_failed",
			"failure_stage": &"final_prevalidated_commit_boundary",
		}

	var pending_old: CardData = fresh.get("replacement_old_card") as CardData if fresh.get("replacement_old_card") is CardData else null
	var play_result: Dictionary
	if pending_old != null:
		var prepared_spatial_replacement: bool = StringName(str(fresh.get("replacement_source_kind", &"none"))) == &"spatial"
		play_result = replace_building_and_play(card, pending_old, prepared_spatial_replacement)
	else:
		play_result = play_card(card)
	if not bool(play_result.get("ok", false)):
		return {
			"ok": false,
			"reason_code": play_result.get("reason_code", &"play_failed"),
			"reason": play_result.get("reason", ""),
		}

	var profile_id := StringName(str(fresh.get("profile_id", &"")))
	var terrain_source := StringName("phase_d2_%s_build" % str(profile_id))
	var skipped_foundation_ids: Array[StringName] = []
	var replacement_structure_id := StringName(str(fresh.get("replacement_structure_id", &"")))
	if replacement_structure_id != &"":
		skipped_foundation_ids.append(replacement_structure_id)
	var terrain_fact: Dictionary = _commit_cell_state_changes_composed(
		typed_terrain_plan, terrain_source, {}, skipped_foundation_ids
	)
	if not bool(terrain_fact.get("ok", false)):
		return {"ok": false, "reason_code": &"structure_transaction_failed"}
	var structure_fact: Dictionary = context.tactical_structure_board_state.commit_prevalidated(fresh.get("_structure_plan", {}))
	if not bool(structure_fact.get("ok", false)):
		return {"ok": false, "reason_code": &"structure_transaction_failed"}
	_ensure_legacy_building_runtime_once(card)

	var structure_build_fact := {
		"placement_kind": fresh.get("placement_kind", &"new_build"),
		"replacement_source_kind": fresh.get("replacement_source_kind", &"none"),
		"replacement_structure_id": fresh.get("replacement_structure_id", &""),
		"replacement_source_runtime_id": int(fresh.get("replacement_source_runtime_id", 0)),
		"orientation_edge": fresh.get("orientation_edge", &""),
		"foundation_before": fresh.get("foundation_before", {}).duplicate(true),
		"foundation_after": fresh.get("foundation_after", {}).duplicate(true),
		"terrain": terrain_fact.duplicate(true),
		"structure": structure_fact.duplicate(true),
	}
	if profile_id in [&"p05_foundation", &"p08_fortification"]:
		structure_build_fact["piece_anchor_cell"] = cell
		structure_build_fact["piece_anchor_runtime_id"] = card.get_instance_id()
		structure_build_fact["anchor_binding"] = &"same_source_same_cell"
	if StringName(str(fresh.get("placement_kind", &""))) == &"dual_target_replacement":
		structure_build_fact["dual_target_replacement"] = {
			"old_card_runtime_id": pending_old.get_instance_id() if pending_old != null else 0,
			"new_card_runtime_id": card.get_instance_id(),
			"replacement_source_kind": fresh.get("replacement_source_kind", &"none"),
			"new_cell": cell,
		}
	var committed := {
		"ok": true,
		"reason_code": &"ok",
		"card": card,
		"play_result": play_result.duplicate(true),
		"structure_build_preview": fresh.duplicate(true),
		"structure_build_fact": structure_build_fact.duplicate(true),
	}
	hand_structure_build_committed.emit(card, structure_build_fact.duplicate(true))
	return committed

# ===== Phase 27B: Tactical Unit Pattern Snapshot =====
var tactical_pattern_snapshot := TacticalUnitPatternSnapshotClass.default_snapshot()

func configure_tactical_unit_patterns(snapshot) -> void:
	tactical_pattern_snapshot = snapshot if snapshot != null else TacticalUnitPatternSnapshotClass.default_snapshot()


# ── Phase 27C: Core Breach / Facing / Rear Defense ──

var tactical_core_facing_rules = TacticalCoreFacingRuleSnapshotClass.new({}, false, [])

func configure_tactical_core_facing_rules(snapshot: RefCounted) -> void:
	tactical_core_facing_rules = snapshot if snapshot != null else TacticalCoreFacingRuleSnapshotClass.new({}, false, [])


# ── Phase 27D: Shared Command Economy ──

var tactical_command_economy_rules = TacticalCommandEconomySnapshotClass.new({}, false, [])
# Per-side runtime state: { "current_points", "turn_max_points", "scheduled_next_turn",
#   "scheduled_next_turn_penalty", "gross_spent", "crossed_thresholds",
#   "instant_refund_total", "refund_by_trigger", "turn_open" }
var _command_economy_player: Dictionary = {}
var _command_economy_boss: Dictionary = {}
var _r5_legacy_bypass_removed: bool = true  # Phase 27D-R5: shared pool is sole legality gate

func configure_tactical_command_economy(snapshot: RefCounted) -> void:
	tactical_command_economy_rules = snapshot if snapshot != null else TacticalCommandEconomySnapshotClass.new({}, false, [])


# ── Phase 27F: Boss tactical AI (read-only planning + atomic execution) ──

var boss_tactical_ai_profile: RefCounted = BossTacticalAIProfileClass.new()
var _boss_tactical_ai_planner: RefCounted = BossTacticalAIPlannerClass.new(boss_tactical_ai_profile)


# ── Phase 27I-R0: Card Piece Traits (immutable snapshot, injected at battle start) ──

var card_piece_traits: RefCounted = CardPieceTraitSnapshotClass.default_snapshot()
# 锚点：key = card runtime instance id → {card, owner_side, anchor_cell, blocks_cell, set_turn}
var _piece_anchor_by_runtime_id: Dictionary = {}
# 运行时棋型状态：key = card runtime instance id → 可变状态（P03 首次行动结阵标记、P05 每轮保护消耗）
var _piece_runtime_state_by_runtime_id: Dictionary = {}

# Phase 27J: unified OD release authority.
signal od_release_event(event_id: StringName, payload: Dictionary)
var od_release_rules: RefCounted = ODReleaseRuleSnapshotClass.default_snapshot()
var _od_release_resolver: RefCounted = ODReleaseResolverClass.new()
var _od_release_resolving := false
var _od_release_transactions: Dictionary = {}
var _od_release_transaction_serial: int = 0
var _skill_heat_transaction_serial: int = 0
# PHASE72: one identity per actual card-play attempt, shared by all its sources.
var _card_heat_transaction_serial: int = 0
var _ritual_trial: RefCounted = null
var _ritual_last_receipt: Dictionary = {}


func configure_ritual_finisher_trial(enabled: bool) -> void:
	_ritual_trial = RitualFinisherTrialClass.new() if enabled else null
	_ritual_last_receipt.clear()


func is_ritual_finisher_trial_enabled() -> bool:
	return _ritual_trial != null


func configure_ritual_payoff_profile(profile: StringName) -> bool:
	return _ritual_trial != null and not _od_release_resolving and _ritual_trial.configure_payoff_profile(profile)


func _ritual_trial_snapshot() -> Dictionary:
	if _ritual_trial == null or context == null or context.player == null:
		return {}
	var active_ids: Array[int] = []
	var garrison_ids: Array[int] = []
	for raw in context.player.field:
		var unit: CardData = raw as CardData
		if unit == null:
			continue
		var state: Variant = _state_for_card(unit)
		if state == null or state.is_dead():
			continue
		var rid: int = unit.get_instance_id()
		active_ids.append(rid)
		if StringName(str(get_garrison_state_for_unit(unit).get("state", &""))) == &"active":
			garrison_ids.append(rid)
	return _ritual_trial.snapshot(active_ids, garrison_ids, context.depth_pressure, context.get_depth_max_value())


func configure_card_piece_traits(snapshot) -> void:
	card_piece_traits = snapshot if snapshot != null else CardPieceTraitSnapshotClass.default_snapshot()


func configure_od_release_rules(snapshot: RefCounted) -> void:
	od_release_rules = snapshot if snapshot != null else ODReleaseRuleSnapshotClass.default_snapshot()


# PHASE63_BEGIN_CONFIG
var _core_damage_heat_trial = null
var _core_damage_heat_configuration_closed := false
var _core_damage_heat_resolving := false
func configure_core_damage_heat_trial(profile: String) -> bool:
	if profile not in ["original","first-core-heat","ascended-core-heat","ascended-delayed-core-heat"] or _core_damage_heat_trial!=null or _core_damage_heat_configuration_closed:return false
	if context==null or context.turn_count>1 or context.cards_played_this_turn>0 or _od_release_resolving or _siege_command_in_progress:return false
	if int(get_command_economy_snapshot("player").get("gross_spent",0))>0 or int(get_core_command_state().get("used",0))>0:return false
	_core_damage_heat_trial=load("res://core/battle/deferred_core_damage_heat_trial.gd").new(profile) if profile=="ascended-delayed-core-heat" else load("res://core/battle/first_core_damage_heat_trial.gd").new(profile)
	return true
func seal_core_damage_heat_trial_configuration() -> void:
	_core_damage_heat_configuration_closed=true
func get_core_damage_heat_trial_status() -> Dictionary:
	if _core_damage_heat_trial==null:return {"profile":"original","amount":0,"used":false,"last_receipt":{}}
	return _core_damage_heat_trial.snapshot(self)
# PHASE67_BEGIN_SETTLEMENT
func resolve_pending_core_damage_heat() -> Dictionary:
	if _core_damage_heat_trial==null or _core_damage_heat_trial.profile!="ascended-delayed-core-heat":return {"applied":0,"reason":"disabled"}
	if _core_damage_heat_resolving:return {"applied":0,"reason":"core_damage_heat_busy"}
	_core_damage_heat_resolving=true
	var result: Dictionary=_core_damage_heat_trial.settle(self)
	_core_damage_heat_resolving=false
	return result
# PHASE67_END_SETTLEMENT
# PHASE63_END_CONFIG
func get_od_release_status(side: String = "player") -> Dictionary:
	var result := {
		"ok": false,
		"reason_code": &"wrong_side",
		"side": side,
		"heat": int(context.od_mode.current_od) if context and context.od_mode else 0,
		"readiness_threshold": od_release_rules.get_readiness_threshold(),
		"release_heat_cost": od_release_rules.get_release_heat_cost(),
		"sources": [],
	}
	if side != "player" or context == null or context.player == null:
		return result
	if _od_release_resolving:
		result.reason_code = &"release_busy"
		return result
	if not bool(get_command_economy_snapshot("player").get("turn_open", false)):
		result.reason_code = &"not_player_turn"
		return result
	if result.heat < result.readiness_threshold:
		result.reason_code = &"insufficient_heat"
		return result
	for raw in context.player.field:
		var source: CardData = raw as CardData
		if source == null or not source.piece_enabled:
			continue
		var source_status := get_od_release_source_status(source)
		if bool(source_status.get("ok", false)):
			result.sources.append(source)
	if (result.sources as Array).is_empty():
		result.reason_code = &"no_legal_source"
		return result
	result.ok = true
	result.reason_code = &"ok"
	return result


func get_od_release_source_status(source: CardData) -> Dictionary:
	var result: Dictionary = _od_release_resolver.build_source_plan(self, source, od_release_rules)
	result["heat"] = int(context.od_mode.current_od) if context and context.od_mode else 0
	result["readiness_threshold"] = od_release_rules.get_readiness_threshold()
	result["points"] = int(get_command_economy_snapshot("player").get("current_points", 0))
	if _od_release_resolving:
		result.ok = false
		result.reason_code = &"release_busy"
		return result
	if not bool(get_command_economy_snapshot("player").get("turn_open", false)):
		result.ok = false
		result.reason_code = &"not_player_turn"
		return result
	if result.heat < result.readiness_threshold:
		result.ok = false
		result.reason_code = &"insufficient_heat"
		return result
	if result.points < int(result.get("command_cost", 0)):
		result.ok = false
		result.reason_code = &"insufficient_command_points"
		return result
	return result


func get_od_release_target_status(source: CardData, target: Variant) -> Dictionary:
	return _od_release_resolver.validate_target(get_od_release_source_status(source), target)


## Current public opportunities and a payment-only budget; never projects a board move.
## Action triggers can change heat/refunds/legality. Re-query after committing the action.
func get_od_release_decision_status(source: CardData) -> Dictionary:
	var release := get_od_release_source_status(source)
	var result := {"ok": bool(release.get("ok", false)), "reason_code": release.get("reason_code"),
		"command_cost": int(release.get("command_cost", 0)), "heat_cost": int(release.get("od_cost", 0)),
		"points_before": int(release.get("points", 0)), "heat_before": int(release.get("heat", 0)),
		"points_after_payment": -1, "heat_after_conversion_only": -1,
		"readiness_threshold": int(release.get("readiness_threshold", 8)),
		"ritual_trial": false, "ritual_used": false, "preparation_complete": false,
		"reward_ready_now": false, "reward_heat_gap": 0,
		"current_core_options": [], "current_core_min_cost": -1, "core_payment_shortfall": 0,
		"projection_scope": &"payment_only_no_action_triggers"}
	if not result.ok:
		return result
	result.points_after_payment = result.points_before - result.command_cost
	result.heat_after_conversion_only = maxi(0, result.heat_before - result.heat_cost)
	var ritual := get_final_convergence_status("player")
	result.ritual_trial = bool(ritual.get("ritual_trial", false))
	result.ritual_used = bool(ritual.get("used", false))
	result.preparation_complete = bool(ritual.get("attack_ready", false)) or bool(ritual.get("guard_ready", false))
	result.reward_ready_now = result.ritual_trial and not result.ritual_used and result.preparation_complete and bool(ritual.get("ok", false))
	if result.ritual_trial and not result.ritual_used:
		result.reward_heat_gap = maxi(0, result.readiness_threshold - result.heat_after_conversion_only)
	for card: CardData in context.player.field:
		var core := get_unit_command_status(card, "attack_core")
		if not bool(core.get("ok", false)):
			continue
		var cost := int(core.get("cost", 0))
		result.current_core_options.append({"runtime_id": card.get_instance_id(), "card_id": card.card_id,
			"name": card.get_display_name(), "cell": get_unit_cell(card), "cost": cost})
		if result.current_core_min_cost < 0 or cost < result.current_core_min_cost:
			result.current_core_min_cost = cost
	if result.current_core_min_cost >= 0:
		result.core_payment_shortfall = maxi(0, result.current_core_min_cost - result.points_after_payment)
	return result


func execute_od_release(side: String, source: CardData, target: Variant, options: Dictionary = {}) -> Dictionary:
	var transaction_id: StringName = StringName(str(options.get("transaction_id", "")))
	if transaction_id != &"" and _od_release_transactions.has(transaction_id):
		return {"ok": false, "reason_code": &"duplicate_transaction", "transaction_id": transaction_id}
	if side != "player":
		return {"ok": false, "reason_code": &"wrong_side"}
	var status := get_od_release_target_status(source, target)
	if not bool(status.get("ok", false)):
		return status
	if not context.od_mode.can_convert_heat(int(status.get("od_cost", 0))):
		status.ok = false
		status.reason_code = &"insufficient_heat"
		return status
	if transaction_id == &"":
		_od_release_transaction_serial += 1
		transaction_id = StringName("release:%s:%d:turn:%d:%d" % [
			str(status.get("piece_type", "unknown")), source.get_instance_id(), context.turn_count, _od_release_transaction_serial])
	var piece_type := StringName(status.get("piece_type", &""))
	var release_source_id := StringName("od_release:%s" % str(piece_type))
	var feedback_options := {
		"source_descriptor": build_heat_source_descriptor(&"od_release", release_source_id, source),
		"piece_type": piece_type,
		"board_cell": get_unit_cell(source),
		"target_cell": target if target is Vector2i else get_unit_cell(target as CardData) if target is CardData else INVALID_GRID_CELL,
	}
	_od_release_resolving = true
	_commit_od_release_feedback(&"release_started", transaction_id, release_source_id, feedback_options, &"started")
	od_release_event.emit(&"od_release_started", status.duplicate(true))
	var action_result: Dictionary = {}
	match StringName(status.get("piece_type", &"")):
		&"pawn":
			action_result = _execute_pawn_od_release(source, target, status)
		&"knight":
			action_result = _execute_knight_od_release(source, target, status)
		&"bishop":
			action_result = _execute_bishop_od_release(source, target, status)
		&"rook":
			action_result = _execute_rook_od_release(source, target, status)
		_:
			action_result = {"ok": false, "reason_code": &"unknown_resolver"}
	if not bool(action_result.get("ok", false)):
		_od_release_resolving = false
		var failed := status.duplicate(true)
		failed.ok = false
		failed.reason_code = action_result.get("reason_code", &"resolver_failed")
		failed["action_result"] = action_result
		_commit_od_release_feedback(&"release_cancelled", transaction_id, release_source_id, feedback_options, &"cancelled")
		od_release_event.emit(&"od_release_cancelled", failed.duplicate(true))
		return failed
	var conversion_options := feedback_options.duplicate(true)
	conversion_options["transaction_id"] = transaction_id
	conversion_options["conversion_reason"] = &"od_release"
	conversion_options["occurrence_id"] = &"conversion"
	var conversion: Dictionary = context.convert_heat(int(status.get("od_cost", 0)), release_source_id, conversion_options)
	if not bool(conversion.get("ok", false)):
		_od_release_resolving = false
		var conversion_failed := {"ok": false, "reason_code": &"conversion_failed", "action_result": action_result}
		_commit_od_release_feedback(&"release_cancelled", transaction_id, release_source_id, feedback_options, &"conversion_failed")
		od_release_event.emit(&"od_release_cancelled", conversion_failed.duplicate(true))
		return conversion_failed
	if transaction_id != &"":
		_od_release_transactions[transaction_id] = true
	_od_release_resolving = false
	var result := status.duplicate(true)
	result.ok = true
	result.reason_code = &"ok"
	result["transaction_id"] = transaction_id
	result["action_result"] = action_result
	result["conversion"] = conversion
	result["heat_before"] = conversion.get("heat_before", 0)
	result["heat_after"] = conversion.get("heat_after", 0)
	result["layer_before"] = conversion.get("layer_before", 1)
	result["layer_after"] = conversion.get("layer_after", 1)
	if context.chain_system != null:
		context.chain_system.record_tactical_event(
			StringName(status.get("chain_event", &"")), transaction_id, true)
	_commit_od_release_feedback(&"release_committed", transaction_id, release_source_id, feedback_options, &"committed")
	od_release_event.emit(&"od_release_committed", result.duplicate(true))
	return result


func _commit_od_release_feedback(event_kind: StringName, transaction_id: StringName,
		source_id: StringName, feedback_options: Dictionary, occurrence_id: StringName) -> Dictionary:
	if context == null or context.od_mode == null:
		return {}
	var state_options := feedback_options.duplicate(true)
	state_options["occurrence_id"] = occurrence_id
	var payload: Dictionary = context.od_mode.build_feedback_state_payload(source_id, state_options)
	return context.commit_od_feedback_event(event_kind, transaction_id, payload)


func get_final_convergence_status(side: String = "player") -> Dictionary:
	if _ritual_trial != null:
		return _get_ritual_final_status(side)
	var rules: Dictionary = od_release_rules.get_final_convergence_rules()
	var heat: int = int(context.od_mode.current_od) if context and context.od_mode else 0
	var layer: int = int(context.od_mode.engine_layer) if context and context.od_mode else 1
	var boss_phase: int = int(context.enemy.combat_phase) if context and context.enemy else 0
	var chain_snapshot: Dictionary = context.chain_system.get_tactical_chain_snapshot() if context and context.chain_system else {}
	var result := {
		"ok": false,
		"reason_code": &"wrong_side",
		"side": side,
		"heat": heat,
		"layer": layer,
		"boss_phase": boss_phase,
		"chain": chain_snapshot,
		"minimum_layer": int(rules.get("minimum_layer", 4)),
		"minimum_heat": int(rules.get("minimum_heat", 8)),
		"required_boss_phase": int(rules.get("required_boss_phase", 3)),
		"boss_damage": int(rules.get("boss_damage", 5)),
		"sources": [],
	}
	if side != "player" or context == null:
		return result
	if layer < result.minimum_layer:
		result.reason_code = &"insufficient_engine_layer"
		return result
	if heat < result.minimum_heat:
		result.reason_code = &"insufficient_heat"
		return result
	if boss_phase < result.required_boss_phase:
		result.reason_code = &"boss_phase_locked"
		return result
	if bool(rules.get("requires_qualifying_chain", true)) and not bool(chain_snapshot.get("qualifying", false)):
		result.reason_code = &"tactical_chain_incomplete"
		return result
	var release_status: Dictionary = get_od_release_status(side)
	if not bool(release_status.get("ok", false)):
		result.reason_code = release_status.get("reason_code", &"no_legal_source")
		return result
	result.sources = (release_status.get("sources", []) as Array).duplicate()
	result.ok = true
	result.reason_code = &"ok"
	return result


func execute_final_convergence(side: String, source: CardData, target: Variant, options: Dictionary = {}) -> Dictionary:
	if _ritual_trial != null:
		return _execute_ritual_final(side, source, target, options)
	var transaction_id := StringName(str(options.get("transaction_id", "")))
	if transaction_id != &"" and _od_release_transactions.has(transaction_id):
		return {"ok": false, "reason_code": &"duplicate_transaction", "transaction_id": transaction_id}
	var final_status: Dictionary = get_final_convergence_status(side)
	if not bool(final_status.get("ok", false)):
		return final_status
	if not (final_status.get("sources", []) as Array).has(source):
		final_status.ok = false
		final_status.reason_code = &"stale_source"
		return final_status
	var target_status: Dictionary = get_od_release_target_status(source, target)
	if not bool(target_status.get("ok", false)):
		return target_status
	var release_result: Dictionary = execute_od_release(side, source, target, options)
	if not bool(release_result.get("ok", false)):
		return release_result
	var damage: int = maxi(0, int(final_status.get("boss_damage", 5)))
	var hp_before: int = context.enemy.hp
	context.enemy.take_damage(damage)
	check_hp_phase_lock(damage, hp_before)
	var result: Dictionary = release_result.duplicate(true)
	result["final_convergence"] = true
	result["final_boss_damage"] = damage
	result["final_actual_hp_loss"] = hp_before - context.enemy.hp
	od_release_event.emit(&"final_convergence_committed", result.duplicate(true))
	return result


func _get_ritual_final_status(side: String) -> Dictionary:
	var release: Dictionary = {
		"ok": false, "reason_code": &"wrong_side", "side": side,
		"heat": int(context.od_mode.current_od) if context and context.od_mode else 0,
		"readiness_threshold": od_release_rules.get_readiness_threshold(),
		"release_heat_cost": od_release_rules.get_release_heat_cost(),
		"sources": [],
	}
	# PHASE62_BEGIN_RITUAL_GATE
	if od_release_rules.has_method("get_ritual_readiness_threshold"):release.readiness_threshold=od_release_rules.get_ritual_readiness_threshold()
	# PHASE62_END_RITUAL_GATE
	if side == "player" and context != null and context.player != null:
		if _od_release_resolving:
			release.reason_code = &"release_busy"
		elif not bool(get_command_economy_snapshot("player").get("turn_open", false)):
			release.reason_code = &"not_player_turn"
		elif release.heat < release.readiness_threshold:
			release.reason_code = &"insufficient_heat"
		else:
			release.ok = true
			release.reason_code = &"ok"
	var evidence: Dictionary = _ritual_trial_snapshot()
	var result: Dictionary = release.duplicate(true)
	result["ritual_trial"] = true
	result["payoff_profile"] = evidence.get("payoff_profile", "original")
	for key in ["attack_count", "garrison_count", "control_count", "living_attack_participants", "living_guard_participants", "attack_sources", "guard_sources", "control_sources"]:
		result[key] = evidence.get(key, 0 if key.ends_with("count") else [])
	result["depth_max"] = context.get_depth_max_value() if context else 6
	result["available_paths"] = evidence.get("available_paths", [])
	result["path_effects"] = evidence.get("path_effects", {})
	result["attack_ready"] = evidence.get("attack_ready", false)
	result["guard_ready"] = evidence.get("guard_ready", false)
	result["overcharge_available"] = evidence.get("overcharge_available", false)
	result["overcharge_depth_after"] = evidence.get("overcharge_depth_after", 0)
	result["depth"] = context.depth_pressure if context else 0
	result["used"] = evidence.get("used", false)
	result["last_receipt"] = _ritual_last_receipt.duplicate(true)
	var previews: Dictionary = {}
	for path in result.available_paths:
		var effect: Dictionary = (result.path_effects as Dictionary).get(path, {})
		previews[path] = {"normal": _preview_ritual_damage(effect, false)}
		if bool(result.overcharge_available):
			previews[path]["overcharge"] = _preview_ritual_damage(effect, true)
	result["path_previews"] = previews
	if bool(result.used):
		result.ok = false
		result.reason_code = &"ritual_already_used"
	return result


func _preview_ritual_damage(effect: Dictionary, overcharge: bool) -> Dictionary:
	var enemy_obj: Enemy = context.enemy
	var damage: int = int(effect.get("damage", 4)) + (2 if overcharge else 0)
	var bypass: bool = bool(effect.get("bypass_boss_shield", false))
	var shield_absorbed: int = 0 if bypass else mini(damage, enemy_obj.boss_shield)
	var remaining: int = damage - shield_absorbed
	var armor: int = (enemy_obj.forge_armor_bonus if enemy_obj._turn_count <= 2 else 0) + (1 if enemy_obj.forge_domain_active else 0)
	var effective: int = maxi(1, remaining - armor) if remaining > 0 and armor > 0 else remaining
	var hp_before: int = enemy_obj.hp
	var hp_after: int = hp_before - effective
	var phase_lock: int = 0
	var overflow: int = 0
	var shield_after: int = enemy_obj.boss_shield - shield_absorbed
	var boss_od_after: int = enemy_obj.od
	if context.are_boss_phase_locks_enabled():
		if context.phases_locked_this_turn >= 1:
			overflow = damage
		elif not context.boss_phase2_triggered and hp_after <= int(context.get_boss_phase_lock(3).get("hp_threshold", 25)):
			phase_lock = 3
			var threshold3: int = int(context.get_boss_phase_lock(3).get("hp_threshold", 25))
			overflow = maxi(0, damage - (hp_before - threshold3))
			hp_after = threshold3
			shield_after += int(context.get_boss_phase_lock(3).get("shield_gain", 6))
			boss_od_after = maxi(boss_od_after, 8)
		elif not context.boss_phase1_triggered and hp_after <= int(context.get_boss_phase_lock(2).get("hp_threshold", 51)):
			phase_lock = 2
			var threshold2: int = int(context.get_boss_phase_lock(2).get("hp_threshold", 51))
			overflow = maxi(0, damage - (hp_before - threshold2))
			hp_after = threshold2
			shield_after += int(context.get_boss_phase_lock(2).get("shield_gain", 4))
		if overflow > 0:
			boss_od_after = mini(enemy_obj.max_od, boss_od_after + clampi(ceili(float(overflow) / context.OVERFLOW_OD_DIVISOR), context.OVERFLOW_OD_MIN, context.OVERFLOW_OD_MAX))
	boss_od_after = maxi(0, boss_od_after - int(effect.get("boss_od_reduce", 0)))
	var depth_after: int = context.depth_pressure + (2 if overcharge else 0)
	var shield_removed: int = shield_after
	return {"nominal_damage": damage, "actual_hp_loss": hp_before - hp_after, "bypass_boss_shield": bypass,
		"shield_absorbed": shield_absorbed, "boss_shield_removed_after_hit": shield_removed,
		"boss_shield_removed_total": shield_absorbed + shield_removed,
		"boss_shield_after": 0, "draw_requested": int(effect.get("draw", 0)) + (1 if overcharge else 0),
		"enemy_unit_count": enemy_obj.field.size(), "enemy_unit_damage": int(effect.get("unit_damage", 0)),
		"phase_lock": phase_lock, "overflow": overflow,
		"boss_od_after": boss_od_after, "depth_after": depth_after,
		"backlash": depth_after >= context.get_depth_max_value()}


func _execute_ritual_final(side: String, source: CardData, target: Variant, options: Dictionary) -> Dictionary:
	var transaction_id := StringName(str(options.get("transaction_id", "")))
	if transaction_id != &"" and _od_release_transactions.has(transaction_id):
		return {"ok": false, "reason_code": &"duplicate_transaction", "transaction_id": transaction_id}
	var status: Dictionary = _get_ritual_final_status(side)
	if not bool(status.get("ok", false)):
		return status
	var path := str(options.get("ritual_path", "early"))
	if not (status.get("available_paths", []) as Array).has(path):
		return {"ok": false, "reason_code": &"ritual_path_not_ready"}
	var overcharge := bool(options.get("ritual_overcharge", false))
	if overcharge and not bool(status.get("overcharge_available", false)):
		return {"ok": false, "reason_code": &"ritual_overcharge_blocked"}
	var effect: Dictionary = (status.get("path_effects", {}) as Dictionary).get(path, {})
	var damage: int = int(effect.get("damage", 4)) + (2 if overcharge else 0)
	var od_cost: int = int(status.get("release_heat_cost", 5))
	if not context.od_mode.can_convert_heat(od_cost):
		return {"ok": false, "reason_code": &"insufficient_heat"}
	if transaction_id == &"":
		_od_release_transaction_serial += 1
		transaction_id = StringName("ritual:turn:%d:%d" % [context.turn_count, _od_release_transaction_serial])
	_od_release_resolving = true
	var conversion: Dictionary = context.convert_heat(od_cost, &"ritual_finisher", {
		"transaction_id": transaction_id, "conversion_reason": &"ritual_finisher",
		"occurrence_id": &"conversion", "source_descriptor": build_heat_source_descriptor(&"ritual_finisher", &"ritual_finisher")})
	if not bool(conversion.get("ok", false)):
		_od_release_resolving = false
		return {"ok": false, "reason_code": &"conversion_failed", "conversion": conversion}
	_od_release_transactions[transaction_id] = true
	var ritual_sources: Array[Dictionary] = []
	var preparation: Dictionary = _ritual_trial_snapshot()
	var source_ids: Array = preparation.get("living_attack_participants" if path == "attack" else "living_guard_participants", []) if path != "early" else []
	for unit: CardData in context.player.field:
		if source_ids.has(unit.get_instance_id()): ritual_sources.append({"cell": get_unit_cell(unit), "name": unit.get_display_name()})
	if path == "guard":
		var source_cells: Array[Vector2i] = []
		for id in preparation.get("guard_structures", []):
			var structure: Dictionary = context.tactical_structure_board_state.get_snapshot().structures.get(id, {})
			if not structure.is_empty() and int(structure.get("integrity_current",0)) > 0 and not source_cells.has(structure.cell):
				source_cells.append(structure.cell)
				ritual_sources.append({"cell": structure.cell, "name": "驻军建筑"})
	var hp_before: int = context.enemy.hp
	var boss_shield_before: int = context.enemy.boss_shield
	var boss_od_before: int = context.enemy.od
	var shield_before: int = context.player.shield
	var depth_before: int = context.depth_pressure
	var bypass: bool = bool(effect.get("bypass_boss_shield", false))
	context.enemy.take_damage(damage, bypass)
	check_hp_phase_lock(damage, hp_before)
	var boss_shield_removed: int = context.enemy.boss_shield
	if boss_shield_removed > 0:
		context.enemy.add_boss_shield(-boss_shield_removed, "Ritual Finisher")
	var unit_damage: int = int(effect.get("unit_damage", 0))
	var unit_hits: int = 0
	var unit_destroyed: int = 0
	var unit_hit_facts: Array[Dictionary] = []
	if unit_damage > 0:
		for raw_unit in context.enemy.field.duplicate():
			var enemy_unit := raw_unit as CardData
			if enemy_unit == null or not enemy_unit in context.enemy.field:
				continue
			var hit_cell := get_unit_cell(enemy_unit)
			var unit_result: Dictionary = damage_unit(enemy_unit, unit_damage, "Ritual Finisher")
			if not bool(unit_result.get("ok", false)):
				continue
			unit_hit_facts.append({"cell": hit_cell, "name": enemy_unit.get_display_name(), "hp_loss": int(unit_result.before) - int(unit_result.after)})
			unit_hits += 1
			if int(unit_result.get("after", 1)) <= 0 and bool(destroy_unit(enemy_unit, "ritual_finisher").get("ok", false)):
				unit_destroyed += 1
	var guard_shield: int = int(effect.get("shield", 0))
	if guard_shield > 0:
		context.player.shield += guard_shield
	var boss_od_reduce: int = int(effect.get("boss_od_reduce", 0))
	if boss_od_reduce > 0:
		context.enemy.modify_od(-boss_od_reduce)
	if overcharge:
		context.add_depth_pressure(2, "Ritual Finisher Overcharge")
	var draw_requested: int = int(effect.get("draw", 0)) + (1 if overcharge else 0)
	var draw_result: Dictionary = draw_player_cards(draw_requested, "Ritual Finisher")
	_ritual_trial.mark_used()
	var result: Dictionary = status.duplicate(true)
	result["transaction_id"] = transaction_id
	result["conversion"] = conversion
	result["od_cost"] = od_cost
	result["heat_before"] = conversion.get("heat_before", 0)
	result["heat_after"] = conversion.get("heat_after", 0)
	result["piece_type"] = &"ritual"
	result["final_convergence"] = true
	result["ritual_path"] = path
	result["ritual_overcharge"] = overcharge
	result["final_boss_damage"] = damage
	result["final_actual_hp_loss"] = hp_before - context.enemy.hp
	result["ritual_boss_od_before"] = boss_od_before
	result["ritual_boss_od_after"] = context.enemy.od
	result["ritual_shield_gained"] = context.player.shield - shield_before
	result["ritual_boss_shield_removed"] = boss_shield_removed
	result["ritual_shield_bypassed"] = bypass
	result["ritual_shield_absorbed"] = 0 if bypass else mini(damage, boss_shield_before)
	result["ritual_boss_shield_removed_total"] = int(result.ritual_shield_absorbed) + boss_shield_removed
	result["ritual_sources"] = ritual_sources
	result["ritual_unit_hit_facts"] = unit_hit_facts
	result["ritual_enemy_units_hit"] = unit_hits
	result["ritual_enemy_units_destroyed"] = unit_destroyed
	result["ritual_draw_requested"] = draw_requested
	result["ritual_cards_drawn"] = (draw_result.get("drawn", []) as Array).size()
	result["ritual_cards_burned"] = (draw_result.get("burned", []) as Array).size()
	result["ritual_fatigue_damage"] = int(draw_result.get("fatigue_damage", 0))
	result["ritual_draw_result"] = draw_result
	result["ritual_depth_before"] = depth_before
	result["ritual_depth_after"] = context.depth_pressure
	_ritual_last_receipt = {}
	for key in ["ritual_path", "final_actual_hp_loss", "ritual_cards_drawn", "ritual_draw_requested", "ritual_shield_gained", "ritual_boss_shield_removed_total", "ritual_shield_bypassed", "ritual_shield_absorbed", "ritual_boss_od_before", "ritual_boss_od_after", "ritual_depth_before", "ritual_depth_after"]:
		_ritual_last_receipt[key] = result.get(key)
	_od_release_resolving = false
	od_release_event.emit(&"final_convergence_committed", result.duplicate(true))
	return result


func _execute_pawn_od_release(source: CardData, target: Variant, status: Dictionary) -> Dictionary:
	if not target is Vector2i:
		return {"ok": false, "reason_code": &"stale_target"}
	var cost: int = int(status.get("command_cost", 0))
	var econ := _economy_for_side("player")
	var points_before: int = int(econ.get("current_points", 0))
	if points_before < cost:
		return {"ok": false, "reason_code": &"insufficient_command_points"}
	var move_result: Dictionary = move_unit_to_cell(source, target, MOVE_FORCED_EFFECT)
	if not bool(move_result.get("ok", false)):
		return move_result
	econ["current_points"] = points_before - cost
	econ["gross_spent"] = int(econ.get("gross_spent", 0)) + cost
	if context != null and context.player != null:
		context.player.shield += 1
	return {"ok": true, "reason_code": &"ok", "cost": cost, "move": move_result, "formation_shield": 1}


func _execute_knight_od_release(source: CardData, target: Variant, status: Dictionary) -> Dictionary:
	if not target is Vector2i:
		return {"ok": false, "reason_code": &"stale_target"}
	var cost: int = int(status.get("command_cost", 0))
	var econ := _economy_for_side("player")
	var points_before: int = int(econ.get("current_points", 0))
	var gross_before: int = int(econ.get("gross_spent", 0))
	if points_before < cost:
		return {"ok": false, "reason_code": &"insufficient_command_points"}
	var move_result: Dictionary = move_unit_to_cell(source, target, MOVE_FORCED_EFFECT)
	if not bool(move_result.get("ok", false)):
		return move_result
	econ["current_points"] = points_before - cost
	econ["gross_spent"] = gross_before + cost
	var disruption: Dictionary = {}
	var attack_targets: Array[CardData] = get_legal_attack_targets(source)
	if not attack_targets.is_empty():
		disruption = _apply_unit_damage_gateway(attack_targets[0], od_release_rules.get_knight_disruption_damage(), "od_release:knight_arc_leap")
	return {
		"ok": true,
		"reason_code": &"ok",
		"cost": cost,
		"points_before": points_before,
		"points_after": points_before - cost,
		"move": move_result,
		"disruption": disruption,
	}


func _execute_bishop_od_release(source: CardData, target: Variant, status: Dictionary) -> Dictionary:
	var target_card: CardData = target as CardData if target is CardData else null
	if target_card == null:
		return {"ok": false, "reason_code": &"stale_target"}
	var cost: int = int(status.get("command_cost", 0))
	var econ := _economy_for_side("player")
	var points_before: int = int(econ.get("current_points", 0))
	if points_before < cost:
		return {"ok": false, "reason_code": &"insufficient_command_points"}
	var attack_result: Dictionary = resolve_monster_attack(source, target_card, 1)
	if not bool(attack_result.get("ok", false)):
		return attack_result
	econ["current_points"] = points_before - cost
	econ["gross_spent"] = int(econ.get("gross_spent", 0)) + cost
	return {"ok": true, "reason_code": &"ok", "cost": cost, "conduction_bonus": 1, "attack": attack_result}


func _execute_rook_od_release(source: CardData, target: Variant, status: Dictionary) -> Dictionary:
	var target_card: CardData = target as CardData if target is CardData else null
	if target_card == null:
		return {"ok": false, "reason_code": &"stale_target"}
	var cost: int = int(status.get("command_cost", 0))
	var econ := _economy_for_side("player")
	var before: int = int(econ.get("current_points", 0))
	if before < cost:
		return {"ok": false, "reason_code": &"insufficient_command_points"}
	econ["current_points"] = before - cost
	var grant := _rook_grant_relay(source, [target_card], int(context.get_turn_number()) if context else 0)
	if not bool(grant.get("ok", false)):
		econ["current_points"] = before
		return grant
	return {"ok": true, "cost": cost, "points_before": before, "points_after": before - cost, "relay": grant}


func get_card_piece_traits() -> RefCounted:
	return card_piece_traits


func get_tactical_unit_pattern_snapshot() -> RefCounted:
	return tactical_pattern_snapshot


func get_virtual_core_anchor_cell(owner_side: StringName) -> Vector2i:
	return tactical_grid_rules.get_virtual_core_anchor_cell(owner_side)


## Phase 27I-R0: 从 origin 按棋路 pattern 投影朝向、唯一、界内格。
## purpose: &"move" → movement_offsets；&"attack" → attack_offsets。
## extra_rank: >0 时将兵卒扇区向前延伸 extra_rank 排（P04 强化监视范围）。
func project_piece_cells(pattern_id: StringName, origin: Vector2i, owner_side: StringName, purpose: StringName, extra_rank: int = 0) -> Array[Vector2i]:
	var offsets: Array[Vector2i] = []
	if purpose == &"move":
		offsets = tactical_pattern_snapshot.get_movement_offsets(pattern_id)
	else:
		offsets = tactical_pattern_snapshot.get_attack_offsets(pattern_id)
	var result: Array[Vector2i] = []
	for off in offsets:
		var oriented: Vector2i = tactical_grid_rules.orient_offset(owner_side, off)
		var extended := Vector2i(oriented.x, oriented.y * (1 + maxi(0, extra_rank)))
		var cell := origin + extended
		if tactical_grid_rules.is_cell_in_bounds(cell) and not result.has(cell):
			result.append(cell)
	return result


## Phase 27I-R1: 唯一权威射线扫描。从 origin 沿 directions 逐格扫描到首个占用格。
## target_rule: &"enemy_unit"（主教）/ &"friendly_unit"（战车）。
## 纯只读几何查询，无副作用；Presenter/UI 只消费返回值，不自行推算几何。
## 返回 canonical ordered cells / legal targets（去重）/ blocking cells / boss core 判定。
func scan_piece_rays(
	origin: Vector2i,
	directions: Array[Vector2i],
	owner_side: StringName,
	target_rule: StringName,
	options: Dictionary = {}
) -> Dictionary:
	var result := {
		"ok": true,
		"origin": origin,
		"directions": directions.duplicate(),
		"ordered_cells": [],
		"rays": {},
		"legal_targets": [],
		"blocking_cells": {},
		"boss_core_eligible": false,
	}
	if origin == INVALID_GRID_CELL:
		result["ok"] = false
		return result
	# Boss 虚拟核心独立判定：优先 options.core_cell，否则取对侧虚拟核心格。
	var core_cell: Vector2i = INVALID_GRID_CELL
	if options.has("core_cell"):
		core_cell = options["core_cell"] as Vector2i
	else:
		core_cell = get_virtual_core_anchor_cell(&"boss") if owner_side == &"player" else get_virtual_core_anchor_cell(&"player")
	var seen_targets: Dictionary = {}
	for dir in directions:
		var ray_cells: Array[Vector2i] = []
		var step := 1
		while true:
			var cell: Vector2i = origin + dir * step
			if not tactical_grid_rules.is_cell_in_bounds(cell):
				# 到达边界后：仅当虚拟核心格是该射线下一格时判 eligible（路径无阻挡已保证）。
				if cell == core_cell:
					result["boss_core_eligible"] = true
				break
			var occ := _ray_occupant_at(cell)
			if not occ.is_empty():
				result["blocking_cells"][cell] = occ
				var occ_unit: CardData = occ.get("occupant") as CardData
				var occ_kind: String = str(occ.get("kind", ""))
				var occ_side: StringName = occ.get("side", &"")
				var matches := false
				if target_rule == &"enemy_unit":
					matches = occ_kind == "unit" and occ_side != owner_side
				elif target_rule == &"friendly_unit":
					matches = occ_kind == "unit" and occ_side == owner_side
				if matches and occ_unit != null and not seen_targets.has(occ_unit.get_instance_id()):
					seen_targets[occ_unit.get_instance_id()] = true
					result["legal_targets"].append(occ_unit)
				break
			ray_cells.append(cell)
			result["ordered_cells"].append(cell)
			step += 1
		result["rays"][dir] = ray_cells
	return result


## Phase 27I-R1: 单格占用判定（射线用）。死亡/离场单位不参与阻挡。
## 返回 {} 表示空格；否则 {occupant, kind, side}。
func _ray_occupant_at(cell: Vector2i) -> Dictionary:
	var unit := get_unit_at_cell(cell)
	if unit != null:
		var st = _state_for_card(unit)
		if st == null or st.is_dead():
			return {}
		return {"occupant": unit, "kind": "unit", "side": st.owner_side}
	if _get_blocking_piece_cells().has(cell):
		return {"occupant": null, "kind": "building", "side": &""}
	for rid in _piece_anchor_by_runtime_id:
		var entry: Dictionary = _piece_anchor_by_runtime_id[rid]
		if entry.get("anchor_cell", INVALID_GRID_CELL) == cell:
			return {"occupant": null, "kind": "piece_anchor", "side": &""}
	return {}


## Phase 27I-R0: 返回被 P05 阻挡锚点占用的格字典（所有移动查询共享）。
func _get_blocking_piece_cells() -> Dictionary:
	var result: Dictionary = {}
	for rid in _piece_anchor_by_runtime_id:
		var entry: Dictionary = _piece_anchor_by_runtime_id[rid]
		if bool(entry.get("blocks_cell", false)):
			var cell: Vector2i = entry.get("anchor_cell", INVALID_GRID_CELL)
			if cell != INVALID_GRID_CELL:
				result[cell] = true
	return result


## Phase 27I-R0: 统一清理棋子运行时状态（锚点 + 消耗记录）。
## 调用点：进墓地、建筑替换、战斗结束、无效实例清理。
func _cleanup_piece_runtime(card: CardData) -> void:
	if card == null:
		return
	var rid: int = card.get_instance_id()
	if _piece_anchor_by_runtime_id.has(rid):
		_piece_anchor_by_runtime_id.erase(rid)
	if _piece_runtime_state_by_runtime_id.has(rid):
		_piece_runtime_state_by_runtime_id.erase(rid)
	# Phase 27I-R1: 单位死亡/离场清理其战车连接反向记录（幂等；P08 自身为来源，非目标，无副作用）
	_rook_remove_target(rid)


func configure_boss_tactical_ai(profile: RefCounted) -> void:
	boss_tactical_ai_profile = profile if profile != null else BossTacticalAIProfileClass.new()
	_boss_tactical_ai_planner = BossTacticalAIPlannerClass.new(boss_tactical_ai_profile)


# ── Phase 27D: Command-Pool Authority ──

## Internal: normalize side to "player"/"boss"; returns "" for invalid
func _normalize_command_side(side: String) -> String:
	if side == "player" or side == "boss":
		return side
	return ""

## Internal: return the mutable economy dict for a side
func _economy_for_side(side: String) -> Dictionary:
	var ns := _normalize_command_side(side)
	if ns == "player":
		return _command_economy_player
	if ns == "boss":
		return _command_economy_boss
	return {}

## Internal: get the current OD layer for a side (1-5 player, 1-5 boss)
func _get_command_side_od_layer(side: String) -> int:
	var ns := _normalize_command_side(side)
	if ns == "":
		return 1
	if ns == "boss":
		if context and context.enemy:
			# Boss uses OD zone: Calm=1, Heated=2, Overdrive=3
			# Map zone to layer for base point lookup: Calm→calmLayer, etc.
			# For now, determine zone from enemy OD value
			var eod: int = context.enemy.od
			if eod >= 6:    return 3  # Overdrive
			elif eod >= 3:  return 2  # Heated
			else:           return 1  # Calm
		return 1
	# Player: use ODMode layer
	if context and context.od_mode:
		return context.od_mode.engine_layer
	return 1

## Internal: get the current Boss OD zone name
func _get_boss_od_zone() -> String:
	if context and context.enemy:
		var eod: int = context.enemy.od
		if eod >= 6:    return "Overdrive"
		elif eod >= 3:  return "Heated"
	return "Calm"

## Internal: get depth zone for surcharge/refund decisions
func _get_command_depth_zone() -> String:
	if context and context.has_method("get_depth_zone"):
		return context.get_depth_zone()
	return "Stable"

## Internal: initialize a fresh economy dict
func _make_fresh_economy() -> Dictionary:
	return {
		"current_points": 0,
		"turn_max_points": 0,
		"scheduled_next_turn": 0,
		"scheduled_next_turn_penalty": 0,
		"gross_spent": 0,
		"crossed_thresholds": [],
		"instant_refund_total": 0,
		"refund_by_trigger": {},
		"turn_open": false,
	}

## Read-only snapshot of command economy for UI/telemetry
func get_command_economy_snapshot(side: String) -> Dictionary:
	var econ := _economy_for_side(side)
	if econ.is_empty():
		return {}
	var result := econ.duplicate(true)
	result["side"] = _normalize_command_side(side)
	if result.has("refund_by_trigger"):
		result["refund_by_trigger"] = econ["refund_by_trigger"].duplicate(true)
	if result.has("crossed_thresholds"):
		result["crossed_thresholds"] = econ["crossed_thresholds"].duplicate(true)
	return result

## Query the final cost of a command, including modifiers
func get_action_command_cost(card: CardData, command_type: String, target: Variant = null) -> int:
	if tactical_command_economy_rules == null:
		return -1
	var base: int = tactical_command_economy_rules.get_base_command_cost(command_type)
	# Compute surcharge for active_skill / overdrive_breach
	var zone: String = _get_command_depth_zone()
	var surcharge: int = 0
	if command_type in ["active_skill", "overdrive_breach"]:
		surcharge = tactical_command_economy_rules.get_skill_surcharge(zone)
	# Apply unit-local modifier from UnitCombatState
	var state: Variant = _state_for_card(card)
	var unit_mod: int = 0
	var free_action: bool = false
	if state != null:
		unit_mod = state.get_command_cost_modifier() if state.has_method("get_command_cost_modifier") else 0
		free_action = state.has_free_action() if state.has_method("has_free_action") else false
	# Compute final cost
	var raw_cost: int = base + unit_mod + surcharge
	var final_cost: int = maxi(tactical_command_economy_rules.get_minimum_paid_cost(), raw_cost)
	# Free action bypasses minimum paid cost
	if free_action:
		final_cost = 0
	return final_cost

## Check if a side can afford a cost
func can_pay_command_cost(side: String, cost: int) -> bool:
	var econ := _economy_for_side(side)
	if econ.is_empty():
		return false
	return int(econ.get("current_points", 0)) >= cost

## Schedule bonus/penalty for next turn (does not affect current points)
func schedule_next_turn_command_points(side: String, amount: int, source: String) -> Dictionary:
	var ns := _normalize_command_side(side)
	if ns == "":
		return {"ok": false, "reason_code": &"invalid_side", "reason": "Invalid side"}
	var econ := _economy_for_side(ns)
	if econ.is_empty():
		return {"ok": false, "reason_code": &"no_economy", "reason": "No economy state"}
	if amount > 0:
		econ["scheduled_next_turn"] = int(econ.get("scheduled_next_turn", 0)) + amount
	elif amount < 0:
		econ["scheduled_next_turn_penalty"] = int(econ.get("scheduled_next_turn_penalty", 0)) + absi(amount)
	return {"ok": true, "reason_code": &"ok", "amount": amount, "source": source,
		"scheduled_bonus": econ.get("scheduled_next_turn", 0),
		"scheduled_penalty": econ.get("scheduled_next_turn_penalty", 0)}

## Grant an instant command-point refund (capped, blocked by Backlash)
func grant_instant_command_refund(side: String, amount: int, trigger_key: String, per_turn_cap: int = -1) -> Dictionary:
	var ns := _normalize_command_side(side)
	if ns == "":
		return {"ok": false, "reason_code": &"invalid_side", "reason": "Invalid side"}
	if amount <= 0:
		return {"ok": false, "reason_code": &"invalid_amount", "reason": "Amount must be positive"}
	var econ := _economy_for_side(ns)
	if econ.is_empty():
		return {"ok": false, "reason_code": &"no_economy", "reason": "No economy state"}
	# Backlash blocks refund
	var zone: String = _get_command_depth_zone()
	if tactical_command_economy_rules.blocks_instant_refund(zone):
		return {"ok": false, "reason_code": &"depth_refund_locked", "reason": "Backlash blocks instant refunds",
			"granted": 0}

	# Per-trigger cap
	var trigger_cap: int = per_turn_cap
	if trigger_cap < 0:
		trigger_cap = tactical_command_economy_rules.get_refund_default_per_trigger_cap()
	var refund_by_trigger: Dictionary = econ.get("refund_by_trigger", {})
	var trigger_used: int = int(refund_by_trigger.get(trigger_key, 0))
	var trigger_remaining: int = maxi(0, trigger_cap - trigger_used)
	if trigger_remaining <= 0:
		return {"ok": false, "reason_code": &"trigger_cap_reached", "reason": "Per-trigger refund cap reached",
			"trigger_key": trigger_key, "trigger_used": trigger_used, "trigger_cap": trigger_cap, "granted": 0}

	# Total-turn cap
	var total_cap: int = tactical_command_economy_rules.get_refund_total_per_turn_cap()
	var total_used: int = int(econ.get("instant_refund_total", 0))
	var total_remaining: int = maxi(0, total_cap - total_used)
	if total_remaining <= 0:
		return {"ok": false, "reason_code": &"total_cap_reached", "reason": "Total-turn refund cap reached",
			"granted": 0}

	var granted: int = mini(amount, mini(trigger_remaining, total_remaining))
	# Apply refund (current points cannot exceed total cap)
	var current: int = int(econ.get("current_points", 0))
	var max_pts: int = int(econ.get("turn_max_points", tactical_command_economy_rules.get_total_cap()))
	var new_points: int = mini(max_pts, current + granted)
	econ["current_points"] = new_points
	econ["instant_refund_total"] = total_used + granted
	refund_by_trigger[trigger_key] = trigger_used + granted
	econ["refund_by_trigger"] = refund_by_trigger
	# Refund does NOT modify gross_spent or crossed_thresholds
	return {"ok": true, "reason_code": &"ok", "granted": granted, "current_points": new_points}

## Reset command economy at turn start (computes new budget from OD snapshot)
func reset_command_economy_for_turn(side: String) -> Dictionary:
	if frontline_trial != null: frontline_trial.begin_turn(side)
	if engineering_trial != null: engineering_trial.begin_turn(side)
	var ns := _normalize_command_side(side)
	if ns == "":
		return {"ok": false, "reason_code": &"invalid_side", "reason": "Invalid side"}
	# Initialize if empty
	if ns == "player" and _command_economy_player.is_empty():
		_command_economy_player = _make_fresh_economy()
	if ns == "boss" and _command_economy_boss.is_empty():
		_command_economy_boss = _make_fresh_economy()
	var econ := _economy_for_side(ns)
	if econ.is_empty():
		return {"ok": false, "reason_code": &"no_economy", "reason": "No economy state"}
	var snapshot_before := get_command_economy_snapshot(ns)

	# Compute base from OD snapshot
	var base: int = 0
	if ns == "player":
		var layer: int = _get_command_side_od_layer("player")
		base = tactical_command_economy_rules.get_player_base_points(layer)
	else:
		var zone: String = _get_boss_od_zone()
		base = tactical_command_economy_rules.get_boss_base_points(zone)

	# Apply scheduled bonus/penalty
	var bonus: int = int(econ.get("scheduled_next_turn", 0))
	var penalty: int = int(econ.get("scheduled_next_turn_penalty", 0))
	var total: int = clampi(base + bonus - penalty, 0, tactical_command_economy_rules.get_total_cap())

	# Reset all mutable fields
	econ["current_points"] = total
	econ["turn_max_points"] = total
	econ["gross_spent"] = 0
	econ["crossed_thresholds"] = []
	econ["instant_refund_total"] = 0
	econ["refund_by_trigger"] = {}
	econ["turn_open"] = true
	# Consume scheduled values
	econ["scheduled_next_turn"] = 0
	econ["scheduled_next_turn_penalty"] = 0

	var snapshot_after := get_command_economy_snapshot(ns)
	return {"ok": true, "reason_code": &"ok", "base": base, "bonus_applied": bonus,
		"penalty_applied": penalty, "total": total, "before": snapshot_before, "after": snapshot_after}

## Close the command economy at turn end (clears unused points)
func close_command_economy_turn(side: String) -> Dictionary:
	var ns := _normalize_command_side(side)
	if ns == "":
		return {"ok": false, "reason_code": &"invalid_side", "reason": "Invalid side"}
	var econ := _economy_for_side(ns)
	if econ.is_empty():
		return {"ok": false, "reason_code": &"no_economy", "reason": "No economy state"}
	var snapshot_before := get_command_economy_snapshot(ns)
	var unused: int = int(econ.get("current_points", 0))

	if tactical_command_economy_rules.clear_unused_points():
		econ["current_points"] = 0
	econ["turn_open"] = false

	var snapshot_after := get_command_economy_snapshot(ns)
	return {"ok": true, "reason_code": &"ok", "unused_cleared": unused,
		"before": snapshot_before, "after": snapshot_after}


# ── Phase 27D: Atomic Repeated Commands ──

const REASON_INSUFFICIENT_POINTS: StringName = &"insufficient_command_points"
const REASON_NO_LEGAL_CELL: StringName = &"no_legal_cell"
const REASON_NO_LEGAL_TARGET: StringName = &"no_legal_target"
const REASON_INVALID_PATTERN: StringName = &"invalid_pattern"
const REASON_SKILL_LOCKED_BY_OD: StringName = &"skill_locked_by_od"
const REASON_SKILL_ON_COOLDOWN: StringName = &"skill_on_cooldown"
const REASON_UNIT_NOT_ON_FIELD: StringName = &"unit_not_on_field"
const REASON_DEPTH_REFUND_LOCKED: StringName = &"depth_refund_locked"
const REASON_INVALID_COMMAND: StringName = &"invalid_command_type"

# ── Phase 27I-R0: 棋子 reason codes ──
const REASON_PIECE_DISABLED: StringName = &"piece_disabled"
const REASON_PIECE_PROFILE_MISSING: StringName = &"piece_profile_missing"
const REASON_PIECE_PAYLOAD_MISSING: StringName = &"piece_payload_missing"
const REASON_PIECE_ANCHOR_REQUIRED: StringName = &"piece_anchor_required"
const REASON_PIECE_ANCHOR_INVALID: StringName = &"piece_anchor_invalid"
const REASON_PIECE_TARGET_INVALID: StringName = &"piece_target_invalid"
const REASON_PIECE_NO_LEGAL_CELL: StringName = &"piece_no_legal_cell"
const REASON_PIECE_ENHANCE_NOT_APPLICABLE: StringName = &"piece_enhance_not_applicable"
const REASON_PIECE_PAYMENT_CHOICE_REQUIRED: StringName = &"piece_payment_choice_required"
const REASON_PIECE_COMMAND_INSUFFICIENT: StringName = &"piece_command_insufficient"
const REASON_PIECE_DEPTH_ZONE_REQUIRED: StringName = &"piece_depth_zone_required"
const REASON_PIECE_DEPTH_AT_CAP: StringName = &"piece_depth_at_cap"
# Phase 27I-R0-R: P02 强化参数显式校验
const REASON_PIECE_FOLLOWUP_FACING_REQUIRED: StringName = &"piece_followup_facing_required"
const REASON_PIECE_FOLLOWUP_FACING_INVALID: StringName = &"piece_followup_facing_invalid"
const REASON_PIECE_SECONDARY_TARGET_REQUIRED: StringName = &"piece_secondary_target_required"
const REASON_PIECE_SECONDARY_TARGET_INVALID: StringName = &"piece_secondary_target_invalid"


## Unified tactical + economy status query (read-only)
## Phase 27I-R0: 兼容扩展 payload —— 当棋子强化以指令支付时并入权威费用快照。
func get_unit_command_status(card: CardData, command_type: String, target: Variant = null, payload: Dictionary = {}) -> Dictionary:
	var base: Dictionary = {
		"ok": false,
		"reason_code": REASON_STATE_MISSING,
		"cost": 0,
		"current_points": 0,
		"remaining_points": 0,
		"depth_before": 0,
		"depth_after": 0,
		"crossed_depth_thresholds": [],
		"legal_cells": [],
		"legal_targets": [],
	}
	if card == null or tactical_command_economy_rules == null:
		base.reason_code = REASON_CARD_MISSING
		return base
	var state: Variant = _state_for_card(card)
	if state == null:
		return base
	if state.is_dead():
		base.reason_code = REASON_STATE_MISSING
		return base
	var atk_cell: Vector2i = get_unit_cell(card)
	if atk_cell == INVALID_GRID_CELL:
		base.reason_code = REASON_NOT_ON_BOARD
		return base
	var owner_side: StringName = state.owner_side
	var ns: String = "player" if owner_side == &"player" else "boss"

	# Summoning sickness
	if command_type in ["move", "attack", "special_move"] and state.summoned_this_turn:
		base.reason_code = REASON_SUMMONING_SICKNESS
		return base

	# Compute cost
	var cost: int = get_action_command_cost(card, command_type, target)
	# Phase 27I-R0: 棋子强化以指令支付时，并入权威费用快照
	if bool(payload.get("piece_enhanced", false)) and str(payload.get("piece_payment_mode", "")) == str(PIECE_PAY_COMMAND):
		cost += card_piece_traits.get_enhance_command_cost()
	base.cost = cost

	# Economy snapshot
	var econ: Dictionary = get_command_economy_snapshot(ns)
	base.current_points = int(econ.get("current_points", 0))
	base.remaining_points = base.current_points - cost

	# Depth
	if context:
		base.depth_before = context.turn_depth

	# Command-specific legality
	match command_type:
		"move":
			var assignment: Dictionary = get_garrison_state_for_unit(card)
			if StringName(str(assignment.get("state", &""))) in [&"active", &"displaced_pending_exit"]:
				base.reason_code = &"garrison_forced_move_blocked"
				base["reason_text"] = "驻军需先选择撤离，再移动"
				return base
			var move_source := MOVE_BOSS_AI if owner_side == &"boss" else MOVE_SELF
			var move_cells: Array = get_legal_move_cells(card, move_source)
			base.legal_cells = move_cells
			if move_cells.is_empty():
				base.reason_code = REASON_NO_LEGAL_CELL
				return base
		"attack":
			var siege_plan: Dictionary = {}
			if target is Dictionary:
				siege_plan = get_siege_attack_status(card, target)
			elif target is CardData:
				siege_plan = _get_covered_unit_siege_status(card, target)
			if payload.has("expected_siege_status") and siege_plan.is_empty():
				base.reason_code = &"siege_preview_stale"
				return base
			if not siege_plan.is_empty():
				if not bool(siege_plan.get("ok", false)):
					base.reason_code = siege_plan.reason_code
					return base
				if payload.has("expected_siege_status") and payload.expected_siege_status != siege_plan:
					base.reason_code = &"siege_preview_stale"
					return base
				base["siege_plan"] = siege_plan.duplicate(true)
				base.legal_targets = [siege_plan.requested_target.duplicate(true)]
				base.ok = can_pay_command_cost(ns, cost)
				base.reason_code = REASON_OK if base.ok else REASON_INSUFFICIENT_POINTS
				return base
			# The old list is Array[CardData]; copy into an untyped menu view before
			# adding validated structure references. Do not widen the old API.
			var targets: Array = []
			targets.append_array(get_legal_attack_targets(card))
			if target == null:
				targets.append_array(get_legal_siege_targets(card))
			base.legal_targets = targets
			if targets.is_empty():
				var core_query: Dictionary = (
					can_monster_attack_player_core(card)
					if owner_side == &"boss"
					else can_monster_attack_boss(card)
				)
				var core_ok: bool = bool(core_query.get("ok", false))
				if not core_ok:
					base.reason_code = REASON_NO_LEGAL_TARGET
					return base
		"turn":
			var turn_status: Dictionary = get_unit_turn_status(card)
			if not bool(turn_status.get("ok", false)):
				base.reason_code = &"turn_blocked"
				return base
		"defend":
			var turn_status2: Dictionary = get_unit_turn_status(card)
			if not bool(turn_status2.get("ok", false)):
				base.reason_code = &"turn_blocked"
				return base
		"attack_core":
			var core_status: Dictionary = (
				can_monster_attack_player_core(card)
				if owner_side == &"boss"
				else can_monster_attack_boss(card)
			)
			if not bool(core_status.get("ok", false)):
				base.reason_code = REASON_NO_LEGAL_TARGET
				return base
		"overdrive_breach":
			var od_status: Dictionary = get_overdrive_core_breach_status(card)
			if not bool(od_status.get("ok", false)):
				base.reason_code = REASON_NO_LEGAL_TARGET
				return base
		_:
			base.reason_code = REASON_INVALID_COMMAND
			return base

	# Affordability
	if not can_pay_command_cost(ns, cost):
		base.reason_code = REASON_INSUFFICIENT_POINTS
		return base

	base.ok = true
	base.reason_code = REASON_OK
	return base


## Atomic command execution with rollback
func execute_unit_command(card: CardData, command_type: String, target: Variant = null, payload: Dictionary = {}) -> Dictionary:
	# PHASE63_BEGIN_COMMAND_GUARD
	var owns: bool=_core_damage_heat_trial!=null and _core_damage_heat_trial.profile in ["first-core-heat","ascended-core-heat","ascended-delayed-core-heat"]
	if owns and _core_damage_heat_resolving:return {"ok":false,"reason_code":&"core_damage_heat_busy"}
	if owns:_core_damage_heat_resolving=true
	var committed: Dictionary=_phase63_execute_unit_command(card,command_type,target,payload)
	if owns:_core_damage_heat_resolving=false
	return committed
func _phase63_execute_unit_command(card: CardData, command_type: String, target: Variant = null, payload: Dictionary = {}) -> Dictionary:
	# PHASE63_END_COMMAND_GUARD
	if _siege_command_in_progress:
		return {"ok": false, "reason_code": &"siege_transaction_in_progress", "reason": "攻城行动正在结算"}
	var result: Dictionary = {
		"ok": false,
		"reason_code": REASON_STATE_MISSING,
		"cost": 0,
		"current_points": 0,
		"remaining_points": 0,
		"depth_before": 0,
		"depth_after": 0,
		"crossed_depth_thresholds": [],
		"legal_cells": [],
		"legal_targets": [],
	}

	# 1. Normalize side
	if card == null or tactical_command_economy_rules == null:
		result.reason_code = REASON_CARD_MISSING
		return result
	var state: Variant = _state_for_card(card)
	if state == null:
		return result
	var owner_side: StringName = state.owner_side
	var ns: String = "player" if owner_side == &"player" else "boss"

	# 2. Set bypass before any queries (economy-level legality replaces legacy caps)
	pass # R5: legacy bypass removed

	# 3. Query full status (legality + cost + affordability)
	var status: Dictionary = get_unit_command_status(card, command_type, target, payload)
	if not bool(status.get("ok", false)):
		for key in ["reason_code", "legal_cells", "legal_targets", "cost", "current_points"]:
			if status.has(key):
				result[key] = status[key]
		return result

	var cost: int = int(status.get("cost", 0))
	result.cost = cost
	result.legal_cells = status.get("legal_cells", [])
	result.legal_targets = status.get("legal_targets", [])
	var siege_plan: Dictionary = status.get("siege_plan", {})
	var siege_command: bool = not siege_plan.is_empty()
	var depth_notifications: Array[Dictionary] = []

	# 3. Capture rollback evidence
	var econ: Dictionary = _economy_for_side(ns)
	var points_before: int = int(econ.get("current_points", 0))
	var gross_before: int = int(econ.get("gross_spent", 0))
	var crossed_before: Array = econ.get("crossed_thresholds", []).duplicate(true)
	var cell_before: Vector2i = get_unit_cell(card)
	var depth_before: int = 0
	if context:
		depth_before = context.turn_depth
	result.depth_before = depth_before

	# 4. Debit tentatively
	if siege_command:
		_siege_command_in_progress = true
	econ["current_points"] = points_before - cost

	# 5. Execute through existing resolver
	var resolver_result: Dictionary = {"ok": false, "reason": "unknown command"}
	var rollback_needed: bool = false

	match command_type:
		"move":
			if target is Vector2i:
				var move_source := MOVE_BOSS_AI if owner_side == &"boss" else MOVE_SELF
				resolver_result = move_unit_to_cell(card, target, move_source)
			else:
				rollback_needed = true
		"attack":
			if siege_command:
				resolver_result = _resolve_siege_attack(card, siege_plan, payload)
			elif target == null or target is CardData:
				resolver_result = resolve_monster_attack(card, target as CardData)
			else:
				rollback_needed = true
		"attack_core":
			if owner_side == &"boss":
				resolver_result = resolve_monster_attack_player_core(card)
			else:
				resolver_result = resolve_monster_attack(card, null)
		"turn":
			resolver_result = turn_unit_for_rear_defense(card)
		"defend":
			resolver_result = turn_unit_for_rear_defense(card)
		"overdrive_breach":
			resolver_result = resolve_overdrive_core_breach(card)
		_:
			rollback_needed = true

	pass # R5: legacy bypass removed

	if rollback_needed or not bool(resolver_result.get("ok", false)):
		# 6. Rollback
		econ["current_points"] = points_before
		if OS.is_debug_build():
			print("[UNIT_COMMAND_REJECTED] ", JSON.stringify({
				"turn": context.turn_count if context != null else -1,
				"side": ns, "card_id": card.card_id, "command": command_type,
				"from_cell": cell_before, "target": str(target),
				"reason_code": str(resolver_result.get("reason_code", "")),
				"reason": str(resolver_result.get("reason", "")),
				"points_before": points_before, "points_after": econ["current_points"],
				"cell_after": get_unit_cell(card), "rollback_needed": rollback_needed,
			}))
		result.reason_code = &"resolver_failed"
		if resolver_result.has("reason"):
			result["reason"] = resolver_result.get("reason")
		if siege_command:
			_siege_command_in_progress = false
		return result

	# 7. Commit: update gross spending and cross thresholds
	var gross_after: int = gross_before + cost
	econ["gross_spent"] = gross_after
	result.current_points = int(econ.get("current_points", 0))
	result.remaining_points = result.current_points

	# 8. Check Depth thresholds
	var thresholds: Array[int] = tactical_command_economy_rules.get_depth_thresholds()
	var newly_crossed: Array[int] = []
	for th in thresholds:
		if th > gross_before and th <= gross_after and not crossed_before.has(th):
			newly_crossed.append(th)
	if not newly_crossed.is_empty():
		var current_crossed: Array = econ.get("crossed_thresholds", [])
		for th in newly_crossed:
			if not current_crossed.has(th):
				current_crossed.append(th)
				if context and context.has_method("add_depth_pressure"):
					depth_notifications.append_array(context.add_depth_pressure(tactical_command_economy_rules.get_depth_per_threshold(), "command_gross_%d" % th, siege_command))
		econ["crossed_thresholds"] = current_crossed
	result.crossed_depth_thresholds = newly_crossed

	# 9. Commit: consume free action if used
	if cost == 0 and state.has_method("consume_free_action"):
		state.consume_free_action()
	# Consume temporary discount
	if state.has_method("set_command_cost_modifier") and state.has_method("get_command_cost_modifier"):
		if state.get_command_cost_modifier() < 0:
			state.set_command_cost_modifier(0)

	# 10. Telemetry: each resolver handles its own counters (move, mark_attacked, turn, breach).
	# execute_unit_command must NOT double-increment.

	state.last_action = StringName(command_type)

	# 11. Emit state
	_emit_unit_state(card)

	# 12. Depth after
	# Phase 27I-R0-R: Depth 支付统一由 execute_card_piece_action 在棋子行动成功后提交一次。
	# execute_unit_command 只读取深度快照，不再在此提交（避免普通指令与棋子强化双扣）。
	var piece_enhanced: bool = bool(payload.get("piece_enhanced", false))
	var piece_payment_mode: StringName = StringName(str(payload.get("piece_payment_mode", "")))
	var depth_after: int = 0
	if context:
		depth_after = context.turn_depth
	result.depth_after = depth_after

	result.ok = true
	result.reason_code = REASON_OK
	# Phase 27I-R0: 转发棋子支付信息供调用者展示
	result["piece_enhanced"] = piece_enhanced
	result["piece_payment_mode"] = piece_payment_mode
	result["piece_command_cost"] = int(card_piece_traits.get_enhance_command_cost()) if (piece_enhanced and piece_payment_mode == PIECE_PAY_COMMAND) else 0
	# Phase 27D-R4: Forward ALL resolver result fields for presenter/UI compatibility.
	# The 'result' key carries the combat result type (target_destroyed, trade, hit_core, etc.)
	# while 'resolver_result' is kept for explicit new-code access.
	if resolver_result.has("result"):
		result["result"] = resolver_result.get("result")  # backward-compat for _handle_attack_result
		result["resolver_result"] = resolver_result.get("result")
	# Forward all resolver keys except metadata keys already handled
	var _skip_forward: Array[String] = ["ok", "reason", "result"]
	for key in resolver_result.keys():
		if not key in _skip_forward:
			result[key] = resolver_result[key]
	if siege_command:
		publish_structure_damage_notifications(resolver_result.get("structure_fact", {}))
		context.publish_depth_notifications(depth_notifications)
		_siege_command_in_progress = false
	if _ritual_trial != null and ns == "player" and command_type in ["attack", "attack_core", "overdrive_breach"]:
		_ritual_trial.record_attack(card.get_instance_id(), card.get_display_name())
	# PHASE63_BEGIN_COMMAND_AFTER
	if _core_damage_heat_trial!=null and ns=="player" and str(resolver_result.get("result",""))=="hit_core":
		result["core_damage_heat"]=_core_damage_heat_trial.commit_paid(self,card,"attack_core",maxi(0,int(resolver_result.get("actual_hp_loss",0))),int(result.get("cost",0))) if _core_damage_heat_trial.profile=="ascended-delayed-core-heat" else _core_damage_heat_trial.commit(self,card,"attack_core",maxi(0,int(resolver_result.get("actual_hp_loss",0))))
	# PHASE63_END_COMMAND_AFTER
	return result


func get_unit_tactical_pattern(card: CardData) -> StringName:
	if card == null:
		return tactical_pattern_snapshot.default_pattern_id
	return tactical_pattern_snapshot.get_pattern_id(StringName(str(card.card_id)))


## Returns plain-data candidates assembled exclusively from current authoritative
## command queries. The planner may score this data but may not mutate battle state.
func _is_battle_terminal() -> bool:
	return context != null and ((is_instance_valid(context.player) and context.player.hp <= 0) or (is_instance_valid(context.enemy) and context.enemy.hp <= 0))


func get_boss_tactical_action_candidates() -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	if context == null or context.enemy == null:
		return candidates
	if _is_battle_terminal():
		return candidates
	var economy := get_command_economy_snapshot("boss")
	var current_points: int = int(economy.get("current_points", 0))
	for raw_card in context.enemy.field:
		var card := raw_card as CardData
		if card == null or not is_instance_valid(card):
			continue
		var state: Variant = _state_for_card(card)
		if state == null or state.is_dead():
			continue
		var actor_id: int = card.get_instance_id()
		var origin: Vector2i = get_unit_cell(card)

		var attack_status := get_unit_command_status(card, "attack")
		var attack_cost: int = int(attack_status.get("cost", get_action_command_cost(card, "attack")))
		for raw_target in attack_status.get("legal_targets", []):
			var target := raw_target as CardData
			if target == null or not is_instance_valid(target):
				continue
			var target_state: Variant = _state_for_card(target)
			if target_state == null or target_state.is_dead():
				continue
			var damage: int = get_unit_effective_attack(card)
			candidates.append({
				"command_id": "attack",
				"actor_runtime_id": actor_id,
				"target_runtime_id": target.get_instance_id(),
				"target_cell": get_unit_cell(target),
				"target_kind": "player_unit",
				"authoritative_cost": attack_cost,
				"legal": bool(attack_status.get("ok", false)) and attack_cost <= current_points,
				"is_kill": damage >= int(target_state.current_hp),
				"is_lethal": false,
				"threat_value": maxi(0, int(target.unit_power)),
				"reason_code": str(attack_status.get("reason_code", "ok")),
			})

		var core_status := get_unit_command_status(card, "attack_core")
		var core_cost: int = int(core_status.get("cost", get_action_command_cost(card, "attack_core")))
		if bool(core_status.get("ok", false)):
			candidates.append({
				"command_id": "attack_core",
				"actor_runtime_id": actor_id,
				"target_runtime_id": 0,
				"target_cell": INVALID_GRID_CELL,
				"target_kind": "player_core",
				"authoritative_cost": core_cost,
				"legal": core_cost <= current_points,
				"is_kill": false,
				"is_lethal": context.player != null and get_unit_effective_attack(card) >= context.player.hp,
				"threat_value": 0,
				"reason_code": str(core_status.get("reason_code", "ok")),
			})

		var move_status := get_unit_command_status(card, "move")
		var move_cost: int = int(move_status.get("cost", get_action_command_cost(card, "move")))
		for raw_cell in move_status.get("legal_cells", []):
			if not raw_cell is Vector2i:
				continue
			var cell: Vector2i = raw_cell
			candidates.append({
				"command_id": "move",
				"actor_runtime_id": actor_id,
				"target_runtime_id": 0,
				"target_cell": cell,
				"target_kind": "cell",
				"authoritative_cost": move_cost,
				"legal": bool(move_status.get("ok", false)) and move_cost <= current_points,
				"advances": origin != INVALID_GRID_CELL and cell.y > origin.y,
				"retreats": origin != INVALID_GRID_CELL and cell.y < origin.y,
				"reason_code": str(move_status.get("reason_code", "ok")),
			})

		var turn_status := get_unit_command_status(card, "turn")
		var turn_cost: int = int(turn_status.get("cost", get_action_command_cost(card, "turn")))
		if bool(turn_status.get("ok", false)):
			candidates.append({
				"command_id": "turn",
				"actor_runtime_id": actor_id,
				"target_runtime_id": 0,
				"target_cell": origin,
				"target_kind": "self",
				"authoritative_cost": turn_cost,
				"legal": turn_cost <= current_points,
				"protects_core": _boss_turn_would_face_a_threat(card),
				"reason_code": str(turn_status.get("reason_code", "ok")),
			})
	# PHASE58_BEGIN_STABLE_KEYS
	for candidate: Dictionary in candidates:
		var actor: CardData=_find_field_card_by_runtime_id(int(candidate.actor_runtime_id),&"boss")
		var target: CardData=_find_field_card_by_runtime_id(int(candidate.get("target_runtime_id",0)),&"player")
		candidate["actor_stable_key"]="boss|%s|%s"%[actor.card_id,get_unit_cell(actor)] if actor!=null else ""
		candidate["target_stable_key"]="player|%s|%s"%[target.card_id,get_unit_cell(target)] if target!=null else ""
	# PHASE58_END_STABLE_KEYS
	return candidates


func get_boss_tactical_ai_snapshot() -> Dictionary:
	var economy := get_command_economy_snapshot("boss")
	return {
		"zone": _get_boss_od_zone(),
		"current_points": int(economy.get("current_points", 0)),
		"turn_max_points": int(economy.get("turn_max_points", 0)),
		"gross_spent": int(economy.get("gross_spent", 0)),
		"depth": context.turn_depth if context != null else 0,
		"candidates": get_boss_tactical_action_candidates(),
	}


## Phase 27F-R1-R: stable candidate fingerprint for exclusion tracking.
func get_boss_tactical_candidate_fingerprint(candidate: Dictionary) -> String:
	return "%s|%s|%s|%s|%s" % [
		str(candidate.get("command_id", "")),
		str(candidate.get("actor_runtime_id", 0)),
		str(candidate.get("target_runtime_id", 0)),
		str(candidate.get("target_cell", INVALID_GRID_CELL)),
		str(candidate.get("target_kind", "")),
	]


func choose_boss_tactical_action(seed: int = 0, excluded_fingerprints: Dictionary = {}) -> Dictionary:
	if _boss_tactical_ai_planner == null:
		return {"command_id": "pass", "reason_code": "planner_missing", "score": 0}
	var snapshot := get_boss_tactical_ai_snapshot()
	if not excluded_fingerprints.is_empty():
		var filtered: Array[Dictionary] = []
		for raw in snapshot.get("candidates", []):
			var cand := raw as Dictionary
			if cand.is_empty():
				continue
			var fp: String = get_boss_tactical_candidate_fingerprint(cand)
			if not excluded_fingerprints.has(fp):
				filtered.append(cand)
		snapshot["candidates"] = filtered
	return _boss_tactical_ai_planner.choose_action(snapshot, seed)


## Re-resolves runtime ids immediately before execution, so stale/dead targets
## fail through the existing atomic transaction without consuming points.
var frontline_trial: RefCounted = null
var core_siege_trial: RefCounted = null
var reaction_trial: RefCounted = null

func execute_boss_tactical_candidate(candidate: Dictionary) -> Dictionary:
	# Revalidate cached choices after the preceding native action completes.
	if _is_battle_terminal():
		return {"ok": false, "reason_code": &"battle_ended", "cost": 0}
	var command_id: String = str(candidate.get("command_id", "pass"))
	if command_id == "pass":
		return {"ok": true, "reason_code": "pass", "cost": 0}
	var actor := _find_field_card_by_runtime_id(int(candidate.get("actor_runtime_id", 0)), &"boss")
	if actor == null:
		return {"ok": false, "reason_code": "stale_actor", "cost": 0}
	match command_id:
		"move":
			return execute_unit_command(actor, "move", candidate.get("target_cell", INVALID_GRID_CELL))
		"attack":
			var target := _find_field_card_by_runtime_id(int(candidate.get("target_runtime_id", 0)), &"player")
			if target == null:
				return {"ok": false, "reason_code": "stale_target", "cost": 0}
			return execute_unit_command(actor, "attack", target)
		"attack_core":
			return execute_unit_command(actor, "attack_core", null)
		"turn":
			return execute_unit_command(actor, "turn")
	return {"ok": false, "reason_code": "unsupported_candidate", "cost": 0}


func _find_field_card_by_runtime_id(runtime_id: int, owner_side: StringName) -> CardData:
	if runtime_id <= 0:
		return null
	for raw_card in _field_for_owner(owner_side):
		var card := raw_card as CardData
		if card != null and is_instance_valid(card) and card.get_instance_id() == runtime_id:
			return card
	return null


func _boss_turn_would_face_a_threat(card: CardData) -> bool:
	var origin := get_unit_cell(card)
	if origin == INVALID_GRID_CELL:
		return false
	for raw_player in _field_for_owner(&"player"):
		var player_card := raw_player as CardData
		if player_card == null:
			continue
		var player_cell := get_unit_cell(player_card)
		if player_cell != INVALID_GRID_CELL and player_cell.y > origin.y:
			return true
	return false

# ===== Phase 25E: unit_combat_states 唯一可变 HP/攻击状态注册表 =====
# key = card.get_instance_id() (int), value = UnitCombatState
var unit_combat_states: Dictionary = {}
var _monster_hero_skills: RefCounted = null  # Phase 27E: MonsterHeroSkillSnapshot

# ===== Phase 26E: Five-Lane Movement =====
var unit_lane_by_runtime_id: Dictionary = {}

const MOVE_OK: StringName = &"ok"
const MOVE_SELF: StringName = &"self"
const MOVE_CORE_REDEPLOY: StringName = &"core_redeploy"
const MOVE_BOSS_AI: StringName = &"boss_ai"
const MOVE_FORCED_EFFECT: StringName = &"forced_effect"

const MOVE_REASON_MOVEMENT_DISABLED: StringName = &"movement_disabled"
const MOVE_REASON_UNIT_NOT_REGISTERED: StringName = &"unit_not_registered"
const MOVE_REASON_UNIT_NOT_ON_FRONT: StringName = &"unit_not_on_front_field"
const MOVE_REASON_UNIT_DEAD: StringName = &"unit_dead"
const MOVE_REASON_SUMMONING_SICKNESS: StringName = &"summoning_sickness"
const MOVE_REASON_ACTION_ALREADY_USED: StringName = &"action_already_used"
const MOVE_REASON_ANCHOR: StringName = &"movement_pattern_anchor"
const MOVE_REASON_TARGET_OOB: StringName = &"target_lane_out_of_range"
const MOVE_REASON_TARGET_OCCUPIED: StringName = &"target_lane_occupied"
const MOVE_REASON_PATH_BLOCKED: StringName = &"path_blocked"
const MOVE_REASON_PATTERN_MISMATCH: StringName = &"pattern_mismatch"
const MOVE_REASON_HEIGHT_GAP: StringName = &"height_gap_too_large"
const MOVE_REASON_NOT_PLAYER_TURN: StringName = &"not_player_turn"
const MOVE_REASON_BATTLE_ENDED: StringName = &"battle_ended"

# Phase 27B: cell-authoritative reason codes
const REASON_OK: StringName = &"ok"
const REASON_CARD_MISSING: StringName = &"card_missing"
const REASON_STATE_MISSING: StringName = &"state_missing"
const REASON_SUMMONING_SICKNESS: StringName = &"summoning_sickness"
const REASON_ACTION_SPENT: StringName = &"action_spent"
const REASON_OUT_OF_BOUNDS: StringName = &"out_of_bounds"
const REASON_OCCUPIED: StringName = &"occupied"
const REASON_EMPTY_TARGET: StringName = &"empty_target"
const REASON_FRIENDLY_TARGET: StringName = &"friendly_target"
const REASON_OUT_OF_PATTERN: StringName = &"out_of_pattern"
const REASON_NOT_ENEMY_TERRITORY: StringName = &"not_enemy_territory"
const REASON_FRONT_ARC_BLOCKED: StringName = &"front_arc_blocked"
const REASON_TARGET_MISSING: StringName = &"target_missing"

# Phase 27C: core breach / facing / rear defense reason codes
const REASON_NOT_BREACH_RANK: StringName = &"not_breach_rank"
const REASON_NOT_THREAT_RANK: StringName = &"not_threat_rank"
const REASON_FACING_AWAY_FROM_CORE: StringName = &"facing_away_from_core"
const REASON_GUARD_INTERCEPTED: StringName = &"guard_intercepted"
const REASON_INSUFFICIENT_CHARGE: StringName = &"insufficient_charge"
const REASON_OVERDRIVE_BREACH_USED: StringName = &"overdrive_breach_used"
const REASON_ENGAGED: StringName = &"engaged"
const REASON_INVALID_FACING: StringName = &"invalid_facing"
const REASON_ALREADY_FACING: StringName = &"already_facing"
const REASON_NOT_ON_BOARD: StringName = &"not_on_board"
const REASON_SELECTION_BUSY: StringName = &"selection_busy"

# ===== Phase 26C: OD Core Commands =====
var od_core_command_rules: RefCounted
var _core_command_used_this_player_turn: bool = false
# PHASE55_BEGIN_LOCK
var _core_command_resolving := false
# PHASE55_END_LOCK
var _core_command_player_turn_open: bool = false

const CORE_OK: StringName = &""
const CORE_NOT_PLAYER_TURN: StringName = &"not_player_turn"
const CORE_ALREADY_USED: StringName = &"already_used_this_turn"
const CORE_INSUFFICIENT_CHARGE: StringName = &"insufficient_charge"
const CORE_BACKLASH_RESTRICTED: StringName = &"backlash_restricted"
const CORE_INVALID_TARGET: StringName = &"invalid_target"
const CORE_TARGET_ALREADY_ATTACKED: StringName = &"target_already_attacked"
const CORE_DEPTH_ALREADY_ZERO: StringName = &"depth_already_zero"
const CORE_UNKNOWN_COMMAND: StringName = &"unknown_command"

## Phase 25D: 注入规则快照（null 时使用 safe default）
func configure_monster_combat_rules(snapshot) -> void:
	monster_combat_rules = snapshot if snapshot != null else MonsterCombatRuleSnapshotClass.default_snapshot()

# ── Phase 25E: 辅助函数 ──

func _normalize_owner_side(owner_side: StringName) -> StringName:
	return &"boss" if owner_side in [&"boss", &"enemy"] else &"player"

func _field_for_owner(owner_side: StringName) -> Array:
	if context == null:
		return []
	var side := _normalize_owner_side(owner_side)
	if side == &"boss" and context.enemy != null:
		return context.enemy.field
	if side == &"player" and context.player != null:
		return context.player.field
	return []


func _opposing_field_for_owner(owner_side: StringName) -> Array:
	var side := _normalize_owner_side(owner_side)
	return _field_for_owner(&"player" if side == &"boss" else &"boss")

func _detect_unit_owner_side(card: CardData) -> StringName:
	if card == null or context == null:
		return &""
	if context.player != null and card in context.player.field:
		return &"player"
	if context.enemy != null and card in context.enemy.field:
		return &"boss"
	return &""

func _is_valid_front_field_unit(card: CardData, owner_side: StringName) -> bool:
	if card == null or not card.is_front_row_card():
		return false
	return card in _field_for_owner(owner_side)

func _state_for_card(card: CardData):
	if card == null:
		return null
	return unit_combat_states.get(card.get_instance_id())

func _emit_unit_state(card: CardData) -> void:
	var state = _state_for_card(card)
	if state != null:
		unit_combat_state_changed.emit(card, state.snapshot(monster_combat_rules.max_attacks_per_turn, monster_combat_rules.actions_per_turn))

func can_play_card(card: CardData) -> bool:
	return bool(get_card_play_status(card).get("ok", false))


## Phase 5E-1: 统一可出牌状态，供 UI / 点击 / 拖拽共用
## Replacement preflight may conditionally reuse both the selected building slot
## and its back-row slot. Ordinary play keeps both limits unchanged.
func get_card_play_status(card: CardData, ignore_active_building_limit: bool = false, ignore_back_row_limit: bool = false) -> Dictionary:
	if context == null:
		return {"ok": false, "reason": "战斗未初始化"}
	if card == null:
		return {"ok": false, "reason": "卡牌无效"}
	var steam_status := _steam_card_play_status(card)
	if not steam_status.get("ok",false): return steam_status
	var basic_status := _basic_card_play_status(card)
	if not basic_status.get("ok",false): return basic_status
	var engineering_status := _engineering_card_play_status(card)
	if not engineering_status.get("ok",false): return engineering_status
	if reaction_trial != null and reaction_trial.owns(card) and reaction_trial.deployed_count() >= 2:
		return {"ok": false, "reason": "伏击已布置 2/2，触发后可再布置"}

	var od_mode: ODMode = context.od_mode
	var player: Player = context.player

	if card.require_od > od_mode.current_od:
		return {"ok": false, "reason": "OD:%d/%d" % [od_mode.current_od, card.require_od]}
	if card.require_load > od_mode.load:
		return {"ok": false, "reason": "Load:%d/%d" % [od_mode.load, card.require_load]}
	if card.require_hp_cost > player.hp:
		return {"ok": false, "reason": "HP不足"}
	if card.require_awaken and not player.is_awakened:
		return {"ok": false, "reason": "需要觉醒"}

	# Phase 23B-R2: Abyss Lock 优先于建筑容量（先检查 Abyss 再检查容量）
	if context and context.has_method("is_abyss_locked") and context.is_abyss_locked():
		if card.archetype_role != CardData.ArchetypeRole.CONTROL:
			return {"ok": false, "reason": "Abyss Lock: only CONTROL. Use Cooldown/Heat Sink"}

	# Phase 10B: 场地容量检查 — 使用 OD 层槽位限制
	if card.is_front_row_card():
		var slot_limit: int = od_mode.get_front_slot_limit() if od_mode else 5
		if player.field.size() >= slot_limit:
			return {"ok": false, "reason": "前场已满 (OD层仅%d个槽位)" % slot_limit}
	if card.is_back_row_card() and player.traps.size() >= MAX_TRAP_SIZE and not ignore_back_row_limit:
		return {"ok": false, "reason": "后场已满"}

	# Phase 5E-2: 建筑特殊限制（不影响普通 COUNTER 后场）
	if card.is_building_card():
		# building_unique: 同名建筑场上只能存在 1 张
		if card.building_unique and context.has_building_on_field(card.card_name):
			return {"ok": false, "reason": "建筑 %s 已存在于场上" % card.card_name}
		# 每局建筑发动次数限制（根据 building_tier）
		var per_battle_limit := _get_building_per_battle_limit(card.building_tier)
		if frontline_trial != null and card.card_id in ["P05", "P08"]:
			per_battle_limit = maxi(2, per_battle_limit)
		var played_count := context.get_building_play_count(card.card_name)
		if played_count >= per_battle_limit:
			return {"ok": false, "reason": "本局建筑 %s 发动次数已达上限（%d/%d）" % [card.card_name, played_count, per_battle_limit]}
		# active_building_limit: 场上最多同时存在 2 个建筑
		# Phase 23B-R2: 当 ignore_active_building_limit=true 时跳过此门（替换预检用）
		var active_building_count := context.count_active_buildings()
		if active_building_count >= context.ACTIVE_BUILDING_LIMIT and not ignore_active_building_limit:
			return {"ok": false, "reason": "建筑槽已满（最多%d个建筑）" % context.ACTIVE_BUILDING_LIMIT, "needs_replacement": true}

	var entry_status := _check_entry_condition(card, player, od_mode)
	if not bool(entry_status.get("ok", true)):
		return entry_status

	return {"ok": true, "reason": ""}


func _check_entry_condition(card: CardData, player: Player, od_mode: ODMode) -> Dictionary:
	var condition_type := card.entry_condition_type
	if condition_type == "":
		return {"ok": true, "reason": ""}

	var needed := maxi(0, card.entry_condition_value)
	match condition_type:
		"od_at_least":
			if od_mode.current_od < needed:
				return {"ok": false, "reason": "需要 OD %d（当前 %d）" % [needed, od_mode.current_od]}
		"series_played":
			var count := 0
			if context and context.has_method("get_series_played_count"):
				count = context.get_series_played_count(card.series_id)
			if count < needed:
				return {"ok": false, "reason": "需要打出 %d 张 %s 系列卡（已打 %d）" % [needed, card.series_id, count]}
		"field_count":
			if player.field.size() < needed:
				return {"ok": false, "reason": "需要前场 %d 个怪兽（当前 %d）" % [needed, player.field.size()]}
		"depth_at_least":
			if context and context.turn_depth < needed:
				return {"ok": false, "reason": "需要 Depth >= %d（当前 %d）" % [needed, context.turn_depth]}
	return {"ok": true, "reason": ""}


func _get_building_per_battle_limit(tier: int) -> int:
	match tier:
		1: return 3
		2: return 2
		3: return 1
		_: return 1


# 唯一初始化入口
func init(_context: BattleContext):
	context = _context
	_heat_cycle_rng.randomize()

	field_system = FieldSystem.new()
	add_child(field_system)

	graveyard_system = GraveyardSystem.new()
	add_child(graveyard_system)

	hub = SystemHub.new()
	hub.init(context)
	add_child(hub)

	# Phase 24B: Install authoritative draw callback
	if context.player:
		context.player.draw_request_callback = Callable(self, "draw_player_cards")


func build_heat_source_descriptor(source_kind: StringName, source_id: StringName, card: CardData = null, extra: Dictionary = {}) -> Dictionary:
	var card_id := str(card.card_id) if card != null else str(extra.get("card_id", ""))
	var descriptor: Dictionary = {}
	if context != null and context.has_method("get_heat_source_descriptor"):
		if card != null and source_kind in [&"card_effect", &"card_bonus"]:
			descriptor = context.get_heat_source_descriptor(&"card_base", StringName("base_card:%s" % card_id), card_id)
		else:
			descriptor = context.get_heat_source_descriptor(source_kind, source_id, card_id)
	# Experimental card families are declared only in the enabled package;
	# the global catalog's strict positive-Heat validation stays unchanged.
	if steam_package_trial != null and card_id == "S01" and source_kind == &"card_base":
		descriptor.merge({"classified":true,"source_family":&"ignition_cards","source_policy":&"bounded_existing","presentation_tier":&"micro"},true)
	descriptor["source_kind"] = source_kind
	descriptor["source_id"] = source_id
	if not card_id.is_empty():
		descriptor["card_id"] = card_id
	for key in extra:
		descriptor[key] = extra[key]
	return descriptor


func _make_card_heat_transaction_id(card: CardData, prefix: StringName = &"card_play") -> StringName:
	if card == null:
		return &""
	# PHASE72: a recovered entity may legally play again, even in the same turn.
	# All effects within this play still share one tx; ledger dedupe stays intact.
	_card_heat_transaction_serial += 1
	return StringName("%s:%s:%d:turn:%d:play:%d" % [str(prefix), str(card.card_id), card.get_instance_id(), context.turn_count, _card_heat_transaction_serial])


func play_card(card: CardData, requested_lane: int = -1, requested_cell: Vector2i = INVALID_GRID_CELL, cast_options: Dictionary = {}) -> Dictionary:
	if _siege_command_in_progress:
		return {"ok": false, "reason_code": &"siege_command_in_progress"}
	if card!=null and card.card_id in ["B01","B02","B03"]:
		if basic_card_trial==null: return {"ok":false,"reason":"此入口未启用公共基础牌"}
		if cast_options.has("repair_target") or cast_options.has("siege_target") or cast_options.has("terrain_raise_target"):
			return {"ok":false,"reason":"基础牌只能选择普通棋子"}
		var basic_target_status: Dictionary=basic_card_trial.target_status(card,cast_options.get("basic_target"))
		if not basic_target_status.get("ok",false): return basic_target_status
		if cast_options.has("expected_basic_status") and cast_options.expected_basic_status!=basic_target_status:
			return {"ok":false,"reason":"目标或费用已变化，请重新确认"}
	var engineering_plan: Dictionary = {}
	if card!=null and card.card_id in ["E01","E02"]:
		if cast_options.has("repair_target") or cast_options.has("siege_target") or cast_options.has("terrain_raise_target") or cast_options.has("basic_target"):
			return {"ok":false,"reason":"工程牌只能选择自己的检索选项或补给目标"}
		engineering_plan=get_engineering_cast_status(card,cast_options.get("engineering_selection"))
		if not engineering_plan.get("ok",false): return engineering_plan
		if cast_options.has("expected_engineering_status") and cast_options.expected_engineering_status!=engineering_plan:
			return {"ok":false,"reason":"工程条件或目标已变化，请重新确认"}
	var terrain_raise_plan: Dictionary = {}
	if cast_options.has("terrain_raise_target") or (card != null and card.card_id == "P23"):
		if cast_options.has("repair_target") or cast_options.has("siege_target") or not cast_options.get("terrain_raise_target") is Dictionary:
			return {"ok": false, "reason_code": &"terrain_raise_cell_required"}
		terrain_raise_plan = get_p23_terrain_raise_cast_status(card, cast_options.terrain_raise_target)
		if not terrain_raise_plan.get("ok", false):
			return terrain_raise_plan
		if cast_options.has("expected_terrain_raise_status") and cast_options.expected_terrain_raise_status != terrain_raise_plan:
			return {"ok": false, "reason_code": &"terrain_raise_preview_stale"}
		terrain_raise_plan.fault_stage = cast_options.get("phase_f2_force_raise_failure", &"")
	var repair_plan: Dictionary = {}
	if cast_options.has("repair_target") or (card != null and card.card_id == "P22"):
		if not tactical_repair_rules.is_enabled():
			return {"ok": false, "reason_code": &"repair_content_not_implemented"}
		if cast_options.has("siege_target") or not cast_options.get("repair_target") is Dictionary:
			return {"ok": false, "reason_code": &"repair_module_required"}
		repair_plan = get_p22_repair_cast_status(card, cast_options.repair_target)
		if not repair_plan.get("ok", false):
			return repair_plan
		if cast_options.has("expected_repair_status") and cast_options.expected_repair_status != repair_plan:
			return {"ok": false, "reason_code": &"repair_preview_stale"}
		repair_plan.fault_stage = cast_options.get("phase_f1_force_repair_failure", &"")
	var siege_plan: Dictionary = {}
	if cast_options.has("siege_target"):
		if not cast_options.siege_target is Dictionary:
			return {"ok": false, "reason_code": &"siege_target_stale"}
		siege_plan = get_p18_siege_cast_status(card, cast_options.siege_target)
		if not bool(siege_plan.get("ok", false)):
			return siege_plan
		if cast_options.has("expected_siege_status") and cast_options.expected_siege_status != siege_plan:
			return {"ok": false, "reason_code": &"siege_preview_stale"}
		siege_plan.fault_stage = cast_options.get("phase_e_force_p18_failure", &"")
		siege_plan.fault_core = bool(cast_options.get("phase_c_force_terrain_commit_failure", false))
	if context == null:
		return {"ok": false, "reason_code": &"context_missing", "reason": "战斗未初始化"}

	var player: Player = context.player
	var od_mode: ODMode = context.od_mode

	var steam_status := _steam_card_play_status(card)
	if not steam_status.get("ok",false): return steam_status
	# ===== 条件检查 =====
	var basic_status := _basic_card_play_status(card)
	if not basic_status.get("ok",false): return basic_status
	var engineering_status := _engineering_card_play_status(card)
	if not engineering_status.get("ok",false): return engineering_status
	if card.require_od > od_mode.current_od:
		print("[WARN] OD not enough for %s (need %d, have %d)" % [card.card_name, card.require_od, od_mode.current_od])
		return {"ok": false, "reason_code": &"od_insufficient", "reason": "OD不足"}

	if card.require_load > od_mode.load:
		print("[WARN] Load not enough for %s (need %d, have %d)" % [card.card_name, card.require_load, od_mode.load])
		return {"ok": false, "reason_code": &"load_insufficient", "reason": "Load不足"}

	if card.require_hp_cost > player.hp:
		print("[WARN] HP not enough for %s" % card.card_name)
		return {"ok": false, "reason_code": &"hp_insufficient", "reason": "HP不足"}

	if card.require_awaken and not player.is_awakened:
		print("[WARN] Need Awakening for %s" % card.card_name)
		return {"ok": false, "reason_code": &"need_awaken", "reason": "需要觉醒"}

	# ===== 场地容量检查（防御性：防止绕过 UI 直接结算）=====
	if card.is_front_row_card() and player.field.size() >= 5:
		print("[WARN] Front row full, cannot play %s" % card.card_name)
		return {"ok": false, "reason_code": &"front_full", "reason": "前场已满"}
	if card.is_back_row_card() and player.traps.size() >= 5:
		print("[WARN] Back row full, cannot play %s" % card.card_name)
		return {"ok": false, "reason_code": &"back_full", "reason": "后场已满"}

	# ===== Phase 27A-R1: requested-cell pre-validation (before resource consumption) =====
	var is_monster := card.is_front_row_card() and (card.card_family == "monster" or card.card_type == CardData.CardType.UNIT)
	if is_monster and requested_cell != INVALID_GRID_CELL:
		var cell_status := get_monster_summon_cell_status(card, requested_cell, &"player")
		if not bool(cell_status.get("ok", false)):
			return {"ok": false, "reason_code": cell_status.get("reason_code", SUMMON_PLAY_BLOCKED), "reason": cell_status.get("reason", "召唤格不可用"), "board_cell": requested_cell}
	elif is_monster and requested_lane >= 0:
		var summon_status := get_monster_summon_status(card, requested_lane, &"player")
		if not bool(summon_status.get("ok", false)):
			return {"ok": false, "reason_code": summon_status.get("reason_code", SUMMON_PLAY_BLOCKED), "reason": summon_status.get("reason", "召唤路线不可用")}

	# ===== Abyss Lock 检查（防止绕过 UI）=====
	if context and context.has_method("is_abyss_locked") and context.is_abyss_locked():
		if card.archetype_role != CardData.ArchetypeRole.CONTROL:
			return {"ok": false, "reason_code": &"abyss_locked", "reason": "Abyss Lock"}

	var heat_transaction_id := _make_card_heat_transaction_id(card, &"card_play")

	# ===== 按牌桌归属处理 — Phase 27C-R1-R2: 原子化：先校验，再注册，再提交 =====
	if card.is_front_row_card():
		# ── 前置校验：实体卡未被其他区域持有 ──
		if card in player.hand and player.hand.has(card):
			pass  # 手牌中，合法
		else:
			return {"ok": false, "reason_code": &"not_in_hand", "reason": "卡牌不在手牌中"}

		# ── Step 1: 暂入前场（仅为注册校验使用）──
		player.field.append(card)
		field_system.add_unit_to_player(card)

		# ── Step 2: 注册单位（若失败则完整回滚）──
		if card.card_family == "monster" or card.card_type == CardData.CardType.UNIT:
			var registered = register_unit(card, &"player", true, requested_lane, requested_cell)
			if registered == null:
				# 完整回滚：field + field_system
				player.field.erase(card)
				if field_system and field_system.has_method("remove_unit_from_player"):
					field_system.remove_unit_from_player(card)
				return {"ok": false, "reason_code": SUMMON_PLAY_BLOCKED, "reason": "召唤格注册失败", "board_cell": requested_cell}

		# ── Step 3: 确认注册成功 ──
		if card.card_family == "monster" or card.card_type == CardData.CardType.UNIT:
			var unit_cell := get_unit_cell(card)
			var unit_at := get_unit_at_cell(unit_cell)
			if unit_at != card:
				# 注册不一致，回滚
				player.field.erase(card)
				if field_system and field_system.has_method("remove_unit_from_player"):
					field_system.remove_unit_from_player(card)
				remove_unit_combat_state(card)
				return {"ok": false, "reason_code": SUMMON_PLAY_BLOCKED, "reason": "注册验证失败：cell 中的单位不一致", "board_cell": unit_cell}

		# ── Step 4: 提交 — 从手牌移除 ──
		player.hand.erase(card)

		# ── Step 5: 执行效果 ──
		_execute_card_effects(card, player, heat_transaction_id)
	elif card.is_back_row_card():
		# ── 前置校验 ──
		if not card in player.hand:
			return {"ok": false, "reason_code": &"not_in_hand", "reason": "卡牌不在手牌中"}
		# BACK_ROW：进入后场，移除手牌
		player.traps.append(card)
		player.hand.erase(card)
		if not card.is_continuous:
			# 非持续 TRAP：不立即执行效果，等待触发
			print("[TRAP] Set: %s (trap count: %d)" % [card.card_name, player.traps.size()])
		else:
			# 持续 SPELL：执行入场效果
			_execute_card_effects(card, player, heat_transaction_id)
	else:
		# ── 前置校验 ──
		if not card in player.hand:
			return {"ok": false, "reason_code": &"not_in_hand", "reason": "卡牌不在手牌中"}
		# INSTANT：执行效果，移除手牌，进入墓地
		if not siege_plan.is_empty() or not repair_plan.is_empty() or not terrain_raise_plan.is_empty() or not engineering_plan.is_empty():
			_siege_command_in_progress = true
		_execute_card_effects(card, player, heat_transaction_id, siege_plan, repair_plan, terrain_raise_plan)
		if bool(terrain_raise_plan.get("failed", false)):
			_siege_command_in_progress = false
			terrain_raise_plan.clear()
			return {"ok": false, "reason_code": &"terrain_raise_transaction_failed"}
		if bool(repair_plan.get("failed", false)):
			_siege_command_in_progress = false
			repair_plan.clear()
			return {"ok": false, "reason_code": &"repair_transaction_failed"}
		if bool(siege_plan.get("failed", false)):
			_siege_command_in_progress = false
			siege_plan.clear()
			return {"ok": false, "reason_code": &"siege_transaction_failed"}
		player.hand.erase(card)
		_add_player_card_to_graveyard(card)

	var package_receipt: Dictionary = {}
	if steam_package_trial != null and card.card_id in ["S01", "S02", "S03"]:
		package_receipt = steam_package_trial.commit(card, heat_transaction_id)
	if basic_card_trial != null and card.card_id in ["B01","B02","B03","B04","B05"]:
		package_receipt=basic_card_trial.commit(card,heat_transaction_id,cast_options.get("basic_target"))

	if not engineering_plan.is_empty():
		package_receipt=engineering_trial.commit(card,heat_transaction_id,engineering_plan,cast_options.get("engineering_selection"))

	# ===== 扣资源（HP 消耗）=====
	var base_descriptor := build_heat_source_descriptor(&"card_base", StringName("base_card:%s" % card.card_id), card)
	var od_notifications: Array[Dictionary] = od_mode.on_card_played(card, heat_transaction_id, base_descriptor, {"defer_signal": not siege_plan.is_empty() or not repair_plan.is_empty() or not terrain_raise_plan.is_empty()})
	# Phase 27J: base card heat is not automatic Depth.  Depth remains an
	# explicit overdraft/payment risk and is only changed by its own gateways.
	od_mode.clear_heat_transaction(heat_transaction_id)
	var card_notifications: Array[Dictionary] = context.on_card_played(card, {"defer_signal": not siege_plan.is_empty() or not repair_plan.is_empty() or not terrain_raise_plan.is_empty()})
	if _ritual_trial != null and card.archetype_role == CardData.ArchetypeRole.CONTROL and card.card_id != "B05":
		_ritual_trial.record_control(heat_transaction_id, card.get_display_name())
	player.hp -= card.require_hp_cost
	# Route completion is known only after on_card_played; reward the finishing card now.
	if siege_plan.is_empty() and repair_plan.is_empty() and terrain_raise_plan.is_empty():
		_apply_committed_chain_reward(card, heat_transaction_id)
	elif context.chain_system != null and card.route_id != "control_route":
		# Targeted casts have an exact, prevalidated hit plan. Never replay that
		# transaction (or carry its completed route over to an unrelated next card).
		context.chain_system.consume_completed_route_if(card.route_id)

	var tutor_receipt := _resolve_committed_card_tutor(card, "on_play")

	# Phase 4C-5: Cooldown — Depth-3 恢复 + Abyss Lock 解除检测
	if card.card_name == "Cooldown" and context:
		var was_abyss_locked := context.abyss_locked
		context.modify_depth(-3, "Cooldown")
		# 如果解除了 Abyss Lock，日志标记
		if was_abyss_locked and not context.abyss_locked:
			print("[CONTROL] Cooldown: Abyss Lock cleared! Depth now %d" % context.turn_depth)

	if not terrain_raise_plan.is_empty():
		_publish_p23_terrain_raise(terrain_raise_plan)
		od_mode.publish_card_notifications(od_notifications)
		context.publish_card_notifications(card_notifications)
		var result := terrain_raise_plan.duplicate(true)
		result.transaction_id = heat_transaction_id
		result.source_kind = &"p23_terrain_raise"
		for key in ["prepared", "failed", "fault_stage"]:
			result.erase(key)
		if engineering_trial!=null: engineering_trial.record_success(result)
		terrain_raise_plan.clear()
		_siege_command_in_progress = false
		return result
	if not repair_plan.is_empty():
		context.tactical_structure_board_state.publish_repair_fact(repair_plan.repair_fact)
		od_mode.publish_card_notifications(od_notifications)
		context.publish_card_notifications(card_notifications)
		var result := repair_plan.duplicate(true)
		result.transaction_id = heat_transaction_id
		result.source_kind = &"p22_repair"
		for key in ["prepared", "failed", "fault_stage"]:
			result.erase(key)
		if engineering_trial!=null: engineering_trial.record_success(result)
		repair_plan.clear()
		_siege_command_in_progress = false
		return result
	if not siege_plan.is_empty():
		_publish_p18_siege_damage(siege_plan)
		od_mode.publish_card_notifications(od_notifications)
		context.publish_card_notifications(card_notifications)
		var result := siege_plan.duplicate(true)
		result.transaction_id = heat_transaction_id
		result.source_kind = &"p18_siege"
		result.before = {"wall": siege_plan.expectations.module.duplicate(true), "structure": siege_plan.expectations.structure.duplicate(true),
			"secondary_hp": siege_plan.unit_damage + siege_plan.secondary_hp_after}
		result.after = {"wall_integrity": siege_plan.wall_after, "secondary_hp": siege_plan.secondary_hp_after, "secondary_integrity": siege_plan.secondary_integrity_after}
		result.destroyed_units = []
		result.structure_cleanup = []
		result.garrison_aftermath = []
		var dead: Dictionary = siege_plan.damage_fact.get("unit_destroyed", {})
		if not dead.is_empty():
			result.destroyed_units.append(dead.unit_runtime_id)
			if not dead.get("garrison", {}).is_empty():
				result.garrison_aftermath.append(dead.garrison.duplicate(true))
		for fact: Dictionary in siege_plan.damage_fact.get("structure_facts", []):
			if bool(fact.get("core_destroyed", false)):
				result.structure_cleanup.append(fact.duplicate(true))
			result.garrison_aftermath.append_array(fact.get("garrison_aftermath", []).duplicate(true))
		for key: String in ["prepared", "failed", "fault_stage", "fault_core", "hit_sounds"]:
			result.erase(key)
		siege_plan.clear()
		_siege_command_in_progress = false
		return result
	if not engineering_plan.is_empty(): _siege_command_in_progress=false
	return {"ok": true, "card": card, "lane_index": requested_lane, "board_cell": get_unit_cell(card) if is_monster else INVALID_GRID_CELL, "zone": &"front", "tutor": tutor_receipt, "package": package_receipt}


## 执行卡牌效果（包含基础效果 + 关键词 + 特殊奖励 + Chain 奖励）
func _execute_card_effects(card: CardData, player: Player, heat_transaction_id: StringName = &"", siege_plan: Dictionary = {}, repair_plan: Dictionary = {}, terrain_raise_plan: Dictionary = {}) -> void:
	var fx_ctx = EffectContext.new()
	fx_ctx.player = player
	fx_ctx.enemy = context.enemy
	fx_ctx.battle_context = context
	fx_ctx.source_card = card
	fx_ctx.field_system = field_system
	fx_ctx.battle_system = self
	fx_ctx.heat_transaction_id = heat_transaction_id
	fx_ctx.siege_cast_plan = siege_plan
	fx_ctx.structure_repair_plan = repair_plan
	fx_ctx.terrain_raise_plan = terrain_raise_plan

	# ===== 执行基础效果 + [4b] 阶段锁定检查 =====
	var boss_hp_before: int = context.enemy.hp if context.enemy else 0
	var repeat = context.get_effect_repeat()
	for repeat_index in range(repeat):
		fx_ctx.effect_repeat_index = repeat_index
		for effect_index in range(card.effects.size()):
			var effect = card.effects[effect_index]
			fx_ctx.effect_index = effect_index
			var effect_source_id := StringName("effect:%s:%d:repeat:%d" % [card.card_id, effect_index, repeat_index])
			fx_ctx.heat_source_descriptor = build_heat_source_descriptor(&"card_effect", effect_source_id, card)
			if effect != null and effect.has_method("execute"):
				_execute_card_effect_in_context(effect, fx_ctx)
				if bool(siege_plan.get("failed", false)) or bool(repair_plan.get("failed", false)) or bool(terrain_raise_plan.get("failed", false)):
					return
				# ADR-0008 [4b]: 每次 DamageEffect 后检查 Boss HP 阶段锁定
				if siege_plan.is_empty() and effect is DamageEffect and fx_ctx.target_type == EffectContext.TargetType.TARGET_ENEMY:
					check_hp_phase_lock(fx_ctx.final_value, boss_hp_before)
					boss_hp_before = context.enemy.hp  # 更新追踪值

	# ===== 执行关键词 =====
	KeywordSystem.on_card_play(card, context, heat_transaction_id)

	# ===== 卡牌特殊奖励 =====
	_apply_card_bonuses(card, fx_ctx)

	# Route rewards are applied by the successful play commit, after route advancement.


func _apply_committed_chain_reward(card: CardData, transaction_id: StringName) -> void:
	if context.chain_system == null or not context.chain_system.is_route_completed(card.route_id):
		return
	var fx_ctx := EffectContext.new()
	fx_ctx.player = context.player
	fx_ctx.enemy = context.enemy
	fx_ctx.battle_context = context
	fx_ctx.source_card = card
	fx_ctx.field_system = field_system
	fx_ctx.battle_system = self
	fx_ctx.heat_transaction_id = transaction_id
	var hp_before: int = context.enemy.hp if context.enemy != null else 0
	_apply_chain_completion_rewards(card, fx_ctx)
	if context.enemy != null and context.enemy.hp < hp_before:
		check_hp_phase_lock(hp_before - context.enemy.hp, hp_before)


# ============================================================
# 卡牌特殊奖励（条件判断）
# ============================================================
func _apply_card_bonuses(card: CardData, ctx: EffectContext) -> void:
	var zone_name := ""
	if context.has_method("get_od_zone_name"):
		zone_name = context.get_od_zone_name()

	match card.card_name:
		"Ember Familiar":
			# Heated 或 Overdrive 区：额外 OD+1
			if zone_name == "Heated" or zone_name == "Overdrive":
				print("[BONUS] Spark Ignition: %s zone → OD +1" % zone_name)
				var source_id := &"bonus:P02:spark_ignition"
				context.add_heat(1, source_id, ctx.heat_transaction_id, {
					"source_descriptor": build_heat_source_descriptor(&"card_bonus", source_id, card),
					"occurrence_id": &"bonus:spark_ignition",
				})

		"Ignite Blade":
			# 前场有 UNIT：追加 1 点伤害
			if ctx.player.field.size() > 0:
				print("[BONUS] Ignite Blade: unit on field → +1 damage")
				if ctx.enemy and ctx.enemy.has_method("take_damage"):
					ctx.enemy.take_damage(1)

		"Spark Vanguard":
			# Heated 区入场：额外 1 点伤害
			if zone_name == "Heated" or zone_name == "Overdrive":
				print("[BONUS] Blazing Soldier: %s zone → +1 damage" % zone_name)
				if ctx.enemy and ctx.enemy.has_method("take_damage"):
					ctx.enemy.take_damage(1)

		"Overclock Pulse":
			# Heated 或 Overdrive 区：额外抽 1
			if zone_name == "Heated" or zone_name == "Overdrive":
				print("[BONUS] Overclock Pulse: %s zone → draw 1" % zone_name)
				draw_player_cards(1, "LayerBonus:OverclockPulse")

		"Chain Conductor":
			# 前场已有 STARTER UNIT：抽 1
			var has_starter := false
			for u in ctx.player.field:
				if u != null and "archetype_role" in u and u.archetype_role == CardData.ArchetypeRole.STARTER:
					has_starter = true
					break
			if has_starter:
				print("[BONUS] Flame Channeler: STARTER on field → draw 1")
				draw_player_cards(1, "LayerBonus:FlameChanneler")

		"Pressure Relay":
			# 本回合已打出 ≥2 张牌：额外 OD+1
			if context.cards_played_this_turn >= 2:
				print("[BONUS] Pressure Loop: %d cards played → OD +1" % context.cards_played_this_turn)
				var source_id := &"bonus:P08:pressure_loop"
				context.add_heat(1, source_id, ctx.heat_transaction_id, {
					"source_descriptor": build_heat_source_descriptor(&"card_bonus", source_id, card),
					"occurrence_id": &"bonus:pressure_loop",
				})

		"Cooldown":
			# Boss 处于 Heated 或 Overdrive：Boss OD -1
			if context.enemy and context.enemy.has_method("get_od_zone_name"):
				var boss_zone := context.enemy.get_od_zone_name()
				if boss_zone == "Heated" or boss_zone == "Overdrive":
					print("[BONUS] Cooldown: Boss in %s → OD -2" % boss_zone)
					if context.enemy.has_method("modify_od"):
						context.enemy.modify_od(-2)

		"Heat Sink":
			# Phase 4C-5: 高 Depth 时入场降温 + 额外护盾，强化日志反馈
			if context.turn_depth >= 3:
				var reduce_amount := context.get_depth_control_reduce()
				context.modify_depth(-reduce_amount, "Heat Sink")
				print("[CONTROL] Heat Sink: Depth >= 3 -> Depth -%d" % reduce_amount)
			if context.turn_depth >= 6:
				print("[CONTROL] Heat Sink: Depth >= 6 -> Shield +2 bonus")
				if ctx.player.has_method("add_shield"):
					ctx.player.add_shield(2)
				else:
					ctx.player.shield += 2
		"Overdrive Eruption":
			# 自身 OD 清零
			print("[BONUS] Overdrive Eruption: clear own OD")
			if context != null and context.od_mode != null:
				var clear_amount := int(context.od_mode.current_od)
				if clear_amount > 0:
					var source_id := &"card:P20:overdrive_eruption_clear"
					context.add_heat(-clear_amount, source_id, ctx.heat_transaction_id, {
						"source_descriptor": build_heat_source_descriptor(&"card_bonus", source_id, card, {"source_family": &"convergence_cards", "classified": true}),
						"occurrence_id": &"overdrive_eruption_clear",
						"conversion_reason": &"finisher_clear",
					})

func _apply_chain_completion_rewards(card: CardData, ctx: EffectContext) -> void:
	if not context.chain_system:
		return

	# Phase 4C-4: 先用 is_route_completed 窥视，避免 control_route 被提前消费
	var cs = context.chain_system
	var completed := ""
	# control_route 留给 Chain Breaker 陷阱触发时消费，不在此消费
	if cs.is_route_completed("control_route"):
		print("[CHAIN REWARD] Control Route completed — bonus deferred to trap trigger")
		return
	# 其他路线正常消费
	completed = cs.consume_completed_route()
	if completed == "":
		return

	print("[CHAIN REWARD] Route '%s' completed — applying bonus for %s" % [completed, card.card_name])

	match completed:
		"heat_route":
			if card.card_name == "Final Slash":
				print("[CHAIN REWARD] Heat Route: Final Slash extra trigger!")
				for effect in card.effects:
					if effect != null and effect.has_method("execute"):
						_execute_card_effect_in_context(effect, ctx)

		"overdrive_route":
			if card.card_name == "Overdrive Eruption":
				print("[CHAIN REWARD] Overdrive Route: Overdrive Eruption +5 damage!")
				if ctx.enemy and ctx.enemy.has_method("take_damage"):
					ctx.enemy.take_damage(5)

		"control_route":
			if card.card_name == "Chain Breaker":
				# Fallback：如果路线已完成但 Chain Breaker 直接打出（非陷阱触发路径）
				print("[CHAIN REWARD] Control Route: Chain Breaker — extra enemy OD -2!")
				if ctx.enemy and ctx.enemy.has_method("modify_od"):
					ctx.enemy.modify_od(-2)


# ============================================================
# 抉择卡出牌接口
# ============================================================
func play_card_with_choice(card: CardData, choice_index: int) -> void:
	if not card.is_choice_card:
		play_card(card)
		return

	match choice_index:
		0:
			print("[CHOICE] Selected A: %s (%s)" % [card.choice_a_name, card.choice_a_effect_type])
		1:
			print("[CHOICE] Selected B: %s (%s)" % [card.choice_b_name, card.choice_b_effect_type])
		_:
			print("[CHOICE] Invalid choice index %d, defaulting to A" % choice_index)

	play_card(card)


# ============================================================
# Boss 出牌 — ADR-0003 / ADR-0007
# Phase 4C-4: 增强满场 fallback + 统一路径追踪
# ============================================================
func boss_play_card(card: CardData) -> void:
	if context == null or card == null:
		return

	var enemy_obj: Enemy = context.enemy
	if enemy_obj == null:
		return

	if card.card_id == "B-18":
		if not get_boss_terrain_card_status(card).get("ok", false):
			return
		if not context.boss_terrain_intent.register_intent(self).get("ok", false):
			return
		_boss_execute_effects(card, enemy_obj)
		_add_enemy_card_to_graveyard(card)
		return

	print("[BOSS PLAY] %s — %s [zone=%s]" % [card.card_name, card.short_description, card.board_zone])

	# ===== Phase 4B-5: 按 board_zone 路由，带容量检查 =====
	if card.is_front_row_card():
		if enemy_obj.field.size() >= MAX_FIELD_SIZE:
			# Boss 前场满 — 不入场、不执行效果（符合设计文档：满场时不能硬打）
			print("[BOSS FIELD FULL] %s — front row full, card fizzled" % card.card_name)
			if context.has_signal("boss_field_full"):
				context.emit_signal("boss_field_full", "front", card.card_name)
			# Phase 4B-7: 进入 Boss 墓地（同步两个 GY 数组）
			_add_enemy_card_to_graveyard(card)
			return
		# Boss FRONT_ROW：先进入前场，再生效
		enemy_obj.field.append(card)
		register_unit(card, &"boss", true)
		print("[BOSS FIELD] %s enters Boss front row (field size: %d)" % [card.card_name, enemy_obj.field.size()])
		_boss_execute_effects(card, enemy_obj)
	elif card.is_back_row_card():
		if enemy_obj.traps.size() >= MAX_TRAP_SIZE:
			print("[BOSS TRAP FULL] %s — back row full, card fizzled" % card.card_name)
			if context.has_signal("boss_field_full"):
				context.emit_signal("boss_field_full", "back", card.card_name)
			# Phase 4B-7: 进入 Boss 墓地（同步两个 GY 数组）
			_add_enemy_card_to_graveyard(card)
			return
		# Boss BACK_ROW：先进入后场
		enemy_obj.traps.append(card)
		if context.has_signal("boss_back_row_set"):
			context.emit_signal("boss_back_row_set", card.card_name)
		print("[BOSS TRAP] %s enters Boss back row (traps size: %d)" % [card.card_name, enemy_obj.traps.size()])
		if card.is_continuous:
			_boss_execute_effects(card, enemy_obj)
		else:
			print("[BOSS TRAP] %s set as back-row threat" % card.card_name)
	else:
		# Boss INSTANT：执行效果（不进前后场），然后进墓地
		_boss_execute_effects(card, enemy_obj)
		_add_enemy_card_to_graveyard(card)

	# Guard 卡护盾处理 — ADR-0006（无论 board_zone 都生效）
	if card.is_guard_card:
		enemy_obj.add_boss_shield(4, "Boss Guard")


## Phase 4C-4: Boss 满场 fallback — 不硬塞卡，改为 Gain OD / Shield / 即时效果
func _boss_field_full_fallback(card: CardData, zone_type: String, enemy_obj: Enemy) -> void:
	print("[BOSS FIELD FULL] %s — %s row full, fallback activated" % [card.card_name, zone_type])

	# Emit signal for UI feedback
	if context.has_signal("boss_field_full"):
		context.emit_signal("boss_field_full", zone_type, card.card_name)

	# Fallback: Gain Boss OD + Shield (模拟压力累积)
	var od_gain := 2 if zone_type == "front" else 1
	var shield_gain := 2
	enemy_obj.modify_od(od_gain)
	enemy_obj.add_boss_shield(shield_gain, "Boss Field Full")
	print("[BOSS FALLBACK] %s row full → Boss OD +%d, Shield +%d" % [zone_type, od_gain, shield_gain])

	# Execute card effects anyway (as INSTANT threat)
	_boss_execute_effects(card, enemy_obj)

	# Card goes to GY (full field = card consumed without taking board space)
	_add_enemy_card_to_graveyard(card)


## Boss 卡效果执行（内部辅助）
func _boss_execute_effects(card: CardData, enemy_obj: Enemy) -> void:
	print("[BOSS EFFECT] Executing effects of %s" % card.card_name)
	var fx_ctx := EffectContext.new()
	fx_ctx.player = context.player
	fx_ctx.enemy = enemy_obj
	fx_ctx.battle_context = context
	fx_ctx.source_card = card
	fx_ctx.battle_system = self
	fx_ctx.target_type = EffectContext.TargetType.TARGET_PLAYER

	# Boss OD cost → 推高 Boss OD（非玩家 OD）
	if card.od_cost > 0:
		enemy_obj.modify_od(card.od_cost)

	# 执行效果
	for effect in card.effects:
		if effect != null and effect.has_method("execute"):
			effect.execute(fx_ctx)


# ============================================================
# Boss HP 阶段锁定检查 — ADR-0008
# ============================================================
func check_hp_phase_lock(actual_damage: int, boss_hp_before: int) -> void:
	if context == null or not context.are_boss_phase_locks_enabled():
		return
	var enemy_obj: Enemy = context.enemy
	if enemy_obj == null:
		return

	# 本回合已跨越 1 阶段 → 只转化溢出，不触发新阶段锁定
	if context.phases_locked_this_turn >= 1:
		_convert_overflow_to_boss_od(actual_damage, boss_hp_before)
		return

	# Phase 27H-R0: 从 encounter 快照读取权威阈值
	var lock2: Dictionary = context.get_boss_phase_lock(2)  # JSON phase 2, 旧 "phase 1"
	var lock3: Dictionary = context.get_boss_phase_lock(3)  # JSON phase 3, 旧 "phase 2"
	var hp2: int = int(lock2.get("hp_threshold", 51))
	var hp3: int = int(lock3.get("hp_threshold", 25))

	# Phase 3 检查（先检查低阈值——HP 可能一次跨两个阶段）
	if not context.boss_phase2_triggered and enemy_obj.hp <= hp3:
		_apply_phase2_lock(actual_damage, boss_hp_before)

	# Phase 2 检查
	elif not context.boss_phase1_triggered and enemy_obj.hp <= hp2:
		_apply_phase1_lock(actual_damage, boss_hp_before)


func _apply_phase1_lock(actual_damage: int, boss_hp_before: int) -> void:
	var enemy_obj: Enemy = context.enemy
	var lock2: Dictionary = context.get_boss_phase_lock(2)
	var hp2: int = int(lock2.get("hp_threshold", 51))
	var shield2: int = int(lock2.get("shield_gain", 4))
	# 溢出伤害
	var overflow: int = maxi(0, actual_damage - (boss_hp_before - hp2))
	# Phase 24A: Atomic HP set + shield gain in one call
	enemy_obj.apply_phase_lock_state(hp2, shield2, 2, "Phase Lock 1")
	context.combo_system.reset()
	# 标记
	context.boss_phase1_triggered = true
	context.phases_locked_this_turn += 1
	# 溢出转化
	_convert_overflow_to_boss_od(overflow)
	# 日志
	print("[PHASE LOCK 1] HP locked at %d, shield +%d, combo reset. Overflow: %d" % [hp2, shield2, overflow])


func _apply_phase2_lock(actual_damage: int, boss_hp_before: int) -> void:
	var enemy_obj: Enemy = context.enemy
	var lock3: Dictionary = context.get_boss_phase_lock(3)
	var hp3: int = int(lock3.get("hp_threshold", 25))
	var shield3: int = int(lock3.get("shield_gain", 6))
	var overflow: int = maxi(0, actual_damage - (boss_hp_before - hp3))
	enemy_obj.apply_phase_lock_state(hp3, shield3, 3, "Phase Lock 2")
	if enemy_obj.od < 8:
		enemy_obj.modify_od(8 - enemy_obj.od)
	context.boss_phase2_triggered = true
	context.phases_locked_this_turn += 1
	_convert_overflow_to_boss_od(overflow)
	print("[PHASE LOCK 2] HP locked at %d, shield +%d, OD→8. Overflow: %d" % [hp3, shield3, overflow])


func _convert_overflow_to_boss_od(overflow: int, _boss_hp_before: int = 0) -> void:
	if overflow <= 0:
		return
	var od_gain: int = clampi(ceili(float(overflow) / context.OVERFLOW_OD_DIVISOR), context.OVERFLOW_OD_MIN, context.OVERFLOW_OD_MAX)
	context.enemy.modify_od(od_gain)
	print("[PHASE OVERFLOW] %d overflow → Boss OD +%d" % [overflow, od_gain])


# ============================================================
# 弃牌（不触发效果，仅移除并进入墓地）
# ============================================================
func discard_card(card: CardData) -> void:
	if card == null:
		return

	var player: Player = context.player
	player.hand.erase(card)
	_add_player_card_to_graveyard(card)

	print("[DISCARD] %s moved to graveyard (no effect)" % card.card_name)


# ============================================================
# 陷阱触发（Boss 回合前自动调用）
# ============================================================
## Read-only presentation facts; pending conditions never consume routes/cards.
func get_back_row_trigger_status(card: CardData) -> Dictionary:
	if card == null or context == null or card.card_id not in ["P04", "R01", "P14"]: return {}
	var active := card in context.player.traps
	var status := {"deployed": active, "remaining": 1 if active else 0, "cost": "触发0热", "watch_cells": [], "state": "未布置", "benefit": "", "detail": ""}
	if not active:
		status.state = "已消耗" if card in context.player.graveyard else "未布置"
		status.detail = status.state
		return status
	if reaction_trial != null and reaction_trial.owns(card):
		status.watch_cells = reaction_trial.watch_cells(card).duplicate()
		if card.card_id == "P04":
			status.state = "区外移入 · 剩1次"
			status.benefit = "阻止本次移动"
			status.detail = "敌军从监视区外移入时阻止本次移动，敌军仍支付行动费用；未触发保留，触发后消耗。"
			if core_siege_trial != null:
				status.detail += "实际拦截后该列准备1次合法攻城穿盾，至下个己方回合结束；仍受护甲/阶段保护，同列不叠加。"
		else:
			status.state = "交战余伤 · 剩1次"
			status.benefit = "监视友军防伤≤3"
			status.detail = "敌方攻击监视区友军、其他防护后仍有交战伤害时，实际防伤最多3；不挡Boss法术和反击，零伤不消耗。未触发保留，触发后消耗。"
		if status.watch_cells.is_empty(): status.state = "缺监视锚点 · 1次"
		status.detail = "触发0热；监视%d格。" % status.watch_cells.size() + status.detail
		return status
	# Legacy batch traps still use their real effect objects and handoff timing.
	var delta := 0
	for effect in card.effects:
		if effect != null and effect.get_script() == preload("res://core/effect/enemy_od_effect.gd"):
			delta += int(effect.amount)
	var bonus := 2 if card.card_name == "Chain Breaker" and context.chain_system != null and context.chain_system.is_route_completed("control_route") else 0
	status["route_bonus"] = bonus
	status["boss_heat_before"] = context.enemy.od
	status["boss_heat_after"] = clampi(context.enemy.od + delta - bonus, 0, context.enemy.max_od)
	status.state = "回合交接 · 剩1次"
	status.benefit = "Boss热量%d→%d" % [status.boss_heat_before,status.boss_heat_after]
	status.detail = "触发0热；结束己方回合、Boss行动前自动触发一次，随后消耗入墓。当前预计%s。" % status.benefit
	if card.card_name == "Chain Breaker":
		status.detail += "控制路线%s；完成时消费路线再降2热，受0下限限制。" % ("已完成" if bonus > 0 else "未完成")
	return status

func trigger_traps(_phase: String) -> void:
	var player: Player = context.player
	if player.traps.is_empty():
		return

	var traps_copy: Array = []
	var continuous_cards: Array = []
	for back_row_card in player.traps:
		if back_row_card == null:
			continue
		if back_row_card.is_continuous or (reaction_trial != null and reaction_trial.owns(back_row_card)):
			continuous_cards.append(back_row_card)
		else:
			traps_copy.append(back_row_card)

	if traps_copy.is_empty():
		return

	player.traps = continuous_cards

	for trap in traps_copy:
		if trap == null:
			continue
		print("[TRAP] Triggered: %s" % trap.card_name)
		var receipt := {"kind": &"handoff", "source_cell": _anchor_cell_of_rid(trap.get_instance_id()), "target_cell": INVALID_GRID_CELL, "boss_heat_before": context.enemy.od, "player_heat_before": context.od_mode.current_od if context.od_mode else player.od, "shield_before": player.shield}

		# 执行陷阱效果
		_apply_trap_effect(trap)

		# 移入墓地
		_add_player_card_to_graveyard(trap)
		receipt.merge({"boss_heat_after": context.enemy.od, "player_heat_after": context.od_mode.current_od if context.od_mode else player.od, "shield_after": player.shield, "consumed": true})
		back_row_triggered.emit(trap, receipt.duplicate(true))


func _apply_trap_effect(trap: CardData) -> void:
	var enemy_obj = context.enemy

	# Phase 4C-3: 所有陷阱先执行基础 effects
	_execute_trap_base_effects(trap)

	match trap.card_name:
		"Jam Signal":
			# Phase 4C-5: Boss Overdrive 时额外降 OD，强化反馈
			if enemy_obj and enemy_obj.is_overdrive():
				if enemy_obj.has_method("modify_od"):
					enemy_obj.modify_od(-1)
					print("[CONTROL] Jam Signal: Boss in Overdrive -> Boss OD -1 (total -3)")

		"Chain Breaker":
			# Phase 4C-5: Control Route 已完成 -> Route Bonus: Boss OD -2
			if enemy_obj and enemy_obj.has_method("modify_od"):
				if context.chain_system and context.chain_system.is_route_completed("control_route"):
					context.chain_system.consume_completed_route_if("control_route")
					enemy_obj.modify_od(-2)
					print("[CONTROL ROUTE BONUS] Chain Breaker: Control Route complete -> Boss OD -2 (total -6)")

	# Phase 27I-R0: P04 断频伏线 — 监视范围结算（进墓前锚点仍存在；原 Boss OD 反制已保留）
	if trap != null and trap.piece_enabled:
		var piece_pid := StringName(str(trap.piece_payload_id))
		if piece_pid == StringName("p04_tripwire_watch"):
			var watch_shield := _piece_p04_resolve_watch(trap)
			if watch_shield > 0:
				print("[PIECE P04] 断频伏线监视：护盾 +%d" % watch_shield)


## Phase 4C-3: 陷阱基础效果执行（统一入口）
func _execute_trap_base_effects(trap: CardData) -> void:
	var fx_ctx := EffectContext.new()
	fx_ctx.player = context.player
	fx_ctx.enemy = context.enemy
	fx_ctx.battle_context = context
	fx_ctx.source_card = trap
	fx_ctx.battle_system = self
	for effect in trap.effects:
		if effect != null and effect.has_method("execute"):
			effect.execute(fx_ctx)


# ============================================================
# Phase 4B-6D: 墓地统一辅助 — 避免重复 append
# ============================================================

## Phase 4B-7: 将玩家卡牌加入墓地（同步 player.graveyard + graveyard_system）
func _add_player_card_to_graveyard(card: CardData) -> void:
	move_card_to_graveyard_once(card)


## Single lifecycle entrance for replacement, destruction and normal disposal.
## Runtime identity is checked in both authoritative graveyard stores; callers
## may therefore retry safely without creating a Phase C-only mirror.
func move_card_to_graveyard_once(card: CardData) -> Dictionary:
	if card == null:
		return {"ok": false, "moved": false}
	if card.is_building_card():
		cleanup_building_state(card)
	# Phase 27I-R0: 进墓地统一清理棋子锚点与消耗记录
	_cleanup_piece_runtime(card)
	var player: Player = context.player
	var player_added := false
	var mirror_added := false
	if player.graveyard.count(card) == 0:
		player.graveyard.append(card)
		player_added = true
		print("[GY] Player GY ← %s (total: %d)" % [card.card_name, player.graveyard.size()])
	if graveyard_system and graveyard_system.player_graveyard.count(card) == 0:
		graveyard_system.add_to_player_graveyard(card)
		mirror_added = true
	return {
		"ok": true,
		"moved": player_added or mirror_added,
		"player_added": player_added,
		"mirror_added": mirror_added,
	}


# ── Phase 24B: Heat Cycle draw authority ──

## Controlled audit seed; normal battles randomize their own recycle stream in init.
func set_heat_cycle_seed(value: int) -> void:
	_heat_cycle_rng.seed = value

## Read-only diagnostic, not a persisted full-battle replay state.
func get_heat_cycle_rng_snapshot() -> Dictionary:
	return {"seed": _heat_cycle_rng.seed, "state": _heat_cycle_rng.state}

func _is_heat_cycle_eligible(card: CardData) -> bool:
	if card == null:
		return false
	if card.is_arsenal_card:
		return false
	if not card.enters_graveyard:
		return false
	if card.archetype_role == CardData.ArchetypeRole.FINISHER:
		return false
	for keyword in card.keywords:
		if String(keyword).strip_edges().to_upper() == "EXHAUST":
			return false
	return true


func _migrate_legacy_discard_to_graveyard(player: Player) -> int:
	var moved := 0
	for card in player.discard.duplicate():
		player.discard.erase(card)
		if card != null and not card in player.graveyard:
			player.graveyard.append(card)
			moved += 1
		if card != null and graveyard_system and not card in graveyard_system.player_graveyard:
			graveyard_system.add_to_player_graveyard(card)
	return moved


func _perform_heat_cycle(player: Player) -> Array[CardData]:
	_migrate_legacy_discard_to_graveyard(player)
	var recovered: Array[CardData] = []
	for raw_card in player.graveyard.duplicate():
		var card := raw_card as CardData
		if not _is_heat_cycle_eligible(card):
			continue
		player.graveyard.erase(card)
		if graveyard_system:
			while card in graveyard_system.player_graveyard:
				graveyard_system.remove_from_player_graveyard(card)
		recovered.append(card)
	if not recovered.is_empty():
		# Local Fisher-Yates: presentation/global random calls cannot change draws.
		for i in range(recovered.size() - 1, 0, -1):
			var j := _heat_cycle_rng.randi_range(0, i)
			var swap := recovered[i]
			recovered[i] = recovered[j]
			recovered[j] = swap
		player.deck.append_array(recovered)
	return recovered


func draw_player_cards(amount: int, source: String = "unknown") -> Dictionary:
	var result := {"requested": amount, "drawn": [], "burned": [], "heat_cycles": 0, "recycled_count": 0, "depth_added": 0, "fatigue_damage": 0, "fatigue_triggers": 0, "source": source}
	if amount <= 0 or context == null or context.player == null:
		return result
	var player: Player = context.player
	for _draw_index in range(amount):
		if player.deck.is_empty():
			var recovered := _perform_heat_cycle(player)
			if not recovered.is_empty():
				result["heat_cycles"] += 1
				result["recycled_count"] += recovered.size()
				context.add_depth_pressure(1, "Heat Cycle")
				result["depth_added"] += 1
				context.heat_cycle_triggered.emit(recovered.size(), 1, context.depth_pressure)
			else:
				context.fatigue_draw_count += 1
				var fatigue_damage := context.fatigue_draw_count
				player.take_damage(fatigue_damage)
				result["fatigue_damage"] += fatigue_damage
				result["fatigue_triggers"] += 1
				context.fatigue_triggered.emit(fatigue_damage, context.fatigue_draw_count, player.hp)
				if player.is_dead():
					break
				continue
		if player.deck.is_empty():
			continue
		var card: CardData = player.deck.pop_front()
		if player.can_add_to_hand():
			player.hand.append(card)
			result["drawn"].append(card)
		else:
			_add_player_card_to_graveyard(card)
			result["burned"].append(card)
	context.player_draw_resolved.emit(result.duplicate(true))
	return result


## Phase 4B-7: 将敌方卡牌加入墓地（同步 enemy.graveyard + boss_deck.graveyard）
func _add_enemy_card_to_graveyard(card: CardData) -> void:
	if card == null:
		return
	var enemy_obj: Enemy = context.enemy
	if not card in enemy_obj.graveyard:
		enemy_obj.graveyard.append(card)
		print("[GY] Boss GY ← %s (total: %d)" % [card.card_name, enemy_obj.graveyard.size()])
	# 同步到 boss_deck.graveyard，确保 UI 统一数据源
	if context.boss_deck and "graveyard" in context.boss_deck:
		if not card in context.boss_deck.graveyard:
			context.boss_deck.graveyard.append(card)


# ============================================================
# Phase 5B-1: 建筑运行时状态管理
# ============================================================

## 初始化建筑运行时状态
func _init_building_state(card: CardData) -> void:
	var key := card.get_instance_id()
	var charge_max := 4  # 默认
	match card.card_name:
		"Reactor Foundation": charge_max = 4
		"Pressure Relay": charge_max = 3
		"Heat Sink": charge_max = 3
		"Containment Wall": charge_max = 1
		"Core Cathedral": charge_max = 5
	building_states[key] = {
		"charge": 0,
		"charge_max": charge_max,
		"used_this_turn": false,
		"interface_enabled": true,
		"card_name": card.card_name,
	}
	print("[BUILDING] State init: %s (id=%d, max_charge=%d)" % [card.card_name, key, charge_max])


## 获取建筑运行时状态
func get_building_state(card: CardData) -> Dictionary:
	var key := card.get_instance_id()
	return building_states.get(key, {})


## 给建筑增加充能
func add_building_charge(card: CardData, amount: int, source: String = "") -> void:
	var state := get_building_state(card)
	if state.is_empty():
		return
	var old_charge: int = state["charge"]
	state["charge"] = mini(state["charge"] + amount, state["charge_max"])
	if state["charge"] != old_charge:
		print("[BUILDING] %s: +%d charge (%s) → %d/%d" % [card.card_name, amount, source, state["charge"], state["charge_max"]])


## 标记建筑本回合已使用接口
func mark_building_used(card: CardData) -> void:
	var state := get_building_state(card)
	if state.is_empty():
		return
	state["used_this_turn"] = true
	print("[BUILDING] %s: interface used this turn" % card.card_name)


## 重置所有建筑的本回合标记（回合开始时调用）
func reset_building_turn() -> void:
	for key in building_states.keys():
		var state: Dictionary = building_states[key]
		if not state.is_empty():
			state["used_this_turn"] = false
	if building_states.size() > 0:
		print("[BUILDING] Reset turn flags for %d buildings" % building_states.size())


## 清理建筑状态（建筑离场/进墓地时调用）
func cleanup_building_state(card: CardData) -> void:
	var key := card.get_instance_id()
	if building_states.has(key):
		building_states.erase(key)
		print("[BUILDING] State cleaned: %s" % card.card_name)
	# Phase 27I-R1: P08 建筑离场/销毁时清理该来源的战车连接（只移除该来源）。
	if card != null and str(card.piece_payload_id) == "p08_rook_relay":
		_rook_remove_source(card)


## Phase 5B-1: 建筑主动接口 — 点击建筑触发
## 返回 {ok: bool, message: String}
func use_building_interface(card: CardData, player: Player) -> Dictionary:
	var interface_status: Dictionary = get_building_interface_status(card, player)
	if not bool(interface_status.get("ok", false)):
		return {
			"ok": false,
			"reason_code": interface_status.get("reason_code", &"building_interface_unavailable"),
			"message": interface_status.get("reason", "建筑接口不可用"),
		}
	var state := get_building_state(card)

	var result: Dictionary = {"ok": false, "message": "未知建筑"}
	match card.card_name:
		"Reactor Foundation":
			result = _building_p05_reactor_foundation(card, player, state)
		"Pressure Relay":
			result = _building_p08_pressure_relay(card, player, state)
		"Heat Sink":
			result = _building_p13_heat_sink(card, player, state)
		"Containment Wall":
			result = _building_p16_containment_wall(card, player, state)
		"Core Cathedral":
			result = _building_p19_core_cathedral(card, player, state)
	if bool(result.get("ok", false)):
		result["tutor"] = _resolve_committed_card_tutor(card, "on_building_activate")
	return result


# ── P05 炉基座 ──
func _building_p05_reactor_foundation(card: CardData, player: Player, state: Dictionary) -> Dictionary:
	# 接口A: 消耗2 OD 或 2充能 强化最左侧怪兽
	if player.field.size() > 0:
		var target := player.field[0] as CardData
		if target and "unit_power" in target:
			# 优先用充能
			if state["charge"] >= 2:
				state["charge"] -= 2
				target.unit_power += 1
				_modify_unit_max_hp_or_template(target, 1, true)
				state["used_this_turn"] = true
				return {"ok": true, "message": "消耗2充能 → %s +1/+1 (剩余充能:%d)" % [target.get_display_name(), state["charge"]], "target_cell": get_unit_cell(target), "feedback": "攻击+1 · 生命+1"}
			elif player.od >= 2:
				player.modify_od(-2)
				target.unit_power += 1
				_modify_unit_max_hp_or_template(target, 1, true)
				state["used_this_turn"] = true
				return {"ok": true, "message": "消耗2 OD → %s +1/+1" % target.get_display_name(), "target_cell": get_unit_cell(target), "feedback": "攻击+1 · 生命+1"}
			else:
				return {"ok": false, "message": "OD不足(需要2 OD或2充能)"}
	else:
		# 接口B: 无怪兽时，消耗1 OD使下次Depth-1
		if player.od >= 1:
			player.modify_od(-1)
			state["used_this_turn"] = true
			context.prepare_depth_reduction(1, "Reactor Foundation")
			return {"ok": true, "message": "消耗1 OD → 下次Depth增加-1（已准备）"}
		else:
			return {"ok": false, "message": "OD不足(需要1 OD)"}
	return {"ok": false, "message": "无可强化怪兽"}


# ── P08 压力继电塔 ──
func _building_p08_pressure_relay(card: CardData, player: Player, state: Dictionary) -> Dictionary:
	if context.cards_played_this_turn < 2:
		return {"ok": false, "message": "本回合需先打出2张牌"}
	if player.od < 1:
		return {"ok": false, "message": "OD不足(需要1 OD)"}
	if player.field.size() == 0:
		return {"ok": false, "message": "无可强化怪兽"}
	var target := player.field[0] as CardData
	player.modify_od(-1)
	target.unit_power += 1
	_modify_unit_max_hp_or_template(target, 1, true)
	state["used_this_turn"] = true
	return {"ok": true, "message": "压力释放 → %s +1/+1" % target.get_display_name(), "target_cell": get_unit_cell(target), "feedback": "攻击+1 · 生命+1"}


# ── P13 热沉装置 ──
func _building_p13_heat_sink(card: CardData, player: Player, state: Dictionary) -> Dictionary:
	var reduce_amount := context.get_depth_control_reduce()
	if player.od >= 1:
		player.modify_od(-1)
		state["used_this_turn"] = true
		if context and context.has_method("prepare_depth_reduction"):
			context.prepare_depth_reduction(reduce_amount, "Heat Sink")
		building_auto_triggered.emit(card.card_name, "Depth减免已准备")
		return {"ok": true, "message": "消耗1 OD → 下次Depth增加-%d (已准备)" % reduce_amount}
	elif state["charge"] >= 1:
		state["charge"] -= 1
		state["used_this_turn"] = true
		if context and context.has_method("prepare_depth_reduction"):
			context.prepare_depth_reduction(reduce_amount, "Heat Sink")
		building_auto_triggered.emit(card.card_name, "Depth减免已准备(冷却充能)")
		return {"ok": true, "message": "消耗1冷却充能 → 下次Depth-%d (剩余:%d)" % [reduce_amount, state["charge"]]}
	return {"ok": false, "message": "OD不足或充能不足"}


# ── P16 封压壁 ──
func _building_p16_containment_wall(card: CardData, player: Player, state: Dictionary) -> Dictionary:
	# 封压壁是被动建筑，接口直接给护盾
	if state["charge"] >= 1:
		state["charge"] -= 1
		player.shield += 3
		state["used_this_turn"] = true
		return {"ok": true, "message": "消耗封压充能 → 护盾+3 (剩余:%d)" % state["charge"]}
	else:
		player.shield += 2
		state["used_this_turn"] = true
		return {"ok": true, "message": "封压壁激活 → 护盾+2"}


# ── P19 炉心圣堂 ──
func _building_p19_core_cathedral(card: CardData, player: Player, state: Dictionary) -> Dictionary:
	if player.od < 3:
		return {"ok": false, "message": "OD不足(需要3 OD)"}
	player.modify_od(-3)
	# 全体友方怪兽 +1/+1
	var count := 0
	for unit in player.field:
		if unit and "unit_power" in unit:
			unit.unit_power += 1
			_modify_unit_max_hp_or_template(unit, 1, true)
			count += 1
	# Depth +1 (代价)
	if context and context.has_method("add_depth"):
		context.add_depth(1, "Core Cathedral")
	state["used_this_turn"] = true
	return {"ok": true, "message": "圣堂共鸣 → %d只怪兽 +1/+1 (OD-3, Depth+1)" % count}


# ============================================================
# Phase 5B-2: P16 封压壁被动防护
# ============================================================

## Player 伤害减免钩子 — 由 Player.take_damage 调用
func apply_player_damage_prevention(dmg: int) -> Variant:
	var player: Player = context.player
	var wall_card = null
	for trap in player.traps:
		if trap != null and trap.has_meta("engineering_site_tx"):
			continue
		if trap != null and trap.card_name == "Containment Wall":
			wall_card = trap
			break
	if wall_card == null:
		return dmg  # 无封压壁，原伤害
	# 减免 3 点伤害
	var prevented := mini(3, dmg)
	var new_dmg := dmg - prevented
	# 从后场移除
	player.traps.erase(wall_card)
	# 进墓地
	_add_player_card_to_graveyard(wall_card)
	# 清理建筑状态
	cleanup_building_state(wall_card)
	# 发信号
	building_auto_triggered.emit(wall_card.card_name, "防止 %d 点伤害 → GY" % prevented)
	print("[BUILDING AUTO] Containment Wall: prevented %d damage, %d remains" % [prevented, new_dmg])
	return {"damage": new_dmg, "prevented": prevented, "card": wall_card.card_name}


# ============================================================
# Phase 5B-2: P19 炉心圣堂动态 Overdrive 光环
# ============================================================

## OD 区间变化时调用 — 应用/移除 Core Cathedral 光环
func apply_cathedral_overdrive_aura() -> void:
	var player: Player = context.player
	var cathedral = null
	for trap in player.traps:
		if trap != null and trap.card_name == "Core Cathedral":
			cathedral = trap
			break
	if cathedral == null:
		return
	var state := get_building_state(cathedral)
	if state.is_empty():
		return
	var is_overdrive := context.od_mode.is_overdrive() if context and context.od_mode else false
	var buffed_ids: Array = state.get("_buffed_ids", [])

	if is_overdrive:
		# 进入/保持 Overdrive: 给所有怪兽 +1 ATK（只加一次）
		var applied := 0
		for unit in player.field:
			if unit and "unit_power" in unit:
				var uid: int = unit.get_instance_id()
				if not uid in buffed_ids:
					unit.unit_power += 1
					buffed_ids.append(uid)
					applied += 1
		if applied > 0:
			state["_buffed_ids"] = buffed_ids
			building_auto_triggered.emit(cathedral.card_name, "共鸣: %d只怪兽ATK+1" % applied)
	else:
		# 离开 Overdrive: 移除加成
		var removed := 0
		for uid in buffed_ids:
			for unit in player.field:
				if unit and unit.get_instance_id() == uid:
					unit.unit_power -= 1
					removed += 1
					break
		if removed > 0:
			state["_buffed_ids"] = []
			building_auto_triggered.emit(cathedral.card_name, "熄火: 共鸣加成移除")


## P13 热沉装置: Depth 降低时获得冷却充能
func trigger_heat_sink_charge_on_depth_reduce(amount: int, source: String) -> void:
	var player: Player = context.player
	for trap in player.traps:
		if trap != null and trap.has_meta("engineering_site_tx"):
			continue
		if trap != null and trap.card_name == "Heat Sink":
			var state := get_building_state(trap)
			if not state.is_empty() and state["charge"] < state["charge_max"]:
				add_building_charge(trap, 1, "Depth降(" + source + ")")
				building_auto_triggered.emit(trap.card_name, "充能: Coolant %d/%d" % [state["charge"], state["charge_max"]])
			break

# ============================================================
# Phase 10H: 建筑替换系统
# ============================================================

## Phase 23B-R2: 两阶段检查 — 先检查是否因容量满被挡，再确认其他门均通过
func needs_building_replacement(card: CardData) -> bool:
	if card == null or not card.is_building_card():
		return false
	var normal_status := get_card_play_status(card)
	var back_row_full: bool = context != null and context.player != null and context.player.traps.size() >= MAX_TRAP_SIZE
	if not bool(normal_status.get("needs_replacement", false)) and not back_row_full:
		return false
	var replacement_status := get_card_play_status(card, true, true)
	return bool(replacement_status.get("ok", false))


## 返回当前场上可替换的建筑列表（按入场顺序，最早的在前）
func get_replaceable_buildings(pl: Player = null) -> Array:
	var target := pl
	if target == null:
		if context and context.player:
			target = context.player
	if target == null:
		return []
	var buildings: Array = []
	for card in target.traps:
		if card != null and is_instance_valid(card) and card.is_building_card():
			buildings.append(card)
	return buildings


## Phase 23B-R2: 加固执行门 — 使用 ignore_active_building_limit=true 重新验证
func can_replace_building(new_card: CardData, old_card: CardData, prepared_spatial_replacement: bool = false) -> Dictionary:
	if new_card == null or old_card == null:
		return {"ok": false, "reason": "卡牌无效"}
	if not new_card.is_building_card() or not old_card.is_building_card():
		return {"ok": false, "reason": "非建筑卡"}
	var player: Player = context.player
	if player == null:
		return {"ok": false, "reason": "玩家未初始化"}
	# Runtime identity is part of the authoritative replacement contract. A
	# same-id clone must never substitute for the exact card held in hand.
	if not new_card in player.hand:
		return {"ok": false, "reason_code": &"not_in_hand", "reason": "新建筑不在手牌中"}
	if not old_card in player.traps:
		return {"ok": false, "reason_code": &"structure_target_stale", "reason": "目标建筑不在场上"}
	var status := get_card_play_status(new_card, true, true)
	if not bool(status.get("ok", false)):
		return {"ok": false, "reason": status.get("reason", "条件不满足")}
	var replacement_needed: bool = context.count_active_buildings() >= context.ACTIVE_BUILDING_LIMIT or player.traps.size() >= MAX_TRAP_SIZE
	if not replacement_needed and not prepared_spatial_replacement:
		return {"ok": false, "reason": "建筑槽未满，无需替换"}
	return {"ok": true, "reason": ""}


## 执行建筑替换：旧建筑→GY，新建筑→后场
func replace_building_and_play(new_card: CardData, old_card: CardData, prepared_spatial_replacement: bool = false) -> Dictionary:
	if context == null or context.player == null:
		return {"ok": false, "reason": "战斗未初始化"}

	# 1. 确认可替换
	var can_result := can_replace_building(new_card, old_card, prepared_spatial_replacement)
	if not can_result.get("ok", false):
		return can_result

	# 1.5. 同普通出牌的热量事务；Depth 只由显式风险支付改变。
	var od_mode: ODMode = context.od_mode
	var heat_transaction_id := _make_card_heat_transaction_id(new_card, &"replace_play")

	# 2. 同轴检测（在移除 old 前完成）
	var is_same_series := (new_card.series_id != "" and new_card.series_id == old_card.series_id)

	# 3. 从后场移除旧建筑
	var player: Player = context.player
	player.traps.erase(old_card)

	# 4. 旧建筑进墓地
	_add_player_card_to_graveyard(old_card)
	cleanup_building_state(old_card)

	# 5. 从手牌移除新建筑
	player.hand.erase(new_card)

	# 6. 新建筑加入后场
	player.traps.append(new_card)

	# 7. 初始化新建筑状态
	_init_building_state(new_card)
	context.record_building_played(new_card.card_name)

	# 8. 同轴奖励：charge+1
	var bonus_text := ""
	if is_same_series:
		add_building_charge(new_card, 1, "同轴升级")
		bonus_text = "同轴升级：充能 +1"

	# 9. 执行新建筑入场效果（如果是持续建筑）
	if new_card.is_continuous:
		_execute_card_effects(new_card, player, heat_transaction_id)

	# 9.5. 与普通出牌一致：先保持既有效果顺序，再提交基础 Heat/Load。
	var base_descriptor := build_heat_source_descriptor(&"card_base", StringName("base_card:%s" % new_card.card_id), new_card)
	od_mode.on_card_played(new_card, heat_transaction_id, base_descriptor)
	od_mode.clear_heat_transaction(heat_transaction_id)
	# Replacement is still one card played: advance identity, count and route once.
	context.on_card_played(new_card)
	_apply_committed_chain_reward(new_card, heat_transaction_id)

	return {
		"ok": true,
		"replaced": old_card.card_name,
		"played": new_card.card_name,
		"same_series": is_same_series,
		"bonus": bonus_text if bonus_text != "" else "无",
		"message": "%s 替换 %s" % [new_card.card_name, old_card.card_name],
	}


# ============================================================
# Phase 25E: UnitCombatState 注册/读写 API
# ============================================================

## 注册单位（必须在前场）
func register_unit(card: CardData, owner_side: StringName, summoned_this_turn: bool, requested_lane: int = -1, requested_cell: Vector2i = INVALID_GRID_CELL):
	var side := _normalize_owner_side(owner_side)
	if not _is_valid_front_field_unit(card, side):
		return null
	var existing = _state_for_card(card)
	if existing != null:
		return existing
	# Phase 27A: resolve target cell
	var target_cell := requested_cell
	if target_cell == INVALID_GRID_CELL and requested_lane >= 0:
		var compatibility_rank := 1 if side == &"boss" else 3
		target_cell = Vector2i(requested_lane, compatibility_rank)
	if target_cell == INVALID_GRID_CELL:
		for candidate in tactical_grid_rules.get_ordered_summon_cells(side):
			if get_unit_at_cell(candidate) == null:
				target_cell = candidate
				break
	if target_cell == INVALID_GRID_CELL:
		return null
	var state = UnitCombatStateClass.new(card.get_instance_id(), side, maxi(1, card.unit_defense), summoned_this_turn)
	print("[UNIT_REGISTER] card=%s runtime_id=%d target_cell=%s existing_unit_at_cell=%s" % [card.card_name, card.get_instance_id(), str(target_cell), str(get_unit_at_cell(target_cell).card_name if get_unit_at_cell(target_cell) else "null")])
	## Phase 27C: initialize default facing from snapshot
	var default_facing: int = tactical_core_facing_rules.get_default_facing(side)
	state.set_facing_rank_delta(default_facing)
	unit_combat_states[card.get_instance_id()] = state
	var assign_result := _assign_unit_cell_atomic(card, target_cell, &"summon", false, _defer_unit_registration_notifications)
	if not bool(assign_result.get("ok", false)):
		unit_combat_states.erase(card.get_instance_id())
		return null
	if not _defer_unit_registration_notifications:
		_emit_unit_state(card)
	return state

## 确保状态存在（懒注册用于遗留路径）
func ensure_unit_combat_state(card: CardData, owner_side: StringName = &""):
	var existing = _state_for_card(card)
	if existing != null:
		return existing
	var side := owner_side
	if side == &"":
		side = _detect_unit_owner_side(card)
	if side == &"":
		return null
	return register_unit(card, side, false)

## 读取快照（懒创建支持）
func get_unit_combat_state(card: CardData) -> Dictionary:
	# Phase 27C-R1-R2: read-only — never auto-create state
	var state = _state_for_card(card)
	if state == null:
		return {}
	return state.snapshot(monster_combat_rules.max_attacks_per_turn, monster_combat_rules.actions_per_turn)

func get_unit_current_hp(card: CardData) -> int:
	return int(get_unit_combat_state(card).get("current_hp", 0))

func get_unit_max_hp(card: CardData) -> int:
	return int(get_unit_combat_state(card).get("max_hp", 0))

## Phase 27E-R5-R: Read-only authoritative effective attack.
## Presenters and UI must read this value — never compute card.unit_power + bonus locally.
func get_unit_effective_attack(card: CardData) -> int:
	if card == null:
		return 0
	var state: Variant = _state_for_card(card)
	if state == null:
		return maxi(0, card.unit_power)
	return int(state.get_effective_attack(card.unit_power))

func unregister_unit(card: CardData) -> void:
	remove_unit_combat_state(card)

func remove_unit_combat_state(card: CardData) -> void:
	if card == null:
		return
	if frontline_trial!=null: frontline_trial.escort.erase(card.get_instance_id())
	_clear_garrison_for_unit(card, &"unit_removed")
	var old_cell: Vector2i = get_unit_cell(card)
	if old_cell != INVALID_GRID_CELL and get_unit_at_cell(old_cell) == card:
		unit_by_cell.erase(old_cell)
	unit_cell_by_runtime_id.erase(card.get_instance_id())
	unit_lane_by_runtime_id.erase(card.get_instance_id())
	var state: Variant = _state_for_card(card)
	if state != null:
		state.clear_board_cell()
	unit_combat_states.erase(card.get_instance_id())

func get_all_monster_attack_states() -> Dictionary:
	var result: Dictionary = {}
	for raw_key in unit_combat_states.keys():
		var state = unit_combat_states.get(raw_key)
		if state != null:
			result[int(raw_key)] = state.snapshot(monster_combat_rules.max_attacks_per_turn, monster_combat_rules.actions_per_turn)
	return result

# ═══════════════════════════════════════════
# Phase 26C: 核心指令规则解析器
# ═══════════════════════════════════════════

# ═══════════════════════════════════════════
# Phase 27C: Facing / Turn / Rear Defense API
# ═══════════════════════════════════════════

## Internal helper: get unit facing, falling back to side default
func _get_unit_facing_checked(card: CardData, owner_side: StringName) -> int:
	var state = _state_for_card(card)
	if state != null:
		var f = state.get_facing_rank_delta()
		if f == -1 or f == 1:
			return f
	return tactical_core_facing_rules.get_default_facing(owner_side)


func get_unit_facing(card: CardData) -> int:
	var state = _state_for_card(card)
	if state == null:
		return 0
	return state.get_facing_rank_delta()


func get_unit_turn_status(card: CardData) -> Dictionary:
	var base := {
		"ok": false,
		"reason": REASON_STATE_MISSING,
		"facing_rank_delta": 0,
	}
	if card == null:
		base.reason = REASON_CARD_MISSING
		return base
	var state = _state_for_card(card)
	if state == null:
		return base
	var from_cell := get_unit_cell(card)
	if from_cell == INVALID_GRID_CELL:
		base.reason = REASON_NOT_ON_BOARD
		return base
	if state.is_dead():
		return base
	var current_facing = state.get_facing_rank_delta()
	base.facing_rank_delta = current_facing

	if tactical_core_facing_rules.is_turn_blocked_by_summoning_sickness() and state.summoned_this_turn:
		base.reason = REASON_SUMMONING_SICKNESS
		return base

	base.ok = true
	base.reason = REASON_OK
	return base


func turn_unit_for_rear_defense(card: CardData) -> Dictionary:
	var status := get_unit_turn_status(card)
	var base := {
		"ok": false,
		"reason": status.get("reason", REASON_STATE_MISSING),
		"action_consumed": false,
		"facing_before": status.get("facing_rank_delta", 0),
		"facing_after": status.get("facing_rank_delta", 0),
	}
	if not bool(status.get("ok", false)):
		return base

	var state = _state_for_card(card)
	var current_facing = state.get_facing_rank_delta()
	var new_facing = -current_facing

	# Flip facing
	state.set_facing_rank_delta(new_facing)
	# Legacy action counter retained for compatibility. Phase 27D paid commands
	# use the shared command pool; turning does not lock subsequent paid moves/attacks.
	state.actions_used = monster_combat_rules.actions_per_turn
	state.last_action = &"turn"
	_emit_unit_state(card)

	base.ok = true
	base.reason = REASON_OK
	base.action_consumed = true
	base.facing_after = new_facing
	return base

# ═══════════════════════════════════════════
# Phase 27C Task 4: Engagement / Core Breach / OD Breach / Guard
# ═══════════════════════════════════════════

## Internal: return the opposite side name
func _opposite_side(owner_side: StringName) -> StringName:
	return &"player" if owner_side == &"boss" else &"boss"


## Internal: get current OD charge for a side
func _get_side_od(owner_side: StringName) -> int:
	if owner_side == &"boss" and context.enemy != null:
		return context.enemy.od
	if owner_side == &"player" and context.player != null:
		return context.player.od
	return 0


## Internal: modify OD charge for a side (delta: positive=gain, negative=spend)
func _modify_side_od(owner_side: StringName, delta: int) -> void:
	if owner_side == &"boss" and context.enemy != null:
		context.enemy.modify_od(delta)
	elif owner_side == &"player" and context.player != null:
		context.player.modify_od(delta)


## Internal: find a guard interceptor that protects the core from this attacker
func _find_guard_interceptor(attacker: CardData, owner_side: StringName) -> CardData:
	if attacker == null:
		return null
	var atk_cell: Vector2i = get_unit_cell(attacker)
	if atk_cell == INVALID_GRID_CELL:
		return null
	var enemy_side: StringName = _opposite_side(owner_side)
	var enemy_field: Array = _field_for_owner(enemy_side)
	var radius: int = tactical_core_facing_rules.get_guard_intercept_column_radius()
	for raw in enemy_field:
		var guard := raw as CardData
		if guard == null or not guard.is_guard_card:
			continue
		var gs: Variant = _state_for_card(guard)
		if gs == null or gs.is_dead():
			continue
		var guard_cell: Vector2i = get_unit_cell(guard)
		if guard_cell == INVALID_GRID_CELL:
			continue
		if abs(guard_cell.x - atk_cell.x) <= radius:
			return guard
	return null


## Check if a unit is engaged (standing in any enemy's legal attack cell)
func is_unit_engaged(card: CardData) -> bool:
	if card == null:
		return false
	var state: Variant = _state_for_card(card)
	if state == null or state.is_dead():
		return false
	var cell: Vector2i = get_unit_cell(card)
	if cell == INVALID_GRID_CELL:
		return false
	var owner_side: StringName = state.owner_side
	var enemy_side: StringName = _opposite_side(owner_side)
	var enemy_field: Array = _field_for_owner(enemy_side)
	for raw in enemy_field:
		var enemy := raw as CardData
		if enemy == null:
			continue
		var enemy_state = _state_for_card(enemy)
		if enemy_state == null or enemy_state.is_dead():
			continue
		var enemy_cell: Vector2i = get_unit_cell(enemy)
		if enemy_cell == INVALID_GRID_CELL:
			continue
		var attack_cells: Array[Vector2i] = _get_pattern_attack_cells(enemy, enemy_cell, enemy_side)
		if attack_cells.has(cell):
			return true
	return false


## Return list of enemy cards whose attack cells contain this card
func get_engaging_units(card: CardData) -> Array[CardData]:
	var result: Array[CardData] = []
	if card == null:
		return result
	var state = _state_for_card(card)
	if state == null or state.is_dead():
		return result
	var cell := get_unit_cell(card)
	if cell == INVALID_GRID_CELL:
		return result
	var owner_side: StringName = state.owner_side
	var enemy_side: StringName = _opposite_side(owner_side)
	var enemy_field: Array = _field_for_owner(enemy_side)
	for raw in enemy_field:
		var enemy := raw as CardData
		if enemy == null:
			continue
		var enemy_state = _state_for_card(enemy)
		if enemy_state == null or enemy_state.is_dead():
			continue
		var enemy_cell: Vector2i = get_unit_cell(enemy)
		if enemy_cell == INVALID_GRID_CELL:
			continue
		var attack_cells: Array[Vector2i] = _get_pattern_attack_cells(enemy, enemy_cell, enemy_side)
		if attack_cells.has(cell):
			result.append(enemy)
	return result


## Query OD breach status from threat rank (mirrored for player/boss)
func get_overdrive_core_breach_status(attacker: CardData) -> Dictionary:
	var base := {
		"ok": false,
		"reason": REASON_STATE_MISSING,
		"source_cell": INVALID_GRID_CELL,
		"facing_rank_delta": 0,
		"target_side": &"",
		"interceptor_runtime_id": 0,
	}
	if attacker == null:
		base.reason = REASON_CARD_MISSING
		return base
	var state: Variant = _state_for_card(attacker)
	if state == null:
		return base
	var cell: Vector2i = get_unit_cell(attacker)
	if cell == INVALID_GRID_CELL:
		base.reason = REASON_NOT_ON_BOARD
		return base
	base.source_cell = cell
	var owner_side: StringName = state.owner_side
	base.facing_rank_delta = state.get_facing_rank_delta()
	var target_side := _opposite_side(owner_side)
	base.target_side = target_side

	# Must be on threat rank
	var threat_rank: int = tactical_core_facing_rules.get_threat_rank(owner_side)
	if cell.y != threat_rank:
		base.reason = REASON_NOT_THREAT_RANK
		return base

	# Must face toward enemy core
	var required_facing: int = tactical_core_facing_rules.get_default_facing(owner_side)
	if state.get_facing_rank_delta() != required_facing:
		base.reason = REASON_FACING_AWAY_FROM_CORE
		return base

	# Summoning sickness
	if state.summoned_this_turn:
		base.reason = REASON_SUMMONING_SICKNESS
		return base

	# Action availability
		return base

	# OD breach once per turn
	if state.overdrive_breach_used_this_turn:
		base.reason = REASON_OVERDRIVE_BREACH_USED
		return base

	# OD charge check
	var charge_needed: int = tactical_core_facing_rules.get_overdrive_breach_charge_cost()
	var current_charge: int = _get_side_od(owner_side)
	if current_charge < charge_needed:
		base.reason = REASON_INSUFFICIENT_CHARGE
		return base

	# Guard interception check — guards can intercept OD breach too
	var interceptor: CardData = _find_guard_interceptor(attacker, owner_side)
	if interceptor != null:
		base.reason = REASON_GUARD_INTERCEPTED
		base.interceptor_runtime_id = interceptor.get_instance_id()
		return base

	base.ok = true
	base.reason = REASON_OK
	return base


## Execute OD breach atomically — no partial state on failure
func resolve_overdrive_core_breach(attacker: CardData) -> Dictionary:
	var status: Dictionary = get_overdrive_core_breach_status(attacker)
	var result := {
		"ok": false,
		"reason": status.get("reason", REASON_STATE_MISSING),
		"action_consumed": false,
		"charge_spent": 0,
		"depth_gained": 0,
		"damage_dealt": 0,
	}
	if not bool(status.get("ok", false)):
		return result

	var state: Variant = _state_for_card(attacker)
	var owner_side: StringName = state.owner_side
	var enemy_side: StringName = _opposite_side(owner_side)

	# Charge cost (atomic: spend before anything else fails)
	var charge_cost: int = tactical_core_facing_rules.get_overdrive_breach_charge_cost()
	_modify_side_od(owner_side, -charge_cost)
	result.charge_spent = charge_cost

	# Depth gain
	var depth_gain: int = tactical_core_facing_rules.get_overdrive_breach_depth_gain()
	if context and context.has_method("add_depth"):
		context.add_depth(depth_gain, attacker.card_name)
	result.depth_gained = depth_gain

	# Consume action (full turn action)
	state.actions_used = monster_combat_rules.actions_per_turn
	result.action_consumed = true

	# Mark OD breach used this turn
	state.overdrive_breach_used_this_turn = true

	# Deal core damage
	var damage: int = get_effective_unit_attack(attacker)
	result.damage_dealt = damage
	if enemy_side == &"boss" and context.enemy != null:
		context.enemy.take_damage(damage)
	elif enemy_side == &"player" and context.player != null:
		context.player.take_damage(damage)

	mark_monster_attacked(attacker)
	_emit_unit_state(attacker)

	result.ok = true
	result.reason = REASON_OK
	return result

func configure_od_core_commands(snapshot: RefCounted) -> void:
	od_core_command_rules = snapshot


# ═══════════════════════════════════════════
# Phase 26E: Lane & movement authority
# ═══════════════════════════════════════════

func _runtime_id(card: CardData) -> int:
	return card.get_instance_id() if card != null else 0

func get_unit_lane(card: CardData) -> int:
	# Phase 27A: compatibility wrapper — lane equals cell.x
	var cell := get_unit_cell(card)
	return cell.x if cell != INVALID_GRID_CELL else -1

func get_occupied_lanes(owner_side: StringName) -> Dictionary:
	var occupied: Dictionary = {}
	var side := _normalize_owner_side(owner_side)
	for raw_card in _field_for_owner(side):
		var card := raw_card as CardData
		if card == null:
			continue
		var lane := get_unit_lane(card)
		if lane >= 0:
			occupied[lane] = card
	return occupied

# ── Phase 27A: Cell authority ──

func get_unit_cell(card: CardData) -> Vector2i:
	if card == null:
		return INVALID_GRID_CELL
	var value: Variant = unit_cell_by_runtime_id.get(card.get_instance_id(), INVALID_GRID_CELL)
	return value if value is Vector2i else INVALID_GRID_CELL

func get_unit_at_cell(cell: Vector2i) -> CardData:
	return unit_by_cell.get(cell, null) as CardData

func get_occupied_cells() -> Dictionary:
	return unit_by_cell.duplicate()

func _assign_unit_cell_atomic(card: CardData, destination: Vector2i, source: StringName, emit_change := true, defer_unit_signal: bool = false) -> Dictionary:
	if card == null or not tactical_grid_rules.is_cell_in_bounds(destination):
		return {"ok": false, "reason_code": &"cell_out_of_bounds"}
	print("[CELL_INVARIANT] _assign_unit_cell_atomic card=%s runtime_id=%d dest=%s occupant=%s map_size=%d" % [card.card_name if card else "null", card.get_instance_id() if card else -1, str(destination), str(get_unit_at_cell(destination).card_name if get_unit_at_cell(destination) else "null"), unit_by_cell.size()])
	var runtime_id := card.get_instance_id()
	var occupant: CardData = get_unit_at_cell(destination)
	if occupant != null and occupant != card:
		return {"ok": false, "reason_code": &"cell_occupied"}
	var state: Variant = _state_for_card(card)
	if state == null:
		return {"ok": false, "reason_code": &"unit_not_registered"}
	var from_cell: Vector2i = get_unit_cell(card)
	if from_cell == destination:
		return {"ok": true, "reason_code": &"ok", "from_cell": from_cell, "to_cell": destination}
	if from_cell != INVALID_GRID_CELL:
		unit_by_cell.erase(from_cell)
	unit_cell_by_runtime_id[runtime_id] = destination
	unit_by_cell[destination] = card
	state.set_board_cell(destination)
	unit_lane_by_runtime_id[runtime_id] = destination.x
	if not defer_unit_signal:
		_emit_unit_state(card)
	if emit_change:
		unit_cell_changed.emit(card, state.owner_side, from_cell, destination, source)
		unit_lane_changed.emit(card, state.owner_side, from_cell.x, destination.x, source)
	return {"ok": true, "reason_code": &"ok", "from_cell": from_cell, "to_cell": destination}

func _first_free_spawn_lane(owner_side: StringName) -> int:
	var occupied := get_occupied_lanes(owner_side)
	for lane in monster_combat_rules.get_spawn_lane_order():
		if not occupied.has(lane):
			return lane
	return -1

func get_unit_movement_pattern(card: CardData) -> StringName:
	return monster_combat_rules.get_movement_pattern(StringName(str(card.card_id))) if card != null else &"step"

func get_legal_move_lanes(card: CardData, source: StringName = MOVE_SELF) -> Array[int]:
	var state: Variant = _state_for_card(card)
	if state == null:
		return []
	var occupied := get_occupied_lanes(state.owner_side)
	occupied.erase(get_unit_lane(card))
	if source in [MOVE_CORE_REDEPLOY, MOVE_FORCED_EFFECT]:
		var all_empty: Array[int] = []
		for lane in range(monster_combat_rules.get_lane_count()):
			if not occupied.has(lane):
				all_empty.append(lane)
		return all_empty
	return monster_combat_rules.get_legal_move_lanes(
		get_unit_movement_pattern(card), get_unit_lane(card), occupied)

# ── Phase 26E-R1: Summon lane queries ──

const SUMMON_OK: StringName = &"ok"
const SUMMON_INVALID_CARD: StringName = &"invalid_card"
const SUMMON_NOT_FRONT_MONSTER: StringName = &"not_front_monster"
const SUMMON_LANE_OUT_OF_RANGE: StringName = &"lane_out_of_range"
const SUMMON_LANE_OCCUPIED: StringName = &"lane_occupied"
const SUMMON_CARD_NOT_IN_HAND: StringName = &"card_not_in_hand"
const SUMMON_PLAY_BLOCKED: StringName = &"card_play_blocked"

func get_legal_summon_lanes(owner_side: StringName = &"player") -> Array[int]:
	var legal: Array[int] = []
	var occ := get_occupied_lanes(owner_side)
	for lane in range(monster_combat_rules.get_lane_count()):
		if not occ.has(lane):
			legal.append(lane)
	return legal

func get_monster_summon_status(card: CardData, requested_lane: int, owner_side: StringName = &"player") -> Dictionary:
	if card == null:
		return {"ok": false, "reason_code": SUMMON_INVALID_CARD, "reason": "卡牌无效", "lane_index": requested_lane, "owner_side": owner_side}
	if not card.is_front_row_card() or (card.card_family != "monster" and card.card_type != CardData.CardType.UNIT):
		return {"ok": false, "reason_code": SUMMON_NOT_FRONT_MONSTER, "reason": "不是前场怪兽", "lane_index": requested_lane, "owner_side": owner_side}
	var play_status := get_card_play_status(card)
	if not bool(play_status.get("ok", false)):
		return {"ok": false, "reason_code": SUMMON_PLAY_BLOCKED, "reason": play_status.get("reason", "出牌条件不满足"), "lane_index": requested_lane, "owner_side": owner_side}
	if requested_lane < 0 or requested_lane >= monster_combat_rules.get_lane_count():
		return {"ok": false, "reason_code": SUMMON_LANE_OUT_OF_RANGE, "reason": "路线超出范围", "lane_index": requested_lane, "owner_side": owner_side}
	var summon_occ := get_occupied_lanes(owner_side)
	if summon_occ.has(requested_lane):
		return {"ok": false, "reason_code": SUMMON_LANE_OCCUPIED, "reason": "目标路线已被占用", "lane_index": requested_lane, "owner_side": owner_side}
	return {"ok": true, "reason_code": SUMMON_OK, "reason": "", "lane_index": requested_lane, "owner_side": owner_side}

# ── Phase 27A: Cell-based summon APIs ──

const SUMMON_CELL_OUT_OF_RANGE: StringName = &"cell_out_of_bounds"
const SUMMON_WRONG_HOME_RANK: StringName = &"wrong_home_rank"
const SUMMON_CELL_OCCUPIED: StringName = &"cell_occupied"

func get_legal_summon_cells(owner_side: StringName = &"player") -> Array[Vector2i]:
	var legal: Array[Vector2i] = []
	for cell in tactical_grid_rules.get_ordered_summon_cells(owner_side):
		if get_unit_at_cell(cell) == null and not is_cell_blocked_by_structure(cell):
			legal.append(cell)
	return legal

func get_monster_summon_cell_status(card: CardData, requested_cell: Vector2i, owner_side: StringName = &"player") -> Dictionary:
	if card == null:
		return {"ok": false, "reason_code": SUMMON_INVALID_CARD, "board_cell": requested_cell}
	if not card.is_front_row_card() or (card.card_family != "monster" and card.card_type != CardData.CardType.UNIT):
		return {"ok": false, "reason_code": SUMMON_NOT_FRONT_MONSTER, "board_cell": requested_cell}
	var play_status := get_card_play_status(card)
	if not bool(play_status.get("ok", false)):
		return {"ok": false, "reason_code": SUMMON_PLAY_BLOCKED, "reason": play_status.get("reason", "出牌条件不满足"), "board_cell": requested_cell}
	if not tactical_grid_rules.is_cell_in_bounds(requested_cell):
		return {"ok": false, "reason_code": SUMMON_CELL_OUT_OF_RANGE, "board_cell": requested_cell}
	if not tactical_grid_rules.is_normal_summon_cell(owner_side, requested_cell):
		return {"ok": false, "reason_code": SUMMON_WRONG_HOME_RANK, "board_cell": requested_cell}
	if get_unit_at_cell(requested_cell) != null:
		return {"ok": false, "reason_code": SUMMON_CELL_OCCUPIED, "board_cell": requested_cell}
	if is_cell_blocked_by_structure(requested_cell):
		return {"ok": false, "reason_code": SUMMON_CELL_OCCUPIED, "board_cell": requested_cell}
	return {"ok": true, "reason_code": SUMMON_OK, "board_cell": requested_cell, "owner_side": _normalize_owner_side(owner_side)}

func get_unit_move_status(card: CardData, target_lane: int, source: StringName = MOVE_SELF) -> Dictionary:
	if context == null:
		return {"ok": false, "reason_code": MOVE_REASON_BATTLE_ENDED, "from_lane": get_unit_lane(card), "to_lane": target_lane, "source": source, "action_consumed": false}
	if not monster_combat_rules.movement_enabled:
		return {"ok": false, "reason_code": MOVE_REASON_MOVEMENT_DISABLED, "from_lane": get_unit_lane(card), "to_lane": target_lane, "source": source, "action_consumed": false}
	if card == null:
		return {"ok": false, "reason_code": MOVE_REASON_UNIT_NOT_REGISTERED, "from_lane": -1, "to_lane": target_lane, "source": source, "action_consumed": false}
	var state: Variant = _state_for_card(card)
	if state == null:
		return {"ok": false, "reason_code": MOVE_REASON_UNIT_NOT_REGISTERED, "from_lane": -1, "to_lane": target_lane, "source": source, "action_consumed": false}
	if state.is_dead():
		return {"ok": false, "reason_code": MOVE_REASON_UNIT_DEAD, "from_lane": get_unit_lane(card), "to_lane": target_lane, "source": source, "action_consumed": false}
	if not _is_valid_front_field_unit(card, state.owner_side):
		return {"ok": false, "reason_code": MOVE_REASON_UNIT_NOT_ON_FRONT, "from_lane": get_unit_lane(card), "to_lane": target_lane, "source": source, "action_consumed": false}
	var from_lane := get_unit_lane(card)

	if source == MOVE_SELF:
		if not _core_command_player_turn_open:
			return {"ok": false, "reason_code": MOVE_REASON_NOT_PLAYER_TURN, "from_lane": from_lane, "to_lane": target_lane, "source": source, "action_consumed": false}
		if monster_combat_rules.summoning_sickness_blocks_self_move and state.summoned_this_turn:
			return {"ok": false, "reason_code": MOVE_REASON_SUMMONING_SICKNESS, "from_lane": from_lane, "to_lane": target_lane, "source": source, "action_consumed": false}

	if target_lane < 0 or target_lane >= monster_combat_rules.get_lane_count():
		return {"ok": false, "reason_code": MOVE_REASON_TARGET_OOB, "from_lane": from_lane, "to_lane": target_lane, "source": source, "action_consumed": false}

	var occupied := get_occupied_lanes(state.owner_side)
	if occupied.has(target_lane) and occupied[target_lane] != card:
		return {"ok": false, "reason_code": MOVE_REASON_TARGET_OCCUPIED, "from_lane": from_lane, "to_lane": target_lane, "source": source, "action_consumed": false}

	if not source in [MOVE_CORE_REDEPLOY, MOVE_FORCED_EFFECT]:
		var pattern := get_unit_movement_pattern(card)
		if pattern == MonsterCombatRuleSnapshotClass.PATTERN_ANCHOR:
			return {"ok": false, "reason_code": MOVE_REASON_ANCHOR, "from_lane": from_lane, "to_lane": target_lane, "source": source, "action_consumed": false}
		var legal := get_legal_move_lanes(card, source)
		if not target_lane in legal:
			var path_blocked := false
			if pattern == MonsterCombatRuleSnapshotClass.PATTERN_SLIDE:
				var step_dir := 1 if target_lane > from_lane else -1
				var check := from_lane + step_dir
				while check != target_lane and check >= 0 and check < monster_combat_rules.get_lane_count():
					if occupied.has(check):
						path_blocked = true
						break
					check += step_dir
			return {"ok": false, "reason_code": MOVE_REASON_PATH_BLOCKED if path_blocked else MOVE_REASON_PATTERN_MISMATCH, "from_lane": from_lane, "to_lane": target_lane, "source": source, "action_consumed": false}

	var action_consumed := source in [MOVE_SELF, MOVE_BOSS_AI]
	return {"ok": true, "reason_code": MOVE_OK, "from_lane": from_lane, "to_lane": target_lane, "source": source, "action_consumed": action_consumed}

func move_unit(card: CardData, target_lane: int, source: StringName = MOVE_SELF) -> Dictionary:
	var status := get_unit_move_status(card, target_lane, source)
	if not bool(status.get("ok", false)):
		return status
	var state: Variant = _state_for_card(card)
	var from_lane := get_unit_lane(card)
	var action_consumed := source in [MOVE_SELF, MOVE_BOSS_AI]
	var from_cell := get_unit_cell(card)
	var new_cell := Vector2i(target_lane, from_cell.y if from_cell != INVALID_GRID_CELL else 3)
	var height_status: Dictionary = get_height_traversal_status(from_cell, new_cell, _movement_height_options(source))
	if not bool(height_status.get("ok", false)):
		status.merge(height_status, true)
		status["action_consumed"] = false
		return status
	unit_lane_by_runtime_id[_runtime_id(card)] = target_lane
	# Phase 27A: sync cell maps
	if from_cell != INVALID_GRID_CELL:
		unit_by_cell.erase(from_cell)
	unit_cell_by_runtime_id[_runtime_id(card)] = new_cell
	unit_by_cell[new_cell] = card
	if state != null:
		state.set_board_cell(new_cell)
	if action_consumed:
		state.actions_used = clampi(state.actions_used + monster_combat_rules.self_move_action_cost, 0, monster_combat_rules.actions_per_turn)
		state.moves_used += 1
		state.last_action = &"move"
	_emit_unit_state(card)
	unit_lane_changed.emit(card, state.owner_side, from_lane, target_lane, source)
	return {
		"ok": true, "reason_code": MOVE_OK, "card": card,
		"owner_side": state.owner_side, "from_lane": from_lane,
		"to_lane": target_lane, "pattern": get_unit_movement_pattern(card),
		"source": source, "action_consumed": action_consumed,
		"opened_boss_route": state.owner_side == &"player" and not get_occupied_lanes(&"boss").has(target_lane)
	}

# ── Phase 27A: Cell move/attack APIs ──

## Phase 27C Task 3-R: Unified move command status.
## Single read-only query for UI: returns ok/reason/legal_cells/engaged in one call.
## ok=false always returns empty legal_cells to prevent phantom blue highlight.
func get_unit_move_command_status(card: CardData, source: StringName = MOVE_SELF) -> Dictionary:
	var base := {
		"ok": false,
		"reason_code": &"state_missing",
		"reason_text": "单位状态不可用",
		"legal_cells": [] as Array[Vector2i],
		"actions_remaining": 0,
		"engaged": false,
	}
	if card == null:
		base.reason_code = &"card_missing"
		base.reason_text = "卡牌不存在"
		return base
	var state: Variant = _state_for_card(card)
	if state == null:
		return base
	if state.is_dead():
		base.reason_code = &"unit_dead"
		base.reason_text = "单位已阵亡"
		return base
	var origin := get_unit_cell(card)
	if origin == INVALID_GRID_CELL:
		base.reason_code = &"not_on_board"
		base.reason_text = "单位不在棋盘上"
		return base
	base.actions_remaining = maxi(0, monster_combat_rules.actions_per_turn - state.actions_used)
	base.engaged = is_unit_engaged(card)

	# Check core_command_player_turn_open for self-move
	if source == MOVE_SELF:
		if not _core_command_player_turn_open:
			base.reason_code = &"not_player_turn"
			base.reason_text = "非玩家回合"
			return base
		if monster_combat_rules.summoning_sickness_blocks_self_move and state.summoned_this_turn:
			base.reason_code = &"summoning_sickness"
			base.reason_text = "刚登场，本回合不能移动"
			return base
		if tactical_core_facing_rules.engagement_locks_self_move() and base.engaged:
			base.reason_code = &"engaged"
			base.reason_text = "正被敌方牵制，需先处理交战"
			return base

	# Compute geometric legal cells
	var cells: Array[Vector2i] = []
	if source in [MOVE_CORE_REDEPLOY, MOVE_FORCED_EFFECT]:
		for cell in tactical_grid_rules.get_all_cells():
			if get_unit_at_cell(cell) == null and not is_cell_blocked_by_structure(cell) and bool(get_height_traversal_status(origin, cell, _movement_height_options(source)).get("ok", false)):
				cells.append(cell)
	else:
		cells = _get_pattern_move_cells(card, origin, state.owner_side, source)

	base.legal_cells = cells
	if cells.is_empty():
		base.reason_code = &"no_legal_cell"
		base.reason_text = "没有符合棋型的空格"
		base.ok = false
		return base

	base.ok = true
	base.reason_code = &"ok"
	base.reason_text = "可移动"
	return base


func get_legal_move_cells(card: CardData, source: StringName = MOVE_SELF) -> Array[Vector2i]:
	var state: Variant = _state_for_card(card)
	if state == null:
		return []
	var origin := get_unit_cell(card)
	if origin == INVALID_GRID_CELL:
		return []
	if source in [MOVE_CORE_REDEPLOY, MOVE_FORCED_EFFECT]:
		var result: Array[Vector2i] = []
		for cell in tactical_grid_rules.get_all_cells():
			if get_unit_at_cell(cell) == null and not is_cell_blocked_by_structure(cell) and bool(get_height_traversal_status(origin, cell, _movement_height_options(source)).get("ok", false)):
				result.append(cell)
		return result
	# Phase 27B: use pattern snapshot for player/Boss movement; fallback to compatibility
	var candidates: Array[Vector2i] = _get_pattern_move_cells(card, origin, state.owner_side, source)
	if edge_fortification_trial != null:
		for candidate: Vector2i in candidates.duplicate():
			if not edge_fortification_trial.can_traverse(origin, candidate, state.owner_side):
				candidates.erase(candidate)
	return candidates

func _get_pattern_move_cells(card: CardData, origin: Vector2i, owner_side: StringName, source: StringName) -> Array[Vector2i]:
	var offsets: Array[Vector2i] = tactical_pattern_snapshot.get_movement_offsets(get_unit_tactical_pattern(card))
	if offsets.is_empty():
		var compatibility: Array[Vector2i] = []
		for candidate in tactical_grid_rules.get_compatibility_move_cells(origin, owner_side, get_occupied_cells()):
			if not is_cell_blocked_by_structure(candidate) and bool(get_height_traversal_status(origin, candidate, _movement_height_options(source)).get("ok", false)):
				compatibility.append(candidate)
		return compatibility
	var result: Array[Vector2i] = []
	## Phase 27C: apply unit-facing correction if unit has turned
	var facing: int = _get_unit_facing_checked(card, owner_side)
	var default_facing: int = tactical_core_facing_rules.get_default_facing(owner_side)
	## Phase 27I-R0: P05 阻挡锚点视为占用格
	var blockers: Dictionary = _get_blocking_piece_cells()
	for off in offsets:
		var oriented: Vector2i = tactical_grid_rules.orient_offset(owner_side, off)
		if facing != 0 and facing != default_facing:
			oriented.y = -oriented.y
		var candidate: Vector2i = origin + oriented
		if tactical_grid_rules.is_cell_in_bounds(candidate) \
		and get_unit_at_cell(candidate) == null \
		and not blockers.has(candidate) \
		and not is_cell_blocked_by_structure(candidate) \
		and bool(get_height_traversal_status(origin, candidate, _movement_height_options(source)).get("ok", false)):
			result.append(candidate)
	return result


func _movement_height_options(source: StringName) -> Dictionary:
	if source in [MOVE_CORE_REDEPLOY, MOVE_FORCED_EFFECT]:
		return {"ignore_height_gap": true}
	return {}

# ── Phase 27B reason code mapper ──

func _to_27b_move_reason(rc: StringName) -> StringName:
	match rc:
		MOVE_OK: return REASON_OK
		MOVE_REASON_UNIT_NOT_REGISTERED: return REASON_STATE_MISSING
		MOVE_REASON_UNIT_DEAD: return REASON_STATE_MISSING
		MOVE_REASON_UNIT_NOT_ON_FRONT: return REASON_STATE_MISSING
		MOVE_REASON_SUMMONING_SICKNESS: return REASON_SUMMONING_SICKNESS
		MOVE_REASON_ACTION_ALREADY_USED: return REASON_ACTION_SPENT
		MOVE_REASON_TARGET_OOB: return REASON_OUT_OF_BOUNDS
		MOVE_REASON_TARGET_OCCUPIED: return REASON_OCCUPIED
		MOVE_REASON_PATTERN_MISMATCH: return REASON_OUT_OF_PATTERN
		MOVE_REASON_HEIGHT_GAP: return MOVE_REASON_HEIGHT_GAP
		_: return rc

func get_unit_move_cell_status(card: CardData, target_cell: Vector2i, source: StringName = MOVE_SELF) -> Dictionary:
	var from_cell: Vector2i = get_unit_cell(card)
	var base := {
		"ok": false,
		"reason_code": MOVE_REASON_UNIT_NOT_REGISTERED,
		"reason": _to_27b_move_reason(MOVE_REASON_UNIT_NOT_REGISTERED),
		"from_cell": from_cell,
		"to_cell": target_cell,
		"source": source,
		"action_consumed": false,
	}
	if context == null:
		base.reason_code = MOVE_REASON_BATTLE_ENDED
		base.reason = _to_27b_move_reason(MOVE_REASON_BATTLE_ENDED)
		return base
	if not monster_combat_rules.movement_enabled:
		base.reason_code = MOVE_REASON_MOVEMENT_DISABLED
		base.reason = _to_27b_move_reason(MOVE_REASON_MOVEMENT_DISABLED)
		return base
	if card == null:
		return base
	var state: Variant = _state_for_card(card)
	if state == null or from_cell == INVALID_GRID_CELL:
		return base
	if state.is_dead():
		base.reason_code = MOVE_REASON_UNIT_DEAD
		base.reason = _to_27b_move_reason(MOVE_REASON_UNIT_DEAD)
		return base
	if not _is_valid_front_field_unit(card, state.owner_side):
		base.reason_code = MOVE_REASON_UNIT_NOT_ON_FRONT
		base.reason = _to_27b_move_reason(MOVE_REASON_UNIT_NOT_ON_FRONT)
		return base
	var garrison_assignment: Dictionary = get_garrison_state_for_unit(card)
	if not garrison_assignment.is_empty() and StringName(str(garrison_assignment.get("state", &""))) in [&"active", &"displaced_pending_exit"]:
		base.reason_code = &"garrison_forced_move_blocked"
		base.reason = _garrison_reason_text(&"garrison_forced_move_blocked")
		return base

	if source == MOVE_SELF:
		if not _core_command_player_turn_open:
			base.reason_code = MOVE_REASON_NOT_PLAYER_TURN
			base.reason = _to_27b_move_reason(MOVE_REASON_NOT_PLAYER_TURN)
			return base
		if monster_combat_rules.summoning_sickness_blocks_self_move and state.summoned_this_turn:
			base.reason_code = MOVE_REASON_SUMMONING_SICKNESS
			base.reason = _to_27b_move_reason(MOVE_REASON_SUMMONING_SICKNESS)
			return base
		# Phase 27C Task 4: engaged units cannot ordinary self-move
		# Phase 27I-R0: 骑士棋路移动忽略普通牵制（不绕过其他硬限制）
		var pattern_id: StringName = get_unit_tactical_pattern(card)
		var ignores_engagement: bool = tactical_pattern_snapshot.ignores_engagement_for_move(pattern_id)
		if not ignores_engagement and tactical_core_facing_rules.engagement_locks_self_move() and is_unit_engaged(card):
			base.reason_code = MOVE_REASON_ANCHOR
			base.reason = "Engaged: cannot move while in enemy attack range"
			return base

	if not tactical_grid_rules.is_cell_in_bounds(target_cell):
		base.reason_code = MOVE_REASON_TARGET_OOB
		base.reason = _to_27b_move_reason(MOVE_REASON_TARGET_OOB)
		return base
	var occupant: CardData = get_unit_at_cell(target_cell)
	if occupant != null and occupant != card:
		base.reason_code = MOVE_REASON_TARGET_OCCUPIED
		base.reason = _to_27b_move_reason(MOVE_REASON_TARGET_OCCUPIED)
		return base
	if is_cell_blocked_by_structure(target_cell):
		base.reason_code = MOVE_REASON_TARGET_OCCUPIED
		base.reason = "Blocked by structure core"
		return base
	if edge_fortification_trial != null and source not in [MOVE_CORE_REDEPLOY, MOVE_FORCED_EFFECT] and not edge_fortification_trial.can_traverse(from_cell, target_cell, state.owner_side):
		base.reason_code = &"edge_ground_path_blocked"
		base.reason = "Closed fortification blocks this ground path"
		return base
	var height_status: Dictionary = get_height_traversal_status(from_cell, target_cell, _movement_height_options(source))
	if not bool(height_status.get("ok", false)):
		base.reason_code = StringName(str(height_status.get("reason_code", MOVE_REASON_HEIGHT_GAP)))
		base.reason = _to_27b_move_reason(base.reason_code)
		return base

	# Phase 27I-R0: P05 阻挡锚点格视为被占用
	if not source in [MOVE_CORE_REDEPLOY, MOVE_FORCED_EFFECT]:
		var blockers: Dictionary = _get_blocking_piece_cells()
		if blockers.has(target_cell):
			base.reason_code = MOVE_REASON_TARGET_OCCUPIED
			base.reason = "Blocked by piece anchor"
			return base

	if not source in [MOVE_CORE_REDEPLOY, MOVE_FORCED_EFFECT]:
		var legal: Array[Vector2i] = get_legal_move_cells(card, source)
		if not target_cell in legal:
			base.reason_code = MOVE_REASON_PATTERN_MISMATCH
			base.reason = _to_27b_move_reason(MOVE_REASON_PATTERN_MISMATCH)
			return base

	base.ok = true
	base.reason_code = MOVE_OK
	base.reason = REASON_OK
	base.action_consumed = source in [MOVE_SELF, MOVE_BOSS_AI]
	return base

func move_unit_to_cell(card: CardData, target_cell: Vector2i, source: StringName = MOVE_SELF) -> Dictionary:
	var status := get_unit_move_cell_status(card, target_cell, source)
	if not bool(status.get("ok", false)):
		return status
	var state: Variant = _state_for_card(card)
	var action_consumed := source in [MOVE_SELF, MOVE_BOSS_AI]
	if source == MOVE_BOSS_AI and reaction_trial != null and reaction_trial.intercept_move(card, target_cell):
		state.actions_used = clampi(state.actions_used + monster_combat_rules.self_move_action_cost, 0, monster_combat_rules.actions_per_turn)
		state.moves_used += 1
		state.last_action = &"move"
		_emit_unit_state(card)
		status.merge({"card": card, "intercepted": true, "action_consumed": true, "message": "断频伏线触发：本次移动被阻止"}, true)
		return status
	var edge_origin: Vector2i = get_unit_cell(card)
	var write_result := _assign_unit_cell_atomic(card, target_cell, source, true)
	if not bool(write_result.get("ok", false)):
		status.merge(write_result, true)
		return status
	if edge_fortification_trial != null and action_consumed:
		edge_fortification_trial.record_passage(card, edge_origin, target_cell)
	if action_consumed:
		state.actions_used = clampi(state.actions_used + monster_combat_rules.self_move_action_cost, 0, monster_combat_rules.actions_per_turn)
		state.moves_used += 1
		state.last_action = &"move"
		if source == MOVE_SELF and state.owner_side == &"player":
			_on_normal_move_completed(card)
		_emit_unit_state(card)
	status.merge({"card": card, "owner_side": state.owner_side, "action_consumed": action_consumed}, true)
	return status

func get_legal_attack_cells(attacker: CardData) -> Array[Vector2i]:
	var result: Array[Vector2i] = _get_base_legal_attack_cells(attacker)
	return _extend_garrison_normal_attack_cells(attacker, result)


func _get_base_legal_attack_cells(attacker: CardData, origin_override: Vector2i = INVALID_GRID_CELL) -> Array[Vector2i]:
	var state: Variant = _state_for_card(attacker)
	if state == null:
		return []
	var origin := get_unit_cell(attacker) if origin_override == INVALID_GRID_CELL else origin_override
	var base: Array[Vector2i] = _get_pattern_attack_cells(attacker, origin, state.owner_side)
	# Phase 27I-R1: 主教赋刃 → 攻击格 = 原始 ∪ 主教斜线（去重）
	if _get_bishop_enchant(attacker).is_empty():
		return base
	var result := base.duplicate()
	for c in _bishop_ray_attack_cells(attacker, origin, state.owner_side):
		if not result.has(c):
			result.append(c)
	return result


func _garrison_assignment_support_intact(assignment: Dictionary) -> bool:
	if StringName(str(assignment.get("state", &""))) != &"active":
		return false
	var structure_id := StringName(str(assignment.get("structure_id", &"")))
	var structure_value: Variant = get_structure_snapshot().get("structures", {}).get(structure_id, null)
	if not structure_value is Dictionary:
		return false
	var structure: Dictionary = structure_value
	if int(structure.get("integrity_current", 0)) <= 0 or StringName(str(structure.get("status", &""))) == &"destroyed":
		return false
	var slot_profile: Dictionary = tactical_garrison_rules.get_slot_profile(
		StringName(str(structure.get("profile_id", &""))),
		StringName(str(assignment.get("slot_id", &"")))
	)
	var support: Dictionary = _garrison_support_module(structure, slot_profile)
	return not support.is_empty() \
		and StringName(str(support.get("module_id", &""))) == StringName(str(assignment.get("support_module_id", &""))) \
		and int(support.get("integrity_current", 0)) > 0 \
		and StringName(str(support.get("status", &""))) != &"destroyed"


## Shared, target-aware normal-attack extension used by preview and execution.
## It never changes the global tactical pattern snapshot.
func _extend_garrison_normal_attack_cells(attacker: CardData, base_cells: Array[Vector2i]) -> Array[Vector2i]:
	var result: Array[Vector2i] = base_cells.duplicate()
	if attacker == null or tactical_garrison_rules == null:
		return result
	var state: Variant = _state_for_card(attacker)
	if state == null or state.is_dead():
		return result
	var assignment: Dictionary = get_garrison_state_for_unit(attacker)
	if not _garrison_assignment_support_intact(assignment):
		return result
	if int(assignment.get("entered_turn", -1)) == int(context.get_turn_number() if context != null else -2):
		return result
	if not bool(can_monster_attack(attacker).get("ok", false)):
		return result
	var unit_profile: Dictionary = tactical_garrison_rules.get_unit_profile(StringName(str(attacker.card_id)))
	var range_profile: Dictionary = tactical_garrison_rules.get_range_profile(
		StringName(str(unit_profile.get("range_profile_id", &"none")))
	)
	if range_profile.is_empty() \
	or StringName(str(range_profile.get("applies_to", &""))) != &"normal_attack" \
	or not bool(range_profile.get("requires_strict_height_advantage", false)):
		return result
	var attacker_height: int = get_unit_effective_board_height(attacker)
	var origin: Vector2i = get_unit_cell(attacker)
	var facing: int = _get_unit_facing_checked(attacker, state.owner_side)
	var default_facing: int = tactical_core_facing_rules.get_default_facing(state.owner_side)
	for raw_offset in range_profile.get("extra_attack_offsets", []):
		if not raw_offset is Vector2i:
			continue
		var oriented: Vector2i = tactical_grid_rules.orient_offset(state.owner_side, raw_offset)
		if facing != 0 and facing != default_facing:
			oriented.y = -oriented.y
		var candidate: Vector2i = origin + oriented
		if not tactical_grid_rules.is_cell_in_bounds(candidate) or result.has(candidate):
			continue
		var target: CardData = get_unit_at_cell(candidate)
		if target == null:
			continue
		var target_state: Variant = _state_for_card(target)
		if target_state == null or target_state.is_dead() or target_state.owner_side == state.owner_side:
			continue
		if attacker_height > get_unit_effective_board_height(target):
			result.append(candidate)
	return result

func _get_pattern_attack_cells(attacker: CardData, origin: Vector2i, owner_side: StringName) -> Array[Vector2i]:
	var offsets: Array[Vector2i] = tactical_pattern_snapshot.get_attack_offsets(get_unit_tactical_pattern(attacker))
	if offsets.is_empty():
		var compatibility: Array[Vector2i] = []
		for candidate in tactical_grid_rules.get_compatibility_attack_cells(origin, owner_side):
			if bool(get_height_traversal_status(origin, candidate).get("ok", false)):
				compatibility.append(candidate)
		return compatibility
	var result: Array[Vector2i] = []
	## Phase 27C: apply unit-facing correction if unit has turned
	var facing: int = _get_unit_facing_checked(attacker, owner_side)
	var default_facing: int = tactical_core_facing_rules.get_default_facing(owner_side)
	for off in offsets:
		var oriented: Vector2i = tactical_grid_rules.orient_offset(owner_side, off)
		if facing != 0 and facing != default_facing:
			oriented.y = -oriented.y
		var candidate: Vector2i = origin + oriented
		if tactical_grid_rules.is_cell_in_bounds(candidate) and bool(get_height_traversal_status(origin, candidate).get("ok", false)):
			result.append(candidate)
	return result

# ── Phase 27B: Cell-authoritative attack status ──

func get_unit_attack_cell_status(attacker: CardData, target: CardData, include_garrison_range: bool = true, origin_override: Vector2i = INVALID_GRID_CELL) -> Dictionary:
	var base := {
		"ok": false,
		"reason": REASON_STATE_MISSING,
		"reason_code": MOVE_REASON_UNIT_NOT_REGISTERED,
		"attacker_cell": INVALID_GRID_CELL,
		"target_cell": INVALID_GRID_CELL,
		"pattern_id": tactical_pattern_snapshot.default_pattern_id,
	}
	if attacker == null:
		base.reason = REASON_CARD_MISSING
		return base
	var atk_state: Variant = _state_for_card(attacker)
	if atk_state == null:
		return base
	var atk_cell := get_unit_cell(attacker) if origin_override == INVALID_GRID_CELL else origin_override
	if atk_cell == INVALID_GRID_CELL:
		return base
	base.attacker_cell = atk_cell
	base.pattern_id = get_unit_tactical_pattern(attacker)
	if atk_state.summoned_this_turn:
		base.reason = REASON_SUMMONING_SICKNESS
		return base
	var entered_assignment: Dictionary = get_garrison_state_for_unit(attacker)
	if origin_override != INVALID_GRID_CELL and origin_override != get_unit_cell(attacker) \
	and StringName(str(entered_assignment.get("state", &""))) == &"active":
		base.reason = &"special_range_requires_commit"
		base.reason_code = &"special_range_requires_commit"
		return base
	if StringName(str(entered_assignment.get("state", &""))) == &"active" \
	and int(entered_assignment.get("entered_turn", -1)) == int(context.get_turn_number() if context != null else -2):
		base.reason = &"garrison_entered_this_turn"
		base.reason_code = &"garrison_entered_this_turn"
		return base

	if target == null:
		base.reason = REASON_TARGET_MISSING
		return base

	var tgt_state: Variant = _state_for_card(target)
	if tgt_state == null or tgt_state.is_dead():
		base.reason = REASON_TARGET_MISSING
		return base

	var tgt_cell := get_unit_cell(target)
	if tgt_cell == INVALID_GRID_CELL:
		base.reason = REASON_TARGET_MISSING
		return base
	base.target_cell = tgt_cell
	if tgt_state.owner_side == atk_state.owner_side:
		base.reason = REASON_FRIENDLY_TARGET
		return base

	var base_attack_cells: Array[Vector2i] = _get_base_legal_attack_cells(attacker, origin_override)
	var attack_cells: Array[Vector2i] = base_attack_cells
	if include_garrison_range:
		attack_cells = _extend_garrison_normal_attack_cells(attacker, base_attack_cells)
	var is_garrison_bonus: bool = include_garrison_range \
		and tgt_cell in attack_cells and not tgt_cell in base_attack_cells
	if not is_garrison_bonus:
		var height_status: Dictionary = get_height_traversal_status(atk_cell, tgt_cell)
		if not bool(height_status.get("ok", false)):
			base.reason = MOVE_REASON_HEIGHT_GAP
			base.reason_code = MOVE_REASON_HEIGHT_GAP
			return base
	if not tgt_cell in attack_cells:
		base.reason = REASON_OUT_OF_PATTERN
		return base

	if edge_fortification_trial != null and edge_fortification_trial.blocks_close_attack(atk_cell, tgt_cell):
		base.reason = &"edge_close_attack_blocked"
		base.reason_code = &"edge_close_attack_blocked"
		return base
	base.ok = true
	base.reason = REASON_OK
	return base

# ── Phase 27B: Core attack status (enemy-territory + front-arc blocker) ──

func get_core_attack_cell_status(attacker: CardData) -> Dictionary:
	var base := {
		"ok": false,
		"reason": REASON_STATE_MISSING,
		"attacker_cell": INVALID_GRID_CELL,
		"pattern_id": tactical_pattern_snapshot.default_pattern_id,
		"facing_rank_delta": 0,
		"interceptor_runtime_id": 0,
	}
	if attacker == null:
		base.reason = REASON_CARD_MISSING
		return base
	var atk_state: Variant = _state_for_card(attacker)
	if atk_state == null:
		return base
	var atk_cell := get_unit_cell(attacker)
	if atk_cell == INVALID_GRID_CELL:
		return base
	base.attacker_cell = atk_cell
	base.pattern_id = get_unit_tactical_pattern(attacker)
	var owner_side: StringName = atk_state.owner_side
	base.facing_rank_delta = atk_state.get_facing_rank_delta()


	if atk_state.summoned_this_turn:
		base.reason = REASON_SUMMONING_SICKNESS
		return base

	# Phase 27C Task 4: require exact breach rank
	var breach_rank: int = tactical_core_facing_rules.get_breach_rank(owner_side)
	if atk_cell.y != breach_rank:
		base.reason = REASON_NOT_BREACH_RANK
		return base

	# Phase 27C Task 4: require facing toward enemy core
	var required_facing: int = tactical_core_facing_rules.get_default_facing(owner_side)
	if atk_state.get_facing_rank_delta() != required_facing:
		base.reason = REASON_FACING_AWAY_FROM_CORE
		return base

	# Phase 27C Task 4: Guard interception check
	var interceptor: CardData = _find_guard_interceptor(attacker, owner_side)
	if interceptor != null:
		base.reason = REASON_GUARD_INTERCEPTED
		base.interceptor_runtime_id = interceptor.get_instance_id()
		return base

	var attack_cells: Array[Vector2i] = _get_pattern_attack_cells(attacker, atk_cell, owner_side)
	for cell in attack_cells:
		var occupant: Variant = get_unit_at_cell(cell)
		if occupant != null:
			var occ_state: Variant = _state_for_card(occupant)
			if occ_state != null and not occ_state.is_dead() and occ_state.owner_side != owner_side:
				base.reason = REASON_FRONT_ARC_BLOCKED
				return base

	base.ok = true
	base.reason = REASON_OK
	return base

# ── Phase 27B: Deterministic mirrored Boss tactical decision ──

func get_boss_tactical_decision(card: CardData) -> Dictionary:
	var blank := {"ok": false, "action": &"none", "reason": REASON_STATE_MISSING,
		"from_cell": INVALID_GRID_CELL}
	var state: Variant = _state_for_card(card)
	if state == null or state.owner_side != &"boss" or state.is_dead():
		return blank
	var from_cell := get_unit_cell(card)
	if from_cell == INVALID_GRID_CELL:
		return blank
	blank.from_cell = from_cell


	# Phase 27C Priority 0: attack player core if on breach rank
	var core_status: Dictionary = get_core_attack_cell_status(card)
	if bool(core_status.get("ok", false)):
		return {"ok": true, "action": &"core_attack", "target": null, "from_cell": from_cell, "reason": REASON_OK}

	# Priority 1: attack enemies in front arc
	var attack_cells: Array[Vector2i] = _get_pattern_attack_cells(card, from_cell, state.owner_side)
	var candidates: Array[Dictionary] = []
	for cell in attack_cells:
		var occupant: Variant = get_unit_at_cell(cell)
		if occupant == null:
			continue
		var occ_state: Variant = _state_for_card(occupant)
		if occ_state == null or occ_state.is_dead() or occ_state.owner_side == &"boss":
			continue
		candidates.append({"target": occupant, "hp": occ_state.current_hp, "cell": cell, "col": cell.x})

	if not candidates.is_empty():
		# Sort: lowest HP → center column (front cell) → lowest column
		candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			if a.hp != b.hp: return a.hp < b.hp
			var a_center := 1 if a.cell.x == from_cell.x else 0
			var b_center := 1 if b.cell.x == from_cell.x else 0
			if a_center != b_center: return a_center > b_center
			return a.col < b.col)
		var best: Dictionary = candidates[0]
		return {"ok": true, "action": &"attack", "target": best.target, "target_cell": best.cell,
			"from_cell": from_cell, "reason": REASON_OK}

	# Phase 27C Priority 1.5: turn for rear defense if enemies behind
	var turn_status: Dictionary = get_unit_turn_status(card)
	if bool(turn_status.get("ok", false)):
		# Check if there are player units behind (rank > from_cell.y for boss)
		var player_behind := false
		for key in unit_by_cell:
			var occ: Variant = unit_by_cell[key]
			if occ != null:
				var os: Variant = _state_for_card(occ)
				if os != null and not os.is_dead() and os.owner_side == &"player" and key.y > from_cell.y:
					player_behind = true
					break
		if player_behind:
			var turn_result: Dictionary = turn_unit_for_rear_defense(card)
			if bool(turn_result.get("ok", false)):
				return {"ok": true, "action": &"turn", "target": null, "from_cell": from_cell, "reason": REASON_OK}

	# Priority 2: move forward; if blocked, side toward nearest player
	var move_offsets: Array[Vector2i] = tactical_pattern_snapshot.get_movement_offsets(get_unit_tactical_pattern(card))
	var legal_moves: Array[Vector2i] = []
	for off in move_offsets:
		var oriented: Vector2i = tactical_grid_rules.orient_offset(&"boss", off)
		var candidate: Vector2i = from_cell + oriented
		if tactical_grid_rules.is_cell_in_bounds(candidate) \
		and get_unit_at_cell(candidate) == null \
		and bool(get_height_traversal_status(from_cell, candidate).get("ok", false)):
			legal_moves.append(candidate)

	if legal_moves.is_empty():
		blank.reason = REASON_OUT_OF_PATTERN
		return blank

	# Collect player unit cells for distance
	var player_cells: Array[Vector2i] = []
	for key in unit_by_cell:
		var occ: Variant = unit_by_cell[key]
		if occ != null:
			var os: Variant = _state_for_card(occ)
			if os != null and not os.is_dead() and os.owner_side == &"player":
				player_cells.append(key)

	# Sort: forward (rank+1 for boss) preferred; tie-break by distance to nearest player
	var boss_forward_dir := Vector2i(0, 1)  # boss forward is rank+1
	legal_moves.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var a_fwd := 1 if (a - from_cell) == boss_forward_dir else 0
		var b_fwd := 1 if (b - from_cell) == boss_forward_dir else 0
		if a_fwd != b_fwd: return a_fwd > b_fwd
		var da := 999
		var db := 999
		for pc in player_cells:
			da = mini(da, absi(a.x - pc.x) + absi(a.y - pc.y))
			db = mini(db, absi(b.x - pc.x) + absi(b.y - pc.y))
		return da < db if da != db else a.x < b.x)

	return {"ok": true, "action": &"move", "from_cell": from_cell, "to_cell": legal_moves[0],
		"source": MOVE_BOSS_AI, "reason": REASON_OK}

func reset_player_turn_core_command() -> void:
	_core_command_player_turn_open = true
	_core_command_used_this_player_turn = false
	clear_all_player_temporary_attack_bonuses()


func close_player_turn_core_command() -> void:
	_core_command_player_turn_open = false
	clear_all_player_temporary_attack_bonuses()
	if basic_card_trial!=null: basic_card_trial.clear_blades()


func get_core_command_state() -> Dictionary:
	var limit: int = od_core_command_rules.get_uses_per_player_turn() if od_core_command_rules else 0
	return {
		"used": 1 if _core_command_used_this_player_turn else 0,
		"limit": limit,
		"player_turn_open": _core_command_player_turn_open,
	}


## 权威攻击力查询：读取 UnitCombatState 的临时加成
func get_effective_unit_attack(card) -> int:
	if card == null:
		return 0
	var base_attack := int(card.unit_power)
	var state = _state_for_card(card)
	if state == null:
		return base_attack
	return state.get_effective_attack(base_attack)


func clear_all_player_temporary_attack_bonuses() -> void:
	for state in unit_combat_states.values():
		if state != null and state.owner_side == &"player":
			state.clear_temporary_attack_bonus()


## 验证指令合法性（不修改任何状态）
func get_core_command_status(command_id: StringName, target = null) -> Dictionary:
	# PHASE55_BEGIN_STATUS
	if _core_command_resolving:return _core_status(false, &"core_command_busy", command_id)
	# PHASE55_END_STATUS
	if od_core_command_rules == null or not od_core_command_rules.has_command(command_id):
		return _core_status(false, CORE_UNKNOWN_COMMAND, command_id)
	if not _core_command_player_turn_open:
		return _core_status(false, CORE_NOT_PLAYER_TURN, command_id)
	if _core_command_used_this_player_turn:
		return _core_status(false, CORE_ALREADY_USED, command_id)
	if context == null:
		return _core_status(false, &"context_missing", command_id)
	if context.is_abyss_locked() and not od_core_command_rules.is_usable_during_backlash(command_id):
		return _core_status(false, CORE_BACKLASH_RESTRICTED, command_id)

	var cost: int = od_core_command_rules.get_charge_cost(command_id)
	if not context.can_spend_engine_charge(cost):
		return _core_status(false, CORE_INSUFFICIENT_CHARGE, command_id)

	if command_id == ODCoreCommandRuleSnapshotClass.SURGE:
		return _get_surge_target_status(target)
	if command_id == ODCoreCommandRuleSnapshotClass.VENT:
		if context.depth_pressure <= 0:
			return _core_status(false, CORE_DEPTH_ALREADY_ZERO, command_id)
		return _core_status(true, CORE_OK, command_id)
	if command_id == ODCoreCommandRuleSnapshotClass.REDEPLOY:
		return _get_redeploy_target_status(target)
	return _core_status(false, CORE_UNKNOWN_COMMAND, command_id)


func _get_redeploy_target_status(target) -> Dictionary:
		# PHASE55_BEGIN_TERMINAL
		if context==null or context.player==null or context.enemy==null or context.player.hp<=0 or context.enemy.hp<=0:return _core_status(false, &"battle_ended", ODCoreCommandRuleSnapshotClass.REDEPLOY)
		# PHASE55_END_TERMINAL
		if target == null or not target is Dictionary:
			return _core_status(false, CORE_INVALID_TARGET, ODCoreCommandRuleSnapshotClass.REDEPLOY)
		var card: Variant = target.get("card")
		# PHASE55_BEGIN_CELL_STATUS
		if not card is CardData or card not in context.player.field:return _core_status(false, CORE_INVALID_TARGET, ODCoreCommandRuleSnapshotClass.REDEPLOY)
		var state: Variant=_state_for_card(card)
		if state==null or state.owner_side!=&"player" or state.current_hp<=0:return _core_status(false, CORE_INVALID_TARGET, ODCoreCommandRuleSnapshotClass.REDEPLOY)
		if target.has("cell"):
			if not target.cell is Vector2i:return _core_status(false, CORE_INVALID_TARGET, ODCoreCommandRuleSnapshotClass.REDEPLOY)
			var cell_status: Dictionary=get_unit_move_cell_status(card,target.cell,MOVE_CORE_REDEPLOY)
			return _core_status(cell_status.get("ok",false),StringName(cell_status.get("reason_code",CORE_INVALID_TARGET)),ODCoreCommandRuleSnapshotClass.REDEPLOY)
		# PHASE55_END_CELL_STATUS
		var lane: int = int(target.get("lane_index", -1))
		if card == null:
			return _core_status(false, CORE_INVALID_TARGET, ODCoreCommandRuleSnapshotClass.REDEPLOY)
		var move_status := get_unit_move_status(card, lane, MOVE_CORE_REDEPLOY)
		if not bool(move_status.get("ok", false)):
			return _core_status(false, StringName(move_status.get("reason_code", CORE_INVALID_TARGET)), ODCoreCommandRuleSnapshotClass.REDEPLOY)
		return _core_status(true, CORE_OK, ODCoreCommandRuleSnapshotClass.REDEPLOY)


# PHASE55_BEGIN_PAID_STATUS
func _get_paid_redeploy_status(target: Dictionary, commit_turn: int) -> Dictionary:
	if context==null or context.turn_count!=commit_turn or not _core_command_player_turn_open:return _core_status(false,CORE_NOT_PLAYER_TURN,ODCoreCommandRuleSnapshotClass.REDEPLOY)
	if _core_command_used_this_player_turn:return _core_status(false,CORE_ALREADY_USED,ODCoreCommandRuleSnapshotClass.REDEPLOY)
	if context.is_abyss_locked():return _core_status(false,CORE_BACKLASH_RESTRICTED,ODCoreCommandRuleSnapshotClass.REDEPLOY)
	return _get_redeploy_target_status(target)
# PHASE55_END_PAID_STATUS
func _get_surge_target_status(target) -> Dictionary:
		if target == null:
			return _core_status(false, CORE_INVALID_TARGET, ODCoreCommandRuleSnapshotClass.SURGE)
		var state: UnitCombatStateClass = _state_for_card(target)
		if state == null:
			return _core_status(false, CORE_INVALID_TARGET, ODCoreCommandRuleSnapshotClass.SURGE)
		if state.owner_side != &"player":
			return _core_status(false, CORE_INVALID_TARGET, ODCoreCommandRuleSnapshotClass.SURGE)
		if state.current_hp <= 0:
			return _core_status(false, CORE_INVALID_TARGET, ODCoreCommandRuleSnapshotClass.SURGE)
		if state.summoned_this_turn:
			return _core_status(false, CORE_INVALID_TARGET, ODCoreCommandRuleSnapshotClass.SURGE)
		var snap: Dictionary = state.snapshot(monster_combat_rules.max_attacks_per_turn, monster_combat_rules.actions_per_turn)
		if bool(snap.get("has_attacked_this_turn", false)):
			return _core_status(false, CORE_TARGET_ALREADY_ATTACKED, ODCoreCommandRuleSnapshotClass.SURGE)
		return _core_status(true, CORE_OK, ODCoreCommandRuleSnapshotClass.SURGE)


## 原子执行核心指令
func execute_core_command(command_id: StringName, target = null) -> Dictionary:
	# PHASE55_BEGIN_FREEZE
	if target is Dictionary:target=target.duplicate(true)
	# PHASE55_END_FREEZE
	var status := get_core_command_status(command_id, target)
	if not bool(status.get("ok", false)):
		return _core_failure_result(command_id, status.get("reason_code", CORE_INVALID_TARGET), target)

	# PHASE55_BEGIN_COMMIT
	var commit_turn: int=context.turn_count
	_core_command_resolving=true
	# PHASE55_END_COMMIT
	var before := _capture_core_command_before_state(command_id, target)
	var cost: int = od_core_command_rules.get_charge_cost(command_id)
	var spend: Dictionary = context.spend_engine_charge(cost, StringName("core_command:%s" % command_id))
	if not bool(spend.get("ok", false)):
		# PHASE55_BEGIN_SPEND_FAIL
		_core_command_resolving=false
		# PHASE55_END_SPEND_FAIL
		return _core_failure_result(command_id, spend.get("reason_code", CORE_INSUFFICIENT_CHARGE), target)

	# PHASE55_BEGIN_RECHECK
	if command_id==ODCoreCommandRuleSnapshotClass.REDEPLOY:
		var current: Dictionary=_get_paid_redeploy_status(target,commit_turn)
		if not current.get("ok",false):
			context.refund_engine_charge(cost,&"core_command:redeploy_refund")
			_core_command_resolving=false
			return _core_failure_result(command_id,current.get("reason_code",CORE_INVALID_TARGET),target)
	# PHASE55_END_RECHECK
	if command_id == ODCoreCommandRuleSnapshotClass.SURGE:
		var effect: Dictionary = od_core_command_rules.get_effect(command_id)
		var st: UnitCombatStateClass = _state_for_card(target)
		if st != null:
			st.add_temporary_attack_bonus(int(effect.get("amount", 0)))
	elif command_id == ODCoreCommandRuleSnapshotClass.VENT:
		var effect: Dictionary = od_core_command_rules.get_effect(command_id)
		context.modify_depth(-int(effect.get("amount", 0)), "core_command:vent")
	elif command_id == ODCoreCommandRuleSnapshotClass.REDEPLOY:
		var tgt: Dictionary = target as Dictionary
		var tgt_card: Variant = tgt.get("card")
		var tgt_lane: int = int(tgt.get("lane_index", -1))
		var move_result: Dictionary = move_unit_to_cell(tgt_card, tgt.cell, MOVE_CORE_REDEPLOY) if tgt.has("cell") else move_unit(tgt_card, tgt_lane, MOVE_CORE_REDEPLOY)
		if not bool(move_result.get("ok", false)):
			context.refund_engine_charge(cost, &"core_command:redeploy_refund")
			# PHASE55_BEGIN_MOVE_FAIL
			_core_command_resolving=false
			# PHASE55_END_MOVE_FAIL
			return _core_failure_result(command_id, StringName(move_result.get("reason_code", CORE_INVALID_TARGET)), target)

	_core_command_used_this_player_turn = true
	var committed: Dictionary = _core_success_result(command_id, target, before, spend)
	_core_command_resolving=false
	return committed


func _capture_core_command_before_state(command_id: StringName, target) -> Dictionary:
	# PHASE55_BEGIN_TARGET__CAPTURE_CORE_COMMAND_BEFORE_STATE
	if target is Dictionary:target=target.get("card")
	# PHASE55_END_TARGET__CAPTURE_CORE_COMMAND_BEFORE_STATE
	var d := {
		"charge_before": context.get_engine_charge(),
		"layer_before": context.od_mode.engine_layer if context and context.od_mode else 0,
		"od_before": context.od_mode.current_od if context and context.od_mode else 0,
		"depth_before": context.depth_pressure if context else 0,
	}
	if target != null:
		var st = _state_for_card(target)
		var base_atk := int(target.unit_power) if target != null else 0
		d["target_card_id"] = StringName(str(target.card_id)) if target != null else &""
		d["attack_before"] = st.get_effective_attack(base_atk) if st != null else base_atk
	return d


func _core_success_result(command_id: StringName, target, before: Dictionary, _spend: Dictionary) -> Dictionary:
	# PHASE55_BEGIN_TARGET__CORE_SUCCESS_RESULT
	if target is Dictionary:target=target.get("card")
	# PHASE55_END_TARGET__CORE_SUCCESS_RESULT
	var result := {
		"ok": true,
		"command_id": command_id,
		"reason_code": CORE_OK,
		"charge_before": before.get("charge_before", 0),
		"charge_after": context.get_engine_charge() if context else 0,
		"layer_before": before.get("layer_before", 0),
		"layer_after": context.od_mode.engine_layer if context and context.od_mode else 0,
		"od_before": before.get("od_before", 0),
		"od_after": context.od_mode.current_od if context and context.od_mode else 0,
		"depth_before": before.get("depth_before", 0),
		"depth_after": context.depth_pressure if context else 0,
	}
	if target != null:
		result["target_card_id"] = StringName(str(target.card_id)) if target != null else &""
		var st: UnitCombatStateClass = _state_for_card(target)
		var base_atk: int = int(target.unit_power) if target != null else 0
		var atk_after: int = st.get_effective_attack(base_atk) if st != null else base_atk
		result["attack_before"] = before.get("attack_before", base_atk)
		result["attack_after"] = atk_after
	return result


func _core_failure_result(command_id: StringName, reason_code: StringName, _target) -> Dictionary:
	return {
		"ok": false,
		"command_id": command_id,
		"reason_code": reason_code,
		"charge_before": context.get_engine_charge() if context else 0,
		"charge_after": context.get_engine_charge() if context else 0,
	}


func _core_status(ok: bool, reason_code: StringName, command_id: StringName) -> Dictionary:
	return {"ok": ok, "command_id": command_id, "reason_code": reason_code}


# ── Phase 25E: damage / heal / max-HP 操作 ──

func damage_unit(card: CardData, amount: int, source: String = "", options: Dictionary = {}) -> Dictionary:
	var state = ensure_unit_combat_state(card)
	if state == null:
		return {"ok": false, "reason": "单位不在有效前场", "applied": 0}
	# Phase 27I-R0: P05 减伤统一在 damage_unit 权威入口
	var gateway := _apply_unit_damage_gateway(card, amount, source, bool(options.get("defer_signal", false)))
	return {"ok": true, "card": card, "source": source, "applied": gateway.applied, "reduction": gateway.reduction, "before": gateway.before, "after": gateway.after, "state": state.snapshot(monster_combat_rules.max_attacks_per_turn, monster_combat_rules.actions_per_turn)}

func heal_unit(card: CardData, amount: int, source: String = "") -> Dictionary:
	var state = ensure_unit_combat_state(card)
	if state == null:
		return {"ok": false, "reason": "单位不在有效前场", "applied": 0}
	var before: int = state.current_hp
	var applied: int = state.heal(amount)
	_emit_unit_state(card)
	return {"ok": true, "card": card, "source": source, "applied": applied, "before": before, "after": state.current_hp, "state": state.snapshot(monster_combat_rules.max_attacks_per_turn, monster_combat_rules.actions_per_turn)}

func modify_unit_max_hp(card: CardData, delta: int, add_to_current: bool = true) -> Dictionary:
	var state = ensure_unit_combat_state(card)
	if state == null:
		return {"ok": false, "reason": "单位不在有效前场"}
	var before_max: int = state.max_hp
	var before_hp: int = state.current_hp
	state.modify_max_hp(delta, add_to_current)
	_emit_unit_state(card)
	return {"ok": true, "card": card, "before_max_hp": before_max, "after_max_hp": state.max_hp, "before_hp": before_hp, "after_hp": state.current_hp, "state": state.snapshot(monster_combat_rules.max_attacks_per_turn, monster_combat_rules.actions_per_turn)}

# ── Phase 25D 兼容委托 ──

## 查询攻击状态（兼容 Phase 25D 调用者）
func get_monster_attack_state(card) -> Dictionary:
	return get_unit_combat_state(card)

func _store_monster_attack_state(card, summoned: bool, attacks_used: int) -> void:
	var state = ensure_unit_combat_state(card)
	if state == null:
		return
	state.summoned_this_turn = summoned
	state.attacks_used = clampi(attacks_used, 0, monster_combat_rules.max_attacks_per_turn)
	_emit_unit_state(card)

func register_monster_summoned(card) -> void:
	register_unit(card, &"player", true)

func get_monster_attacks_remaining(card) -> int:
	var state := get_monster_attack_state(card)
	if state.is_empty():
		return 0
	return maxi(0, monster_combat_rules.max_attacks_per_turn - int(state.get("attacks_used", 0)))

## 重置攻击标记，保留 HP
func reset_monster_attacks_turn() -> void:
	reset_unit_turn_state_for_side("player")


## Phase 27F-R1: side-aware turn state reset for player or boss.
## Resets per-turn counters (attacks_used, actions_used, summoned_this_turn)
## without touching persistent HP, board_cell, facing, or permanent modifiers.
func reset_unit_turn_state_for_side(side: String) -> void:
	if context == null:
		return
	var field: Array = []
	var owner: StringName = &"player"
	if side == "boss":
		if context.enemy == null:
			return
		field = context.enemy.field
		owner = &"boss"
	elif side == "player":
		if context.player == null:
			return
		field = context.player.field
		owner = &"player"
		# Phase 27I-R0: 玩家回合开始重置棋子一次性状态
		_reset_piece_turn_state()
	else:
		return
	for raw_card in field:
		var card := raw_card as CardData
		if card == null or not card.is_front_row_card():
			continue
		var state = ensure_unit_combat_state(card, owner)
		if state != null and not state.is_dead():
			state.reset_turn(monster_combat_rules.max_attacks_per_turn, monster_combat_rules.actions_per_turn)
			_emit_unit_state(card)
	if side == "boss":
		print("[BOSS AI] Reset boss unit turn state: attacks_used, actions_used, summoned_this_turn cleared")

func has_monster_attacked(card) -> bool:
	return get_monster_attacks_remaining(card) <= 0

func mark_monster_attacked(card, defer_signal: bool = false) -> void:
	var state = ensure_unit_combat_state(card)
	if state == null:
		return
	state.attacks_used = clampi(state.attacks_used + 1, 0, monster_combat_rules.max_attacks_per_turn)
	# Phase 26E: attack consumes shared action
	state.actions_used = clampi(state.actions_used + 1, 0, monster_combat_rules.actions_per_turn)
	state.last_action = &"attack"
	if not defer_signal:
		_emit_unit_state(card)

func _exhaust_monster_attacks(card) -> void:
	var state = ensure_unit_combat_state(card)
	if state == null:
		return
	state.summoned_this_turn = false
	state.attacks_used = monster_combat_rules.max_attacks_per_turn
	_emit_unit_state(card)


## Phase 5B-1: 建筑接口状态查询（不执行，仅检查）
func get_building_interface_status(card: CardData, player: Player) -> Dictionary:
	var state := get_building_state(card)
	if state.is_empty():
		return {"ok": false, "reason_code": &"building_state_missing", "reason": "建筑状态丢失"}
	if _ensure_structure_board():
		var structure_id: StringName = context.tactical_structure_board_state.get_source_structure_id(
			card.get_instance_id() if card != null else 0
		)
		if structure_id != &"":
			var structure: Dictionary = context.tactical_structure_board_state.get_foundation_status(structure_id)
			if not structure.is_empty() and StringName(str(structure.get("foundation_state", &"stable"))) != &"stable":
				return {
					"ok": false,
					"reason_code": &"structure_interface_paused_undermined",
					"reason": "建筑地基失稳，主动接口暂停",
					"structure_id": structure_id,
					"foundation_state": structure.get("foundation_state", &"undermined"),
				}.duplicate(true)
	if state["used_this_turn"]:
		return {"ok": false, "reason_code": &"building_interface_used", "reason": "本回合已使用"}
	if not state["interface_enabled"]:
		return {"ok": false, "reason_code": &"building_interface_disabled", "reason": "接口未启用"}
	var preview := ""
	var cost := ""
	var reason := ""
	var target: CardData = player.field[0] if not player.field.is_empty() else null
	match card.card_name:
		"Reactor Foundation":
			if target != null:
				preview = "强化%s +1/+1" % target.get_display_name()
				cost = "2充能" if int(state.charge) >= 2 else "2 OD"
				if int(state.charge) < 2 and player.od < 2: reason = "需要2充能或2 OD"
			else:
				preview = "准备下次Depth增长减免1"
				cost = "1 OD"
				if player.od < 1: reason = "无前场棋子；减免接口需要1 OD"
		"Pressure Relay":
			cost = "1 OD"
			preview = "强化%s +1/+1" % target.get_display_name() if target != null else "强化最先登场的前场棋子 +1/+1"
			if context.cards_played_this_turn < 2: reason = "本回合需先成功打出2张牌（当前%d）" % context.cards_played_this_turn
			elif target == null: reason = "无可强化的前场棋子"
			elif player.od < 1: reason = "需要1 OD"
		"Heat Sink":
			preview = "准备下次Depth增长减免%d" % context.get_depth_control_reduce()
			cost = "1 OD" if player.od >= 1 else "1冷却充能"
			if player.od < 1 and int(state.charge) < 1: reason = "需要1 OD或1冷却充能"
		"Containment Wall":
			preview = "护盾 +3" if int(state.charge) >= 1 else "护盾 +2"
			cost = "1充能" if int(state.charge) >= 1 else "无资源费用"
		"Core Cathedral":
			preview = "全体前场 +1/+1；Depth +1"
			cost = "3 OD"
			if player.od < 3: reason = "需要3 OD"
		_:
			return {"ok": false, "reason_code": &"building_interface_unimplemented", "reason": "这张牌没有主动接口"}
	if card.tutor_enabled and card.tutor_timing == "on_building_activate":
		var candidates := find_cards_in_deck(_card_tutor_criteria(card))
		if not player.can_add_to_hand(): preview += "；手牌已满，无法检索"
		elif candidates.is_empty(): preview += "；牌库无匹配检索目标"
		else: preview += "；检索" + candidates[0].get_display_name()
	return {"ok": reason.is_empty(), "reason_code": &"ok" if reason.is_empty() else &"building_interface_requirements",
		"reason": reason, "preview": preview, "cost": cost, "charge": state.charge, "charge_max": state.charge_max}

# ============================================================
# Phase 23B-R2-R-H1: Recovered from history blob
# ============================================================

func _series_label(series_id: String) -> String:
	match series_id:
		"core_cathedral":
			return "炉心圣堂轴"
		"abyss_containment":
			return "深渊封压轴"
		"steam_monster":
			return "蒸汽怪兽轴"
		"generic":
			return "通用轴"
	return series_id


## Phase 5E-2: 根据建筑层级返回每局最大发动次数

func can_monster_attack(card: CardData) -> Dictionary:
	if context == null:
		return {"ok": false, "reason": "战斗未初始化"}
	if card == null:
		return {"ok": false, "reason": "卡牌无效"}
	var state: Variant = _state_for_card(card)
	var owner_side: StringName = state.owner_side if state != null else _detect_unit_owner_side(card)
	if owner_side == &"" or not card in _field_for_owner(owner_side):
		return {"ok": false, "reason": "不在己方前场"}
	if not card.is_front_row_card():
		return {"ok": false, "reason": "不是前场怪兽"}
	# Phase 25D: 召唤病 — 当回合登场的怪兽不能攻击
	var attack_state := get_monster_attack_state(card)
	if monster_combat_rules.summoning_sickness_enabled and bool(attack_state.get("summoned_this_turn", false)):
		return {"ok": false, "reason": "怪兽刚登场，本回合不能攻击"}
	var entered_assignment: Dictionary = get_garrison_state_for_unit(card)
	if StringName(str(entered_assignment.get("state", &""))) == &"active" \
	and int(entered_assignment.get("entered_turn", -1)) == int(context.get_turn_number() if context != null else -2):
		return {
			"ok": false,
			"reason_code": &"garrison_entered_this_turn",
			"reason": _garrison_reason_text(&"garrison_entered_this_turn"),
		}
	# Phase 26E: shared action — cannot attack if action already used
	# Phase 13F-4: A04 is pacifist
	if card.card_id == "A04":
		return {"ok": false, "reason": "深渊束缚者无法攻击"}
	if card.unit_power <= 0:
		return {"ok": false, "reason": "攻击力不足 (ATK=0)"}
	return {"ok": true, "reason": ""}


# Phase 26E: lane-scope guard helpers

func _living_guards_in_scope(attacker: CardData, origin_override: Vector2i = INVALID_GRID_CELL) -> Array[CardData]:
	var guards: Array[CardData] = []
	if context == null:
		return guards
	var attacker_state: Variant = _state_for_card(attacker)
	if attacker_state == null:
		return guards
	var attacker_lane := get_unit_lane(attacker) if origin_override == INVALID_GRID_CELL else origin_override.x
	if attacker_lane < 0:
		return guards
	for raw in _opposing_field_for_owner(attacker_state.owner_side):
		var card := raw as CardData
		if card == null or not card.is_guard_card:
			continue
		var st: Variant = _state_for_card(card)
		if st == null or st.is_dead():
			continue
		if monster_combat_rules.is_guard_in_scope(attacker_lane, get_unit_lane(card)):
			guards.append(card)
	return guards


func _distance_to_nearest_lane(from_lane: int, target_lanes: Array) -> int:
	if target_lanes.is_empty():
		return 999
	var best := 999
	for raw in target_lanes:
		var tl := int(raw)
		var d := absi(from_lane - tl)
		if d < best:
			best = d
	return best


## Phase 27B: cell-authoritative attack targeting (lane compat fallback)
func can_monster_attack_target(attacker, target, include_garrison_range: bool = true, origin_override: Vector2i = INVALID_GRID_CELL) -> Dictionary:
	var attacker_status := can_monster_attack(attacker)
	if not bool(attacker_status.get("ok", false)):
		return attacker_status
	if context == null:
		return {"ok": false, "reason": "战斗未初始化"}
	var attacker_state: Variant = _state_for_card(attacker)
	if attacker_state == null:
		return {"ok": false, "reason": "攻击者状态不存在"}
	var opposing_field := _opposing_field_for_owner(attacker_state.owner_side)
	if target == null or not target in opposing_field:
		return {"ok": false, "reason": "目标不是敌方前场怪兽"}

	# Phase 27B: cell-authoritative front-arc check (primary when board cells exist)
	# Fall back to legacy lane compat when cell check does not explicitly pass
	var atk_cell := get_unit_cell(attacker) if origin_override == INVALID_GRID_CELL else origin_override
	var tgt_cell := get_unit_cell(target)
	if atk_cell != INVALID_GRID_CELL and tgt_cell != INVALID_GRID_CELL:
		var cell_status: Dictionary = get_unit_attack_cell_status(attacker, target, include_garrison_range, origin_override)
		if bool(cell_status.get("ok", false)):
			# Cell check passed — guard priority within front arc
			var in_scope_guards := _living_guards_in_scope(attacker, origin_override)
			if not in_scope_guards.is_empty():
				var guard_in_front_arc := false
				var guard_attack_cells: Array[Vector2i] = get_legal_attack_cells(attacker) \
					if include_garrison_range and (origin_override == INVALID_GRID_CELL or origin_override == get_unit_cell(attacker)) \
					else _get_base_legal_attack_cells(attacker, origin_override)
				for g in in_scope_guards:
					var gs := get_unit_cell(g)
					if gs != INVALID_GRID_CELL and gs in guard_attack_cells:
						guard_in_front_arc = true
						break
				if guard_in_front_arc and not target in in_scope_guards:
					return {"ok": false, "reason": "必须先攻击守卫"}
			return {"ok": true, "reason": ""}
		return {"ok": false, "reason": str(cell_status.get("reason", "无法攻击")),
			"reason_code": cell_status.get("reason_code", cell_status.get("reason", REASON_OUT_OF_PATTERN))}

	# Compatibility for callers without assigned board cells.
	var attacker_lane := get_unit_lane(attacker) if origin_override == INVALID_GRID_CELL else origin_override.x
	var target_lane := get_unit_lane(target)
	if attacker_lane >= 0 and target_lane >= 0:
		if target_lane != attacker_lane:
			return {"ok": false, "reason": "只能攻击同路线敌人"}
		var in_scope_guards := _living_guards_in_scope(attacker, origin_override)
		if not in_scope_guards.is_empty() and not target in in_scope_guards:
			return {"ok": false, "reason": "必须先攻击守卫"}
		return {"ok": true, "reason": ""}
	if not monster_combat_rules.is_legal_unit_target(target, opposing_field):
		return {"ok": false, "reason": "必须先攻击守卫"}
	return {"ok": true, "reason": ""}


## Phase 27B: cell-authoritative Boss direct attack (lane compat fallback)
func can_monster_attack_boss(attacker) -> Dictionary:
	var state: Variant = _state_for_card(attacker)
	if state == null or state.owner_side != &"player":
		return {"ok": false, "reason": "仅玩家怪兽可攻击 Boss 核心"}
	var attacker_status := can_monster_attack(attacker)
	if not bool(attacker_status.get("ok", false)):
		return attacker_status
	if context == null or context.enemy == null:
		return {"ok": false, "reason": "Boss 不存在"}
	if not monster_combat_rules.direct_attack_enabled:
		return {"ok": false, "reason": "当前规则禁止直接攻击 Boss"}

	# Phase 27B: cell-authoritative check (primary when board cell exists)
	# Fall back to legacy lane compat when cell check does not explicitly pass
	var atk_cell := get_unit_cell(attacker)
	var cell_authoritative_ok := false
	if atk_cell != INVALID_GRID_CELL:
		var core_status: Dictionary = get_core_attack_cell_status(attacker)
		cell_authoritative_ok = bool(core_status.get("ok", false))
		if cell_authoritative_ok:
			return {"ok": true, "reason": ""}
		# Phase 27C Task 4: cell-authoritative only - no legacy lane fallback
		var cell_reason: StringName = core_status.get("reason", &"")
		return {"ok": false, "reason": str(core_status.get("reason", "无法攻击核心"))}

	# No board cell — cannot attack core under cell-authoritative rules
	return {"ok": false, "reason": "单位不在棋盘上"}


## Phase 27F: mirrored core check for Boss units attacking the player core.
func can_monster_attack_player_core(attacker) -> Dictionary:
	if _is_battle_terminal():
		return {"ok": false, "reason": "对局已结束", "reason_code": &"battle_ended"}
	var state: Variant = _state_for_card(attacker)
	if state == null or state.owner_side != &"boss":
		return {"ok": false, "reason": "仅 Boss 怪兽可攻击玩家核心"}
	var attacker_status := can_monster_attack(attacker)
	if not bool(attacker_status.get("ok", false)):
		return attacker_status
	if context == null or context.player == null:
		return {"ok": false, "reason": "玩家核心不存在"}
	if not monster_combat_rules.direct_attack_enabled:
		return {"ok": false, "reason": "当前规则禁止直接攻击核心"}
	var core_status: Dictionary = get_core_attack_cell_status(attacker)
	if bool(core_status.get("ok", false)):
		return {"ok": true, "reason": ""}
	return {"ok": false, "reason": str(core_status.get("reason", "无法攻击玩家核心"))}


## Phase 27F: Boss unit resolves attack against player core.
## Does NOT call check_hp_phase_lock (Boss-only) and does NOT reward
## player stable OD. Returns standard transaction result.
func resolve_monster_attack_player_core(attacker: CardData) -> Dictionary:
	var can := can_monster_attack_player_core(attacker)
	if not bool(can.get("ok", false)):
		return {"ok": false, "reason": can.get("reason", "无法攻击玩家核心")}
	if context == null or context.player == null:
		return {"ok": false, "reason": "玩家核心不存在"}
	var dmg: int = get_effective_unit_attack(attacker)
	var hp_before: int = context.player.hp
	var breach: int = frontline_trial.commit_breach(attacker) if frontline_trial != null else 0
	context.player.take_damage(dmg)
	var actual_hp_loss: int = hp_before - context.player.hp
	mark_monster_attacked(attacker)
	_emit_unit_state(attacker)
	var msg: String = "%s 直接攻击玩家核心 (ATK:%d, HP -%d)" % [attacker.get_display_name(), dmg, actual_hp_loss]
	print("[MONSTER ATTACK] %s" % msg)
	return {"ok": true, "result": "hit_player_core", "attacker": attacker, "target": null,
		"damage": dmg, "actual_hp_loss": actual_hp_loss, "breach": breach, "destroyed_units": [],
		"stable_od_events": [], "stable_od_gained": 0, "message": msg}


## Phase 27B-R1: legacy lane-based Boss attack compatibility.
func _can_legacy_lane_unit_attack_boss(attacker) -> Dictionary:
	var attacker_lane := get_unit_lane(attacker)
	if attacker_lane >= 0:
		var boss_occupied := get_occupied_lanes(&"boss")
		if boss_occupied.has(attacker_lane):
			return {"ok": false, "reason": "该路线仍有 Boss 怪兽阻挡"}
		var in_scope_guards := _living_guards_in_scope(attacker)
		if not in_scope_guards.is_empty():
			return {"ok": false, "reason": "相邻路线守卫拦截 Boss 攻击"}
	match monster_combat_rules.direct_attack_blocker:
		"same_lane":
			pass
		"any_enemy":
			if not context.enemy.field.is_empty():
				return {"ok": false, "reason": "Boss 前场仍有怪兽"}
		"guard_only":
			var global_guards: Array = []
			for raw in context.enemy.field:
				var c := raw as CardData
				if c != null and c.is_guard_card:
					global_guards.append(c)
			if not global_guards.is_empty():
				return {"ok": false, "reason": "Boss 前场仍有守卫"}
	return {"ok": true, "reason": ""}


# Phase 26E: legal attack targets for UI/AI
func get_legal_attack_targets(attacker: CardData, origin_override: Vector2i = INVALID_GRID_CELL, include_garrison_range: bool = true) -> Array[CardData]:
	var targets: Array[CardData] = []
	if context == null:
		return targets
	var attacker_state: Variant = _state_for_card(attacker)
	if attacker_state == null:
		return targets
	for raw in _opposing_field_for_owner(attacker_state.owner_side):
		var target := raw as CardData
		if target == null:
			continue
		var st: Variant = _state_for_card(target)
		if st != null and st.is_dead():
			continue
		if bool(can_monster_attack_target(attacker, target, include_garrison_range, origin_override).get("ok", false)):
			targets.append(target)
	return targets


## Read-only OD landing projection. Never moves a unit or consumes protection.
## Complex range effects stay explicitly unknown rather than guessing a hit.
func get_knight_od_landing_preview(source: CardData, landing: Vector2i) -> Dictionary:
	var status := get_od_release_target_status(source, landing)
	var result := {"ok": bool(status.get("ok", false)), "prediction_available": false,
		"reason_code": status.get("reason_code", &"stale_target"), "landing": landing,
		"target": null, "base_damage": 0}
	if not result.ok:
		return result
	if StringName(status.get("piece_type", &"")) != &"knight":
		result.reason_code = &"not_knight"
		return result
	if StringName(get_garrison_state_for_unit(source).get("state", &"")) == &"active" or not _get_bishop_enchant(source).is_empty():
		result.reason_code = &"special_range_requires_commit"
		return result
	var targets := get_legal_attack_targets(source, landing, false)
	result.prediction_available = true
	result.reason_code = &"ok"
	if not targets.is_empty():
		result.target = targets[0]
		result.base_damage = od_release_rules.get_knight_disruption_damage()
	return result


## Phase 27C-R1-R4 Task 3: Unified attack command query API (read-only)
## Returns full attack command status including legal targets, geometric cells,
## and core attack availability. Must not modify HP/cell/actions/OD/Depth.
func get_unit_attack_command_status(card: CardData) -> Dictionary:
	var base := {
		"ok": false,
		"reason_code": &"state_missing",
		"reason_text": "单位状态不可用",
		"legal_targets": [] as Array[CardData],
		"legal_target_cells": [] as Array[Vector2i],
		"core_attack_ok": false,
		"geometric_attack_cells": [] as Array[Vector2i],
	}
	if card == null:
		base.reason_code = &"card_missing"
		base.reason_text = "卡牌不存在"
		return base

	# First: check basic attack readiness (actions, summoning sickness, ATK)
	var can := can_monster_attack(card)
	if not bool(can.get("ok", false)):
		base.reason_code = &"attack_locked"
		base.reason_text = str(can.get("reason", "不能攻击"))
		return base

	# Compute geometric attack cells (all cells in pattern, regardless of enemy presence)
	var geo_cells: Array[Vector2i] = get_legal_attack_cells(card)
	base.geometric_attack_cells = geo_cells

	# Compute real legal targets (enemies in geometric cells)
	var legal_targets: Array[CardData] = get_legal_attack_targets(card)
	base.legal_targets = legal_targets

	# Collect legal target cells
	var target_cells: Array[Vector2i] = []
	for raw_t in legal_targets:
		var tc: Vector2i = get_unit_cell(raw_t)
		if tc != INVALID_GRID_CELL and not target_cells.has(tc):
			target_cells.append(tc)
	base.legal_target_cells = target_cells

	# Check boss core attack
	var state: Variant = _state_for_card(card)
	var core_status: Dictionary = (
		can_monster_attack_player_core(card)
		if state != null and state.owner_side == &"boss"
		else can_monster_attack_boss(card)
	)
	base.core_attack_ok = bool(core_status.get("ok", false))

	# ok=true only if there are legal monster targets OR boss core is attackable
	if not legal_targets.is_empty() or base.core_attack_ok:
		base.ok = true
		base.reason_code = &"ok"
		base.reason_text = "可攻击"
	else:
		if geo_cells.is_empty():
			base.reason_code = &"no_geometric_cells"
			base.reason_text = "该单位没有攻击范围格"
		else:
			base.reason_code = &"no_legal_target"
			base.reason_text = "攻击范围内没有目标"

	return base


# Phase 26E: deterministic Boss movement decision
func get_boss_movement_decision(card: CardData) -> Dictionary:
	var blank: Dictionary = {"ok": false, "action": &"none", "reason_code": &"invalid_target"}
	var state: Variant = _state_for_card(card)
	if state == null or state.owner_side != &"boss" or state.is_dead():
		return blank
	if not monster_combat_rules.boss_movement_enabled:
		return {"ok": false, "action": &"none", "reason_code": &"movement_disabled"}
	var lane := get_unit_lane(card)
	if lane < 0:
		return blank
	# Priority 1: attack if same-lane player unit exists
	var player_at_lane: Variant = get_occupied_lanes(&"player").get(lane)
	if player_at_lane != null:
		return {"ok": true, "action": &"attack", "target": player_at_lane, "from_lane": lane}
	# Priority 2: move toward nearest player unit
	var legal := get_legal_move_lanes(card, MOVE_BOSS_AI)
	if legal.is_empty():
		return {"ok": false, "action": &"none", "reason_code": &"no_legal_move", "from_lane": lane}
	var player_lanes: Array[int] = []
	for key in get_occupied_lanes(&"player").keys():
		player_lanes.append(int(key))
	if player_lanes.is_empty():
		return {"ok": false, "action": &"none", "reason_code": &"no_player_units", "from_lane": lane}
	# Sort by: distance to nearest player, then center-preference, then lower lane
	var sorted: Array = legal.duplicate()
	sorted.sort_custom(func(a: int, b: int) -> bool:
		var da := _distance_to_nearest_lane(a, player_lanes)
		var db := _distance_to_nearest_lane(b, player_lanes)
		if da != db: return da < db
		var ca := absi(a - 2)
		var cb := absi(b - 2)
		return ca < cb if ca != cb else a < b)
	return {"ok": true, "action": &"move", "from_lane": lane, "to_lane": sorted[0], "source": MOVE_BOSS_AI}


## 执行怪兽攻击
## attacker: 攻击方 CardData
## target: 目标 CardData（Boss前场卡），为 null 时攻击 Boss 本体
## 返回 {ok, result, attacker, target, damage, actual_hp_loss, message}

# ── Phase 25E: 统一销毁 ──

func _destroy_field_unit(card: CardData, reason: String, defer_signal: bool = false) -> bool:
	if card == null or context == null:
		return false
	var state = _state_for_card(card)
	var owner_side: StringName = &""
	if state != null:
		owner_side = state.owner_side
	if owner_side == &"":
		owner_side = _detect_unit_owner_side(card)
	var field := _field_for_owner(owner_side)
	var was_in_field := card in field
	if was_in_field:
		field.erase(card)
		if owner_side == &"boss":
			_add_enemy_card_to_graveyard(card)
		else:
			_add_player_card_to_graveyard(card)
	remove_unit_combat_state(card)
	if was_in_field and not defer_signal:
		unit_destroyed.emit(card, owner_side, reason)
	return was_in_field

func destroy_unit(card: CardData, reason: String = "effect") -> Dictionary:
	var removed := _destroy_field_unit(card, reason)
	return {"ok": removed, "card": card, "reason": reason}


func _collect_player_combat_stable_od(target_damaged: bool, target_destroyed: bool) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if context == null:
		return events
	if target_damaged:
		var damage_result: Dictionary = context.award_player_combat_stable_od(&"unit_damage")
		if bool(damage_result.get("awarded", false)):
			events.append(damage_result)
	if target_destroyed:
		var destroy_result: Dictionary = context.award_player_combat_stable_od(&"enemy_destroyed")
		if bool(destroy_result.get("awarded", false)):
			events.append(destroy_result)
	return events


func _sum_stable_od_events(events: Array[Dictionary]) -> int:
	var total: int = 0
	for event in events:
		total += int(event.get("applied", 0))
	return total

# ── Phase 25E: 同时结算 ──

func _resolve_simultaneous_unit_combat(attacker: CardData, target: CardData, bonus_atk: int = 0) -> Dictionary:
	var attacker_state = _state_for_card(attacker)  # Phase 27C-R1-R3: read-only
	var target_state = _state_for_card(target)  # Phase 27C-R1-R3: read-only
	if attacker_state == null or target_state == null:
		return {"ok": false, "reason": "state missing", "result": "state_missing"}

	var attacker_damage := maxi(0, get_effective_unit_attack(attacker) + bonus_atk)
	var target_damage := maxi(0, target.unit_power)  # Boss unit uses base power
	var edge_cover_target: int = edge_fortification_trial.cover_reduction(attacker, target, attacker_damage) if edge_fortification_trial != null else 0
	var edge_cover_attacker: int = edge_fortification_trial.cover_reduction(target, attacker, target_damage) if edge_fortification_trial != null else 0
	attacker_damage = maxi(0, attacker_damage - edge_cover_target)
	target_damage = maxi(0, target_damage - edge_cover_attacker)
	var attacker_hp_before: int = attacker_state.current_hp
	var target_hp_before: int = target_state.current_hp

	mark_monster_attacked(attacker)
	# Phase 27I-R0: 同时战斗也走 P05 减伤网关（保持前后快照与 deferred destruction 语义）
	_apply_unit_damage_gateway(attacker, target_damage, "simultaneous_retaliation")
	_apply_unit_damage_gateway(target, attacker_damage, "simultaneous")
	var attacker_hp_after: int = attacker_state.current_hp
	var target_hp_after: int = target_state.current_hp
	_emit_unit_state(attacker)
	_emit_unit_state(target)

	var attacker_dead: bool = attacker_state.is_dead()
	var target_dead: bool = target_state.is_dead()
	var result_type := "both_survive"
	if attacker_dead and target_dead:
		result_type = "trade"
	elif target_dead:
		result_type = "target_destroyed"
	elif attacker_dead:
		result_type = "attacker_destroyed"

	var destroyed_units: Array = []
	if attacker_dead:
		destroyed_units.append(attacker)
	if target_dead:
		destroyed_units.append(target)
	# Phase 27C-R1-R3: defer destruction — presenter needs tokens for death animation
	# _destroy_field_unit is now called by the caller after presentation completes

	# Phase 27F-R1: Stable OD only rewarded for player-unit attacks, not Boss attacks
	var stable_od_events: Array[Dictionary] = []
	if attacker_state.owner_side == &"player":
		stable_od_events = _collect_player_combat_stable_od(
			target_hp_after < target_hp_before,
			target_dead
		)

	var message := "%s 与 %s 交战：%d/%d → %d/%d" % [
		attacker.get_display_name(), target.get_display_name(),
		attacker_hp_before, target_hp_before,
		attacker_hp_after, target_hp_after,
	]
	return {
		"ok": true,
		"result": result_type,
		"attacker": attacker,
		"target": target,
		"attacker_damage": attacker_damage,
		"edge_cover_for_target": edge_cover_target,
		"edge_cover_for_attacker": edge_cover_attacker,
		"target_damage": target_damage,
		"attacker_hp_before": attacker_hp_before,
		"attacker_hp_after": attacker_hp_after,
		"target_hp_before": target_hp_before,
		"target_hp_after": target_hp_after,
		"destroyed_units": destroyed_units,
		"stable_od_events": stable_od_events,
		"stable_od_gained": _sum_stable_od_events(stable_od_events),
		"message": message,
	}

# Phase 27C-R1-R3: deferred destruction — call after presenter finishes animation
func _apply_deferred_destruction(result: Dictionary) -> void:
	var destroyed: Array = result.get("destroyed_units", []) as Array
	if destroyed.is_empty():
		return
	for dead_card in destroyed:
		if dead_card != null:
			_destroy_field_unit(dead_card, "simultaneous_combat")

# ── Phase 25D 遗留结算（兼容） ──

func _resolve_legacy_atk_vs_def(attacker: CardData, target: CardData, bonus_atk: int = 0) -> Dictionary:
	var atk: int = get_effective_unit_attack(attacker) + bonus_atk
	var def: int = maxi(0, target.unit_defense)
	mark_monster_attacked(attacker)
	if atk >= def:
		# Phase 27C-R1-R3: defer destruction — caller cleans up after presenter
		pass  # target destruction recorded in result.destroyed_units
		# Phase 27F-R1: Stable OD only for player-unit attacks
		var att_state = _state_for_card(attacker)
		var stable_od_events: Array[Dictionary] = []
		if att_state != null and att_state.owner_side == &"player":
			stable_od_events = _collect_player_combat_stable_od(false, true)
		var msg: String = "%s 攻击并破坏 %s (ATK:%d vs DEF:%d)" % [attacker.get_display_name(), target.get_display_name(), atk, def]
		print("[MONSTER ATTACK] %s" % msg)
		return {"ok": true, "result": "destroyed", "attacker": attacker, "target": target, "damage": atk, "destroyed_units": [target], "stable_od_events": stable_od_events, "stable_od_gained": _sum_stable_od_events(stable_od_events), "message": msg}
	else:
		var msg: String = "%s 攻击 %s 未突破 (ATK:%d vs DEF:%d)" % [attacker.get_display_name(), target.get_display_name(), atk, def]
		print("[MONSTER ATTACK] %s" % msg)
		return {"ok": true, "result": "blocked", "attacker": attacker, "target": target, "damage": 0, "stable_od_events": [], "stable_od_gained": 0, "message": msg}

# ── 入口：模式调度 ──

func resolve_monster_attack(attacker: CardData, target: CardData = null, release_bonus: int = 0) -> Dictionary:
	var can := can_monster_attack(attacker)
	if not can.get("ok", false):
		return {"ok": false, "reason": can.get("reason", "不能攻击")}

	var enemy_obj: Enemy = context.enemy
	if enemy_obj == null:
		return {"ok": false, "reason": "Boss 不存在"}

	# Phase 27I-R1: 主教强化赋刃一次性 ATK +1（来源隔离，成功攻击后随赋刃消耗移除）
	var bishop_bonus: int = get_normal_attack_bonus(attacker) + maxi(0, release_bonus)

	# ── 攻击 Boss 前场卡 ──
	if target != null:
		var target_status := can_monster_attack_target(attacker, target)
		if not bool(target_status.get("ok", false)):
			return target_status
		var unit_result: Dictionary
		if monster_combat_rules.resolution_mode == "simultaneous_hp":
			unit_result = _resolve_simultaneous_unit_combat(attacker, target, bishop_bonus)
		else:
			unit_result = _resolve_legacy_atk_vs_def(attacker, target, bishop_bonus)
		if bool(unit_result.get("ok", false)):
			_bishop_consume(attacker)
			if basic_card_trial!=null: basic_card_trial.consume_blade(attacker)
		return unit_result

	# ── 攻击 Boss 本体 ──
	var boss_status := can_monster_attack_boss(attacker)
	if not bool(boss_status.get("ok", false)):
		return boss_status

	var dmg: int = get_effective_unit_attack(attacker) + bishop_bonus
	var boss_hp_before: int = enemy_obj.hp
	var breach: int = frontline_trial.commit_breach(attacker) if frontline_trial != null else 0
	var suppressed: bool = core_siege_trial.consume_for_hit(attacker, dmg) if core_siege_trial != null else false
	enemy_obj.take_damage(dmg, suppressed)
	check_hp_phase_lock(dmg, boss_hp_before)
	var actual_hp_loss: int = boss_hp_before - enemy_obj.hp
	mark_monster_attacked(attacker)
	_bishop_consume(attacker)
	if basic_card_trial!=null: basic_card_trial.consume_blade(attacker)
	var msg: String = "%s 直接攻击 Boss (ATK:%d, HP -%d)" % [attacker.get_display_name(), dmg, actual_hp_loss]
	print("[MONSTER ATTACK] %s" % msg)
	return {"ok": true, "result": "hit_core", "attacker": attacker, "target": null, "damage": dmg, "actual_hp_loss": actual_hp_loss, "breach": breach, "suppressed": suppressed, "destroyed_units": [], "stable_od_events": [], "stable_od_gained": 0, "message": msg}


## 标记怪兽已攻击

func _get_engine_layer() -> int:
	if context and context.od_mode:
		return context.od_mode.engine_layer
	return 1



func _is_layer_3_or_higher() -> bool:
	return _get_engine_layer() >= 3



func _is_layer_5_or_burst() -> bool:
	return _get_engine_layer() >= 5 or (context and context.od_mode and context.od_mode.is_burst_active())



func _get_player_od_value() -> int:
	if context and context.od_mode:
		return context.od_mode.current_od
	if context and context.player:
		return context.player.od
	return 0



func _spend_player_od(amount: int) -> bool:
	if amount <= 0:
		return true
	if _get_player_od_value() < amount:
		return false
	if context and context.has_method("change_od"):
		context.change_od(-amount)
		return true
	push_error("[BUILDING] _spend_player_od: context.change_od unavailable!")
	return false



func _is_player_heated_or_more() -> bool:
	return context and context.od_mode and not context.od_mode.is_calm()



func _is_player_overdrive() -> bool:
	return context and context.od_mode and context.od_mode.is_overdrive()



func _modify_unit_max_hp_or_template(card: CardData, delta: int, add_to_current: bool = true) -> void:
	if card == null:
		return
	if _state_for_card(card) != null:
		modify_unit_max_hp(card, delta, add_to_current)
	else:
		card.unit_defense = maxi(1, card.unit_defense + delta)

func _boost_unit(unit: CardData, atk_bonus: int, def_bonus: int) -> void:
	if unit == null:
		return
	unit.unit_power += atk_bonus
	_modify_unit_max_hp_or_template(unit, def_bonus, true)



func _boost_all_units(player: Player, atk_bonus: int, def_bonus: int) -> int:
	var count := 0
	for unit in player.field:
		if unit is CardData:
			_boost_unit(unit, atk_bonus, def_bonus)
			count += 1
	return count



func trigger_building_charge_on_od_gain(amount: int, source: String) -> void:
	if amount <= 0 or context == null or context.player == null:
		return
	for card in context.player.traps:
		if card == null or not is_instance_valid(card):
			continue
		if not card.is_building_card():
			continue
		var state := get_building_state(card)
		if state.is_empty():
			continue
		var before: int = state.get("charge", 0)
		add_building_charge(card, 1, "OD+" + str(amount) + " " + source)
		var after: int = state.get("charge", before)
		if after > before:
			building_auto_triggered.emit(card.card_name, "充能 +1 → %d/%d" % [after, state.get("charge_max", after)])


## Phase 5B-1: 建筑主动接口 — 点击建筑触发
## 返回 {ok: bool, message: String}

func _status_p05_reactor_foundation(_card: CardData, player: Player, state: Dictionary) -> Dictionary:
	if player.field.size() > 0:
		var target := player.field[0] as CardData
		if target:
			var atk_bonus := 2 if _is_player_heated_or_more() else 1
			var def_bonus := 2 if _is_player_overdrive() else 1
			var can_charge: bool = state["charge"] >= 2
			var can_od: bool = _get_player_od_value() >= 2
			if can_charge or can_od:
				var cost_text := "2充能" if can_charge else "2 OD"
				return {"ok": true, "reason": "", "cost": cost_text,
					"preview": "→ %s +%d/+%d" % [target.card_name, atk_bonus, def_bonus]}
			else:
				return {"ok": false, "reason": "OD不足(需要2 OD或2充能)", "cost": "2 OD/充能", "preview": ""}
	else:
		if _get_player_od_value() >= 1:
			return {"ok": true, "reason": "", "cost": "1 OD", "preview": "→ 下次Depth增加-1"}
		else:
			return {"ok": false, "reason": "OD不足(需要1 OD)", "cost": "1 OD", "preview": ""}
	return {"ok": false, "reason": "无可强化怪兽", "cost": "", "preview": ""}


# ── P08 压力继电塔 状态查询 ──

func _status_p08_pressure_relay(_card: CardData, player: Player, _state: Dictionary) -> Dictionary:
	if context.cards_played_this_turn < 2:
		return {"ok": false, "reason": "本回合需先打出2张牌（当前%d张）" % context.cards_played_this_turn, "cost": "1 OD", "preview": ""}
	if _get_player_od_value() < 1:
		return {"ok": false, "reason": "OD不足(需要1 OD)", "cost": "1 OD", "preview": ""}
	if player.field.size() == 0:
		return {"ok": false, "reason": "无可强化怪兽", "cost": "1 OD", "preview": ""}
	var atk_bonus := 2 if _is_player_overdrive() else 1
	var def_bonus := 1 if _is_player_heated_or_more() else 0
	return {"ok": true, "reason": "", "cost": "1 OD",
		"preview": "→ %d只怪兽 +%d/+%d，继电塔充能+1" % [player.field.size(), atk_bonus, def_bonus]}


# ── P13 热沉装置 状态查询 ──

func _status_p13_heat_sink(_card: CardData, _player: Player, state: Dictionary) -> Dictionary:
	var has_od: bool = _get_player_od_value() >= 1
	var has_charge: bool = state["charge"] >= 1
	if has_od:
		var reduction := 2 if context.turn_depth >= 6 else 1
		return {"ok": true, "reason": "", "cost": "1 OD",
			"preview": "→ 下次Depth增加-%d (当前Depth:%d)" % [reduction, context.turn_depth]}
	elif has_charge:
		return {"ok": true, "reason": "", "cost": "1冷却充能",
			"preview": "→ 下次Depth-1 (剩余充能:%d)" % state["charge"]}
	return {"ok": false, "reason": "OD不足或充能不足", "cost": "1 OD/充能", "preview": ""}


# ── P16 封压壁 状态查询 ──

func _status_p16_containment_wall(_card: CardData, _player: Player, state: Dictionary) -> Dictionary:
	var has_charge: bool = state["charge"] >= 1
	var has_od: bool = _get_player_od_value() >= 1
	if has_charge:
		return {"ok": true, "reason": "", "cost": "1封压充能",
			"preview": "→ 护盾+4，Boss OD-1"}
	elif has_od:
		return {"ok": true, "reason": "", "cost": "1 OD",
			"preview": "→ 护盾+3，Boss OD-1"}
	return {"ok": false, "reason": "OD不足或封压充能不足", "cost": "1 OD/充能", "preview": ""}


# ── P19 炉心圣堂 状态查询 ──

func _status_p19_core_cathedral(_card: CardData, player: Player, state: Dictionary) -> Dictionary:
	if player.field.is_empty():
		return {"ok": false, "reason": "需要至少1只前场怪兽", "cost": "3 OD/充能", "preview": ""}
	var has_charge: bool = state["charge"] >= 3
	var has_od: bool = _get_player_od_value() >= 3
	if not has_charge and not has_od:
		return {"ok": false, "reason": "OD不足(需要3 OD或3充能)", "cost": "3 OD/充能", "preview": ""}
	var overdrive_before := _is_player_overdrive()
	var atk_bonus := 2
	var def_bonus := 2 if overdrive_before else 1
	var shld := 3 if overdrive_before else 2
	var cost_text := "3充能" if has_charge else "3 OD"
	var depth_text := "" if overdrive_before else "，Depth+1"
	return {"ok": true, "reason": "", "cost": cost_text,
		"preview": "→ %d只怪兽 +%d/+%d，护盾+%d%s" % [player.field.size(), atk_bonus, def_bonus, shld, depth_text]}


# ── P05 炉基座 ──

func _apply_backlash_side_effects(card: CardData, player: Player) -> void:
		if not context or context.backlash_turns_remaining <= 0:
			return
		if card.card_family == "building" or card.is_building_card():
			_apply_backlash_on_building(card)
			return
		if card.card_family == "counter":
			return  # CONTROL/Counter safe



func _apply_backlash_on_monster(card: CardData, player: Player) -> void:
		if not context or context.backlash_turns_remaining <= 0:
			return
		if card.card_family != "monster":
			return
		# 副作用 1: 玩家受 1 点伤害
		player.hp -= 1
		print("[BACKLASH] Monster %s: player HP -1 -> %d" % [card.card_name, player.hp])
		# 副作用 2: 怪兽 DEF -1
		_modify_unit_max_hp_or_template(card, -1, false)
		if context and context.get_parent() and is_instance_valid(context.get_parent()) and context.get_parent().get("action_feed"):
			context.get_parent().action_feed.push_message("Backlash: %s HP-1 DEF-1" % card.get_display_name(), Color(0.8, 0.2, 0.2, 1))



func _apply_backlash_on_spell(card: CardData, _player: Player) -> void:
		if not context or context.backlash_turns_remaining <= 0:
			return
		if card.card_family != "spell":
			return
		# 副作用: Load +1
		context.od_mode.load += 1
		print("[BACKLASH] Spell %s: Load +1 -> %d" % [card.card_name, context.od_mode.load])
		if context and context.get_parent() and is_instance_valid(context.get_parent()) and context.get_parent().get("action_feed"):
			context.get_parent().action_feed.push_message("Backlash: %s Load+1" % card.get_display_name(), Color(0.8, 0.2, 0.2, 1))



func _apply_backlash_on_building(card: CardData) -> void:
		if not context or context.backlash_turns_remaining <= 0:
			return
		# 建筑不吃副作用，可减少 Backlash 回合（每回合一次）
		if not context.backlash_reduced_this_turn:
			context.modify_depth(-1, "Building Stabilize:%s" % card.card_name)
			context.backlash_reduced_this_turn = true
			print("[BACKLASH] Building %s stabilized Depth to %d" % [card.card_name, context.depth_pressure])
			if context and context.get_parent() and is_instance_valid(context.get_parent()) and context.get_parent().get("action_feed"):
				context.get_parent().action_feed.push_message("Building stabilized Depth to %d" % context.depth_pressure, Color(0.2, 0.8, 0.4, 1))


func find_cards_in_deck(criteria: Dictionary) -> Array[CardData]:
	if context == null or context.player == null:
		return []
	var deck: Array = context.player.deck
	if deck.is_empty():
		return []

	var results: Array[CardData] = []
	var series_id: String = criteria.get("series_id", "")
	var card_type_filter: String = criteria.get("card_type", "")
	var card_family_filter: String = criteria.get("card_family", "")
	var tag_filter: String = criteria.get("tag", "")
	var exclude_names: Array = criteria.get("exclude_names", [])

	for card in deck:
		if card == null or not is_instance_valid(card):
			continue
		if not card is CardData:
			continue

		# 系列过滤
		if series_id != "":
			if card.series_id != series_id and not series_id in card.secondary_series_ids:
				continue

		# 卡牌类型过滤（优先 card_family，其次 card_type）
		if card_type_filter != "":
			var matched := false
			if card.card_family == card_type_filter.to_lower():
				matched = true
			elif _card_family_matches_string(card, card_type_filter):
				matched = true
			if not matched:
				continue

		if card_family_filter != "":
			if card.card_family != card_family_filter.to_lower():
				continue

		if card.card_id in criteria.get("exclude_ids", []): continue
		if criteria.get("normal_monsters",false) and card.is_arsenal_card: continue
		var tags_any: Array = criteria.get("tags_any", [])
		if not tags_any.is_empty():
			var matched_tag := false
			for tag in tags_any:
				if tag in card.search_tags: matched_tag = true
			if not matched_tag: continue

		# 标签过滤
		if tag_filter != "":
			if not tag_filter in card.search_tags:
				continue

		# 排除列表
		if not exclude_names.is_empty():
			var excluded := false
			for en in exclude_names:
				if en is String and card.matches_name(en):
					excluded = true
					break
			if excluded:
				continue

		results.append(card)

	return results



func _card_family_matches_string(card: CardData, filter_str: String) -> bool:
	var f := filter_str.to_lower()
	match f:
		"monster":
			return card.card_family == "monster" or card.card_type == CardData.CardType.UNIT
		"spell":
			return card.card_family == "spell" or card.card_type == CardData.CardType.SPELL
		"counter", "trap":
			return card.card_family == "counter" or card.card_type == CardData.CardType.TRAP
		"build", "building":
			return card.is_building_card()
	return false


## 从牌库检索第一张匹配卡，移入手牌
## 返回 {ok: bool, card: CardData|null, message: String}

func _card_tutor_criteria(card: CardData) -> Dictionary:
	return {"series_id": card.tutor_series_id, "card_type": card.tutor_card_type,
		"tag": card.tutor_tag, "exclude_names": [card.card_name]}


# Only successful commit callers reach this function. Never called from previews
# or presentation completion. Metadata currently permits at most one search.
func _resolve_committed_card_tutor(card: CardData, timing: String) -> Dictionary:
	if not card.tutor_enabled or card.tutor_count < 1 or card.tutor_timing != timing:
		return {}
	if timing == "on_play" and not on_play_tutors_enabled:
		return {}
	var source := card.get_display_name()
	var receipt := tutor_first_matching_card(_card_tutor_criteria(card), source)
	if bool(receipt.get("ok", false)):
		card_tutored.emit(source, receipt.card, str(receipt.get("message", "")))
	else:
		tutor_failed.emit(source, str(receipt.get("message", "")))
	return receipt


func tutor_first_matching_card(criteria: Dictionary, source: String = "") -> Dictionary:
	if context == null or context.player == null:
		return {"ok": false, "card": null, "message": "战斗未初始化"}

	var deck: Array = context.player.deck
	if deck.is_empty():
		return {"ok": false, "card": null, "message": "牌库为空"}

	var matches := find_cards_in_deck(criteria)
	if matches.is_empty():
		var desc := _build_tutor_fail_description(criteria)
		return {"ok": false, "card": null, "message": "检索失败: 没有" + desc}

	var found: CardData = matches[0]
	# Phase 8A-Hotfix: 手牌已满时不检索
	if not context.player.can_add_to_hand():
		print("[TUTOR FAIL] %s → hand full (%d/%d), card stays in deck" % [source, context.player.hand.size(), Player.MAX_HAND_SIZE])
		return {"ok": false, "card": null, "message": "手牌已满 (%d/%d)，无法检索" % [context.player.hand.size(), Player.MAX_HAND_SIZE]}
	# 从牌库移除
	deck.erase(found)
	# 加入手牌
	context.player.hand.append(found)

	var source_info := ""
	if source != "":
		source_info = " (%s)" % source
	print("[TUTOR] %s → %s from deck%s (deck:%d, hand:%d)" % [source, found.card_name, source_info, deck.size(), context.player.hand.size()])

	return {"ok": true, "card": found, "message": "检索: %s → %s" % [source, found.get_display_name()]}



func _build_tutor_fail_description(criteria: Dictionary) -> String:
	var parts: Array[String] = []
	if criteria.get("series_id", "") != "":
		parts.append("系列匹配的目标")
	if criteria.get("card_type", "") != "":
		parts.append("%s类型" % criteria["card_type"])
	if criteria.get("tag", "") != "":
		parts.append("标签'%s'的目标" % criteria["tag"])
	if parts.is_empty():
		return "可用目标"
	return "".join(parts)


# ============================================================
# Phase 13E/13F: Arsenal mid + final
# ============================================================


func get_arsenal_play_status(card: CardData) -> Dictionary:
	if card == null:
		return {"ok": false, "reason": "invalid", "stage": ""}
	if not card.is_arsenal_card:
		return {"ok": false, "reason": "not arsenal", "stage": ""}
	if context == null or context.od_mode == null:
		return {"ok": false, "reason": "no context", "stage": card.arsenal_tier}

	var layer := context.od_mode.get_engine_layer()
	var burst := context.od_mode.is_burst_active()
	var tier := card.arsenal_tier

	if layer < card.unlock_layer:
		return {"ok": false, "reason": "OD L%d needed (L%d)" % [card.unlock_layer, layer], "stage": tier}
	if context.is_abyss_locked():
		return {"ok": false, "reason": "Abyss Lock", "stage": tier}

	# mid
	if tier == "mid":
		if not context.can_use_mid_arsenal():
			return {"ok": false, "reason": "mid already used", "stage": "mid"}
		if card.is_front_row_card():
			var slot_limit := context.od_mode.get_front_slot_limit()
			if context.player.field.size() >= slot_limit:
				return {"ok": false, "reason": "front row full (L%d=%d)" % [layer, slot_limit], "stage": "mid"}
		return {"ok": true, "reason": "", "stage": "mid"}

	# final
	if tier == "final":
		if layer < 5 and not burst:
			return {"ok": false, "reason": "Need L5/Burst for final", "stage": "final"}
		if not context.arsenal_mid_used:
			return {"ok": false, "reason": "Deploy mid Arsenal first", "stage": "final"}
		if not context.can_use_final_arsenal():
			return {"ok": false, "reason": "final already used", "stage": "final"}
		match card.card_id:
			"A02":
				var has_build := false
				for c in context.player.traps:
					if c != null and is_instance_valid(c) and c.is_building_card():
						has_build = true
						break
				if not has_build:
					return {"ok": false, "reason": "Need a building to upgrade", "stage": "final"}
			"A05":
				if context.depth_pressure < 2:
					return {"ok": false, "reason": "Depth<2 need >=2", "stage": "final"}
			"A06":
				if context.player.field.size() < 2:
					return {"ok": false, "reason": "Need 2 monsters for fusion", "stage": "final"}
		return {"ok": true, "reason": "", "stage": "final"}

	return {"ok": false, "reason": "unknown tier", "stage": tier}



func play_mid_arsenal_card(card: CardData) -> Dictionary:
	if card == null:
		return {"ok": false, "message": "null card"}
	var status: Dictionary = get_arsenal_play_status(card)
	if not bool(status.get("ok", false)):
		return {"ok": false, "message": status.get("reason", "blocked")}

	if card.is_front_row_card():
		context.player.field.append(card)
	else:
		context.player.field.append(card)

	context.record_arsenal_used(card)
	var dname := card.get_display_name() if card.has_method("get_display_name") else card.card_name
	var msg := "Arsenal deployed: %s" % dname

	if card.card_id == "A01":
		if context.enemy:
			context.enemy.change_hp_direct(-2, "Arsenal A01")
			msg += " (Boss HP -2)"
	if card.card_id == "A04":
		if context.has_method("modify_depth"):
			context.modify_depth(-3, "Arsenal:A04")
			msg += " (Depth -3)"
		_exhaust_monster_attacks(card)

	print("[ARSENAL] %s" % msg)
	return {"ok": true, "card": card, "message": msg}


func _building_states_remove(card: CardData) -> void:
	if card == null:
		return
	var key := card.get_instance_id()
	if building_states.has(key):
		building_states.erase(key)
	remove_unit_combat_state(card)
	# Phase 27I-R0: 建筑移除时清理棋子锚点与消耗记录（替换/销毁/无效实例）
	_cleanup_piece_runtime(card)
# ============================================================
# Phase 13F-2: Ascension read-only query (no side effects)
# ============================================================

## Check if a field card has an available ascension target.
## Returns preview info only. Does NOT modify state.

func get_ascension_preview_status(base_card: CardData, _player) -> Dictionary:
	if not is_instance_valid(base_card) or context == null:
		return {"has_target": false, "ok": false, "reason": "来源无效", "target": null, "label": "", "preview": ""}
	for candidate: CardData in _get_arsenal_catalog(base_card):
		if candidate.is_ascension_form and base_card.card_id in candidate.ascends_from_ids:
			var status := can_ascend_card(base_card, candidate, _player)
			status["has_target"] = true
			status["target"] = candidate
			status["label"] = "FUSION" if candidate.card_id == "A06" else "ASCEND"
			status["preview"] = candidate.get_display_name()
			if status.get("ok", false):
				var names: Array[String] = []
				for material: CardData in status.materials:
					names.append(material.get_display_name())
				status["preview"] += "\n素材：%s → 入墓\n保留选中棋子格 %s 与朝向；新单位本回合不能攻击\n支付 %d HP（%d→%d），不消耗或赠送指令" % ["＋".join(names), str(status.source_cell), status.hp_cost, status.hp_before, status.hp_after]
				if candidate.card_id == "A04": status["preview"] += "\n入场 Depth 最多-3；不能主动攻击"
				if candidate.card_id == "A01": status["preview"] += "\n入场对 Boss 造成2伤害"
			# PHASE61_BEGIN_PREVIEW
			if candidate.card_id=="A01" and status.get("ok",false) and _ascension_barrier_trial!=null and _ascension_barrier_trial.profile=="first-barrier" and not _ascension_barrier_trial.used:
				status["preview"]+="\n炉躯显现：首次成功升格后护盾+4；生命或Boss耗尽、反噬时不领取，每战一次"
			# PHASE61_END_PREVIEW
			return status
	return {"has_target": false, "ok": false, "reason": "无升格目标", "target": null, "label": "", "preview": ""}


func _get_arsenal_catalog(ascension_source: CardData = null) -> Array:
	var gm := get_node_or_null("/root/GameManager")
	if gm and gm.has_method("get_arsenal_catalog"):
		var cards = gm.get_arsenal_catalog()
		if not cards.is_empty():
			return cards
	# Fallback direct load
	var loader_cls = preload("res://core/deck/card_catalog_loader.gd")
	var loader = loader_cls.new()
	if ascension_source != null:
		# Filter metadata before constructing Nodes; keep the original first-match order
		# and converter. Each query still returns a fresh battle-owned candidate.
		for row: Variant in loader.load_raw_arsenal_cards():
			if not row is Dictionary or not bool(row.get("is_ascension_form", false)):
				continue
			var from_ids: Array = row.get("ascends_from_ids", [])
			if ascension_source.card_id.is_empty() or ascension_source.card_id not in from_ids:
				continue
			var candidate: CardData = loader.convert_arsenal_to_carddata(row)
			if candidate != null:
				add_child(candidate)
				loader.free()
				return [candidate]
		loader.free()
		return []
	loader.load_arsenal_cards()
	var cards: Array = loader.get_arsenal_cards()
	# Preserve fresh candidates on every request; their lifetime belongs to this battle.
	for owned: CardData in cards:
		add_child(owned)
	loader.free()
	return cards
# ============================================================
# ============================================================
# Phase 13F-3/4/5: Ascension Execution (P02->A01 + P15->A04 + A06 Fusion)
# ============================================================


## Read-only authority for the exact entity, its materials, and the payment.
func _is_live_ascension_material(card: CardData) -> bool:
	if not is_instance_valid(card) or context == null or context.player == null:
		return false
	if card not in context.player.field or card.is_arsenal_card or not card.is_front_row_card():
		return false
	var state: Variant = _state_for_card(card)
	if state == null or state.owner_side != &"player" or state.current_hp <= 0:
		return false
	var cell := get_unit_cell(card)
	if cell == INVALID_GRID_CELL or get_unit_at_cell(cell) != card:
		return false
	if context.tactical_structure_board_state != null:
		if not context.tactical_structure_board_state.get_garrison_for_unit(card.get_instance_id()).is_empty():
			return false
	return true


func can_ascend_card(base_card: CardData, target_card: CardData, _player) -> Dictionary:
	if context == null or context.player == null or context.od_mode == null or _player != context.player:
		return {"ok": false, "reason": "战斗或玩家无效"}
	if _siege_command_in_progress or not get_command_economy_snapshot("player").get("turn_open", false):
		return {"ok": false, "reason": "需要己方行动窗口"}
	if not _is_live_ascension_material(base_card):
		return {"ok": false, "reason": "来源必须是存活且登记在外场的己方普通棋子；驻军需先撤离"}
	if not is_instance_valid(target_card) or not target_card.is_arsenal_card or not target_card.is_ascension_form:
		return {"ok": false, "reason": "升格目标无效"}
	if target_card in context.player.field or target_card in context.player.hand or target_card in context.player.deck or target_card in context.player.graveyard or _state_for_card(target_card) != null:
		return {"ok": false, "reason": "目标已在使用中"}
	if context.is_abyss_locked():
		return {"ok": false, "reason": "深渊锁定中无法升格"}
	var layer: int = context.od_mode.get_engine_layer()
	var materials: Array[CardData] = [base_card]
	match target_card.card_id:
		"A01":
			if base_card.card_id != "P02": return {"ok": false, "reason": "请选择燃芯使魔"}
			if layer < 3: return {"ok": false, "reason": "需要 OD L3"}
			if not context.can_use_mid_arsenal(): return {"ok": false, "reason": "本局已使用中级武库"}
		"A04":
			if base_card.card_id != "P15": return {"ok": false, "reason": "请选择热压壁垒兽"}
			if layer < 3 and context.depth_pressure < target_card.ascension_depth_min:
				return {"ok": false, "reason": "需要 OD L3 或 Depth≥%d" % target_card.ascension_depth_min}
			if not context.can_use_mid_arsenal(): return {"ok": false, "reason": "本局已使用中级武库"}
		"A06":
			if base_card.card_id not in ["P07", "P10"]: return {"ok": false, "reason": "请选择热流导体或连锁导体发起合体"}
			if layer < 5 and not context.od_mode.is_burst_active(): return {"ok": false, "reason": "需要 OD L5 或 Burst"}
			if target_card.requires_mid_arsenal_used and not context.arsenal_mid_used: return {"ok": false, "reason": "先使用一次中级武库"}
			if not context.can_use_final_arsenal(): return {"ok": false, "reason": "本局已使用终场武库"}
			var fusion := get_fusion_materials_for_arsenal(target_card, _player, base_card)
			if not fusion.get("ok", false): return fusion
			materials.assign(fusion.materials)
		_:
			return {"ok": false, "reason": "不支持该升格链"}
	var hp_cost := maxi(0, target_card.require_hp_cost)
	if context.player.hp < hp_cost: return {"ok": false, "reason": "生命不足：需要 %d HP" % hp_cost}
	return {"ok": true, "reason": "", "materials": materials, "source_cell": get_unit_cell(base_card), "hp_cost": hp_cost, "hp_before": context.player.hp, "hp_after": context.player.hp - hp_cost}


func get_fusion_materials_for_arsenal(target_card: CardData, _player, selected_source: CardData = null) -> Dictionary:
	if not is_instance_valid(target_card) or target_card.card_id != "A06" or context == null or _player != context.player:
		return {"ok": false, "reason": "合体目标或玩家无效", "materials": [], "indices": []}
	var source := selected_source
	if source == null:
		for id in ["P07", "P10"]:
			for card: CardData in context.player.field:
				if _is_live_ascension_material(card) and card.card_id == id: source = card; break
			if source != null: break
	if not _is_live_ascension_material(source) or source.card_id not in ["P07", "P10"] or source.series_id != "steam_monster":
		return {"ok": false, "reason": "需要外场热流导体或连锁导体作为来源", "materials": [], "indices": []}
	var partners: Array[CardData] = []
	for card: CardData in context.player.field:
		if card != source and _is_live_ascension_material(card) and card.series_id == "steam_monster": partners.append(card)
	if partners.is_empty(): return {"ok": false, "reason": "还需要一名存活的外场蒸汽普通棋子", "materials": [], "indices": []}
	var partner: CardData = partners[0]
	var preferred := "P10" if source.card_id == "P07" else "P07"
	for card: CardData in partners:
		if card.card_id == preferred: partner = card; break
	return {"ok": true, "reason": "", "materials": [source, partner], "indices": [context.player.field.find(source), context.player.field.find(partner)]}


## Stage the replacement before retiring materials. No observer sees a half commit.
func ascend_card(base_card: CardData, target_card: CardData, _player) -> Dictionary:
	var status := can_ascend_card(base_card, target_card, _player)
	if not status.get("ok", false): return {"ok": false, "message": status.get("reason", "升格失败")}
	var materials: Array = status.materials
	var source_cell: Vector2i = status.source_cell
	var source_facing := get_unit_facing(base_card)
	var source_index: int = context.player.field.find(base_card)
	var result_index := source_index
	for material: CardData in materials:
		if context.player.field.find(material) < source_index: result_index -= 1
	_siege_command_in_progress = true
	unit_by_cell.erase(source_cell)
	context.player.field.append(target_card)
	_defer_unit_registration_notifications = true
	var new_state: Variant = register_unit(target_card, &"player", true, -1, source_cell)
	_defer_unit_registration_notifications = false
	if new_state == null:
		context.player.field.erase(target_card)
		remove_unit_combat_state(target_card)
		unit_by_cell[source_cell] = base_card
		_siege_command_in_progress = false
		return {"ok": false, "message": "目标登记失败，素材与费用已保留"}
	new_state.set_facing_rank_delta(source_facing)
	var names: Array[String] = []
	for material: CardData in materials:
		names.append(material.get_display_name())
		_destroy_field_unit(material, "arsenal_material", true)
	context.player.field.erase(target_card)
	context.player.field.insert(result_index, target_card)
	context.player.hp -= int(status.hp_cost)
	context.record_arsenal_used(target_card)
	var extra := {}
	if target_card.card_id == "A01" and context.enemy != null:
		context.enemy.change_hp_direct(-2, "Ascension A01")
		extra["boss_damage"] = 2
	if target_card.card_id == "A04":
		var reduction := mini(3, context.depth_pressure)
		if reduction > 0: context.modify_depth(-reduction, "Abyss Ascension")
		extra["depth_delta"] = -reduction
	# PHASE61_BEGIN_COMMIT
	if _ascension_barrier_trial!=null and target_card.card_id=="A01":
		extra["ascension_barrier"]=_ascension_barrier_trial.commit(self,base_card,target_card,status)
		ascension_barrier_resolved.emit(extra.ascension_barrier.duplicate(true))
	# PHASE61_END_COMMIT
	_siege_command_in_progress = false
	for material: CardData in materials: unit_destroyed.emit(material, &"player", "arsenal_material")
	_emit_unit_state(target_card)
	unit_cell_changed.emit(target_card, &"player", INVALID_GRID_CELL, source_cell, &"ascension")
	var message := "%s：%s → %s；保留格%s；支付%d HP；新单位本回合不能攻击" % ["OD合体" if target_card.card_id == "A06" else "OD升格", "＋".join(names), target_card.get_display_name(), str(source_cell), status.hp_cost]
	# PHASE61_BEGIN_MESSAGE
	if extra.has("ascension_barrier") and extra.ascension_barrier.granted>0:message+="；炉躯显现：护盾+%d" % extra.ascension_barrier.granted
	# PHASE61_END_MESSAGE
	extra.merge({"ok": true, "message": message, "source": base_card, "target": target_card, "materials": materials, "material_names": names, "source_cell": source_cell, "board_cell": source_cell, "hp_cost": status.hp_cost, "hp_before": status.hp_before, "hp_after": status.hp_after, "summoned_this_turn": true})
	print("[ASCENSION] ", message)
	return extra


# ============================================================
# Phase 13F-6: Final Arsenal SPELL/BUILD (A02/A03/A05)
# ============================================================


func get_final_arsenal_play_status(card: CardData, _player) -> Dictionary:
	if card == null:
		return {"ok": false, "reason": "卡牌无效"}
	if not card.is_arsenal_card:
		return {"ok": false, "reason": "非 Arsenal 卡"}
	if card.is_ascension_form:
		return {"ok": false, "reason": "怪兽型 Arsenal 需要场上升格"}
	if card.arsenal_tier != "final":
		return {"ok": false, "reason": "非终场 Arsenal"}
	if not card.card_id in ["A02", "A03", "A05"]:
		return {"ok": false, "reason": "暂不支持此 Arsenal"}
	if context == null or context.od_mode == null:
		return {"ok": false, "reason": "战斗未初始化"}

	var layer := context.od_mode.get_engine_layer()
	var burst := context.od_mode.is_burst_active()
	if layer < 5 and not burst:
		return {"ok": false, "reason": "需要 OD Layer 5 或 Burst (当前 L%d)" % layer}
	if context.is_abyss_locked():
		return {"ok": false, "reason": "Abyss Lock 中无法使用 Arsenal"}
	if not context.can_use_final_arsenal():
		return {"ok": false, "reason": "本局已使用终场 Arsenal"}

	# Per-card conditions
	match card.card_id:
		"A02":
			var has_build := false
			for c in context.player.traps:
				if c != null and is_instance_valid(c) and c.is_building_card():
					has_build = true
					break
			if not has_build:
				return {"ok": false, "reason": "需要一个建筑作为熔炉形态的基座"}
		"A05":
			if context.depth_pressure < 2:
				return {"ok": false, "reason": "Depth 不足 (需要 >=2，当前 %d)" % context.depth_pressure}

	return {"ok": true, "reason": ""}



func play_final_arsenal_card(card: CardData, _player) -> Dictionary:
	var status: Dictionary = get_final_arsenal_play_status(card, _player)
	if not status.get("ok", false):
		return {"ok": false, "message": status.get("reason", "不可使用")}

	if card.card_id != "A02": context.record_arsenal_used(card)
	var dname := card.get_display_name() if card.has_method("get_display_name") else card.card_name
	var msg := "Final Arsenal: %s" % dname
	var extra := {"ok": true, "card": card, "message": msg}

	match card.card_id:
		"A02":
			var r := _execute_a02_build_upgrade(card)
			if not r.get("ok", false): return r
			msg = r.get("message", msg)
			extra = r
		"A03":
			var r := _execute_a03_divine_descent_v2(card)
			msg = r.get("message", msg)
			extra = r
		"A05":
			var r := _execute_a05_void_discharge_v2(card)
			msg = r.get("message", msg)
			extra = r

	if card.card_id == "A02":
		context.record_arsenal_used(card)
		var cleanup: Dictionary = extra.get("structure_cleanup", {})
		if not cleanup.is_empty(): publish_structure_damage_notifications(cleanup)
	print("[FINAL ARSENAL] %s" % msg)
	extra["ok"] = true; extra["message"] = msg; extra["card"] = card
	return extra



func _execute_a02_build_upgrade(card: CardData) -> Dictionary:
	var target_idx := -1
	for i in range(context.player.traps.size()):
		var c = context.player.traps[i]
		if c != null and is_instance_valid(c) and c.is_building_card():
			target_idx = i
			break
	if target_idx < 0:
		return {"ok": false, "message": "没有可替换的建筑"}

	var old_build: CardData = context.player.traps[target_idx]
	var old_name: String = old_build.card_name
	if old_build.has_method("get_display_name"): old_name = old_build.get_display_name()
	# Retire the consumed base through the existing board writer. This is not
	# an attack: no terrain ruins, damage rewards, new A02 profile or inheritance.
	var cleanup: Dictionary = {}
	if _ensure_structure_board():
		var board: RefCounted = context.tactical_structure_board_state
		var sid: StringName = board.get_source_structure_id(old_build.get_instance_id())
		if sid != &"":
			var base: Dictionary = board.get_snapshot().get("structures", {}).get(sid, {})
			if base.is_empty(): return {"ok": false, "message": "建筑来源已失效"}
			var ref: Dictionary = board.make_core_target_ref(base.cell, int(get_cell_state(base.cell).get("revision", -1)))
			cleanup = board.commit_damage(ref, int(base.integrity_current), {"defer_signal": true})
			if not cleanup.get("ok", false): return {"ok": false, "message": "建筑替换未能提交"}
			cleanup["cleanup_cause"] = &"arsenal_replacement"
			cleanup["source"] = &"arsenal_a02_replacement"
	context.player.graveyard.append(old_build)
	cleanup_building_state(old_build)
	_building_states_remove(old_build)
	context.player.traps[target_idx] = card

	if context.enemy:
		context.enemy.change_hp_direct(-2, "Arsenal A02")
	for unit in context.player.field:
		if unit != null and is_instance_valid(unit) and unit.is_front_row_card():
			unit.unit_power = maxi(0, unit.unit_power + 1)
			_modify_unit_max_hp_or_template(unit, 1, true)

	if not cleanup.is_empty(): cleanup["garrison_aftermath"] = resolve_garrison_aftermath(cleanup, true)
	return {"ok": true, "message": "终场 Arsenal：炉心圣堂·熔炉形态 替换 %s (Boss-2,全军+1/+1)" % old_name, "structure_cleanup": cleanup}



func _execute_a03_divine_descent_v2(card: CardData) -> Dictionary:
	context.player.graveyard.append(card)
	if context.enemy:
		context.enemy.change_hp_direct(-8, "Arsenal A03")
	var msg := "终场 Arsenal：神机降诞，Boss HP -8"
	if context.enemy and "hp" in context.enemy and context.enemy.hp > 0:
		context.modify_depth(3, "Arsenal:A03")
		msg += " (神机反噬：Depth +3)"
	return {"ok": true, "message": msg}



func _execute_a05_void_discharge_v2(card: CardData) -> Dictionary:
	context.player.graveyard.append(card)
	var d := context.depth_pressure
	var dmg := clampi(d * 2, 4, 12)
	if context.enemy:
		context.enemy.change_hp_direct(-dmg, "Arsenal A05")
	context.modify_depth(-d, "Arsenal:A05")
	# Backlash cleared centrally by modify_depth()
	return {"ok": true, "message": "终场 Arsenal：虚空倾泻，Boss HP -%d, Depth 清零" % dmg}


# ═══════════════════════════════════════
# Phase 27E: 怪兽英雄技能 API
# ═══════════════════════════════════════

## 初始化技能快照（由 BattleScene 在 _setup_game 后调用）
func init_monster_hero_skills(snapshot: RefCounted) -> void:
	_monster_hero_skills = snapshot
	if context != null and not context.od_feedback_event_committed.is_connected(_on_skill_heat_committed):
		context.od_feedback_event_committed.connect(_on_skill_heat_committed)
	print("[BattleSystem] MonsterHeroSkills initialized: %s" % str(snapshot.get_card_ids() if snapshot else "null"))

func get_monster_hero_skills() -> RefCounted:
	return _monster_hero_skills

## 查询主动技能合法性
func get_unit_skill_command_status(card: CardData, skill_id: StringName) -> Dictionary:
	var result: Dictionary = {"ok": false, "reason_code": "no_skill", "skill_id": str(skill_id),
		"base_cost": 0, "cost": 0, "current_points": 0, "max_points": 0,
		"stack_count": 0, "max_stacks": 0, "legal_cells": [], "legal_targets": [], "can_target_boss_core": false, "preview": {}}
	if card == null or _monster_hero_skills == null:
		result["reason_code"] = "no_skill"; return result
	if not _monster_hero_skills.has_skill(card.card_id):
		result["reason_code"] = "no_skill"; return result
	var state = _state_for_card(card)
	if state == null:
		result["reason_code"] = "state_missing"; return result
	if state.owner_side != &"player" or context == null or card not in context.player.field:
		result["reason_code"] = "not_player_unit"; return result
	if not bool(get_command_economy_snapshot("player").get("turn_open", false)):
		result["reason_code"] = "not_player_turn"; return result
	if state.is_dead():
		result["reason_code"] = "unit_dead"; return result
	if state.summoned_this_turn:
		result["reason_code"] = "summoning_sickness"; return result

	var active_def: Dictionary = _monster_hero_skills.get_active(card.card_id)
	if active_def.is_empty():
		result["reason_code"] = "no_skill"; return result
	var passive_def: Dictionary = _monster_hero_skills.get_passive(card.card_id)
	result["base_cost"] = int(active_def.get("base_cost", 0))
	result["max_stacks"] = int(passive_def.get("max_stacks", 0))
	var pid: StringName = _passive_id_for_card(card)
	result["stack_count"] = state.get_skill_stack(_stack_id_from_passive(pid))
	# min_stacks 检查
	var min_stacks: int = int(active_def.get("min_stacks", 0))
	if min_stacks > 0 and result["stack_count"] < min_stacks:
		result["reason_code"] = "insufficient_stacks"; return result

	# 计算有效费用 (含 Warning/Backlash)
	var econ := _economy_for_side("player")
	result["current_points"] = int(econ.get("current_points", 0))
	result["max_points"] = int(econ.get("turn_max_points", 0))
	var ecost: int = result["base_cost"]
	ecost += state.get_command_cost_modifier()
	ecost += tactical_command_economy_rules.get_skill_surcharge(_get_command_depth_zone())
	result["cost"] = maxi(ecost, 1)
	if result["current_points"] < result["cost"]:
		result["reason_code"] = "insufficient_command_points"; return result

	# 目标合法性
	var tmode: StringName = StringName(str(active_def.get("target_mode", "")))
	match tmode:
		&"cell":
			result["legal_cells"] = _get_skill_move_cells(state, card)
			if result["legal_cells"].is_empty():
				result["reason_code"] = "no_legal_cell"; return result
		&"enemy_unit_or_boss_core":
			result["legal_targets"] = _get_legal_attack_targets(card, state)
			result["can_target_boss_core"] = _can_monster_target_boss_core(card, state)
			if result["legal_targets"].is_empty() and not result["can_target_boss_core"]:
				result["reason_code"] = "no_legal_target"; return result
		&"cell_or_self":
			var cells: Array[Vector2i] = _get_skill_move_cells(state, card)
			cells.push_front(state.board_cell)
			result["legal_cells"] = cells
	result["ok"] = true; result["reason_code"] = "ok"
	return result

## 执行主动技能
# PHASE61_BEGIN_CONFIG
signal ascension_barrier_resolved(receipt: Dictionary)
const AscensionBarrierTrial := preload("res://core/battle/first_ascension_barrier_trial.gd")
var _ascension_barrier_trial: RefCounted=null
var _ascension_barrier_configuration_closed := false
func seal_ascension_barrier_configuration() -> void:_ascension_barrier_configuration_closed=true
func configure_ascension_barrier_trial(profile: String) -> bool:
	if profile not in ["original","first-barrier"] or context==null or context.player==null:return false
	if _ascension_barrier_configuration_closed or _ascension_barrier_trial!=null:return false
	if _od_release_resolving or _siege_command_in_progress or _core_command_resolving or context.turn_count>1 or not context.player.field.is_empty() or context.arsenal_mid_used:return false
	if context.cards_played_this_turn>0 or get_command_economy_snapshot("player").get("gross_spent",0)>0 or _core_command_used_this_player_turn:return false
	_ascension_barrier_trial=AscensionBarrierTrial.new(profile)
	return true
func get_ascension_barrier_trial_status() -> Dictionary:
	return {"profile":"original","used":false,"attempts":0,"last_receipt":{}} if _ascension_barrier_trial==null else _ascension_barrier_trial.snapshot()
# PHASE61_END_CONFIG
# PHASE52_BEGIN_CONFIG
const FirstThermalRefundTrial := preload("res://core/battle/first_thermal_refund_trial.gd")
var _thermal_refund_trial: RefCounted=null
func configure_thermal_refund_trial(profile: String) -> bool:
	if profile not in ["original","first-full-refund"] or context==null or context.player==null:return false
	if _od_release_resolving or _siege_command_in_progress or context.turn_count>1 or not context.player.field.is_empty() or context.arsenal_mid_used:return false
	if _thermal_refund_trial!=null and (_thermal_refund_trial.resolving or _thermal_refund_trial.used or not _thermal_refund_trial.last_receipt.is_empty()):return false
	_thermal_refund_trial=FirstThermalRefundTrial.new(profile)
	return true
func get_thermal_refund_trial_status() -> Dictionary:
	return {"profile":"original","used":false,"resolving":false,"attempts":0,"last_receipt":{}} if _thermal_refund_trial==null else _thermal_refund_trial.snapshot()
# PHASE52_END_CONFIG
# PHASE52_BEGIN_WRAPPER
func execute_unit_skill_command(card: CardData, skill_id: StringName, target, options: Dictionary = {}) -> Dictionary:
	# PHASE63_BEGIN_SKILL_GUARD
	var owns: bool=_core_damage_heat_trial!=null and _core_damage_heat_trial.profile in ["first-core-heat","ascended-core-heat","ascended-delayed-core-heat"]
	if owns and _core_damage_heat_resolving:return {"ok":false,"reason_code":&"core_damage_heat_busy"}
	if owns:_core_damage_heat_resolving=true
	var committed: Dictionary=_phase63_execute_unit_skill_command(card,skill_id,target,options)
	if owns:_core_damage_heat_resolving=false
	return committed
func _phase63_execute_unit_skill_command(card: CardData, skill_id: StringName, target, options: Dictionary = {}) -> Dictionary:
	# PHASE63_END_SKILL_GUARD
	if _thermal_refund_trial==null:return _execute_unit_skill_command_internal(card,skill_id,target,options)
	if _thermal_refund_trial.resolving or _siege_command_in_progress or _od_release_resolving:return {"ok":false,"reason_code":&"skill_resolution_busy","skill_id":str(skill_id)}
	_thermal_refund_trial.resolving=true
	_siege_command_in_progress=true
	var result: Dictionary=_execute_unit_skill_command_internal(card,skill_id,target,options)
	_siege_command_in_progress=false
	_thermal_refund_trial.resolving=false
	return result
# PHASE52_END_WRAPPER
func _execute_unit_skill_command_internal(card: CardData, skill_id: StringName, target, options: Dictionary = {}) -> Dictionary:
	var result: Dictionary = {"ok": false, "reason_code": "no_skill", "skill_id": str(skill_id),
		"cost": 0, "point_delta": 0, "points_before": 0, "points_after": 0, "refund": 0,
		"source_cell": Vector2i(-1,-1), "destination_cell": Vector2i(-1,-1),
		"stacks_before": 0, "stacks_consumed": 0,
		"od_delta": 0, "depth_delta": 0, "shield_delta": 0, "damage": 0, "destroyed_units": []}
	# 验证
	var status := get_unit_skill_command_status(card, skill_id)
	if not bool(status.get("ok", false)):
		for key in status: result[key] = status[key]
		return result
	var state = _state_for_card(card)
	var active_def: Dictionary = _monster_hero_skills.get_active(card.card_id)
	var cost: int = int(status.get("cost", 0))
	var econ := _economy_for_side("player")
	result["points_before"] = int(econ.get("current_points", 0))
	result["source_cell"] = state.board_cell
	# 验证目标归属
	var tmode: String = str(active_def.get("target_mode", ""))
	if tmode == "cell" or tmode == "cell_or_self":
		if not target is Vector2i:
			result["reason_code"] = "illegal_cell"; return result
		var legal: Array = status.get("legal_cells", [])
		if not legal.has(target):
			result["reason_code"] = "illegal_cell"; return result
		if target != state.board_cell:
			if not _is_cell_legal_and_empty(target):
				result["reason_code"] = "cell_occupied"; return result
	elif tmode == "enemy_unit_or_boss_core":
		if target == null:
			if not bool(status.get("can_target_boss_core", false)):
				result["reason_code"] = "illegal_target"; return result
		elif not target is CardData or not is_instance_valid(target) or not target in status.get("legal_targets", []):
			result["reason_code"] = "illegal_target"; return result
		elif _state_for_card(target) == null or _state_for_card(target).is_dead():
			result["reason_code"] = "target_dead"; return result

	# 暂扣指令
	econ = _economy_for_side("player")
	var cur_pts: int = int(econ.get("current_points", 0))
	if cur_pts < cost:
		result["reason_code"] = "insufficient_command_points"; return result
	econ["current_points"] = cur_pts - cost
	result["point_delta"] = cost
	econ = _economy_for_side("player")
	result["points_after"] = int(econ.get("current_points", 0))

	# 调用 resolver (BattleSystem extends Node; the resolver accepts Object)
	# Phase 27K-R1-A: one execution owns one Heat feedback transaction.
	var resolver_options := options.duplicate(true)
	var heat_transaction_id := StringName(resolver_options.get("heat_transaction_id", &""))
	if heat_transaction_id == &"":
		_skill_heat_transaction_serial += 1
		heat_transaction_id = StringName("skill:%s:%d:turn:%d:%d" % [
			str(skill_id), card.get_instance_id(), context.turn_count, _skill_heat_transaction_serial])
		resolver_options["heat_transaction_id"] = heat_transaction_id
	result["heat_transaction_id"] = heat_transaction_id
	var resolve_result: Dictionary = SkillResolverClass.resolve(
		self, card, target, state, active_def, resolver_options)
	if not bool(resolve_result.get("ok", false)):
		# 回滚
		_refund_command_points("player", cost)
		result["points_after"] = result["points_before"]
		result["point_delta"] = 0
		for key in resolve_result: result[key] = resolve_result[key]
		return result

	# Commit gross payment only after the resolver succeeds; refunds never erase spending.
	var gross_before: int = int(econ.get("gross_spent", 0))
	var gross_after: int = gross_before + cost
	econ["gross_spent"] = gross_after
	var crossed: Array = econ.get("crossed_thresholds", []).duplicate()
	var newly_crossed: Array[int] = []
	for threshold: int in tactical_command_economy_rules.get_depth_thresholds():
		if threshold > gross_before and threshold <= gross_after and not crossed.has(threshold):
			crossed.append(threshold)
			newly_crossed.append(threshold)
			context.add_depth_pressure(tactical_command_economy_rules.get_depth_per_threshold(), "command_gross_%d" % threshold)
	econ["crossed_thresholds"] = crossed
	result["crossed_depth_thresholds"] = newly_crossed
	if state.get_command_cost_modifier() < 0: state.set_command_cost_modifier(0)
	state.last_action = &"active_skill"

	# PHASE52_BEGIN_RESERVE
	var thermal_receipt: Dictionary={}
	var thermal_grant: Dictionary={}
	if _thermal_refund_trial!=null:
		thermal_receipt=_thermal_refund_trial.reserve(self,card,skill_id,target,resolve_result)
		if thermal_receipt.requested>0:resolve_result["refund"]=1
	# PHASE52_END_RESERVE
	var refund: int = int(resolve_result.get("refund", 0))
	if refund > 0:
		var refund_result := grant_instant_command_refund("player", refund, "hero_skill:%s:%d" % [str(skill_id), card.get_instance_id()])
		# PHASE52_BEGIN_GRANT
		if not thermal_receipt.is_empty() and thermal_receipt.requested>0:thermal_grant=refund_result.duplicate(true)
		# PHASE52_END_GRANT
		resolve_result["refund"] = int(refund_result.get("granted", 0))
		result["refund_reason"] = refund_result.get("reason_code", &"ok")
	# PHASE52_BEGIN_FINISH
	if _thermal_refund_trial!=null:resolve_result["thermal_refund"]=_thermal_refund_trial.finish(thermal_receipt,thermal_grant)
	# PHASE52_END_FINISH
	result["points_after"] = int(econ.get("current_points", 0))

	# 合并结果
	for key in resolve_result: result[key] = resolve_result[key]
	result["ok"] = true; result["reason_code"] = "ok"
	result["cost"] = cost; result["skill_id"] = str(skill_id)
	result["point_delta"] = int(result["points_before"]) - int(result["points_after"])
	_emit_unit_state(card)
	# PHASE63_BEGIN_SKILL_AFTER
	if _core_damage_heat_trial!=null and skill_id==&"stream_cannon" and target==null:
		result["core_damage_heat"]=_core_damage_heat_trial.commit(self,card,"stream_cannon",maxi(0,int(result.get("damage",0))))
	# PHASE63_END_SKILL_AFTER
	return result

func _on_skill_heat_committed(event: Dictionary) -> void:
	if event.get("event_kind", &"") == &"heat_committed" and event.get("actor_side", &"player") == &"player" \
	and int(event.get("applied_heat_delta", 0)) > 0 and not bool(event.get("deduplicated", false)):
		_on_player_od_gained()

## 被动触发：普通移动完成
func _on_normal_move_completed(card: CardData) -> void:
	if _monster_hero_skills == null or card == null: return
	if not _monster_hero_skills.has_skill(card.card_id): return
	var passive: Dictionary = _monster_hero_skills.get_passive(card.card_id)
	if StringName(str(passive.get("trigger", ""))) != &"normal_move_completed": return
	var state = _state_for_card(card)
	if state == null: return
	var sid := StringName(str(passive.get("id", "")))
	var ms := int(passive.get("max_stacks", 0))
	if ms <= 0: return
	var stack_id: StringName = _stack_id_from_passive(StringName(str(passive.get("id", ""))))
	state.add_skill_stack(stack_id, 1, ms)
	_emit_unit_state(card)

## 被动触发：玩家 OD 实际增加
func _on_player_od_gained() -> void:
	if _monster_hero_skills == null: return
	for card_id in _monster_hero_skills.get_card_ids():
		var passive: Dictionary = _monster_hero_skills.get_passive(card_id)
		if StringName(str(passive.get("trigger", ""))) != &"player_od_gained": continue
		# 遍历场上该 card_id 的所有实例
		var states := _all_states_for_card_id(card_id)
		for state in states:
			var sid := StringName(str(passive.get("id", "")))
			var ms := int(passive.get("max_stacks", 0))
			if ms <= 0: continue
			var stack_id: StringName = _stack_id_from_passive(sid)
			if not state.is_dead():
				state.add_skill_stack(stack_id, 1, ms)
				_emit_unit_state(_card_for_state(state))

## 被动触发：怪兽战斗伤害
func _on_monster_combat_damage(victim_card: CardData) -> void:
	if _monster_hero_skills == null or victim_card == null: return
	var victim_state = _state_for_card(victim_card)
	if victim_state == null or victim_state.owner_side != &"player": return
	var victim_cell: Vector2i = victim_state.board_cell
	# 查找P15实例
	var states := _all_states_for_card_id("P15")
	for state in states:
		if state == null or state.is_dead(): continue
		var passive: Dictionary = _monster_hero_skills.get_passive("P15")
		if StringName(str(passive.get("trigger", ""))) != &"monster_combat_damage_received": continue
		# 自身或邻接友军触发
		var cell: Vector2i = state.board_cell
		if cell == victim_cell or _cells_adjacent(cell, victim_cell):
			var ms := int(passive.get("max_stacks", 0))
			if ms <= 0: continue
			state.add_skill_stack(&"pressure_stacks", 1, ms)
			_emit_unit_state(_card_for_state(state))

# ── 内部辅助 ──

func _skill_move_pattern(card: CardData = null) -> StringName:
	if card != null:
		var pat := get_unit_movement_pattern(card)
		if pat != &"" and not pat.is_empty():
			return pat
	return &"vanguard"

func _get_skill_move_cells(state, card: CardData = null) -> Array[Vector2i]:
	# 返回当前棋型允许的相邻空格
	var cells: Array[Vector2i] = []
	if tactical_pattern_snapshot == null: return cells
	var offsets: Array = tactical_pattern_snapshot.get_movement_offsets(_skill_move_pattern(card))
	for off in offsets:
		var cell: Vector2i = state.board_cell + off
		if _is_cell_legal_and_empty(cell):
			cells.append(cell)
	return cells

func _get_legal_attack_targets(card: CardData, state) -> Array:
	var targets: Array = []
	var enemy_side: StringName = &"boss" if state.owner_side == &"player" else &"player"
	for entry in unit_combat_states.values():
		if entry.owner_side == enemy_side and not entry.is_dead():
			var target_card := _card_for_state(entry)
			if target_card:
				var atk_status := can_monster_attack_target(card, target_card, false)
				if bool(atk_status.get("ok", false)):
					targets.append(target_card)
	return targets

func _is_cell_legal_and_empty(cell: Vector2i) -> bool:
	if tactical_grid_rules == null: return false
	if not tactical_grid_rules.is_cell_in_bounds(cell): return false
	for entry in unit_combat_states.values():
		if entry.board_cell == cell:
			return false
	return true

func _set_unit_board_cell(state, cell: Vector2i) -> void:
	var _c := _card_for_state(state)
	if _c:
		_assign_unit_cell_atomic(_c, cell, &"skill_move", true)
		return
	state.board_cell = cell

func _apply_skill_attack_damage(card: CardData, target_card, amount: int, source: String) -> int:
	if amount <= 0: return 0
	if target_card is CardData:
		return int(_apply_unit_damage_gateway(target_card, amount, source).get("applied", 0))
	if target_card == null and context != null and context.enemy != null:
		var before: int = context.enemy.hp
		# Skills keep the normal Boss shield/armor and phase gates.
		context.enemy.take_damage(amount)
		check_hp_phase_lock(amount, before)
		return maxi(0, before - context.enemy.hp)
	return 0

func _execute_unit_attack_internal(card: CardData, target_card) -> Dictionary:
	# Internal skill attack; cost and target have already been validated.
	var result: Dictionary = {"damage": 0, "destroyed_units": []}
	if card == null: return result
	var atk_state = _state_for_card(card)
	if atk_state == null: return result
	var raw: int = card.unit_power + atk_state.get_turn_attack_bonus()
	result["damage"] = _apply_skill_attack_damage(card, target_card, raw, "unit_attack_internal")
	if target_card is CardData:
		var def_state = _state_for_card(target_card)
		if def_state != null and def_state.is_dead():
			result["destroyed_units"].append(target_card)
	return result

func _refund_command_points(side: String, amount: int) -> void:
	var econ := _economy_for_side(side)
	if econ.is_empty(): return
	econ["current_points"] = int(econ.get("current_points", 0)) + amount
	econ["current_points"] = mini(econ["current_points"], int(econ.get("turn_max_points", 0)))

func _card_for_state(state) -> CardData:
	for card in context.player.field + context.enemy.field:
		if is_instance_valid(card) and card.get_instance_id() == state.runtime_id:
			return card
	return null


# ═══════════════════════════════════════════════════════
# Phase 27I-R0: Card Piece Status Query (read-only)
# ═══════════════════════════════════════════════════════

func _piece_profile(card: CardData) -> Dictionary:
	if card_piece_traits == null or card == null:
		return {}
	return card_piece_traits.get_profile_for_card(card)

func _piece_payload(card: CardData) -> Dictionary:
	if card_piece_traits == null or card == null:
		return {}
	return card_piece_traits.get_payload_for_card(card)

func _piece_base_value(card: CardData, key: String, default_value: Variant = 0) -> Variant:
	var pl := _piece_payload(card)
	var base: Dictionary = pl.get("base", {}) if pl is Dictionary else {}
	return base.get(key, default_value)

func _piece_enhanced_value(card: CardData, key: String, default_value: Variant = 0) -> Variant:
	var pl := _piece_payload(card)
	var enh: Dictionary = pl.get("enhanced", {}) if pl is Dictionary else {}
	return enh.get(key, default_value)

func _piece_enhance_applicable(card: CardData, action_id: StringName) -> bool:
	var payload := _piece_payload(card)
	if payload.is_empty():
		return false
	var enh: Dictionary = payload.get("enhanced", {})
	if enh.is_empty():
		return false
	if bool(enh.get("only_attack", false)) and action_id != &"attack":
		return false
	return true


# ═══════════════════════════════════════════
# Phase 27I-R1: P06 主教赋刃状态与斜线
# ═══════════════════════════════════════════

## 读目标单位的主教赋刃状态（无则空字典）。
func _get_bishop_enchant(unit: CardData) -> Dictionary:
	if unit == null:
		return {}
	var entry: Dictionary = _piece_runtime_state_by_runtime_id.get(unit.get_instance_id(), {})
	var ench: Dictionary = entry.get("bishop_enchant", {})
	return ench if ench is Dictionary else {}

## 合并写入 bishop_enchant 子项（不整体覆盖实例状态 Dictionary，不破坏 P02/P03 子项）。
## 强化版本覆盖基础版本；基础版本不得降级现有强化版本。
func _set_bishop_enchant(unit: CardData, enhanced: bool) -> void:
	if unit == null:
		return
	var rid: int = unit.get_instance_id()
	var entry: Dictionary = _piece_runtime_state_by_runtime_id.get(rid, {})
	var cur: Dictionary = entry.get("bishop_enchant", {})
	var keep_enhanced: bool = bool(cur.get("enhanced", false)) or enhanced
	entry["bishop_enchant"] = {
		"enhanced": keep_enhanced,
		"set_turn": int(context.get_turn_number()) if context else 0,
	}
	_piece_runtime_state_by_runtime_id[rid] = entry

## 强化且未消耗 → 一次性 ATK +1；基础赋刃不提供 ATK 加成。
func _bishop_one_shot_atk(unit: CardData) -> int:
	var ench := _get_bishop_enchant(unit)
	if not ench.is_empty() and bool(ench.get("enhanced", false)):
		return 1
	return 0

func get_normal_attack_bonus(unit: CardData) -> int:
	return _bishop_one_shot_atk(unit) + (basic_card_trial.blade_amount(unit) if basic_card_trial!=null else 0)

## 移除 bishop_enchant 子项（幂等）。只清除主教自身的 +1，不触碰其他来源的临时攻击加成。
func _bishop_consume(unit: CardData) -> void:
	if unit == null:
		return
	var rid: int = unit.get_instance_id()
	var entry: Dictionary = _piece_runtime_state_by_runtime_id.get(rid, {})
	if entry.has("bishop_enchant"):
		entry.erase("bishop_enchant")
		_piece_runtime_state_by_runtime_id[rid] = entry

## 主教斜线攻击格：scan_piece_rays 的 ordered_cells（空格）+ 首占用敌军格（可攻击）。
## 固定四斜向，不受怪兽当前朝向裁剪。
func _bishop_ray_attack_cells(unit: CardData, origin: Vector2i, owner_side: StringName) -> Array[Vector2i]:
	var dirs: Array[Vector2i] = tactical_pattern_snapshot.get_raycast_directions(&"piece_bishop")
	if dirs.is_empty():
		return []
	var scan := scan_piece_rays(origin, dirs, owner_side, &"enemy_unit")
	var cells: Array[Vector2i] = []
	for c in scan.get("ordered_cells", []):
		if bool(get_height_traversal_status(origin, c).get("ok", false)):
			cells.append(c)
	for cell in scan.get("blocking_cells", {}):
		var occ: Dictionary = scan["blocking_cells"][cell]
		if str(occ.get("kind", "")) == "unit" \
		and str(occ.get("side", "")) != str(owner_side) \
		and bool(get_height_traversal_status(origin, cell).get("ok", false)):
			cells.append(cell)
	return cells

## 玩家回合结束清除主教赋刃（不等待下一个玩家回合开始）。
func cleanup_piece_enchant_for_turn_end(side: StringName) -> void:
	if core_siege_trial != null: core_siege_trial.end_turn(side)
	for rid in _piece_runtime_state_by_runtime_id.keys():
		var st = unit_combat_states.get(rid)
		if st == null or st.owner_side != side:
			continue
		var entry: Dictionary = _piece_runtime_state_by_runtime_id[rid]
		if entry.has("bishop_enchant"):
			entry.erase("bishop_enchant")
			_piece_runtime_state_by_runtime_id[rid] = entry


# ═══════════════════════════════════════════
# Phase 27I-R1: P08 战车连接（来源追踪临时耐久）
# ═══════════════════════════════════════════

var _rook_relay_by_source: Dictionary = {}   # P08 rid(int) -> {source_key:StringName, targets:Array[int], set_turn:int}
var _rook_relay_by_target: Dictionary = {}   # 目标 rid(int) -> Array[StringName]（source_key 列表，去重）

## 来源键：仅由 P08 实例 runtime id 派生（不同实例 = 不同来源）。
func _rook_source_key(rook_card: CardData) -> StringName:
	return StringName("rook_%d" % rook_card.get_instance_id())

## 从权威建筑格查询战车直线可连接友军（首占用格；每方向至多一个；去重）。
func _rook_query_connectables(anchor_cell: Vector2i) -> Array[CardData]:
	var dirs: Array[Vector2i] = tactical_pattern_snapshot.get_raycast_directions(&"piece_rook")
	if dirs.is_empty():
		return []
	var scan := scan_piece_rays(anchor_cell, dirs, &"player", &"friendly_unit")
	var result: Array[CardData] = []
	for occ_unit in scan.get("legal_targets", []):
		if occ_unit is CardData and not result.has(occ_unit):
			result.append(occ_unit)
	return result

## 赋予战车连接：对每个目标 state.set_temporary_max_hp_bonus(source_key, 1)。
## 同一来源再次赋予只刷新 set_turn（不重复 +1）；来源记录去重；双向可追踪。
func _rook_grant_relay(rook_card: CardData, targets: Array, set_turn: int) -> Dictionary:
	if rook_card == null or targets.is_empty():
		return {"ok": false, "granted": 0}
	var rid: int = rook_card.get_instance_id()
	var source_key := _rook_source_key(rook_card)
	var granted := 0
	for raw in targets:
		var target := raw as CardData
		if target == null:
			continue
		var st = _state_for_card(target)
		if st == null or st.is_dead():
			continue
		st.set_temporary_max_hp_bonus(source_key, 1)
		# target → source 反向记录（去重）
		var t_list: Array = _rook_relay_by_target.get(target.get_instance_id(), [])
		if not t_list.has(source_key):
			t_list.append(source_key)
		_rook_relay_by_target[target.get_instance_id()] = t_list
		granted += 1
	# source → targets（同来源刷新只更新 set_turn）
	var entry: Dictionary = _rook_relay_by_source.get(rid, {})
	entry["source_key"] = source_key
	entry["set_turn"] = set_turn
	var target_ids: Array = entry.get("targets", [])
	for t in targets:
		var t_id: int = t.get_instance_id()
		if not target_ids.has(t_id):
			target_ids.append(t_id)
	entry["targets"] = target_ids
	_rook_relay_by_source[rid] = entry
	return {"ok": true, "granted": granted, "source_key": source_key}

## 只移除该来源：先清目标/来源关联记录，再删除来源记录（幂等）。
## 若还有其他有效来源，不降低 max_hp。
## Phase 27I-R1-R: 主教斜线预览格（scan_piece_rays ordered_cells，只读，不含目标格）。
func _bishop_ray_preview_cells(origin: Vector2i, owner_side: StringName) -> Array[Vector2i]:
	var dirs: Array[Vector2i] = tactical_pattern_snapshot.get_raycast_directions(&"piece_bishop")
	if dirs.is_empty():
		return []
	var scan := scan_piece_rays(origin, dirs, owner_side, &"enemy_unit")
	var cells: Array[Vector2i] = []
	for c in scan.get("ordered_cells", []):
		cells.append(c)
	return cells


## Phase 27I-R1-R: 战车正交轨道预览格（scan_piece_rays ordered_cells，只读）。
func _rook_ray_preview_cells(anchor_cell: Vector2i) -> Array[Vector2i]:
	var dirs: Array[Vector2i] = tactical_pattern_snapshot.get_raycast_directions(&"piece_rook")
	if dirs.is_empty():
		return []
	var scan := scan_piece_rays(anchor_cell, dirs, &"player", &"friendly_unit")
	var cells: Array[Vector2i] = []
	for c in scan.get("ordered_cells", []):
		cells.append(c)
	return cells


## Phase 27I-R1-R: P08 执行前权威校验。基础模式且有连接候选时必须提供合法主目标；
## 强化模式不要求主目标（执行时重查全部候选）；fallback_original_only 不要求目标。
## 校验在支付 / play_card / replace_building_and_play 之前完成，失败零副作用。
## Phase 27I-R1-R2: 与查询阶段一致地携带 replacement_old_card 豁免，使 P08 可复用被替换建筑
## 的棋子锚点格（豁免只绑定本次 replacement_old_card，其他已占用锚点格仍非法）。
func _p08_execution_guard(card: CardData, anchor: Variant, target: Variant, status: Dictionary, options: Dictionary = {}) -> Dictionary:
	if card == null:
		return {"ok": true}
	var enhanced_req: bool = bool(status.get("enhanced_requested", false))
	if bool(status.get("fallback_original_only", false)) or enhanced_req:
		return {"ok": true}
	var pending_old: CardData = options.get("replacement_old_card") as CardData if options.has("replacement_old_card") else null
	var exempt_rid: int = pending_old.get_instance_id() if pending_old != null else 0
	var resolved := _resolve_piece_anchor(card, anchor, exempt_rid)
	var anchor_cell: Vector2i = resolved.get("cell", INVALID_GRID_CELL) if bool(resolved.get("ok", false)) else INVALID_GRID_CELL
	if anchor_cell == INVALID_GRID_CELL:
		return {"ok": false, "reason_code": REASON_PIECE_ANCHOR_INVALID, "reason": "锚点无效"}
	var connectables: Array = _rook_query_connectables(anchor_cell)
	if connectables.is_empty():
		return {"ok": true}  # 无候选 → 按 fallback 语义只结算原效果
	var tgt: CardData = target as CardData if (target is CardData) else null
	if tgt == null:
		return {"ok": false, "reason_code": &"piece_target_required", "reason": "请选择 1 个战车连接目标"}
	if not tgt in connectables:
		return {"ok": false, "reason_code": &"piece_target_invalid", "reason": "目标不在战车连接范围内或已过期"}
	return {"ok": true}


func _rook_remove_source(rook_card: CardData) -> Dictionary:
	if rook_card == null:
		return {"ok": true}
	var rid: int = rook_card.get_instance_id()
	if not _rook_relay_by_source.has(rid):
		return {"ok": true, "removed": 0}
	var entry: Dictionary = _rook_relay_by_source[rid]
	var source_key: StringName = entry.get("source_key", StringName(""))
	for t_id in entry.get("targets", []):
		var st = unit_combat_states.get(t_id)
		if st != null:
			st.clear_temporary_max_hp_bonus(source_key)
		# 清理目标反向记录
		if _rook_relay_by_target.has(t_id):
			var t_list: Array = _rook_relay_by_target[t_id]
			t_list.erase(source_key)
			if t_list.is_empty():
				_rook_relay_by_target.erase(t_id)
			else:
				_rook_relay_by_target[t_id] = t_list
	_rook_relay_by_source.erase(rid)
	return {"ok": true, "removed": 1}

## 目标死亡/离场清理：移除目标全部战车连接记录（含来源中的 target id）。
func _rook_remove_target(target_rid: int) -> Dictionary:
	if not _rook_relay_by_target.has(target_rid):
		return {"ok": true, "removed": 0}
	var keys: Array = _rook_relay_by_target[target_rid].duplicate()
	_rook_relay_by_target.erase(target_rid)
	for rid in _rook_relay_by_source.keys():
		var entry: Dictionary = _rook_relay_by_source[rid]
		var t_ids: Array = entry.get("targets", [])
		if t_ids.has(target_rid):
			t_ids.erase(target_rid)
			entry["targets"] = t_ids
			_rook_relay_by_source[rid] = entry
	_rook_relay_by_target.erase(target_rid)
	return {"ok": true, "removed": 1}

## 下个玩家回合开始清理正常到期来源（set_turn < current_turn 的来源贡献）。
## 清理顺序：先清目标/来源关联记录，再删除来源记录（幂等）。
func _rook_clear_expired_for_new_turn(current_turn: int) -> Dictionary:
	var removed := 0
	for rid in _rook_relay_by_source.keys():
		var entry: Dictionary = _rook_relay_by_source[rid]
		if int(entry.get("set_turn", 0)) < current_turn:
			var source_key: StringName = entry.get("source_key", StringName(""))
			for t_id in entry.get("targets", []):
				var st = unit_combat_states.get(t_id)
				if st != null:
					st.clear_temporary_max_hp_bonus(source_key)
				if _rook_relay_by_target.has(t_id):
					var t_list: Array = _rook_relay_by_target[t_id]
					t_list.erase(source_key)
					if t_list.is_empty():
						_rook_relay_by_target.erase(t_id)
					else:
						_rook_relay_by_target[t_id] = t_list
			_rook_relay_by_source.erase(rid)
			removed += 1
	return {"ok": true, "removed": removed}

## 锚点解析：返回 {ok, cell, mode, object, anchor_type}
## exempt_anchor_rid: Phase 27I-R1 建筑替换——被替换建筑拥有的棋子锚点格在 pending replacement 时条件性可用。
func _resolve_piece_anchor(card: CardData, anchor: Variant, exempt_anchor_rid: int = 0) -> Dictionary:
	var profile := _piece_profile(card)
	var amode := str(profile.get("anchor_mode", "none"))
	match amode:
		"unit_self":
			var state = _state_for_card(card)
			if state == null or state.is_dead():
				return {"ok": false, "reason_code": REASON_PIECE_ANCHOR_INVALID}
			var cell := get_unit_cell(card)
			if cell == INVALID_GRID_CELL:
				return {"ok": false, "reason_code": REASON_PIECE_ANCHOR_INVALID}
			return {"ok": true, "cell": cell, "mode": amode, "object": card, "anchor_type": &"unit"}
		"friendly_anchor":
			if anchor == null:
				return {"ok": false, "reason_code": REASON_PIECE_ANCHOR_REQUIRED}
			return _resolve_friendly_anchor(card, anchor)
		"friendly_unit":
			# Phase 27I-R1: 只接受存活玩家怪兽作为赋刃对象（不含核心/已有棋子锚点/建筑）。
			if anchor == null:
				return {"ok": false, "reason_code": REASON_PIECE_ANCHOR_REQUIRED}
			return _resolve_friendly_unit_anchor(card, anchor)
		"board_cell":
			if anchor == null:
				return {"ok": false, "reason_code": REASON_PIECE_ANCHOR_REQUIRED}
			return _resolve_board_cell_anchor(card, anchor, exempt_anchor_rid)
	return {"ok": false, "reason_code": REASON_PIECE_ANCHOR_INVALID}

## Phase 27I-R1: friendly_unit 严格锚点解析——只接受存活玩家怪兽。
func _resolve_friendly_unit_anchor(card: CardData, anchor: Variant) -> Dictionary:
	if not (anchor is CardData):
		return {"ok": false, "reason_code": REASON_PIECE_ANCHOR_INVALID}
	var target := anchor as CardData
	if not target.is_front_row_card() or target.card_family != "monster":
		return {"ok": false, "reason_code": REASON_PIECE_ANCHOR_INVALID}
	var state = _state_for_card(target)
	if state == null or state.is_dead() or state.owner_side != &"player":
		return {"ok": false, "reason_code": REASON_PIECE_ANCHOR_INVALID}
	var cell := get_unit_cell(target)
	if cell == INVALID_GRID_CELL:
		return {"ok": false, "reason_code": REASON_PIECE_ANCHOR_INVALID}
	return {"ok": true, "cell": cell, "mode": "friendly_unit", "object": target, "anchor_type": &"unit"}

func _resolve_friendly_anchor(card: CardData, anchor: Variant) -> Dictionary:
	if anchor is CardData:
		var target := anchor as CardData
		var state = _state_for_card(target)
		if state != null and not state.is_dead() and state.owner_side == &"player":
			return {"ok": true, "cell": get_unit_cell(target), "mode": "friendly_anchor", "object": target, "anchor_type": &"unit"}
		if _piece_anchor_by_runtime_id.has(target.get_instance_id()):
			var entry: Dictionary = _piece_anchor_by_runtime_id[target.get_instance_id()]
			var cell: Vector2i = entry.get("anchor_cell", INVALID_GRID_CELL)
			if cell != INVALID_GRID_CELL:
				return {"ok": true, "cell": cell, "mode": "friendly_anchor", "object": target, "anchor_type": &"building"}
		return {"ok": false, "reason_code": REASON_PIECE_ANCHOR_INVALID}
	if anchor is Dictionary:
		var dict: Dictionary = anchor
		if str(dict.get("type", "")) == "core":
			return {"ok": true, "cell": get_virtual_core_anchor_cell(&"player"), "mode": "friendly_anchor", "object": null, "anchor_type": &"core"}
	return {"ok": false, "reason_code": REASON_PIECE_ANCHOR_INVALID}

func _resolve_board_cell_anchor(card: CardData, anchor: Variant, exempt_anchor_rid: int = 0) -> Dictionary:
	if not (anchor is Dictionary):
		return {"ok": false, "reason_code": REASON_PIECE_ANCHOR_INVALID}
	var dict: Dictionary = anchor
	var anchor_type: String = str(dict.get("type", ""))
	if anchor_type not in ["cell", "structure_core", "structure_module"]:
		return {"ok": false, "reason_code": REASON_PIECE_ANCHOR_INVALID}
	var cell: Vector2i = dict.get("cell", INVALID_GRID_CELL)
	if anchor_type == "structure_module":
		var module: Dictionary = get_structure_module(cell, StringName(str(dict.get("edge", &""))))
		var owner_structure_id: StringName = StringName(str(module.get("structure_id", &"")))
		var structures: Dictionary = get_structure_snapshot().get("structures", {})
		cell = (structures.get(owner_structure_id, {}) as Dictionary).get("cell", INVALID_GRID_CELL)
	if cell == INVALID_GRID_CELL or not tactical_grid_rules.is_cell_in_bounds(cell):
		return {"ok": false, "reason_code": REASON_PIECE_ANCHOR_INVALID}
	if not tactical_grid_rules.is_normal_summon_cell(&"player", cell) and not (frontline_trial != null and card.card_id in ["P05", "P08"] and frontline_trial.can_build_forward(cell)):
		return {"ok": false, "reason_code": REASON_PIECE_ANCHOR_INVALID}
	if get_unit_at_cell(cell) != null:
		return {"ok": false, "reason_code": REASON_PIECE_ANCHOR_INVALID}
	var structure: Dictionary = get_structure_at_cell(cell)
	var structure_rid: int = int(structure.get("source_runtime_id", 0))
	var p08_over_p05: bool = card != null and str(card.card_id) == "P08" and StringName(str(structure.get("profile_id", &""))) == &"p05_foundation"
	if not structure.is_empty() and structure_rid != card.get_instance_id() and structure_rid != exempt_anchor_rid and not p08_over_p05:
		return {"ok": false, "reason_code": REASON_PIECE_ANCHOR_INVALID}
	# Phase 27I-R1: pending replacement 时豁免被替换建筑拥有的棋子锚点格（条件性可用）。
	var implicit_spatial_exempt_rid: int = structure_rid if p08_over_p05 else 0
	if not ((exempt_anchor_rid != 0 and _anchor_cell_of_rid(exempt_anchor_rid) == cell) or (implicit_spatial_exempt_rid != 0 and _anchor_cell_of_rid(implicit_spatial_exempt_rid) == cell)):
		if _get_blocking_piece_cells().has(cell):
			return {"ok": false, "reason_code": REASON_PIECE_ANCHOR_INVALID}
		for rid in _piece_anchor_by_runtime_id:
			if rid == card.get_instance_id():
				continue
			var entry: Dictionary = _piece_anchor_by_runtime_id[rid]
			if entry.get("anchor_cell", INVALID_GRID_CELL) == cell:
				return {"ok": false, "reason_code": REASON_PIECE_ANCHOR_INVALID}
	return {"ok": true, "cell": cell, "mode": "board_cell", "object": null, "anchor_type": &"cell"}


func _structure_card_for_owner(runtime_id: int, owner_side: StringName) -> CardData:
	if owner_side == &"player":
		return _player_trap_by_runtime_id(runtime_id)
	if owner_side == &"boss" and context != null and context.enemy != null:
		for raw: Variant in context.enemy.traps:
			if raw is CardData and raw.get_instance_id() == runtime_id:
				return raw
	return null


func _player_trap_by_runtime_id(runtime_id: int) -> CardData:
	if runtime_id <= 0 or context == null or context.player == null:
		return null
	for trap: CardData in context.player.traps:
		if trap != null and trap.get_instance_id() == runtime_id:
			return trap
	return null

func _anchor_cell_of_rid(rid: int) -> Vector2i:
	var entry: Dictionary = _piece_anchor_by_runtime_id.get(rid, {})
	return entry.get("anchor_cell", INVALID_GRID_CELL)

func _is_cell_used_by_anchor(cell: Vector2i, exclude_rid: int) -> bool:
	for rid in _piece_anchor_by_runtime_id:
		if rid == exclude_rid:
			continue
		var entry: Dictionary = _piece_anchor_by_runtime_id[rid]
		if entry.get("anchor_cell", INVALID_GRID_CELL) == cell:
			return true
	return false

func _get_legal_anchor_cells(card: CardData, exempt_anchor_rid: int = 0) -> Array[Vector2i]:
	var profile := _piece_profile(card)
	var amode := str(profile.get("anchor_mode", "none"))
	if amode == "unit_self":
		var cell := get_unit_cell(card)
		if cell == INVALID_GRID_CELL:
			return []
		var arr: Array[Vector2i] = [cell]
		return arr
	if amode == "board_cell":
		if card != null and str(card.card_id) in ["P05", "P08"] and tactical_structure_rules.has_profile(str(card.card_id)):
			var structure_options: Dictionary = {}
			var exempt_card: CardData = _player_trap_by_runtime_id(exempt_anchor_rid)
			if exempt_card != null:
				structure_options["replacement_old_card"] = exempt_card
			return get_legal_structure_build_cells(card, structure_options)
		var result: Array[Vector2i] = []
		for cell in tactical_grid_rules.get_ordered_summon_cells(&"player"):
			var exempt: bool = exempt_anchor_rid != 0 and _anchor_cell_of_rid(exempt_anchor_rid) == cell
			if get_unit_at_cell(cell) == null and (exempt or (not _get_blocking_piece_cells().has(cell) and not _is_cell_used_by_anchor(cell, card.get_instance_id()))):
				result.append(cell)
		return result
	if amode == "friendly_anchor":
		var result: Array[Vector2i] = []
		for entry in unit_combat_states.values():
			if entry.owner_side == &"player" and not entry.is_dead():
				var cell: Vector2i = entry.board_cell
				if cell != INVALID_GRID_CELL and not result.has(cell):
					result.append(cell)
		result.append(get_virtual_core_anchor_cell(&"player"))
		for rid in _piece_anchor_by_runtime_id:
			var entry: Dictionary = _piece_anchor_by_runtime_id[rid]
			var cell2: Vector2i = entry.get("anchor_cell", INVALID_GRID_CELL)
			if cell2 != INVALID_GRID_CELL and not result.has(cell2):
				result.append(cell2)
		return result
	if amode == "friendly_unit":
		# Phase 27I-R1: 只含存活玩家怪兽；不含核心/已有棋子锚点/建筑。
		var result: Array[Vector2i] = []
		for entry in unit_combat_states.values():
			if entry.owner_side == &"player" and not entry.is_dead():
				var cell: Vector2i = entry.board_cell
				if cell != INVALID_GRID_CELL and not result.has(cell):
					result.append(cell)
		return result
	return []

func _friendly_unit_in_cells(cells: Array) -> bool:
	for cell in cells:
		var unit := get_unit_at_cell(cell)
		if unit != null:
			var state = _state_for_card(unit)
			if state != null and not state.is_dead() and state.owner_side == &"player":
				return true
	return false

func _get_adjacent_enemy_candidates(card: CardData, primary_target: CardData) -> Array:
	var result: Array = []
	if primary_target == null:
		return result
	var cell: Vector2i = get_unit_cell(primary_target)
	if cell == INVALID_GRID_CELL:
		return result
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			var adj := cell + Vector2i(dx, dy)
			if not tactical_grid_rules.is_cell_in_bounds(adj):
				continue
			var unit := get_unit_at_cell(adj)
			if unit != null and unit != primary_target and not result.has(unit):
				result.append(unit)
	return result


## 只读查询：卡牌棋子状态（含锚点、几何、目标、费用、支付选项、Depth/OD 快照）
func get_card_piece_status(card: CardData, action_id: StringName, anchor: Variant = null, target: Variant = null, options: Dictionary = {}) -> Dictionary:
	var result := {
		"ok": false,
		"reason_code": REASON_PIECE_DISABLED,
		"piece_enabled": false,
		"piece_type": &"",
		"piece_name": "",
		"profile_id": &"",
		"payload_id": &"",
		"action_id": action_id,
		"anchor_mode": "none",
		"target_mode": "none",
		"anchor_cells": [],
		"base_cells": [],
		"enhanced_cells": [],
		"legal_targets": [],
		"ray_preview_cells": [],
		"legal_target_cells": [],
		"enhanced_requested": bool(options.get("enhanced_requested", false)),
		"payment_options": [],
		"selected_payment_mode": PIECE_PAY_NONE,
		"base_command_cost": 0,
		"piece_command_cost": 0,
		"piece_depth_cost": 0,
		"total_command_cost": 0,
		"points_before": 0,
		"points_after": 0,
		"depth_before": 0,
		"depth_after": 0,
		"od_before": 0,
		"od_after": 0,
		"preview": {},
		"fallback_original_only": false,
	}
	if card == null:
		result.reason_code = REASON_CARD_MISSING
		return result
	if not card.piece_enabled:
		return result
	var profile := _piece_profile(card)
	var payload := _piece_payload(card)
	if profile.is_empty():
		result.reason_code = REASON_PIECE_PROFILE_MISSING
		return result
	if payload.is_empty():
		result.reason_code = REASON_PIECE_PAYLOAD_MISSING
		return result
	result.piece_enabled = true
	result.piece_type = card.piece_type
	result.piece_name = card_piece_traits.get_piece_type_name(result.piece_type)
	result.profile_id = card.piece_effect_profile_id
	result.payload_id = card.piece_payload_id
	result.anchor_mode = str(profile.get("anchor_mode", "none"))
	result.target_mode = str(profile.get("target_mode", "none"))
	var allowed_families: Array = profile.get("allowed_families", [])
	if not str(card.card_family) in allowed_families:
		result.reason_code = &"piece_family_mismatch"
		return result

	# ── 基础费用快照 ──
	var econ: Dictionary = get_command_economy_snapshot("player")
	result.points_before = int(econ.get("current_points", 0))
	result.depth_before = int(context.turn_depth) if context else 0
	result.od_before = int(context.od_mode.current_od) if (context and context.od_mode) else 0
	result.od_after = result.od_before
	var amode := str(profile.get("anchor_mode", "none"))

	# ── 锚点 ──
	# Phase 27I-R1: pending replacement 时豁免被替换建筑拥有的棋子锚点格（仅绑定 replacement_card）。
	var exempt_rid: int = 0
	var pending_old: CardData = options.get("replacement_old_card") as CardData if options.has("replacement_old_card") else null
	if pending_old != null:
		exempt_rid = pending_old.get_instance_id()
	var resolved := _resolve_piece_anchor(card, anchor, exempt_rid)
	var anchor_cell: Vector2i = INVALID_GRID_CELL
	if bool(resolved.get("ok", false)):
		anchor_cell = resolved.get("cell", INVALID_GRID_CELL)
		result.anchor_cells = [anchor_cell]
	else:
		# Phase 27I-R1: friendly_unit 无合法友军 → fallback_original_only（不要求 anchor、强化禁用、原效果正常结算）。
		if amode == "friendly_unit" and anchor == null:
			var fu_candidates := _get_legal_anchor_cells(card)
			if fu_candidates.is_empty():
				result["fallback_original_only"] = true
				result["enhanced_requested"] = false
				result["payment_options"] = []
				result["selected_payment_mode"] = PIECE_PAY_NONE
				result["ok"] = true
				result["reason_code"] = REASON_OK
				return result
			result.anchor_cells = fu_candidates
			result.reason_code = REASON_PIECE_ANCHOR_REQUIRED
			return result
		result.anchor_cells = _get_legal_anchor_cells(card, exempt_rid)
		result.reason_code = resolved.get("reason_code", REASON_PIECE_ANCHOR_REQUIRED)
		if amode != "unit_self" and anchor == null:
			result.reason_code = REASON_PIECE_ANCHOR_REQUIRED
		return result

	# Elevated Grid Phase C: P05 and P08 board-cell anchors are their construction
	# cells. One copied preview drives legality and the later prepared commit.
	if action_id == &"play" and str(card.card_id) in ["P05", "P08"] and tactical_structure_rules.has_profile(str(card.card_id)):
		var build_status: Dictionary = get_structure_build_status(card, anchor_cell, options)
		result["structure_build_preview"] = build_status.duplicate(true)
		result.preview["structure_build_preview"] = build_status.duplicate(true)
		if build_status.get("replacement_old_card", null) is CardData:
			pending_old = build_status.get("replacement_old_card") as CardData
			result["replacement_old_card"] = pending_old
		if not bool(build_status.get("ok", false)):
			result.reason_code = build_status.get("reason_code", &"structure_transaction_failed")
			result["awaiting_replacement"] = bool(build_status.get("awaiting_replacement", false))
			return result

	# ── 几何 / 目标 / 基础合法性 ──
	var base_ok := true
	if amode == "unit_self":
		if action_id == &"move":
			var cmd_move := get_unit_command_status(card, "move", null)
			result.base_cells = cmd_move.get("legal_cells", [])
			result.base_command_cost = int(cmd_move.get("cost", 0))
			if not bool(cmd_move.get("ok", false)):
				result.reason_code = cmd_move.get("reason_code", REASON_PIECE_NO_LEGAL_CELL)
				base_ok = false
		elif action_id == &"attack":
			var core_target: bool = target is StringName and target == &"boss_core"
			if core_target and bool(result.get("enhanced_requested", false)) and str(card.piece_payload_id) == "p02_knight_action":
				result.reason_code = REASON_PIECE_SECONDARY_TARGET_REQUIRED
				return result
			var cmd_atk := get_unit_command_status(card, "attack_core" if core_target else "attack", null)
			result.base_cells = get_legal_attack_cells(card)
			result.legal_targets = cmd_atk.get("legal_targets", [])
			result.base_command_cost = int(cmd_atk.get("cost", 0))
			if not bool(cmd_atk.get("ok", false)):
				result.reason_code = cmd_atk.get("reason_code", REASON_PIECE_NO_LEGAL_CELL)
				base_ok = false
			# P02 强化攻击：主目标确定时列出相邻次目标
			if bool(result.get("enhanced_requested", false)) and target != null and target is CardData:
				var splash := _get_adjacent_enemy_candidates(card, target as CardData)
				if not splash.is_empty():
					result.legal_targets = splash
		else:
			result.reason_code = REASON_PIECE_TARGET_INVALID
			base_ok = false
	else:
		# play 类（P01/P04/P05/P06/P08）
		result.base_command_cost = 0
		var pattern_id: StringName = StringName(str(profile.get("pattern_id", "")))
		# Phase 27I-R1: pending replacement 时建筑位满不判不可用——走 get_card_play_status(card, true) 豁免容量门。
		var play_status := bool(get_card_play_status(card, true, true).get("ok", false)) if pending_old != null else can_play_card(card)
		if not play_status:
			result.reason_code = &"piece_base_action_blocked"
			base_ok = false
		else:
			var extra_rank := 0
			if action_id == &"play" and bool(result.get("enhanced_requested", false)):
				var payload_id := card.piece_payload_id
				if payload_id == StringName("p04_tripwire_watch"):
					extra_rank = 1
			result.base_cells = project_piece_cells(pattern_id, anchor_cell, &"player", &"attack", 0)
			result.enhanced_cells = project_piece_cells(pattern_id, anchor_cell, &"player", &"attack", 1) if (bool(result.get("enhanced_requested", false)) and extra_rank > 0) else []
			# Phase 27I-R1-R: 动态射线预览（P06 主教斜线 / P08 战车正交）来自唯一权威 scan_piece_rays。
			var r1_payload: String = str(card.piece_payload_id)
			if r1_payload == "p06_bishop_blade":
				var bishop_preview := _bishop_ray_preview_cells(anchor_cell, &"player")
				result["ray_preview_cells"] = bishop_preview
				result.base_cells = bishop_preview
			elif r1_payload == "p08_rook_relay":
				var rook_preview := _rook_ray_preview_cells(anchor_cell)
				result["ray_preview_cells"] = rook_preview
				result.base_cells = rook_preview
				var connectables: Array = _rook_query_connectables(anchor_cell)
				result.legal_targets = connectables
				var lt_cells: Array[Vector2i] = []
				for cc in connectables:
					var ccell := get_unit_cell(cc)
					if ccell != INVALID_GRID_CELL and not lt_cells.has(ccell):
						lt_cells.append(ccell)
				result["legal_target_cells"] = lt_cells
				result.enhanced_cells = lt_cells  # 合法端点金色（Presenter 只读展示）
				if connectables.is_empty():
					result["fallback_original_only"] = true

	# Phase 27I-R1: P08 无连接友军 → 只结算原效果（强化禁用）
	if bool(result.get("fallback_original_only", false)):
		result["enhanced_requested"] = false
		result["payment_options"] = []
		result["selected_payment_mode"] = PIECE_PAY_NONE
		result["ok"] = true
		result["reason_code"] = REASON_OK
		return result

	if not base_ok:
		return result

	# ── 强化适用性与支付 ──
	var enhanced_requested: bool = bool(result.get("enhanced_requested", false))
	var enhance_modes: Array = profile.get("enhance_modes", [])
	var piece_command_cost: int = 0
	var piece_depth_cost: int = 0
	if enhanced_requested:
		if not _piece_enhance_applicable(card, action_id):
			result.reason_code = REASON_PIECE_ENHANCE_NOT_APPLICABLE
			return result
		piece_command_cost = card_piece_traits.get_enhance_command_cost()
		piece_depth_cost = card_piece_traits.get_enhance_depth_cost()
	result.piece_command_cost = piece_command_cost
	result.piece_depth_cost = piece_depth_cost

	var total_command_cost: int = int(result.get("base_command_cost", 0)) + piece_command_cost
	result.total_command_cost = total_command_cost

	# 支付选项
	var in_overdrive: bool = _is_player_overdrive()
	var depth_at_cap: bool = (context != null and result.depth_before >= int(context.get_depth_max_value())) if context else false
	var command_legal: bool = PIECE_PAY_COMMAND in enhance_modes and can_pay_command_cost("player", total_command_cost)
	# Depth 支付只替换强化指令费用：基础行动费用仍需用指令点支付
	var base_afford: bool = can_pay_command_cost("player", int(result.get("base_command_cost", 0)))
	var depth_legal: bool = (PIECE_PAY_DEPTH in enhance_modes) and in_overdrive and not depth_at_cap and base_afford
	result.payment_options = []
	if command_legal:
		result.payment_options.append(PIECE_PAY_COMMAND)
	if depth_legal:
		result.payment_options.append(PIECE_PAY_DEPTH)

	if enhanced_requested:
		var requested_mode: StringName = StringName(str(options.get("selected_payment_mode", "")))
		if requested_mode == PIECE_PAY_COMMAND:
			if not command_legal:
				result.reason_code = REASON_PIECE_COMMAND_INSUFFICIENT
				return result
			result.selected_payment_mode = PIECE_PAY_COMMAND
		elif requested_mode == PIECE_PAY_DEPTH:
			if not depth_legal:
				result.reason_code = REASON_PIECE_DEPTH_AT_CAP if depth_at_cap else REASON_PIECE_DEPTH_ZONE_REQUIRED
				return result
			result.selected_payment_mode = PIECE_PAY_DEPTH
		else:
			# 未显式选择：仅 command 合法时自动 command；其余需要显式选择（Depth 永不自动）
			if command_legal and not depth_legal:
				result.selected_payment_mode = PIECE_PAY_COMMAND
			else:
				result.reason_code = REASON_PIECE_PAYMENT_CHOICE_REQUIRED
				return result
	else:
		result.selected_payment_mode = PIECE_PAY_NONE

	# ── Phase 27I-R0-R: P02 强化参数显式校验（查询直接返回 reason code，执行前重查同路径）──
	if enhanced_requested and card.piece_payload_id == StringName("p02_knight_action"):
		if action_id == &"move":
			if not options.has("followup_facing"):
				result.reason_code = REASON_PIECE_FOLLOWUP_FACING_REQUIRED
				return result
			var facing: int = int(options.get("followup_facing", 0))
			if facing not in [-1, 1]:
				result.reason_code = REASON_PIECE_FOLLOWUP_FACING_INVALID
				return result
		elif action_id == &"attack" and target != null and (target is CardData):
			var candidates: Array = _get_adjacent_enemy_candidates(card, target as CardData)
			if candidates.is_empty():
				result.reason_code = REASON_PIECE_SECONDARY_TARGET_REQUIRED
				return result
			result.legal_targets = candidates
			if options.has("secondary_target"):
				var secondary: CardData = options.get("secondary_target") as CardData
				if secondary == null or secondary == target or not (secondary in candidates):
					result.reason_code = REASON_PIECE_SECONDARY_TARGET_INVALID
					return result

	# 指令支付：强化指令费用并入 total；Depth 支付：指令侧只扣基础行动费用，强化费用改由 Depth 承担
	var paid_piece_cost: int = piece_command_cost if result.selected_payment_mode == PIECE_PAY_COMMAND else 0
	result.points_after = result.points_before - (int(result.get("base_command_cost", 0)) + paid_piece_cost)
	if result.selected_payment_mode == PIECE_PAY_DEPTH:
		result.depth_after = result.depth_before + piece_depth_cost
	else:
		result.depth_after = result.depth_before

	result.ok = true
	result.reason_code = REASON_OK
	return result


## Phase 27I-R0: 原子棋子执行。执行前必须重新查询；失败时指令/Depth/HP/护盾/OD/手牌/场面/锚点/一次性状态全部不变。
func execute_card_piece_action(card: CardData, action_id: StringName, anchor: Variant = null, target: Variant = null, options: Dictionary = {}) -> Dictionary:
	var status := get_card_piece_status(card, action_id, anchor, target, options)
	if not bool(status.get("ok", false)):
		return status
	# Phase 27I-R0-R: P02 强化攻击执行前必须显式提供合法次目标，不允许花强化费却无溅射。
	# （查询在“选择阶段”允许未提供次目标以展示候选；执行必须强制提供。）
	if action_id == &"attack" and str(card.piece_payload_id) == "p02_knight_action" and bool(status.get("enhanced_requested", false)):
		if not options.has("secondary_target"):
			var need := status.duplicate(true)
			need["ok"] = false
			need["reason_code"] = REASON_PIECE_SECONDARY_TARGET_REQUIRED
			return need
		var sec: CardData = options.get("secondary_target") as CardData
		var prim: CardData = target as CardData if (target is CardData) else null
		if sec == null or prim == null or sec == prim or not (sec in _get_adjacent_enemy_candidates(card, prim)):
			var bad := status.duplicate(true)
			bad["ok"] = false
			bad["reason_code"] = REASON_PIECE_SECONDARY_TARGET_INVALID
			return bad
	# Phase 27I-R1-R: P08 战车连接权威执行前校验——必须在支付 / play_card / replace_building_and_play 之前。
	if action_id == &"play" and str(card.piece_payload_id) == "p08_rook_relay":
		var p08_guard := _p08_execution_guard(card, anchor, target, status, options)
		if not bool(p08_guard.get("ok", false)):
			return p08_guard
	var profile := _piece_profile(card)
	var amode := str(profile.get("anchor_mode", "none"))
	var payment_mode: StringName = status.get("selected_payment_mode", PIECE_PAY_NONE)
	var points_before: int = int(status.get("points_before", 0))
	var econ := _economy_for_side("player")
	var debit_applied := false
	var piece_command_cost: int = int(status.get("piece_command_cost", 0))
	var resolver_result: Dictionary = {}
	if amode == "unit_self":
		# move/attack 委托现有 execute_unit_command 事务（指令费用在其中预扣/回滚）
		resolver_result = _execute_unit_piece_action(card, action_id, anchor, target, options, status)
	else:
		# play 类：受控入口，command 支付需在此预扣
		if payment_mode == PIECE_PAY_COMMAND and piece_command_cost > 0:
			econ["current_points"] = points_before - piece_command_cost
			debit_applied = true
		resolver_result = _execute_play_piece_action(card, action_id, anchor, target, options, status)

	if not bool(resolver_result.get("ok", false)):
		if debit_applied:
			econ["current_points"] = points_before
		var fail := status.duplicate(true)
		fail["ok"] = false
		fail["reason_code"] = resolver_result.get("reason_code", resolver_result.get("reason", &"resolver_failed"))
		if resolver_result.has("reason"):
			fail["reason"] = resolver_result.get("reason")
		if resolver_result.has("failure_stage"):
			fail["failure_stage"] = resolver_result.get("failure_stage")
		return fail

	# Depth 支付：委托成功后提交恰好一次
	if payment_mode == PIECE_PAY_DEPTH and context:
		context.modify_depth(1, "piece_enhance:%s" % card.card_id)

	var result := resolver_result.duplicate(true)
	result["ok"] = true
	result["reason_code"] = REASON_OK
	result["selected_payment_mode"] = payment_mode
	result["enhanced"] = bool(status.get("enhanced_requested", false))
	result["points_before"] = points_before
	# 指令侧真实扣费：command 扣 base+piece，depth 扣 base，基础行动扣 base（由委托事务或 play 管线扣）
	result["points_after"] = int(econ.get("current_points", 0))
	result["depth_before"] = int(status.get("depth_before", 0))
	result["depth_after"] = int(context.turn_depth) if context else int(status.get("depth_before", 0))
	return result


## 单位类棋子行动（P02/P03）：委托 execute_unit_command，叠加强化跟随效果
func _execute_unit_piece_action(card: CardData, action_id: StringName, anchor: Variant, target: Variant, options: Dictionary, status: Dictionary) -> Dictionary:
	var enhanced: bool = bool(status.get("enhanced_requested", false))
	var payment_mode: StringName = status.get("selected_payment_mode", PIECE_PAY_NONE)
	# Phase 27I-R0-R: P02 强化参数执行前守卫（正常经 execute_card_piece_action 查询已校验；此处双保险，
	# 防止 GUI 直接绕到 execute_unit_command 时跳过 P02 强化参数）。
	if enhanced and str(card.piece_payload_id) == "p02_knight_action":
		if action_id == &"move":
			if not options.has("followup_facing"):
				return {"ok": false, "reason_code": REASON_PIECE_FOLLOWUP_FACING_REQUIRED, "reason": "强化移动必须显式选择朝向"}
			if int(options.get("followup_facing", 0)) not in [-1, 1]:
				return {"ok": false, "reason_code": REASON_PIECE_FOLLOWUP_FACING_INVALID, "reason": "朝向非法"}
		elif action_id == &"attack":
			var prim0: CardData = target as CardData if (target is CardData) else null
			if prim0 == null:
				return {"ok": false, "reason_code": REASON_PIECE_TARGET_INVALID, "reason": "缺少合法主目标"}
			var cands0: Array = _get_adjacent_enemy_candidates(card, prim0)
			if cands0.is_empty():
				return {"ok": false, "reason_code": REASON_PIECE_SECONDARY_TARGET_REQUIRED, "reason": "无合法相邻次目标"}
			if not options.has("secondary_target"):
				return {"ok": false, "reason_code": REASON_PIECE_SECONDARY_TARGET_REQUIRED, "reason": "强化攻击必须显式选择次目标"}
			var sec0: CardData = options.get("secondary_target") as CardData
			if sec0 == null or sec0 == prim0 or not (sec0 in cands0):
				return {"ok": false, "reason_code": REASON_PIECE_SECONDARY_TARGET_INVALID, "reason": "次目标非法或已过期"}
	var piece_payload := {
		"piece_enhanced": enhanced,
		"piece_payment_mode": payment_mode,
		"piece_followup_facing": options.get("followup_facing", 0),
		"piece_secondary_target": options.get("secondary_target", null),
	}
	# P03 强化攻击：仅本次攻击临时 ATK +1
	var state = _state_for_card(card)
	var atk_bonus_applied := false
	if enhanced and action_id == &"attack":
		var payload := _piece_payload(card)
		if int(payload.get("enhanced", {}).get("temporary_atk_bonus", 0)) > 0 and state != null:
			state.add_temporary_attack_bonus(1)
			atk_bonus_applied = true

	var core_target: bool = action_id == &"attack" and target is StringName and target == &"boss_core"
	var cmd_result := execute_unit_command(card, "attack_core" if core_target else str(action_id), null if core_target else target, piece_payload)

	# 无论成败都清除临时 ATK
	if atk_bonus_applied and state != null:
		state.clear_temporary_attack_bonus()

	if not bool(cmd_result.get("ok", false)):
		return {"ok": false, "reason_code": cmd_result.get("reason_code", &"resolver_failed"), "reason": cmd_result.get("reason", "")}

	# 强化跟随效果（成功后）
	var payload_id := card.piece_payload_id
	if enhanced:
		if action_id == &"move" and payload_id == StringName("p02_knight_action"):
			# 强化移动：显式朝向
			var facing: int = int(options.get("followup_facing", 0))
			if facing in [-1, 1] and state != null:
				state.set_facing_rank_delta(facing)
		elif action_id == &"attack" and payload_id == StringName("p02_knight_action"):
			# 强化攻击：主目标相邻第二敌方单位溅射 1
			var secondary: CardData = options.get("secondary_target", null) as CardData
			if secondary != null and target != null and target is CardData:
				var candidates := _get_adjacent_enemy_candidates(card, target as CardData)
				if secondary in candidates:
					_apply_unit_damage_gateway(secondary, 1, "piece_splash:%s" % card.card_id)
	# P03 结阵护盾：本回合第一次成功行动（基础或强化）时结算
	if payload_id == StringName("p03_vanguard_formation"):
		_piece_p03_maybe_formation_shield(card)

	var result: Dictionary = cmd_result.duplicate(true)
	result["ok"] = true
	result["piece_enhanced"] = enhanced
	result["piece_payment_mode"] = payment_mode
	return result


## play 类棋子行动（P01/P04/P05/P06/P08）：受控入口调用现有 play_card 或建筑替换事务
func _execute_play_piece_action(card: CardData, action_id: StringName, anchor: Variant, target: Variant, options: Dictionary, status: Dictionary) -> Dictionary:
	var fallback_original_only: bool = bool(status.get("fallback_original_only", false))
	# Phase 27I-R1: pending replacement —— 被替换建筑锚点格条件性可用。
	var pending_old: CardData = options.get("replacement_old_card") as CardData if options.has("replacement_old_card") else null
	if pending_old == null and status.get("replacement_old_card", null) is CardData:
		pending_old = status.get("replacement_old_card") as CardData
	var exempt_rid: int = pending_old.get_instance_id() if pending_old != null else 0
	var resolved := _resolve_piece_anchor(card, anchor, exempt_rid)
	var anchor_ok: bool = bool(resolved.get("ok", false))
	# Phase 27I-R1: friendly_unit fallback_original_only 不要求 anchor，仍正常结算原效果。
	if not anchor_ok and not fallback_original_only:
		return {"ok": false, "reason_code": resolved.get("reason_code", REASON_PIECE_ANCHOR_INVALID), "reason": "锚点无效"}
	var anchor_cell: Vector2i = resolved.get("cell", INVALID_GRID_CELL)
	var enhanced: bool = bool(status.get("enhanced_requested", false))
	var structure_build_preview: Dictionary = {}
	var is_structure_build: bool = action_id == &"play" and str(card.card_id) in ["P05", "P08"] and tactical_structure_rules.has_profile(str(card.card_id))
	var play_result: Dictionary = {}
	var structure_build_fact: Dictionary = {}
	if is_structure_build:
		structure_build_preview = get_structure_build_status(card, anchor_cell, options)
		if not bool(structure_build_preview.get("ok", false)):
			return {
				"ok": false,
				"reason_code": structure_build_preview.get("reason_code", &"structure_transaction_failed"),
				"structure_build_preview": structure_build_preview.duplicate(true),
			}
		var coordinated: Dictionary = _commit_prevalidated_structure_build(card, anchor_cell, options, structure_build_preview)
		if not bool(coordinated.get("ok", false)):
			return coordinated.duplicate(true)
		play_result = coordinated.get("play_result", {}).duplicate(true)
		structure_build_fact = coordinated.get("structure_build_fact", {}).duplicate(true)
	else:
		# Phase 27I-R1: non-spatial building replacement and ordinary piece play
		# retain their original lifecycle path.
		if pending_old != null:
			play_result = replace_building_and_play(card, pending_old)
		else:
			play_result = play_card(card)
	if not bool(play_result.get("ok", false)):
		return {"ok": false, "reason_code": play_result.get("reason_code", &"play_failed"), "reason": play_result.get("reason", "")}

	# 成功后棋子载荷
	var payload_id := card.piece_payload_id
	var shield_delta := 0
	var anchor_stored := false
	match payload_id:
		StringName("p01_formation_shield"):
			shield_delta = _piece_p01_apply_shield(card, anchor_cell, enhanced)
			if frontline_trial != null and anchor_ok and resolved.get("object") is CardData:
				var escort_target: CardData = resolved.get("object")
				if escort_target in context.player.field:
					frontline_trial.grant_escort(escort_target, enhanced)
		StringName("p06_bishop_blade"):
			# Phase 27I-R1: 主教赋刃 → 对锚点友方怪兽合并写入状态（无锚点 fallback 只结算原效果）
			if anchor_ok and resolved.get("object") is CardData:
				_set_bishop_enchant(resolved.get("object") as CardData, enhanced)
		StringName("p08_rook_relay"):
			# Phase 27I-R1: 战车连接。基础模式：主目标 target（或 options.target）；强化模式：重查全部候选。
			_piece_anchor_by_runtime_id[card.get_instance_id()] = {
				"card": card,
				"owner_side": &"player",
				"anchor_cell": anchor_cell,
				"blocks_cell": true,
				"set_turn": int(context.get_turn_number()) if context else 0,
			}
			anchor_stored = true
			var rook_targets: Array = []
			if enhanced:
				rook_targets = _rook_query_connectables(anchor_cell)
			else:
				var rook_main: CardData = target as CardData if (target is CardData) else null
				if rook_main == null and options.has("target") and (options["target"] is CardData):
					rook_main = options["target"] as CardData
				if rook_main != null:
					rook_targets = [rook_main]
			if not rook_targets.is_empty():
				_rook_grant_relay(card, rook_targets, int(context.get_turn_number()) if context else 0)
		StringName("p04_tripwire_watch"):
			# 固定非阻挡锚点（触发时解析监视范围）
			_piece_anchor_by_runtime_id[card.get_instance_id()] = {
				"card": card,
				"owner_side": &"player",
				"anchor_cell": anchor_cell,
				"blocks_cell": false,
				"enhanced": enhanced,
				"set_turn": int(context.get_turn_number()) if context else 0,
			}
			anchor_stored = true
		StringName("p05_foundation_guard"):
			# 固定阻挡建筑锚点
			var max_protected: int = int(_piece_enhanced_value(card, "protected_units", 2)) if enhanced else int(_piece_base_value(card, "protected_units", 1))
			_piece_anchor_by_runtime_id[card.get_instance_id()] = {
				"card": card,
				"owner_side": &"player",
				"anchor_cell": anchor_cell,
				"blocks_cell": true,
				"set_turn": int(context.get_turn_number()) if context else 0,
			}
			_piece_runtime_state_by_runtime_id[card.get_instance_id()] = {
				"enhanced": enhanced,
				"max_protected_units": max_protected,
				"protected_this_round": [],
				"remaining_slots": max_protected,
			}
			anchor_stored = true

	if not anchor_stored:
		_cleanup_piece_runtime(card)

	return {
		"ok": true,
		"card": card,
		"anchor_cell": anchor_cell,
		"anchor_stored": anchor_stored,
		"shield_delta": shield_delta,
		"play_result": play_result,
		"structure_build_fact": structure_build_fact.duplicate(true),
	}


func _ensure_legacy_building_runtime_once(card: CardData) -> void:
	if card == null or not card.is_building_card():
		return
	if not get_building_state(card).is_empty():
		return
	_init_building_state(card)
	if context != null:
		context.record_building_played(card.card_name)


## P01 结阵护盾：锚点前方扇区内存在活友军时，基础 +1 / 强化总计 +2
func _piece_p01_apply_shield(card: CardData, anchor_cell: Vector2i, enhanced: bool) -> int:
	var fan := project_piece_cells(&"piece_pawn", anchor_cell, &"player", &"attack", 0)
	if not _friendly_unit_in_cells(fan):
		return 0
	var delta: int = int(_piece_enhanced_value(card, "shield_delta", 2)) if enhanced else int(_piece_base_value(card, "shield_delta", 1))
	if context and context.player:
		context.player.shield += delta
	return delta


## P03 结阵护盾：每回合第一次成功行动时结算一次（按实例独立，同名实例不共享状态）
## 该函数只会在成功行动后调用（execute_unit_command ok=true 之后），失败/取消不消耗首次触发。
func _piece_p03_maybe_formation_shield(card: CardData) -> int:
	if card == null:
		return 0
	var rid: int = card.get_instance_id()
	var entry: Dictionary = _piece_runtime_state_by_runtime_id.get(rid, {})
	if bool(entry.get("formation_checked_this_turn", false)):
		return 0
	var state = _state_for_card(card)
	if state == null:
		return 0
	# 成功行动后标记首次触发（本回合该实例不再重复结算）
	entry["formation_checked_this_turn"] = true
	_piece_runtime_state_by_runtime_id[rid] = entry
	var fan := project_piece_cells(&"piece_pawn", state.board_cell, &"player", &"attack", 0)
	if _friendly_unit_in_cells(fan):
		if context and context.player:
			context.player.shield += 1
			return 1
	return 0


## P04 监视范围投影：触发时从固定锚点重新计算兵卒扇区（强化延伸一排）
func _piece_p04_resolve_watch(card: CardData, enhanced: bool = false) -> int:
	if not _piece_anchor_by_runtime_id.has(card.get_instance_id()):
		return 0
	var entry: Dictionary = _piece_anchor_by_runtime_id[card.get_instance_id()]
	var anchor_cell: Vector2i = entry.get("anchor_cell", INVALID_GRID_CELL)
	if anchor_cell == INVALID_GRID_CELL:
		return 0
	if not enhanced:
		enhanced = bool(entry.get("enhanced", false))
	var ranks: int = int(_piece_enhanced_value(card, "watch_ranks", 2)) if enhanced else int(_piece_base_value(card, "watch_ranks", 1))
	var watch: Array[Vector2i] = []
	for r in range(maxi(1, ranks)):
		var cells := project_piece_cells(&"piece_pawn", anchor_cell, &"player", &"attack", r)
		for c in cells:
			if not watch.has(c):
				watch.append(c)
	if _friendly_unit_in_cells(watch):
		var delta: int = int(_piece_base_value(card, "shield_delta", 1))
		if context and context.player:
			context.player.shield += delta
			return delta
	return 0


## P05 减伤：每轮每个受保护单位首伤 -1；强化允许多一个不同友军；R0 同一伤害事件总减伤封顶 1
func _apply_p05_mitigation(card: CardData, amount: int, commit: bool = true) -> int:
	if amount <= 0 or card == null:
		return 0
	var protected_rid: int = card.get_instance_id()
	for rid in _piece_anchor_by_runtime_id:
		var entry: Dictionary = _piece_anchor_by_runtime_id[rid]
		if not bool(entry.get("blocks_cell", false)):
			continue
		var anchor_cell: Vector2i = entry.get("anchor_cell", INVALID_GRID_CELL)
		if anchor_cell == INVALID_GRID_CELL:
			continue
		var unit_cell: Vector2i = get_unit_cell(card)
		if unit_cell == INVALID_GRID_CELL:
			continue
		var fan := project_piece_cells(&"piece_pawn", anchor_cell, &"player", &"attack", 0)
		if not fan.has(unit_cell):
			continue
		var state: Dictionary = _piece_runtime_state_by_runtime_id.get(rid, {})
		var protected_set: Array = state.get("protected_this_round", [])
		var slots: int = int(state.get("remaining_slots", 0))
		if protected_set.has(protected_rid) or slots <= 0:
			continue
		if not commit:
			return 1
		protected_set.append(protected_rid)
		state["protected_this_round"] = protected_set
		state["remaining_slots"] = slots - 1
		_piece_runtime_state_by_runtime_id[rid] = state
		return 1  # R0 封顶 1
	return 0


## 权威单位伤害网关：P05 减伤后扣 HP。同时战斗/英雄攻击/技能均走此入口。
func _apply_unit_damage_gateway(card: CardData, amount: int, source: String, defer_signal: bool = false) -> Dictionary:
	var state = _state_for_card(card)
	if state == null:
		return {"ok": false, "applied": 0, "reduction": 0}
	var before: int = state.current_hp
	var reduction: int = _apply_p05_mitigation(card, amount) if state.owner_side == &"player" else 0
	var mitigated: int = maxi(0, amount - reduction)
	if frontline_trial != null:
		mitigated = frontline_trial.reduce_damage(card, mitigated, source)
		reduction = amount - mitigated
	if reaction_trial != null:
		mitigated = reaction_trial.reduce_damage(card, mitigated, source)
		reduction = amount - mitigated
	var applied: int = state.apply_damage(mitigated)
	if applied > 0 and source in ["simultaneous", "simultaneous_retaliation", "unit_attack_internal"]:
		_on_monster_combat_damage(card)
	if not defer_signal:
		_emit_unit_state(card)
	return {"ok": true, "applied": applied, "reduction": reduction, "before": before, "after": state.current_hp}


## 玩家回合开始重置棋子一次性状态
## P03：按实例重置首次行动结阵标记（只重置存活 P03）。
## P05：按实例保存的强化状态恢复名额（基础 1 / 强化 2），不得强制写回基础值。
func _reset_piece_turn_state() -> void:
	# P03：重置所有存活 P03 的首次行动结阵标记
	if context and context.player:
		for raw in context.player.field:
			var c := raw as CardData
			if c == null or c.piece_payload_id != StringName("p03_vanguard_formation"):
				continue
			var rid: int = c.get_instance_id()
			var entry: Dictionary = _piece_runtime_state_by_runtime_id.get(rid, {})
			entry["formation_checked_this_turn"] = false
			_piece_runtime_state_by_runtime_id[rid] = entry
	# P05：按实例保存的 max_protected_units 恢复本轮名额与已保护集合
	for rid in _piece_runtime_state_by_runtime_id.keys():
		var state: Dictionary = _piece_runtime_state_by_runtime_id[rid]
		if not state.has("max_protected_units"):
			continue
		state["protected_this_round"] = []
		state["remaining_slots"] = int(state.get("max_protected_units", 1))
		_piece_runtime_state_by_runtime_id[rid] = state


func _passive_id_for_card(card: CardData) -> StringName:
	if _monster_hero_skills == null: return &""
	var passive: Dictionary = _monster_hero_skills.get_passive(card.card_id)
	return StringName(str(passive.get("id", "")))

func _can_monster_target_boss_core(card: CardData, state) -> bool:
	if tactical_core_facing_rules == null:
		return false
	var core_status := get_core_attack_cell_status(card)
	return bool(core_status.get("ok", false))

func _stack_id_from_passive(passive_id: StringName) -> StringName:
	match passive_id:
		&"ember_cadence": return &"ember_stacks"
		&"thermal_pressure": return &"thermal_stacks"
		&"pressure_reserve": return &"pressure_stacks"
		&"vanguard_momentum": return &"vanguard_stacks"
		&"conductor_charge": return &"conductor_stacks"
	return passive_id

func _all_states_for_card_id(card_id: String) -> Array:
	var out: Array = []
	for sid in unit_combat_states:
		var st = unit_combat_states[sid]
		# 通过context查找对应卡片的card_id
		if context:
			for c in context.player.field:
				if is_instance_valid(c) and c.card_id == card_id and c.get_instance_id() == st.runtime_id:
					out.append(st)
	return out

func _cells_adjacent(a: Vector2i, b: Vector2i) -> bool:
	var d := Vector2i(abs(a.x - b.x), abs(a.y - b.y))
	return (d.x <= 1 and d.y <= 1) and d != Vector2i(0, 0)


## P18 uses an inward wall normal, never a temporary caster unit or mouse ray.
func get_p22_repair_cast_status(card: CardData, target_ref: Dictionary) -> Dictionary:
	if _siege_command_in_progress:
		return {"ok": false, "reason_code": &"siege_command_in_progress"}
	if not tactical_repair_rules.is_enabled():
		return {"ok": false, "reason_code": &"repair_content_not_implemented"}
	if context == null or card == null or card.card_id != "P22" or card.is_front_row_card() or card.is_back_row_card() or not context.player.hand.has(card):
		return {"ok": false, "reason_code": &"repair_card_unavailable"}
	if card.require_od > context.od_mode.current_od or card.require_load > context.od_mode.load or card.require_hp_cost > context.player.hp \
	or (card.require_awaken and not context.player.is_awakened) or (context.is_abyss_locked() and card.archetype_role != CardData.ArchetypeRole.CONTROL):
		return {"ok": false, "reason_code": &"repair_card_requirements"}
	if card.effects.size() != 1 or not card.effects[0] is StructureRepairEffect or card.effects[0].amount <= 0:
		return {"ok": false, "reason_code": &"repair_effect_unavailable"}
	var status := get_structure_repair_status(target_ref)
	if not status.get("ok", false):
		return status
	var board: Variant = context.tactical_structure_board_state
	var structure: Dictionary = board.get_structure_at_cell(target_ref.cell)
	var source_present := false
	for raw: Variant in context.player.traps:
		if raw is CardData and raw.get_instance_id() == int(structure.source_runtime_id) and StringName(raw.card_id) == structure.source_card_id:
			source_present = true
	if not source_present:
		return {"ok": false, "reason_code": &"repair_source_missing"}
	var hits: Array[Dictionary] = []
	var integrity: int = status.before.integrity_current
	var repeats: int = context.get_effect_repeat()
	var amount: int = card.effects[0].amount
	for index in range(repeats):
		var after := integrity + mini(amount, int(status.before.integrity_max) - integrity)
		hits.append({"index": index, "before": integrity, "after": after, "actual_steps": after - integrity})
		integrity = after
	return {"ok": true, "reason_code": &"ok", "mode": &"p22_repair", "resolved_target": status.target.duplicate(true),
		"before": status.before.duplicate(true), "wall_after": integrity, "hits": hits,
		"actual_steps": integrity - int(status.before.integrity_current), "foundation": status.foundation.duplicate(true),
		"costs": {"load": card.load_cost, "od_gain": context.od_mode.get_od_gain(card), "hp": card.require_hp_cost},
		"expectations": {"card_runtime_id": card.get_instance_id(), "structure": structure, "module": status.before.duplicate(true),
			"terrain": get_cell_state(target_ref.cell), "board_revision": board.get_revision(), "garrison": board.get_garrison_snapshot(),
			"effect_runtime_id": card.effects[0].get_instance_id(), "amount": amount, "repeat": repeats,
			"od": context.od_mode.current_od, "load": context.od_mode.load, "hp": context.player.hp, "player_od": context.player.od,
			"awakening": context.player.is_awakened, "depth": context.depth_pressure, "turn": context.turn_count,
			"requirements": [card.require_od, card.require_load, card.require_hp_cost, card.require_awaken],
			"route_id": card.route_id, "route_step": card.route_step, "engine_gain": card.engine_gain,
			"card_count": context.cards_played_this_turn, "route": context.chain_system.current_route_id, "step": context.chain_system.current_step}}.duplicate(true)


func commit_p22_repair_cast(card: CardData, target_ref: Dictionary, options: Dictionary = {}) -> Dictionary:
	var cast_options := options.duplicate(true)
	cast_options.repair_target = target_ref.duplicate(true)
	return play_card(card, -1, INVALID_GRID_CELL, cast_options)


func _prepare_p22_repair(plan: Dictionary) -> Dictionary:
	if plan.get("fault_stage", &"") == &"before_owner":
		return {"ok": false, "reason_code": &"repair_transaction_failed"}
	var board: Variant = context.tactical_structure_board_state
	var fact: Dictionary = board.commit_repair(plan.resolved_target, plan.actual_steps, {"defer_signal": true})
	if fact.get("ok", false) and plan.get("fault_stage", &"") == &"after_owner":
		board.rollback_repair(fact)
		return {"ok": false, "reason_code": &"repair_transaction_failed"}
	return fact


func _apply_p22_repair_effect(fx_ctx: EffectContext) -> void:
	var plan := fx_ctx.structure_repair_plan
	if plan.is_empty() or not _siege_command_in_progress:
		return
	if not plan.get("prepared", false):
		plan.repair_fact = _prepare_p22_repair(plan)
		plan.prepared = true
		plan.failed = not plan.repair_fact.get("ok", false)
		plan.effect_receipts = []
	if plan.get("failed", false):
		return
	# Repeated callbacks read one locked sequence; never heal the board again.
	var index := fx_ctx.effect_repeat_index
	if index >= 0 and index < plan.hits.size() and plan.effect_receipts.size() == index:
		plan.effect_receipts.append(plan.hits[index].duplicate(true))
		fx_ctx.final_value = int(plan.hits[index].actual_steps)


func get_p18_siege_cast_status(card: CardData, target_ref: Dictionary, _options: Dictionary = {}) -> Dictionary:
	var failed := _siege_query_failure(&"siege_disabled", card, target_ref, "攻城模式未启用")
	failed.mode = &"p18_siege"
	if not tactical_siege_rules.is_enabled():
		return failed
	var profile: Dictionary = tactical_siege_rules.get_profile(&"p18_wall_pierce")
	if profile.is_empty():
		failed.reason_code = &"siege_profile_invalid"
		return failed
	if context == null or context.get_tactical_cell_states().is_empty() or context.tactical_structure_board_state == null:
		failed.reason_code = &"context_missing"
		return failed
	if card == null or card.card_id != "P18" or card.is_front_row_card() or card.is_back_row_card() or not context.player.hand.has(card):
		failed.reason_code = &"siege_card_unavailable"
		return failed
	if card.require_od > context.od_mode.current_od or card.require_load > context.od_mode.load or card.require_hp_cost > context.player.hp \
	or (card.require_awaken and not context.player.is_awakened) or (context.is_abyss_locked() and card.archetype_role != CardData.ArchetypeRole.CONTROL):
		failed.reason_code = &"siege_card_requirements"
		return failed
	failed.reason_code = &"siege_target_stale"
	if target_ref.get("target_kind") != &"structure_module" or not target_ref.get("cell") is Vector2i:
		return failed
	var cell: Vector2i = target_ref.cell
	var board: Variant = context.tactical_structure_board_state
	var structure: Dictionary = board.get_structure_at_cell(cell)
	if structure.is_empty() or structure.get("structure_id") != target_ref.get("structure_id") or structure.get("owner_side") != &"boss":
		return failed
	if target_ref.has("owner_side") and target_ref.owner_side != &"boss":
		return failed
	for field: String in ["expected_terrain_revision", "expected_structure_revision", "expected_module_revision"]:
		if not target_ref.get(field) is int:
			return failed
	var source_present := false
	for raw: Variant in context.enemy.traps:
		if raw is CardData and raw.get_instance_id() == int(structure.source_runtime_id) and StringName(raw.card_id) == structure.source_card_id:
			source_present = true
	if not source_present or not get_structure_damage_status(target_ref, 1).get("ok", false):
		return failed
	var module: Dictionary = board.get_snapshot().modules.get(target_ref.get("module_id"), {})
	if module.get("module_kind") not in [&"wall", &"gatehouse"] or int(module.get("integrity_current", 0)) <= 0:
		return failed
	var secondary := {"target_kind": &"structure_core", "structure_id": structure.structure_id, "cell": cell}
	var secondary_kind: StringName = &"core"
	var secondary_hp := 0
	var assignment: Dictionary = {}
	var assignments: Dictionary = board.get_garrison_snapshot().get("assignments", {})
	var slots: Array = assignments.keys()
	slots.sort()
	for slot: Variant in slots:
		var candidate: Dictionary = assignments[slot]
		if candidate.get("structure_id") != structure.structure_id or candidate.get("state") != &"active":
			continue
		var unit: CardData = _find_field_card_by_runtime_id(int(candidate.unit_runtime_id), &"boss")
		var state: Variant = _state_for_card(unit)
		if state != null and not state.is_dead():
			assignment = candidate.duplicate(true)
			secondary = {"target_kind": &"unit", "unit_runtime_id": unit.get_instance_id(), "structure_id": structure.structure_id, "cell": cell}
			secondary_kind = &"unit"
			secondary_hp = state.current_hp
			break
	var damages: Array[int] = []
	var effect_values: Array[Dictionary] = []
	var echo: int = context.echo_damage_bonus if context.echo_route_id == card.route_id and card.route_id != "" else 0
	var repeats: int = context.get_effect_repeat()
	var heat_extra: bool = context.chain_system != null and context.chain_system.is_route_completed("heat_route") and card.card_name == "Final Slash"
	if card.effects.is_empty():
		failed.reason_code = &"siege_effect_unavailable"
		return failed
	for repeat_index in range(repeats + (1 if heat_extra else 0)):
		for effect: Node in card.effects:
			if not effect is DamageEffect:
				failed.reason_code = &"siege_effect_unavailable"
				return failed
			var damage_effect := effect as DamageEffect
			var values := DamageEffect.calculate_values(damage_effect.base_damage, context.player.od, damage_effect.od_ratio,
				damage_effect._get_zone_damage_bonus(card, context.od_mode.get_zone()), echo,
				context.combo_system.get_od_multiplier(), context.od_mode.get_damage_taken_multiplier())
			echo = 0
			if values.final_value < 0:
				failed.reason_code = &"siege_effect_unavailable"
				return failed
			damages.append(values.final_value)
			effect_values.append(values)
	var plan: Dictionary = TacticalSiegePlannerClass.plan_p18_hits({"wall_integrity": module.integrity_current,
		"secondary_kind": secondary_kind, "secondary_hp": secondary_hp, "secondary_integrity": structure.integrity_current,
		"hp_per_integrity": profile.hp_per_integrity}, damages)
	var result: Dictionary = failed.duplicate(true)
	result.merge(plan, true)
	result.reason_text = "可以攻城施放"
	result.resolved_target = _siege_enrich_ref(target_ref, structure, board)
	result.secondary_target = secondary
	result.canonical_edge = module.canonical_edge
	result.cover_reason = &"selected_wall"
	result.structure_steps = int(module.integrity_current) - int(plan.wall_after)
	result.unit_damage = secondary_hp - int(plan.secondary_hp_after)
	result.effect_values = effect_values
	result.costs = {"od_gain": context.od_mode.get_od_gain(card), "load": card.load_cost, "hp": card.require_hp_cost}
	result.expectations = {"card_runtime_id": card.get_instance_id(), "structure": structure, "module": module, "assignment": assignment,
		"terrain": get_cell_state(cell), "board_revision": board.get_revision(), "garrison_revision": board.get_garrison_snapshot().get("revision"),
		"source_card_requirements": [card.require_od, card.require_load, card.require_hp_cost, card.require_awaken],
		"od": context.od_mode.current_od, "player_od": context.player.od, "load": context.od_mode.load, "hp": context.player.hp,
		"awakening": context.player.is_awakened, "recoil": card.overdrive_self_damage, "repeat": repeats, "heat_extra": heat_extra,
		"echo_route": context.echo_route_id, "echo_bonus": context.echo_damage_bonus, "turn": context.turn_count, "depth": context.depth_pressure,
		"card_count": context.cards_played_this_turn, "route": context.chain_system.current_route_id, "route_step": context.chain_system.current_step}
	return result.duplicate(true)


func commit_p18_siege_cast(card: CardData, target_ref: Dictionary, options: Dictionary = {}) -> Dictionary:
	var cast_options := options.duplicate(true)
	cast_options["siege_target"] = target_ref.duplicate(true)
	return play_card(card, -1, INVALID_GRID_CELL, cast_options)


## The first effect commits the validated whole sequence before consuming Echo
## or route receipts. A rejected sequence leaves those original owners untouched.
func _execute_card_effect_in_context(effect: Object, fx_ctx: EffectContext) -> void:
	if not fx_ctx.siege_cast_plan.is_empty():
		if not bool(fx_ctx.siege_cast_plan.get("prepared", false)):
			var fact := _prepare_p18_siege_damage(fx_ctx.siege_cast_plan)
			fx_ctx.siege_cast_plan["prepared"] = true
			fx_ctx.siege_cast_plan["damage_fact"] = fact
			if not bool(fact.get("ok", false)):
				fx_ctx.siege_cast_plan["failed"] = true
				return
		if bool(fx_ctx.siege_cast_plan.get("failed", false)):
			return
	effect.execute(fx_ctx)


func _prepare_p18_siege_damage(plan: Dictionary) -> Dictionary:
	var board: Variant = context.tactical_structure_board_state
	var cell: Vector2i = plan.resolved_target.cell
	var facts: Array[Dictionary] = []
	var unit: CardData = null
	var unit_hp := 0
	if plan.secondary_target.target_kind == &"unit":
		unit = _find_field_card_by_runtime_id(int(plan.secondary_target.unit_runtime_id), &"boss")
		unit_hp = _state_for_card(unit).current_hp
	var failure := false
	for hit: Dictionary in plan.hits:
		if int(hit.wall_damage) > 0:
			var ref: Dictionary = board.make_module_target_ref(cell, plan.resolved_target.edge, get_cell_state(cell).revision)
			var fact := commit_structure_damage(ref, hit.wall_damage, &"p18_siege", {"defer_signal": true, "defer_aftermath": true})
			if not fact.get("ok", false):
				failure = true
				break
			facts.append(fact)
			if plan.get("fault_stage", &"") == &"after_wall":
				failure = true
				break
		if int(hit.unit_damage) > 0:
			var damage := damage_unit(unit, int(hit.unit_damage), "p18_siege", {"defer_signal": true})
			if not damage.get("ok", false) or damage.applied != hit.unit_damage or plan.get("fault_stage", &"") == &"after_unit":
				failure = true
				break
		if int(hit.core_damage) > 0:
			var ref: Dictionary = board.make_core_target_ref(cell, get_cell_state(cell).revision)
			var fact := commit_structure_damage(ref, hit.core_damage, &"p18_siege", {"defer_signal": true, "defer_aftermath": true,
				"phase_c_force_terrain_commit_failure": bool(plan.get("fault_core", false))})
			if not fact.get("ok", false):
				failure = true
				break
			facts.append(fact)
	if failure:
		# Core cleanup rolls itself back before returning failure. Earlier module or
		# nonlethal core writes restore in reverse order; aftermath has not run yet.
		for index in range(facts.size() - 1, -1, -1):
			board.rollback_damage(facts[index])
		if unit != null:
			_state_for_card(unit).current_hp = unit_hp
		return {"ok": false, "reason_code": &"siege_transaction_failed"}
	var unit_destroyed_fact: Dictionary = {}
	if unit != null and _state_for_card(unit).is_dead():
		var cleared := _clear_garrison_assignment(board.get_garrison_for_unit(unit.get_instance_id()), &"unit_removed", &"garrison_unit_cleanup", false)
		unit_destroyed_fact = {"unit_runtime_id": unit.get_instance_id(), "owner_side": &"boss", "reason": "p18_siege", "garrison": cleared}
		_destroy_field_unit(unit, "p18_siege", true)
	var core_destroyed: bool = facts.any(func(fact): return bool(fact.get("core_destroyed", false)))
	for fact: Dictionary in facts:
		if not core_destroyed or bool(fact.get("core_destroyed", false)):
			fact.garrison_aftermath = resolve_garrison_aftermath(fact, true)
	return {"ok": true, "structure_facts": facts, "unit_destroyed": unit_destroyed_fact,
		"unit_runtime_id": unit.get_instance_id() if unit != null else 0}


func _publish_p18_siege_damage(plan: Dictionary) -> void:
	var damage: Dictionary = plan.get("damage_fact", {})
	var dead: Dictionary = damage.get("unit_destroyed", {})
	if not dead.is_empty():
		if not dead.get("garrison", {}).is_empty():
			garrison_transaction_committed.emit(dead.garrison.duplicate(true))
		var card: CardData = instance_from_id(dead.unit_runtime_id) as CardData
		unit_destroyed.emit(card, dead.owner_side, dead.reason)
	elif int(damage.get("unit_runtime_id", 0)) != 0:
		var card: CardData = _find_field_card_by_runtime_id(damage.unit_runtime_id, &"boss")
		if card != null:
			_emit_unit_state(card)
	for fact: Dictionary in damage.get("structure_facts", []):
		publish_structure_damage_notifications(fact)
	var tree := Engine.get_main_loop() as SceneTree
	var am := tree.root.get_node_or_null("AudioManager") if tree != null else null
	if am != null and am.has_method("play_sfx"):
		for index in range(int(plan.get("hit_sounds", 0))):
			am.play_sfx("hit")


## Private boundary receipts use the original turn serial, not a second clock.
var _boss_siege_preparing := false
var _boss_siege_resolving_intent_id: StringName = &""

func _boss_siege_blank(reason: StringName = &"boss_siege_no_pending") -> Dictionary:
	return {"ok": false, "active": false, "intent_id": &"", "status": &"none", "announced_turn": -1,
		"actor_runtime_id": 0, "target": {}, "reason_code": reason}

func get_boss_siege_intent_status() -> Dictionary:
	if context == null or context._boss_siege_pending_intent.is_empty():
		return _boss_siege_blank()
	var result: Dictionary = context._boss_siege_pending_intent.duplicate(true)
	result.active = result.get("status") == &"pending"
	if result.active:
		var actor: CardData = _find_field_card_by_runtime_id(int(result.actor_runtime_id), &"boss")
		var target := _boss_siege_current_target(result)
		if actor != null and not target.is_empty():
			var preview := _get_siege_attack_status(actor, target, {}, true)
			result.preview = preview
			result.structure_steps = int(preview.get("structure_steps", 0))
			if bool(preview.get("ok", false)):
				result.target = preview.requested_target.duplicate(true)
	return result

func _on_player_siege_window_begin() -> Dictionary:
	if context == null or not tactical_siege_rules.is_enabled():
		return _boss_siege_blank(&"siege_disabled")
	if context._boss_siege_player_window_turn == context.turn_count:
		return get_boss_siege_intent_status()
	context._boss_siege_player_window_turn = context.turn_count
	context._boss_siege_tactical_window_turn = -1
	context._boss_siege_pending_intent = {}
	_boss_siege_preparing = true
	var result := prepare_boss_siege_intent()
	_boss_siege_preparing = false
	return result

func prepare_boss_siege_intent() -> Dictionary:
	if context == null:
		return _boss_siege_blank()
	if get_boss_terrain_intent_status().get("active", false):
		return _boss_siege_blank(&"terrain_threat_already_pending")
	if not context._boss_siege_pending_intent.is_empty():
		return get_boss_siege_intent_status()
	if not _boss_siege_preparing:
		return _boss_siege_blank(&"boss_siege_player_window_required")
	if tactical_siege_rules.get_profile(&"boss_b07_breach").is_empty():
		return _boss_siege_blank(&"siege_profile_invalid")
	var actors: Array[CardData] = []
	for raw: Variant in context.enemy.field:
		if raw is CardData and raw.card_id == "B-07" and _state_for_card(raw) != null and not _state_for_card(raw).is_dead():
			actors.append(raw)
	actors.sort_custom(func(a: CardData, b: CardData) -> bool:
		var ac := get_unit_cell(a)
		var bc := get_unit_cell(b)
		return ac.y < bc.y if ac.y != bc.y else (ac.x < bc.x if ac.x != bc.x else a.get_instance_id() < b.get_instance_id()))
	var targets: Array[Dictionary] = []
	var board: Variant = context.tactical_structure_board_state
	for cell: Vector2i in tactical_grid_rules.get_all_cells():
		var structure: Dictionary = board.get_structure_at_cell(cell)
		if structure.is_empty() or structure.owner_side != &"player":
			continue
		for edge: StringName in [&"north", &"east", &"south", &"west"]:
			var module: Dictionary = board.get_module_at_edge(cell, edge)
			if module.get("structure_id") == structure.structure_id and int(module.get("integrity_current", 0)) > 0:
				var target: Dictionary = board.make_module_target_ref(cell, edge, get_cell_state(cell).revision)
				target.canonical_edge = module.canonical_edge
				targets.append(target)
	targets.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.cell.y < b.cell.y if a.cell.y != b.cell.y else (a.cell.x < b.cell.x if a.cell.x != b.cell.x else String(a.canonical_edge) < String(b.canonical_edge)))
	for actor: CardData in actors:
		for target: Dictionary in targets:
			var query := _get_siege_attack_status(actor, target, {}, true)
			if not query.get("ok", false):
				continue
			context._boss_siege_pending_intent = {"ok": true, "active": true, "status": &"pending", "reason_code": &"ok",
				"intent_id": StringName("boss_siege:%d:%d:%s" % [context.turn_count, actor.get_instance_id(), String(target.module_id)]),
				"announced_turn": context.turn_count, "actor_runtime_id": actor.get_instance_id(), "target": target.duplicate(true),
				"canonical_edge": target.canonical_edge, "structure_id": target.structure_id, "module_id": target.module_id,
				"label": "B-07 预备攻城：下个 Boss 回合卡牌结算后、战术行动开始时攻击此墙（1耐久）"}
			return get_boss_siege_intent_status()
	return _boss_siege_blank(&"boss_siege_no_legal_target")

func _boss_siege_current_target(pending: Dictionary) -> Dictionary:
	var old: Dictionary = pending.get("target", {})
	if not old.get("cell") is Vector2i:
		return {}
	var board: Variant = context.tactical_structure_board_state
	var structure: Dictionary = board.get_structure_at_cell(old.cell)
	var module: Dictionary = board.get_module_at_edge(old.cell, old.get("edge", &""))
	if structure.get("structure_id") != old.get("structure_id") or module.get("module_id") != old.get("module_id") or int(module.get("integrity_current", 0)) <= 0:
		return {}
	return board.make_module_target_ref(old.cell, old.edge, get_cell_state(old.cell).revision)

func _boss_siege_attack_authorized(actor: CardData, target: Dictionary) -> bool:
	if context == null or actor == null or _boss_siege_resolving_intent_id == &"":
		return false
	var pending: Dictionary = context._boss_siege_pending_intent
	return pending.get("intent_id") == _boss_siege_resolving_intent_id and pending.get("status") == &"resolving" \
		and pending.get("actor_runtime_id") == actor.get_instance_id() and target.get("target_kind") == &"structure_module" \
		and pending.get("module_id") == target.get("module_id") and pending.get("structure_id") == target.get("structure_id")

func _on_boss_siege_tactical_start() -> Dictionary:
	if context == null or not tactical_siege_rules.is_enabled():
		return _boss_siege_blank(&"siege_disabled")
	if bool(get_command_economy_snapshot("player").get("turn_open", false)):
		return _boss_siege_blank(&"boss_siege_window_not_complete")
	context._boss_siege_tactical_window_turn = context.turn_count
	return resolve_boss_siege_intent()

func resolve_boss_siege_intent() -> Dictionary:
	var pending := get_boss_siege_intent_status()
	if pending.get("status") != &"pending":
		pending.ok = false
		pending.reason_code = &"boss_siege_already_resolved" if pending.get("intent_id", &"") != &"" else &"boss_siege_no_pending"
		return pending
	if context._boss_siege_tactical_window_turn != pending.announced_turn or context.turn_count != pending.announced_turn:
		var early := pending.duplicate(true)
		early.ok = false
		early.reason_code = &"boss_siege_window_not_complete"
		return early
	if tactical_siege_rules.get_profile(&"boss_b07_breach").is_empty():
		return clear_boss_siege_intent(&"siege_profile_invalid")
	var actor: CardData = _find_field_card_by_runtime_id(int(pending.actor_runtime_id), &"boss")
	var target := _boss_siege_current_target(pending)
	if actor == null or actor.card_id != "B-07" or target.is_empty():
		return clear_boss_siege_intent(&"boss_siege_identity_lost")
	context._boss_siege_pending_intent.status = &"resolving"
	_boss_siege_resolving_intent_id = pending.intent_id
	var result := execute_unit_command(actor, "attack", target)
	_boss_siege_resolving_intent_id = &""
	context._boss_siege_pending_intent.status = &"resolved" if bool(result.get("ok", false)) else &"cancelled"
	context._boss_siege_pending_intent.reason_code = result.get("reason_code", &"ok")
	context._boss_siege_pending_intent["result"] = {"ok": result.get("ok", false), "reason_code": result.get("reason_code", &"ok"),
		"cost": result.get("cost", 0), "structure_steps": result.get("structure_steps", 0), "transaction_id": result.get("transaction_id", &"")}
	result.intent_id = pending.intent_id
	return result

func clear_boss_siege_intent(reason: StringName) -> Dictionary:
	var current := get_boss_siege_intent_status()
	if current.get("status") == &"pending":
		context._boss_siege_pending_intent.status = &"cancelled"
		context._boss_siege_pending_intent.reason_code = reason
		context._boss_siege_pending_intent.ok = false
		current = get_boss_siege_intent_status()
	current.ok = false
	return current


# F2 uses a disabled-by-default experiment snapshot and the original board owners.
func configure_boss_terrain_threat(enabled: bool) -> void:
	context.boss_terrain_intent.enabled = enabled
	if not enabled:
		clear_boss_terrain_intent(&"terrain_threat_disabled")

func get_boss_terrain_cast_status() -> Dictionary:
	return context.boss_terrain_intent.query(self)

func get_boss_terrain_card_status(card: CardData) -> Dictionary:
	if card == null or card.card_id != "B-18" or context.enemy.graveyard.has(card):
		return {"ok": false, "reason_code": &"terrain_threat_card_invalid"}
	return get_boss_terrain_cast_status()

func get_boss_terrain_intent_status() -> Dictionary:
	return context.boss_terrain_intent.status(self) if context != null else {"ok": false, "active": false}

func _on_player_terrain_window_begin() -> void:
	context.boss_terrain_intent.player_begin(self)

func _on_boss_terrain_tactical_start() -> Dictionary:
	return context.boss_terrain_intent.resolve(self)

func clear_boss_terrain_intent(reason: StringName) -> void:
	if context != null:
		context.boss_terrain_intent.clear(reason)

var tactical_terrain_raise_rules: RefCounted = preload("res://core/config/tactical_terrain_raise_rule_snapshot.gd").new()

func configure_tactical_terrain_raise_rules(snapshot: RefCounted) -> void:
	tactical_terrain_raise_rules = snapshot

func make_terrain_raise_target_ref(cell: Vector2i) -> Dictionary:
	if context == null or not _ensure_tactical_board_state() or get_cell_state(cell).is_empty():
		return {}
	var board: Variant = context.tactical_structure_board_state
	var unit := get_unit_at_cell(cell)
	return {"cell": cell, "terrain": get_cell_state(cell), "structure": board.get_structure_at_cell(cell),
		"board_revision": board.get_revision(), "garrison": board.get_garrison_snapshot(),
		"occupant_runtime_id": unit.get_instance_id() if unit != null else 0}

func get_p23_terrain_raise_cast_status(card: CardData, target_ref: Dictionary) -> Dictionary:
	if _siege_command_in_progress:
		return {"ok": false, "reason_code": &"siege_command_in_progress"}
	if tactical_terrain_raise_rules == null or not tactical_terrain_raise_rules.is_enabled():
		return {"ok": false, "reason_code": &"terrain_raise_disabled"}
	if context == null or card == null or card.card_id != "P23" or card.is_front_row_card() or card.is_back_row_card() or not context.player.hand.has(card):
		return {"ok": false, "reason_code": &"terrain_raise_card_unavailable"}
	if card.require_od > context.od_mode.current_od or card.require_load > context.od_mode.load or card.require_hp_cost > context.player.hp \
	or (card.require_awaken and not context.player.is_awakened) or (context.is_abyss_locked() and card.archetype_role != CardData.ArchetypeRole.CONTROL):
		return {"ok": false, "reason_code": &"terrain_raise_card_requirements"}
	if card.effects.size() != 1 or not is_instance_valid(card.effects[0]) or card.effects[0].get_script() != preload("res://core/effect/terrain_raise_effect.gd") or card.effects[0].amount != 1:
		return {"ok": false, "reason_code": &"terrain_raise_effect_unavailable"}
	if not target_ref.get("cell") is Vector2i:
		return {"ok": false, "reason_code": &"terrain_raise_cell_required"}
	var cell: Vector2i = target_ref.cell
	if target_ref != make_terrain_raise_target_ref(cell):
		return {"ok": false, "reason_code": &"terrain_raise_target_stale"}
	if not tactical_grid_rules.is_normal_summon_cell(&"player", cell):
		return {"ok": false, "reason_code": &"terrain_raise_outside_build_zone"}
	var structure: Dictionary = target_ref.structure
	var unit := get_unit_at_cell(cell)
	if not structure.is_empty():
		if structure.owner_side != &"player" or int(structure.integrity_current) <= 0:
			return {"ok": false, "reason_code": &"terrain_raise_hostile_structure"}
		var source_present := false
		for raw: Variant in context.player.traps:
			if raw is CardData and raw.get_instance_id() == int(structure.source_runtime_id) and StringName(raw.card_id) == structure.source_card_id:
				source_present = true
		if not source_present:
			return {"ok": false, "reason_code": &"terrain_raise_source_missing"}
	if unit != null:
		var assignment: Dictionary = context.tactical_structure_board_state.get_garrison_for_unit(unit.get_instance_id())
		if structure.is_empty() or not context.player.field.has(unit) or assignment.get("state") != &"active" or assignment.get("structure_id") != structure.structure_id:
			return {"ok": false, "reason_code": &"terrain_raise_occupied"}
	var height: int = target_ref.terrain.height
	if height >= 2:
		return {"ok": false, "reason_code": &"terrain_raise_height_cap"}
	var repeats: int = context.get_effect_repeat()
	var hits: Array[Dictionary] = []
	var final_height := height
	for index in range(repeats):
		var next_height := mini(2, final_height + 1)
		hits.append({"index": index, "before": final_height, "after": next_height, "actual_steps": next_height - final_height})
		final_height = next_height
	var changes: Array[Dictionary] = [{"cell": cell, "expected_height": height,
		"expected_revision": target_ref.terrain.revision, "target_height": height + 1, "target_surface": target_ref.terrain.surface}]
	var status := get_cell_state_change_status(changes, {"turn_side": &"player"})
	if not status.get("ok", false):
		return status
	return {"ok": true, "reason_code": &"ok", "mode": &"p23_terrain_raise", "resolved_target": target_ref.duplicate(true),
		"before": target_ref.terrain.duplicate(true), "height_after": final_height, "hits": hits,
		"actual_steps": final_height - height,
		"costs": {"load": card.load_cost, "od_gain": context.od_mode.get_od_gain(card), "hp": card.require_hp_cost},
		"expectations": {"card_runtime_id": card.get_instance_id(), "effect_runtime_id": card.effects[0].get_instance_id(),
			"repeat": repeats, "od": context.od_mode.current_od, "load": context.od_mode.load, "hp": context.player.hp,
			"player_od": context.player.od, "awakening": context.player.is_awakened, "depth": context.depth_pressure,
			"turn": context.turn_count, "requirements": [card.require_od, card.require_load, card.require_hp_cost, card.require_awaken],
			"route_id": card.route_id, "route_step": card.route_step, "engine_gain": card.engine_gain,
			"card_count": context.cards_played_this_turn, "route": context.chain_system.current_route_id, "step": context.chain_system.current_step}}.duplicate(true)

func commit_p23_terrain_raise_cast(card: CardData, target_ref: Dictionary, options: Dictionary = {}) -> Dictionary:
	var cast_options := options.duplicate(true)
	cast_options.terrain_raise_target = target_ref.duplicate(true)
	return play_card(card, -1, INVALID_GRID_CELL, cast_options)

func _rollback_p23_terrain_raise(receipts: Array[Dictionary]) -> void:
	for index in range(receipts.size() - 1, -1, -1):
		context.tactical_structure_board_state.rollback_foundation_reconcile(receipts[index].get("foundation", {}))
		context.tactical_board_state.rollback_changes(receipts[index].get("terrain", {}))

func _prepare_p23_terrain_raise(plan: Dictionary) -> Dictionary:
	var failed := {"ok": false, "reason_code": &"terrain_raise_transaction_failed"}
	if not _siege_command_in_progress or plan.get("fault_stage", &"") == &"before_owner":
		return failed
	if plan.resolved_target != make_terrain_raise_target_ref(plan.resolved_target.cell):
		return failed
	var receipts: Array[Dictionary] = []
	var options := {"defer_signal": true, "turn_side": &"player"}
	for hit: Dictionary in plan.hits:
		if hit.actual_steps == 0:
			continue
		var state := get_cell_state(plan.resolved_target.cell)
		var changes: Array[Dictionary] = [{"cell": plan.resolved_target.cell, "expected_height": state.height,
			"expected_revision": state.revision, "target_height": hit.after, "target_surface": state.surface}]
		var status := get_cell_state_change_status(changes, options)
		var foundation := _prepare_foundation_reconcile_from_terrain_fact(_project_terrain_fact(changes, &"p23_terrain_raise"), options, [], false)
		if not status.get("ok", false) or not foundation.get("ok", false) or (hit.index == 1 and plan.get("fault_stage", &"") == &"second_segment"):
			_rollback_p23_terrain_raise(receipts)
			return failed
		var terrain_fact: Dictionary = context.tactical_board_state.commit_changes(changes, &"p23_terrain_raise", options)
		if not terrain_fact.get("ok", false):
			_rollback_p23_terrain_raise(receipts)
			return failed
		var receipt := {"terrain": terrain_fact, "foundation": {}}
		receipts.append(receipt)
		if plan.get("fault_stage", &"") == &"after_terrain":
			_rollback_p23_terrain_raise(receipts)
			return failed
		receipt.foundation = context.tactical_structure_board_state.commit_foundation_reconcile(foundation.plan, options)
		if not receipt.foundation.get("ok", false) or plan.get("fault_stage", &"") == &"after_foundation":
			_rollback_p23_terrain_raise(receipts)
			return failed
	return {"ok": true, "receipts": receipts}

func _publish_p23_terrain_raise(plan: Dictionary) -> void:
	var receipts: Array = plan.raise_fact.receipts
	if receipts.is_empty():
		return
	var terrain: Dictionary = receipts[0].terrain.duplicate(true)
	terrain.changes[0].after = receipts[-1].terrain.changes[0].after.duplicate(true)
	var foundation: Dictionary = {}
	for receipt: Dictionary in receipts:
		var fact: Dictionary = receipt.foundation
		if not fact.get("changed", false):
			continue
		if foundation.is_empty():
			foundation = fact.duplicate(true)
		else:
			foundation.revision = fact.revision
			foundation.structure_revision = fact.structure_revision
			foundation.foundation_after = fact.foundation_after.duplicate(true)
			foundation.transitions[0].after = fact.transitions[0].after.duplicate(true)
			foundation.transitions[0].foundation_after = fact.transitions[0].foundation_after.duplicate(true)
	context.tactical_board_state.publish_changes_fact(terrain)
	context.tactical_structure_board_state.publish_foundation_fact(foundation)

func _apply_p23_terrain_raise_effect(fx_ctx: EffectContext) -> void:
	var plan := fx_ctx.terrain_raise_plan
	if plan.is_empty() or not _siege_command_in_progress:
		return
	if not plan.get("prepared", false):
		plan.raise_fact = _prepare_p23_terrain_raise(plan)
		plan.prepared = true
		plan.failed = not plan.raise_fact.get("ok", false)
		plan.effect_receipts = []
	if plan.get("failed", false):
		return
	var index := fx_ctx.effect_repeat_index
	if index >= 0 and index < plan.hits.size() and plan.effect_receipts.size() == index:
		plan.effect_receipts.append(plan.hits[index].duplicate(true))
		fx_ctx.final_value = int(plan.hits[index].actual_steps)
