extends Panel
class_name CardUI

## 统一卡牌显示模式 — Phase 4B-4
enum CardDisplayMode {
	HAND,            # 手牌：小尺寸、可交互、hover 放大
	PLAYER_FIELD,    # 玩家场上：更小、更亮、信息精简
	BOSS_FIELD,      # Boss 场上：暗红调、小尺寸
	DETAIL,          # 详情面板：最大、信息完整、最高层级
	FEED,            # ActionFeed / 临时展示：只读、最小
}

signal card_clicked(card_ui: CardUI)
signal card_dropped(card_ui: CardUI, drop_zone: DropZone)
signal drag_started(card_ui: CardUI)
signal drag_ended(card_ui: CardUI)
signal card_hovered(card_data: CardData)
signal card_unhovered()
signal card_selected(card_data: CardData)

## ── 统一色板 ──
const TC = preload("res://core/theme/theme_colors.gd")
const TableLayoutConfigClass = preload("res://core/config/table_layout_config.gd")
const CardVisualProfileClass = preload("res://ui/card_visual_profile.gd")
const MonsterSummonDragPreviewClass := preload("res://ui/monster_summon_drag_preview.gd")
const HAND_OVERLAY_PATH := NodePath("HandFrameOverlay")
const CARD_CAST_DRAG_INTENTS := [
	&"engineering_target",
	&"basic_unit_target",
	&"friendly_anchor_spell",
	&"tripwire_anchor",
	&"directed_spell",
	&"cast_lane",
	&"finisher_cast",
]
const BOARD_DRAG_LABELS := {
	&"engineering_target": "选择工程",
	&"basic_unit_target": "选择目标",
	&"monster_summon": "召唤中",
	&"structure_build": "建设中",
	&"friendly_anchor_spell": "引导中",
	&"tripwire_anchor": "布设中",
	&"directed_spell": "引导中",
	&"cast_lane": "施放中",
	&"finisher_cast": "终结准备",
}
const CARD_CAST_GLYPHS := {
	&"engineering_target": "◇◎",
	&"basic_unit_target": "◇◎",
	&"friendly_anchor_spell": "◇◎",
	&"tripwire_anchor": "⌁◈",
	&"directed_spell": "╱◆",
	&"cast_lane": "✦",
	&"finisher_cast": "✦◆",
}

# Phase 5C-3: 布局配置缓存
var _layout_cfg = null

func _get_layout_cfg():
	if _layout_cfg == null:
		_layout_cfg = TableLayoutConfigClass.new()
	return _layout_cfg

# ── Phase 4B-8: CardUI 专属 z_index（与 battle_scene ZI_* 对齐）──
const ZI_FIELD_CARD  := 30  # Phase 19C: 提高到 30，确保卡在槽位封板/状态标签上方
const ZI_HAND_BASE   := 10
const ZI_DETAIL      := 200

var card_data: CardData
var is_playable := true
var _is_compact := false
var _hand_mode := false
var _glow_tween: Tween = null
# Phase 12B-R: _showing_back / _card_back_panel removed — unused in current flow

# ===== 拖拽支持 =====
var _drag_start_position: Vector2
var _is_dragging := false
var _drop_succeeded := false
var _board_drop_accept_count := 0
var _accepted_drop_zone: DropZone = null
var _saved_z_index := 0
var _saved_modulate := Color(1, 1, 1, 1)
var _drag_preview_identifiable := false
var _display_mode: int = CardDisplayMode.HAND
var _entry_pulse_tween: Tween = null
var _saved_hover_z := 0
var _tabletop_pose_enabled := false
var _tabletop_base_scale := Vector2.ONE
var _tabletop_hover_scale := Vector2.ONE
var _tabletop_base_rotation := 0.0
var _summon_reserved := false
var _summon_reserved_previous_self_modulate := Color.WHITE
var _board_drag_intent: StringName = &"generic_drop"
var _contextual_board_drag_enabled := false
var _reservation_label_text := ""
var _hand_readability: Dictionary = {}


## 统一入口：设置显示模式并刷新视觉 — Phase 4B-4
func set_display_mode(mode: int) -> void:
	_display_mode = mode
	clear_tabletop_field_pose()
	match mode:
		CardDisplayMode.HAND:
			_apply_card_dimensions(Vector2(152, 192))
			z_index = ZI_HAND_BASE
			mouse_filter = Control.MOUSE_FILTER_STOP
			scale = Vector2(1.0, 1.0)
			modulate = Color(1, 1, 1, 1)
			_hand_mode = true
			_is_compact = true
		CardDisplayMode.PLAYER_FIELD:
			_apply_card_dimensions(Vector2(132, 96))
			z_index = ZI_FIELD_CARD
			mouse_filter = Control.MOUSE_FILTER_STOP
			scale = Vector2(1.0, 1.0)
			modulate = Color(1.05, 1.05, 1.05, 1)
			_hand_mode = false
			_is_compact = true
		CardDisplayMode.BOSS_FIELD:
			_apply_card_dimensions(Vector2(132, 96))
			z_index = ZI_FIELD_CARD
			mouse_filter = Control.MOUSE_FILTER_STOP
			scale = Vector2(1.0, 1.0)
			modulate = Color(1.1, 0.9, 0.9, 1)
			_hand_mode = false
			_is_compact = true
		CardDisplayMode.DETAIL:
			_apply_card_dimensions(Vector2(180, 240))
			z_index = ZI_DETAIL
			mouse_filter = Control.MOUSE_FILTER_STOP
			scale = Vector2(1.0, 1.0)
			modulate = Color(1, 1, 1, 1)
			_hand_mode = false
			_is_compact = false
		CardDisplayMode.FEED:
			_apply_card_dimensions(Vector2(100, 64))
			z_index = ZI_FIELD_CARD
			mouse_filter = Control.MOUSE_FILTER_IGNORE
			scale = Vector2(0.85, 0.85)
			modulate = Color(1, 1, 1, 0.9)
			_hand_mode = false
			_is_compact = true

	# Phase 23B: show/hide hand frame overlay per display mode
	var hand_overlay := get_node_or_null(HAND_OVERLAY_PATH) as Control
	if hand_overlay:
		hand_overlay.visible = mode == CardDisplayMode.HAND
	# Phase 23B-R: restore old VBoxContainer name label in non-HAND modes
	var old_name := get_node_or_null(NodePath("VBoxContainer/NameLabel")) as Label
	if old_name:
		old_name.visible = mode != CardDisplayMode.HAND
	# Phase 27I-R0-R2: 模式切换时按新模式重定位徽记（不重复创建）
	if card_data != null:
		_update_piece_badge()

## Phase 12B: 公开访问器，供 CardVFXController 判断当前显示模式
func get_display_mode() -> int:
	return _display_mode


## 根据当前 _display_mode 应用对应尺寸（供 _setup_common 调用）
func _apply_display_size() -> void:
	match _display_mode:
		CardDisplayMode.HAND:
			_apply_card_dimensions(Vector2(152, 192))
		CardDisplayMode.PLAYER_FIELD, CardDisplayMode.BOSS_FIELD:
			_apply_card_dimensions(Vector2(132, 96))
		CardDisplayMode.DETAIL:
			_apply_card_dimensions(Vector2(180, 240))
		CardDisplayMode.FEED:
			_apply_card_dimensions(Vector2(100, 64))


func _apply_card_dimensions(card_size: Vector2) -> void:
	custom_minimum_size = card_size
	# Field cards fill their slot via anchors; their parent owns the size.
	if anchor_left == anchor_right and anchor_top == anchor_bottom:
		set_deferred("size", card_size)


