extends RefCounted
class_name CombatPresentationProfile

## Phase 26B-T2: 每场战斗不可变的战斗表现配置快照
## 由 GameConfig.create_combat_presentation_profile() 构造，创建后只读。
##
## 一场战斗只创建一次，生产 Presenter 不直接读取 JSON。
## 所有 duration 字段范围: 0.05–3.0
## lunge_distance 范围: 0.05–1.0

# ── 怪兽攻击 ──
var monster_attack_target_lock: float:
	get: return _monster_attack_target_lock
var monster_attack_telegraph: float:
	get: return _monster_attack_telegraph
var monster_attack_lunge: float:
	get: return _monster_attack_lunge
var monster_attack_hit_pause: float:
	get: return _monster_attack_hit_pause
var monster_attack_reaction: float:
	get: return _monster_attack_reaction
var monster_attack_return: float:
	get: return _monster_attack_return
var monster_attack_destroy: float:
	get: return _monster_attack_destroy
var monster_attack_lunge_distance: float:
	get: return _monster_attack_lunge_distance

# ── 魔法发动 ──
var spell_hand_charge: float:
	get: return _spell_hand_charge
var spell_stage_travel: float:
	get: return _spell_stage_travel
var spell_stage_hold: float:
	get: return _spell_stage_hold
var spell_resolve_hold: float:
	get: return _spell_resolve_hold
var spell_graveyard_travel: float:
	get: return _spell_graveyard_travel
var spell_finisher_extra_hold: float:
	get: return _spell_finisher_extra_hold

# ── 升格 ──
var ascension_charge: float:
	get: return _ascension_charge
var ascension_swap_out: float:
	get: return _ascension_swap_out
var ascension_swap_in: float:
	get: return _ascension_swap_in
var ascension_settle: float:
	get: return _ascension_settle

var used_fallback: bool:
	get: return _used_fallback
var validation_errors: Array[String]:
	get: return _validation_errors.duplicate()

# ── 私有存储 ──
var _monster_attack_target_lock: float
var _monster_attack_telegraph: float
var _monster_attack_lunge: float
var _monster_attack_hit_pause: float
var _monster_attack_reaction: float
var _monster_attack_return: float
var _monster_attack_destroy: float
var _monster_attack_lunge_distance: float

var _spell_hand_charge: float
var _spell_stage_travel: float
var _spell_stage_hold: float
var _spell_resolve_hold: float
var _spell_graveyard_travel: float
var _spell_finisher_extra_hold: float

var _ascension_charge: float
var _ascension_swap_out: float
var _ascension_swap_in: float
var _ascension_settle: float

var _orchestration: Dictionary
var _od_release_choreography: Dictionary
var _monster_summon: Dictionary
var _result_feedback: Dictionary
var _piece_sigils: Dictionary
var _audio_cues: Dictionary
var _accessibility: Dictionary
var _world_visual_language: Dictionary
var _card_direction_profiles: Dictionary

var _used_fallback: bool
var _validation_errors: Array[String]


