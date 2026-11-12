extends RefCounted
class_name GameConfig

## Phase 25A: 业务配置 API 包装
## 面向战斗代码的窄 API，隐藏 JSON 字段细节。
## 所有方法都有安全默认值 fallback。

const Registry := preload("res://core/config/config_registry.gd")
const Validator := preload("res://core/config/config_validator.gd")
const BattleRuleSnapshotClass := preload("res://core/config/battle_rule_snapshot.gd")
const MonsterCombatRuleSnapshotClass := preload("res://core/config/monster_combat_rule_snapshot.gd")
const CombatPresentationProfileClass := preload("res://core/config/combat_presentation_profile.gd")
const ODCoreCommandRuleSnapshotClass := preload("res://core/config/od_core_command_rule_snapshot.gd")
const TacticalGridRuleSnapshotClass := preload("res://core/config/tactical_grid_rule_snapshot.gd")
const ODCompanionPresentationProfileClass := preload("res://core/config/od_companion_presentation_profile.gd")
const TacticalGridPresentationProfileClass := preload("res://core/config/tactical_grid_presentation_profile.gd")
const TacticalUnitPatternSnapshotClass := preload("res://core/config/tactical_unit_pattern_snapshot.gd")
const TacticalCoreFacingRuleSnapshotClass := preload("res://core/config/tactical_core_facing_rule_snapshot.gd")
const TacticalCommandEconomySnapshotClass := preload("res://core/config/tactical_command_economy_snapshot.gd")
const MonsterHeroSkillSnapshotClass := preload("res://core/config/monster_hero_skill_snapshot.gd")  # Phase 27E
const BossTacticalAIProfileClass := preload("res://core/config/boss_tactical_ai_profile.gd")  # Phase 27F
const CardPieceTraitSnapshotClass := preload("res://core/config/card_piece_trait_snapshot.gd")  # Phase 27I-R0
const ODReleaseRuleSnapshotClass := preload("res://core/config/od_release_rule_snapshot.gd")  # Phase 27J
const ODPresentationSnapshotClass := preload("res://core/config/od_presentation_snapshot.gd")  # Phase 27K-R0
const ODFlowFeedbackSnapshotClass := preload("res://core/config/od_flow_feedback_snapshot.gd")  # Phase 27K-R1-A
const TacticalStructureRuleSnapshotClass := preload("res://core/config/tactical_structure_rule_snapshot.gd")  # Phase C
const TacticalStructurePresentationProfileClass := preload("res://core/config/tactical_structure_presentation_profile.gd")  # Phase C presentation
const TacticalGarrisonRuleSnapshotClass := preload("res://core/config/tactical_garrison_rule_snapshot.gd")  # Phase D1
const TacticalSiegeRuleSnapshotClass := preload("res://core/config/tactical_siege_rule_snapshot.gd")  # Phase E


# ── 一次性初始化 ──

static var _initialized: bool = false
static var _reported_tactical_structure_presentation_errors: Dictionary = {}
static var _reported_tactical_siege_errors: Dictionary = {}

static func ensure_loaded() -> void:
	if _initialized:
		return
	_initialized = true
	Registry.load_all()
	Validator.validate_all()


static func create_tactical_siege_rule_snapshot(report_errors: bool = true, table_override: Dictionary = {}) -> RefCounted:
	ensure_loaded()
	var table: Dictionary = table_override if not table_override.is_empty() else Registry.get_table("tactical_siege_rules")
	var snapshot := TacticalSiegeRuleSnapshotClass.new(table)
	var errors: Array[String] = Validator.validate_tactical_siege_rules_table(table)
	if table_override.is_empty():
		errors.append_array(Registry.get_tactical_siege_load_errors())
	if report_errors:
		_report_tactical_siege_errors(errors, _emit_tactical_siege_error)
	return snapshot


## Injectable diagnostic sink; capability filtering never depends on reporting.
static func _report_tactical_siege_errors(errors: Array[String], sink: Callable) -> void:
	var fresh: Array[String] = []
	for error in errors:
		if not _reported_tactical_siege_errors.has(error):
			_reported_tactical_siege_errors[error] = true
			fresh.append(error)
	if not fresh.is_empty():
		sink.call("[CONFIG ERROR] " + "; ".join(fresh))


static func _emit_tactical_siege_error(message: String) -> void:
	push_error(message)


# ── battle_rules ──

static func get_starting_hand_size() -> int:
	ensure_loaded()
	return Registry.get_value("battle_rules", "starting_hand_size", 6)


