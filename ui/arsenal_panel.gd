extends Panel
class_name ArsenalPanel

## ArsenalPanel — OD Arsenal 额外卡组预览面板 (Phase 13D)
## 显示 6 张 Arsenal 卡的解锁状态，随 OD 引擎层级变化。
## 本阶段仅预览，不可使用 Arsenal 卡。

const TC = preload("res://core/theme/theme_colors.gd")
const CardUIScene: PackedScene = preload("res://ui/card_ui.tscn")

# ============================================================
# 解锁状态枚举
# ============================================================
enum ArsenalState {
	LOCKED,       # OD L1 — 全部锁定
	PREVIEW,      # OD L2 — 可预览但不可用
	MID_READY,    # OD L3-L4 — 中级可看
	FINAL_READY,  # OD L5/Burst — 终场可看
}

# ============================================================
# 内部节点
# ============================================================
var _collapsed_box: Control = null      # 收起态：小型 HUD
var _status_label: Label = null         # "ARSENAL 0/6"
var _stage_label: Label = null          # "LOCKED" / "PREVIEW" etc
var _expanded_box: Control = null       # 展开态：6 张小卡
var _mid_row: HBoxContainer = null      # 上排 3 张中级
var _final_row: HBoxContainer = null    # 下排 3 张终场
var _preview_cards: Array[Control] = [] # 6 个 CardUIContainer
var _mid_cards: Array[CardData] = []    # unlock_layer=3 的卡片数据
var _final_cards: Array[CardData] = []  # unlock_layer=5 的卡片数据
var _state: int = ArsenalState.LOCKED
var _is_expanded := false
var _detail_panel: CardDetailPanel = null  # 外部详情面板引用
var _pulse_tween: Tween = null
var _battle_hud_enabled := true  # Phase 27K-R0-R2: 战斗 HUD 显示策略开关

# ============================================================
# 常量
# ============================================================
const ZI_ARSENAL := 65
const COLLAPSED_W := 180
const COLLAPSED_H := 32
const EXPANDED_W := 260
const EXPANDED_H := 220
const MINI_CARD_W := 60
const MINI_CARD_H := 44


# ============================================================
# 初始化
# ============================================================
func _ready() -> void:
	z_index = ZI_ARSENAL
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(COLLAPSED_W, COLLAPSED_H)
	size = Vector2(COLLAPSED_W, COLLAPSED_H)

	_build_panel_style()
	_build_collapsed_view()
	_build_expanded_view()
	_apply_state_visuals()

	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)


func _build_panel_style() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.05, 0.10, 0.92)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.50, 0.38, 0.18, 0.85)  # Phase 14E: brass dock
	style.set_corner_radius_all(4)
	add_theme_stylebox_override("panel", style)


func _build_collapsed_view() -> void:
	_collapsed_box = Control.new()
	_collapsed_box.name = "CollapsedBox"
	_collapsed_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	_collapsed_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_collapsed_box)

	# 齿轮图标 + Arsenal 计数
	_status_label = Label.new()
	_status_label.name = "ArsenalStatus"
	_status_label.text = "ARSENAL 0/6"
	_status_label.add_theme_font_size_override("font_size", 10)
	_status_label.add_theme_color_override("font_color", Color(0.45, 0.65, 0.9, 1))
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_status_label.offset_top = 3
	_status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_collapsed_box.add_child(_status_label)

	# 解锁阶段文字
	_stage_label = Label.new()
	_stage_label.name = "ArsenalStage"
	_stage_label.text = "LOCKED"
	_stage_label.add_theme_font_size_override("font_size", 8)
	_stage_label.add_theme_color_override("font_color", TC.TEXT_DIM)
	_stage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stage_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_stage_label.offset_bottom = -3
	_stage_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_collapsed_box.add_child(_stage_label)