## ── 手牌模式：标准尺寸 + 交互 ──
func setup_hand(data: CardData) -> void:
	card_data = data
	set_display_mode(CardDisplayMode.HAND)
	_setup_common(data)
	mouse_entered.connect(_on_hover)
	mouse_exited.connect(_on_exit)
	gui_input.connect(_on_input)


## ── Boss 展示模式：只读+暗红调 ──
func setup_boss(data: CardData) -> void:
	card_data = data
	set_display_mode(CardDisplayMode.BOSS_FIELD)
	_setup_common(data)
	is_playable = false


## Boss intent / boss instant display compatibility entry.
func setup_boss_intent(data: CardData) -> void:
	card_data = data
	set_display_mode(CardDisplayMode.FEED)
	_setup_common(data)
	is_playable = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	modulate = Color(1.08, 0.9, 0.82, 1)


## ── 场上棋格模式 ──
func apply_board_mode(data: CardData, is_boss_side: bool) -> void:
	card_data = data
	set_display_mode(CardDisplayMode.BOSS_FIELD if is_boss_side else CardDisplayMode.PLAYER_FIELD)
	_setup_common(data)
	is_playable = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_field_children_mouse_passthrough()
	if not gui_input.is_connected(_on_input):
		gui_input.connect(_on_input)


func set_field_children_mouse_passthrough() -> void:
	_set_children_mouse_filter_ignore(self)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _set_children_mouse_filter_ignore(node: Node) -> void:
	for child in node.get_children():
		if child is Control:
			var control_child := child as Control
			control_child.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_set_children_mouse_filter_ignore(child)


func apply_tabletop_field_pose(owner_side: String = "player", zone: String = "front") -> void:
	if _display_mode != CardDisplayMode.PLAYER_FIELD and _display_mode != CardDisplayMode.BOSS_FIELD:
		return
	_tabletop_pose_enabled = true
	var is_boss := owner_side == "boss" or _display_mode == CardDisplayMode.BOSS_FIELD
	# Phase 20A: 差异化透视 — 前场更强压缩（贴近桌面），后场较轻（半直立）
	if is_boss:
		if zone == "front":
			_tabletop_base_scale = Vector2(0.96, 0.72)   # Boss 前场：强压扁
			_tabletop_base_rotation = 3.2                  # 微右上倾
		else:
			_tabletop_base_scale = Vector2(0.96, 0.80)   # Boss 后场：轻度压缩
			_tabletop_base_rotation = 1.8
	else:
		if zone == "front":
			_tabletop_base_scale = Vector2(0.96, 0.74)   # 玩家前场：强压扁
			_tabletop_base_rotation = -3.0                 # 微左下倾
		else:
			_tabletop_base_scale = Vector2(0.96, 0.82)   # 玩家后场：轻度压缩
			_tabletop_base_rotation = -1.5

	_tabletop_hover_scale = _tabletop_base_scale + Vector2(0.06, 0.08)
	call_deferred("_deferred_apply_tabletop_field_pose", is_boss, zone)


func clear_tabletop_field_pose() -> void:
	_tabletop_pose_enabled = false
	_tabletop_base_scale = Vector2.ONE
	_tabletop_hover_scale = Vector2.ONE
	_tabletop_base_rotation = 0.0
	rotation_degrees = 0.0
	scale = Vector2.ONE
	_remove_named_child("TabletopShadow")
	_remove_named_child("TabletopSheen")


func get_tabletop_rest_scale() -> Vector2:
	return _tabletop_base_scale if _tabletop_pose_enabled else Vector2.ONE


func _deferred_apply_tabletop_field_pose(is_boss: bool, zone: String = "front") -> void:
	if not is_instance_valid(self):
		return
	pivot_offset = size * 0.5
	scale = _tabletop_base_scale
	rotation_degrees = _tabletop_base_rotation
	_ensure_tabletop_shadow(is_boss, zone)
	_ensure_tabletop_sheen(is_boss, zone)


func _ensure_tabletop_shadow(is_boss: bool, zone: String = "front") -> void:
	_remove_named_child("TabletopShadow")
	var shadow := ColorRect.new()
	shadow.name = "TabletopShadow"
	# Phase 20A: 前场卡阴影更深更大，模拟"贴在桌面"
	var alpha := 0.12
	var grow := 2
	if zone == "front":
		alpha = 0.22 if is_boss else 0.18
		grow = 4
	shadow.color = Color(0, 0, 0, alpha)
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shadow.z_index = -1
	shadow.set_anchors_preset(Control.PRESET_FULL_RECT)
	shadow.offset_left = grow
	shadow.offset_top = 6 if zone == "front" else 4
	shadow.offset_right = -grow
	shadow.offset_bottom = -1
	add_child(shadow)


func _ensure_tabletop_sheen(is_boss: bool, zone: String = "front") -> void:
	_remove_named_child("TabletopSheen")
	var sheen := ColorRect.new()
	sheen.name = "TabletopSheen"
	# Phase 20A: 顶部微光模拟卡面反射
	var alpha := 0.06
	if zone == "front":
		alpha = 0.10
	sheen.color = Color(1.0, 0.42, 0.12, alpha) if is_boss else Color(0.28, 0.9, 1.0, alpha)
	sheen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sheen.z_index = 30
	sheen.custom_minimum_size = Vector2(0, 3)
	sheen.set_anchors_preset(Control.PRESET_TOP_WIDE)
	sheen.offset_top = 2
	sheen.offset_bottom = 5
	sheen.offset_left = 8
	sheen.offset_right = -8
	add_child(sheen)


## 通用初始化入口（被 boss_reaction_fx / deck_builder / collection 调用）
func setup(data: CardData, compact: bool = false) -> void:
	card_data = data
	if data != null:
		# 根据调用上下文选择模式：compact → FEED / 否则使用当前模式
		if compact:
			set_display_mode(CardDisplayMode.FEED)
		else:
			set_display_mode(CardDisplayMode.HAND)
		_setup_common(data)


func dim_if_unplayable() -> void:
	stop_glow()
	set_unplayable()


func set_playable() -> void:
	is_playable = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	modulate = Color(1, 1, 1, 1)


# Phase 23B-R: color constants for playable/unplayable states
const UNPLAYABLE_MODULATE := Color(0.55, 0.55, 0.55, 1)
const UNPLAYABLE_HOVER_MODULATE := Color(0.70, 0.70, 0.70, 1)
const PLAYABLE_MODULATE := Color(1.0, 1.0, 1.0, 1)
const PLAYABLE_HOVER_MODULATE := Color(1.2, 1.2, 1.2, 1)

func set_unplayable() -> void:
	is_playable = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	modulate = UNPLAYABLE_MODULATE


## ── 字段颜色映射 ──
func _family_color(data: CardData) -> Color:
	match data.card_family:
		"monster":  return Color(1.2, 0.55, 0.2, 1)
		"building": return Color(0.9, 0.55, 0.22, 1)
		"spell":    return Color(0.25, 0.55, 0.95, 1)
		"counter":  return Color(0.2, 0.85, 0.6, 1)
		_:          return Color(0.6, 0.6, 0.7, 1)


func _family_bg(data: CardData) -> Color:
	match data.card_family:
		"monster":  return Color(0.08, 0.04, 0.02, 1)
		"building": return Color(0.06, 0.04, 0.01, 1)
		"spell":    return Color(0.02, 0.04, 0.1, 1)
		"counter":  return Color(0.02, 0.1, 0.06, 1)
		_:          return Color(0.05, 0.05, 0.08, 1)


