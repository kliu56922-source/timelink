extends Node
class_name SpellActivationPresenter

## Phase 27C Task 3-R: Spell activation state machine.
##
## IDLE -> RESERVED -> HAND_CHARGE -> STAGE_ENTER -> STAGE_HOLD -> COMMIT_RESOLVE -> GY_TRAVEL -> CLEANUP
##
## Rules:
## - battle.play_card() is called exactly once at COMMIT_RESOLVE.
## - Original hand CardUI is hidden during activation.
## - End Turn is blocked while active.
## - Proxy is always cleaned up, even on cancel/exit.

enum State { IDLE, RESERVED, HAND_CHARGE, STAGE_ENTER, STAGE_HOLD, COMMIT_RESOLVE, GY_TRAVEL, CLEANUP }

signal spell_phase_changed(phase: StringName, facts: Dictionary)

var _scene: Node = null
var _profile: RefCounted = null
var _direction_presenter: Node = null
var _active_tweens: Array[Tween] = []
var _spell_stage: Control = null
var _active_proxy: Control = null
var _original_card_ui: Control = null
var _state: int = State.IDLE
var _generation: int = 0
var _end_turn_blocked: bool = false
var _active_presentation_facts: Dictionary = {}
var _active_direction_trace: Array[Dictionary] = []
var _kingfire_stage_handled := false

## Externally settable: function to call when End Turn should be blocked/unblocked.
var end_turn_block_callback: Callable

const STAGE_Z_INDEX := 80
const LOCKED_PRESENTATION_FACT_KEYS: Array[StringName] = [
	&"transaction_id", &"card_id", &"card_name", &"source_position",
	&"target_position", &"player_position", &"target_kind", &"is_finisher",
]
const KINGFIRE_BOSS_MOTIF := &"kingfire_boss_impact"
const KINGFIRE_BACKLASH_MOTIF := &"kingfire_backlash"


func setup(scene_ref: Node) -> void:
	_scene = scene_ref


func configure_profile(profile: RefCounted) -> void:
	_profile = profile


func configure_direction_presenter(presenter: Node) -> void:
	_direction_presenter = presenter


func is_active() -> bool:
	return _state != State.IDLE and _state != State.CLEANUP


func get_active_tween_count() -> int:
	var count := 0
	for tween in _active_tweens:
		if tween != null and tween.is_valid():
			count += 1
	return count


func cancel_all() -> void:
	var old_gen := _generation
	_generation += 1
	for tw in _active_tweens:
		if tw != null and tw.is_valid():
			tw.kill()
	_active_tweens.clear()
	if _active_proxy != null and is_instance_valid(_active_proxy):
		_active_proxy.queue_free()
	_active_proxy = null
	# Restore original card UI if hidden
	if _original_card_ui != null and is_instance_valid(_original_card_ui):
		_original_card_ui.visible = true
		_original_card_ui = null
	_state = State.IDLE
	_active_presentation_facts.clear()
	_active_direction_trace.clear()
	_kingfire_stage_handled = false
	_set_end_turn_blocked(false)


func _get_profile() -> RefCounted:
	if _profile != null:
		return _profile
	var GameCfg: GDScript = load("res://core/config/game_config.gd")
	_profile = GameCfg.create_combat_presentation_profile(false)
	return _profile


func _ensure_spell_stage() -> Control:
	if _spell_stage != null and is_instance_valid(_spell_stage):
		return _spell_stage
	if _scene == null or not is_instance_valid(_scene):
		return null
	_spell_stage = Control.new()
	_spell_stage.name = "SpellStage"
	_spell_stage.set_anchors_preset(Control.PRESET_FULL_RECT)
	_spell_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_spell_stage.z_index = STAGE_Z_INDEX
	_scene.add_child(_spell_stage)
	return _spell_stage


func _set_end_turn_blocked(blocked: bool) -> void:
	if _end_turn_blocked == blocked:
		return
	_end_turn_blocked = blocked
	if end_turn_block_callback.is_valid():
		end_turn_block_callback.call(blocked)


# ══════════════════════════════════════════════════
# Phase 1: Begin spell activation (RESERVED → STAGE_HOLD)
# Returns a handle; caller must call finish_spell_activation when ready.
# ══════════════════════════════════════════════════

