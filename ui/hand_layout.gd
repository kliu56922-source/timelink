extends Control
class_name HandLayout

# Stable horizontal hand layout for Phase 1. No tween, no fan rotation.
const TableLayoutConfigClass = preload("res://core/config/table_layout_config.gd")
var CARD_UI_SIZE: Vector2 = Vector2(152, 192)

@export var min_visible_per_card: float = 72.0
@export var preferred_spacing: float = 130.0
@export var fallback_width: float = 900.0
@export var fallback_height: float = 210.0
@export var max_fan_angle: float = 4.0

var needs_arrange: bool = false
var _cards: Array[CardUI] = []


func _ready() -> void:
	custom_minimum_size = Vector2(fallback_width, fallback_height)
	clip_contents = false
	needs_arrange = true
	if not resized.is_connected(_on_resized):
		resized.connect(_on_resized)
	call_deferred("arrange_cards")


func _on_resized() -> void:
	needs_arrange = true
	call_deferred("arrange_cards")


func arrange_cards() -> void:
	_cards.clear()
	for child in get_children():
		if not is_instance_valid(child):
			continue
		var card: CardUI = child as CardUI
		if card != null and is_instance_valid(card) and not card.is_queued_for_deletion():
			_cards.append(card)

	if _cards.is_empty():
		needs_arrange = false
		return

	var card_count: int = _cards.size()
	var layout_width: float = maxf(maxf(size.x, custom_minimum_size.x), fallback_width)
	var layout_height: float = maxf(maxf(size.y, custom_minimum_size.y), fallback_height)

	var spacing: float = preferred_spacing
	if card_count > 1:
		spacing = minf(preferred_spacing, (layout_width - CARD_UI_SIZE.x) / float(card_count - 1))
		spacing = maxf(min_visible_per_card, spacing)

	var total_width: float = spacing * float(card_count - 1) + CARD_UI_SIZE.x
	var start_x: float = maxf(8.0, (layout_width - total_width) * 0.5)
	var y_pos: float = maxf(0.0, layout_height - CARD_UI_SIZE.y - 8.0)

	# ── Phase 4B-6: 轻微扇形 ──
	var center_i: float = float(card_count - 1) / 2.0
	for i in range(card_count):
		var card: CardUI = _cards[i]
		if card == null or not is_instance_valid(card):
			continue
		card.size = CARD_UI_SIZE
		card.set_as_top_level(false)
		card.custom_minimum_size = CARD_UI_SIZE
		card.scale = Vector2.ONE
		card.pivot_offset = CARD_UI_SIZE * 0.5
		card.position = Vector2(start_x + spacing * float(i), y_pos)
		# 扇形旋转: 中心 0°, 左右最大 ±max_fan_angle
		if card_count > 1:
			var offset: float = float(i) - center_i
			var angle: float = offset * (max_fan_angle / maxf(1.0, center_i))
			card.rotation_degrees = angle
		else:
			card.rotation_degrees = 0.0
		card.z_index = i

	needs_arrange = false


func _process(_delta: float) -> void:
	if needs_arrange:
		arrange_cards()


func add_card(card_ui: CardUI) -> void:
	if card_ui == null or not is_instance_valid(card_ui) or card_ui.is_queued_for_deletion():
		return
	if card_ui.get_parent() and card_ui.get_parent() != self:
		card_ui.get_parent().remove_child(card_ui)
	if card_ui.get_parent() != self:
		add_child(card_ui)
	card_ui.size = CARD_UI_SIZE
	card_ui.custom_minimum_size = CARD_UI_SIZE
	card_ui.scale = Vector2.ONE
	card_ui.position = Vector2.ZERO
	card_ui.rotation_degrees = 0.0
	card_ui.pivot_offset = CARD_UI_SIZE * 0.5
	# Phase 4B-6: 连接 hover 信号管理 z_index
	if not card_ui.card_hovered.is_connected(_on_card_hovered):
		card_ui.card_hovered.connect(_on_card_hovered.bind(card_ui))
	if not card_ui.card_unhovered.is_connected(_on_card_unhovered):
		card_ui.card_unhovered.connect(_on_card_unhovered.bind(card_ui))
	needs_arrange = true
	call_deferred("arrange_cards")


func clear_cards() -> void:
	for child in get_children():
		if not is_instance_valid(child):
			continue
		child.queue_free()
	_cards.clear()
	needs_arrange = true


## Phase 22F-7: 返回手牌 CardUI 数量
func get_card_count() -> int:
	return _cards.size()


## Phase 22F-7: 返回手牌 CardData 数组（供可出性审计）
func get_cards() -> Array:
	var result: Array = []
	for ui in _cards:
		if is_instance_valid(ui) and ui.card_data != null:
			result.append(ui.card_data)
	return result


# ── Phase 4B-8: hover 时 z_index 提升，不遮挡详情区和 EndTurn ──
const ZI_HAND_CARD_HOVER := 80

func _on_card_hovered(_card_data: CardData, card_ui: CardUI) -> void:
	if is_instance_valid(card_ui):
		card_ui.z_index = ZI_HAND_CARD_HOVER  # 80


func _on_card_unhovered(card_ui: CardUI) -> void:
	if is_instance_valid(card_ui):
		needs_arrange = true  # 重排恢复 z_index