## ── 卡面主构建 ──
## Phase 21-Final: apply color-coded card frame based on card_family
func _apply_card_frame(data: CardData) -> void:
	var accent := _family_color(data)
	var border_color := accent
	var frame := StyleBoxFlat.new()
	frame.bg_color = accent.darkened(0.45)
	frame.border_width_left = 10
	frame.border_width_right = 2
	frame.border_width_top = 12
	frame.border_width_bottom = 2
	frame.border_color = accent.lightened(0.18)
	frame.shadow_size = 7
	frame.shadow_color = Color(accent.r, accent.g, accent.b, 0.42)
	frame.set_corner_radius_all(8)
	add_theme_stylebox_override("panel", frame)
	var type_frame := get_node_or_null("TypeFrame") as Panel
	if type_frame == null:
		type_frame = Panel.new()
		type_frame.name = "TypeFrame"
		type_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		type_frame.z_index = 60
		add_child(type_frame)
	type_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var tsb := StyleBoxFlat.new()
	tsb.draw_center = false
	tsb.bg_color = Color(0, 0, 0, 0)
	tsb.border_color = accent.lightened(0.25)
	tsb.border_width_left = 4
	tsb.border_width_right = 4
	tsb.border_width_top = 7
	tsb.border_width_bottom = 4
	tsb.set_corner_radius_all(8)
	type_frame.add_theme_stylebox_override("panel", tsb)
	_remove_named_child("FamilyAccent")
	var top_accent := ColorRect.new()
	top_accent.name = "FamilyAccent"
	top_accent.color = accent
	top_accent.custom_minimum_size = Vector2(0, 4)
	top_accent.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top_accent.offset_bottom = 4.0
	top_accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_accent.visible = true
	add_child(top_accent)

func _setup_common(data: CardData) -> void:
	if not data:
		return
	# 清除旧子节点（除了 VBoxContainer 结构体）
	var vbox := get_node_or_null(NodePath("VBoxContainer"))
	if vbox:
		vbox.offset_left = 13.0
		vbox.offset_top = 14.0
		vbox.offset_right = -8.0
		vbox.offset_bottom = -6.0
	if not vbox:
		vbox = VBoxContainer.new()
		vbox.name = "VBoxContainer"
		vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
		vbox.add_theme_constant_override("separation", 2)
		add_child(vbox)
	else:
		# 保留结构，仅清除动态内容
		for child in vbox.get_children():
			if child.name in ["ArtPlaceholder", "NameLabel", "CostRow", "TypeLabel"]:
				pass  # 保留框架
			else:
				child.queue_free()

	# 名称标签
	var name_label := vbox.get_node_or_null("NameLabel") as Label
	if not name_label:
		name_label = Label.new()
		name_label.name = "NameLabel"
		vbox.add_child(name_label)
	name_label.text = data.card_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 9 if _is_compact else 11)
	name_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	# Phase 23B-R: hide old VBoxContainer name in HAND (overlay NameLabel is authoritative)
	name_label.visible = _display_mode != CardDisplayMode.HAND

	# Phase 27I-R0: 紧凑棋子徽记（仅 P01–P05 显示；不产生世界空间大字）
	_update_piece_badge()

	# ── 费用行 ──
	if not _is_compact or _display_mode == CardDisplayMode.DETAIL:
		var cost_row := vbox.get_node_or_null("CostRow") as HBoxContainer
		if not cost_row:
			cost_row = HBoxContainer.new()
			cost_row.name = "CostRow"
			cost_row.alignment = BoxContainer.ALIGNMENT_CENTER
			vbox.add_child(cost_row)
		else:
			for c in cost_row.get_children():
				c.queue_free()
		# OD/Load 标签
		var cost_text := "OD:%d Load:%d" % [data.od_cost, data.load_cost]
		var cost_label := Label.new()
		cost_label.text = cost_text
		cost_label.add_theme_font_size_override("font_size", 8)
		cost_label.add_theme_color_override("font_color", Color(0.6, 0.8, 1, 1))
		cost_row.add_child(cost_label)

	# 卡图
	_add_card_art(data)
	# Phase 21-Final: color-coded card frame
	_apply_card_frame(data)
	# Phase 23B: semantic hand frame overlay
	_refresh_hand_frame(data)

	# ── 场上 MONSTER ATK/DEF 标签 ──
	if (_display_mode == CardDisplayMode.PLAYER_FIELD or _display_mode == CardDisplayMode.BOSS_FIELD) and data.card_family == "monster":
		_add_monster_field_tags(data)

	# ── 场上 FINISHER 金色底光 ──
	if (_display_mode == CardDisplayMode.PLAYER_FIELD or _display_mode == CardDisplayMode.BOSS_FIELD) and data.rarity == CardData.CardRarity.SUPER:
		_add_finisher_field_glow()


# ============================================================
# 卡图填充
# ============================================================

func _add_card_art(data: CardData) -> void:
	var art_panel := get_node_or_null(NodePath("VBoxContainer/ArtPlaceholder")) as Panel
	if not art_panel:
		_add_card_art_legacy(data)
		return

	for child in art_panel.get_children():
		if is_instance_valid(child):
			art_panel.remove_child(child)
			child.queue_free()

	var real_tex: Texture2D = data.get_art_texture_for_mode(_display_mode)
	if real_tex != null:
		var is_field := _display_mode == CardDisplayMode.PLAYER_FIELD or _display_mode == CardDisplayMode.BOSS_FIELD
		var _style := StyleBoxFlat.new()
		_style.bg_color = Color(0.04, 0.04, 0.06, 1)
		_style.set_corner_radius_all(4)
		art_panel.add_theme_stylebox_override("panel", _style)

		if is_field and data.card_family == "building":
			var glow_bar := ColorRect.new()
			glow_bar.name = "BuildGlow"
			glow_bar.color = Color(0.85, 0.55, 0.15, 0.35)
			glow_bar.custom_minimum_size = Vector2(0, 3)
			glow_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
			glow_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
			art_panel.add_child(glow_bar)

			var top_glow := ColorRect.new()
			top_glow.name = "BuildTopGlow"
			top_glow.color = Color(0.35, 0.55, 0.85, 0.25)
			top_glow.custom_minimum_size = Vector2(0, 2)
			top_glow.set_anchors_preset(Control.PRESET_TOP_WIDE)
			top_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
			art_panel.add_child(top_glow)

		var tex_rect := TextureRect.new()
		tex_rect.name = "RealCardArt"
		tex_rect.texture = real_tex
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

		if is_field and data.card_family == "counter":
			tex_rect.modulate = Color(0.65, 0.7, 0.72, 1)

		art_panel.add_child(tex_rect)

		var art_h: int
		if is_field and data.card_family == "monster":
			art_h = 62
		elif is_field and data.card_family == "counter":
			art_h = 48
		else:
			art_h = 72 if _hand_mode else (56 if _is_compact else 80)
		art_panel.custom_minimum_size = Vector2(0, art_h)
		art_panel.visible = true
		return

	# Fallback: 程序化占位
	var art_color: Color = _family_color(data)
	var art_bg: Color = _family_bg(data)

	if data.boss_card_role != "":
		art_color = Color(0.9, 0.15, 0.05, 1)
		art_bg = Color(0.16, 0.03, 0.02, 1)

	if data.rarity == CardData.CardRarity.SUPER:
		art_color = TC.ACCENT_GOLD
		art_bg = Color(0.14, 0.09, 0.02, 0.95)

	var art_style := StyleBoxFlat.new()
	art_style.bg_color = art_bg
	art_style.set_corner_radius_all(4)
	art_style.border_width_left = 2
	art_style.border_width_right = 2
	art_style.border_width_top = 2
	art_style.border_width_bottom = 2
	art_style.border_color = art_color.lightened(0.3)
	art_panel.add_theme_stylebox_override("panel", art_style)

	_add_art_decoration(art_panel, data, art_color)

	var art_h2: int = 72 if _hand_mode else (56 if _is_compact else 80)
	art_panel.custom_minimum_size = Vector2(0, art_h2)
	art_panel.visible = true


