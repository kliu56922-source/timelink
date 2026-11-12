extends Panel
class_name GraveyardView

## GraveyardView — 墓地卡牌列表弹窗
## 点击 GY 区域时弹出，显示最近 8 张墓地卡牌
## hover 卡牌条目 → 左侧详情面板显示完整信息
## 点击条目 → pin 到详情面板

const TC = preload("res://core/theme/theme_colors.gd")
const MAX_DISPLAY := 8

signal card_hovered(card: CardData)
signal card_selected(card: CardData)
signal close_requested()

var _scroll: ScrollContainer = null
var _vbox: VBoxContainer = null
var _title_label: Label = null
var _close_btn: Button = null
var _entries: Array[Control] = []
var _gy_data: Array = []
var _selected_idx: int = -1
var _is_boss: bool = false


func _ready() -> void:
	_build_ui()
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP


func _build_ui() -> void:
	# 暗色半透明底
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.10, 0.94)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.25, 0.25, 0.40, 1)
	style.set_corner_radius_all(6)
	add_theme_stylebox_override("panel", style)

	# 最外层 VBox
	var outer := VBoxContainer.new()
	outer.name = "GYOuter"
	outer.set_anchors_preset(Control.PRESET_FULL_RECT)
	outer.add_theme_constant_override("separation", 2)
	add_child(outer)

	# ── 标题栏 ──
	var title_bar := HBoxContainer.new()
	title_bar.name = "TitleBar"
	title_bar.add_theme_constant_override("separation", 4)

	_title_label = Label.new()
	_title_label.name = "GYTitle"
	_title_label.text = "Graveyard"
	_title_label.add_theme_font_size_override("font_size", 12)
	_title_label.add_theme_color_override("font_color", TC.TEXT_PRIMARY)
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_bar.add_child(_title_label)

	_close_btn = Button.new()
	_close_btn.name = "GYCloseBtn"
	_close_btn.text = "✕"
	_close_btn.add_theme_font_size_override("font_size", 11)
	_close_btn.custom_minimum_size = Vector2(20, 20)
	_close_btn.flat = true
	_close_btn.pressed.connect(_on_close)
	title_bar.add_child(_close_btn)

	outer.add_child(title_bar)

	# ── 分隔线 ──
	var sep := HSeparator.new()
	sep.name = "GYSep"
	outer.add_child(sep)

	# ── 滚动列表 ──
	_scroll = ScrollContainer.new()
	_scroll.name = "GYScroll"
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	_vbox = VBoxContainer.new()
	_vbox.name = "GYList"
	_vbox.add_theme_constant_override("separation", 2)
	_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_vbox)

	outer.add_child(_scroll)

	# ── 空提示 ──
	var empty_label := Label.new()
	empty_label.name = "GYEmptyLabel"
	empty_label.text = "墓地为空"
	empty_label.add_theme_font_size_override("font_size", 10)
	empty_label.add_theme_color_override("font_color", TC.TEXT_DIM)
	empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_label.visible = true
	_vbox.add_child(empty_label)


## 显示墓地列表（is_boss: true=Boss, false=Player）
func show_gy(cards: Array, is_boss: bool = false) -> void:
	_gy_data = cards.duplicate()
	_is_boss = is_boss
	_selected_idx = -1

	var owner_name := "Boss" if is_boss else "Player"
	_title_label.text = "%s Graveyard (%d)" % [owner_name, _gy_data.size()]

	# 清空旧条目
	for entry in _entries:
		if is_instance_valid(entry):
			entry.queue_free()
	_entries.clear()

	# 取最近 MAX_DISPLAY 张（倒序：最新的在上）
	var recent := _gy_data.slice(maxi(0, _gy_data.size() - MAX_DISPLAY), _gy_data.size())
	recent.reverse()

	# 隐藏/显示空提示
	var empty_label := _vbox.get_node_or_null(NodePath("GYEmptyLabel"))
	if empty_label:
		empty_label.visible = recent.is_empty()

	for i in range(recent.size()):
		var card: CardData = recent[i]
		var is_newest := (i == 0)  # Phase 8C: 第一行标记 NEW
		var entry := _create_entry(card, i, is_newest)
		_vbox.add_child(entry)
		_entries.append(entry)

	visible = true
	z_index = 300


func hide_gy() -> void:
	visible = false
	for entry in _entries:
		if is_instance_valid(entry):
			entry.queue_free()
	_entries.clear()


func _on_close() -> void:
	hide_gy()
	close_requested.emit()


