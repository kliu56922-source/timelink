extends Control
class_name PlayerTable

## PlayerTable — 个人牌桌组件
## 承载单个玩家/敌人的战斗UI：HP、OD、手牌、前场、陷阱、墓地、卡组、Chain、行动按钮。
## 用法：bind_context + bind_player → rebuild_hand / rebuild_field / refresh

# ============================================================
# 信号
# ============================================================
signal card_clicked(card_ui: CardUI)
signal end_turn_pressed()
signal card_dropped(card_ui: CardUI, card_data: CardData, zone_type: String)
signal hand_drag_started(card_ui: CardUI)
signal hand_drag_ended(card_ui: CardUI)
signal building_interact_requested(card: CardData)
# Phase 10A: 场卡点击信号（区分于手牌点击，用于怪兽攻击选择）
signal field_card_clicked(card: CardData, owner_side: String)
# Phase 10A: Boss 本体区域点击信号（用于直接攻击 Boss HP）
signal boss_area_clicked(owner_side: String)
# Phase 13F-3: 升格触发信号
signal ascend_triggered(base_card: CardData, target_card: CardData)

# ============================================================
# 常量
# ============================================================
const CardUIScene: PackedScene = preload("res://ui/card_ui.tscn")
const CardDetailScene: PackedScene = preload("res://ui/card_detail_panel.tscn")
const HandLayoutClass = preload("res://ui/hand_layout.gd")
const DETAIL_PREVIEW_HIDE_DELAY := 0.15

# ── 统一色板 ──
const TC = preload("res://core/theme/theme_colors.gd")
const TableLayoutConfigClass = preload("res://core/config/table_layout_config.gd")

# ============================================================
# 皮肤数据（纯色值，不需要美术资源）
# ============================================================
const TABLE_SKINS: Dictionary = {
	"default_dark": {
		"bg_color": Color(0.06, 0.06, 0.1, 1),
		"border_color": Color(0.15, 0.15, 0.25, 1),
	},
	"blue_neon": {
		"bg_color": Color(0.02, 0.05, 0.14, 1),
		"border_color": Color(0.1, 0.5, 0.9, 1),
	},
	"red_overdrive": {
		"bg_color": Color(0.12, 0.03, 0.03, 1),
		"border_color": Color(0.9, 0.2, 0.1, 1),
	},
}

const OD_CORE_SKINS: Dictionary = {
	"default_core": {
		"calm_color": Color(0.3, 0.5, 1, 1),
		"bar_tint": Color(0.3, 0.5, 1, 1),
	},
	"blue_neon": {
		"calm_color": Color(0.1, 0.8, 1, 1),
		"bar_tint": Color(0.1, 0.7, 1, 1),
	},
	"red_overdrive": {
		"calm_color": Color(1, 0.35, 0.15, 1),
		"bar_tint": Color(1, 0.25, 0.1, 1),
	},
}

# ============================================================
# ============================================================
# @onready 节点引用
# ============================================================
@onready var table_bg: Panel = _safe_node("TableBG")
@onready var player_name_label: Label = _safe_node("MarginContainer/MainVBox/HeaderBar/PlayerNameLabel")
@onready var hp_label: Label = _safe_node("MarginContainer/MainVBox/HeaderBar/HPLabel")
@onready var od_bar: ProgressBar = _safe_node("MarginContainer/MainVBox/ODCore/ODBar")
@onready var od_zone_label: Label = _safe_node("MarginContainer/MainVBox/ODCore/ODZoneLabel")
@onready var field_zone: HBoxContainer = _safe_node("MarginContainer/MainVBox/FieldZone")
@onready var trap_zone: HBoxContainer = _safe_node("MarginContainer/MainVBox/TrapZone")
@onready var chain_zone: Label = _safe_node("MarginContainer/MainVBox/ChainZone")
@onready var hand_zone: Control = _safe_node("MarginContainer/MainVBox/HandZone")
@onready var deck_zone: Label = _safe_node("MarginContainer/MainVBox/BottomBar/DeckZone")
@onready var graveyard_zone: Label = _safe_node("MarginContainer/MainVBox/BottomBar/GraveyardZone")
@onready var end_turn_btn: Button = _safe_node("MarginContainer/MainVBox/BottomBar/ActionZone/EndTurnBtn")
@onready var decoration_slots: HBoxContainer = _safe_node("MarginContainer/MainVBox/DecorationSlots")
@onready var spell_drop_zone: DropZone = _safe_node("MarginContainer/MainVBox/SpellDropZone")

var field_drop_zone: DropZone = null
var trap_drop_zone: DropZone = null
var graveyard_drop_zone: DropZone = null
var od_value_label: Label = null
var load_label: Label = null
var chain_stepper_hbox: HBoxContainer = null
var depth_label: Label = null
var chain_stepper_blocks: Array = []
var chain_name_label: Label = null
var card_detail_panel: CardDetailPanel = null
var _hand_layout: HandLayout = null
var front_row_visual: HBoxContainer = null
var back_row_visual: HBoxContainer = null
var front_slots: Array[Control] = []
var back_slots: Array[Control] = []
const ZONE_SLOT_SIZE: Vector2 = Vector2(108, 76)
const MAX_FRONT_SLOTS := 5
const MAX_BACK_SLOTS := 5


# 内部状态
# ============================================================
var _context: BattleContext = null
var _player = null
var _end_turn_callable: Callable = Callable()
var _od_signal_connected := false
var _can_play_check: Callable = Callable()

# ===== Phase 10E: CardVFXController 引用 =====
var _card_vfx: CardVFXController = null

# ===== Preview 模式（主页使用）=====
var _preview_mode := false
var _preview_data: Dictionary = {
	"player_name": "Player",
	"hp": 30,
	"od_value": 0,
	"od_zone_name": "Calm",
}

# ===== 当前皮肤 ID =====
var _current_table_skin_id := "default_dark"
var _current_od_core_skin_id := "default_core"

# ===== 牌桌阵营（player / enemy / boss）=====
var _owner_side := "player"

# Phase 21G: 2D field card visibility flag
var _field_cards_visible := true

# Phase 23A-R: 3D board mode — suppress old 2D overlays
var _3d_status_tags_hidden := false
var _3d_chain_stepper_hidden := false

# ===== Phase 4B-6: 嵌入模式 + 外部宿主 =====
var _embedded_mode := false
var _detail_panel_host: Control = null
var _hand_host: Control = null
var _hand_layout_external: HandLayout = null
var _detail_preview_card: CardData = null
var _detail_pinned := false
var _detail_hide_generation := 0

# ===== Phase 4B-6E: 唯一槽位来源 =====
var _external_front_slots: Array[Control] = []
var _external_back_slots: Array[Control] = []
var _external_slots_set := false

# ===== Phase 4B-6D: 外部行动展示槽 =====
var _action_slot: Control = null

# ===== Zone 状态追踪 =====
var last_zone_name: String = ""

# ===== Phase 4B-6D: OD 分段仪表 =====
var _od_segment_container: HBoxContainer = null
var _od_segments: Array[ColorRect] = []
var _od_segment_glow: ColorRect = null
var _od_delta_label: Label = null
var _depth_delta_label: Label = null
var _abyss_lock_indicator: ColorRect = null
var _abyss_lock_tween: Tween = null

# ===== Phase 4B-6D: 意图标签 =====
var _intent_label: Label = null

# ===== Phase 4B-6D: 危险脉冲 =====
var _danger_pulse: Tween = null
var _home_pulse_tween: Tween = null
var _last_field_click_instance_id: int = 0
var _last_field_click_msec: int = 0


func _ready() -> void:
	if end_turn_btn:
		end_turn_btn.pressed.connect(_on_end_turn_internal)
	_setup_drop_zones()
	_setup_detail_panel()
	_setup_od_labels()
	_setup_intent_label()
	_setup_chain_stepper()
	_setup_hand_layout()
	_setup_zone_visual_slots()
	_setup_depth_label()
	_create_od_segmented_bar()


func _safe_node(path: String) -> Node:
	return get_node_or_null(NodePath(path))


func bind_context(ctx: BattleContext) -> void:
	if _od_signal_connected and _context and _context.od_changed.is_connected(_on_od_changed):
		_context.od_changed.disconnect(_on_od_changed)
		_od_signal_connected = false
	_context = ctx
	if _context and _context.has_signal("od_changed"):
		if not _context.od_changed.is_connected(_on_od_changed):
			_context.od_changed.connect(_on_od_changed)
			_od_signal_connected = true


func bind_player(pl) -> void:
	_player = pl


func set_end_turn_callback(cb: Callable) -> void:
	_end_turn_callable = cb


func set_can_play_check(cb: Callable) -> void:
	_can_play_check = cb


## Phase 10E: 绑定 CardVFXController 引用（用于手牌/场上动效）
func set_card_vfx_controller(controller: CardVFXController) -> void:
	_card_vfx = controller


func set_owner_side(side: String) -> void:
	_owner_side = side
	match side:
		"enemy": _apply_enemy_side()
		"boss": _apply_boss_side()
		_: _apply_player_side()


func _apply_player_side() -> void:
	if hand_zone: hand_zone.visible = true
	if end_turn_btn: end_turn_btn.visible = true


func _apply_enemy_side() -> void:
	if hand_zone: hand_zone.visible = false
	if end_turn_btn: end_turn_btn.visible = false
	# Phase 10A: Boss 侧 Header 可点击 → 攻击 Boss 本体目标
	if player_name_label:
		player_name_label.mouse_filter = Control.MOUSE_FILTER_STOP
		if not player_name_label.gui_input.is_connected(_on_boss_area_gui_input):
			player_name_label.gui_input.connect(_on_boss_area_gui_input)


func _apply_boss_side() -> void:
	if hand_zone: hand_zone.visible = false
	if end_turn_btn: end_turn_btn.visible = false
	_apply_table_skin("red_overdrive")


func _setup_drop_zones() -> void:
	if field_zone:
		field_drop_zone = _create_drop_zone("field")
		field_zone.add_child(field_drop_zone)
		field_zone.move_child(field_drop_zone, 0)
	if trap_zone:
		trap_drop_zone = _create_drop_zone("trap")
		trap_zone.add_child(trap_drop_zone)
		trap_zone.move_child(trap_drop_zone, 0)
	if graveyard_zone:
		var gy_parent := graveyard_zone.get_parent()
		if gy_parent:
			graveyard_drop_zone = _create_drop_zone("graveyard")
			graveyard_drop_zone.custom_minimum_size = Vector2(80, 34)
			gy_parent.add_child(graveyard_drop_zone)
			gy_parent.move_child(graveyard_drop_zone, 0)


func _create_drop_zone(zone_type: String) -> DropZone:
	var dz := DropZone.new()
	dz.zone_type = zone_type
	dz.set_anchors_preset(Control.PRESET_FULL_RECT)
	dz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return dz


func _setup_detail_panel() -> void:
	if _owner_side == "player":
		card_detail_panel = CardDetailScene.instantiate()
		card_detail_panel.visible = false
		card_detail_panel.z_index = 200
		add_child(card_detail_panel)


func set_detail_panel_host(host: Control) -> void:
	_detail_panel_host = host
	if not card_detail_panel or not is_instance_valid(card_detail_panel):
		return
	if not host:
		return
	var old_parent := card_detail_panel.get_parent()
	if old_parent:
		old_parent.remove_child(card_detail_panel)
	host.add_child(card_detail_panel)
	card_detail_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	card_detail_panel.offset_left = 0
	card_detail_panel.offset_top = 0
	card_detail_panel.offset_right = 0
	card_detail_panel.offset_bottom = 0
	card_detail_panel.visible = false
	card_detail_panel.z_index = 200


func set_embedded_board_mode(enabled: bool) -> void:
	_embedded_mode = enabled
	if enabled:
		_hide_old_ui()
	else:
		_show_old_ui()


func _hide_old_ui() -> void:
	var nodes_to_hide := [
		"MarginContainer/MainVBox/HeaderBar",
		"MarginContainer/MainVBox/ODCore",
		"MarginContainer/MainVBox/BottomBar",
		"MarginContainer/MainVBox/HSep1",
		"MarginContainer/MainVBox/HSep2",
		"MarginContainer/MainVBox/ChainZone",
		"MarginContainer/MainVBox/SpellDropZone",
		"MarginContainer/MainVBox/MidSpacer",
		"MarginContainer/MainVBox/HandZone",
		"MarginContainer/MainVBox/DecorationSlots",
		"MarginContainer/MainVBox/FrontRowVisual",
		"MarginContainer/MainVBox/BackRowVisual",
		"MarginContainer/MainVBox/FieldZone",
		"MarginContainer/MainVBox/TrapZone",
	]
	for path in nodes_to_hide:
		var node := _safe_node(path)
		if node:
			node.visible = false
	if depth_label and is_instance_valid(depth_label):
		depth_label.visible = false
	if _od_segment_container and is_instance_valid(_od_segment_container):
		_od_segment_container.visible = false
	if table_bg:
		table_bg.visible = false


func _show_old_ui() -> void:
	var nodes_to_show := [
		"MarginContainer/MainVBox/HeaderBar",
		"MarginContainer/MainVBox/ODCore",
		"MarginContainer/MainVBox/BottomBar",
		"MarginContainer/MainVBox/HSep1",
		"MarginContainer/MainVBox/HSep2",
		"MarginContainer/MainVBox/ChainZone",
		"MarginContainer/MainVBox/SpellDropZone",
		"MarginContainer/MainVBox/MidSpacer",
		"MarginContainer/MainVBox/HandZone",
		"MarginContainer/MainVBox/DecorationSlots",
		"MarginContainer/MainVBox/FrontRowVisual",
		"MarginContainer/MainVBox/BackRowVisual",
		"MarginContainer/MainVBox/FieldZone",
		"MarginContainer/MainVBox/TrapZone",
	]
	for path in nodes_to_show:
		var node := _safe_node(path)
		if node:
			node.visible = true
	if depth_label and is_instance_valid(depth_label):
		depth_label.visible = true
	if _od_segment_container and is_instance_valid(_od_segment_container):
		_od_segment_container.visible = true
	if table_bg:
		table_bg.visible = true


