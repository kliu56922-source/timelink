extends Node
class_name BattleVFXController
## BattleVFXController — 战斗全局动效统一入口
## Phase 10F: 增强 Engine Gauge 动画（charge tick / current pulse / layer complete）

# ============================================================
# 内部状态
# ============================================================
var _loop_tweens: Dictionary = {}
var _one_shot_tweens: Array[Tween] = []
var _presentation_nodes: Array[Node] = []  # Phase 27K-R1-B: cancellable view-only primitives
var _presentation_tweens_by_node_id: Dictionary = {}
## 记录被 shake 的 root 原始位置，用于恢复
var _shake_root: Control = null
var _shake_orig_pos: Vector2 = Vector2.ZERO


# ============================================================
# 安全工具
# ============================================================

func _is_safe(node: Node) -> bool:
	return node != null and is_instance_valid(node)


func stop_all() -> void:
	for key in _loop_tweens.keys():
		var tw: Tween = _loop_tweens[key]
		if tw and tw.is_valid():
			tw.kill()
	_loop_tweens.clear()
	for tw in _one_shot_tweens:
		if tw and tw.is_valid():
			tw.kill()
	_one_shot_tweens.clear()
	_presentation_tweens_by_node_id.clear()
	var temporary := _presentation_nodes.duplicate()
	_presentation_nodes.clear()
	for node in temporary:
		if _is_safe(node):
			if node.get_parent() != null:
				node.get_parent().remove_child(node)
			node.queue_free()
	if _is_safe(_shake_root):
		_shake_root.position = _shake_orig_pos
	_shake_root = null


func get_active_tween_count() -> int:
	var count := 0
	for tween in _loop_tweens.values():
		if tween != null and tween.is_valid():
			count += 1
	for tween in _one_shot_tweens:
		if tween != null and tween.is_valid():
			count += 1
	return count


func get_presentation_debug_snapshot() -> Dictionary:
	var node_count := 0
	for node in _presentation_nodes:
		if _is_safe(node):
			node_count += 1
	return {
		"temporary_node_count": node_count,
		"active_tween_count": get_active_tween_count(),
		"shake_count": 1 if _is_safe(_shake_root) else 0,
	}


func _track_presentation_node(node: Node, generation: int) -> Node:
	if node == null:
		return null
	node.set_meta("presentation_generation", generation)
	_presentation_nodes.append(node)
	return node


func _finish_presentation_node(node: Node) -> void:
	if _is_safe(node):
		_presentation_tweens_by_node_id.erase(node.get_instance_id())
	_presentation_nodes.erase(node)
	if _is_safe(node):
		node.queue_free()


func cancel_presentation_node(node: Node) -> void:
	if not _is_safe(node):
		return
	var node_id := node.get_instance_id()
	var tween: Tween = _presentation_tweens_by_node_id.get(node_id, null) as Tween
	if tween != null:
		if tween.is_valid():
			tween.kill()
		_one_shot_tweens.erase(tween)
	_presentation_tweens_by_node_id.erase(node_id)
	_presentation_nodes.erase(node)
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.queue_free()


func _track_presentation_tween(node: Node, tween: Tween) -> void:
	if _is_safe(node) and tween != null:
		_presentation_tweens_by_node_id[node.get_instance_id()] = tween


## Phase 10F: 停止指定节点的循环 tween
func stop_for(node: Node) -> void:
	if not _is_safe(node):
		return
	var key: int = node.get_instance_id()
	if not _loop_tweens.has(key):
		return
	var tw: Tween = _loop_tweens[key]
	if tw and tw.is_valid():
		tw.kill()
	_loop_tweens.erase(key)


# ============================================================
# 槽位解锁 — 亮边 + scale pulse
# ============================================================