## 创建单行卡牌条目
func _create_entry(card: CardData, idx: int, is_newest: bool = false) -> Control:
	var entry := Panel.new()
	entry.name = "GYEntry_%d" % idx
	entry.custom_minimum_size = Vector2(0, 22)
	entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	entry.mouse_filter = Control.MOUSE_FILTER_STOP

	# 条目背景
	var entry_style := StyleBoxFlat.new()
	entry_style.bg_color = Color(0.12, 0.12, 0.22, 0.85) if is_newest else Color(0.08, 0.08, 0.14, 0.8)
	entry_style.set_corner_radius_all(3)
	entry_style.border_width_left = 1
	entry_style.border_width_right = 1
	entry_style.border_width_top = 1
	entry_style.border_width_bottom = 1
	entry_style.border_color = Color(0.5, 0.4, 0.2, 1) if is_newest else Color(0.2, 0.2, 0.35, 1)
	entry.add_theme_stylebox_override("panel", entry_style)

	# hover/click 信号
	entry.mouse_entered.connect(_on_entry_hovered.bind(idx))
	entry.gui_input.connect(_on_entry_input.bind(idx))

	# HBox: 类型色标 + 卡名 + 角色标签
	var hbox := HBoxContainer.new()
	hbox.name = "EntryHBox"
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 4)
	entry.add_child(hbox)

	# Phase 8C: NEW 标记 (最新条目)
	if is_newest:
		var new_tag := _make_tag("NEW", Color(1, 0.75, 0.2, 1), 7)
		hbox.add_child(new_tag)

	# 类型色标
	var dot := ColorRect.new()
	dot.name = "TypeDot"
	dot.custom_minimum_size = Vector2(8, 8)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dot.color = _type_dot_color(card)
	hbox.add_child(dot)

	# 卡名
	var name_lbl := Label.new()
	name_lbl.name = "CardName"
	name_lbl.text = card.get_display_name() if card.has_method("get_display_name") else card.card_name
	name_lbl.add_theme_font_size_override("font_size", 10)
	name_lbl.add_theme_color_override("font_color", TC.TEXT_PRIMARY)
	name_lbl.clip_text = true
	name_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(name_lbl)

	# 角色/类型标签
	var tag_text := ""
	var tag_color := Color.WHITE
	if card.boss_card_role != "":
		tag_text = "BOSS"
		tag_color = TC.ZONE_OVERDRIVE
	elif card.archetype_role >= 0:
		tag_text = _role_short(card.archetype_role)
		tag_color = TC.role_color(card.archetype_role)
	if tag_text != "":
		var tag := _make_tag(tag_text, tag_color, 8)
		hbox.add_child(tag)

	# SUPER 星标
	if card.rarity == CardData.CardRarity.SUPER:
		var star := _make_tag("★", TC.ACCENT_GOLD, 8)
		hbox.add_child(star)

	return entry


func _on_entry_hovered(idx: int) -> void:
	if idx >= 0 and idx < _entries.size():
		# 高亮当前条目
		for i in range(_entries.size()):
			var entry := _entries[i]
			if is_instance_valid(entry):
				var style := entry.get_theme_stylebox("panel")
				if style and style is StyleBoxFlat:
					var s := style.duplicate() as StyleBoxFlat
					if i == idx:
						s.bg_color = Color(0.15, 0.15, 0.32, 0.9)
						s.border_color = TC.ZONE_CALM
					else:
						s.bg_color = Color(0.08, 0.08, 0.14, 0.8)
						s.border_color = Color(0.2, 0.2, 0.35, 1)
					entry.add_theme_stylebox_override("panel", s)

		# 发出信号给详情面板
		var recent := _gy_data.slice(maxi(0, _gy_data.size() - MAX_DISPLAY), _gy_data.size())
		recent.reverse()
		if idx < recent.size():
			card_hovered.emit(recent[idx])


func _on_entry_input(event: InputEvent, idx: int) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_selected_idx = idx
			var recent := _gy_data.slice(maxi(0, _gy_data.size() - MAX_DISPLAY), _gy_data.size())
			recent.reverse()
			if idx < recent.size():
				card_selected.emit(recent[idx])
				_refresh_selection_highlight()


func _refresh_selection_highlight() -> void:
	for i in range(_entries.size()):
		var entry := _entries[i]
		if is_instance_valid(entry):
			var style := entry.get_theme_stylebox("panel")
			if style and style is StyleBoxFlat:
				var s := style.duplicate() as StyleBoxFlat
				if i == _selected_idx:
					s.bg_color = Color(0.12, 0.22, 0.40, 0.9)
					s.border_color = TC.ZONE_CALM
				else:
					s.bg_color = Color(0.08, 0.08, 0.14, 0.8)
					s.border_color = Color(0.2, 0.2, 0.35, 1)
				entry.add_theme_stylebox_override("panel", s)


func _make_tag(text: String, color: Color, font_sz: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_sz)
	l.add_theme_color_override("font_color", Color.WHITE)
	var tag_style := StyleBoxFlat.new()
	var bg := color
	bg.a = 0.35
	tag_style.bg_color = bg
	tag_style.set_corner_radius_all(2)
	tag_style.border_color = color
	tag_style.border_width_left = 1
	tag_style.border_width_right = 1
	tag_style.border_width_top = 1
	tag_style.border_width_bottom = 1
	l.add_theme_stylebox_override("normal", tag_style)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _type_dot_color(card: CardData) -> Color:
	if card.boss_card_role != "":
		return TC.ZONE_OVERDRIVE
	if card.has_method("get_family_tag") and card.get_family_tag() == "BUILD":
		return Color(0.90, 0.55, 0.22, 1)
	match card.card_type:
		CardData.CardType.SPELL: return TC.ZONE_CALM
		CardData.CardType.UNIT: return TC.ZONE_HEATED
		CardData.CardType.TRAP: return TC.ROLE_CONTROL
	return TC.TEXT_DIM


func _role_short(role: int) -> String:
	match role:
		CardData.ArchetypeRole.STARTER: return "ST"
		CardData.ArchetypeRole.EXTENDER: return "EX"
		CardData.ArchetypeRole.CONTROL: return "CT"
		CardData.ArchetypeRole.FINISHER: return "FN"
		CardData.ArchetypeRole.DEFENSE: return "DF"
	return ""