static func get_max_hand_size() -> int:
	ensure_loaded()
	return Registry.get_value("battle_rules", "max_hand_size", 7)


static func get_player_start_hp() -> int:
	ensure_loaded()
	return Registry.get_value("battle_rules", "player_start_hp", 35)


static func get_turn_draw_count() -> int:
	ensure_loaded()
	return Registry.get_value("battle_rules", "turn_draw_count", 1)


static func get_fatigue_base_damage() -> int:
	ensure_loaded()
	return Registry.get_value("battle_rules", "fatigue_base_damage", 1)


# ── od_depth_rules ──

static func get_od_max() -> int:
	ensure_loaded()
	return Registry.get_value("od_depth_rules", "od_max", 10)


## 根据 OD 值返回区间名称 — "Calm", "Heated", "Overdrive"
static func get_od_zone(od_value: int) -> String:
	ensure_loaded()
	var zones: Array = Registry.get_value("od_depth_rules", "zones", [])
	if zones.is_empty():
		# fallback
		if od_value <= 3:
			return "Calm"
		elif od_value <= 7:
			return "Heated"
		return "Overdrive"
	for z in zones:
		if z is Dictionary:
			var zmin: int = z.get("min", -1)
			var zmax: int = z.get("max", -1)
			if od_value >= zmin and od_value <= zmax:
				return z.get("id", "Unknown")
	return "Unknown"


static func get_depth_max() -> int:
	ensure_loaded()
	return Registry.get_value("od_depth_rules", "depth.max", 6)


static func get_depth_end_turn_recover() -> int:
	ensure_loaded()
	return Registry.get_value("od_depth_rules", "depth.end_turn_recover", 2)


static func get_depth_backlash_threshold() -> int:
	ensure_loaded()
	return Registry.get_value("od_depth_rules", "depth.backlash_threshold", 6)


static func get_depth_control_reduce() -> int:
	ensure_loaded()
	return Registry.get_value("od_depth_rules", "depth.control_reduce", 1)


# ── Phase 25B: 规则快照工厂 ──

static func create_battle_rule_snapshot(report_errors: bool = true):
	ensure_loaded()
	var errors: Array[String] = Registry.get_errors()
	errors.append_array(Validator.validate_all())
	if not errors.is_empty():
		if report_errors:
			for error in errors:
				push_error("[CONFIG ERROR] %s" % error)
		return BattleRuleSnapshotClass.default_snapshot(errors)
	var table: Dictionary = Registry.get_table("od_depth_rules").duplicate(true)
	return BattleRuleSnapshotClass.new(table, false, [])


# ── encounter ──

static func get_encounter(encounter_id: String) -> Dictionary:
	ensure_loaded()
	var t := Registry.get_table("encounter")
	if t.is_empty():
		return {}
	var eid: String = t.get("encounter_id", "")
	if eid != encounter_id:
		print_rich("[color=yellow][CONFIG][/color] Encounter '%s' not found (loaded: '%s')" % [encounter_id, eid])
		return {}
	return t


static func get_encounter_field(encounter_id: String, field: String, fallback = null):
	var enc := get_encounter(encounter_id)
	if enc.is_empty():
		return fallback
	return enc.get(field, fallback)


# ── boss_deck ──

static func get_boss_deck(deck_id: String) -> Dictionary:
	ensure_loaded()
	var table: Dictionary = Registry.get_table("boss_deck")
	if table.get("deck_id", "") != deck_id:
		return {}
	return table.duplicate(true)


static func get_boss_pool(deck_id: String, zone_id: String) -> Array:
	var deck := get_boss_deck(deck_id)
	var pools = deck.get("pools", {})
	if not pools is Dictionary:
		return []
	var entries = pools.get(zone_id, [])
	return entries.duplicate(true) if entries is Array else []


# ── localization ──

## 获取本地化文本。若 key 缺失则返回 fallback；若 fallback 为空则返回 key 本身。
static func text(key: String, fallback: String = "") -> String:
	ensure_loaded()
	var loc := Registry.get_table("localization")
	if loc.is_empty():
		return fallback if fallback != "" else key
	if loc.has(key):
		var val = loc[key]
		if val is String:
			return val
	return fallback if fallback != "" else key


# ── Phase 25D: monster_combat_rules ──

static func create_monster_combat_rule_snapshot(report_errors: bool = true):
	ensure_loaded()
	var table: Dictionary = Registry.get_table("monster_combat_rules").duplicate(true)
	var errors: Array[String] = Registry.get_errors()
	errors.append_array(Validator.validate_monster_combat_rules_table(table))
	if not errors.is_empty():
		if report_errors:
			for error in errors:
				push_error("[CONFIG ERROR] %s" % error)
		return MonsterCombatRuleSnapshotClass.default_snapshot(errors)
	return MonsterCombatRuleSnapshotClass.new(table, false, [])