func set_hand_host(host: Control) -> void:
	_hand_host = host
	if not host:
		return
	if _hand_layout_external and is_instance_valid(_hand_layout_external):
		_hand_layout_external.queue_free()
		_hand_layout_external = null
	_hand_layout_external = HandLayoutClass.new()
	_hand_layout_external.name = "BattleHandLayout"
	_hand_layout_external.mouse_filter = Control.MOUSE_FILTER_STOP
	host.add_child(_hand_layout_external)
	_hand_layout_external.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hand_layout_external.offset_left = 0
	_hand_layout_external.offset_top = 0
	_hand_layout_external.offset_right = 0
	_hand_layout_external.offset_bottom = 0
	_hand_layout_external.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hand_layout_external.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_hand_layout_external.custom_minimum_size = Vector2(maxf(host.size.x, 900.0), maxf(host.size.y, 210.0))
	_hand_layout_external.needs_arrange = true
	_hand_layout_external.call_deferred("arrange_cards")


func set_board_zone_hosts(_front_host: Control, _back_host: Control) -> void:
	pass


func set_external_board_slots(external_front_slots: Array[Control], external_back_slots: Array[Control]) -> void:
	_external_front_slots.clear()
	_external_back_slots.clear()
	for slot in external_front_slots:
		if slot != null and is_instance_valid(slot):
			_external_front_slots.append(slot)
	for slot in external_back_slots:
		if slot != null and is_instance_valid(slot):
			_external_back_slots.append(slot)
	_external_slots_set = true
	if front_row_visual and is_instance_valid(front_row_visual):
		front_row_visual.queue_free()
		front_row_visual = null
	if back_row_visual and is_instance_valid(back_row_visual):
		back_row_visual.queue_free()
		back_row_visual = null
	front_slots.clear()
	back_slots.clear()
	_apply_external_drop_zones()
	call_deferred("_refresh_front_row_visual")
	call_deferred("_refresh_back_row_visual")


func set_action_slot(slot: Control) -> void:
	_action_slot = slot


func _apply_external_drop_zones() -> void:
	if field_drop_zone and not _external_front_slots.is_empty():
		var host: Control = _external_front_slots[0].get_parent()
		if host:
			_reparent_drop_to(field_drop_zone, host)
	if trap_drop_zone and not _external_back_slots.is_empty():
		var host: Control = _external_back_slots[0].get_parent()
		if host:
			_reparent_drop_to(trap_drop_zone, host)


func _reparent_drop_to(dz: DropZone, host: Control) -> void:
	if not dz or not is_instance_valid(dz) or not host:
		return
	var old_parent := dz.get_parent()
	if old_parent:
		old_parent.remove_child(dz)
	host.add_child(dz)
	dz.set_anchors_preset(Control.PRESET_FULL_RECT)
	dz.z_index = 4
	dz.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _setup_od_labels() -> void:
	if not od_bar:
		return
	var od_core_parent = od_bar.get_parent()
	if not od_core_parent:
		return
	od_value_label = Label.new()
	od_value_label.name = "ODValueLabel"
	od_value_label.text = "OD: 0/10"
	od_value_label.add_theme_font_size_override("font_size", 12)
	od_value_label.add_theme_color_override("font_color", Color(0.7, 0.85, 1, 1))
	od_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	od_core_parent.add_child(od_value_label)
	od_core_parent.move_child(od_value_label, 1)
	load_label = Label.new()
	load_label.name = "LoadLabel"
	load_label.text = "Load: 0/5"
	load_label.add_theme_font_size_override("font_size", 11)
	load_label.add_theme_color_override("font_color", Color(0.9, 0.7, 0.3, 1))
	load_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	od_core_parent.add_child(load_label)
	od_core_parent.move_child(load_label, 2)


func _setup_intent_label() -> void:
	if not player_name_label:
		return
	var parent = player_name_label.get_parent()
	if not parent:
		return
	_intent_label = Label.new()
	_intent_label.name = "IntentLabel"
	_intent_label.add_theme_font_size_override("font_size", 11)
	_intent_label.add_theme_color_override("font_color", TC.TEXT_DIM)
	_intent_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_intent_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(_intent_label)


func flash_hit() -> void:
	if not table_bg:
		return
	var t := create_tween()
	t.tween_property(table_bg, "modulate", Color(1.3, 0.5, 0.5, 1), 0.06)
	t.tween_property(table_bg, "modulate", Color(1, 1, 1, 1), 0.15)


func start_danger_pulse() -> void:
	if _danger_pulse and _danger_pulse.is_valid():
		return
	_danger_pulse = create_tween()
	_danger_pulse.set_loops()
	_danger_pulse.tween_property(self, "modulate", Color(1.08, 0.6, 0.6, 1), 0.5).set_trans(Tween.TRANS_SINE)
	_danger_pulse.tween_property(self, "modulate", Color(1, 1, 1, 1), 0.5).set_trans(Tween.TRANS_SINE)


func stop_danger_pulse() -> void:
	if _danger_pulse and _danger_pulse.is_valid():
		_danger_pulse.kill()
	_danger_pulse = null
	modulate = Color(1, 1, 1, 1)


func _setup_chain_stepper() -> void:
	if not chain_zone:
		return
	var parent = chain_zone.get_parent()
	if not parent:
		return
	chain_zone.visible = false
	chain_stepper_hbox = HBoxContainer.new()
	chain_stepper_hbox.name = "ChainStepper"
	chain_stepper_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	chain_stepper_hbox.add_theme_constant_override("separation", 4)
	parent.add_child(chain_stepper_hbox)
	parent.move_child(chain_stepper_hbox, chain_zone.get_index())
	chain_name_label = Label.new()
	chain_name_label.name = "ChainNameLabel"
	chain_name_label.add_theme_font_size_override("font_size", 12)
	chain_name_label.add_theme_color_override("font_color", TC.TEXT_SECONDARY)
	chain_stepper_hbox.add_child(chain_name_label)


func _setup_hand_layout() -> void:
	if not hand_zone:
		return
	if _hand_layout and is_instance_valid(_hand_layout):
		return
	var parent = hand_zone.get_parent()
	if not parent:
		return
	_hand_layout = HandLayoutClass.new()
	_hand_layout.name = "HandLayout"
	_hand_layout.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hand_layout.custom_minimum_size = Vector2(maxf(hand_zone.custom_minimum_size.x, 900.0), maxf(hand_zone.custom_minimum_size.y, 210.0))
	_hand_layout.mouse_filter = Control.MOUSE_FILTER_STOP
	_hand_layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hand_layout.size_flags_vertical = Control.SIZE_SHRINK_END
	parent.add_child(_hand_layout)
	parent.move_child(_hand_layout, hand_zone.get_index())
	hand_zone.visible = false


func _setup_depth_label() -> void:
	if not od_bar:
		return
	var parent = od_bar.get_parent()
	if not parent:
		return
	depth_label = Label.new()
	depth_label.name = "DepthLabel"
	depth_label.text = "D:0 Stable"
	depth_label.add_theme_font_size_override("font_size", 11)
	depth_label.add_theme_color_override("font_color", Color(0.4, 0.7, 1.0))
	depth_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(depth_label)


func set_depth(value: int, zone: String) -> void:
	if not depth_label:
		return
	depth_label.text = "D:%d %s" % [value, zone]
	match zone:
		"Stable":
			depth_label.add_theme_color_override("font_color", Color(0.4, 0.7, 1.0))
		"Pressure":
			depth_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25))
		"Distortion":
			depth_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.15))
		"Abyss":
			depth_label.add_theme_color_override("font_color", Color(1.0, 0.15, 0.4))
		_:
			depth_label.add_theme_color_override("font_color", Color.WHITE)
	_set_abyss_lock_visual(zone == "Abyss")



func _setup_zone_visual_slots() -> void:
	var main_vbox := _safe_node("MarginContainer/MainVBox") as VBoxContainer
	if not main_vbox:
		return

	# Phase 5C-3: 从配置文件读取槽位参数
	var cfg := TableLayoutConfigClass.new()
	var front_sz := cfg.get_front_slot_size()
	var back_sz := cfg.get_back_slot_size()
	var s_gap := cfg.get_slot_gap()

	# ── 前场视觉槽位（插在 FieldZone 后面） ──
	if field_zone:
		front_row_visual = HBoxContainer.new()
		front_row_visual.name = "FrontRowVisual"
		front_row_visual.add_theme_constant_override("separation", s_gap)
		front_row_visual.alignment = BoxContainer.ALIGNMENT_CENTER
		front_row_visual.custom_minimum_size = Vector2(0, 82)
		main_vbox.add_child(front_row_visual)
		main_vbox.move_child(front_row_visual, field_zone.get_index() + 1)

		front_slots.clear()
		for i in range(MAX_FRONT_SLOTS):
			var slot := _make_zone_slot("FrontSlot%d" % (i + 1), TC.ZONE_CALM, front_sz)
			front_row_visual.add_child(slot)
			front_slots.append(slot)

		# 隐藏旧 FieldZone（保留 NodePath，不参与可见布局）
		field_zone.visible = false
		field_zone.custom_minimum_size = Vector2.ZERO

	# ── 后场视觉槽位（插在 TrapZone 后面） ──
	if trap_zone:
		back_row_visual = HBoxContainer.new()
		back_row_visual.name = "BackRowVisual"
		back_row_visual.add_theme_constant_override("separation", s_gap)
		back_row_visual.alignment = BoxContainer.ALIGNMENT_CENTER
		back_row_visual.custom_minimum_size = Vector2(0, 82)
		main_vbox.add_child(back_row_visual)
		# 找到 trap_zone 的索引并在其后插入
		main_vbox.move_child(back_row_visual, trap_zone.get_index() + 1)

		back_slots.clear()
		for i in range(MAX_BACK_SLOTS):
			var slot := _make_zone_slot("BackSlot%d" % (i + 1), TC.ROLE_CONTROL, back_sz)
			back_row_visual.add_child(slot)
			back_slots.append(slot)

		# 隐藏旧 TrapZone（保留 NodePath，不参与可见布局）
		trap_zone.visible = false
		trap_zone.custom_minimum_size = Vector2.ZERO

	# Phase 4B-6E: 旧 reparent 已废弃，槽位来源由 set_external_board_slots() 统一管理

## Phase 1B 旧槽位工厂（只在无 external slots 时使用）
func _make_zone_slot(slot_name: String, border_color: Color, slot_size: Vector2 = Vector2(108, 76)) -> Control:
	var slot := Control.new()
	slot.name = slot_name
	slot.custom_minimum_size = ZONE_SLOT_SIZE
	slot.mouse_filter = Control.MOUSE_FILTER_STOP

	# 空槽：暗色半透明占位，前场蓝调/后场绿调边框
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.02, 0.04, 0.22)
	style.border_width_left = 0
	style.border_width_right = 0
	style.border_width_top = 0
	style.border_width_bottom = 1
	style.border_color = Color(border_color.r, border_color.g, border_color.b, 0.16)
	style.set_corner_radius_all(2)

	var panel := Panel.new()
	panel.name = "SlotPanel"
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", style)
	slot.add_child(panel)

	return slot

## 清除槽位中的旧内容（保留底框）
func _clear_slot(slot: Control) -> void:
	if not slot:
		return
	for child in slot.get_children():
		if not is_instance_valid(child):
			continue
		if child.name != "SlotPanel":
			# Phase 10E: stop VFX before freeing
			if _card_vfx and child is CardUI:
					_card_vfx.stop_premium_surface(child)
					_card_vfx.stop_for(child)
			child.queue_free()

## 在槽位中显示卡牌信息
func _populate_slot(slot: Control, card: CardData) -> void:
	_clear_slot(slot)
	if not card:
		return

	# 更新槽位底框为亮色（区分空槽）
	var slot_panel := slot.get_node_or_null("SlotPanel") as Panel
	if slot_panel:
		var new_style := StyleBoxFlat.new()
		new_style.set_corner_radius_all(2)
		new_style.border_width_left = 1
		new_style.border_width_right = 1
		new_style.border_width_top = 1
		new_style.border_width_bottom = 1
		if card.is_front_row_card():
			# 前场 UNIT：亮蓝底 + 橙红边框，明显区别于手牌暗色
			new_style.bg_color = Color(0.08, 0.14, 0.28, 0.75)
			new_style.border_color = Color(0.85, 0.45, 0.15, 0.60)
		elif card.has_method("is_building_card") and card.is_building_card():
			# 建筑：蒸汽铜底 + 暗金边框，区别于一次性反制
			new_style.bg_color = Color(0.10, 0.06, 0.03, 0.70)
			new_style.border_color = Color(0.65, 0.38, 0.14, 0.55)
		elif card.display_type == CardData.DisplayType.TRAP:
			# 后场 TRAP：暗绿底 + 荧光绿边框
			new_style.bg_color = Color(0.03, 0.12, 0.08, 0.70)
			new_style.border_color = Color(0.12, 0.55, 0.35, 0.55)
		else:
			# 后场 SUSTAIN / 持续 SPELL：紫底 + 青紫边框
			new_style.bg_color = Color(0.08, 0.04, 0.14, 0.70)
			new_style.border_color = Color(0.35, 0.18, 0.60, 0.55)
		slot_panel.add_theme_stylebox_override("panel", new_style)

	# ── Phase 4B-5A: 实例化 CardUI 作为场上卡主体 ──
	var card_ui: CardUI = CardUIScene.instantiate()
	card_ui.name = "CardUI"
	card_ui.set_anchors_preset(Control.PRESET_FULL_RECT)

	# Phase 9B: 所有场上卡需要 hover/点击查看详情
	card_ui.mouse_filter = Control.MOUSE_FILTER_STOP

	# 根据阵营设置显示模式（先设置模式，再填充数据，尺寸不会被覆盖）
	if _owner_side == "player":
		card_ui.set_display_mode(CardUI.CardDisplayMode.PLAYER_FIELD)
	else:
		card_ui.set_display_mode(CardUI.CardDisplayMode.BOSS_FIELD)

	# 填充卡面数据
	card_ui.apply_board_mode(card, _owner_side != "player")
	card_ui.mouse_filter = Control.MOUSE_FILTER_STOP

	# 场上卡不可出牌
	card_ui.is_playable = false

	# 连接 hover 信号到详情面板
	if not card_ui.card_hovered.is_connected(_on_card_hovered_detail):
		card_ui.card_hovered.connect(_on_card_hovered_detail)
	if not card_ui.card_unhovered.is_connected(_on_card_unhovered_detail):
		card_ui.card_unhovered.connect(_on_card_unhovered_detail)

	# Phase 5E-4: 建筑卡点击连接
	if card.has_method("is_building_card") and card.is_building_card() and _owner_side == "player":
		if not card_ui.card_clicked.is_connected(_on_building_card_clicked):
			card_ui.card_clicked.connect(_on_building_card_clicked)
	else:
		# Phase 9B: 非建筑场卡点击 → 显示详情（不拖拽）
		if not card_ui.card_clicked.is_connected(_on_field_card_clicked_detail):
			card_ui.card_clicked.connect(_on_field_card_clicked_detail)

	if not card_ui.gui_input.is_connected(_on_field_card_gui_input):
		card_ui.gui_input.connect(_on_field_card_gui_input.bind(card_ui))

	slot.add_child(card_ui)
	# Phase 21G: respect 2D field card visibility flag
	if not _field_cards_visible:
		card_ui.visible = false
	# Phase 19C: move card to front (above slot seal / lock label / status tag)
	var _p19c_parent := card_ui.get_parent()
	if _p19c_parent:
		_p19c_parent.move_child(card_ui, _p19c_parent.get_child_count() - 1)
	var _p19c_name := card.get_display_name() if card.has_method("get_display_name") else card.card_name
	# Phase 19D: [FIELD_CARD_ADDED] silent
	if card_ui.has_method("apply_tabletop_field_pose"):
		# Phase 20A: 检测前场/后场，传递 zone 参数
		var _slot_zone := "front"
		if _external_slots_set:
			if slot in _external_back_slots:
				_slot_zone = "back"
		else:
			if slot in back_slots:
				_slot_zone = "back"
		card_ui.apply_tabletop_field_pose(_owner_side, _slot_zone)

	# ── 入场发光反馈 ──
	if slot_panel and is_instance_valid(slot_panel):
		var pulse_tween: Tween = create_tween()
		pulse_tween.tween_property(slot_panel, "modulate", Color(1.5, 1.5, 1.5, 1), 0.08)
		pulse_tween.tween_property(slot_panel, "modulate", Color(1, 1, 1, 1), 0.2)

	# CardUI 入场脉冲
	if is_instance_valid(card_ui):
		card_ui.play_entry_pulse()

	# Phase 10E: 落地动画 + 场上待机
	if _card_vfx:
		var ltype := _card_vfx._get_field_idle_type(card)
		if ltype != "":
			var is_sup := (card.rarity == CardData.CardRarity.SUPER)
			_card_vfx.play_card_landing(card_ui, ltype, is_sup)
			_card_vfx.play_field_idle(card_ui, ltype)
			# Phase 12B: Premium card surface（场上模式，强度降低）
			if _card_vfx.is_premium_card(card):
				_card_vfx.play_premium_surface(card_ui, card, 1)  # mode=1=场上

	# Phase 5E-4: 建筑状态标签（ACT / USED / LOCK）
	if card.has_method("is_building_card") and card.is_building_card():
		_add_building_status_label(slot, card, slot_panel)

	# Phase 13F-2: ASCEND 升格标签
	_add_ascend_tag(slot, card)
	# Phase 15D: monster status tags (ATK READY / USED / EFFECT)
	_add_monster_status_tags(slot, card)
	if card_ui.has_method("set_field_children_mouse_passthrough"):
		card_ui.set_field_children_mouse_passthrough()


