extends Node
class_name MonsterCombatPresenter

signal combat_phase_changed(phase: StringName, facts: Dictionary)

## Phase 24C-A: Monster Combat Presentation MVP
##
## 怪兽攻击演出层 —— 只负责表现，不修改任何战斗数据。
## 接收 result Dictionary → 播放 3D token 动画 + 2D VFX → 返回后由 battle_scene 刷新表格。
##
## 安全原则：
## - 所有节点引用必须 is_instance_valid 检查
## - 3D token 找不到则 fallback 到 2D VFX
## - 不调用 take_damage / field.erase / graveyard.push
## - 不 resolve_monster_attack()

var _scene: Node = null
var _battle_vfx: Node = null
var _card_vfx: Node = null

# Phase 26B-T5: Presentation profile and Tween lifecycle
var _profile: RefCounted = null
var _active_tweens: Array[Tween] = []
var _presentation_busy: bool = false
var _combat_phase_history: Array[Dictionary] = []


# ═══════════════════════════════════════════════════════════
# Setup
# ═══════════════════════════════════════════════════════════

func setup(scene_ref: Node, battle_vfx_ref: Node, card_vfx_ref: Node) -> void:
	_scene = scene_ref
	_battle_vfx = battle_vfx_ref
	_card_vfx = card_vfx_ref


## Phase 26B-T5: Lazy-load presentation profile from GameConfig.
func _get_profile() -> RefCounted:
	if _profile != null:
		return _profile
	var GameCfg: GDScript = load("res://core/config/game_config.gd")
	_profile = GameCfg.create_combat_presentation_profile(false)
	return _profile


## Phase 26B-T5: Cancel all running tweens and reset busy state.
func cancel_all() -> void:
	_presentation_busy = false
	for tw in _active_tweens:
		if tw != null and tw.is_valid():
			tw.kill()
	_active_tweens.clear()
	_combat_phase_history.clear()


func is_presentation_busy() -> bool:
	return _presentation_busy


func get_active_tween_count() -> int:
	var count := 0
	for tween in _active_tweens:
		if tween != null and tween.is_valid():
			count += 1
	return count


func get_combat_phase_history() -> Array[Dictionary]:
	return _combat_phase_history.duplicate(true)


func _emit_combat_phase(phase: StringName, facts: Dictionary) -> void:
	var snapshot := facts.duplicate(true)
	snapshot["phase"] = phase
	_combat_phase_history.append(snapshot)
	if _combat_phase_history.size() > 64:
		_combat_phase_history.pop_front()
	combat_phase_changed.emit(phase, snapshot.duplicate(true))


