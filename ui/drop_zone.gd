extends Panel
class_name DropZone

## DropZone — 拖拽放置区域
## 检测 CardUI 拖入，4 种视觉状态 + 实时卡牌预览 + 提示文字。

const TC = preload("res://core/theme/theme_colors.gd")

# ============================================================
# 信号
# ============================================================
signal card_dropped(card_data: CardData, zone_type: String)

# ============================================================
# 导出
# ============================================================
@export var zone_type: String = "field"
@export var accepted_card_types: Array[String] = []

# ============================================================
# 内部
# ============================================================
var _default_style: StyleBoxFlat
var _valid_style: StyleBoxFlat
var _invalid_style: StyleBoxFlat
var _disabled_style: StyleBoxFlat
var _current_state: String = "normal"
var _hint_label: Label


# ============================================================
# 初始化
# ============================================================
func _ready() -> void:
	_auto_fill_accepted_types()
	_build_styles()
	_create_hint_label()


func _auto_fill_accepted_types() -> void:
	if not accepted_card_types.is_empty():
		return
	match zone_type:
		"field":
			accepted_card_types = ["UNIT"]
		"spell":
			accepted_card_types = ["SPELL"]
		"trap":
			accepted_card_types = ["TRAP"]
		"graveyard":
			accepted_card_types = []  # 空 = 接受全部


func _build_styles() -> void:
	_default_style = StyleBoxFlat.new()
	_default_style.bg_color = Color(TC.BG_PANEL.r, TC.BG_PANEL.g, TC.BG_PANEL.b, 0.0)
	_default_style.border_width_left = 0
	_default_style.border_width_right = 0
	_default_style.border_width_top = 0
	_default_style.border_width_bottom = 0
	_default_style.border_color = Color(TC.BORDER_DEFAULT.r, TC.BORDER_DEFAULT.g, TC.BORDER_DEFAULT.b, 0.0)
	_default_style.set_corner_radius_all(4)

	_valid_style = StyleBoxFlat.new()
	_valid_style.bg_color = Color(0.08, 0.32, 0.14, 0.55)
	_valid_style.border_width_left = 2
	_valid_style.border_width_right = 2
	_valid_style.border_width_top = 2
	_valid_style.border_width_bottom = 2
	_valid_style.border_color = TC.SUCCESS
	_valid_style.set_corner_radius_all(4)

	_invalid_style = StyleBoxFlat.new()
	_invalid_style.bg_color = Color(0.32, 0.06, 0.06, 0.55)
	_invalid_style.border_width_left = 2
	_invalid_style.border_width_right = 2
	_invalid_style.border_width_top = 2
	_invalid_style.border_width_bottom = 2
	_invalid_style.border_color = TC.DANGER
	_invalid_style.set_corner_radius_all(4)

	_disabled_style = StyleBoxFlat.new()
	_disabled_style.bg_color = Color(TC.BG_DARK.r, TC.BG_DARK.g, TC.BG_DARK.b, 0.0)
	_disabled_style.border_width_left = 0
	_disabled_style.border_width_right = 0
	_disabled_style.border_width_top = 0
	_disabled_style.border_width_bottom = 0
	_disabled_style.border_color = Color(TC.BORDER_DEFAULT.r, TC.BORDER_DEFAULT.g, TC.BORDER_DEFAULT.b, 0.0)
	_disabled_style.set_corner_radius_all(4)

	add_theme_stylebox_override("panel", _default_style)


func _create_hint_label() -> void:
	_hint_label = Label.new()
	_hint_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hint_label.add_theme_font_size_override("font_size", 10)
	_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_label.visible = false
	add_child(_hint_label)


# ============================================================
# 4 种视觉状态
# ============================================================

func set_state(state: String) -> void:
	_current_state = state
	match state:
		"normal":
			add_theme_stylebox_override("panel", _default_style)
			_hint_label.visible = false
		"hover_valid":
			add_theme_stylebox_override("panel", _valid_style)
		"hover_invalid":
			add_theme_stylebox_override("panel", _invalid_style)
		"disabled":
			add_theme_stylebox_override("panel", _disabled_style)
			_hint_label.visible = false


# ============================================================
# 拖拽预览（全局高亮）
# ============================================================

## 根据卡牌类型预览可放/不可放
func preview_card(card: CardData) -> void:
	if card == null:
		clear_preview()
		return

	if accepts_card(card):
		set_state("hover_valid")
		_hint_label.text = _hint_text()
		_hint_label.add_theme_color_override("font_color", Color(0.2, 0.9, 0.3, 1))
	else:
		set_state("hover_invalid")
		_hint_label.text = "Cannot place"
		_hint_label.add_theme_color_override("font_color", Color(1, 0.25, 0.25, 1))
	_hint_label.visible = true


## 清除预览，回到 normal
func clear_preview() -> void:
	set_state("normal")


## 释放成功闪光：短暂亮色 → 恢复
func play_success_flash() -> void:
	var flash_style := StyleBoxFlat.new()
	flash_style.bg_color = Color(0.3, 0.7, 0.2, 0.7)
	flash_style.set_corner_radius_all(4)
	flash_style.border_width_left = 2
	flash_style.border_width_right = 2
	flash_style.border_width_top = 2
	flash_style.border_width_bottom = 2
	flash_style.border_color = Color(0.4, 1, 0.3, 1)
	add_theme_stylebox_override("panel", flash_style)
	var tween := create_tween()
	tween.tween_interval(0.15)
	tween.tween_callback(_reset_style)


# ============================================================
# 拖拽检测（Godot 内置拖拽系统回调）
# ============================================================

func _can_drop_data(_pos: Vector2, data) -> bool:
	if is_instance_valid(data) and data is CardUI:
		return _can_accept_card(data.card_data)
	return false


func _drop_data(_pos: Vector2, data) -> void:
	if is_instance_valid(data) and data is CardUI:
		data.on_drop_accepted(self)
		clear_preview()
	_reset_style()


# ============================================================
# 公开 API
# ============================================================

func accepts_card(card: CardData) -> bool:
	if card == null:
		return false
	match zone_type:
		"field":
			return card.is_front_row_card()
		"spell":
			return card.is_instant_card()
		"trap":
			return card.is_back_row_card()
		"graveyard":
			return true
	if accepted_card_types.is_empty():
		return true

	var type_str := ""
	match card.card_type:
		CardData.CardType.SPELL:
			type_str = "SPELL"
		CardData.CardType.UNIT:
			type_str = "UNIT"
		CardData.CardType.TRAP:
			type_str = "TRAP"

	return type_str in accepted_card_types


# ============================================================
# Hover 视觉反馈（内部）
# ============================================================

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_DRAG_BEGIN:
			pass
		NOTIFICATION_DRAG_END:
			_reset_style()


func _can_accept_card(card: CardData) -> bool:
	if card == null:
		return false

	var ok := accepts_card(card)
	if ok:
		_apply_style(_valid_style)
		return true

	_apply_style(_invalid_style)
	return false


func _apply_style(style: StyleBoxFlat) -> void:
	add_theme_stylebox_override("panel", style)


func _reset_style() -> void:
	if _current_state == "normal":
		add_theme_stylebox_override("panel", _default_style)


func _hint_text() -> String:
	match zone_type:
		"field":
			return "Summon"
		"spell":
			return "Cast"
		"trap":
			return "Set Trap"
		"graveyard":
			return "Discard"
	return ""