func _build_expanded_view() -> void:
	_expanded_box = Control.new()
	_expanded_box.name = "ExpandedBox"
	_expanded_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	_expanded_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_expanded_box.visible = false
	add_child(_expanded_box)

	# 标题
	var title := Label.new()
	title.name = "ArsenalTitle"
	title.text = "OD ARSENAL"
	title.add_theme_font_size_override("font_size", 10)
	title.add_theme_color_override("font_color", Color(0.55, 0.75, 1.0, 1))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 3
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_expanded_box.add_child(title)

	# 分隔线
	var sep := HSeparator.new()
	sep.name = "TitleSep"
	sep.set_anchors_preset(Control.PRESET_TOP_WIDE)
	sep.offset_top = 16
	sep.custom_minimum_size = Vector2(0, 1)
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_expanded_box.add_child(sep)

	# 中级行标签
	var mid_label := Label.new()
	mid_label.name = "MidLabel"
	mid_label.text = "Mid — L3"
	mid_label.add_theme_font_size_override("font_size", 8)
	mid_label.add_theme_color_override("font_color", Color(0.3, 0.65, 0.4, 1))
	mid_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	mid_label.offset_top = 20
	mid_label.offset_left = 6
	mid_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_expanded_box.add_child(mid_label)

	# 中级卡行
	_mid_row = HBoxContainer.new()
	_mid_row.name = "MidRow"
	_mid_row.add_theme_constant_override("separation", 4)
	_mid_row.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_mid_row.offset_top = 34
	_mid_row.offset_left = 6
	_mid_row.offset_right = -6
	_mid_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_expanded_box.add_child(_mid_row)

	# 终场行标签
	var final_label := Label.new()
	final_label.name = "FinalLabel"
	final_label.text = "Final — L5"
	final_label.add_theme_font_size_override("font_size", 8)
	final_label.add_theme_color_override("font_color", Color(0.9, 0.45, 0.1, 1))
	final_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	final_label.offset_top = 118
	final_label.offset_left = 6
	final_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_expanded_box.add_child(final_label)

	# 终场卡行
	_final_row = HBoxContainer.new()
	_final_row.name = "FinalRow"
	_final_row.add_theme_constant_override("separation", 4)
	_final_row.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_final_row.offset_top = 132
	_final_row.offset_left = 6
	_final_row.offset_right = -6
	_final_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_expanded_box.add_child(_final_row)


# ============================================================
# 公开 API
# ============================================================

## 设置 Arsenal 卡片数据来源
func set_arsenal_cards(cards: Array[CardData]) -> void:
	_mid_cards.clear()
	_final_cards.clear()
	for card in cards:
		if card == null:
			continue
		if card.unlock_layer <= 3:
			_mid_cards.append(card)
		else:
			_final_cards.append(card)
	_build_mini_cards()


## 设置详情面板引用（用于 hover 显示）
func set_detail_panel(dp: CardDetailPanel) -> void:
	_detail_panel = dp


## Phase 27K-R0-R2: 战斗 HUD 显示策略开关。
## 禁用时：收起 ExpandedBox、隐藏 CollapsedBox、清除展开态、mouse_filter=IGNORE、
## visible=false、process_mode=DISABLED、停止 Tween/脉冲。幂等。
## 数据（_mid_cards/_final_cards）、业务结算（arsenal_card_clicked）与点击处理不受影响。
func set_battle_hud_enabled(enabled: bool) -> void:
	_battle_hud_enabled = enabled
	if not enabled:
		_is_expanded = false
		if _expanded_box:
			_expanded_box.visible = false
		if _collapsed_box:
			_collapsed_box.visible = false
		if _state_tween and _state_tween.is_valid():
			_state_tween.kill()
			_state_tween = null
		if _pulse_tween and _pulse_tween.is_valid():
			_pulse_tween.kill()
			_pulse_tween = null
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		visible = false
		process_mode = Node.PROCESS_MODE_DISABLED
	else:
		mouse_filter = Control.MOUSE_FILTER_STOP
		visible = true
		process_mode = Node.PROCESS_MODE_INHERIT


## 根据 OD 引擎状态刷新解锁 UI
## layer: int (1-5), burst_active: bool
func refresh(layer: int, burst_active: bool) -> void:
	if _state_tween:
		_state_tween.kill()
		_state_tween = null

	var old_state := _state
	if layer >= 5 or burst_active:
		_state = ArsenalState.FINAL_READY
	elif layer >= 3:
		_state = ArsenalState.MID_READY
	elif layer >= 2:
		_state = ArsenalState.PREVIEW
	else:
		_state = ArsenalState.LOCKED

	_apply_state_visuals()

	# 状态变化脉冲
	if old_state != _state and old_state != ArsenalState.LOCKED:
		_play_unlock_pulse()


# ============================================================
# 内部：迷你卡构建
# ============================================================