func _add_card_art_legacy(data: CardData) -> void:
	_remove_named_child("CardArt")
	var vbox := get_node_or_null(NodePath("VBoxContainer"))
	if vbox:
		vbox.offset_left = 13.0
		vbox.offset_top = 14.0
		vbox.offset_right = -8.0
		vbox.offset_bottom = -6.0
	if not vbox:
		return
	var art_height: int = 72 if _hand_mode else 56
	var art_panel := Panel.new()
	art_panel.name = "ArtPlaceholder"
	art_panel.custom_minimum_size = Vector2(0, art_height)
	art_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	art_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	art_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var art_color: Color = _family_color(data)
	var art_bg: Color = _family_bg(data)
	var art_style := StyleBoxFlat.new()
	art_style.bg_color = art_bg
	art_style.set_corner_radius_all(4)
	art_style.border_width_left = 2
	art_style.border_width_right = 2
	art_style.border_width_top = 2
	art_style.border_width_bottom = 2
	art_style.border_color = art_color.lightened(0.3)
	art_panel.add_theme_stylebox_override("panel", art_style)
	_add_art_decoration(art_panel, data, art_color)
	vbox.add_child(art_panel)
	var name_idx := vbox.get_children().find(art_panel)
	if name_idx > 1:
		vbox.move_child(art_panel, 1)


## Phase 27I-R0-R2: 紧凑棋子徽记（手牌/详情固定定位；未实装卡不显示）。
## 不再追加到 VBoxContainer 尾部（会被 HandFrameOverlay 覆盖/裁剪）。
## HAND：HandFrameOverlay/PieceBadgePanel；DETAIL：卡根节点 PieceBadgePanel。
func _update_piece_badge() -> void:
	_remove_piece_badge()
	if card_data == null or not card_data.piece_enabled:
		return
	var badge_name := _piece_badge_name(card_data.piece_type)
	if badge_name == "":
		return
	var panel := _ensure_piece_badge_panel()
	if panel == null:
		return
	panel.visible = true
	var label := panel.get_node_or_null("PieceBadgeLabel") as Label
	if not label:
		label = Label.new()
		label.name = "PieceBadgeLabel"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 9)
		label.add_theme_color_override("font_color", Color(0.95, 0.9, 0.45, 1))
		label.set_anchors_preset(Control.PRESET_FULL_RECT)
		panel.add_child(label)
	label.text = badge_name


## Phase 27I-R0-R2: 按当前显示模式返回徽记底板（无棋型时返回 null）
func _ensure_piece_badge_panel() -> Control:
	if _display_mode == CardDisplayMode.HAND:
		var overlay := _ensure_hand_frame_overlay()
		var panel := overlay.get_node_or_null("PieceBadgePanel") as Panel
		if not panel:
			panel = Panel.new()
			panel.name = "PieceBadgePanel"
			# 卡图下部、TypePlate 上方（HAND 卡 152×192，TypePlate offset_top=-33）
			panel.anchor_left = 0.5
			panel.anchor_right = 0.5
			panel.anchor_top = 1.0
			panel.anchor_bottom = 1.0
			panel.offset_left = -24.0
			panel.offset_right = 24.0
			panel.offset_top = -42.0
			panel.offset_bottom = -30.0
			panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
			panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.03, 0.03, 0.06, 0.82), Color(0.80, 0.68, 0.25, 0.9), 1))
			overlay.add_child(panel)
		return panel
	if _display_mode == CardDisplayMode.DETAIL:
		var panel := get_node_or_null("PieceBadgePanel") as Panel
		if not panel:
			panel = Panel.new()
			panel.name = "PieceBadgePanel"
			# DETAIL 卡 180×240：卡图下部独立固定位置
			panel.anchor_left = 0.5
			panel.anchor_right = 0.5
			panel.anchor_top = 1.0
			panel.anchor_bottom = 1.0
			panel.offset_left = -28.0
			panel.offset_right = 28.0
			panel.offset_top = -56.0
			panel.offset_bottom = -40.0
			panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
			panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.03, 0.03, 0.06, 0.82), Color(0.80, 0.68, 0.25, 0.9), 1))
			add_child(panel)
		return panel
	return null


func _remove_piece_badge() -> void:
	# 立即 remove_child（而非仅 queue_free），避免同帧二次调用复用已排队待释放的旧节点
	var overlay := get_node_or_null(HAND_OVERLAY_PATH) as Control
	if overlay:
		var panel := overlay.get_node_or_null("PieceBadgePanel") as Panel
		if panel:
			overlay.remove_child(panel)
			panel.queue_free()
	var detail_panel := get_node_or_null("PieceBadgePanel") as Panel
	if detail_panel:
		remove_child(detail_panel)
		detail_panel.queue_free()


## 棋子中文名（数据驱动，不计算任何合法性/费用）
func _piece_badge_name(piece_type: StringName) -> String:
	match piece_type:
		StringName("pawn"): return "兵卒"
		StringName("knight"): return "骑士"
		StringName("bishop"): return "主教"
		StringName("rook"): return "战车"
		StringName("queen"): return "皇后"
	return ""


func _add_art_decoration(parent: Panel, data: CardData, base_color: Color) -> void:
	match data.card_family:
		"monster":  _add_monster_art(parent, base_color, hash(data.card_name) % 20)
		"spell":    _add_spell_art(parent, base_color, hash(data.card_name) % 20)
		"counter":  _add_counter_art(parent, base_color, hash(data.card_name) % 20)
		"building": _add_building_art(parent, base_color, hash(data.card_name) % 20)
		_:          _add_default_art(parent, base_color, hash(data.card_name) % 20)
	if data.rarity == CardData.CardRarity.SUPER:
		_add_finisher_art(parent, base_color, hash(data.card_name) % 20)


func _add_monster_art(parent: Panel, base_color: Color, seed: int) -> void:
	var shape_idx := seed % 4
	var rect := ColorRect.new()
	rect.name = "ArtShape"
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.color = Color(base_color.r, base_color.g, base_color.b, 0.2)
	parent.add_child(rect)
	# 怪兽轮廓 — 锯齿/斜块
	var decor := ColorRect.new()
	decor.name = "ArtDecor"
	decor.color = Color(base_color.r * 0.6, base_color.g * 0.3, base_color.b * 0.15, 0.4)
	match shape_idx:
		0: decor.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE, Control.PRESET_MODE_MINSIZE, 8)
		1: decor.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE, Control.PRESET_MODE_MINSIZE, 8)
		2: decor.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE, Control.PRESET_MODE_MINSIZE, 8)
		_: decor.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE, Control.PRESET_MODE_MINSIZE, 8)
	decor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(decor)


func _add_spell_art(parent: Panel, base_color: Color, seed: int) -> void:
	var shape_idx := seed % 4
	var rect := ColorRect.new()
	rect.name = "ArtShape"
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.color = Color(base_color.r * 0.15, base_color.g * 0.25, base_color.b * 0.5, 0.25)
	parent.add_child(rect)
	# 波纹圆环
	var circle := ColorRect.new()
	circle.name = "ArtDecor"
	var sz := 20 + (seed % 3) * 8
	match shape_idx:
		0: circle.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE, sz)
		1: circle.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, sz)
		2: circle.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, sz)
		_: circle.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT, Control.PRESET_MODE_MINSIZE, sz)
	circle.color = Color(base_color.r, base_color.g, base_color.b, 0.35)
	circle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(circle)


func _add_counter_art(parent: Panel, base_color: Color, seed: int) -> void:
	var rect := ColorRect.new()
	rect.name = "ArtShape"
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.color = Color(0.02, 0.08, 0.05, 0.3)
	parent.add_child(rect)
	# 交叉线（反制标记）
	var cross := ColorRect.new()
	cross.name = "ArtDecor"
	cross.set_anchors_preset(Control.PRESET_FULL_RECT)
	cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cross.color = Color(base_color.r * 0.3, base_color.g * 0.6, base_color.b * 0.4, 0.25)
	parent.add_child(cross)