# Phase 5B-1: 后场建筑点击 → 转发为建筑交互请求
func _on_building_card_clicked(card_ui: CardUI) -> void:
	if not _consume_field_click(card_ui):
		return
	if card_ui.card_data and card_ui.card_data.is_building_card():
		building_interact_requested.emit(card_ui.card_data)


# Phase 15B: field card click -> always emit field_card_clicked (menu handles ascension)
func _on_field_card_clicked_detail(card_ui: CardUI) -> void:
	if not _consume_field_click(card_ui):
		return
	if not card_ui.card_data:
		return
	var display_name := "?"
	if card_ui.card_data.has_method("get_display_name"):
		display_name = card_ui.card_data.get_display_name()
	else:
		display_name = card_ui.card_data.card_name
	# Phase 19D: [FIELD_CARD_CLICK_EMIT] silent
	_on_card_hovered_detail(card_ui.card_data)
	if card_detail_panel:
		card_detail_panel.visible = true
	# Phase 10A: notify BattleScene (menu/attack/ascension handled there)
	# Phase 19C: 发射前打印 [FIELD_CARD_CLICK_EMIT]
	field_card_clicked.emit(card_ui.card_data, _owner_side)


func _on_field_card_gui_input(event: InputEvent, card_ui: CardUI) -> void:
	if not (event is InputEventMouseButton):
		return
	if not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return
	if not is_instance_valid(card_ui) or card_ui.card_data == null:
		return
	if card_ui.card_data.has_method("is_building_card") and card_ui.card_data.is_building_card() and _owner_side == "player":
		_on_building_card_clicked(card_ui)
	else:
		_on_field_card_clicked_detail(card_ui)


func _consume_field_click(card_ui: CardUI) -> bool:
	if not is_instance_valid(card_ui):
		return false
	var now := Time.get_ticks_msec()
	var instance_id := card_ui.get_instance_id()
	if instance_id == _last_field_click_instance_id and now - _last_field_click_msec < 120:
		return false
	_last_field_click_instance_id = instance_id
	_last_field_click_msec = now
	return true

func _on_card_hovered_detail(card: CardData) -> void:
	_detail_hide_generation += 1
	if _detail_pinned:
		return
	_detail_preview_card = card
	_show_card_detail(card, false)


func _show_card_detail(card: CardData, pinned: bool) -> void:
	if card_detail_panel:
		if card_detail_panel.has_method("set_detail_mode"):
			card_detail_panel.set_detail_mode(pinned)
		var zone_name := ""
		if _context and _context.has_method("get_od_zone_name"):
			zone_name = _context.get_od_zone_name()
		if _context and _context.chain_system:
			card_detail_panel.set_chain_system(_context.chain_system)

		# 传递可用性状态
		var status: Dictionary = {}
		if _can_play_check.is_valid():
			var result = _can_play_check.call(card)
			if result is Dictionary:
				status = result
			elif typeof(result) == TYPE_BOOL:
				if result:
					status = {"ok": true, "reason": ""}
			else:
					status = {"ok": false, "reason": "条件不满足"}

		# Phase 5E-4: 建筑接口状态追加
		if card.is_building_card() and _player != null and card in _player.field:
			var b_status := _query_building_status(card)
			if not b_status.is_empty():
				status["building_ok"] = b_status.get("ok", false)
				status["building_reason"] = b_status.get("reason", "")
				status["building_cost"] = b_status.get("cost", "")
				status["building_preview"] = b_status.get("preview", "")

		# Phase 13F-2: append ascension preview status
		if _player != null and card in _player.traps:
			var battle_system := _get_battle_system()
			if battle_system != null:
				var back_row: Dictionary = battle_system.get_back_row_trigger_status(card)
				if not back_row.is_empty(): status["back_row_facts"] = back_row

		var asc_info := _get_ascension_info_for_card(card)
		if not asc_info.is_empty():
			status["ascension_target"] = asc_info.get("target")
			status["ascension_ok"] = asc_info.get("ok", false)
			status["ascension_reason"] = asc_info.get("reason", "")
			status["ascension_label"] = asc_info.get("label", "")
			status["ascension_preview"] = asc_info.get("preview", "")

		var combat_state: Dictionary = {}
		if _player != null and card in _player.field:
			var bs = _get_battle_system()
			if bs != null and bs.has_method("get_unit_combat_state"):
				combat_state = bs.get_unit_combat_state(card)
		card_detail_panel.show_card(card, zone_name, status, combat_state)


func _on_card_unhovered_detail() -> void:
	if _detail_pinned:
		return
	_detail_hide_generation += 1
	var generation := _detail_hide_generation
	await get_tree().create_timer(DETAIL_PREVIEW_HIDE_DELAY).timeout
	if generation != _detail_hide_generation or _detail_pinned:
		return
	_clear_card_detail()


func _on_card_selected_detail(card: CardData) -> void:
	_detail_hide_generation += 1
	if _detail_pinned and _detail_preview_card == card:
		_clear_card_detail()
		return
	_detail_pinned = true
	_detail_preview_card = card
	_show_card_detail(card, true)


func is_detail_pinned() -> bool:
	return _detail_pinned


func clear_pinned_detail() -> bool:
	if not _detail_pinned:
		return false
	_clear_card_detail()
	return true


func _clear_card_detail() -> void:
	_detail_hide_generation += 1
	_detail_pinned = false
	_detail_preview_card = null
	if card_detail_panel != null and is_instance_valid(card_detail_panel):
		card_detail_panel.clear()


func _on_hand_card_dropped(card_ui: CardUI, drop_zone: DropZone) -> void:
	var card := card_ui.card_data
	if card == null:
		return
	card_dropped.emit(card_ui, card, drop_zone.zone_type)


func _on_hand_drag_started(card_ui: CardUI) -> void:
	if not _detail_pinned:
		_clear_card_detail()
	if card_ui.card_data:
		begin_card_drag_preview(card_ui.card_data)
	hand_drag_started.emit(card_ui)


func _on_hand_drag_ended(card_ui: CardUI) -> void:
	end_card_drag_preview()
	hand_drag_ended.emit(card_ui)
	if _hand_layout_external and is_instance_valid(_hand_layout_external):
		_hand_layout_external.needs_arrange = true
		_hand_layout_external.call_deferred("arrange_cards")
	elif _hand_layout and is_instance_valid(_hand_layout):
		_hand_layout.needs_arrange = true
		_hand_layout.call_deferred("arrange_cards")


# ============================================================
# 拖拽预览（全局区域高亮）
# ============================================================

## CardUI 开始拖拽时调用 — 所有 DropZone 实时显示可放/不可放
func begin_card_drag_preview(card: CardData) -> void:
	for dz in _get_all_drop_zones():
		if dz:
			dz.preview_card(card)


## CardUI 结束拖拽时调用 — 所有 DropZone 清除预览状态
func end_card_drag_preview() -> void:
	for dz in _get_all_drop_zones():
		if dz:
			dz.clear_preview()


## 返回所有 DropZone 引用
func get_drop_zones() -> Array[DropZone]:
	return _get_all_drop_zones()


func _get_all_drop_zones() -> Array[DropZone]:
	var zones: Array[DropZone] = []
	if field_drop_zone:
		zones.append(field_drop_zone)
	if spell_drop_zone:
		zones.append(spell_drop_zone)
	if trap_drop_zone:
		zones.append(trap_drop_zone)
	if graveyard_drop_zone:
		zones.append(graveyard_drop_zone)
	return zones


# ============================================================
# 区域位置查询 + 闪光反馈
# ============================================================

## 返回指定区域的全局中心坐标（用于卡牌飞行动画目标）
## Phase 4B-6D: 优先使用外部槽位区域
func get_zone_global_center(zone_type: String) -> Vector2:
	# 外部槽位模式：直接返回行宿主中心
	if _external_slots_set:
		match zone_type:
			"field":
				if not _external_front_slots.is_empty() and is_instance_valid(_external_front_slots[0]):
					var p := _external_front_slots[0].get_parent()
					if p: return p.get_global_rect().get_center()
			"trap":
				if not _external_back_slots.is_empty() and is_instance_valid(_external_back_slots[0]):
					var p := _external_back_slots[0].get_parent()
					if p: return p.get_global_rect().get_center()
			"spell":
				if _action_slot and is_instance_valid(_action_slot):
					return _action_slot.get_global_rect().get_center()

	var dz: DropZone = null
	match zone_type:
		"field":
			dz = field_drop_zone
		"spell":
			dz = spell_drop_zone
		"trap":
			dz = trap_drop_zone
		"graveyard":
			dz = graveyard_drop_zone

	if dz and dz is Control:
		return dz.global_position + dz.size / 2.0

	# Fallback：使用对应的容器/标签
	var fallback: Control = null
	match zone_type:
		"field":
			fallback = field_zone
		"trap":
			fallback = trap_zone
		"spell":
			fallback = spell_drop_zone
		"graveyard":
			fallback = graveyard_zone

	if fallback:
		return fallback.global_position + fallback.size / 2.0

	return Vector2.ZERO

## 返回卡牌应飞入的下一个槽位屏幕坐标（Phase 2C-0）
## Phase 4B-6D: 优先使用外部槽位
func get_next_board_slot_screen_pos(card: CardData) -> Vector2:
	if card == null:
		return get_global_rect().get_center()

	var slots: Array[Control] = []
	if card.is_front_row_card():
		slots = _external_front_slots if _external_slots_set else front_slots
	elif card.is_back_row_card():
		slots = _external_back_slots if _external_slots_set else back_slots

	if slots.is_empty():
		# INSTANT/SPELL → 返回 ActionSlot 中心
		if _action_slot and is_instance_valid(_action_slot):
			return _action_slot.get_global_rect().get_center()
		return get_global_rect().get_center()

	for slot in slots:
		if slot and is_instance_valid(slot):
			# 找第一个没有 CardUI 的空槽位
			if slot.get_node_or_null("CardUI") == null:
				return slot.get_global_rect().get_center()

	# 满场时飞到该行宿主中心
	if not slots.is_empty() and is_instance_valid(slots[0]):
		var parent := slots[0].get_parent()
		if parent:
			return parent.get_global_rect().get_center()

	return get_global_rect().get_center()


## Phase 4B-6D: 获取行动展示槽（SPELL/INSTANT 短暂停留）
func get_action_slot() -> Control:
	return _action_slot

## 成功释放后对应区域闪一下
func flash_zone(zone_type: String) -> void:
	var dz: DropZone = null
	match zone_type:
		"field":
			dz = field_drop_zone
		"spell":
			dz = spell_drop_zone
		"trap":
			dz = trap_drop_zone
		"graveyard":
			dz = graveyard_drop_zone

	if dz and dz.has_method("play_success_flash"):
		dz.play_success_flash()


## Boss/玩家满场时目标区域短暂红闪 — Phase 4B-5
func flash_zone_full(zone_type: String) -> void:
	var visual: HBoxContainer = null
	match zone_type:
		"front":
			visual = front_row_visual
		"back":
			visual = back_row_visual
		_:
			return
	if not visual:
		return
	var tween: Tween = create_tween()
	tween.tween_property(visual, "modulate", Color(1.5, 0.2, 0.2, 1), 0.08)
	tween.tween_property(visual, "modulate", Color(1, 1, 1, 1), 0.25)


## OD 核心脉冲：出牌成功后 OD 条短暂放大
func pulse_od_core() -> void:
	if not od_bar:
		return
	var tween := create_tween()
	tween.tween_property(od_bar, "scale", Vector2(1.08, 1.2), 0.08)
	tween.tween_property(od_bar, "scale", Vector2(1.0, 1.0), 0.12)


