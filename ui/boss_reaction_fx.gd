extends Node
class_name BossReactionFX

## BossReactionFX — Boss 反应视觉效果调度
## 玩家触发反应时：弹出 Reaction 卡框 + 护盾闪光 + Load 提示
## 用法: boss_reaction_fx.trigger_reaction(reaction_card, boss_screen_pos, shield_amount)

const CardUIScene: PackedScene = preload("res://ui/card_ui.tscn")
const TC = preload("res://core/theme/theme_colors.gd")


## 触发完整的反应动画序列（CardUI 卡框版）
func trigger_reaction(card: CardData, boss_screen_pos: Vector2, shield_gained: int) -> void:
	if card == null:
		return
	var root := get_tree().current_scene
	if root == null:
		return

	# ── 1. 弹出 Reaction 卡框（CardUI 占位框，替换旧文字标签）──
	var card_ui: CardUI = CardUIScene.instantiate()
	card_ui.setup(card, true)  # compact 模式
	card_ui.scale = Vector2(0.6, 0.6)
	card_ui.modulate.a = 0.0
	card_ui.global_position = boss_screen_pos - Vector2(76, 96)
	card_ui.z_index = 150
	card_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(card_ui)

	var ct := create_tween()
	ct.set_parallel(true)
	ct.tween_property(card_ui, "modulate:a", 1.0, 0.15)
	ct.tween_property(card_ui, "scale", Vector2(1.0, 1.0), 0.25)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	ct.tween_property(card_ui, "position:y", card_ui.position.y - 60, 0.7)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	ct.tween_property(card_ui, "modulate:a", 0.0, 0.2).set_delay(0.5)
	ct.tween_callback(card_ui.queue_free).set_delay(0.75)

	# ── 2. 护盾闪光（红色屏幕叠加）──
	var flash := ColorRect.new()
	flash.color = Color(0.3, 0.06, 0.02, 0.3)
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(flash)

	var ft := root.create_tween()
	ft.tween_property(flash, "color:a", 0.0, 0.4)
	ft.tween_callback(flash.queue_free)

	# ── 3. 护盾量浮字 ──
	if shield_gained > 0:
		var shield_text := Label.new()
		shield_text.text = "+%d 护盾" % shield_gained
		shield_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		shield_text.add_theme_font_size_override("font_size", 20)
		shield_text.add_theme_color_override("font_color", Color(0.4, 0.8, 1, 1))
		shield_text.global_position = boss_screen_pos + Vector2(0, -60)
		shield_text.modulate.a = 0.0
		shield_text.z_index = 150
		shield_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(shield_text)

		var st := root.create_tween()
		st.set_parallel(true)
		st.tween_property(shield_text, "modulate:a", 1.0, 0.1)
		st.tween_property(shield_text, "position:y", shield_text.position.y - 35, 0.65)
		st.tween_property(shield_text, "modulate:a", 0.0, 0.25).set_delay(0.4)
		st.tween_callback(shield_text.queue_free).set_delay(0.7)

	# ── 4. Load +1 提示 ──
	var load_text := Label.new()
	load_text.text = "Load +1"
	load_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	load_text.add_theme_font_size_override("font_size", 18)
	load_text.add_theme_color_override("font_color", TC.LOAD_SAFE)
	load_text.global_position = boss_screen_pos + Vector2(80, -30)
	load_text.modulate.a = 0.0
	load_text.z_index = 150
	load_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(load_text)

	var lt := root.create_tween()
	lt.set_parallel(true)
	lt.tween_property(load_text, "modulate:a", 1.0, 0.15)
	lt.tween_property(load_text, "position:y", load_text.position.y - 35, 0.6)
	lt.tween_property(load_text, "modulate:a", 0.0, 0.25).set_delay(0.4)
	lt.tween_callback(load_text.queue_free).set_delay(0.7)