func _add_building_art(parent: Panel, base_color: Color, seed: int) -> void:
	var shape_idx := seed % 4
	var rect := ColorRect.new()
	rect.name = "ArtShape"
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.color = Color(0.08, 0.05, 0.02, 0.3)
	parent.add_child(rect)
	# 建筑方块
	var block := ColorRect.new()
	block.name = "ArtDecor"
	var bw := 16 + (seed % 3) * 6
	var bh := 12 + (seed % 3) * 4
	match shape_idx:
		0: block.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		1: block.set_anchors_preset(Control.PRESET_CENTER_TOP)
		2: block.set_anchors_preset(Control.PRESET_LEFT_WIDE)
		_: block.set_anchors_preset(Control.PRESET_CENTER)
	block.custom_minimum_size = Vector2(bw, bh)
	block.color = Color(base_color.r * 0.6, base_color.g * 0.35, base_color.b * 0.1, 0.45)
	block.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(block)


func _add_finisher_art(parent: Panel, base_color: Color, seed: int) -> void:
	var rect := ColorRect.new()
	rect.name = "FinisherOverlay"
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.color = Color(1, 0.75, 0.2, 0.12)
	parent.add_child(rect)


func _add_default_art(parent: Panel, base_color: Color, seed: int) -> void:
	var rect := ColorRect.new()
	rect.name = "ArtShape"
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.color = Color(base_color.r, base_color.g, base_color.b, 0.12)
	parent.add_child(rect)


func _remove_named_child(node_name: String) -> void:
	var node := get_node_or_null(NodePath(node_name))
	if node != null and is_instance_valid(node):
		node.queue_free()


# ── Phase 23B: Hand frame overlay helpers ──