## Chain 步进器脉冲：步骤推进时短暂高亮放大
func pulse_chain_stepper() -> void:
	if not chain_stepper_hbox:
		return
	var tween := create_tween()
	tween.tween_property(chain_stepper_hbox, "modulate", Color(1.5, 1.5, 1.5, 1), 0.08)
	tween.tween_property(chain_stepper_hbox, "scale", Vector2(1.08, 1.08), 0.08)
	tween.tween_property(chain_stepper_hbox, "modulate", Color(1, 1, 1, 1), 0.15)
	tween.tween_property(chain_stepper_hbox, "scale", Vector2(1.0, 1.0), 0.15)


## 主页缓慢脉冲：预览模式下牌桌整体节奏呼吸
func home_pulse() -> void:
	if _home_pulse_tween and _home_pulse_tween.is_valid():
		return
	_home_pulse_tween = create_tween()
	_home_pulse_tween.set_loops()
	_home_pulse_tween.tween_property(self, "scale", Vector2(1.015, 1.015), 2.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_home_pulse_tween.tween_property(self, "scale", Vector2(1.0, 1.0), 2.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## OD Zone 标签闪烁：OD 区间变化时高亮
func flash_od_zone() -> void:
	if not od_zone_label:
		return
	var tween := create_tween()
	tween.tween_property(od_zone_label, "modulate", Color(2, 2, 2, 1), 0.08)
	tween.tween_property(od_zone_label, "modulate", Color(1, 1, 1, 1), 0.15)


# ============================================================
# OD Zone 视觉辅助函数
# ============================================================

## 根据 OD Zone 名称设置 OD 条和标签颜色（与 ODMode.ZONE_COLORS 对齐）
func _apply_zone_visuals(zone_name: String) -> void:
	var c: Color = TC.zone_color(zone_name)
	if od_bar:
		od_bar.modulate = c
	if od_zone_label:
		od_zone_label.add_theme_color_override("font_color", c)


## Zone 切换时的过渡动画：应用新视觉 + 简短脉冲闪烁
func play_zone_transition(_old_zone: String, new_zone: String) -> void:
	_apply_zone_visuals(new_zone)

	# 短暂脉冲高亮 OD Zone 标签
	if od_zone_label:
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(od_zone_label, "modulate", Color(2, 2, 2, 1), 0.1)
		tween.tween_property(od_zone_label, "scale", Vector2(1.15, 1.15), 0.1)
		tween.tween_property(od_zone_label, "modulate", Color(1, 1, 1, 1), 0.2).set_delay(0.1)
		tween.tween_property(od_zone_label, "scale", Vector2(1.0, 1.0), 0.2).set_delay(0.1)

	# OD 条短暂放大
	if od_bar:
		var t2 := create_tween()
		t2.tween_property(od_bar, "scale", Vector2(1.05, 1.15), 0.1)
		t2.tween_property(od_bar, "scale", Vector2(1.0, 1.0), 0.15)


## 将 OD Zone 英文名转为显示文本
func _get_zone_display_name(zone_name: String) -> String:
	match zone_name:
		"Calm":
			return "平稳"
		"Heated":
			return "升温"
		"Overdrive":
			return "超载"
		_:
			return zone_name


# ============================================================
# Preview 模式（主页使用，不需要真实 BattleContext）
# ============================================================

## 开启/关闭预览模式。预览模式下不依赖 _context / _player，
## 所有显示来自 set_preview_data 设置的数据。
func set_preview_mode(enabled: bool) -> void:
	_preview_mode = enabled
	# 隐藏战斗专属区域
	if hand_zone:
		hand_zone.visible = not enabled
	if end_turn_btn:
		end_turn_btn.visible = not enabled


## 设置预览模式下的显示数据
func set_preview_data(player_name: String, hp: int, od_value: int, od_zone_name: String) -> void:
	_preview_data["player_name"] = player_name
	_preview_data["hp"] = hp
	_preview_data["od_value"] = od_value
	_preview_data["od_zone_name"] = od_zone_name


# ============================================================
# 皮肤应用
# ============================================================

## 根据 TableConfig 对象应用桌面皮肤和 OD 核心颜色
func apply_table_config(config: TableConfig) -> void:
	if config == null:
		return
	_apply_table_skin(config.table_skin_id)
	_apply_od_core_skin(config.od_core_skin_id)
	# card_back_id 和 graveyard_skin_id 预留，后续接入 CardUI 和 GraveyardZone 时使用


## 应用桌面皮肤：修改 TableBG Panel 的 StyleBoxFlat 颜色
func _apply_table_skin(skin_id: String) -> void:
	if not table_bg:
		return
	var skin: Dictionary = TABLE_SKINS.get(skin_id, TABLE_SKINS["default_dark"])
	_current_table_skin_id = skin_id

	var style := StyleBoxFlat.new()
	style.bg_color = skin.get("bg_color", Color(0.06, 0.06, 0.1, 1))
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = skin.get("border_color", Color(0.15, 0.15, 0.25, 1))
	style.set_corner_radius_all(6)
	table_bg.add_theme_stylebox_override("panel", style)


## 应用 OD 核心皮肤：存储 ID，refresh_od / refresh_od_preview 中引用
func _apply_od_core_skin(skin_id: String) -> void:
	_current_od_core_skin_id = skin_id


# ============================================================
# 全量刷新
# ============================================================

func refresh() -> void:
	_refresh_header()
	_refresh_od()
	_refresh_trap()
	_refresh_chain()
	_refresh_deck()
	_refresh_graveyard()
	# Phase 1B：同步视觉槽位
	_refresh_front_row_visual()
	_refresh_back_row_visual()


# ============================================================
# 手牌重建
# ============================================================

func rebuild_hand(cards: Array) -> void:
	cards = _sorted_for_hand(cards)
	if _preview_mode:
		return

	# ── Phase 4B-6: 外部手牌宿主优先 ──
	if _hand_host and _hand_layout_external and is_instance_valid(_hand_layout_external):
		_hand_layout_external.clear_cards()
		for card in cards:
			if card == null:
				continue
			var ui: CardUI = CardUIScene.instantiate()
			ui.setup_hand(card)
			var card_status: Dictionary = {}
			if _can_play_check.is_valid():
				var status: Variant = _can_play_check.call(card)
				var ok: bool = false
				if status is Dictionary:
					card_status = (status as Dictionary).duplicate(true)
					ok = status.get("ok", true)
				elif status is bool:
					ok = status
				else:
					ok = true
				if ok:
					if card.rarity == CardData.CardRarity.SUPER:
						ui.start_finisher_glow()
					else:
						ui.set_playable()
				else:
					ui.set_unplayable()
			else:
				ui.set_playable()
			if ui.has_method("set_board_drag_context"):
				ui.set_board_drag_context(StringName(str(card_status.get("board_drag_intent", &"generic_drop"))), bool(card_status.get("contextual_board_drag", false)))
			ui.set_hand_readability(card_status.get("hand_facts",{}))
			if card_status.has("hand_facts"): _hand_layout_external.preferred_spacing=156.0
			ui.card_clicked.connect(_forward_card_clicked)
			ui.card_dropped.connect(_on_hand_card_dropped)
			ui.drag_started.connect(_on_hand_drag_started)
			ui.drag_ended.connect(_on_hand_drag_ended)
			ui.card_hovered.connect(_on_card_hovered_detail)
			ui.card_unhovered.connect(_on_card_unhovered_detail)
			ui.card_selected.connect(_on_card_selected_detail)
			_hand_layout_external.add_card(ui)
			# Phase 10E: 手牌动态
			_apply_hand_idle_vfx(card, ui)
		return

	# ── 内部手牌（兼容旧布局）──
	if not hand_zone:
		return
	# Clear old cards from both HandLayout and hand_zone
	if _hand_layout and is_instance_valid(_hand_layout):
		_hand_layout.clear_cards()
	for c in hand_zone.get_children():
		c.queue_free()
	for card in cards:
		if card == null:
			continue
		var ui: CardUI = CardUIScene.instantiate()
		# 战斗手牌使用极简模式：只显示卡名 + 卡图 + 状态
		# 完整信息在 hover / 右键 → CardDetailPanel 中显示
		ui.setup_hand(card)
		var card_status: Dictionary = {}

		# 可出性检查
		if _can_play_check.is_valid():
			var status: Variant = _can_play_check.call(card)
			var ok: bool = false
			if status is Dictionary:
				card_status = (status as Dictionary).duplicate(true)
				ok = status.get("ok", true)
			elif status is bool:
				ok = status
			else:
				ok = true
			if ok:
				if card.rarity == CardData.CardRarity.SUPER:
					ui.start_finisher_glow()
				else:
					ui.set_playable()
			else:
				# 手牌模式：不可用只灰掉，不在卡面写原因
				# 原因在 hover / 右键 → CardDetailPanel 中显示
				ui.set_unplayable()
		else:
			ui.set_playable()
		if ui.has_method("set_board_drag_context"):
			ui.set_board_drag_context(StringName(str(card_status.get("board_drag_intent", &"generic_drop"))), bool(card_status.get("contextual_board_drag", false)))
		ui.set_hand_readability(card_status.get("hand_facts",{}))
		if card_status.has("hand_facts") and is_instance_valid(_hand_layout): _hand_layout.preferred_spacing=156.0

		ui.card_clicked.connect(_forward_card_clicked)
		ui.card_dropped.connect(_on_hand_card_dropped)
		ui.drag_started.connect(_on_hand_drag_started)
		ui.drag_ended.connect(_on_hand_drag_ended)
		ui.card_hovered.connect(_on_card_hovered_detail)
		ui.card_unhovered.connect(_on_card_unhovered_detail)
		ui.card_selected.connect(_on_card_selected_detail)


		# Arrange cards in fan layout
		if _hand_layout:
			_hand_layout.add_card(ui)
			# Phase 10E: 手牌动态
			_apply_hand_idle_vfx(card, ui)
		else:
			hand_zone.add_child(ui)
			# Phase 10E: 手牌动态
			_apply_hand_idle_vfx(card, ui)


## Phase 22F-7: 返回手牌 CardUI 数量（供状态审计）
func get_hand_card_count() -> int:
	if _hand_host and _hand_layout_external and is_instance_valid(_hand_layout_external):
		return _hand_layout_external.get_card_count() if _hand_layout_external.has_method("get_card_count") else -1
	if _hand_layout:
		return _hand_layout.get_card_count() if _hand_layout.has_method("get_card_count") else -1
	return -1


## Phase 22F-7: 返回手牌可出性映射 {card_id: {card, playable}}
func get_hand_playability_map() -> Dictionary:
	var result: Dictionary = {}
	var cards := _get_hand_cards_from_layout()
	for card in cards:
		if card == null:
			continue
		var playable := true
		if _can_play_check.is_valid():
			var status: Variant = _can_play_check.call(card)
			if status is Dictionary:
				playable = status.get("ok", false)
			elif status is bool:
				playable = status
		result[card.card_id] = {"card": card, "playable": playable}
	return result


func _get_hand_cards_from_layout() -> Array:
	if _hand_host and _hand_layout_external and is_instance_valid(_hand_layout_external):
		if _hand_layout_external.has_method("get_cards"):
			return _hand_layout_external.get_cards()
	if _hand_layout and _hand_layout.has_method("get_cards"):
		return _hand_layout.get_cards()
	return []


# ============================================================
# 前场重建
# ============================================================

func rebuild_field(units: Array) -> void:
	if _preview_mode:
		return
	# Phase 1C：不再往旧 field_zone 塞 Label，只刷新 FrontRowVisual
	# 旧 field_zone 已在 _setup_zone_visual_slots 中设为 visible=false
	_refresh_front_row_visual()
	_refresh_back_row_visual()


# ============================================================
# Phase 1B：前场/后场视觉刷新
# ============================================================

## 将 _player.field 的 UNIT 映射到 FrontRowVisual 槽位
## Phase 4B-6D: 优先使用外部槽位
func _refresh_front_row_visual() -> void:
	# 外部槽位模式
	if _external_slots_set and not _external_front_slots.is_empty():
		_refresh_external_front_slots_centered(_external_front_slots, _player.field if _player and "field" in _player else [])
		# Phase 10B: 应用 OD 层槽位锁定
		_apply_front_slot_locks_from_context()
		return
	# 旧模式
	if not front_row_visual or front_slots.is_empty():
		return

	# 清除所有槽位
	for slot in front_slots:
		_clear_slot(slot)

	if _player and "field" in _player:
		var units: Array = _player.field
		for i in range(mini(units.size(), MAX_FRONT_SLOTS)):
			if units[i] != null:
				_populate_slot(front_slots[i], units[i])

	# Phase 10B: 无论是否有怪兽，都要应用槽位锁定
	_apply_front_slot_locks_from_context()


## Phase 10B: 从 context.od_mode 获取当前槽位限制并应用锁定
func _apply_front_slot_locks_from_context() -> void:
	var slot_limit := 5  # 默认全开
	if _context and _context.od_mode:
		slot_limit = _context.od_mode.get_front_slot_limit()
	apply_front_slot_locks(slot_limit)

## 将 _player.traps 的 TRAP 映射到 BackRowVisual 槽位
## Phase 4B-6D: 优先使用外部槽位
func _refresh_back_row_visual() -> void:
	# 外部槽位模式
	if _external_slots_set and not _external_back_slots.is_empty():
		_refresh_external_slots(_external_back_slots, _player.traps if _player and "traps" in _player else [])
		return
	# 旧模式
	if not back_row_visual or back_slots.is_empty():
		return

	# 清除所有槽位
	for slot in back_slots:
		_clear_slot(slot)

	if not _player or not "traps" in _player:
		return

	var traps: Array = _player.traps
	if traps.is_empty():
		return

	for i in range(mini(traps.size(), MAX_BACK_SLOTS)):
		if traps[i] != null:
			_populate_slot(back_slots[i], traps[i])

## Phase 4B-6D: 通用外部槽位刷新
func _refresh_external_slots(slots: Array[Control], cards: Array) -> void:
	for slot in slots:
		if slot == null or not is_instance_valid(slot):
			continue
		_clear_slot(slot)
	for i in range(mini(cards.size(), slots.size())):
		if slots[i] != null and is_instance_valid(slots[i]) and cards[i] != null:
			_populate_slot(slots[i], cards[i])


# ============================================================
# 内部刷新
# ============================================================

## Player front row uses Hearthstone-like centered placement:
## 1 card -> middle, 2 cards -> split around center, then expands outward.
func _refresh_external_front_slots_centered(slots: Array[Control], cards: Array) -> void:
	if _owner_side != "player":
		_refresh_external_slots(slots, cards)
		return
	for slot in slots:
		if slot == null or not is_instance_valid(slot):
			continue
		_clear_slot(slot)
	var count: int = mini(cards.size(), slots.size())
	if count <= 0:
		return
	var indices: Array[int] = get_centered_slot_indices(count, slots.size())
	for i in range(count):
		if i >= indices.size():
			break
		var slot_idx: int = indices[i]
		if slot_idx < 0 or slot_idx >= slots.size():
			continue
		if slots[slot_idx] != null and is_instance_valid(slots[slot_idx]) and cards[i] != null:
			_populate_slot(slots[slot_idx], cards[i])
	_compact_visible_front_slots(slots, indices)

## Phase 22F-5R: 公开中心阵型接口 — 将 N 张卡居中排列到 total 个槽位中
## 返回视觉槽位索引列表 [visual_slot_index, ...]
## 可用于 2D 展示 和 3D Token 定位
static func get_centered_slot_indices(count: int, total: int) -> Array[int]:
	return _get_centered_slot_indices_impl(count, total)

## 内部实现（保持与旧接口兼容）
static func _get_centered_slot_indices_impl(count: int, total: int) -> Array[int]:
	var result: Array[int] = []
	if total <= 0 or count <= 0:
		return result
	count = clampi(count, 1, total)
	var center: int = total / 2
	match count:
		1:
			result.append(center)
		2:
			result.append(maxi(0, center - 1))
			result.append(mini(total - 1, center + 1))
		3:
			result.append(maxi(0, center - 1))
			result.append(center)
			result.append(mini(total - 1, center + 1))
		4:
			# Phase 14C: fill 0,1,2,3 — natural left-to-right, one gap on far right
			result.append(maxi(0, center - 2))
			result.append(maxi(0, center - 1))
			result.append(center)
			result.append(mini(total - 1, center + 1))
		_:
			for i in range(total):
				result.append(i)
	return result



func _refresh_header() -> void:
	if _preview_mode:
		_refresh_header_preview()
		return
	if not _player:
		return

	if player_name_label:
		var name_str := ""
		if "player_name" in _player:
			name_str = _player.player_name
		elif _player is Player:
			name_str = "You"
		elif _player is Enemy:
			name_str = "Enemy"
		else:
			name_str = "Player"
		player_name_label.text = name_str

	if hp_label:
		if "hp" in _player:
			var hp_val: int = _player.hp
			var max_hp_val: int = _player.get("max_hp") if "max_hp" in _player else hp_val
			hp_label.text = "HP: %d/%d" % [hp_val, max_hp_val]
		else:
			hp_label.text = "HP: ?"

	# Boss 意图显示（含危险等级）
	if _intent_label:
		if _owner_side in ["enemy", "boss"] and _player is Enemy:
			var d: String = _player.intent_danger
			var prefix: String = ""
			match d:
				"OVERDRIVE": prefix = "⚠⚠ "
				"HIGH": prefix = "⚠ "
				"MID": prefix = ""
				_: prefix = ""
			_intent_label.text = prefix + _player.intent_text
			_intent_label.add_theme_color_override("font_color", _player.intent_color)
			_intent_label.visible = _player.intent_text != ""
		else:
			_intent_label.visible = false


func _refresh_header_preview() -> void:
	if player_name_label:
		player_name_label.text = _preview_data.get("player_name", "Player")
	if hp_label:
		hp_label.text = "HP: %d" % _preview_data.get("hp", 30)


func _refresh_od() -> void:
	if _preview_mode:
		_refresh_od_preview()
		return

	# 判断数据来源：_player（敌方）有独立OD / _context.od_mode（玩家）
	var use_player_od := _player_has_own_od()

	if not use_player_od and not _context:
		_apply_zone_visuals("Calm")
		return

	var current_val: int = 0
	var max_val: int = 10

	# OD Bar 数值
	if od_bar:
		if use_player_od:
			max_val = _player.get("max_od") if "max_od" in _player else 10
			current_val = _player.od
			od_bar.max_value = max_val
			od_bar.value = current_val
		else:
			if _context.has_method("get_od_max"):
				max_val = _context.get_od_max()
			if _context.has_method("get_current_od"):
				current_val = _context.get_current_od()
			od_bar.max_value = max_val
			od_bar.value = current_val

	# OD 数值标签
	if od_value_label:
		if _owner_side == "enemy":
			od_value_label.text = "Boss OD: %d/%d" % [current_val, max_val]
		else:
			od_value_label.text = "OD: %d/%d" % [current_val, max_val]

	# Zone 名称
	var current_zone := "Calm"
	if use_player_od:
		if _player.has_method("get_od_zone_name"):
			current_zone = _player.get_od_zone_name()
	else:
		if _context.has_method("get_od_zone_name"):
			current_zone = _context.get_od_zone_name()

	# Zone 变化检测
	if last_zone_name != "" and last_zone_name != current_zone:
		play_zone_transition(last_zone_name, current_zone)
	elif last_zone_name == "":
		_apply_zone_visuals(current_zone)

	last_zone_name = current_zone

	# Phase 4C-4B: 更新分段仪表
	_update_od_segments(current_val, current_zone)

	# OD Zone 标签文字（中文）
	if od_zone_label:
		od_zone_label.text = _get_zone_display_name(current_zone)

	# 颜色
	if od_bar:
		if use_player_od and _player.has_method("get_od_zone_color"):
			od_bar.modulate = _player.get_od_zone_color()
		elif _context.has_method("get_od_zone_color"):
			od_bar.modulate = _context.get_od_zone_color()

	if od_zone_label:
		if use_player_od and _player.has_method("get_od_zone_color"):
			od_zone_label.add_theme_color_override("font_color", _player.get_od_zone_color())
		elif _context.has_method("get_od_zone_color"):
			od_zone_label.add_theme_color_override("font_color", _context.get_od_zone_color())

	# OD 数值标签颜色跟随 Zone
	if od_value_label:
		var zone_color := Color(0.3, 0.5, 1, 1)
		if use_player_od and _player.has_method("get_od_zone_color"):
			zone_color = _player.get_od_zone_color()
		elif _context.has_method("get_od_zone_color"):
			zone_color = _context.get_od_zone_color()
		od_value_label.add_theme_color_override("font_color", zone_color)

	# Load 刷新
	_refresh_load()


## 判断绑定的 _player 是否有独立的 OD 系统（敌方/Boss）
func _player_has_own_od() -> bool:
	if not _player:
		return false
	return "od" in _player and _player.has_method("modify_od")


func _refresh_od_preview() -> void:
	var skin: Dictionary = OD_CORE_SKINS.get(_current_od_core_skin_id, OD_CORE_SKINS["default_core"])

	if od_bar:
		od_bar.max_value = 10
		od_bar.value = _preview_data.get("od_value", 0)
		od_bar.modulate = skin.get("bar_tint", Color(0.3, 0.5, 1, 1))

	if od_zone_label:
		od_zone_label.text = _preview_data.get("od_zone_name", "Calm")
		od_zone_label.add_theme_color_override("font_color", skin.get("calm_color", Color(0.3, 0.5, 1, 1)))

	if od_value_label:
		od_value_label.text = "OD: %d/10" % _preview_data.get("od_value", 0)


# ============================================================
# Load 显示
# ============================================================
func _refresh_load() -> void:
	if _preview_mode:
		if load_label:
			load_label.visible = false
		return

	if not load_label:
		return

	# 仅玩家需要显示 Load（敌方无 Load 系统）
	if not _owner_side in ["player"]:
		load_label.visible = false
		return

	if _context and _context.od_mode:
		var info: Dictionary = _context.od_mode.get_load_info()
		var current_load: int = info.get("current", 0)
		var limit_load: int = info.get("limit", 5)
		load_label.text = "Load: %d/%d" % [current_load, limit_load]
		load_label.visible = true

		# 接近过载时变色警告
		if current_load >= limit_load:
			load_label.add_theme_color_override("font_color", Color(1, 0.15, 0.05, 1))
		elif current_load >= limit_load - 1:
			load_label.add_theme_color_override("font_color", Color(1, 0.5, 0.1, 1))
		else:
			load_label.add_theme_color_override("font_color", Color(0.9, 0.7, 0.3, 1))
	else:
		load_label.text = "Load: 0/5"
		load_label.visible = _owner_side == "player"


func _refresh_trap() -> void:
	if _preview_mode:
		return
	# Phase 1C：不再往旧 trap_zone 塞 Label，只刷新 BackRowVisual
	# 旧 trap_zone 已在 _setup_zone_visual_slots 中设为 visible=false
	_refresh_back_row_visual()

func _refresh_chain() -> void:
	# Phase 23A-R: 3D mode - route only in ThisTurn/ActionFeed
	if _3d_chain_stepper_hidden:
		if chain_stepper_hbox and is_instance_valid(chain_stepper_hbox):
			chain_stepper_hbox.visible = false
		return

	if _preview_mode:
		if chain_stepper_hbox:
			chain_stepper_hbox.visible = false
		return

	var cs = _context.chain_system if _context else null
	if not cs:
		if chain_stepper_hbox:
			chain_stepper_hbox.visible = false
		return

	# 确保 stepper 可见
	if chain_stepper_hbox:
		chain_stepper_hbox.visible = true

	var route_id: String = cs.current_route_id
	if route_id == "":
		_clear_chain_stepper()
		if chain_name_label:
			chain_name_label.text = "—"
			chain_name_label.add_theme_color_override("font_color", TC.TEXT_DIM)
		return

	# ── 路线名称 ──
	var route_color := TC.route_color(route_id)
	var route_name: String = cs.get_route_display_name()

	# 从 route_definitions 获取总步数
	var total_steps: int = 4
	var def: Dictionary = cs.route_definitions.get(route_id, {})
	if not def.is_empty():
		total_steps = def.get("total_steps", 4)

	var current_step: int = cs.current_step

	# ── 重建步进器 ──
	_clear_chain_stepper()
	if chain_name_label and chain_stepper_hbox:
		chain_name_label.text = route_name
		chain_name_label.add_theme_color_override("font_color", route_color)

	for i in range(1, total_steps + 1):
		var block := ColorRect.new()
		block.custom_minimum_size = Vector2(14, 14)
		block.name = "Step%d" % i

		var style := StyleBoxFlat.new()
		style.set_corner_radius_all(3)

		if i <= current_step:
			# 已完成：路线色实心
			style.bg_color = route_color
			style.border_width_left = 1
			style.border_width_right = 1
			style.border_width_top = 1
			style.border_width_bottom = 1
			style.border_color = route_color.lightened(0.2)
		elif i == current_step + 1:
			# 当前步骤：白色边框 + 脉冲
			style.bg_color = Color(route_color.r, route_color.g, route_color.b, 0.3)
			style.border_width_left = 2
			style.border_width_right = 2
			style.border_width_top = 2
			style.border_width_bottom = 2
			style.border_color = route_color
		else:
			# 未激活：灰色
			style.bg_color = Color(0.12, 0.12, 0.18, 1)
			style.border_width_left = 1
			style.border_width_right = 1
			style.border_width_top = 1
			style.border_width_bottom = 1
			style.border_color = TC.BORDER_DEFAULT

		block.add_theme_stylebox_override("panel", style)
		chain_stepper_hbox.add_child(block)
		chain_stepper_blocks.append(block)

		# 步骤间连接线（除最后一步）
		if i < total_steps:
			var connector := Label.new()
			connector.text = "›"
			connector.add_theme_font_size_override("font_size", 14)
			connector.add_theme_color_override("font_color",
				route_color if i < current_step else TC.TEXT_DIM)
			chain_stepper_hbox.add_child(connector)
			chain_stepper_blocks.append(connector)

	# ── 下一步推荐卡 ──
	var next_cards: Array[String] = cs.get_next_cards()
	if not next_cards.is_empty() and chain_stepper_hbox:
		var next_label := Label.new()
		next_label.text = " → %s" % ", ".join(next_cards)
		next_label.add_theme_font_size_override("font_size", 11)
		next_label.add_theme_color_override("font_color", route_color)
		chain_stepper_hbox.add_child(next_label)
		chain_stepper_blocks.append(next_label)


func _clear_chain_stepper() -> void:
	if not chain_stepper_hbox:
		return
	# 移除除 chain_name_label 外的所有子节点
	var to_remove: Array = []
	for c in chain_stepper_hbox.get_children():
		if c != chain_name_label:
			to_remove.append(c)
	for c in to_remove:
		if is_instance_valid(c):
			c.queue_free()
	chain_stepper_blocks.clear()


func _refresh_deck() -> void:
	if not deck_zone:
		return
	var count := 0
	if _player and "deck" in _player:
		count = _player.deck.size()
	deck_zone.text = "牌库:%d" % count
	deck_zone.add_theme_font_size_override("font_size", 10)


func _refresh_graveyard() -> void:
	if not graveyard_zone:
		return
	var count := 0
	if _player and "graveyard" in _player:
		count = _player.graveyard.size()
	graveyard_zone.text = "墓地:%d" % count
	graveyard_zone.add_theme_font_size_override("font_size", 10)


# ============================================================
# 信号转发
# ============================================================

func _forward_card_clicked(card_ui: CardUI) -> void:
	card_clicked.emit(card_ui)


func _on_end_turn_internal() -> void:
	if _end_turn_callable.is_valid():
		_end_turn_callable.call()
	end_turn_pressed.emit()


# Phase 10A: Boss 本体区域点击 → 发射 boss_area_clicked
func _on_boss_area_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		boss_area_clicked.emit(_owner_side)


func _on_od_changed(_new_od: int, _new_phase: int, _zone: int) -> void:
	_refresh_od()

# ============================================================
# Phase 4C-4B: OD 分段仪表 — 10 格过热核心风格
# ============================================================
func _create_od_segmented_bar() -> void:
	if _od_segment_container and is_instance_valid(_od_segment_container):
		return
	var main_vbox := _safe_node("MarginContainer/MainVBox") as VBoxContainer
	if not main_vbox:
		return
	var container := HBoxContainer.new()
	container.name = "ODSegmentBar"
	container.alignment = BoxContainer.ALIGNMENT_CENTER
	container.add_theme_constant_override("separation", 3)
	container.custom_minimum_size = Vector2(0, 20)
	main_vbox.add_child(container)
	if depth_label and is_instance_valid(depth_label):
		main_vbox.move_child(container, depth_label.get_index() + 1)
	_od_segment_container = container

	_od_segment_glow = ColorRect.new()
	_od_segment_glow.name = "ODGlow"
	_od_segment_glow.color = Color(0.2, 0.4, 0.8, 0.18)
	_od_segment_glow.custom_minimum_size = Vector2(0, 22)
	_od_segment_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(_od_segment_glow)

	_od_segments.clear()
	for seg_i in range(10):
		var seg := ColorRect.new()
		seg.name = "ODSeg%d" % seg_i
		seg.custom_minimum_size = Vector2(16, 14)
		seg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var style := StyleBoxFlat.new()
		style.set_corner_radius_all(2)
		seg.add_theme_stylebox_override("panel", style)
		container.add_child(seg)
		_od_segments.append(seg)

	_od_delta_label = Label.new()
	_od_delta_label.name = "ODDeltaLabel"
	_od_delta_label.text = ""
	_od_delta_label.add_theme_font_size_override("font_size", 10)
	_od_delta_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_od_delta_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_od_delta_label.modulate.a = 0.0
	container.add_child(_od_delta_label)
	print("[OD Segments] Created 10-segment OD bar")


func _update_od_segments(current_od: int, zone_name: String) -> void:
	if _od_segments.is_empty():
		return
	for seg_i in range(_od_segments.size()):
		var seg := _od_segments[seg_i]
		if not is_instance_valid(seg):
			continue
		var style: StyleBoxFlat = seg.get_theme_stylebox("panel", "ColorRect") as StyleBoxFlat
		if not style:
			style = StyleBoxFlat.new()
			style.set_corner_radius_all(2)
		var filled := seg_i < current_od
		var color: Color
		if seg_i <= 2:
			color = TC.ZONE_CALM if filled else Color(0.08, 0.12, 0.22, 1)
		elif seg_i <= 6:
			color = TC.ZONE_HEATED if filled else Color(0.18, 0.08, 0.04, 1)
		else:
			color = TC.ZONE_OVERDRIVE if filled else Color(0.15, 0.03, 0.08, 1)
		style.bg_color = color
		style.border_width_left = 1
		style.border_width_right = 1
		style.border_width_top = 1
		style.border_width_bottom = 1
		style.border_color = color.lightened(0.3) if filled else Color(0.1, 0.1, 0.12, 1)
		seg.add_theme_stylebox_override("panel", style)

	if _od_segment_glow and is_instance_valid(_od_segment_glow):
		var glow_color: Color = TC.zone_color(zone_name)
		glow_color.a = 0.22
		_od_segment_glow.color = glow_color


func show_od_delta(delta: int) -> void:
	if not _od_delta_label or not is_instance_valid(_od_delta_label):
		return
	_od_delta_label.text = "OD %+d" % delta
	_od_delta_label.modulate.a = 1.0
	var t := create_tween()
	t.tween_property(_od_delta_label, "position:y", _od_delta_label.position.y - 14, 0.6)
	t.parallel().tween_property(_od_delta_label, "modulate:a", 0.0, 0.6)
	t.tween_callback(_reset_od_delta_label)


func _reset_od_delta_label() -> void:
	if _od_delta_label and is_instance_valid(_od_delta_label):
		_od_delta_label.position.y += 14


func show_depth_delta(delta: int) -> void:
	if not depth_label or not is_instance_valid(depth_label):
		return
	if not _depth_delta_label or not is_instance_valid(_depth_delta_label):
		_depth_delta_label = Label.new()
		_depth_delta_label.name = "DepthDeltaLabel"
		_depth_delta_label.add_theme_font_size_override("font_size", 10)
		_depth_delta_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_depth_delta_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		depth_label.get_parent().add_child(_depth_delta_label)
		_depth_delta_label.position = depth_label.position + Vector2(40, 0)
	_depth_delta_label.text = "D %+d" % delta
	_depth_delta_label.modulate.a = 1.0
	var t := create_tween()
	t.tween_property(_depth_delta_label, "position:y", _depth_delta_label.position.y - 12, 0.6)
	t.parallel().tween_property(_depth_delta_label, "modulate:a", 0.0, 0.6)
	t.tween_callback(_reset_depth_delta_label)


func _reset_depth_delta_label() -> void:
	if _depth_delta_label and is_instance_valid(_depth_delta_label):
		_depth_delta_label.position.y += 12


func _set_abyss_lock_visual(locked: bool) -> void:
	if locked:
		if not _abyss_lock_indicator or not is_instance_valid(_abyss_lock_indicator):
			if not depth_label or not is_instance_valid(depth_label):
				return
			_abyss_lock_indicator = ColorRect.new()
			_abyss_lock_indicator.name = "AbyssLockIndicator"
			_abyss_lock_indicator.color = Color(0.6, 0.1, 0.5, 0.4)
			_abyss_lock_indicator.custom_minimum_size = Vector2(120, 18)
			_abyss_lock_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
			depth_label.get_parent().add_child(_abyss_lock_indicator)
			_abyss_lock_indicator.position = depth_label.position
		if _abyss_lock_tween and _abyss_lock_tween.is_valid():
			_abyss_lock_tween.kill()
		_abyss_lock_tween = create_tween()
		_abyss_lock_tween.set_loops()
		_abyss_lock_tween.tween_property(_abyss_lock_indicator, "modulate:a", 0.6, 0.5).set_trans(Tween.TRANS_SINE)
		_abyss_lock_tween.tween_property(_abyss_lock_indicator, "modulate:a", 0.15, 0.5).set_trans(Tween.TRANS_SINE)
	else:
		if _abyss_lock_tween and _abyss_lock_tween.is_valid():
			_abyss_lock_tween.kill()
			_abyss_lock_tween = null
		if _abyss_lock_indicator and is_instance_valid(_abyss_lock_indicator):
			_abyss_lock_indicator.queue_free()
			_abyss_lock_indicator = null


# ============================================================
# Phase 5B-1: 建筑充能显示辅助
# ============================================================

func _get_building_charge_text(card: CardData) -> String:
	if not card.is_building_card():
		return ""
	# 尝试从 BattleSystem 获取状态
	var battle_sys = null
	if _context and _context.get_parent():
		for child in _context.get_parent().get_children():
			if child is BattleSystem:
				battle_sys = child
				break
	if battle_sys and battle_sys.has_method("get_building_state"):
		var state: Dictionary = battle_sys.get_building_state(card)
		if not state.is_empty():
			var used := " [USED]" if state.get("used_this_turn", false) else ""
			match card.card_name:
				"Reactor Foundation": return "Charge %d/%d%s" % [state["charge"], state["charge_max"], used]
				"Pressure Relay": return "Pressure %d/%d%s" % [state["charge"], state["charge_max"], used]
				"Heat Sink": return "Coolant %d/%d%s" % [state["charge"], state["charge_max"], used]
				"Containment Wall": return "Active%s" % used
				"Core Cathedral": return "Charge %d/%d%s" % [state["charge"], state["charge_max"], used]
			return "Charge %d/%d%s" % [state["charge"], state["charge_max"], used]
	return ""

func refresh_building_charge_display() -> void:
	_refresh_back_row_visual()


# ============================================================
# Phase 5E-4: 建筑状态标签与点击反馈
# ============================================================

## 在建筑槽位上添加状态标签（ACT/USED/LOCK）
func _add_building_status_label(slot: Control, card: CardData, slot_panel: Panel) -> void:
	if _3d_status_tags_hidden: return
	# 移除旧标签
	_remove_building_status_label(slot)

	var status := _query_building_status(card)
	var label := Label.new()
	label.name = "BuildingStatusLabel"
	label.add_theme_font_size_override("font_size", 9)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# 定位在卡面左上角
	label.anchor_left = 1.0
	label.anchor_top = 1.0
	label.offset_left = -44
	label.offset_top = -18
	label.custom_minimum_size = Vector2(40, 14)

	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(2)

	if status.get("ok", false):
		# 可发动 — ACT 标签，铜金色
		label.text = "ACT"
		style.bg_color = Color(0.7, 0.35, 0.05, 0.88)
		label.add_theme_color_override("font_color", Color(1, 0.95, 0.7, 1))
	elif status.get("reason", "") == "本回合已使用":
		# 本回合已用 — USED 标签，灰色
		label.text = "USED"
		style.bg_color = Color(0.3, 0.3, 0.35, 0.7)
		label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65, 1))
	else:
		# 条件不足 — LOCK 标签，暗红
		label.text = "LOCK"
		style.bg_color = Color(0.4, 0.1, 0.08, 0.7)
		label.add_theme_color_override("font_color", Color(0.9, 0.5, 0.4, 1))

	label.add_theme_stylebox_override("normal", style)
	# 放在 slot_panel 上面（在 CardUI 之上）
	slot.add_child(label)
	label.z_index = 10

	# 可发动时添加微弱发光脉冲
	if status.get("ok", false) and slot_panel and is_instance_valid(slot_panel):
		var act_tween: Tween = create_tween()
		act_tween.set_loops(3)
		act_tween.tween_property(slot_panel, "modulate", Color(1.3, 1.1, 0.7, 1), 0.4).set_trans(Tween.TRANS_SINE)
		act_tween.tween_property(slot_panel, "modulate", Color(1, 1, 1, 1), 0.6).set_trans(Tween.TRANS_SINE)