# ── Phase 26B-T2: combat_presentation ──

static func create_combat_presentation_profile(report_errors: bool = true):
	ensure_loaded()
	var table: Dictionary = Registry.get_table("combat_presentation").duplicate(true)
	var errors: Array[String] = Registry.get_errors()
	errors.append_array(Validator.validate_combat_presentation_table(table))
	if not errors.is_empty():
		if report_errors:
			for error in errors:
				push_error("[CONFIG ERROR] %s" % error)
		return CombatPresentationProfileClass.default_profile(errors)
	var monster_attack: Dictionary = table.get("monster_attack", {})
	var spell_activation: Dictionary = table.get("spell_activation", {})
	var ascension: Dictionary = table.get("ascension", {})
	var orchestration: Dictionary = table.get("orchestration", {})
	var od_release_choreography: Dictionary = table.get("od_release_choreography", {})
	var monster_summon: Dictionary = table.get("monster_summon", {})
	var result_feedback: Dictionary = table.get("result_feedback", {})
	var piece_sigils: Dictionary = table.get("piece_sigils", {})
	var audio_cues: Dictionary = table.get("audio_cues", {})
	var accessibility: Dictionary = table.get("accessibility", {})
	var world_visual_language: Dictionary = table.get("world_visual_language", {})
	var card_direction_profiles: Dictionary = table.get("card_direction_profiles", {})
	return CombatPresentationProfileClass.new(
		monster_attack,
		spell_activation,
		ascension,
		false,
		[],
		orchestration,
		od_release_choreography,
		monster_summon,
		result_feedback,
		piece_sigils,
		audio_cues,
		accessibility,
		world_visual_language,
		card_direction_profiles,
	)


# ── Phase 26C: od_core_commands ──

static func create_od_core_command_rule_snapshot(report_errors: bool = true) -> RefCounted:
	ensure_loaded()
	var table: Dictionary = Registry.get_table("od_core_commands").duplicate(true)
	var localization: Dictionary = Registry.get_table("localization")
	var errors: Array[String] = Registry.get_errors()
	errors.append_array(Validator.validate_od_core_commands_table(table, localization))
	if not errors.is_empty():
		if report_errors:
			for error in errors:
				push_error("[CONFIG ERROR] %s" % error)
		return ODCoreCommandRuleSnapshotClass.new({})
	return ODCoreCommandRuleSnapshotClass.new(table)


# ── Phase 26D: od_companion_presentation ──

static func create_od_companion_presentation_profile(report_errors: bool = true) -> RefCounted:
	ensure_loaded()
	var table: Dictionary = Registry.get_table("od_companion_presentation").duplicate(true)
	var errors: Array[String] = Registry.get_errors()
	errors.append_array(Validator.validate_od_companion_presentation_table(table))
	if not errors.is_empty():
		if report_errors:
			for error in errors:
				push_error("[CONFIG ERROR] %s" % error)
		var fallback := ODCompanionPresentationProfileClass.new()
		fallback._apply_defaults()
		fallback._used_fallback = true
		fallback._validation_errors = errors.duplicate()
		return fallback
	return ODCompanionPresentationProfileClass.new(table, false, [])

# ── Phase 27A: tactical_grid_rules ──

static func create_tactical_grid_rule_snapshot(report_errors: bool = true) -> RefCounted:
	ensure_loaded()
	var table: Dictionary = Registry.get_table("tactical_grid_rules").duplicate(true)
	var errs: Array[String] = Registry.get_errors()
	errs.append_array(Validator.validate_tactical_grid_rules_table(table))
	if not errs.is_empty():
		if report_errors:
			for error in errs:
				push_error("[CONFIG ERROR] %s" % error)
		return TacticalGridRuleSnapshotClass.default_snapshot(errs)
	return TacticalGridRuleSnapshotClass.new(table, false, [])


# ── Phase 27A-R1: tactical_grid_presentation ──

static func create_tactical_grid_presentation_profile(report_errors: bool = true) -> RefCounted:
	ensure_loaded()
	var table: Dictionary = Registry.get_table("tactical_grid_presentation").duplicate(true)
	var registry_errors: Array[String] = Registry.get_errors()
	if table.is_empty():
		if report_errors:
			for error in registry_errors:
				push_error("[CONFIG ERROR] %s" % error)
		return TacticalGridPresentationProfileClass.default_profile(registry_errors)
	var errors: Array[String] = Validator.validate_tactical_grid_presentation_table(table)
	if not errors.is_empty() and report_errors:
		for error in errors:
			push_error("[CONFIG ERROR] %s" % error)
	return TacticalGridPresentationProfileClass.new(table, not errors.is_empty(), errors)