func play_slot_unlock(slot: Control, layer: int = 1) -> void:
	if not _is_safe(slot):
		return
	var tween: Tween = slot.create_tween()
	tween.set_parallel(true)
	var slot_panel: Panel = slot.get_node_or_null("SlotPanel") as Panel
	if slot_panel and _is_safe(slot_panel):
		tween.tween_property(slot_panel, "modulate", Color(2.0, 2.0, 1.2, 1), 0.12)
		tween.tween_property(slot_panel, "modulate", Color(1, 1, 1, 1), 0.25)\
			.set_delay(0.12)
	tween.tween_property(slot, "scale", Vector2(1.06, 1.06), 0.12)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(slot, "scale", Vector2(1.0, 1.0), 0.2)\
		.set_delay(0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_one_shot_tweens.append(tween)


# ============================================================
# Phase 10F: Engine Gauge Charge Tick — 当前条短促亮一下
# ============================================================

func play_engine_charge_tick(bar: Control, layer: int) -> void:
	if not _is_safe(bar):
		return
	var orig_mod := bar.modulate
	var tween: Tween = bar.create_tween()
	tween.tween_property(bar, "modulate", Color(2.5, 2.5, 2.5, 1), 0.06)
	tween.tween_property(bar, "modulate", orig_mod, 0.15)
	_one_shot_tweens.append(tween)


# ============================================================
# Phase 10F: Engine Gauge Current Pulse — 当前层呼吸（循环）
# ============================================================

func play_engine_current_pulse(bar: Control, layer: int) -> void:
	if not _is_safe(bar):
		return
	stop_for(bar)
	var key: int = bar.get_instance_id()
	var tween: Tween = bar.create_tween()
	tween.set_loops()
	# 根据层数调整呼吸节奏
	var period := 1.2 - layer * 0.12  # L1=1.08s, L5=0.6s
	period = maxf(0.45, period)
	tween.tween_property(bar, "modulate:a", 0.5, period * 0.5).set_trans(Tween.TRANS_SINE)
	tween.tween_property(bar, "modulate:a", 1.0, period * 0.5).set_trans(Tween.TRANS_SINE)
	_loop_tweens[key] = tween


# ============================================================
# Phase 10F: Engine Gauge Layer Complete — 完成层闪亮后收敛
# ============================================================

func play_engine_layer_complete(bar: Control, layer: int) -> void:
	if not _is_safe(bar):
		return
	stop_for(bar)
	var tween: Tween = bar.create_tween()
	tween.tween_property(bar, "modulate", Color(1.8, 1.8, 1.8, 1), 0.1)
	tween.tween_property(bar, "modulate", Color(0.3, 0.3, 0.35, 1), 0.35)
	_one_shot_tweens.append(tween)


# ============================================================
# Engine Gauge Layer Up — 仪表短暂发光 + 微震
# ============================================================

func play_engine_layer_up(panel: Control, layer: int) -> void:
	if not _is_safe(panel):
		return
	var color: Color
	match layer:
		2: color = Color(0.00, 0.81, 0.82, 1)
		3: color = Color(0.20, 0.60, 0.86, 1)
		4: color = Color(0.56, 0.27, 0.68, 1)
		5: color = Color(1.0, 0.25, 0.06, 1)
		_: color = Color(0.18, 0.80, 0.25, 1)

	# Phase 10F: 强光 + 微震（scale pulse）
	var orig_scale := panel.scale
	var orig_mod := panel.modulate
	var tween: Tween = panel.create_tween()
	tween.set_parallel(true)
	tween.tween_property(panel, "modulate", Color(color.r * 2.5, color.g * 2.5, color.b * 2.5, 1), 0.08)
	tween.tween_property(panel, "scale", Vector2(1.04, 1.04), 0.08)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "modulate", orig_mod, 0.25).set_delay(0.08)
	tween.tween_property(panel, "scale", orig_scale, 0.2)\
		.set_delay(0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_one_shot_tweens.append(tween)


# ============================================================
# Burst Flash — 金橙闪光（Phase 10F: 增强持续时间和强度）
# ============================================================

func play_burst_flash(root: Control) -> void:
	if not _is_safe(root):
		return
	# Phase 10F: 更强、稍长的闪光
	var overlay := ColorRect.new()
	overlay.color = Color(1, 0.5, 0.05, 0.35)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(overlay)

	var tween: Tween = overlay.create_tween()
	tween.tween_property(overlay, "color:a", 0.15, 0.15)
	tween.tween_property(overlay, "color:a", 0.0, 0.5)
	tween.tween_callback(overlay.queue_free)
	_one_shot_tweens.append(tween)


# ============================================================
# Phase 10F: Depth Warning — 增强紫色闪烁
# ============================================================

func play_depth_warning(target: Control, depth_value: int) -> void:
	if not _is_safe(target):
		return
	stop_for(target)
	var intensity: float = minf(1.0, depth_value / 6.0)
	var flash_color := Color(0.8 + intensity * 0.2, 0.1, 0.7, 1)
	var tween: Tween = target.create_tween()
	tween.tween_property(target, "modulate", flash_color, 0.06)
	tween.tween_property(target, "modulate", Color(1, 1, 1, 1), 0.2)
	_one_shot_tweens.append(tween)


# ============================================================
# Boss Core Pulse — 红/橙呼吸（循环）
# ============================================================

func play_boss_core_pulse(target: Control, level: int = 1) -> void:
	if not _is_safe(target):
		return
	var key: int = target.get_instance_id()
	if _loop_tweens.has(key):
		var old: Tween = _loop_tweens[key]
		if old and old.is_valid():
			old.kill()
		_loop_tweens.erase(key)

	var intensity: float = 1.0 + level * 0.15
	var period: float = maxf(0.6, 1.8 - level * 0.2)
	var tween: Tween = target.create_tween()
	tween.set_loops()
	tween.tween_property(target, "modulate:a", 0.55, period * 0.5)\
		.set_trans(Tween.TRANS_SINE)
	tween.tween_property(target, "modulate:a", intensity, period * 0.5)\
		.set_trans(Tween.TRANS_SINE)
	_loop_tweens[key] = tween


# ============================================================
# Screen Shake — 小幅位移后归位
# ============================================================

func play_screen_shake(root: Control, strength: float = 4.0, duration: float = 0.12) -> void:
	if not _is_safe(root):
		return
	_shake_root = root
	_shake_orig_pos = root.position
	var iterations := maxi(1, ceili(duration / 0.03))
	var settle_time := minf(0.05, duration * 0.3)
	var tween: Tween = create_tween()
	for i in range(iterations):
		tween.tween_property(
			root,
			"position",
			Vector2(randf_range(-strength, strength), randf_range(-strength, strength)),
			0.03
		)
	tween.tween_property(root, "position", _shake_orig_pos, settle_time)
	_one_shot_tweens.append(tween)


# ============================================================
# Phase 12D: Field Action VFX — 短生命周期场上特效
# ============================================================

const ZI_FIELD_VFX := 150

## 攻击线 — 从攻击者到目标的短促连线
func play_attack_line(root: Control, from_global: Vector2, to_global: Vector2, color: Color = Color(1, 0.55, 0.15, 1)) -> void:
	## Phase 26B-T4: endpoints clamped to viewport safe rect.
	if not _is_safe(root):
		return
	var vp_rect: Rect2 = root.get_viewport_rect()
	var margin: float = 6.0
	var clamped_from: Vector2 = Vector2(
		clampf(from_global.x, margin, vp_rect.size.x - margin),
		clampf(from_global.y, margin, vp_rect.size.y - margin)
	)
	var clamped_to: Vector2 = Vector2(
		clampf(to_global.x, margin, vp_rect.size.x - margin),
		clampf(to_global.y, margin, vp_rect.size.y - margin)
	)
	var line := Line2D.new()
	line.name = "AttackLine"
	line.z_index = ZI_FIELD_VFX
	line.width = 3.0
	line.default_color = color
	line.add_point(root.get_global_transform().affine_inverse() * clamped_from)
	line.add_point(root.get_global_transform().affine_inverse() * clamped_to)
	root.add_child(line)

	var tween: Tween = root.create_tween()
	tween.tween_property(line, "modulate:a", 0.0, 0.22).set_delay(0.06)
	tween.tween_callback(func():
		if _is_safe(line):
			line.queue_free()
	)
	_one_shot_tweens.append(tween)


func play_impact_burst(root: Control, at_global: Vector2, color: Color = Color(1, 0.35, 0.15, 1), scale_hint: float = 1.0) -> void:
	if not _is_safe(root):
		return
	var burst := ColorRect.new()
	burst.name = "ImpactBurst"
	burst.z_index = ZI_FIELD_VFX
	burst.mouse_filter = Control.MOUSE_FILTER_IGNORE
	burst.color = Color(color.r, color.g, color.b, 0.45)
	var sz := 20.0 * scale_hint
	burst.size = Vector2(sz, sz)
	burst.pivot_offset = Vector2(sz * 0.5, sz * 0.5)
	var local_pos := root.get_global_transform().affine_inverse() * at_global
	burst.position = local_pos - Vector2(sz * 0.5, sz * 0.5)
	root.add_child(burst)

	var tween: Tween = root.create_tween()
	tween.set_parallel(true)
	tween.tween_property(burst, "scale", Vector2(2.5, 2.5), 0.25)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(burst, "color:a", 0.0, 0.22)
	tween.tween_callback(func():
		if _is_safe(burst):
			burst.queue_free()
	)
	_one_shot_tweens.append(tween)


## 法术波纹 — 目标区域扩散的蓝色波纹环
func play_spell_wave(root: Control, at_global: Vector2, color: Color = Color(0.35, 0.65, 1.0, 1)) -> void:
	if not _is_safe(root):
		return
	var wave := ColorRect.new()
	wave.name = "SpellWave"
	wave.z_index = ZI_FIELD_VFX
	wave.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wave.color = Color(color.r, color.g, color.b, 0.3)
	var sz := 16.0
	wave.size = Vector2(sz, sz)
	wave.pivot_offset = Vector2(sz * 0.5, sz * 0.5)
	var local_pos := root.get_global_transform().affine_inverse() * at_global
	wave.position = local_pos - Vector2(sz * 0.5, sz * 0.5)
	root.add_child(wave)

	var tween: Tween = root.create_tween()
	tween.set_parallel(true)
	tween.tween_property(wave, "scale", Vector2(3.0, 3.0), 0.35)\
		.set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)
	tween.tween_property(wave, "color:a", 0.0, 0.3)
	tween.tween_callback(func():
		if _is_safe(wave):
			wave.queue_free()
	)
	_one_shot_tweens.append(tween)