func _make_overlay_label(node_name: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.name = node_name
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label


func _make_panel_style(bg: Color, border: Color, radius: int = 5) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.set_corner_radius_all(radius)
	return style


func _make_card_style(accent: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = accent.darkened(0.45)
	style.border_color = accent.lightened(0.15)
	style.border_width_left = 10
	style.border_width_right = 2
	style.border_width_top = 12
	style.border_width_bottom = 2
	style.set_corner_radius_all(8)
	return style


func _ensure_hand_frame_overlay() -> Control:
	var existing := get_node_or_null(HAND_OVERLAY_PATH) as Control
	if existing:
		return existing

	var overlay := Control.new()
	overlay.name = "HandFrameOverlay"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.z_index = 40
	add_child(overlay)

	var rail := ColorRect.new()
	rail.name = "FamilyRail"
	rail.anchor_bottom = 1.0
	rail.offset_right = 9.0
	rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(rail)

	var top_line := ColorRect.new()
	top_line.name = "FamilyTopLine"
	top_line.anchor_right = 1.0
	top_line.offset_bottom = 4.0
	top_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(top_line)

	var od_socket := Panel.new()
	od_socket.name = "ODSocket"
	od_socket.position = Vector2(8, 6)
	od_socket.size = Vector2(28, 28)
	od_socket.mouse_filter = Control.MOUSE_FILTER_IGNORE
	od_socket.add_theme_stylebox_override("panel", _make_panel_style(Color(0.03, 0.06, 0.11, 0.96), Color("4b92ff"), 14))
	var od_value := _make_overlay_label("Value", 12, Color.WHITE)
	od_value.set_anchors_preset(Control.PRESET_FULL_RECT)
	od_socket.add_child(od_value)
	overlay.add_child(od_socket)

	var load_socket := Panel.new()
	load_socket.name = "LoadSocket"
	load_socket.anchor_left = 1.0
	load_socket.anchor_right = 1.0
	load_socket.offset_left = -42.0
	load_socket.offset_top = 7.0
	load_socket.offset_right = -7.0
	load_socket.offset_bottom = 29.0
	load_socket.mouse_filter = Control.MOUSE_FILTER_IGNORE
	load_socket.add_theme_stylebox_override("panel", _make_panel_style(Color(0.08, 0.045, 0.02, 0.96), Color("ed8a3f"), 5))
	var load_value := _make_overlay_label("Value", 10, Color("ffc08a"))
	load_value.set_anchors_preset(Control.PRESET_FULL_RECT)
	load_socket.add_child(load_value)
	overlay.add_child(load_socket)

	# Phase 23B-R: NameLabel between OD and Load sockets
	var name_label := _make_overlay_label("NameLabel", 9, Color.WHITE)
	name_label.anchor_right = 1.0
	name_label.offset_left = 38.0
	name_label.offset_top = 7.0
	name_label.offset_right = -44.0
	name_label.offset_bottom = 24.0
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	overlay.add_child(name_label)

	var type_plate := Panel.new()
	type_plate.name = "TypePlate"
	type_plate.anchor_top = 1.0
	type_plate.anchor_right = 1.0
	type_plate.anchor_bottom = 1.0
	type_plate.offset_left = 10.0
	type_plate.offset_top = -33.0
	type_plate.offset_right = -8.0
	type_plate.offset_bottom = -7.0
	type_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(type_plate)

	var family_label := _make_overlay_label("FamilyLabel", 9, Color.WHITE)
	family_label.anchor_right = 0.62
	family_label.anchor_bottom = 1.0
	family_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	family_label.offset_left = 8.0
	type_plate.add_child(family_label)

	var role_label := _make_overlay_label("RoleLabel", 8, Color("9ca9b8"))
	role_label.anchor_left = 0.55
	role_label.anchor_right = 1.0
	role_label.anchor_bottom = 1.0
	role_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	role_label.offset_right = -7.0
	type_plate.add_child(role_label)

	var finisher_badge := _make_overlay_label("FinisherBadge", 8, Color("fff0b1"))
	finisher_badge.text = "FINISHER"
	finisher_badge.anchor_left = 1.0
	finisher_badge.anchor_top = 1.0
	finisher_badge.anchor_right = 1.0
	finisher_badge.anchor_bottom = 1.0
	finisher_badge.offset_left = -74.0
	finisher_badge.offset_top = -51.0
	finisher_badge.offset_right = -5.0
	finisher_badge.offset_bottom = -36.0
	finisher_badge.rotation_degrees = -12.0
	finisher_badge.add_theme_color_override("font_color", Color("f6d56a"))
	finisher_badge.add_theme_stylebox_override("normal", _make_panel_style(Color(0.34, 0.07, 0.04, 0.94), Color(0.90, 0.68, 0.22, 1.0), 3))
	overlay.add_child(finisher_badge)

	return overlay


func _refresh_hand_frame(data: CardData) -> void:
	var overlay := _ensure_hand_frame_overlay()
	overlay.visible = _display_mode == CardDisplayMode.HAND
	if not overlay.visible or data == null:
		return

	var profile: Dictionary = CardVisualProfileClass.from_card(data)
	var accent: Color = profile["accent"]
	add_theme_stylebox_override("panel", _make_card_style(accent))
	var name_node := overlay.get_node_or_null("NameLabel") as Label
	if name_node != null:
		name_node.add_theme_color_override("font_color", Color(
			minf(accent.r + 0.35, 1.0), minf(accent.g + 0.35, 1.0),
			minf(accent.b + 0.35, 1.0), 1.0))
	(overlay.get_node("FamilyRail") as ColorRect).color = accent
	(overlay.get_node("FamilyTopLine") as ColorRect).color = Color(accent.r, accent.g, accent.b, 0.78)
	(overlay.get_node("NameLabel") as Label).text = data.get_display_name()
	(overlay.get_node("ODSocket/Value") as Label).text = str(data.od_cost)
	(overlay.get_node("LoadSocket/Value") as Label).text = "L%d" % data.load_cost

	var plate := overlay.get_node("TypePlate") as Panel
	plate.add_theme_stylebox_override("panel", _make_panel_style(Color(0.035, 0.05, 0.075, 0.94), Color(accent.r, accent.g, accent.b, 0.72), 4))
	var family_label := overlay.get_node("TypePlate/FamilyLabel") as Label
	family_label.text = profile["family_label"]
	family_label.add_theme_color_override("font_color", accent)
	(overlay.get_node("TypePlate/RoleLabel") as Label).text = profile["display_label"]
	(overlay.get_node("FinisherBadge") as Label).visible = profile["is_finisher"]
	if not _hand_readability.is_empty(): set_hand_readability(_hand_readability)


## Opt-in battle presentation. No card data, resources or input ownership changes.
func set_hand_readability(facts: Dictionary) -> void:
	_hand_readability=facts.duplicate(true)
	if facts.is_empty() or card_data==null or _display_mode!=CardDisplayMode.HAND: return
	var overlay := _ensure_hand_frame_overlay()
	var title: Label=overlay.get_node("NameLabel")
	title.anchor_right=1.0
	title.offset_left=8;title.offset_right=-8;title.offset_top=3;title.offset_bottom=25
	title.add_theme_font_size_override("font_size",12)
	title.add_theme_stylebox_override("normal",_make_panel_style(Color(0.02,0.04,0.07,0.95),Color.TRANSPARENT,3))
	var socket: Panel=overlay.get_node("ODSocket")
	socket.position=Vector2(8,28);socket.size=Vector2(88,24)
	var cost: Label=socket.get_node("Value")
	cost.text=str(facts.get("cost",""));cost.add_theme_font_size_override("font_size",10)
	var load_socket: Panel=overlay.get_node("LoadSocket")
	load_socket.offset_left=-54;load_socket.offset_right=-8;load_socket.offset_top=28;load_socket.offset_bottom=52
	(load_socket.get_node("Value") as Label).text="负荷%d" % card_data.load_cost
	var badge: Control=overlay.get_node_or_null("PieceBadgePanel")
	if badge!=null:
		badge.anchor_top=0;badge.anchor_bottom=0;badge.offset_top=78;badge.offset_bottom=91
	var panel: Panel=overlay.get_node_or_null("EffectPanel")
	if panel==null:
		panel=Panel.new();panel.name="EffectPanel";panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
		panel.anchor_right=1;panel.offset_left=8;panel.offset_right=-8;panel.offset_top=97;panel.offset_bottom=150
		panel.add_theme_stylebox_override("panel",_make_panel_style(Color(0.02,0.04,0.07,0.97),Color(0.3,0.45,0.6,0.65),3))
		overlay.add_child(panel)
		var effect := _make_overlay_label("EffectSummaryLabel",11,Color.WHITE)
		effect.anchor_right=1;effect.offset_left=4;effect.offset_right=-4;effect.offset_top=2;effect.offset_bottom=36
		effect.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;effect.max_lines_visible=2
		effect.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
		panel.add_child(effect)
		var hint := _make_overlay_label("ContextLabel",9,Color("79ffe1"))
		hint.anchor_right=1;hint.offset_left=4;hint.offset_right=-4;hint.offset_top=36;hint.offset_bottom=52
		hint.clip_text=true;hint.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
		panel.add_child(hint)
	(panel.get_node("EffectSummaryLabel") as Label).text=str(facts.get("summary",""))
	(panel.get_node("ContextLabel") as Label).text=str(facts.get("context",""))
	var family: Label=overlay.get_node("TypePlate/FamilyLabel")
	family.text={"monster":"棋子","spell":"魔法","building":"建筑","counter":"反制"}.get(card_data.card_family,"卡牌")
	var role: Label=overlay.get_node("TypePlate/RoleLabel")
	role.text="驻场" if card_data.is_building_card() else "盖伏" if card_data.is_back_row_card() else ""
	set_meta("hand_readability",_hand_readability)


func _passthrough_children(node: Node) -> void:
	for child in node.get_children():
		if is_instance_valid(child) and child is Control:
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_passthrough_children(child)


# ============================================================
# 交互
# ============================================================

func _on_hover() -> void:
	_saved_hover_z = z_index
	z_index = 80
	if card_data:
		card_hovered.emit(card_data)
	var tween = create_tween()
	tween.set_parallel(true)
	if _tabletop_pose_enabled:
		tween.tween_property(self, "scale", _tabletop_hover_scale, 0.12)
		tween.tween_property(self, "rotation_degrees", 0.0, 0.12)
	elif is_playable:
		tween.tween_property(self, "scale", Vector2(1.15, 1.15), 0.12)
	# Phase 23B-R: unplayable cards stay dim on hover, playable go bright
	var hover_target := UNPLAYABLE_HOVER_MODULATE if not is_playable else PLAYABLE_HOVER_MODULATE
	tween.tween_property(self, "modulate", hover_target, 0.1)


func _on_exit() -> void:
	z_index = _saved_hover_z
	var tween = create_tween()
	tween.set_parallel(true)
	var target_scale := _tabletop_base_scale if _tabletop_pose_enabled else Vector2(1.0, 1.0)
	var target_rotation := _tabletop_base_rotation if _tabletop_pose_enabled else 0.0
	tween.tween_property(self, "scale", target_scale, 0.12)
	tween.tween_property(self, "rotation_degrees", target_rotation, 0.12)
	# Phase 23B-R: restore correct modulate per playability
	var exit_target: Color
	if is_playable:
		exit_target = PLAYABLE_MODULATE
	elif _display_mode == CardDisplayMode.PLAYER_FIELD or _display_mode == CardDisplayMode.BOSS_FIELD:
		exit_target = _get_field_modulate()
	else:
		exit_target = UNPLAYABLE_MODULATE
	tween.tween_property(self, "modulate", exit_target, 0.1)
	card_unhovered.emit()


func _get_field_modulate() -> Color:
	match _display_mode:
		CardDisplayMode.PLAYER_FIELD: return Color(1.05, 1.05, 1.05, 1)
		CardDisplayMode.BOSS_FIELD: return Color(1.1, 0.9, 0.9, 1)
	return Color(1, 1, 1, 1)


func _on_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		# Phase 19C: unified debug log — always print raw input on any button press
		var label := card_data.get_display_name() if card_data and card_data.has_method("get_display_name") else (card_data.card_name if card_data else "?")
		print("[CARDUI_RAW_INPUT] card=%s mode=%d mouse_filter=%d event=%s" % [label, _display_mode, mouse_filter, event.as_text()])
		match event.button_index:
			MOUSE_BUTTON_RIGHT:
				if card_data:
					card_selected.emit(card_data)
			_:
				card_clicked.emit(self)


# ============================================================
# 拖拽支持
# ============================================================

func _get_drag_data(_pos: Vector2):
	if (not is_playable and not _contextual_board_drag_enabled) or card_data == null:
		return null
	_is_dragging = true
	_drop_succeeded = false
	_drag_start_position = global_position
	_saved_z_index = z_index
	_saved_modulate = modulate
	# Godot permits set_drag_preview only during a native GUI drag callback.
	# Focused behavior tests may call this method directly to inspect the exact
	# payload contract, so keep that pure probe free of an engine assertion.
	if get_viewport() != null and get_viewport().gui_is_dragging():
		var preview := create_identifiable_drag_preview()
		set_drag_preview(preview)
	scale = Vector2(1.1, 1.1)
	modulate = Color(1.2, 1.2, 1.2, 0.75)
	z_index = 100
	drag_started.emit(self)
	return self


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		_is_dragging = false
		scale = Vector2(1, 1)
		modulate = _saved_modulate
		z_index = _saved_z_index
		if not _drop_succeeded:
			_snap_back()
		_accepted_drop_zone = null
		drag_ended.emit(self)


func set_summon_reservation_visual(active: bool) -> void:
	set_board_reservation_visual(active, &"monster_summon")


func set_board_drag_context(intent: StringName, contextual_enabled: bool = false) -> void:
	_board_drag_intent = intent
	_contextual_board_drag_enabled = contextual_enabled


func get_board_drag_intent() -> StringName:
	return _board_drag_intent


func set_board_reservation_visual(active: bool, intent: StringName = &"monster_summon") -> void:
	if active == _summon_reserved:
		if active:
			_update_reservation_label(intent)
		return
	_summon_reserved = active
	if active:
		_summon_reserved_previous_self_modulate = self_modulate
		self_modulate = Color(0.45, 0.55, 0.58, 0.38)
		_update_reservation_label(intent)
		_ensure_summon_reserved_label().show()
	else:
		self_modulate = _summon_reserved_previous_self_modulate
		_reservation_label_text = ""
		var label := get_node_or_null(NodePath("SummonReservedLabel")) as Label
		if label != null:
			label.hide()


func _update_reservation_label(intent: StringName) -> void:
	_reservation_label_text = str(BOARD_DRAG_LABELS.get(intent, "召唤中"))
	_ensure_summon_reserved_label().text = _reservation_label_text


func _ensure_summon_reserved_label() -> Label:
	var existing := get_node_or_null(NodePath("SummonReservedLabel")) as Label
	if existing != null:
		return existing
	var label := Label.new()
	label.name = "SummonReservedLabel"
	label.text = "召唤中"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.anchor_left = 0.12
	label.anchor_top = 0.32
	label.anchor_right = 0.88
	label.anchor_bottom = 0.56
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color(0.74, 0.96, 1.0, 1.0))
	add_child(label)
	return label


func _snap_back() -> void:
	global_position = _drag_start_position


func on_drop_accepted(drop_zone: DropZone) -> void:
	_drop_succeeded = true
	_accepted_drop_zone = drop_zone
	card_dropped.emit(self, drop_zone)


## Exact-cell board drops have no generic DropZone object. BattleScene calls
## this only after the authoritative play_card result reports success.
func accept_board_drop() -> void:
	_drop_succeeded = true
	_accepted_drop_zone = null
	_board_drop_accept_count += 1


func create_identifiable_drag_preview() -> Control:
	if _board_drag_intent == &"structure_build":
		return create_structure_drag_preview()
	if _is_monster_drag_preview_card():
		var hologram_preview := MonsterSummonDragPreviewClass.new()
		hologram_preview.setup(card_data, false)
		_drag_preview_identifiable = card_data != null and not card_data.card_id.is_empty()
		return hologram_preview
	if _board_drag_intent in CARD_CAST_DRAG_INTENTS:
		return create_card_cast_drag_preview(_board_drag_intent)
	var preview := Panel.new()
	preview.name = "CardDragPreview"
	preview.custom_minimum_size = size
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.modulate = Color(1, 1, 1, 0.82)
	preview.scale = Vector2(1.1, 1.1)
	preview.set_meta("card_id", card_data.card_id if card_data != null else "")
	var source_art := get_real_card_art()
	if source_art != null and source_art.texture != null:
		var art := TextureRect.new()
		art.name = "DragArt"
		art.set_anchors_preset(Control.PRESET_FULL_RECT)
		art.texture = source_art.texture
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		preview.add_child(art)
	var label := Label.new()
	label.name = "DragIdentity"
	if card_data != null:
		label.text = card_data.get_display_name() if card_data.has_method("get_display_name") else card_data.card_name
	label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.add_child(label)
	_drag_preview_identifiable = not label.text.is_empty()
	return preview


func create_card_cast_drag_preview(intent: StringName) -> Control:
	var preview := PanelContainer.new()
	preview.name = "CardCastDragPreview"
	preview.custom_minimum_size = Vector2(86.0, 86.0)
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.modulate = Color(0.62, 0.96, 1.0, 0.9)
	preview.set_meta("card_id", card_data.card_id if card_data != null else "")
	preview.set_meta("board_drag_intent", intent)
	var stack := VBoxContainer.new()
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.add_child(stack)
	var glyph := Label.new()
	glyph.name = "IntentGlyph"
	glyph.text = str(CARD_CAST_GLYPHS.get(intent, "◇"))
	glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glyph.add_theme_font_size_override("font_size", 22)
	stack.add_child(glyph)
	var label := Label.new()
	label.name = "DragIdentity"
	label.text = card_data.get_display_name() if card_data != null and card_data.has_method("get_display_name") else "施放"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 11)
	stack.add_child(label)
	_drag_preview_identifiable = card_data != null and not card_data.card_id.is_empty()
	return preview