# ── Phase 27B: tactical_unit_patterns ──

static func create_tactical_unit_pattern_snapshot(report_errors: bool = true) -> RefCounted:
	ensure_loaded()
	var table: Dictionary = Registry.get_table("tactical_unit_patterns").duplicate(true)
	var errors: Array[String] = Registry.get_errors()
	errors.append_array(Validator.validate_tactical_unit_patterns_table(table))
	if not errors.is_empty():
		if report_errors:
			for error in errors:
				push_error("[CONFIG ERROR] %s" % error)
		return TacticalUnitPatternSnapshotClass.default_snapshot(errors)
	return TacticalUnitPatternSnapshotClass.new(table, false, [])


# ── Phase 27C: tactical_core_facing_rules ──

static func create_tactical_core_facing_rule_snapshot(report_errors: bool = true) -> RefCounted:
	ensure_loaded()
	var table: Dictionary = Registry.get_table("tactical_core_facing_rules").duplicate(true)
	var errors: Array[String] = Registry.get_errors()
	errors.append_array(Validator.validate_tactical_core_facing_rules_table(table))
	if not errors.is_empty():
		if report_errors:
			for error in errors:
				push_error("[CONFIG ERROR] %s" % error)
		return TacticalCoreFacingRuleSnapshotClass.new({}, true, errors)
	return TacticalCoreFacingRuleSnapshotClass.new(table, false, [])

# ── Phase 27D: tactical_command_economy ──

static func create_tactical_command_economy_snapshot(report_errors: bool = true) -> RefCounted:
	ensure_loaded()
	var table: Dictionary = Registry.get_table("tactical_command_economy").duplicate(true)
	var errors: Array[String] = Registry.get_errors()
	errors.append_array(Validator.validate_tactical_command_economy(table))
	if not errors.is_empty():
		if report_errors:
			for error in errors:
				push_error("[CONFIG ERROR] %s" % error)
		return TacticalCommandEconomySnapshotClass.new({}, true, errors)
	return TacticalCommandEconomySnapshotClass.new(table, false, [])


## Phase 27E: 怪兽英雄技能快照
## Phase 27E: 怪兽英雄技能快照
static func create_monster_hero_skill_snapshot(report_errors: bool = true) -> RefCounted:
	ensure_loaded()
	var table: Dictionary = Registry.get_table("monster_hero_skills").duplicate(true)
	var errors: Array[String] = Registry.get_errors()
	errors.append_array(Validator.validate_monster_hero_skills_table(table))
	if not errors.is_empty():
		if report_errors:
			for error in errors:
				push_error("[CONFIG ERROR] %s" % error)
		return MonsterHeroSkillSnapshotClass.new({}, true, errors)
	return MonsterHeroSkillSnapshotClass.new(table, false, [])


# ── Phase 27F: Boss tactical AI ──

static func create_boss_tactical_ai_profile(report_errors: bool = true) -> RefCounted:
	ensure_loaded()
	var table: Dictionary = Registry.get_table("boss_tactical_ai").duplicate(true)
	var errors: Array[String] = Registry.get_errors()
	errors.append_array(Validator.validate_boss_tactical_ai_table(table))
	if not errors.is_empty():
		if report_errors:
			for error in errors:
				push_error("[CONFIG ERROR] %s" % error)
		return BossTacticalAIProfileClass.new({}, true, errors)
	return BossTacticalAIProfileClass.new(table, false, [])


# ── Phase 27I-R0: card_piece_traits ──

static func create_card_piece_trait_snapshot(report_errors: bool = true) -> RefCounted:
	ensure_loaded()
	var table: Dictionary = Registry.get_table("card_piece_traits").duplicate(true)
	var errors: Array[String] = Registry.get_errors()
	errors.append_array(Validator.validate_card_piece_traits_table(table, Registry.get_table("tactical_unit_patterns")))
	if not errors.is_empty():
		if report_errors:
			for error in errors:
				push_error("[CONFIG ERROR] %s" % error)
		return CardPieceTraitSnapshotClass.default_snapshot(errors)
	return CardPieceTraitSnapshotClass.new(table, false, [])


# ── Phase 27J: OD release rules ──