## 反制锁链 — 从 COUNTER 到目标的青绿色封锁线
func play_counter_lock(root: Control, from_global: Vector2, to_global: Vector2) -> void:
	if not _is_safe(root):
		return
	var lock_color := Color(0.2, 0.9, 0.6, 0.8)
	var line := Line2D.new()
	line.name = "CounterLock"
	line.z_index = ZI_FIELD_VFX
	line.width = 2.5
	line.default_color = lock_color
	# 锯齿锁链效果：3段折线
	var from_local := root.get_global_transform().affine_inverse() * from_global
	var to_local := root.get_global_transform().affine_inverse() * to_global
	var mid := (from_local + to_local) * 0.5 + Vector2(0, -15)
	line.add_point(from_local)
	line.add_point(mid)
	line.add_point(to_local)
	root.add_child(line)

	var tween: Tween = root.create_tween()
	tween.tween_property(line, "modulate:a", 0.4, 0.15)
	tween.tween_property(line, "modulate:a", 0.8, 0.12)
	tween.tween_property(line, "modulate:a", 0.0, 0.2)
	tween.tween_callback(func():
		if _is_safe(line):
			line.queue_free()
	)
	_one_shot_tweens.append(tween)


## 建筑光环 — 建筑发动时扩散的铜金能量环
func play_building_aura(root: Control, at_global: Vector2, color: Color = Color(1.0, 0.68, 0.2, 1)) -> void:
	if not _is_safe(root):
		return
	var aura := ColorRect.new()
	aura.name = "BuildingAura"
	aura.z_index = ZI_FIELD_VFX
	aura.mouse_filter = Control.MOUSE_FILTER_IGNORE
	aura.color = Color(color.r, color.g, color.b, 0.35)
	var sz := 24.0
	aura.size = Vector2(sz, sz)
	aura.pivot_offset = Vector2(sz * 0.5, sz * 0.5)
	var local_pos := root.get_global_transform().affine_inverse() * at_global
	aura.position = local_pos - Vector2(sz * 0.5, sz * 0.5)
	root.add_child(aura)

	var tween: Tween = root.create_tween()
	tween.set_parallel(true)
	tween.tween_property(aura, "scale", Vector2(3.5, 3.5), 0.45)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(aura, "color:a", 0.0, 0.4)
	tween.tween_callback(func():
		if _is_safe(aura):
			aura.queue_free()
	)
	_one_shot_tweens.append(tween)


