extends Node
class_name BossCardPresenter

## BossCardPresenter — Boss 意图卡动画调度
## 三阶段动画：出现（从 BossCore 飞出）→ 驻留（发光脉冲）→ 消退（飞向墓地/淡出）
## 用法: boss_card_presenter.present_intent(card, from_pos, center_pos, graveyard_pos)
##        await boss_card_presenter.animation_complete

const CardUIScene = preload("res://ui/card_ui.tscn")
const TC = preload("res://core/theme/theme_colors.gd")

signal animation_complete()


## 播放完整的 Boss 意图卡动画序列
func present_intent(card: CardData, from_pos: Vector2, center_pos: Vector2, graveyard_pos: Vector2) -> void:
	if card == null:
		animation_complete.emit()
		return

	var root := get_tree().current_scene
	if root == null:
		animation_complete.emit()
		return

	# 创建临时卡片视觉
	var card_ui: CardUI = CardUIScene.instantiate()
	card_ui.setup_hand(card)
	card_ui.scale = Vector2(0.6, 0.6)
	card_ui.modulate.a = 0.0
	card_ui.global_position = from_pos
	card_ui.z_index = 200
	root.add_child(card_ui)

	# ── 阶段 1：出现 ──
	# 从 BossCore 位置飞入中央，scale 增大，fade in
	var t1 := create_tween()
	t1.set_parallel(true)
	t1.tween_property(card_ui, "modulate:a", 1.0, 0.2)
	t1.tween_property(card_ui, "scale", Vector2(1.0, 1.0), 0.3)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t1.tween_property(card_ui, "global_position", center_pos, 0.35)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await t1.finished

	# ── 阶段 2：驻留 ──
	# 呼吸缩放 + 屏幕微闪
	var t2 := create_tween()
	t2.set_parallel(true)
	t2.tween_property(card_ui, "scale", Vector2(1.15, 1.15), 0.15)\
		.set_trans(Tween.TRANS_SINE)
	t2.tween_property(card_ui, "scale", Vector2(1.0, 1.0), 0.15)\
		.set_trans(Tween.TRANS_SINE).set_delay(0.15)

	# 屏幕微闪
	_add_resolve_flash(root)
	await get_tree().create_timer(0.5).timeout

	# ── 阶段 3：消退 ──
	# 飞向墓地位置，缩小淡出
	var t3 := create_tween()
	t3.set_parallel(true)
	if graveyard_pos != Vector2.ZERO:
		t3.tween_property(card_ui, "global_position", graveyard_pos, 0.3)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	t3.tween_property(card_ui, "modulate:a", 0.0, 0.25)
	t3.tween_property(card_ui, "scale", Vector2(0.5, 0.5), 0.25)
	await t3.finished

	if is_instance_valid(card_ui):
		card_ui.queue_free()

	animation_complete.emit()


## 添加结算闪光（全屏微闪，表示卡牌效果结算）
func _add_resolve_flash(root: Node) -> void:
	var flash := ColorRect.new()
	flash.color = Color(TC.ZONE_HEATED.r, TC.ZONE_HEATED.g, TC.ZONE_HEATED.b, 0.12)
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(flash)

	var t := root.create_tween()
	t.tween_property(flash, "color:a", 0.0, 0.3)
	t.tween_callback(flash.queue_free)