func create_structure_drag_preview() -> Control:
	var preview := PanelContainer.new()
	preview.name = "StructureBuildDragPreview"
	preview.custom_minimum_size = Vector2(86.0, 86.0)
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.modulate = Color(0.45, 0.95, 1.0, 0.88)
	preview.set_meta("card_id", card_data.card_id if card_data != null else "")
	preview.set_meta("board_drag_intent", &"structure_build")
	var stack := VBoxContainer.new()
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.add_child(stack)
	var glyph := Label.new()
	glyph.text = "◇\n▰"
	glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glyph.add_theme_font_size_override("font_size", 22)
	stack.add_child(glyph)
	var label := Label.new()
	label.text = card_data.get_display_name() if card_data != null and card_data.has_method("get_display_name") else "建设"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 11)
	stack.add_child(label)
	_drag_preview_identifiable = card_data != null and not card_data.card_id.is_empty()
	return preview


func _is_monster_drag_preview_card() -> bool:
	return card_data != null and (card_data.card_family == "monster" or card_data.card_type == CardData.CardType.UNIT)


func get_drag_debug_snapshot() -> Dictionary:
	var summon_label := get_node_or_null(NodePath("SummonReservedLabel")) as Label
	return {
		"dragging": _is_dragging,
		"drop_succeeded": _drop_succeeded,
		"board_drop_accept_count": _board_drop_accept_count,
		"card_id": card_data.card_id if card_data != null else "",
		"preview_identifiable": _drag_preview_identifiable,
		"summon_reserved": _summon_reserved,
		"self_alpha": self_modulate.a,
		"summon_label_visible": summon_label != null and summon_label.visible,
		"board_drag_intent": _board_drag_intent,
		"contextual_board_drag_enabled": _contextual_board_drag_enabled,
		"reservation_label": _reservation_label_text,
		"reservation_label_visible": summon_label != null and summon_label.visible,
	}


# ============================================================
# 动画
# ============================================================

func play_card_animation(target_pos: Vector2, speed := 1.0) -> void:
	if not is_instance_valid(self):
		return
	var tween = create_tween()
	tween.set_speed_scale(speed)
	tween.tween_property(self, "scale", Vector2(1.3, 1.3), 0.1)
	tween.tween_property(self, "global_position", target_pos, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(self, "position:x", position.x + 6, 0.05)
	tween.tween_property(self, "position:x", position.x - 6, 0.05)
	tween.tween_property(self, "position:x", position.x, 0.05)
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	await tween.finished
	if is_instance_valid(self):
		queue_free()


func play_hit_effect(strength := 5.0) -> void:
	var tween = create_tween()
	tween.tween_property(self, "position:x", position.x + strength, 0.05)
	tween.tween_property(self, "position:x", position.x - strength, 0.05)
	tween.tween_property(self, "position:x", position.x, 0.05)


func play_fly_to_graveyard(target_pos: Vector2) -> void:
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.15, 1.15), 0.1)
	tween.tween_property(self, "global_position", target_pos, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "modulate:a", 0.0, 0.15)
	await tween.finished
	if is_instance_valid(self):
		queue_free()