func _build_mini_cards() -> void:
	# 清除旧卡片
	_clear_mini_cards()
	if _mid_row == null or _final_row == null:
		return

	var all_cards: Array[CardData] = []
	all_cards.append_array(_mid_cards)
	all_cards.append_array(_final_cards)

	if all_cards.is_empty():
		_show_empty_state()
		return

	for card in all_cards:
		var container := _make_mini_card_container(card)
		if container == null:
			continue
		_preview_cards.append(container)

		# 分配到对应行
		if card.unlock_layer <= 3 and _mid_row:
			_mid_row.add_child(container)
		elif _final_row:
			_final_row.add_child(container)

	# 确保展开区大小
	if _expanded_box:
		_expanded_box.custom_minimum_size = Vector2(EXPANDED_W, EXPANDED_H)


func _clear_mini_cards() -> void:
	for container in _preview_cards:
		if is_instance_valid(container):
			# 清除内部 CardUI
			for child in container.get_children():
				if is_instance_valid(child):
					child.queue_free()
			container.queue_free()
	_preview_cards.clear()

	# 清除行的残留
	for row in [_mid_row, _final_row]:
		if row == null:
			continue
		for child in row.get_children():
			if is_instance_valid(child) and child not in _preview_cards:
				child.queue_free()


func _show_empty_state() -> void:
	if _status_label and is_instance_valid(_status_label):
		_status_label.text = "ARSENAL DATA MISSING"
		_status_label.add_theme_color_override("font_color", TC.WARNING)
	push_warning("[ArsenalPanel] No Arsenal cards loaded — panel empty.")


## 创建迷你卡容器（复用 CardUI FEED 模式）
func _make_mini_card_container(card: CardData) -> Control:
	var container := Control.new()
	container.name = "ArsenalMini_%s" % card.card_id
	container.custom_minimum_size = Vector2(MINI_CARD_W, MINI_CARD_H)
	container.mouse_filter = Control.MOUSE_FILTER_STOP

	# 容器背景
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.03, 0.03, 0.06, 0.85)
	bg_style.border_width_left = 1
	bg_style.border_width_right = 1
	bg_style.border_width_top = 1
	bg_style.border_width_bottom = 1
	bg_style.border_color = Color(0.15, 0.22, 0.40, 0.7)
	bg_style.set_corner_radius_all(2)
	var bg_panel := Panel.new()
	bg_panel.name = "MiniBg"
	bg_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_panel.add_theme_stylebox_override("panel", bg_style)
	bg_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(bg_panel)

	# 如果 CardUI scene 可用，实例化小卡
	var card_ui := _try_create_card_ui(card)
	if card_ui != null:
		card_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
		card_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
		container.add_child(card_ui)

	# 卡名标签（极简）
	var name_label := Label.new()
	name_label.name = "MiniName"
	name_label.text = card.display_name if card.display_name != "" else card.card_name
	name_label.add_theme_font_size_override("font_size", 7)
	name_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.85, 1))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	name_label.offset_bottom = -1
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(name_label)

	# hover 连接 → 详情面板
	container.mouse_entered.connect(_on_mini_card_hovered.bind(card))
	container.mouse_exited.connect(_on_mini_card_unhovered)

	# Phase 13E: 点击信号
	container.gui_input.connect(_on_mini_card_gui_input.bind(card))

	return container


## 尝试用 CardUI FEED 模式创建迷你卡
func _try_create_card_ui(card: CardData) -> Control:
	if CardUIScene == null:
		return null
	var ui: CardUI = CardUIScene.instantiate()
	if ui == null:
		return null
	ui.card_data = card
	ui.set_display_mode(CardUI.CardDisplayMode.FEED)
	ui.setup(card, true)  # compact=true
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.is_playable = false
	# 断开所有交互信号，确保不可打出
	if ui.card_clicked.get_connections().size() > 0:
		for conn in ui.card_clicked.get_connections():
			ui.card_clicked.disconnect(conn.callable)
	if ui.card_selected.get_connections().size() > 0:
		for conn in ui.card_selected.get_connections():
			ui.card_selected.disconnect(conn.callable)
	return ui


# ============================================================
# hover 交互
# ============================================================

func _on_mouse_entered() -> void:
	# Phase 27K-R0-R2: 战斗 HUD 禁用时不展开悬停 Dock
	if not _battle_hud_enabled:
		return
	_is_expanded = true
	if _expanded_box:
		_expanded_box.visible = true
	if _collapsed_box:
		_collapsed_box.visible = false
	custom_minimum_size = Vector2(EXPANDED_W, EXPANDED_H)
	size = Vector2(EXPANDED_W, EXPANDED_H)
	# 提升 z_index 防止被相邻元素遮挡
	z_index = ZI_ARSENAL + 5