static func create_od_release_rule_snapshot(report_errors: bool = true) -> RefCounted:
	ensure_loaded()
	var table: Dictionary = Registry.get_table("od_release_rules").duplicate(true)
	var errors: Array[String] = Registry.get_errors()
	errors.append_array(Validator.validate_od_release_rules_table(table))
	if not errors.is_empty():
		if report_errors:
			for error in errors:
				push_error("[CONFIG ERROR] %s" % error)
		return ODReleaseRuleSnapshotClass.default_snapshot(errors)
	return ODReleaseRuleSnapshotClass.new(table, false, [])


# ── Phase 27K-R0: OD presentation rules（纯表现，非权威） ──

static func create_od_presentation_snapshot(report_errors: bool = true) -> RefCounted:
	ensure_loaded()
	var table: Dictionary = Registry.get_table("od_presentation_rules").duplicate(true)
	var errors: Array[String] = Registry.get_errors()
	errors.append_array(Validator.validate_od_presentation_rules_table(table))
	if not errors.is_empty():
		if report_errors:
			for error in errors:
				push_error("[CONFIG ERROR] %s" % error)
		return ODPresentationSnapshotClass.default_snapshot(errors)
	return ODPresentationSnapshotClass.new(table, false, [])


# Phase 27K-R1-A: read-only Heat source descriptors and event presentation metadata.
static func create_od_flow_feedback_snapshot(report_errors: bool = true) -> RefCounted:
	ensure_loaded()
	var table: Dictionary = Registry.get_table("od_flow_feedback_rules").duplicate(true)
	var errors: Array[String] = Registry.get_errors()
	errors.append_array(Validator.validate_od_flow_feedback_rules_table(table))
	if not errors.is_empty():
		if report_errors:
			for error in errors:
				push_error("[CONFIG ERROR] %s" % error)
		return ODFlowFeedbackSnapshotClass.default_snapshot(errors)
	return ODFlowFeedbackSnapshotClass.new(table, false, [])


# ── Phase C: tactical_structure_rules ──

static func create_tactical_structure_presentation_profile(report_errors: bool = true, table_override: Dictionary = {}) -> RefCounted:

	ensure_loaded()
	var table: Dictionary = table_override.duplicate(true) if not table_override.is_empty() else Registry.get_table("tactical_structure_presentation").duplicate(true)
	var errors: Array[String] = Validator.validate_tactical_structure_presentation_table(table)
	if report_errors:
		for error in errors:
			if _reported_tactical_structure_presentation_errors.has(error): continue
			_reported_tactical_structure_presentation_errors[error] = true
			push_error("[CONFIG ERROR] %s" % error)
	return TacticalStructurePresentationProfileClass.new(table, not errors.is_empty(), errors)

static func get_tactical_structure_presentation_reported_error_count() -> int:

	return _reported_tactical_structure_presentation_errors.size()

static func create_tactical_structure_rule_snapshot(report_errors: bool = true) -> RefCounted:
	ensure_loaded()
	var table: Dictionary = Registry.get_table("tactical_structure_rules").duplicate(true)
	# 只校验结构表本身；其他配置表的 Registry 加载错误不得污染结构 snapshot。
	# 坏 profile 由 RuleSnapshot 逐 profile 过滤，合法 profile 仍保留。
	var errors: Array[String] = Validator.validate_tactical_structure_rules_table(table)
	var reported: Array[String] = []
	for error in errors:
		reported.append("[CONFIG ERROR] %s" % error)
	# 表有内容时由 RuleSnapshot 自行收集 profile 级错误（已去重）；空表时才注入表级错误。
	var injected: Array[String] = []
	if table.is_empty():
		injected = reported
	var snapshot: RefCounted = TacticalStructureRuleSnapshotClass.new(table, not errors.is_empty(), injected)
	if report_errors and not reported.is_empty():
		for error in reported:
			push_error(error)
	return snapshot


# ── Phase D1: tactical_garrison_rules ──

static func create_tactical_garrison_rule_snapshot(report_errors: bool = true) -> RefCounted:
	ensure_loaded()
	var table: Dictionary = Registry.get_table("tactical_garrison_rules").duplicate(true)
	# Only this table participates. An unrelated Registry load error must not disable garrison rules.
	var errors: Array[String] = Validator.validate_tactical_garrison_rules_table(table)
	var snapshot: RefCounted = TacticalGarrisonRuleSnapshotClass.new(table, not errors.is_empty(), errors)
	if report_errors:
		for error in errors:
			push_error("[CONFIG ERROR] %s" % error)
	return snapshot