func play_destroy_sequence() -> void:
	var tween = create_tween()
	tween.tween_property(self, "position:x", position.x - 8, 0.04)
	tween.tween_property(self, "position:x", position.x + 8, 0.04)
	tween.tween_property(self, "position:x", position.x - 5, 0.04)
	tween.tween_property(self, "position:x", position.x, 0.04)


func play_finisher_flash(target_global_position: Vector2) -> void:
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(1.3, 1.1, 0.4, 0.9), 0.15)
	tween.tween_interval(0.1)
	tween.tween_property(self, "scale", Vector2(1.4, 1.4), 0.12)
	tween.tween_property(self, "global_position", target_global_position, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	await tween.finished
	if is_instance_valid(self):
		queue_free()


func start_finisher_glow() -> void:
	if card_data == null or card_data.rarity != CardData.CardRarity.SUPER:
		return
	stop_glow()
	is_playable = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_glow_tween = create_tween()
	_glow_tween.set_loops()
	_glow_tween.tween_property(self, "modulate", Color(1.3, 1.15, 0.55, 1.0), 0.6).set_trans(Tween.TRANS_SINE)
	_glow_tween.tween_property(self, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.6).set_trans(Tween.TRANS_SINE)


func stop_glow() -> void:
	if _glow_tween and _glow_tween.is_valid():
		_glow_tween.kill()
	_glow_tween = null


func play_entry_pulse() -> void:
	if _entry_pulse_tween and _entry_pulse_tween.is_valid():
		_entry_pulse_tween.kill()
	_entry_pulse_tween = create_tween()
	var pulse_color: Color
	if card_data != null:
		match card_data.card_family:
			"monster":  pulse_color = Color(1.2, 0.65, 0.3, 1)
			"building": pulse_color = Color(0.5, 0.7, 1.3, 1)
			"counter":  pulse_color = Color(0.4, 1.0, 0.8, 1)
			_:          pulse_color = Color(1.4, 1.4, 1.4, 1)
	else:
		pulse_color = Color(1.4, 1.4, 1.4, 1)
	var rest_scale := _tabletop_base_scale if _tabletop_pose_enabled else Vector2(1.0, 1.0)
	var pulse_scale := rest_scale * 1.08
	var rest_modulate := _get_field_modulate() if (_display_mode == CardDisplayMode.PLAYER_FIELD or _display_mode == CardDisplayMode.BOSS_FIELD) else Color(1, 1, 1, 1)
	_entry_pulse_tween.tween_property(self, "modulate", pulse_color, 0.12)
	_entry_pulse_tween.tween_property(self, "scale", pulse_scale, 0.12)
	_entry_pulse_tween.tween_property(self, "modulate", rest_modulate, 0.2)
	_entry_pulse_tween.tween_property(self, "scale", rest_scale, 0.2)


# ============================================================
# Phase 7E-3: 场上 MONSTER ATK/DEF 标签
# ============================================================

func _add_monster_field_tags(_data: CardData) -> void:
	_remove_named_child("MonsterFieldTags")
	var hbox := HBoxContainer.new()
	hbox.name = "MonsterFieldTags"
	hbox.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE, Control.PRESET_MODE_MINSIZE, 14)
	hbox.offset_top = -16
	hbox.offset_bottom = -2
	hbox.offset_left = 3
	hbox.offset_right = -3
	hbox.custom_minimum_size = Vector2(0, 14)
	hbox.add_theme_constant_override("separation", 4)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.02, 0.02, 0.06, 0.75)
	bg_style.set_corner_radius_all(3)
	hbox.add_theme_stylebox_override("normal", bg_style)

	var atk_label := Label.new()
	atk_label.text = "ATK:%d" % _data.unit_power
	atk_label.add_theme_font_size_override("font_size", 8)
	atk_label.add_theme_color_override("font_color", Color(1, 0.55, 0.2, 1))
	hbox.add_child(atk_label)

	var def_label := Label.new()
	def_label.text = "DEF:%d" % _data.unit_defense
	def_label.add_theme_font_size_override("font_size", 8)
	def_label.add_theme_color_override("font_color", Color(0.35, 0.7, 1, 1))
	hbox.add_child(def_label)

	add_child(hbox)


# ============================================================
# Phase 7E-3: FINISHER 金色底光
# ============================================================

func _add_finisher_field_glow() -> void:
	_remove_named_child("FinisherFieldGlow")
	var glow := ColorRect.new()
	glow.name = "FinisherFieldGlow"
	glow.color = Color(1, 0.75, 0.2, 0.18)
	glow.custom_minimum_size = Vector2(0, 2)
	glow.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	glow.offset_bottom = -2
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(glow)


# ============================================================
# Phase 12B: Premium Card Surface — 安全访问器
# ============================================================

## 返回 ArtPlaceholder Panel（卡图容器），供 CardVFXController 添加 overlay
func get_art_panel() -> Panel:
	return get_node_or_null(NodePath("VBoxContainer/ArtPlaceholder")) as Panel


## 返回 RealCardArt TextureRect（真实卡图），供 overlay 精确定位
func get_real_card_art() -> TextureRect:
	var art_panel := get_art_panel()
	if art_panel == null:
		return null
	return art_panel.get_node_or_null("RealCardArt") as TextureRect


## 安全移除指定名称的子节点（用于清理 premium overlay）
func remove_named_overlay(node_name: String) -> void:
	var node := get_node_or_null(NodePath(node_name))
	if node != null and is_instance_valid(node):
		node.queue_free()


# ── Release skin：类型配色 + 左侧色条 + 类型图标 ──
const _TYPE_SKIN := {
	"monster": Color(0.78, 0.46, 0.24),
	"spell": Color(0.29, 0.50, 0.77),
	"building": Color(0.34, 0.57, 0.39),
	"counter": Color(0.55, 0.42, 0.75),
}
const _TYPE_GLYPH_SCRIPT = preload("res://ui/card_type_glyph.gd")

var _type_strip: ColorRect
var _type_glyph: Control


func _apply_type_skin(data: CardData) -> void:
	if data == null or not is_inside_tree():
		return
	var fam := str(data.card_family)
	var col: Color = _TYPE_SKIN.get(fam, Color(0.38, 0.41, 0.45))

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.075, 0.09, 0.11, 0.97)
	sb.border_width_left = 2
	sb.border_width_right = 2
	sb.border_width_top = 2
	sb.border_width_bottom = 2
	sb.border_color = col
	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_left = 8
	sb.corner_radius_bottom_right = 8
	add_theme_stylebox_override("panel", sb)

	if not is_instance_valid(_type_strip):
		_type_strip = ColorRect.new()
		_type_strip.name = "TypeStrip"
		_type_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_type_strip)
		_type_strip.set_anchors_preset(Control.PRESET_LEFT_WIDE)
		_type_strip.offset_left = 0
		_type_strip.offset_right = 3
		_type_strip.offset_top = 8
		_type_strip.offset_bottom = -8
	_type_strip.color = col
	_type_strip.visible = _display_mode == CardDisplayMode.HAND

	var art := get_node_or_null(NodePath("VBoxContainer/ArtPlaceholder")) as Control
	if art != null:
		if not is_instance_valid(_type_glyph):
			_type_glyph = _TYPE_GLYPH_SCRIPT.new()
			_type_glyph.name = "TypeGlyph"
			_type_glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_type_glyph.set_anchors_preset(Control.PRESET_FULL_RECT)
			art.add_child(_type_glyph)
		_type_glyph.setup(fam, col)
		_type_glyph.visible = _display_mode != CardDisplayMode.FEED