func _on_mouse_exited() -> void:
	if not _battle_hud_enabled:
		return
	_is_expanded = false
	if _expanded_box:
		_expanded_box.visible = false
	if _collapsed_box:
		_collapsed_box.visible = true
	custom_minimum_size = Vector2(COLLAPSED_W, COLLAPSED_H)
	size = Vector2(COLLAPSED_W, COLLAPSED_H)
	z_index = ZI_ARSENAL



## Phase 13E: gui_input handler for mini card clicks
func _on_mini_card_gui_input(event: InputEvent, card: CardData) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_mini_card_clicked(card)
func _on_mini_card_hovered(card: CardData) -> void:
	# Phase 27K-R0-R2: 战斗 HUD 禁用时不触发外部详情预览
	if not _battle_hud_enabled:
		return
	if _detail_panel == null or not is_instance_valid(_detail_panel):
		return
	if card == null:
		return
	var zone_name := "Calm"
	_detail_panel.show_card(card, zone_name, {"ok": false, "reason": "Arsenal 预览 — 不可使用"})


func _on_mini_card_unhovered() -> void:
	pass  # 保留最后预览，不清空


# ============================================================
# 状态视觉
# ============================================================

func _apply_state_visuals() -> void:
	if _status_label == null or _stage_label == null:
		return

	var panel_style := StyleBoxFlat.new()
	panel_style.set_corner_radius_all(4)

	match _state:
		ArsenalState.LOCKED:
			_status_label.text = "ARSENAL 0/6"
			_status_label.add_theme_color_override("font_color", Color(0.25, 0.30, 0.40, 1))
			_stage_label.text = "LOCKED — L2 Preview"
			_stage_label.add_theme_color_override("font_color", TC.TEXT_DIM)
			panel_style.bg_color = Color(0.03, 0.03, 0.06, 0.90)
			panel_style.border_color = Color(0.12, 0.12, 0.20, 0.6)
			_apply_mini_cards_lock(0.25)
		ArsenalState.PREVIEW:
			_status_label.text = "ARSENAL 0/6"
			_status_label.add_theme_color_override("font_color", Color(0.35, 0.50, 0.70, 1))
			_stage_label.text = "PREVIEW — L3 Unlocks Mid"
			_stage_label.add_theme_color_override("font_color", Color(0.30, 0.55, 0.75, 1))
			panel_style.bg_color = Color(0.04, 0.05, 0.10, 0.92)
			panel_style.border_color = Color(0.18, 0.40, 0.60, 0.7)
			_apply_mini_cards_lock(0.40)  # 中级半亮
			_apply_mini_cards_by_tier("mid", 0.55)
		ArsenalState.MID_READY:
			_status_label.text = "ARSENAL MID"
			_status_label.add_theme_color_override("font_color", Color(0.25, 0.65, 0.35, 1))
			_stage_label.text = "MID READY — Final at L5"
			_stage_label.add_theme_color_override("font_color", Color(0.30, 0.70, 0.45, 1))
			panel_style.bg_color = Color(0.04, 0.08, 0.06, 0.90)
			panel_style.border_color = Color(0.15, 0.50, 0.25, 0.7)
			# 中级高亮
			_apply_mini_cards_by_tier("mid", 1.0)
			_apply_mini_cards_lock(0.40)
			_apply_mini_cards_by_tier("final", 0.50)
		ArsenalState.FINAL_READY:
			_status_label.text = "ARSENAL FINAL"
			_status_label.add_theme_color_override("font_color", Color(1.0, 0.55, 0.10, 1))
			_stage_label.text = "FINAL READY — Burst Active"
			_stage_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.05, 1))
			panel_style.bg_color = Color(0.12, 0.04, 0.02, 0.90)
			panel_style.border_color = Color(0.85, 0.35, 0.05, 0.8)
			# 所有高亮，终场金红强调
			_apply_mini_cards_by_tier("mid", 1.0)
			_apply_mini_cards_by_tier("final", 1.0)

	panel_style.border_width_left = 2
	panel_style.border_width_right = 2
	panel_style.border_width_top = 2
	panel_style.border_width_bottom = 2
	add_theme_stylebox_override("panel", panel_style)


## 设置所有迷你卡透明度
func _apply_mini_cards_lock(alpha: float) -> void:
	for container in _preview_cards:
		if not is_instance_valid(container):
			continue
		container.modulate = Color(1, 1, 1, clampi(alpha, 0.15, 1.0))


