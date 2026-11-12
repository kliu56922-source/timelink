extends Node2D
class_name BattleFX

const TC = preload("res://core/theme/theme_colors.gd")

# ======================
# 屏幕震动
# ======================
func shake(strength: float = 8.0, duration: float = 0.15) -> void:
	var root := get_tree().current_scene
	if root == null:
		return
	var iterations := maxi(1, ceili(duration / 0.03))
	var settle_time := minf(0.05, duration * 0.3)
	var tween := create_tween()
	for i in range(iterations):
		tween.tween_property(
			root,
			"position",
			Vector2(randf_range(-strength, strength), randf_range(-strength, strength)),
			0.03
		)
	tween.tween_property(root, "position", Vector2(0, 0), settle_time)


# ======================
# 命中闪白（单个节点）
# ======================
func hit_flash(node: CanvasItem) -> void:
	if node == null:
		return
	var tween := create_tween()
	tween.tween_property(node, "modulate", Color(2, 2, 2), 0.05)
	tween.tween_property(node, "modulate", Color(1, 1, 1), 0.1)


# ======================
# 全屏闪白 / 闪色
# ======================
func flash(color: Color = Color(1, 1, 1, 0.25), duration: float = 0.15) -> void:
	var root := get_tree().current_scene
	if root == null:
		return
	var overlay := ColorRect.new()
	overlay.color = color
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(overlay)

	var tween := create_tween()
	tween.tween_property(overlay, "color:a", 0.0, duration)
	tween.tween_callback(overlay.queue_free)


# ======================
# SUPER 卡专属演出
# ======================
func super_flash() -> void:
	flash(Color(1, 0.85, 0.2, 0.4), 0.3)
	shake(15.0, 0.25)


# ======================
# 伤害数字
# ======================
func damage_number(parent: Node, pos: Vector2, value: int, crit := false) -> void:
	if not is_instance_valid(parent):
		return
	var dmg_scene = load("res://ui/damage_number.tscn")
	if dmg_scene == null:
		return
	var dmg = dmg_scene.instantiate()
	if dmg == null:
		return
	parent.add_child(dmg)
	dmg.global_position = pos
	if dmg.has_method("setup"):
		dmg.setup(value, crit)


# ======================
# 卡牌飞行
# ======================
func fly_card(node: Node2D, target: Vector2) -> void:
	var tween := create_tween()
	tween.tween_property(node, "global_position", target, 0.25)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_OUT)


# ======================
# Boss 领域转场 — 升温区
# ======================
func boss_zone_heated() -> void:
	flash(Color(1, 0.45, 0.1, 0.3), 0.4)
	shake(8.0, 0.2)


# ======================
# Boss 领域转场 — 超驱区
# ======================
func boss_zone_overdrive() -> void:
	flash(Color(1, 0.08, 0.05, 0.45), 0.5)
	shake(16.0, 0.35)


# ======================
# Boss 熔炉爆发
# ======================
func boss_meltdown_burst() -> void:
	flash(Color(1, 0.2, 0.05, 0.5), 0.5)
	shake(22.0, 0.4)


# ======================
# Boss 死亡演出
# ======================
func boss_defeated() -> void:
	flash(Color(1, 0.85, 0.2, 0.5), 0.6)
	shake(24.0, 0.5)


# ======================
# Boss Reaction 闪光
# ======================
func boss_reaction_flash() -> void:
	flash(Color(1, 0.35, 0.1, 0.3), 0.3)
	shake(5.0, 0.15)


# ======================
# 护盾脉冲（节点闪蓝白）
# ======================
func shield_pulse(node: CanvasItem) -> void:
	if node == null:
		return
	var t := create_tween()
	t.tween_property(node, "modulate", Color(1.3, 1.3, 1.8, 1), 0.08)
	t.tween_property(node, "modulate", Color(1, 1, 1, 1), 0.2)


# ======================
# OD 条脉冲
# ======================
func od_pulse(bar: ProgressBar, color: Color) -> void:
	if bar == null:
		return
	var orig := bar.modulate
	var t := create_tween()
	t.tween_property(bar, "modulate", Color(2, 2, 2, 1), 0.06)
	t.tween_property(bar, "modulate", color, 0.08)
	t.tween_property(bar, "modulate", orig, 0.15)