func _init(
	monster_attack: Dictionary,
	spell_activation: Dictionary,
	ascension: Dictionary,
	fallback_used: bool = false,
	errors: Array[String] = [],
	orchestration: Dictionary = {},
	od_release_choreography: Dictionary = {},
	monster_summon: Dictionary = {},
	result_feedback: Dictionary = {},
	piece_sigils: Dictionary = {},
	audio_cues: Dictionary = {},
	accessibility: Dictionary = {},
	world_visual_language: Dictionary = {},
	card_direction_profiles: Dictionary = {}
) -> void:
	# ── 怪兽攻击 ──
	_monster_attack_target_lock = _clamp_duration(float(monster_attack.get("target_lock", 0.12)))
	_monster_attack_telegraph = _clamp_duration(float(monster_attack.get("telegraph", 0.24)))
	_monster_attack_lunge = _clamp_duration(float(monster_attack.get("lunge", 0.22)))
	_monster_attack_hit_pause = _clamp_duration(float(monster_attack.get("hit_pause", 0.12)))
	_monster_attack_reaction = _clamp_duration(float(monster_attack.get("reaction", 0.18)))
	_monster_attack_return = _clamp_duration(float(monster_attack.get("return", 0.28)))
	_monster_attack_destroy = _clamp_duration(float(monster_attack.get("destroy", 0.34)))
	_monster_attack_lunge_distance = clampf(float(monster_attack.get("lunge_distance", 0.35)), 0.05, 1.0)

	# ── 魔法发动 ──
	_spell_hand_charge = _clamp_duration(float(spell_activation.get("hand_charge", 0.35)))
	_spell_stage_travel = _clamp_duration(float(spell_activation.get("stage_travel", 0.30)))
	_spell_stage_hold = _clamp_duration(float(spell_activation.get("stage_hold", 0.70)))
	_spell_resolve_hold = _clamp_duration(float(spell_activation.get("resolve_hold", 0.45)))
	_spell_graveyard_travel = _clamp_duration(float(spell_activation.get("graveyard_travel", 0.35)))
	_spell_finisher_extra_hold = _clamp_duration(float(spell_activation.get("finisher_extra_hold", 0.20)))

	# ── 升格 ──
	_ascension_charge = _clamp_duration(float(ascension.get("charge", 0.20)))
	_ascension_swap_out = _clamp_duration(float(ascension.get("swap_out", 0.18)))
	_ascension_swap_in = _clamp_duration(float(ascension.get("swap_in", 0.28)))
	_ascension_settle = _clamp_duration(float(ascension.get("settle", 0.18)))

	_orchestration = (orchestration if not orchestration.is_empty() else _default_orchestration()).duplicate(true)
	_od_release_choreography = (od_release_choreography if not od_release_choreography.is_empty() else _default_od_release_choreography()).duplicate(true)
	_monster_summon = (monster_summon if not monster_summon.is_empty() else _default_monster_summon()).duplicate(true)
	_result_feedback = (result_feedback if not result_feedback.is_empty() else _default_result_feedback()).duplicate(true)
	_piece_sigils = (piece_sigils if not piece_sigils.is_empty() else _default_piece_sigils()).duplicate(true)
	_audio_cues = (audio_cues if not audio_cues.is_empty() else _default_audio_cues()).duplicate(true)
	_accessibility = (accessibility if not accessibility.is_empty() else _default_accessibility()).duplicate(true)
	_world_visual_language = world_visual_language.duplicate(true)
	_card_direction_profiles = card_direction_profiles.duplicate(true)

	_used_fallback = fallback_used
	_validation_errors = errors.duplicate()


static func _clamp_duration(value: float) -> float:
	return clampf(value, 0.05, 3.0)


static func default_profile(errors: Array[String] = []):
	return new(
		{"target_lock": 0.12, "telegraph": 0.24, "lunge": 0.22, "hit_pause": 0.12, "reaction": 0.18, "return": 0.28, "destroy": 0.34, "lunge_distance": 0.35},
		{"hand_charge": 0.35, "stage_travel": 0.30, "stage_hold": 0.70, "resolve_hold": 0.45, "graveyard_travel": 0.35, "finisher_extra_hold": 0.20},
		{"charge": 0.20, "swap_out": 0.18, "swap_in": 0.28, "settle": 0.18},
		not errors.is_empty(),
		errors,
		_default_orchestration(),
		_default_od_release_choreography(),
		_default_monster_summon(),
		_default_result_feedback(),
		_default_piece_sigils(),
		_default_audio_cues(),
		_default_accessibility(),
	)


func get_phase_order() -> Array[StringName]:
	var result: Array[StringName] = []
	for phase in _orchestration.get("phase_order", []):
		result.append(StringName(phase))
	return result


func get_lane_names() -> Array[StringName]:
	var result: Array[StringName] = []
	for lane in _orchestration.get("lanes", []):
		result.append(StringName(lane))
	return result


func get_tier_duration(tier: StringName) -> float:
	match tier:
		&"micro": return float(_orchestration.get("micro_duration", 0.20))
		&"minor": return float(_orchestration.get("minor_duration", 0.55))
		&"major": return float(_orchestration.get("major_duration", 1.15))
		_: return 0.0


func get_major_hard_timeout() -> float:
	return float(_orchestration.get("major_hard_timeout", 1.40))


func get_coalescing_window() -> float:
	return float(_orchestration.get("coalescing_window", 0.04))


func get_fast_mode_multiplier() -> float:
	return float(_orchestration.get("fast_mode_multiplier", 0.65))


func get_auto_fast_queue_threshold() -> int:
	return int(_orchestration.get("auto_fast_queue_threshold", 4))


func get_auto_fast_multiplier() -> float:
	return float(_orchestration.get("auto_fast_multiplier", 0.55))


func get_reduced_motion_duration_multiplier() -> float:
	return float(_orchestration.get("reduced_motion_duration_multiplier", 0.50))