## 按 tier 设置特定卡高亮
func _apply_mini_cards_by_tier(tier: String, alpha: float) -> void:
	var target_cards: Array[CardData]
	if tier == "mid":
		target_cards = _mid_cards
	else:
		target_cards = _final_cards

	for container in _preview_cards:
		if not is_instance_valid(container):
			continue
		# 匹配容器名和卡片tier
		for card in target_cards:
			if container.name == "ArsenalMini_%s" % card.card_id:
				container.modulate = Color(1, 1, 1, clampi(alpha, 0.15, 1.0))
				# 终场卡高亮时加金红效果
				if tier == "final" and alpha >= 1.0:
					_add_final_glow(container)
				break


## 给终场卡容器加金红底光
func _add_final_glow(container: Control) -> void:
	var old_glow := container.get_node_or_null(NodePath("FinalGlow"))
	if old_glow and is_instance_valid(old_glow):
		old_glow.queue_free()
	var glow := ColorRect.new()
	glow.name = "FinalGlow"
	glow.color = Color(1, 0.35, 0.05, 0.2)
	glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(glow)
	glow.move_child(glow, 0)


# ============================================================
# 解锁脉冲
# ============================================================

var _state_tween: Tween = null

func _play_unlock_pulse() -> void:
	# Phase 27K-R0-R2: 战斗 HUD 禁用时不播放解锁脉冲
	if not _battle_hud_enabled:
		return
	if _state_tween and _state_tween.is_valid():
		_state_tween.kill()
	_state_tween = create_tween()
	_state_tween.tween_property(self, "scale", Vector2(1.06, 1.06), 0.10)
	_state_tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.20)


# ============================================================
# 生命周期
# ============================================================

func _exit_tree() -> void:
	if _state_tween and _state_tween.is_valid():
		_state_tween.kill()
	_state_tween = null
	_clear_mini_cards()

# ============================================================
# Phase 13E: 点击使用信号
# ============================================================

signal arsenal_card_clicked(card: CardData)

# Phase 13E 状态追踪
var _mid_used := false
var _final_used := false
var _current_layer := 1
var _burst_active := false


## Phase 13E: 扩展 refresh 参数
func refresh_ext(layer: int, burst_active: bool, mid_used: bool = false, final_used: bool = false) -> void:
	_current_layer = layer
	_burst_active = burst_active
	_mid_used = mid_used
	_final_used = final_used

	if _state_tween and is_instance_valid(_state_tween):
		_state_tween.kill()
		_state_tween = null

	var old_state := _state
	if layer >= 5 or burst_active:
		_state = ArsenalState.FINAL_READY
	elif layer >= 3:
		_state = ArsenalState.MID_READY
	elif layer >= 2:
		_state = ArsenalState.PREVIEW
	else:
		_state = ArsenalState.LOCKED

	_apply_state_visuals_ext()

	if old_state != _state and old_state != ArsenalState.LOCKED:
		_play_unlock_pulse()


func _apply_state_visuals_ext() -> void:
	# 先调基础样式
	_apply_state_visuals()

	# 修正状态文案根据 used
	var used_count := 0
	if _mid_used: used_count += 1
	if _final_used: used_count += 1

	if _status_label and is_instance_valid(_status_label):
		_status_label.text = "ARSENAL %d/2" % used_count
		if used_count >= 2:
			_status_label.add_theme_color_override("font_color", TC.TEXT_DIM)

	if _stage_label and is_instance_valid(_stage_label):
		if _mid_used and _final_used:
			_stage_label.text = "USED 2/2"
		elif _mid_used:
			match _state:
				ArsenalState.FINAL_READY:
					_stage_label.text = "MID USED — Final Ready"
				_:
					_stage_label.text = "MID USED — Final at L5"
		else:
			pass  # 保留原有文案

	# USED cards gray out
	if _mid_used:
		_apply_mini_cards_by_tier("mid", 0.35)
	if _final_used:
		_apply_mini_cards_by_tier("final", 0.35)

# ============================================================
# Phase 13E: 点击处理
# ============================================================

func _on_mini_card_clicked(card: CardData) -> void:
	if card == null:
		return
	if not card.is_arsenal_card:
		return

	# Phase 13F-2: ascension forms cannot be summoned directly
	if card.is_ascension_form:
		arsenal_card_clicked.emit(card)  # battle_scene shows "monster ascension only"
		return

	if card.arsenal_tier == "mid" and (_mid_used or _current_layer < card.unlock_layer):
		arsenal_card_clicked.emit(card)
		return
	if card.arsenal_tier == "final":
		if _final_used:
			arsenal_card_clicked.emit(card)
			return
		arsenal_card_clicked.emit(card)
		return
	arsenal_card_clicked.emit(card)