# ============================================================
# Phase 12E: Boss Spectacle — BossCore 受击与暴走
# ============================================================

## BossCore 受击 — 白橙闪光 + 微缩
func play_boss_core_hit(root: Control, at_global: Vector2) -> void:
	if not _is_safe(root):
		return
	var hit := ColorRect.new()
	hit.name = "BossCoreHit"
	hit.z_index = 55
	hit.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hit.color = Color(1, 0.6, 0.2, 0.35)
	var sz := 28.0
	hit.size = Vector2(sz, sz)
	hit.pivot_offset = Vector2(sz * 0.5, sz * 0.5)
	var local_pos := root.get_global_transform().affine_inverse() * at_global
	hit.position = local_pos - Vector2(sz * 0.5, sz * 0.5)
	root.add_child(hit)

	var tween: Tween = root.create_tween()
	tween.set_parallel(true)
	tween.tween_property(hit, "scale", Vector2(2.0, 2.0), 0.18)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(hit, "color:a", 0.0, 0.2)
	tween.tween_callback(func():
		if _is_safe(hit):
			hit.queue_free()
	)
	_one_shot_tweens.append(tween)


## Boss Overdrive 暴走脉冲 — 红紫强闪光扩散
func play_boss_overdrive_surge(root: Control, at_global: Vector2) -> void:
	if not _is_safe(root):
		return
	var surge := ColorRect.new()
	surge.name = "BossOverdriveSurge"
	surge.z_index = 55
	surge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	surge.color = Color(1, 0.1, 0.05, 0.4)
	var sz := 32.0
	surge.size = Vector2(sz, sz)
	surge.pivot_offset = Vector2(sz * 0.5, sz * 0.5)
	var local_pos := root.get_global_transform().affine_inverse() * at_global
	surge.position = local_pos - Vector2(sz * 0.5, sz * 0.5)
	root.add_child(surge)

	var tween: Tween = root.create_tween()
	tween.set_parallel(true)
	tween.tween_property(surge, "scale", Vector2(3.5, 3.5), 0.4)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(surge, "color", Color(0.6, 0.05, 0.5, 0), 0.35)
	tween.tween_callback(func():
		if _is_safe(surge):
			surge.queue_free()
	)
	_one_shot_tweens.append(tween)