func play_summon_sequence(card, facts: Dictionary) -> void:
	var committed := facts.duplicate(true)
	committed["card"] = card
	_emit_combat_phase(&"select", committed)
	_emit_combat_phase(&"commit", committed)
	if not bool(committed.get("ok", true)) or StringName(committed.get("status", &"committed")) != &"committed":
		return
	_presentation_busy = true
	_emit_combat_phase(&"convey", committed)
	var token := _get_3d_token(card)
	if token != null and is_instance_valid(token):
		var visual: Node3D = token.get_node_or_null("CardCarrier") as Node3D
		if visual == null:
			visual = token
		var baseline_scale := visual.scale
		var baseline_position := visual.position
		visual.scale = baseline_scale * 0.82
		visual.position = baseline_position + Vector3(0.0, 0.08, 0.0)
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(visual, "scale", baseline_scale, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(visual, "position", baseline_position, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_active_tweens.append(tween)
		await tween.finished
		if is_instance_valid(visual):
			visual.scale = baseline_scale
			visual.position = baseline_position
	_play_committed_marker(committed, &"spawn")
	_emit_combat_phase(&"resolve", committed)
	_presentation_busy = false


func play_skill_sequence(card, skill_id: StringName, target, result: Dictionary) -> void:
	var committed := result.duplicate(true)
	committed["card"] = card
	committed["skill_id"] = skill_id
	committed["target"] = target
	_emit_combat_phase(&"select", committed)
	_emit_combat_phase(&"commit", committed)
	if not bool(committed.get("ok", false)):
		return
	_presentation_busy = true
	_emit_combat_phase(&"convey", committed)
	_play_committed_marker(committed, &"skill")
	await get_tree().create_timer(0.10).timeout
	_emit_combat_phase(&"resolve", committed)
	_presentation_busy = false


func _play_committed_marker(facts: Dictionary, marker_kind: StringName) -> void:
	var root := _get_combat_vfx_root()
	if root == null or _battle_vfx == null:
		return
	var target_position: Variant = facts.get("target_position", facts.get("screen_position", null))
	if not target_position is Vector2:
		return
	if marker_kind == &"spawn" and _battle_vfx.has_method("play_spawn_ring"):
		_battle_vfx.call("play_spawn_ring", root, target_position, Color(0.25, 0.90, 1.0, 0.95), 0.22, 0)
	elif _battle_vfx.has_method("play_piece_sigil"):
		_battle_vfx.call("play_piece_sigil", root, target_position, StringName(facts.get("piece_type", &"pawn")), Color(1.0, 0.68, 0.18, 0.95), 0.22, 0)
	if marker_kind == &"skill" and _battle_vfx.has_method("play_result_badge"):
		_battle_vfx.call("play_result_badge", root, target_position, facts.duplicate(true), 0.25, 0)


# ═══════════════════════════════════════════════════════════
# Public API — 主入口
# ═══════════════════════════════════════════════════════════

func play_attack_sequence(result: Dictionary) -> void:
	## Phase 26B-T5: Profile-driven attack sequence with busy guard.
	_emit_combat_phase(&"select", result)
	_emit_combat_phase(&"commit", result)
	if not result.get("ok", false):
		return
	_presentation_busy = true
	_emit_combat_phase(&"convey", result)
	var res_type: String = result.get("result", "")
	var attacker_card = result.get("attacker")
	var target_card = result.get("target")

	match res_type:
		"both_survive", "target_destroyed", "attacker_destroyed", "trade", "destroyed", "blocked":
			await play_monster_vs_monster_sequence(attacker_card, target_card, result)
		"hit_core":
			await play_direct_attack_sequence(attacker_card, result)
		_:
			await get_tree().create_timer(0.05).timeout
	_emit_combat_phase(&"resolve", result)
	_presentation_busy = false


# ═══════════════════════════════════════════════════════════
# 怪兽攻击怪兽
# ═══════════════════════════════════════════════════════════

func play_monster_vs_monster_sequence(attacker_card, target_card, result: Dictionary) -> void:
	## Phase 26B-T5: Full 6-phase profile-driven attack rhythm.
	## target_lock -> telegraph -> lunge -> hit_pause -> reaction -> return/destroy
	var prof: RefCounted = _get_profile()
	var attacker_token: Node3D = _get_3d_token(attacker_card)
	var target_token: Node3D = _get_3d_token(target_card)
	var res_type: String = result.get("result", "")
	var attacker_dies := res_type in ["attacker_destroyed", "trade"]
	var target_dies := res_type in ["target_destroyed", "trade", "destroyed"]

	var atk_valid: bool = attacker_token != null and is_instance_valid(attacker_token)
	var tgt_valid: bool = target_token != null and is_instance_valid(target_token)

	if not atk_valid or not tgt_valid:
		_play_monster_attack_2d_vfx(result, attacker_card, target_card)
		await get_tree().create_timer(0.15).timeout
		return

	# Get CardCarrier visual nodes
	var atk_visual: Node3D = attacker_token.get_node_or_null("CardCarrier") as Node3D
	var tgt_visual: Node3D = target_token.get_node_or_null("CardCarrier") as Node3D
	var atk_use_vis: bool = atk_visual != null and is_instance_valid(atk_visual)
	var tgt_use_vis: bool = tgt_visual != null and is_instance_valid(tgt_visual)
	if not atk_use_vis:
		atk_visual = attacker_token
	if not tgt_use_vis:
		tgt_visual = target_token

	var atk_carr_start: Vector3 = atk_visual.position
	var tgt_carr_start: Vector3 = tgt_visual.position

	# ── Phase 1: Target Lock (highlight target) ──
	var t_lock: float = prof.monster_attack_target_lock
	if tgt_use_vis:
		var lock_tw: Tween = create_tween()
		lock_tw.tween_property(tgt_visual, "scale", tgt_visual.scale * 1.05, t_lock * 0.6)
		lock_tw.tween_property(tgt_visual, "scale", tgt_visual.scale, t_lock * 0.4)
		_active_tweens.append(lock_tw)
	await get_tree().create_timer(t_lock).timeout
	if not is_instance_valid(attacker_token) or not is_instance_valid(target_token):
		_cleanup_visuals(atk_visual, atk_use_vis, atk_carr_start, tgt_visual, tgt_use_vis, tgt_carr_start)
		return

	# ── Phase 2: Telegraph (orange line preview + target pulse) ──
	var t_telegraph: float = prof.monster_attack_telegraph
	var telegraph_tw: Tween = create_tween()
	if tgt_use_vis:
		telegraph_tw.tween_property(tgt_visual, "scale", tgt_visual.scale * 1.08, t_telegraph * 0.5)
		telegraph_tw.tween_property(tgt_visual, "scale", tgt_visual.scale, t_telegraph * 0.5)
	_active_tweens.append(telegraph_tw)
	await get_tree().create_timer(t_telegraph).timeout
	if not is_instance_valid(attacker_token) or not is_instance_valid(target_token):
		_cleanup_visuals(atk_visual, atk_use_vis, atk_carr_start, tgt_visual, tgt_use_vis, tgt_carr_start)
		return

	# ── Phase 3: Lunge (attacker moves toward target) ──
	var t_lunge: float = prof.monster_attack_lunge
	var dir: Vector3 = target_token.global_position - attacker_token.global_position
	dir.y = 0
	if dir.length_squared() > 0.0001:
		var world_dir: Vector3 = dir.normalized()
		var local_dir: Vector3 = attacker_token.global_transform.basis.inverse() * world_dir
		var lunge_dist: float = prof.monster_attack_lunge_distance
		var lunge_offset: Vector3 = local_dir * lunge_dist + Vector3(0, 0.03, 0)
		var lunge_pos: Vector3 = atk_carr_start + lunge_offset
		var lunge_tw: Tween = create_tween()
		lunge_tw.tween_property(atk_visual, "position", lunge_pos, t_lunge).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_active_tweens.append(lunge_tw)
		await lunge_tw.finished
	else:
		await get_tree().create_timer(t_lunge).timeout

	if not is_instance_valid(attacker_token) or not is_instance_valid(target_token):
		_cleanup_visuals(atk_visual, atk_use_vis, atk_carr_start, tgt_visual, tgt_use_vis, tgt_carr_start)
		return

	# ── Phase 4: Hit Pause (brief freeze at impact) ──
	_play_monster_attack_2d_vfx(result, attacker_card, target_card)
	var t_pause: float = prof.monster_attack_hit_pause
	await get_tree().create_timer(t_pause).timeout
	if not is_instance_valid(attacker_token) or not is_instance_valid(target_token):
		_cleanup_visuals(atk_visual, atk_use_vis, atk_carr_start, tgt_visual, tgt_use_vis, tgt_carr_start)
		return

	# ── Phase 5: Reaction (target knockback) ──
	var t_reaction: float = prof.monster_attack_reaction
	if is_instance_valid(tgt_visual) and is_instance_valid(target_token):
		var hit_dir: Vector3 = target_token.global_position - attacker_token.global_position
		hit_dir.y = 0
		if hit_dir.length_squared() > 0.0001:
			var knock_local: Vector3 = target_token.global_transform.basis.inverse() * hit_dir.normalized()
			var knock_pos: Vector3 = tgt_carr_start + knock_local * 0.08
			var react_tw: Tween = create_tween()
			react_tw.tween_property(tgt_visual, "position", knock_pos, t_reaction * 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			react_tw.tween_property(tgt_visual, "position", tgt_carr_start, t_reaction * 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
			_active_tweens.append(react_tw)
			await react_tw.finished
		else:
			await get_tree().create_timer(t_reaction).timeout
	else:
		await get_tree().create_timer(t_reaction).timeout

	# ── Phase 6: Return (attacker) + Destroy (if applicable, parallel) ──
	var t_return: float = prof.monster_attack_return
	var t_destroy: float = prof.monster_attack_destroy

	# Start attacker return
	var return_done: bool = false
	if is_instance_valid(atk_visual) and is_instance_valid(attacker_token) and not attacker_dies:
		var ret_tw: Tween = create_tween()
		ret_tw.tween_property(atk_visual, "position", atk_carr_start, t_return).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		ret_tw.tween_callback(func():
			if is_instance_valid(atk_visual) and atk_use_vis:
				atk_visual.position = atk_carr_start
		)
		_active_tweens.append(ret_tw)
		await ret_tw.finished
	return_done = true

	# Destroy animations (parallel for trade)
	if target_dies and is_instance_valid(target_token):
		await play_token_destroyed(target_token)
	if attacker_dies and is_instance_valid(attacker_token):
		await play_token_destroyed(attacker_token)

	# If attacker survived and hasn"t returned yet, return now
	if not return_done and not attacker_dies:
		if is_instance_valid(atk_visual) and atk_use_vis:
			atk_visual.position = atk_carr_start

	# Restore baseline transforms
	_cleanup_visuals(atk_visual, atk_use_vis, atk_carr_start, tgt_visual, tgt_use_vis, tgt_carr_start)


## Phase 26B-T5: Restore visual baseline after sequence.
func _cleanup_visuals(atk_vis, atk_use, atk_start, tgt_vis, tgt_use, tgt_start) -> void:
	if is_instance_valid(atk_vis) and atk_use:
		atk_vis.position = atk_start
		atk_vis.scale = Vector3.ONE
	if is_instance_valid(tgt_vis) and tgt_use:
		tgt_vis.position = tgt_start
		tgt_vis.scale = Vector3.ONE


func play_direct_attack_sequence(attacker_card, result: Dictionary) -> void:
	## Phase 26B-T5: Profile-driven direct attack on Boss Core.
	var prof: RefCounted = _get_profile()
	var attacker_token: Node3D = _get_3d_token(attacker_card)
	var core_3d_pos: Vector3 = _get_boss_core_3d_position()
	var atk_valid: bool = attacker_token != null and is_instance_valid(attacker_token)

	if atk_valid and core_3d_pos != Vector3.ZERO:
		var atk_visual: Node3D = attacker_token.get_node_or_null("CardCarrier") as Node3D
		var use_vis: bool = atk_visual != null and is_instance_valid(atk_visual)
		if not use_vis:
			atk_visual = attacker_token
		var carr_start: Vector3 = atk_visual.position
		var token_world: Vector3 = attacker_token.global_position
		var dir: Vector3 = core_3d_pos - token_world
		dir.y = 0
		if dir.length_squared() > 0.0001:
			var local_dir: Vector3 = attacker_token.global_transform.basis.inverse() * dir.normalized()
			var lunge_dist: float = prof.monster_attack_lunge_distance
			var lunge_offset: Vector3 = local_dir * lunge_dist + Vector3(0, 0.03, 0)
			var lunge_pos: Vector3 = carr_start + lunge_offset
			var fwd_tw: Tween = create_tween()
			fwd_tw.tween_property(atk_visual, "position", lunge_pos, prof.monster_attack_lunge).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			_active_tweens.append(fwd_tw)
			await fwd_tw.finished
		else:
			await get_tree().create_timer(prof.monster_attack_lunge).timeout

		_play_boss_core_2d_vfx(result)
		await get_tree().create_timer(prof.monster_attack_hit_pause).timeout

		if is_instance_valid(atk_visual) and is_instance_valid(attacker_token):
			var ret_tw: Tween = create_tween()
			ret_tw.tween_property(atk_visual, "position", carr_start, prof.monster_attack_return).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
			_active_tweens.append(ret_tw)
			await ret_tw.finished
			if is_instance_valid(atk_visual) and use_vis:
				atk_visual.position = carr_start
	else:
		_play_boss_core_2d_vfx(result)
		await get_tree().create_timer(0.20).timeout


# ═══════════════════════════════════════════════════════════
# 3D Token 动画原语 (Phase 26B-T3: CardCarrier visual only)
# ═══════════════════════════════════════════════════════════

func play_token_lunge(token: Node3D, target_world_position: Vector3, strength: float = 0.35) -> void:
	## Phase 26B-T3: Animate CardCarrier visual only.
	if not is_instance_valid(token):
		return
	var visual: Node3D = token.get_node_or_null("CardCarrier") as Node3D
	var use_visual: bool = visual != null and is_instance_valid(visual)
	if not use_visual:
		visual = token
	var carr_start: Vector3 = visual.position
	var token_world: Vector3 = token.global_position
	var dir: Vector3 = target_world_position - token_world
	dir.y = 0
	if dir.length_squared() < 0.0001:
		return
	var local_dir: Vector3 = token.global_transform.basis.inverse() * dir.normalized()
	var lunge_offset: Vector3 = local_dir * strength + Vector3(0, 0.03, 0)
	var lunge_pos: Vector3 = carr_start + lunge_offset
	var tween: Tween = create_tween()
	tween.tween_property(visual, "position", lunge_pos, 0.10).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(visual, "position", carr_start, 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	await tween.finished
	if is_instance_valid(visual) and use_visual:
		visual.position = carr_start


func play_token_hit_reaction(token: Node3D, attacker_world_position: Vector3) -> void:
	## Phase 26B-T3: Animate CardCarrier visual only.
	if not is_instance_valid(token):
		return
	var visual: Node3D = token.get_node_or_null("CardCarrier") as Node3D
	var use_visual: bool = visual != null and is_instance_valid(visual)
	if not use_visual:
		visual = token
	var carr_start: Vector3 = visual.position
	var token_world: Vector3 = token.global_position
	var dir: Vector3 = token_world - attacker_world_position
	dir.y = 0
	if dir.length_squared() < 0.0001:
		return
	var local_dir: Vector3 = token.global_transform.basis.inverse() * dir.normalized()
	var knock_offset: Vector3 = local_dir * 0.08
	var knock_pos: Vector3 = carr_start + knock_offset
	var tween: Tween = create_tween()
	tween.tween_property(visual, "position", knock_pos, 0.06).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(visual, "position", carr_start, 0.10).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await tween.finished
	if is_instance_valid(visual) and use_visual:
		visual.position = carr_start


func play_token_destroyed(token: Node3D) -> void:
	## Phase 26B-T3: Animate CardCarrier visual only. TokenRoot scale stays standard.
	if not is_instance_valid(token):
		return
	var visual: Node3D = token.get_node_or_null("CardCarrier") as Node3D
	var use_visual: bool = visual != null and is_instance_valid(visual)
	if not use_visual:
		visual = token
	var start_scale: Vector3 = visual.scale
	var start_pos: Vector3 = visual.position
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(visual, "scale", start_scale * 0.72, 0.20)
	tween.tween_property(visual, "position:y", start_pos.y - 0.12, 0.22)
	tween.tween_property(visual, "rotation:y", 0.12, 0.18)
	await tween.finished
	# Restore visual transform so token can be reused cleanly
	if is_instance_valid(visual) and use_visual:
		visual.transform = Transform3D.IDENTITY
	# Note: do not queue_free token here; _refresh_tables() manages that


# ═══════════════════════════════════════════════════════════
# 2D VFX —— 直击 Boss Core
# ═══════════════════════════════════════════════════════════


# ═══════════════════════════════════════════════════════════
# 2D VFX —— 攻击怪兽 (Phase 26B-T4: CombatVFXRoot + 3D projection)
# ═══════════════════════════════════════════════════════════

func _play_monster_attack_2d_vfx(result: Dictionary, attacker_card, target_card) -> void:
	var _btab: Control = _get_battle_table()
	var res_type: String = result.get("result", "")
	var target_dies := res_type in ["target_destroyed", "trade", "destroyed"]
	var is_blocked: bool = (res_type == "blocked")

	# Phase 26B-T4: 3D token projection first for both endpoints
	var _from_pos: Vector2 = _get_attacker_screen_pos(attacker_card)
	var _to_pos: Vector2
	if target_card:
		_to_pos = _get_target_screen_pos(target_card)
	else:
		_to_pos = _from_pos + Vector2(0, -80)

	# Phase 26B-T4: Attack line on full-screen CombatVFXRoot
	var _vfx_root: Control = _get_combat_vfx_root()
	if _vfx_root and _battle_vfx and _battle_vfx.has_method("play_attack_line"):
		var _atk_col := Color(1, 0.55, 0.15, 1)
		if target_dies:
			_atk_col = Color(1, 0.45, 0.12, 1)
		_battle_vfx.play_attack_line(_vfx_root, _from_pos, _to_pos, _atk_col)

	if target_dies:
		if _btab and _battle_vfx and _battle_vfx.has_method("play_impact_burst"):
			_battle_vfx.play_impact_burst(_btab, _to_pos, Color(1, 0.35, 0.15, 1), 1.2)
		if target_card:
			var _tslot: Control = _find_boss_slot_for_card(target_card)
			if _tslot and is_instance_valid(_tslot):
				if _card_vfx and _card_vfx.has_method("play_card_destroy"):
					_card_vfx.play_card_destroy(_tslot)
				_call_enemy_table_method("play_destroyed_pulse", _tslot)
		_call_enemy_table("flash_hit")
		_call_fx_shake(4.0)

	elif is_blocked:
		if _btab and _battle_vfx and _battle_vfx.has_method("play_impact_burst"):
			_battle_vfx.play_impact_burst(_btab, _to_pos, Color(0.8, 0.4, 0.2, 1), 0.7)
		if target_card:
			var _tslot: Control = _find_boss_slot_for_card(target_card)
			if _tslot and is_instance_valid(_tslot):
				if _card_vfx and _card_vfx.has_method("play_card_hit"):
					_card_vfx.play_card_hit(_tslot)
				_call_enemy_table_method("play_blocked_flash", _tslot)


func _play_boss_core_2d_vfx(result: Dictionary) -> void:
	var _btab: Control = _get_battle_table()
	var dmg: int = result.get("damage", 0)
	var attacker_card = result.get("attacker")

	var _from_pos: Vector2 = _get_attacker_screen_pos(attacker_card)
	var _to_pos: Vector2 = _get_boss_core_screen_pos()

	# Phase 26B-T4: Attack line on full-screen CombatVFXRoot
	var _vfx_root2: Control = _get_combat_vfx_root()
	if _vfx_root2 and _battle_vfx and _battle_vfx.has_method("play_attack_line"):
		_battle_vfx.play_attack_line(_vfx_root2, _from_pos, _to_pos, Color(1, 0.7, 0.2, 1))

	# ── 伤害数字 ──
	if dmg > 0:
		_show_damage_number(dmg)

	# ── Boss 桌面闪红 ──
	_call_enemy_table("flash_hit")

	# ── Boss Core 3D 闪光 ──
	_call_flash_boss_core()

	# ── 屏幕震动（更强） ──
	_call_fx_shake(6.0)

	# ── 命中爆点（较大） ──
	if _btab and _battle_vfx and _battle_vfx.has_method("play_impact_burst"):
		_battle_vfx.play_impact_burst(_btab, _to_pos, Color(1, 0.7, 0.2, 1), 1.5)

	# ── Boss Core 受击闪光 ──
	if _btab and _battle_vfx and _battle_vfx.has_method("play_boss_core_hit"):
		_battle_vfx.play_boss_core_hit(_btab, _to_pos)

	# ── Boss Core 2D 缩放脉冲 ──
	_play_boss_core_scale_pulse()


# ═══════════════════════════════════════════════════════════
# 内部辅助
# ═══════════════════════════════════════════════════════════

func _get_3d_token(card) -> Node3D:
	if card == null or _scene == null:
		return null
	if _scene.has_method("_get_3d_token_for_card"):
		var raw = _scene.call("_get_3d_token_for_card", card)
		if raw != null and is_instance_valid(raw):
			return raw as Node3D
	return null


## Phase 26B-T4: Project 3D token to screen via Camera3D + SubViewportContainer offset.
func _project_3d_to_screen(token: Node3D) -> Vector2:
	if token == null or not is_instance_valid(token) or _scene == null:
		return Vector2.INF
	if not is_instance_valid(_scene):
		return Vector2.INF
	if _scene.has_method("_project_3d_token_to_screen"):
		var result = _scene.call("_project_3d_token_to_screen", token)
		if result != null:
			return result as Vector2
	return Vector2.INF


## Phase 26B-T4: Clamp a screen-space point to the viewport safe rect.
func _clamp_to_safe_rect(pos: Vector2) -> Vector2:
	var viewport_size: Vector2 = Vector2(1600, 900)  # fallback
	if _scene != null:
		var vp_rect: Rect2 = _scene.get_viewport_rect() if _scene.has_method("get_viewport_rect") else Rect2()
		if vp_rect.size.x > 1:
			viewport_size = vp_rect.size
	var margin: float = 8.0
	return Vector2(
		clampf(pos.x, margin, viewport_size.x - margin),
		clampf(pos.y, margin, viewport_size.y - margin)
	)


func _get_battle_table() -> Control:
	if _scene == null:
		return null
	return _scene.get_node_or_null(NodePath("BattleTable")) as Control


## Phase 26B-T4: Get or create full-screen CombatVFXRoot for attack lines.
func _get_combat_vfx_root() -> Control:
	if _scene == null:
		return null
	# Use battle_scene"s _ensure_combat_vfx_root if available
	if _scene.has_method("_ensure_combat_vfx_root"):
		var root: Control = _scene.call("_ensure_combat_vfx_root") as Control
		if root != null and is_instance_valid(root):
			return root
	# Fallback: find existing CombatVFXRoot
	var existing := _scene.get_node_or_null(NodePath("CombatVFXRoot")) as Control
	if existing != null and is_instance_valid(existing):
		return existing
	# Last fallback: use BattleTable
	return _get_battle_table()


func _get_attacker_screen_pos(attacker_card) -> Vector2:
	## Phase 26B-T4: 3D token projection first, 2D slot as fallback.
	# 1. Try 3D token projection
	var token: Node3D = _get_3d_token(attacker_card)
	if token != null and is_instance_valid(token) and token.is_inside_tree():
		var projected: Vector2 = _project_3d_to_screen(token)
		if projected != Vector2.INF and not is_nan(projected.x):
			return _clamp_to_safe_rect(projected)
	# 2. Fall back to 2D slot (explicitly convert to global screen coords)
	if _scene != null:
		var slot_val = _scene.get("_selected_attacker_slot")
		if slot_val != null:
			var slot := slot_val as Control
			if slot != null and is_instance_valid(slot):
				return _clamp_to_safe_rect(slot.global_position + slot.size * 0.5)
	# 3. Player table slot lookup
	if attacker_card != null and _scene != null:
		var pt = _scene.get("player_table")
		if pt != null and pt.has_method("find_front_slot_for_card"):
			var slot := pt.find_front_slot_for_card(attacker_card) as Control
			if slot != null and is_instance_valid(slot):
				return _clamp_to_safe_rect(slot.global_position + slot.size * 0.5)
	# 4. Last fallback
	if _scene != null and "card_board_position" in _scene:
		return _clamp_to_safe_rect(_scene.get("card_board_position"))
	return Vector2(400, 500)


func _get_target_screen_pos(target_card) -> Vector2:
	## Phase 26B-T4: 3D token projection first for target position.
	var token: Node3D = _get_3d_token(target_card)
	if token != null and is_instance_valid(token) and token.is_inside_tree():
		var projected: Vector2 = _project_3d_to_screen(token)
		if projected != Vector2.INF and not is_nan(projected.x):
			return _clamp_to_safe_rect(projected)
	# Fall back to 2D boss slot
	var slot: Control = _find_boss_slot_for_card(target_card)
	if slot != null and is_instance_valid(slot):
		return _clamp_to_safe_rect(slot.global_position + slot.size * 0.5)
	# Last fallback
	return _clamp_to_safe_rect(Vector2(800, 350))


func _find_boss_slot_for_card(card) -> Control:
	if _scene == null or card == null:
		return null
	if _scene.has_method("_find_boss_slot_for_card"):
		return _scene.call("_find_boss_slot_for_card", card) as Control
	return null


func _get_boss_core_screen_pos() -> Vector2:
	if _scene == null:
		return Vector2(800, 200)
	# 优先 _boss_core_visual
	var core_val = _scene.get("_boss_core_visual")
	if core_val != null:
		var core := core_val as Control
		if core != null and is_instance_valid(core):
			return core.global_position + core.size * 0.5
	# fallback: _get_boss_screen_pos()
	if _scene.has_method("_get_boss_screen_pos"):
		return _scene.call("_get_boss_screen_pos")
	return Vector2(800, 200)


func _get_boss_core_3d_position() -> Vector3:
	if _scene and _scene.has_method("_get_boss_core"):
		var core_node = _scene.call("_get_boss_core")
		if core_node != null and is_instance_valid(core_node):
			return core_node.global_position
	return Vector3.ZERO


func _call_enemy_table(method_name: String) -> void:
	## 调用 enemy_table 的无参数方法
	if _scene == null:
		return
	var et = _scene.get("enemy_table")
	if et != null and et.has_method(method_name):
		et.call(method_name)


func _call_enemy_table_method(method_name: String, arg = null) -> void:
	## 调用 enemy_table 的带参数方法（如 play_destroyed_pulse(slot)）
	if _scene == null:
		return
	var et = _scene.get("enemy_table")
	if et != null and et.has_method(method_name):
		et.call(method_name, arg)


func _call_fx_shake(strength: float) -> void:
	if _scene == null:
		return
	var fx_node = _scene.get("fx")
	if fx_node != null and fx_node.has_method("shake"):
		fx_node.shake(strength)


func _call_flash_boss_core() -> void:
	if _scene and _scene.has_method("_flash_boss_core"):
		_scene.call("_flash_boss_core")


func _show_damage_number(value: int) -> void:
	if value <= 0 or _scene == null:
		return
	var et = _scene.get("enemy_table")
	if et != null and is_instance_valid(et) and _scene.has_method("_show_damage_number"):
		_scene.call("_show_damage_number", value, et, false)


func _play_boss_core_scale_pulse() -> void:
	if _scene == null:
		return
	var core_val = _scene.get("_boss_core_visual")
	if core_val != null:
		var core := core_val as Control
		if core != null and is_instance_valid(core):
			var orig_scale: Vector2 = core.scale
			var tween: Tween = create_tween()
			tween.tween_property(core, "scale", Vector2(0.94, 0.94), 0.06)
			tween.tween_property(core, "scale", orig_scale, 0.15)


func _safe_global_pos(node: Node3D) -> Vector3:
	if node != null and is_instance_valid(node):
		return node.global_position
	return Vector3.ZERO