func _remove_building_status_label(slot: Control) -> void:
	var old := slot.get_node_or_null("BuildingStatusLabel")
	if old and is_instance_valid(old):
		old.queue_free()


## 查询建筑接口状态（无副作用）
	# Phase 7A-3: 前场槽位解锁/锁定可视化

# Phase 10B: 前场槽位三态视觉 — Active / Locked / Sealed
## slot_limit: 当前 OD 层允许的可用前场槽位数
func apply_front_slot_locks(slot_limit: int) -> void:
	# Phase 23A-R: 3D 模式下不再 return — OD 槽位容量与规则照常计算
	# 只禁止旧 2D 表现生成（SlotPanel / LockLabel / SealOverlay / visible / modulate）
	if _owner_side != "player":
		# Boss 侧不锁定，全槽位高在线
		_apply_boss_full_slots()
		return
	var slots: Array[Control] = _external_front_slots if (_external_slots_set and not _external_front_slots.is_empty()) else front_slots
	var card_count := 0
	if _player and "field" in _player:
		card_count = mini(_player.field.size(), slots.size())
	var display_count: int = clampi(slot_limit, 1, slots.size())  # Phase 18H-3: show full OD-layer slot capacity
	var active_indices: Array[int] = get_centered_slot_indices(display_count, slots.size())
	for i in range(slots.size()):
		var slot := slots[i]
		if not is_instance_valid(slot):
			continue
		var has_card := _slot_has_card(slot)

		if active_indices.has(i) or has_card:
			# ── Active: 可用槽位 ──
			if not _3d_status_tags_hidden:
				slot.visible = true
				slot.modulate = Color(1, 1, 1, 1)
				_remove_slot_lock_label(slot)
				_remove_slot_seal(slot)
				if not has_card:
					var slot_panel := slot.get_node_or_null("SlotPanel") as Panel
					if slot_panel and is_instance_valid(slot_panel):
						_apply_slot_panel_style(slot_panel, Color(0.03, 0.08, 0.18, 0.40), Color(0.08, 0.35, 0.55, 0.30))  # Phase 18H-3: table recess, not bright box
			slot.mouse_filter = Control.MOUSE_FILTER_STOP
		elif i < 5:
			# ── Locked: 已规划但当前层未解锁 ──
			if not _3d_status_tags_hidden:
				slot.visible = false
				var unlock_layer: int = _get_unlock_layer_for_slot_index(i)
				slot.modulate = Color(0.3, 0.3, 0.3, 1)
				_ensure_slot_seal(slot, unlock_layer)
				_ensure_slot_lock_label(slot, unlock_layer)
				if not has_card:
					var slot_panel := slot.get_node_or_null("SlotPanel") as Panel
					if slot_panel and is_instance_valid(slot_panel):
						_apply_slot_panel_style(slot_panel, Color(0.03, 0.03, 0.06, 0.30), Color(0.12, 0.10, 0.20, 0.15))
			slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		else:
			# ── Sealed: 超远槽位几乎不可见 ──
			if not _3d_status_tags_hidden:
				slot.visible = false
				slot.modulate = Color(0.08, 0.08, 0.08, 1)
				_remove_slot_lock_label(slot)
				_ensure_slot_seal(slot, -1)
				if not has_card:
					var slot_panel := slot.get_node_or_null("SlotPanel") as Panel
					if slot_panel and is_instance_valid(slot_panel):
						_apply_slot_panel_style(slot_panel, Color(0.02, 0.02, 0.03, 0.10), Color(0.05, 0.05, 0.08, 0.05))
			slot.mouse_filter = Control.MOUSE_FILTER_IGNORE