# ============================================================
# Phase 12F: Table Stage — 桌面能量线
# ============================================================

## 桌面能量脉冲 — 沿桌面从 from 到 to 短促闪线
func play_table_energy_pulse(root: Control, from_global: Vector2, to_global: Vector2, color: Color = Color(0.2, 0.6, 1.0, 0.8)) -> void:
	if not _is_safe(root):
		return
	var line := Line2D.new()
	line.name = "TableEnergyPulse"
	line.z_index = 25  # 在卡槽之下、桌面之上
	line.width = 2.0
	line.default_color = color
	line.add_point(root.get_global_transform().affine_inverse() * from_global)
	line.add_point(root.get_global_transform().affine_inverse() * to_global)
	root.add_child(line)

	var tween: Tween = root.create_tween()
	tween.tween_property(line, "modulate:a", 0.9, 0.06)
	tween.tween_property(line, "modulate:a", 0.0, 0.25)
	tween.tween_callback(func():
		if _is_safe(line):
			line.queue_free()
	)
	_one_shot_tweens.append(tween)


# ============================================================
# Phase 27K-R1-B: reusable read-only presentation primitives
# ============================================================

func play_board_dim(root: Control, alpha: float, duration: float, generation: int) -> Node:
	if not _is_safe(root):
		return null
	var overlay := ColorRect.new()
	overlay.name = "PresentationBoardDim"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.z_index = 120
	overlay.color = Color(0.015, 0.02, 0.045, 0.0)
	root.add_child(overlay)
	_track_presentation_node(overlay, generation)
	var tween := root.create_tween()
	tween.tween_property(overlay, "color:a", clampf(alpha, 0.0, 0.65), maxf(0.01, duration * 0.35))
	tween.tween_property(overlay, "color:a", 0.0, maxf(0.01, duration * 0.65))
	tween.tween_callback(_finish_presentation_node.bind(overlay))
	_one_shot_tweens.append(tween)
	return overlay


func play_conduit_path(root: Control, points: Array[Vector2], color: Color, duration: float, generation: int, reduced_motion_static: bool = false) -> Node:
	if not _is_safe(root) or points.size() < 2:
		return null
	var line := Line2D.new()
	line.name = "PresentationConduitPath"
	line.z_index = 132
	line.width = 4.0
	line.default_color = color
	var local_points: Array[Vector2] = []
	for point in points:
		var local_point: Vector2 = root.get_global_transform().affine_inverse() * point
		local_points.append(local_point)
		line.add_point(local_point)
	line.set_meta("presentation_points", points.duplicate())
	line.set_meta("reduced_motion_static", reduced_motion_static)
	root.add_child(line)
	_track_presentation_node(line, generation)
	var tween := root.create_tween()
	if reduced_motion_static:
		line.width = 6.0
		tween.tween_interval(maxf(0.01, duration * 0.45))
		tween.tween_property(line, "modulate:a", 0.0, maxf(0.01, duration * 0.55))
	else:
		tween.tween_property(line, "width", 7.0, maxf(0.01, duration * 0.3)).set_trans(Tween.TRANS_SINE)
		tween.tween_property(line, "modulate:a", 0.0, maxf(0.01, duration * 0.7))
	tween.tween_callback(_finish_presentation_node.bind(line))
	_one_shot_tweens.append(tween)
	return line