func get_od_release_timeline() -> Dictionary:
	return _od_release_choreography.duplicate(true)


func get_monster_summon_profile() -> Dictionary:
	return _monster_summon.duplicate(true)


func get_result_feedback_profile() -> Dictionary:
	return _result_feedback.duplicate(true)


func get_piece_sigil_style(piece_type: StringName) -> StringName:
	return StringName(_piece_sigils.get(String(piece_type), _piece_sigils.get(piece_type, "")))


func get_audio_cue(cue_key: StringName) -> StringName:
	return StringName(_audio_cues.get(String(cue_key), _audio_cues.get(cue_key, "")))


func is_reduced_motion_default() -> bool:
	return bool(_accessibility.get("reduced_motion_default", false))


func is_fast_mode_default() -> bool:
	return bool(_accessibility.get("fast_mode_default", false))


func get_reduced_motion_shake_scale() -> float:
	return float(_accessibility.get("reduced_motion_shake_scale", 0.0))


func get_world_visual_language() -> Dictionary:
	return _world_visual_language.duplicate(true)


func get_card_direction_profile(card_id: StringName) -> Dictionary:
	return Dictionary(_card_direction_profiles.get(str(card_id), {})).duplicate(true)


static func _default_orchestration() -> Dictionary:
	return {
		"phase_order": ["select", "commit", "convey", "resolve"],
		"lanes": ["engine_lane", "board_lane", "card_lane", "audio_lane"],
		"micro_duration": 0.20,
		"minor_duration": 0.55,
		"major_duration": 1.15,
		"major_hard_timeout": 1.40,
		"coalescing_window": 0.04,
		"fast_mode_multiplier": 0.65,
		"auto_fast_queue_threshold": 4,
		"auto_fast_multiplier": 0.55,
		"reduced_motion_duration_multiplier": 0.50,
	}


static func _default_od_release_choreography() -> Dictionary:
	return {
		"commit_end": 0.10,
		"extract_end": 0.38,
		"conduit_end": 0.62,
		"sigil_end": 0.85,
		"impact_end": 1.05,
		"settle_end": 1.20,
		"board_dim_alpha": 0.18,
	}


static func _default_monster_summon() -> Dictionary:
	return {
		"card_commit_end": 0.10,
		"travel_end": 0.30,
		"token_land_end": 0.46,
		"settle_end": 0.55,
		"spawn_ring_scale": 1.18,
	}


static func _default_result_feedback() -> Dictionary:
	return {
		"damage_badge_duration": 0.55,
		"blocked_badge_duration": 0.45,
		"status_badge_duration": 0.65,
		"float_distance": 36.0,
		"impact_scale": 1.12,
	}


static func _default_piece_sigils() -> Dictionary:
	return {
		"pawn": "forward_fan",
		"knight": "knight_l",
		"bishop": "diagonal_cross",
		"rook": "orthogonal_cross",
	}


static func _default_audio_cues() -> Dictionary:
	return {
		"od_release_commit": "od_release_commit",
		"od_release_extract": "od_release_extract",
		"od_release_impact": "od_release_impact",
		"spell_commit": "spell_commit",
		"spell_resolve": "spell_resolve",
		"monster_summon": "monster_summon",
		"monster_attack": "monster_attack",
		"monster_skill": "monster_skill",
		"building_commit": "building_commit",
		"counter_trigger": "counter_trigger",
	}


static func _default_accessibility() -> Dictionary:
	return {
		"reduced_motion_default": false,
		"fast_mode_default": false,
		"reduced_motion_shake_scale": 0.0,
	}


## 计算普通魔法的总演出时长
func total_spell_duration() -> float:
	return _spell_hand_charge + _spell_stage_travel + _spell_stage_hold + _spell_resolve_hold + _spell_graveyard_travel


## 计算 Finisher 的总演出时长
func total_finisher_duration() -> float:
	return total_spell_duration() + _spell_finisher_extra_hold


## 计算怪兽攻击总时长
func total_monster_attack_duration(destroy_included: bool = true) -> float:
	var base: float = _monster_attack_target_lock + _monster_attack_telegraph + _monster_attack_lunge + _monster_attack_hit_pause + _monster_attack_reaction + _monster_attack_return
	if destroy_included:
		base += _monster_attack_destroy
	return base


## 计算升格总时长
func total_ascension_duration() -> float:
	return _ascension_charge + _ascension_swap_out + _ascension_swap_in + _ascension_settle