# ── Active/Locked/Sealed 辅助方法 ──
func _compact_visible_front_slots(slots: Array[Control], active_indices: Array[int]) -> void:
	if _owner_side != "player" or slots.is_empty():
		return
	var host := slots[0].get_parent() as Control
	if host == null or not is_instance_valid(host):
		return
	if host.size.x <= 0 or host.size.y <= 0:
		return

	var visible_indices: Array[int] = []
	for i in range(slots.size()):
		var slot := slots[i]
		if slot == null or not is_instance_valid(slot):
			continue
		if slot.visible and (active_indices.has(i) or _slot_has_card(slot)):
			visible_indices.append(i)
	if visible_indices.is_empty():
		return

	var sample_slot := slots[visible_indices[0]]
	var slot_size := sample_slot.size
	if slot_size.x <= 0 or slot_size.y <= 0:
		slot_size = sample_slot.custom_minimum_size
	if slot_size.x <= 0 or slot_size.y <= 0:
		slot_size = Vector2(136, 96)

	var gap := 14.0
	var total_w: float = float(visible_indices.size()) * slot_size.x + float(max(0, visible_indices.size() - 1)) * gap
	var start_x := maxf(0.0, (host.size.x - total_w) * 0.5)
	var y := maxf(0.0, (host.size.y - slot_size.y) * 0.5)

	for order in range(visible_indices.size()):
		var slot_idx: int = visible_indices[order]
		var slot := slots[slot_idx]
		if slot == null or not is_instance_valid(slot):
			continue
		slot.position = Vector2(start_x + order * (slot_size.x + gap), y)