func play_material_stamp(root: Control, center: Vector2, motif: StringName, color: Color, duration: float, generation: int, reduced_motion: bool = false) -> Node:
	if not _is_safe(root):
		return null
	var stamp := Panel.new()
	stamp.name = "PresentationMaterialStamp"
	stamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stamp.z_index = 134
	stamp.size = Vector2(84, 58)
	stamp.pivot_offset = stamp.size * 0.5
	var final_position := root.get_global_transform().affine_inverse() * center - stamp.pivot_offset
	stamp.position = final_position
	stamp.set_meta("motif", motif)
	stamp.set_meta("physical_material", &"stone_iron")
	stamp.set_meta("crystal_reveal_alpha", _crystal_reveal_alpha(color))
	var plate_style := StyleBoxFlat.new()
	plate_style.bg_color = Color(0.075, 0.080, 0.085, 0.96)
	plate_style.border_color = Color(0.31, 0.32, 0.31, 0.98)
	plate_style.set_border_width_all(3)
	plate_style.corner_radius_top_left = 8
	plate_style.corner_radius_top_right = 5
	plate_style.corner_radius_bottom_left = 5
	plate_style.corner_radius_bottom_right = 8
	stamp.add_theme_stylebox_override("panel", plate_style)
	var inset := Line2D.new()
	inset.name = "CrystalInset"
	inset.set_meta("reduced_motion", reduced_motion)
	inset.width = 2.0
	inset.default_color = _limited_crystal_color(color)
	inset.add_point(Vector2(19, 32))
	inset.add_point(Vector2(33, 22))
	inset.add_point(Vector2(43, 35))
	inset.add_point(Vector2(64, 24))
	stamp.add_child(inset)
	root.add_child(stamp)
	_track_presentation_node(stamp, generation)
	var lifetime := maxf(0.01, duration)
	var tween := root.create_tween()
	if reduced_motion:
		tween.tween_interval(lifetime * 0.55)
		tween.tween_property(stamp, "modulate:a", 0.0, lifetime * 0.45)
	else:
		stamp.position = final_position - Vector2(0, 18)
		stamp.scale = Vector2(0.92, 0.92)
		tween.set_parallel(true)
		tween.tween_property(stamp, "position", final_position, lifetime * 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_property(stamp, "scale", Vector2.ONE, lifetime * 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.chain().tween_interval(lifetime * 0.28)
		tween.chain().tween_property(stamp, "modulate:a", 0.0, lifetime * 0.40)
	tween.chain().tween_callback(_finish_presentation_node.bind(stamp))
	_one_shot_tweens.append(tween)
	_track_presentation_tween(stamp, tween)
	return stamp


func play_weighted_path(root: Control, points: Array[Vector2], motif: StringName, color: Color, duration: float, generation: int, reduced_motion: bool = false) -> Node:
	if not _is_safe(root) or points.size() < 2:
		return null
	var path_root := Control.new()
	path_root.name = "PresentationWeightedPath"
	path_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	path_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	path_root.z_index = 133
	path_root.set_meta("motif", motif)
	path_root.set_meta("physical_material", &"iron_track")
	path_root.set_meta("presentation_points", points.duplicate())
	path_root.set_meta("crystal_reveal_alpha", _crystal_reveal_alpha(color))
	var iron_track := Line2D.new()
	iron_track.name = "IronTrack"
	iron_track.set_meta("reduced_motion", reduced_motion)
	iron_track.width = 10.0
	iron_track.default_color = Color(0.095, 0.10, 0.105, 0.98)
	iron_track.joint_mode = Line2D.LINE_JOINT_BEVEL
	var crystal_inlay := Line2D.new()
	crystal_inlay.name = "CrystalInlay"
	crystal_inlay.set_meta("reduced_motion", reduced_motion)
	crystal_inlay.width = 2.5
	crystal_inlay.default_color = _limited_crystal_color(color)
	crystal_inlay.joint_mode = Line2D.LINE_JOINT_BEVEL
	for point in points:
		var local_point: Vector2 = root.get_global_transform().affine_inverse() * point
		iron_track.add_point(local_point)
		crystal_inlay.add_point(local_point)
	path_root.add_child(iron_track)
	path_root.add_child(crystal_inlay)
	root.add_child(path_root)
	_track_presentation_node(path_root, generation)
	var lifetime := maxf(0.01, duration)
	var tween := root.create_tween()
	if reduced_motion:
		tween.tween_interval(lifetime * 0.58)
		tween.tween_property(path_root, "modulate:a", 0.0, lifetime * 0.42)
	else:
		iron_track.width = 14.0
		crystal_inlay.width = 5.0
		tween.set_parallel(true)
		tween.tween_property(iron_track, "width", 10.0, lifetime * 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(crystal_inlay, "width", 2.5, lifetime * 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.chain().tween_interval(lifetime * 0.30)
		tween.chain().tween_property(path_root, "modulate:a", 0.0, lifetime * 0.42)
	tween.chain().tween_callback(_finish_presentation_node.bind(path_root))
	_one_shot_tweens.append(tween)
	_track_presentation_tween(path_root, tween)
	return path_root


func play_material_response(root: Control, center: Vector2, motif: StringName, color: Color, duration: float, generation: int, reduced_motion: bool = false) -> Node:
	if not _is_safe(root):
		return null
	var response := Panel.new()
	response.name = "PresentationMaterialResponse"
	response.mouse_filter = Control.MOUSE_FILTER_IGNORE
	response.z_index = 137
	response.size = Vector2(70, 70)
	response.pivot_offset = response.size * 0.5
	response.position = root.get_global_transform().affine_inverse() * center - response.pivot_offset
	response.set_meta("motif", motif)
	response.set_meta("physical_material", &"fractured_stone_iron")
	response.set_meta("crystal_reveal_alpha", _crystal_reveal_alpha(color))
	var response_style := StyleBoxFlat.new()
	response_style.bg_color = Color(0.055, 0.06, 0.065, 0.94)
	response_style.border_color = Color(0.36, 0.35, 0.31, 0.98)
	response_style.set_border_width_all(4)
	response_style.set_corner_radius_all(9)
	response.add_theme_stylebox_override("panel", response_style)
	var fissure := Line2D.new()
	fissure.name = "CrystalFissure"
	fissure.set_meta("reduced_motion", reduced_motion)
	fissure.width = 2.2
	fissure.default_color = _limited_crystal_color(color)
	fissure.add_point(Vector2(10, 39))
	fissure.add_point(Vector2(26, 31))
	fissure.add_point(Vector2(34, 17))
	fissure.add_point(Vector2(40, 36))
	fissure.add_point(Vector2(59, 29))
	response.add_child(fissure)
	root.add_child(response)
	_track_presentation_node(response, generation)
	var lifetime := maxf(0.01, duration)
	var tween := root.create_tween()
	if reduced_motion:
		tween.tween_interval(lifetime * 0.60)
		tween.tween_property(response, "modulate:a", 0.0, lifetime * 0.40)
	else:
		response.scale = Vector2(0.78, 0.78)
		tween.tween_property(response, "scale", Vector2.ONE, lifetime * 0.30).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_interval(lifetime * 0.28)
		tween.tween_property(response, "modulate:a", 0.0, lifetime * 0.42)
	tween.chain().tween_callback(_finish_presentation_node.bind(response))
	_one_shot_tweens.append(tween)
	_track_presentation_tween(response, tween)
	return response


func _limited_crystal_color(color: Color) -> Color:
	return Color(color.r, color.g, color.b, _crystal_reveal_alpha(color))


func _crystal_reveal_alpha(color: Color) -> float:
	return clampf(color.a, 0.0, 0.60)


func play_piece_sigil(root: Control, center: Vector2, piece_type: StringName, color: Color, duration: float, generation: int) -> Node:
	if not _is_safe(root):
		return null
	var style_by_piece := {
		&"pawn": &"forward_fan",
		&"knight": &"knight_l",
		&"bishop": &"diagonal_cross",
		&"rook": &"orthogonal_cross",
	}
	var glyph_by_piece := {
		&"pawn": "△",
		&"knight": "⌞",
		&"bishop": "╳",
		&"rook": "╋",
	}
	var sigil := Panel.new()
	sigil.name = "PresentationPieceSigil"
	sigil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sigil.z_index = 136
	sigil.size = Vector2(64, 64)
	sigil.pivot_offset = sigil.size * 0.5
	sigil.position = root.get_global_transform().affine_inverse() * center - sigil.pivot_offset
	var piece_style := StringName(style_by_piece.get(piece_type, &"neutral_ring"))
	sigil.set_meta("piece_type", piece_type)
	sigil.set_meta("sigil_style", piece_style)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(color.r * 0.15, color.g * 0.15, color.b * 0.15, 0.15)
	panel_style.border_color = Color(color.r, color.g, color.b, 0.9)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(32)
	sigil.add_theme_stylebox_override("panel", panel_style)
	var glyph := Label.new()
	glyph.set_anchors_preset(Control.PRESET_FULL_RECT)
	glyph.text = str(glyph_by_piece.get(piece_type, "◇"))
	glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	glyph.add_theme_font_size_override("font_size", 30)
	glyph.add_theme_color_override("font_color", color)
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sigil.add_child(glyph)
	root.add_child(sigil)
	_track_presentation_node(sigil, generation)
	var tween := root.create_tween()
	tween.set_parallel(true)
	tween.tween_property(sigil, "scale", Vector2(1.45, 1.45), maxf(0.01, duration)).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(sigil, "modulate:a", 0.0, maxf(0.01, duration)).set_delay(maxf(0.0, duration * 0.3))
	tween.chain().tween_callback(_finish_presentation_node.bind(sigil))
	_one_shot_tweens.append(tween)
	return sigil


func play_result_badge(root: Control, at_global: Vector2, facts: Dictionary, duration: float, generation: int, reduced_motion_static: bool = false) -> Node:
	if not _is_safe(root):
		return null
	var badge := PanelContainer.new()
	badge.name = "PresentationResultBadge"
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.z_index = 142
	badge.position = root.get_global_transform().affine_inverse() * at_global - Vector2(70, 20)
	badge.custom_minimum_size = Vector2(140, 36)
	for key in facts.keys():
		badge.set_meta(str(key), facts[key])
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.035, 0.07, 0.94)
	style.border_color = Color(0.82, 0.64, 0.25, 0.95)
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	badge.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	var parts: PackedStringArray = []
	if facts.has("damage") and int(facts.get("damage", 0)) > 0:
		parts.append("伤害 %d" % int(facts.get("damage", 0)))
	if facts.has("shield_absorbed") and int(facts.get("shield_absorbed", 0)) > 0:
		parts.append("护盾吸收 %d" % int(facts.get("shield_absorbed", 0)))
	if facts.has("heal") and int(facts.get("heal", 0)) > 0:
		parts.append("恢复 %d" % int(facts.get("heal", 0)))
	if facts.has("buff") and not str(facts.get("buff", "")).is_empty():
		parts.append("强化 %s" % str(facts.get("buff", "")))
	if facts.has("debuff") and not str(facts.get("debuff", "")).is_empty():
		parts.append("弱化 %s" % str(facts.get("debuff", "")))
	if facts.has("move") and not str(facts.get("move", "")).is_empty():
		parts.append("移动 %s" % str(facts.get("move", "")))
	if facts.has("summon") and bool(facts.get("summon", false)):
		parts.append("召唤完成")
	if parts.is_empty():
		parts.append(str(facts.get("label", "已结算")))
	label.text = "  ".join(parts)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.62, 1.0))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(label)
	root.add_child(badge)
	_track_presentation_node(badge, generation)
	var tween := root.create_tween()
	tween.set_parallel(true)
	if not reduced_motion_static:
		tween.tween_property(badge, "position:y", badge.position.y - 28.0, maxf(0.01, duration)).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(badge, "modulate:a", 0.0, maxf(0.01, duration * 0.45)).set_delay(maxf(0.0, duration * 0.55))
	tween.chain().tween_callback(_finish_presentation_node.bind(badge))
	_one_shot_tweens.append(tween)
	return badge


func play_spawn_ring(root: Control, at_global: Vector2, color: Color, duration: float, generation: int) -> Node:
	if not _is_safe(root):
		return null
	var ring := Panel.new()
	ring.name = "PresentationSpawnRing"
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.z_index = 130
	ring.size = Vector2(52, 52)
	ring.pivot_offset = ring.size * 0.5
	ring.position = root.get_global_transform().affine_inverse() * at_global - ring.pivot_offset
	var style := StyleBoxFlat.new()
	style.bg_color = Color(color.r, color.g, color.b, 0.04)
	style.border_color = Color(color.r, color.g, color.b, 0.9)
	style.set_border_width_all(3)
	style.set_corner_radius_all(26)
	ring.add_theme_stylebox_override("panel", style)
	root.add_child(ring)
	_track_presentation_node(ring, generation)
	var tween := root.create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector2(2.3, 2.3), maxf(0.01, duration)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring, "modulate:a", 0.0, maxf(0.01, duration))
	tween.chain().tween_callback(_finish_presentation_node.bind(ring))
	_one_shot_tweens.append(tween)
	return ring


# ============================================================
# 生命周期清理
# ============================================================

func _exit_tree() -> void:
	stop_all()