func begin_spell_activation(card_ui: Control, card, is_finisher: bool = false, presentation_facts: Dictionary = {}) -> Dictionary:
	if _state != State.IDLE:
		return {"ok": false, "reason": "spell_already_active"}

	_state = State.RESERVED
	_active_presentation_facts = presentation_facts.duplicate(true)
	_active_direction_trace.clear()
	_kingfire_stage_handled = false
	_active_presentation_facts["is_finisher"] = is_finisher
	if card != null:
		_active_presentation_facts["card_id"] = StringName(str(card.card_id)) if "card_id" in card else &""
		_active_presentation_facts["card_name"] = str(card.card_name) if "card_name" in card else ""
	_emit_phase(&"reserved")
	_generation += 1
	var gen := _generation
	_set_end_turn_blocked(true)

	# Hide original hand card
	_original_card_ui = card_ui
	if is_instance_valid(card_ui):
		card_ui.visible = false

	var prof: RefCounted = _get_profile()

	# ── Create presentation proxy ──
	var proxy: Control = _create_proxy(card_ui, card, is_finisher)
	if proxy == null:
		cancel_all()
		return {"ok": false, "reason": "proxy_creation_failed"}
	_active_proxy = proxy

	var stage: Control = _ensure_spell_stage()
	if stage == null:
		cancel_all()
		return {"ok": false, "reason": "stage_creation_failed"}

	var orig_global: Vector2 = card_ui.global_position if is_instance_valid(card_ui) else Vector2(300, 500)
	var orig_size: Vector2 = card_ui.size if is_instance_valid(card_ui) else Vector2(100, 140)
	proxy.global_position = orig_global
	proxy.size = orig_size
	stage.add_child(proxy)

	# ── HAND_CHARGE ──
	_state = State.HAND_CHARGE
	_emit_phase(&"hand_charge")
	var t_charge: float = prof.spell_hand_charge
	var charge_tw: Tween = create_tween()
	charge_tw.set_parallel(true)
	charge_tw.tween_property(proxy, "modulate", Color(1.0, 0.9, 0.6, 1.0), t_charge * 0.5)
	charge_tw.tween_property(proxy, "modulate", Color(1.5, 1.5, 1.0, 1.0), t_charge * 0.5).set_delay(t_charge * 0.5)
	_active_tweens.append(charge_tw)
	print("[SPELL] hand_charge card=%s gen=%d" % [card.card_name if "card_name" in card else "?", gen])
	await get_tree().create_timer(t_charge).timeout
	if _generation != gen or not is_instance_valid(proxy): return {"ok": false, "reason": "cancelled"}

	# ── STAGE_ENTER ──
	_state = State.STAGE_ENTER
	_emit_phase(&"stage_enter")
	var t_travel: float = prof.spell_stage_travel
	var vp_size: Vector2 = _scene.get_viewport_rect().size if _scene != null and is_instance_valid(_scene) else Vector2(1600, 900)
	var stage_center: Vector2 = Vector2(vp_size.x * 0.5, vp_size.y * 0.38)
	var travel_tw: Tween = create_tween()
	travel_tw.set_parallel(true)
	travel_tw.tween_property(proxy, "global_position", stage_center, t_travel).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	travel_tw.tween_property(proxy, "scale", Vector2(1.0, 1.0), t_travel).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_active_tweens.append(travel_tw)
	print("[SPELL] stage_enter gen=%d" % gen)
	await travel_tw.finished
	if _generation != gen or not is_instance_valid(proxy): return {"ok": false, "reason": "cancelled"}

	# ── STAGE_HOLD ──
	_state = State.STAGE_HOLD
	_emit_phase(&"stage_hold")
	var t_hold: float = prof.spell_stage_hold
	if is_finisher: t_hold += prof.spell_finisher_extra_hold
	_play_kingfire_stage_phases(t_hold)
	var hold_tw: Tween = create_tween()
	hold_tw.tween_property(proxy, "scale", Vector2(1.15, 1.15), t_hold * 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	hold_tw.tween_property(proxy, "scale", Vector2(1.0, 1.0), t_hold * 0.8).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_active_tweens.append(hold_tw)
	_show_card_detail(proxy, card, is_finisher)
	_play_spell_target_relation(proxy)
	print("[SPELL] stage_hold duration=%.2f gen=%d" % [t_hold, gen])
	await get_tree().create_timer(t_hold).timeout
	if _generation != gen or not is_instance_valid(proxy): return {"ok": false, "reason": "cancelled"}

	return {"ok": true, "handle": gen, "proxy": proxy, "card": card, "is_finisher": is_finisher, "stage": stage, "presentation_facts": presentation_facts.duplicate(true)}


# ══════════════════════════════════════════════════
# Phase 2: Finish spell activation (COMMIT_RESOLVE → GY_TRAVEL → CLEANUP)
# Caller must pass the handle from begin_spell_activation.
# battle.play_card() must have been called BEFORE this.
# ══════════════════════════════════════════════════

func finish_spell_activation(handle: Dictionary, play_result: Dictionary) -> void:
	if handle == null or not handle.get("ok", false):
		_set_end_turn_blocked(false)
		_state = State.IDLE
		return
	var gen: int = handle.get("handle", -1)
	if _generation != gen:
		return
	var proxy: Control = handle.get("proxy")
	var is_finisher: bool = handle.get("is_finisher", false)
	var prof: RefCounted = _get_profile()

	if not is_instance_valid(proxy):
		cancel_all()
		return

	# ── COMMIT_RESOLVE ──
	_state = State.COMMIT_RESOLVE
	var committed_facts := _committed_result_facts(play_result)
	var kingfire_resolved := _play_kingfire_resolve(committed_facts)
	_emit_phase(&"commit_resolve", committed_facts)
	var t_resolve: float = prof.spell_resolve_hold
	if is_finisher: t_resolve += prof.spell_finisher_extra_hold * 0.5
	print("[SPELL] commit_resolve ok=%s duration=%.2f gen=%d" % [str(play_result.get("ok", false)), t_resolve, gen])

	_play_spell_wave(proxy.global_position + proxy.size * 0.5, is_finisher)
	_play_spell_result(committed_facts, proxy, kingfire_resolved)
	_emit_phase(&"result", committed_facts)

	var resolve_tw: Tween = create_tween()
	resolve_tw.tween_property(proxy, "modulate", Color(2.0, 2.0, 2.0, 1.0), t_resolve * 0.3)
	resolve_tw.tween_property(proxy, "modulate", Color(1.0, 1.0, 1.0, 1.0), t_resolve * 0.7)
	_active_tweens.append(resolve_tw)
	await get_tree().create_timer(t_resolve).timeout
	if _generation != gen or not is_instance_valid(proxy):
		cancel_all(); return

	# ── GY_TRAVEL ──
	_state = State.GY_TRAVEL
	_emit_phase(&"graveyard_travel", committed_facts)
	var t_gy: float = prof.spell_graveyard_travel
	var gy_pos: Vector2 = _get_graveyard_screen_pos()
	var gy_tw: Tween = create_tween()
	gy_tw.set_parallel(true)
	gy_tw.tween_property(proxy, "global_position", gy_pos, t_gy).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	gy_tw.tween_property(proxy, "modulate:a", 0.0, t_gy)
	gy_tw.tween_property(proxy, "scale", Vector2(0.5, 0.5), t_gy)
	_active_tweens.append(gy_tw)
	print("[SPELL] graveyard_travel gen=%d" % gen)
	await gy_tw.finished

	_cleanup()


func _cleanup() -> void:
	_state = State.CLEANUP
	_emit_phase(&"cleanup")
	for tw in _active_tweens:
		if tw != null and tw.is_valid(): tw.kill()
	_active_tweens.clear()
	if _active_proxy != null and is_instance_valid(_active_proxy):
		_active_proxy.queue_free()
	_active_proxy = null
	_original_card_ui = null
	_active_presentation_facts.clear()
	_active_direction_trace.clear()
	_kingfire_stage_handled = false
	_set_end_turn_blocked(false)
	_state = State.IDLE


func _emit_phase(phase: StringName, extra: Dictionary = {}) -> void:
	var facts := _active_presentation_facts.duplicate(true)
	for key in extra:
		var stable_key := StringName(str(key))
		if stable_key in LOCKED_PRESENTATION_FACT_KEYS and facts.has(stable_key):
			continue
		facts[key] = extra[key]
	facts["direction_trace"] = _active_direction_trace.duplicate(true)
	facts["phase"] = phase
	spell_phase_changed.emit(phase, facts)


func _play_kingfire_stage_phases(duration: float) -> void:
	if not _is_kingfire_finisher() or not _direction_available():
		return
	if not _kingfire_direction_profile_complete():
		return
	var facts := _staged_direction_facts()
	var options := _direction_options(duration)
	var commit: Dictionary = _direction_presenter.call(
		"play_phase", &"P20", &"spell", &"commit", facts,
		_direction_root(), _generation, options
	)
	var convey: Dictionary = _direction_presenter.call(
		"play_phase", &"P20", &"spell", &"convey", facts,
		_direction_root(), _generation, options
	)
	_kingfire_stage_handled = bool(commit.get("handled", false)) and bool(convey.get("handled", false))
	if not _kingfire_stage_handled:
		return
	_append_direction_trace(commit, options)
	_append_direction_trace(convey, options)


func _play_kingfire_resolve(committed_facts: Dictionary) -> bool:
	if not _kingfire_stage_handled or not _direction_available():
		return false
	if not bool(committed_facts.get("ok", false)) or StringName(committed_facts.get("status", &"")) != &"committed":
		return false
	if bool(committed_facts.get("cancelled", false)) or bool(committed_facts.get("expired", false)) or _battle_ended():
		return false
	var options := _direction_options(float(_get_profile().spell_resolve_hold))
	var resolved: Dictionary = _direction_presenter.call(
		"play_phase", &"P20", &"spell", &"resolve", committed_facts,
		_direction_root(), _generation, options
	)
	if not bool(resolved.get("handled", false)):
		return false
	_append_direction_trace(resolved, options)
	return true


func _committed_result_facts(play_result: Dictionary) -> Dictionary:
	var facts := _active_presentation_facts.duplicate(true)
	for key in play_result:
		var stable_key := StringName(str(key))
		if stable_key in LOCKED_PRESENTATION_FACT_KEYS and facts.has(stable_key):
			continue
		facts[key] = play_result[key]
	if bool(facts.get("ok", false)):
		facts["status"] = &"committed"
	elif StringName(facts.get("status", &"")) == &"":
		facts["status"] = &"failed"
	return facts


func _staged_direction_facts() -> Dictionary:
	var facts := _active_presentation_facts.duplicate(true)
	facts["ok"] = true
	facts["status"] = &"committed"
	facts["presentation_stage_only"] = true
	facts["anchor_position"] = facts.get("source_position", Vector2.ZERO)
	return facts


func _direction_options(duration: float) -> Dictionary:
	var prof := _get_profile()
	var scale := 1.0
	var reduced_motion := prof.has_method("is_reduced_motion_default") and bool(prof.call("is_reduced_motion_default"))
	var fast_mode := prof.has_method("is_fast_mode_default") and bool(prof.call("is_fast_mode_default"))
	if fast_mode and prof.has_method("get_fast_mode_multiplier"):
		scale *= float(prof.call("get_fast_mode_multiplier"))
	if reduced_motion and prof.has_method("get_reduced_motion_duration_multiplier"):
		scale *= float(prof.call("get_reduced_motion_duration_multiplier"))
	var capped_duration := maxf(0.04, duration * scale)
	if prof.has_method("get_major_hard_timeout"):
		capped_duration = minf(capped_duration, float(prof.call("get_major_hard_timeout")))
	return {
		"duration": capped_duration,
		"reduced_motion": reduced_motion,
		"fast_mode": fast_mode,
		"tier": &"major",
	}


func _append_direction_trace(result: Dictionary, options: Dictionary) -> void:
	_active_direction_trace.append({
		"template": StringName(result.get("template", &"")),
		"motif": StringName(result.get("motif", &"")),
		"phase": StringName(result.get("phase", &"")),
		"generation": _generation,
		"duration": float(options.get("duration", 0.0)),
		"reduced_motion": bool(options.get("reduced_motion", false)),
		"fast_mode": bool(options.get("fast_mode", false)),
		"tier": &"major",
	})


func _append_settle_trace(motif: StringName, position: Vector2, value_key: StringName, value: int) -> void:
	_active_direction_trace.append({
		"template": &"kingfire_finisher",
		"motif": motif,
		"phase": &"settle",
		"generation": _generation,
		"position": position,
		"value_key": value_key,
		"value": value,
		"reduced_motion": _is_reduced_motion(),
		"fast_mode": _is_fast_mode(),
		"tier": &"major",
	})


func _is_kingfire_finisher() -> bool:
	return StringName(_active_presentation_facts.get("card_id", &"")) == &"P20" \
		and bool(_active_presentation_facts.get("is_finisher", false))


func _direction_available() -> bool:
	return _direction_presenter != null and is_instance_valid(_direction_presenter) \
		and _direction_presenter.has_method("play_phase") and _direction_root() != null


## Phase 27K-R1-D Task 8/9: kingfire direction playback requires a complete
## P20 direction profile. Any missing template/motif/accent/reveal key falls the
## whole kingfire layer back to the locked R1-C generic two-stage spell, so a
## partial profile can never emit a partially specialized kingfire presentation.
func _kingfire_direction_profile_complete() -> bool:
	var profile_value: Variant = _get_profile().call("get_card_direction_profile", &"P20")
	if not profile_value is Dictionary:
		return false
	var direction := profile_value as Dictionary
	for key in ["template", "commit_motif", "convey_motif", "resolve_motif", "accent", "reveal_level"]:
		if str(direction.get(key, "")).is_empty():
			return false
	return true


func _direction_root() -> Control:
	if _scene == null or not is_instance_valid(_scene):
		return null
	var battle_table := _scene.get_node_or_null(NodePath("BattleTable")) as Control
	return battle_table if battle_table != null else _scene as Control


func _is_reduced_motion() -> bool:
	var prof := _get_profile()
	return prof.has_method("is_reduced_motion_default") and bool(prof.call("is_reduced_motion_default"))


func _is_fast_mode() -> bool:
	var prof := _get_profile()
	return prof.has_method("is_fast_mode_default") and bool(prof.call("is_fast_mode_default"))


func _battle_ended() -> bool:
	var ended: Variant = _get_scene_property(&"battle_ended")
	return bool(ended) if ended != null else false


func _play_spell_target_relation(proxy: Control) -> void:
	if not is_instance_valid(proxy):
		return
	var target_position: Vector2 = _active_presentation_facts.get("target_position", Vector2.ZERO)
	if target_position == Vector2.ZERO:
		return
	var battle_vfx = _get_scene_property(&"battle_vfx")
	if battle_vfx == null:
		return
	var parent: Node = _scene.get_node_or_null(NodePath("BattleTable")) if _scene.has_method("get_node_or_null") else _scene
	if parent == null:
		parent = _scene
	var source_position := proxy.global_position + proxy.size * 0.5
	if battle_vfx.has_method("play_conduit_path"):
		var conduit_points: Array[Vector2] = [source_position, target_position]
		battle_vfx.play_conduit_path(parent, conduit_points, Color(0.45, 0.78, 1.0, 0.9), 0.48, _generation)
	if battle_vfx.has_method("play_piece_sigil"):
		var piece_type := StringName(_active_presentation_facts.get("piece_type", &"pawn"))
		battle_vfx.play_piece_sigil(parent, target_position, piece_type, Color(0.85, 0.72, 0.32, 0.95), 0.48, _generation)


func _play_spell_result(play_result: Dictionary, proxy: Control, kingfire_resolved: bool = false) -> void:
	var battle_vfx = _get_scene_property(&"battle_vfx")
	if battle_vfx == null or not battle_vfx.has_method("play_result_badge"):
		return
	var parent: Node = _scene.get_node_or_null(NodePath("BattleTable")) if _scene.has_method("get_node_or_null") else _scene
	if parent == null:
		parent = _scene
	var result_position: Vector2 = play_result.get("target_position", _active_presentation_facts.get("target_position", proxy.global_position + proxy.size * 0.5))
	if not kingfire_resolved:
		battle_vfx.play_result_badge(parent, result_position, play_result, 0.62, _generation)
		return
	var boss_facts := play_result.duplicate(true)
	boss_facts["template"] = &"kingfire_finisher"
	boss_facts["motif"] = KINGFIRE_BOSS_MOTIF
	boss_facts["phase"] = &"settle"
	boss_facts["result_kind"] = &"boss_damage"
	battle_vfx.play_result_badge(parent, result_position, boss_facts, 0.62, _generation, _is_reduced_motion())
	_append_settle_trace(KINGFIRE_BOSS_MOTIF, result_position, &"damage", int(play_result.get("damage", 0)))
	var self_damage := maxi(0, int(play_result.get("self_damage", 0)))
	var player_position: Vector2 = play_result.get("player_position", Vector2.ZERO)
	if self_damage <= 0 or player_position == Vector2.ZERO:
		return
	var backlash_facts := {
		"ok": true,
		"status": &"committed",
		"card_id": &"P20",
		"template": &"kingfire_finisher",
		"motif": KINGFIRE_BACKLASH_MOTIF,
		"phase": &"settle",
		"result_kind": &"player_backlash",
		"self_damage": self_damage,
		"label": "反噬 %d" % self_damage,
	}
	battle_vfx.play_result_badge(parent, player_position, backlash_facts, 0.62, _generation, _is_reduced_motion())
	_append_settle_trace(KINGFIRE_BACKLASH_MOTIF, player_position, &"self_damage", self_damage)


func _get_scene_property(property_name: StringName):
	if _scene == null or not is_instance_valid(_scene):
		return null
	for property_info in _scene.get_property_list():
		if StringName(property_info.get("name", &"")) == property_name:
			return _scene.get(property_name)
	return null


# ══════════════════════════════════════════════════
# Proxy / VFX helpers (unchanged from original)
# ══════════════════════════════════════════════════

func _create_proxy(card_ui: Control, card, is_finisher: bool) -> Control:
	var proxy: Control = Control.new()
	proxy.name = "SpellPresentationProxy"
	proxy.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var art_tex: Texture2D = null
	if card != null:
		if card.has_method("get_art_texture_for_mode"):
			art_tex = card.get_art_texture_for_mode(1)
		if not art_tex and card.has_method("get_art_texture"):
			art_tex = card.get_art_texture()
		if not art_tex and "art" in card:
			art_tex = card.art

	var art_rect := TextureRect.new()
	art_rect.name = "Art"
	art_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	art_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	if art_tex: art_rect.texture = art_tex
	else:
		var fallback := GradientTexture2D.new()
		fallback.gradient = Gradient.new()
		fallback.gradient.colors = PackedColorArray([Color(0.2, 0.3, 0.5, 0.9), Color(0.06, 0.1, 0.2, 0.9)])
		art_rect.texture = fallback
	proxy.add_child(art_rect)

	var name_label := Label.new()
	name_label.name = "CardName"
	name_label.text = card.card_name if "card_name" in card else "???"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	name_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.add_theme_color_override("font_color", Color(1, 1, 0.85, 1))
	proxy.add_child(name_label)

	if is_finisher:
		var border := ColorRect.new()
		border.name = "FinisherBorder"
		border.color = Color(1, 0.75, 0.2, 0.3)
		border.set_anchors_preset(Control.PRESET_FULL_RECT)
		proxy.add_child(border)

	proxy.size = card_ui.size if is_instance_valid(card_ui) else Vector2(120, 168)
	return proxy


func _show_card_detail(proxy: Control, card, is_finisher: bool) -> void:
	if not is_instance_valid(proxy): return
	var art_rect: TextureRect = proxy.get_node_or_null("Art") as TextureRect
	if art_rect and is_instance_valid(art_rect):
		var detail_tex: Texture2D = null
		if card != null and card.has_method("get_art_texture_for_mode"):
			detail_tex = card.get_art_texture_for_mode(3)
		if detail_tex: art_rect.texture = detail_tex


func _play_spell_wave(at_global: Vector2, is_finisher: bool) -> void:
	if _scene == null or not is_instance_valid(_scene): return
	var btab: Control = _scene.get_node_or_null(NodePath("BattleTable")) as Control
	if btab == null: return
	var battle_vfx = _scene.get("battle_vfx")
	if battle_vfx != null and battle_vfx.has_method("play_spell_wave"):
		var color := Color(0.35, 0.65, 1.0, 1)
		if is_finisher: color = Color(1.0, 0.75, 0.2, 1)
		battle_vfx.play_spell_wave(btab, at_global, color)


func _get_graveyard_screen_pos() -> Vector2:
	if _scene != null and is_instance_valid(_scene):
		var pt = _scene.get("player_table")
		if pt != null and is_instance_valid(pt) and pt.has_method("get_zone_global_center"):
			return pt.get_zone_global_center("graveyard")
	if _scene != null and is_instance_valid(_scene):
		var vp_size: Vector2 = _scene.get_viewport_rect().size
		return Vector2(vp_size.x * 0.85, vp_size.y * 0.9)
	return Vector2(1360, 810)


func _exit_tree() -> void:
	cancel_all()