func _apply_slot_panel_style(slot_panel: Panel, bg: Color, border: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_color = border
	style.set_corner_radius_all(4)
	slot_panel.add_theme_stylebox_override("panel", style)


func _ensure_slot_lock_label(slot: Control, unlock_layer: int) -> void:
	var existing: Label = slot.get_node_or_null(NodePath("LockLabel"))
	if not existing:
		existing = Label.new()
		existing.name = "LockLabel"
		existing.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		existing.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		existing.set_anchors_preset(Control.PRESET_CENTER)
		existing.mouse_filter = Control.MOUSE_FILTER_IGNORE
		existing.custom_minimum_size = Vector2(60, 18)
		existing.z_index = 8
		slot.add_child(existing)
	existing.text = "L%d" % unlock_layer if unlock_layer >= 2 else "SEAL"
	existing.add_theme_font_size_override("font_size", 7)
	existing.add_theme_color_override("font_color", Color(0.30, 0.22, 0.14, 0.75))
	existing.visible = true


func _remove_slot_lock_label(slot: Control) -> void:
	var existing: Label = slot.get_node_or_null(NodePath("LockLabel"))
	if existing and is_instance_valid(existing):
		existing.visible = false


func _ensure_slot_seal(slot: Control, _unlock_layer: int) -> void:
	if slot.get_node_or_null("SealOverlay"):
		return
	var seal := ColorRect.new()
	seal.name = "SealOverlay"
	seal.set_anchors_preset(Control.PRESET_FULL_RECT)
	seal.color = Color(0.04, 0.03, 0.08, 0.72)
	seal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	seal.z_index = 5
	# Phase 18H-3: mechanical cross-bars for device-like seal plate
	var cross_h := ColorRect.new()
	cross_h.name = "SealCrossH"
	cross_h.set_anchors_preset(Control.PRESET_CENTER)
	cross_h.color = Color(0.10, 0.08, 0.13, 0.55)
	cross_h.custom_minimum_size = Vector2(0, 4)
	cross_h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cross_h.anchor_left = 0.1
	cross_h.anchor_right = 0.9
	seal.add_child(cross_h)
	var cross_v := ColorRect.new()
	cross_v.name = "SealCrossV"
	cross_v.set_anchors_preset(Control.PRESET_CENTER)
	cross_v.color = Color(0.10, 0.08, 0.13, 0.55)
	cross_v.custom_minimum_size = Vector2(4, 0)
	cross_v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cross_v.anchor_top = 0.1
	cross_v.anchor_bottom = 0.9
	seal.add_child(cross_v)
	var bolt := ColorRect.new()
	bolt.name = "SealBolt"
	bolt.set_anchors_preset(Control.PRESET_CENTER)
	bolt.color = Color(0.22, 0.17, 0.10, 0.7)
	bolt.custom_minimum_size = Vector2(12, 12)
	bolt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	seal.add_child(bolt)
	slot.add_child(seal)


func _remove_slot_seal(slot: Control) -> void:
	var seal := slot.get_node_or_null("SealOverlay")
	if seal and is_instance_valid(seal):
		seal.queue_free()


func _get_unlock_layer_for_slot_index(idx: int) -> int:
	if idx <= 1:
		return 1
	elif idx == 2:
		return 2
	elif idx == 3:
		return 3
	else:
		return 4


func _apply_boss_full_slots() -> void:
	var use_external := _external_slots_set and not _external_front_slots.is_empty()
	var slots: Array[Control] = _external_front_slots if use_external else front_slots
	for i in range(slots.size()):
		var slot := slots[i]
		if not is_instance_valid(slot):
			continue
		slot.visible = true
		slot.modulate = Color(1, 1, 1, 1)
		_remove_slot_lock_label(slot)
		_remove_slot_seal(slot)
		var slot_panel := slot.get_node_or_null("SlotPanel") as Panel
		if slot_panel and is_instance_valid(slot_panel):
			_apply_slot_panel_style(slot_panel, Color(0.08, 0.02, 0.03, 0.75), Color(0.72, 0.18, 0.08, 0.80))  # Phase 18H-3: Boss vermilion device slot
		slot.mouse_filter = Control.MOUSE_FILTER_STOP


func _slot_has_card(slot: Control) -> bool:
	for c in slot.get_children():
		if c is CardUI:
			return true
	return false


# Phase 10B: 槽位解锁脉冲动画
func play_slot_unlock_pulse(slot_index: int) -> void:
	var slot: Control = null
	var use_external := _external_slots_set and not _external_front_slots.is_empty()
	if use_external:
		if slot_index < _external_front_slots.size():
			slot = _external_front_slots[slot_index]
	else:
		if slot_index < front_slots.size():
			slot = front_slots[slot_index]
	if not slot or not is_instance_valid(slot):
		return
	# Phase 18H-3: seal-breaking fade before removal
	var seal_overlay = slot.get_node_or_null("SealOverlay")
	if seal_overlay and is_instance_valid(seal_overlay):
		var seal_fade: Tween = create_tween()
		seal_fade.tween_property(seal_overlay, "modulate:a", 0.0, 0.25)
		seal_fade.tween_callback(_remove_slot_seal.bind(slot))
	else:
		_remove_slot_seal(slot)
	# 清除锁定状态（视觉）
	slot.modulate = Color(1, 1, 1, 1)
	_remove_slot_lock_label(slot)
	slot.mouse_filter = Control.MOUSE_FILTER_STOP
	# 解锁脉冲：边框短暂亮起
	var slot_panel := slot.get_node_or_null("SlotPanel") as Panel
	if slot_panel and is_instance_valid(slot_panel):
		var t: Tween = create_tween()
		t.tween_property(slot_panel, "modulate", Color(1.8, 1.6, 0.3, 1), 0.12)
		t.tween_property(slot_panel, "modulate", Color(0.8, 0.9, 1.0, 1), 0.2)
		t.tween_property(slot_panel, "modulate", Color(1, 1, 1, 1), 0.25)
		# 应用 Active 空槽底框
		_apply_slot_panel_style(slot_panel, Color(0.03, 0.08, 0.18, 0.40), Color(0.08, 0.35, 0.55, 0.30))  # Phase 18H-3: table recess, not bright box
	# L5 burst: 所有槽位一次短促全体脉冲
	if slot_index >= 4:
		# 已全解锁，给所有 active 槽一次 energized pulse
		_pulse_all_active_slots()

func _pulse_all_active_slots() -> void:
	var use_external := _external_slots_set and not _external_front_slots.is_empty()
	var slots: Array[Control] = _external_front_slots if use_external else front_slots
	for i in range(slots.size()):
		if not is_instance_valid(slots[i]):
			continue
		var sp := slots[i].get_node_or_null("SlotPanel") as Panel
		if sp and is_instance_valid(sp):
			var t: Tween = create_tween()
			t.tween_property(sp, "modulate", Color(1.3, 1.5, 0.6, 1), 0.1)
			t.tween_property(sp, "modulate", Color(1, 1, 1, 1), 0.3)


func _query_building_status(card: CardData) -> Dictionary:
	# 尝试从 BattleSystem 获取状态
	var battle_sys = _find_battle_system()
	if battle_sys and battle_sys.has_method("get_building_interface_status"):
		return battle_sys.get_building_interface_status(card, _player)
	return {"ok": false, "reason": "无法查询", "cost": "", "preview": ""}


## 查找 BattleSystem 引用
func _find_battle_system():
	if _context and _context.get_parent():
		for child in _context.get_parent().get_children():
			if child is BattleSystem:
				return child
	return null


## Phase 5E-4: 建筑成功脉冲动画
func play_building_activate_pulse(slot: Control) -> void:
	if not slot or not is_instance_valid(slot):
		return
	var slot_panel := slot.get_node_or_null("SlotPanel") as Panel
	if slot_panel and is_instance_valid(slot_panel):
		var t: Tween = create_tween()
		t.tween_property(slot_panel, "modulate", Color(1.6, 1.3, 0.5, 1), 0.1)
		t.tween_property(slot_panel, "modulate", Color(0.8, 0.6, 0.3, 1), 0.15)
		t.tween_property(slot_panel, "modulate", Color(1, 1, 1, 1), 0.25)
	# CardUI 缩放脉冲
	var card_ui := slot.get_node_or_null("CardUI")
	if card_ui and is_instance_valid(card_ui) and card_ui.has_method("play_entry_pulse"):
		card_ui.play_entry_pulse()


## Phase 5E-4: 建筑点击拒绝动画（抖动）
func play_building_denied_shake(slot: Control) -> void:
	if not slot or not is_instance_valid(slot):
		return
	var card_ui := slot.get_node_or_null("CardUI")
	if card_ui and is_instance_valid(card_ui):
		var orig_pos: Vector2 = card_ui.position
		var t: Tween = create_tween()
		t.tween_property(card_ui, "position:x", orig_pos.x - 4, 0.05)
		t.tween_property(card_ui, "position:x", orig_pos.x + 4, 0.05)
		t.tween_property(card_ui, "position:x", orig_pos.x - 3, 0.05)
		t.tween_property(card_ui, "position:x", orig_pos.x + 3, 0.05)
		t.tween_property(card_ui, "position:x", orig_pos.x, 0.05)
	# 槽位短暂红闪
	var slot_panel := slot.get_node_or_null("SlotPanel") as Panel
	if slot_panel and is_instance_valid(slot_panel):
		var t2: Tween = create_tween()
		t2.tween_property(slot_panel, "modulate", Color(1.4, 0.3, 0.3, 1), 0.08)
		t2.tween_property(slot_panel, "modulate", Color(1, 1, 1, 1), 0.2)


## 根据卡牌找到对应的后场槽位
func find_back_slot_for_card(card: CardData) -> Control:
	if not _player or not "traps" in _player:
		return null
	var traps: Array = _player.traps
	var slots := _external_back_slots if _external_slots_set else back_slots
	for i in range(mini(traps.size(), slots.size())):
		if traps[i] == card:
			if i < slots.size():
				return slots[i]
	return null

# ============================================================
# Phase 10A: 怪兽攻击视觉反馈辅助
# ============================================================


# Phase 21G: Toggle 2D field card visibility.
# When false, hide all CardUI children and SlotPanel backgrounds in field slots.
# Slot Controls remain as invisible hit-test fallback targets.
func set_field_cards_visible(v: bool) -> void:
	_field_cards_visible = v
	var use_external := _external_slots_set and not _external_front_slots.is_empty()
	var all_slots: Array[Control] = []
	if use_external:
		all_slots.append_array(_external_front_slots)
		all_slots.append_array(_external_back_slots)
	else:
		all_slots.append_array(front_slots)
		all_slots.append_array(back_slots)
	for slot in all_slots:
		if not is_instance_valid(slot):
			continue
		# Hide/show CardUI children
		for child in slot.get_children():
			if child is CardUI and is_instance_valid(child):
				child.visible = v
		# Hide/show SlotPanel background
		var panel := slot.get_node_or_null(NodePath("SlotPanel")) as Panel
		if panel and is_instance_valid(panel):
			panel.visible = v

## Phase 23A-R: 隐藏/显示路线步进器（3D 模式下 Route 仅写入 ThisTurn/ActionFeed）
func set_chain_stepper_visible(v: bool) -> void:
	_3d_chain_stepper_hidden = not v
	if chain_stepper_hbox and is_instance_valid(chain_stepper_hbox):
		chain_stepper_hbox.visible = v

## Phase 23A-R: 隐藏/显示槽位状态标签（LOCK/ASCEND/ACT）
func set_status_tags_visible(v: bool) -> void:
	_3d_status_tags_hidden = not v
	if not v:
		_remove_all_legacy_status_tags()

## 根据卡牌找到对应的前场槽位
func find_front_slot_for_card(card: CardData) -> Control:
	if not _player or not "field" in _player:
		return null

	var units: Array = _player.field
	var slots := _external_front_slots if _external_slots_set else front_slots
	var count := mini(units.size(), slots.size())
	var centered_indices: Array[int] = []
	if _owner_side == "player" and _external_slots_set:
		centered_indices = get_centered_slot_indices(count, slots.size())
	for i in range(count):
		if units[i] == card:
			var slot_idx: int = centered_indices[i] if i < centered_indices.size() else i
			if slot_idx >= 0 and slot_idx < slots.size():
				return slots[slot_idx]
	return null

## Phase 19C-2: Hit-test fallback – find which field card (if any) is at a global mouse position.
## Called by BattleScene._input when CardUI native _gui_input is not reached.
## Returns {"ok": true, "card": CardData, "owner_side": String, "zone": String, "card_ui": CardUI, "slot": Control}
## or {"ok": false}.
func get_field_card_at_global_position(global_pos: Vector2) -> Dictionary:
	# Determine slot arrays
	var use_external := _external_slots_set and not _external_front_slots.is_empty()
	var f_slots: Array[Control] = _external_front_slots if use_external else front_slots
	var b_slots: Array[Control] = _external_back_slots if use_external else back_slots

	# Collect card-infos from all slots, then pick the best match
	var candidates: Array[Dictionary] = []
	var scanned_slots := 0
	var scanned_cards := 0

	# Helper: scan a slot array
	var _scan_slots := func(slots: Array[Control], zone_name: String):
		for slot in slots:
			if not is_instance_valid(slot):
				continue
			scanned_slots += 1
			var slot_rect: Rect2 = slot.get_global_rect().grow(14.0)
			for child in slot.get_children():
				var card_ui := child as CardUI
				if not is_instance_valid(card_ui) or card_ui.card_data == null:
					continue
				scanned_cards += 1
				# Prefer CardUI rect; fall back to the containing slot with a small tolerance.
				var rect: Rect2 = card_ui.get_global_rect().grow(12.0)
				var hit := rect.has_point(global_pos)
				if not hit:
					hit = slot_rect.has_point(global_pos)
				if hit:
					candidates.append({
						"card": card_ui.card_data,
						"owner_side": _owner_side,
						"zone": zone_name,
						"card_ui": card_ui,
						"slot": slot,
						"z_index": card_ui.z_index,
					})

	_scan_slots.call(f_slots, "front")
	_scan_slots.call(b_slots, "back")

	if candidates.is_empty():
		pass  # Phase 19D: [FIELD_HITTEST] ok=false silent
		return {"ok": false}

	# Pick the candidate with the highest z_index (last added / topmost)
	candidates.sort_custom(func(a, b): return a.z_index > b.z_index)
	var best := candidates[0]
	var cname: String = best.card.get_display_name() if best.card.has_method("get_display_name") else best.card.card_name
	pass  # Phase 19D: [FIELD_HITTEST] ok=true silent
	return {"ok": true, "card": best.card, "owner_side": best.owner_side, "zone": best.zone, "card_ui": best.card_ui, "slot": best.slot}

## 选中攻击者槽位脉冲高亮（金色边框）
func play_monster_selected_pulse(slot: Control) -> void:
	if not slot or not is_instance_valid(slot):
		return
	var slot_panel := slot.get_node_or_null("SlotPanel") as Panel
	if not slot_panel or not is_instance_valid(slot_panel):
		return
	var t: Tween = create_tween()
	t.set_loops()
	t.tween_property(slot_panel, "modulate", Color(1.4, 1.2, 0.4, 1), 0.5).set_trans(Tween.TRANS_SINE)
	t.tween_property(slot_panel, "modulate", Color(1.0, 0.85, 0.3, 1), 0.5).set_trans(Tween.TRANS_SINE)
	# 存到 slot meta 以便后续清理
	slot.set_meta("_attack_selected_tween", t)


## Boss 目标槽位脉冲高亮（红色边框）
func play_attack_target_pulse(slot: Control) -> void:
	if not slot or not is_instance_valid(slot):
		return
	var slot_panel := slot.get_node_or_null("SlotPanel") as Panel
	if not slot_panel or not is_instance_valid(slot_panel):
		return
	var t: Tween = create_tween()
	t.set_loops()
	t.tween_property(slot_panel, "modulate", Color(1.3, 0.5, 0.3, 1), 0.4).set_trans(Tween.TRANS_SINE)
	t.tween_property(slot_panel, "modulate", Color(0.9, 0.35, 0.2, 1), 0.4).set_trans(Tween.TRANS_SINE)
	slot.set_meta("_attack_target_tween", t)


## 清除所有攻击相关高亮
func clear_attack_highlights() -> void:
	var slots: Array[Control] = []
	if _external_slots_set:
		slots = _external_front_slots + _external_back_slots
	else:
		slots = front_slots + back_slots
	for slot in slots:
		if not is_instance_valid(slot):
			continue
		# 清除选中高亮
		if slot.has_meta("_attack_selected_tween"):
			var st: Tween = slot.get_meta("_attack_selected_tween", null)
			if st and is_instance_valid(st):
				st.kill()
			slot.remove_meta("_attack_selected_tween")
		# 清除目标高亮
		if slot.has_meta("_attack_target_tween"):
			var tt: Tween = slot.get_meta("_attack_target_tween", null)
			if tt and is_instance_valid(tt):
				tt.kill()
			slot.remove_meta("_attack_target_tween")
		# 恢复槽位面板颜色
		var slot_panel := slot.get_node_or_null("SlotPanel") as Panel
		if slot_panel and is_instance_valid(slot_panel):
			slot_panel.modulate = Color(1, 1, 1, 1)


## 根据攻击状态数组更新场上怪兽的 USED 标签
func apply_monster_attack_used_states(attack_states: Dictionary) -> void:
	var slots := _external_front_slots if _external_slots_set else front_slots
	if not _player or not "field" in _player:
		return
	var units: Array = _player.field
	var count := mini(units.size(), slots.size())
	var centered_indices: Array[int] = []
	if _owner_side == "player" and _external_slots_set:
		centered_indices = get_centered_slot_indices(count, slots.size())
	for i in range(count):
		var card := units[i] as CardData
		if card == null:
			continue
		var slot_idx: int = centered_indices[i] if i < centered_indices.size() else i
		if slot_idx < 0 or slot_idx >= slots.size():
			continue
		var slot := slots[slot_idx]
		if not is_instance_valid(slot):
			continue
		var key: int = card.get_instance_id()
		var used: bool = attack_states.get(key, {}).get("has_attacked_this_turn", false)
		if used:
			_add_attack_used_label(slot, card)
		else:
			_remove_attack_used_label(slot)


func _add_attack_used_label(slot: Control, _card: CardData) -> void:
	if slot.get_node_or_null("AttackUsedLabel"):
		return  # 已存在
	var label := Label.new()
	label.name = "AttackUsedLabel"
	label.text = "USED"
	label.add_theme_font_size_override("font_size", 8)
	label.add_theme_color_override("font_color", Color(0.7, 0.5, 0.2, 1))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.custom_minimum_size = Vector2(36, 14)
	label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	label.offset_top = 2
	label.offset_right = -2
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.z_index = 10
	slot.add_child(label)


func _remove_attack_used_label(slot: Control) -> void:
	var lbl := slot.get_node_or_null("AttackUsedLabel")
	if lbl and is_instance_valid(lbl):
		lbl.queue_free()


## Boss 目标被破坏时的槽位脉冲
func play_destroyed_pulse(slot: Control) -> void:
	if not slot or not is_instance_valid(slot):
		return
	var slot_panel := slot.get_node_or_null("SlotPanel") as Panel
	if not slot_panel or not is_instance_valid(slot_panel):
		return
	# 清除可能存在的目标高亮 tween
	if slot.has_meta("_attack_target_tween"):
		var tt: Tween = slot.get_meta("_attack_target_tween", null)
		if tt and is_instance_valid(tt):
			tt.kill()
		slot.remove_meta("_attack_target_tween")
	var t: Tween = create_tween()
	t.tween_property(slot_panel, "modulate", Color(2.0, 0.2, 0.1, 1), 0.1)
	t.tween_property(slot_panel, "modulate", Color(1.0, 0.4, 0.2, 1), 0.15)
	t.tween_property(slot_panel, "modulate", Color(1, 1, 1, 1), 0.25)


## Boss 攻击被阻挡时的槽位红闪
func play_blocked_flash(slot: Control) -> void:
	if not slot or not is_instance_valid(slot):
		return
	var slot_panel := slot.get_node_or_null("SlotPanel") as Panel
	if not slot_panel or not is_instance_valid(slot_panel):
		return
	var t: Tween = create_tween()
	t.tween_property(slot_panel, "modulate", Color(1.6, 0.1, 0.1, 1), 0.08)
	t.tween_property(slot_panel, "modulate", Color(1, 1, 1, 1), 0.2)

# ============================================================
# Phase 10E: 手牌动态辅助
# ============================================================
func _apply_hand_idle_vfx(card: CardData, card_ui: CardUI) -> void:
	if not _card_vfx:
		return
	# Phase 12B: Premium card surface（流光 + 边缘呼吸）
	if _card_vfx.is_premium_card(card):
		_card_vfx.play_premium_surface(card_ui, card, 0)  # mode=0=手牌
	# 原有手牌浮动（premium 卡也保留，更明显的"活着"感）
	if _card_vfx._should_use_premium_idle(card):
		var intensity := _card_vfx._get_hand_idle_intensity(card)
		_card_vfx.play_hand_idle(card_ui, intensity)

# ============================================================
# Phase 13F-2: ASCEND Tag
# ============================================================


## Phase 23A-R: Remove all legacy 2D status tags from slots
func _remove_all_legacy_status_tags() -> void:
	var all_slots: Array[Control] = []
	var ext_front := _external_front_slots if (_external_slots_set and not _external_front_slots.is_empty()) else front_slots
	var ext_back := _external_back_slots if (_external_slots_set and not _external_back_slots.is_empty()) else back_slots
	for s in ext_front:
		if s and is_instance_valid(s):
			all_slots.append(s)
	for s in ext_back:
		if s and is_instance_valid(s):
			all_slots.append(s)
	for slot in all_slots:
		if not is_instance_valid(slot):
			continue
		for tag_name in ["BuildingStatusLabel", "AscendTag", "MonsterStatusTag", "LockLabel", "SealOverlay"]:
			var tag := slot.get_node_or_null(NodePath(tag_name))
			if tag and is_instance_valid(tag):
				tag.queue_free()
		var slot_panel := slot.get_node_or_null("SlotPanel") as Panel
		if slot_panel and is_instance_valid(slot_panel):
			slot_panel.visible = false
	for slot in front_slots:
		if not is_instance_valid(slot):
			continue
		for tag_name in ["BuildingStatusLabel", "AscendTag", "MonsterStatusTag", "LockLabel", "SealOverlay"]:
			var tag := slot.get_node_or_null(NodePath(tag_name))
			if tag and is_instance_valid(tag):
				tag.queue_free()
	for slot in back_slots:
		if not is_instance_valid(slot):
			continue
		for tag_name in ["BuildingStatusLabel", "AscendTag", "MonsterStatusTag", "LockLabel", "SealOverlay"]:
			var tag := slot.get_node_or_null(NodePath(tag_name))
			if tag and is_instance_valid(tag):
				tag.queue_free()
func _add_ascend_tag(slot: Control, card: CardData) -> void:
	if _3d_status_tags_hidden: return
	if _owner_side != "player":
		return
	if not card.is_front_row_card():
		return
	# Query ascension status from BattleSystem
	var bs: BattleSystem = _get_battle_system()
	if bs == null:
		return
	var asc: Dictionary = bs.get_ascension_preview_status(card, _player)
	if not asc.get("has_target", false):
		return

	var tag := Label.new()
	tag.name = "AscendTag"
	tag.text = asc.get("label", "ASCEND")
	tag.add_theme_font_size_override("font_size", 8)
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.custom_minimum_size = Vector2(48, 14)
	tag.size = Vector2(48, 14)

	var ok: bool = asc.get("ok", false)
	if ok:
		tag.add_theme_color_override("font_color", Color(1, 0.85, 0.2, 1))
		var tag_style: StyleBoxFlat = StyleBoxFlat.new()
		tag_style.bg_color = Color(0.08, 0.06, 0.02, 0.85)
		tag_style.border_width_left = 1
		tag_style.border_width_right = 1
		tag_style.border_width_top = 1
		tag_style.border_width_bottom = 1
		tag_style.border_color = Color(1, 0.65, 0.1, 0.7)
		tag_style.set_corner_radius_all(2)
		tag.add_theme_stylebox_override("normal", tag_style)
	else:
		tag.add_theme_color_override("font_color", Color(0.4, 0.4, 0.45, 1))
		var tag_style: StyleBoxFlat = StyleBoxFlat.new()
		tag_style.bg_color = Color(0.04, 0.04, 0.06, 0.7)
		tag_style.border_color = Color(0.2, 0.2, 0.25, 0.5)
		tag_style.set_corner_radius_all(2)
		tag.add_theme_stylebox_override("normal", tag_style)

	# Position top-right of slot
	tag.anchor_left = 1.0
	tag.anchor_right = 1.0
	tag.anchor_top = 0.0
	tag.offset_left = -52
	tag.offset_top = 2

	slot.add_child(tag)


func _get_battle_system() -> BattleSystem:
	if _context and is_instance_valid(_context) and _context.get_parent():
		var parent := _context.get_parent()
		for child in parent.get_children():
			if child is BattleSystem:
				return child as BattleSystem
	return null


func _get_ascension_info_for_card(card: CardData) -> Dictionary:
	if _owner_side != "player":
		return {}
	if not card.is_front_row_card():
		return {}
	var bs: BattleSystem = _get_battle_system()
	if bs == null:
		return {}
	var asc: Dictionary = bs.get_ascension_preview_status(card, _player)
	if not asc.get("has_target", false):
		return {}
	return asc

# ============================================================
# Phase 15D: Monster status tags
# ============================================================

func _add_monster_status_tags(slot: Control, card: CardData) -> void:
	if _3d_status_tags_hidden: return
	if _owner_side != "player": return
	if not card.is_front_row_card(): return
	# Only show if no ASCEND tag (ascend takes priority)
	if slot.get_node_or_null("AscendTag"): return

	var bs: BattleSystem = _get_battle_system()
	if bs == null: return

	var tag_text: String = ""
	var tag_color: Color = Color.WHITE
	var has_attacked: bool = bs.has_monster_attacked(card) if bs.has_method("has_monster_attacked") else false
	var can_atk: bool = bs.can_monster_attack(card).get("ok", false) if bs.has_method("can_monster_attack") else false

	# Check active effect status
	var active_used: bool = false
	if bs.has_method("get_monster_active_status"):
		var ast: Dictionary = bs.get_monster_active_status(card, null)
		if ast.get("ok", false):
			tag_text = "EFFECT"
			tag_color = Color(0.4, 0.85, 1.0)
		elif ast.get("reason", "") == "本回合已发动":
			active_used = true

	# If no EFFECT, check attack status
	if tag_text == "":
		if has_attacked:
			tag_text = "USED"
			tag_color = Color(0.45, 0.45, 0.5)
		elif can_atk:
			tag_text = "ATK READY"
			tag_color = Color(1, 0.55, 0.2)
		elif active_used:
			tag_text = "E.USED"
			tag_color = Color(0.4, 0.5, 0.55)

	if tag_text == "": return

	var tag: Label = Label.new()
	tag.name = "MonsterStatusTag"
	tag.text = tag_text
	tag.add_theme_font_size_override("font_size", 7)
	tag.add_theme_color_override("font_color", tag_color)
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.custom_minimum_size = Vector2(52, 12)
	tag.size = Vector2(52, 12)

	var tag_style: StyleBoxFlat = StyleBoxFlat.new()
	tag_style.bg_color = Color(0.04, 0.04, 0.08, 0.8)
	tag_style.border_color = Color(tag_color.r * 0.5, tag_color.g * 0.5, tag_color.b * 0.5, 0.6)
	tag_style.set_corner_radius_all(2)
	tag.add_theme_stylebox_override("normal", tag_style)

	# Position bottom-left
	tag.anchor_left = 0.0
	tag.anchor_bottom = 1.0
	tag.offset_left = 2
	tag.offset_bottom = -2

	slot.add_child(tag)


func _family_rank(card) -> int:
	if card == null:
		return 9
	match str(card.card_family):
		"spell":
			return 0
		"monster":
			return 1
		"building":
			return 2
		"counter":
			return 3
	return 4


func _sorted_for_hand(cards: Array) -> Array:
	## Display-only ordering: keeps the underlying hand array untouched.
	var rows: Array = []
	for i in range(cards.size()):
		rows.append([_family_rank(cards[i]), i, cards[i]])
	rows.sort_custom(func(a, b):
		if a[0] == b[0]:
			return a[1] < b[1]
		return a[0] < b[0])
	var out: Array = []
	for r in rows:
		out.append(r[2])
	return out
