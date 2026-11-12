extends Control
class_name StructureInteractionPresenter
## Read-only inspection UI for semantic structure targets.  It never owns rules or visuals.

signal activate_requested(target_ref: Dictionary)
signal candidate_selected(target_ref: Dictionary)
signal detail_closed
signal build_confirm_requested
signal build_reselect_requested
signal build_cancel_requested

const PANEL_SIZE := Vector2(272.0, 220.0)
const CANDIDATE_SIZE := Vector2(248.0, 164.0)
const BUILD_PENDING_SIZE := Vector2(356.0, 118.0)
const REASON_TEXT := {
	&"structure_profile_missing": "这张建筑牌没有可用的空间配置",
	&"structure_profile_invalid": "建筑配置无效，已改用普通出牌方式",
	&"structure_cell_wrong_height": "当前地形高度不符合建设要求",
	&"structure_surface_invalid": "当前地表无法承载这座建筑",
	&"structure_cell_occupied_by_unit": "目标格已有单位",
	&"structure_cell_occupied_by_core": "目标格已有建筑核心",
	&"structure_orientation_required": "请选择墙体朝向",
	&"structure_orientation_invalid": "这个墙体朝向无效",
	&"structure_edge_conflict": "所选格边已被其他墙体占用",
	&"structure_replacement_required": "请选择一座可替换的建筑",
	&"structure_replacement_profile_invalid": "只能升级指定的前置建筑",
	&"structure_replacement_not_stable": "建筑地基不稳定，暂时不能升级",
	&"structure_replacement_garrison_occupied": "请先撤离建筑内的驻防单位",
	&"structure_target_stale": "目标状态已变化，请重新选择",
	&"terrain_cell_stabilized_by_structure": "该格受热沉装置保护，无法降低",
	&"foundation_reconcile_stale": "地基状态已变化，请重新确认",
	&"foundation_window_not_ready": "地基恢复窗口尚未开始",
	&"foundation_window_already_active": "地基恢复窗口已经处于活动状态",
	&"structure_interface_paused_undermined": "建筑失去地基，功能暂时停用",
	&"garrison_structure_undermined": "建筑失去地基，不能安排新的驻防",
	&"foundation_collapse_stale": "坍塌目标已变化，本次处理已取消",
	&"repair_content_not_implemented": "维修内容将在后续阶段开放",
	&"structure_cell_out_of_bounds": "目标不在棋盘范围内",
	&"structure_wrong_territory": "只能在我方建设区域放置",
	&"frontline_support_required": "前推需要上回合已建立且未移动的相邻友军；目标附近不能有敌军",
	&"frontline_platform_occupied": "前方平台需要空格：请避开棋子、建筑和已布置的牌",
	&"frontline_platform_height": "前方平台须为平地或地基，与塔身高度差不超过1",
	&"frontline_large_limit": "当前最多一座大型烽堡，请先利用已有驻防平台",
	&"structure_cell_occupied_by_anchor": "目标格已有棋子锚点",
	&"piece_base_action_blocked": "当前资源或卡牌条件不满足",
}

var _view_model: Dictionary = {}
var _target_ref: Dictionary = {}
var _hover_label: Label
var _panel: PanelContainer
var _title: Label
var _details: Label
var _garrison: Label
var _activate_button: Button
var _close_button: Button
var _candidate_panel: PanelContainer
var _candidate_box: VBoxContainer
var _candidates: Array[Dictionary] = []
var _reserved_rects: Array[Rect2] = []
var _candidate_screen_position := Vector2.INF
var _build_pending_fact: Dictionary = {}
var _build_panel: PanelContainer
var _build_title: Label
var _build_summary: Label
var _build_anchor := Vector2.INF
var _build_details_toggle: Button
var _build_details: Label
var _build_confirm_button: Button
var _build_reselect_button: Button
var _build_cancel_button: Button
var _build_reason_label: Label
var _build_reason_code: StringName = &""
var _build_reason_text := ""

func _ready() -> void:

	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hover_label = Label.new()
	_hover_label.name = "StructureHover"
	_hover_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hover_label.visible = false
	add_child(_hover_label)
	_panel = PanelContainer.new()
	_panel.name = "StructurePinnedPanel"
	_panel.size = PANEL_SIZE
	var detail_style := StyleBoxFlat.new()
	detail_style.bg_color = Color(0.025,0.045,0.075,0.98)
	detail_style.border_color = Color("79ffe1")
	detail_style.set_border_width_all(1)
	detail_style.set_corner_radius_all(6)
	detail_style.set_content_margin_all(10)
	_panel.add_theme_stylebox_override("panel", detail_style)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.visible = false
	add_child(_panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)
	_panel.add_child(content)
	_title = Label.new(); _title.name = "Title"; _title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(_title)
	_details = Label.new(); _details.name = "Details"; _details.add_theme_font_size_override("font_size", 14); _details.custom_minimum_size.x = PANEL_SIZE.x - 20; _details.size.x = PANEL_SIZE.x - 20; _details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; _details.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(_details)
	_garrison = Label.new(); _garrison.name = "GarrisonDisabled"; _garrison.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(_garrison)
	var actions := HBoxContainer.new(); actions.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(actions)
	_activate_button = Button.new(); _activate_button.name = "ActivateBuildingInterface"; _activate_button.text = "发动接口"; _activate_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_activate_button.pressed.connect(func() -> void: activate_requested.emit(_target_ref.duplicate(true)))
	actions.add_child(_activate_button)
	_close_button = Button.new(); _close_button.name = "CloseStructureDetail"; _close_button.text = "关闭"; _close_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_close_button.pressed.connect(clear)
	actions.add_child(_close_button)
	_candidate_panel = PanelContainer.new()
	_candidate_panel.name = "StructureCandidatePanel"
	_candidate_panel.size = CANDIDATE_SIZE
	_candidate_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_candidate_panel.visible = false
	add_child(_candidate_panel)
	_candidate_box = VBoxContainer.new()
	_candidate_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_candidate_panel.add_child(_candidate_box)
	_build_panel = PanelContainer.new()
	_build_panel.name = "StructureBuildPendingPanel"
	_build_panel.size = BUILD_PENDING_SIZE
	_build_panel.z_index = 120
	_build_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_panel.visible = false
	var build_style := StyleBoxFlat.new()
	build_style.bg_color = Color(0.035, 0.05, 0.075, 0.98)
	build_style.border_color = Color(0.3, 0.8, 0.92, 0.95)
	build_style.set_border_width_all(1)
	build_style.set_corner_radius_all(8)
	build_style.content_margin_left = 12
	build_style.content_margin_right = 12
	build_style.content_margin_top = 10
	build_style.content_margin_bottom = 10
	_build_panel.add_theme_stylebox_override("panel", build_style)
	add_child(_build_panel)
	var build_content := VBoxContainer.new()
	build_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	build_content.add_theme_constant_override("separation", 7)
	_build_panel.add_child(build_content)
	_build_title = Label.new()
	_build_title.name = "BuildPendingTitle"
	_build_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	build_content.add_child(_build_title)
	_build_summary = Label.new()
	_build_summary.mouse_filter = Control.MOUSE_FILTER_IGNORE
	build_content.add_child(_build_summary)
	_build_details = Label.new()
	_build_details.name = "BuildPendingDetails"
	_build_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_build_details.mouse_filter = Control.MOUSE_FILTER_IGNORE
	build_content.add_child(_build_details)
	var build_actions := HBoxContainer.new()
	build_actions.mouse_filter = Control.MOUSE_FILTER_IGNORE
	build_content.add_child(build_actions)
	_build_confirm_button = Button.new()
	_build_confirm_button.name = "ConfirmStructureBuild"
	_build_confirm_button.text = "确认建设"
	_build_confirm_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_build_confirm_button.pressed.connect(func() -> void: build_confirm_requested.emit())
	build_actions.add_child(_build_confirm_button)
	_build_reselect_button = Button.new()
	_build_reselect_button.name = "ReselectStructureCell"
	_build_reselect_button.text = "重新选位"
	_build_reselect_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_build_reselect_button.pressed.connect(func() -> void: build_reselect_requested.emit())
	build_actions.add_child(_build_reselect_button)
	_build_cancel_button = Button.new()
	_build_cancel_button.name = "CancelStructureBuild"
	_build_cancel_button.text = "取消"
	_build_cancel_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_build_cancel_button.pressed.connect(func() -> void: build_cancel_requested.emit())
	build_actions.add_child(_build_cancel_button)
	_build_details_toggle = Button.new()
	_build_details_toggle.name = "BuildDetailsToggle"
	_build_details_toggle.text = "详情"
	_build_details_toggle.pressed.connect(_toggle_build_details)
	build_actions.add_child(_build_details_toggle)
	for button: Button in [_build_confirm_button, _build_reselect_button, _build_cancel_button, _build_details_toggle]:
		button.custom_minimum_size.y = 34
	_build_reason_label = Label.new()
	_build_reason_label.name = "StructureBuildReason"
	_build_reason_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_reason_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_build_reason_label.add_theme_color_override("font_color", Color("#FF8C86"))
	_build_reason_label.visible = false
	_build_reason_label.z_index = 121
	add_child(_build_reason_label)

func set_structure_view_model(view_model: Dictionary, target_ref: Dictionary = {}) -> void:

	_view_model = view_model.duplicate(true)
	_target_ref = target_ref.duplicate(true)
	_refresh_labels()

func show_hover(view_model: Dictionary, target_ref: Dictionary = {}, screen_position: Vector2 = Vector2.ZERO) -> void:

	set_structure_view_model(view_model, target_ref)
	_hide_candidates()
	_panel.visible = false
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hover_label.text = "%s · (%d,%d) · %d/%d" % [str(_view_model.get("title", "Structure")), (_view_model.get("cell", Vector2i.ZERO) as Vector2i).x, (_view_model.get("cell", Vector2i.ZERO) as Vector2i).y, int(_view_model.get("integrity_current", 0)), int(_view_model.get("integrity_max", 0))]
	_hover_label.position = _clamp_hover_position(screen_position + Vector2(14.0, 14.0))
	_hover_label.visible = true

func pin_detail(view_model: Dictionary = {}, target_ref: Dictionary = {}) -> void:

	if not view_model.is_empty():
		set_structure_view_model(view_model, target_ref)
	_hide_candidates()
	_hover_label.visible = false
	_panel.position = get_safe_panel_rect(size).position
	_panel.visible = not _view_model.is_empty()
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP if _panel.visible else Control.MOUSE_FILTER_IGNORE
	call_deferred("_position_pinned_detail")

func inspect(view_model: Dictionary, target_ref: Dictionary, screen_position: Vector2 = Vector2.ZERO) -> void:

	show_hover(view_model, target_ref, screen_position)

func show_semantic_candidates(candidates: Array, screen_position: Vector2 = Vector2.ZERO) -> void:

	_candidates.clear()
	for candidate in candidates:
		if candidate is Dictionary:
			_candidates.append((candidate as Dictionary).duplicate(true))
	_candidates.sort_custom(_candidate_less)
	if _candidates.size() == 1:
		candidate_selected.emit(_candidates[0].duplicate(true))
		_hide_candidates()
		return
	_rebuild_candidate_buttons()
	_candidate_screen_position = screen_position
	_hover_label.visible = false
	_panel.visible = false
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_candidate_panel.position = _safe_rect_for_size(size, CANDIDATE_SIZE, screen_position).position
	_candidate_panel.visible = not _candidates.is_empty()
	_candidate_panel.mouse_filter = Control.MOUSE_FILTER_STOP if _candidate_panel.visible else Control.MOUSE_FILTER_IGNORE


func show_build_pending(preview_fact: Dictionary, card_name: String, confirm_enabled: bool = true, continuation_text: String = "", screen_position: Vector2 = Vector2.INF) -> void:
	_build_pending_fact = preview_fact.duplicate(true)
	_build_anchor = screen_position
	_build_details.visible = false
	_build_details_toggle.text = "详情"
	_clear_build_reason()
	_hover_label.visible = false
	_panel.visible = false
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hide_candidates()
	var cell: Vector2i = preview_fact.get("piece_anchor_cell", preview_fact.get("cell", Vector2i(-1, -1)))
	var before: Dictionary = preview_fact.get("terrain_before", {})
	var after: Dictionary = preview_fact.get("terrain_after", before)
	var modules: Array = preview_fact.get("modules", [])
	_build_summary.text = "H%d → H%d · %s" % [int(before.get("height", 0)), int(after.get("height", 0)), _placement_text(StringName(str(preview_fact.get("placement_kind", &"new_build"))))]
	_build_title.text = "在 %d列%d行 建设「%s」？" % [cell.x + 1, cell.y + 1, card_name]
	var orientation := StringName(str(preview_fact.get("orientation_edge", &"")))
	var direction_text := _orientation_text(orientation) if orientation != &"" else "固定"
	_build_details.text = "地形：H%d %s → H%d %s\n朝向：%s · 核心 + %d 个模块\n方式：%s" % [
		int(before.get("height", 0)), str(before.get("surface", &"flat")),
		int(after.get("height", before.get("height", 0))), str(after.get("surface", before.get("surface", &"flat"))),
		direction_text, modules.size(), _placement_text(StringName(str(preview_fact.get("placement_kind", &"new_build")))),
	]
	var replacement_id := StringName(str(preview_fact.get("replacement_structure_id", &"")))
	if replacement_id != &"":
		_build_details.text += "\n替换来源：%s" % replacement_id
	var foundation_after: Dictionary = preview_fact.get("foundation_after", {})
	if not foundation_after.is_empty():
		_build_details.text += "\n地基：%s" % _foundation_text(foundation_after)
	if not continuation_text.is_empty():
		_build_details.text += "\n%s" % continuation_text
	_build_confirm_button.disabled = not confirm_enabled
	_position_build_panel()
	call_deferred("_position_build_panel")
	_build_panel.visible = true
	_build_panel.mouse_filter = Control.MOUSE_FILTER_STOP


func owns_build_pointer(point: Vector2) -> bool:
	return is_instance_valid(_build_panel) and _build_panel.is_visible_in_tree() and _build_panel.get_global_rect().has_point(point)


func clear_build_pending() -> void:
	_build_pending_fact.clear()
	_build_anchor = Vector2.INF
	if _build_panel != null:
		_build_panel.visible = false
		_build_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_build_refusal(status: Dictionary, card_name: String = "建筑") -> void:
	_build_reason_code = StringName(str(status.get("reason_code", &"structure_target_invalid")))
	_build_reason_text = get_reason_text(_build_reason_code)
	var cell: Variant = status.get("cell", Vector2i(-1, -1))
	var suffix := ""
	if cell is Vector2i and cell != Vector2i(-1, -1):
		suffix = " · (%d,%d)" % [cell.x, cell.y]
	_build_reason_label.text = "%s%s：%s" % [card_name, suffix, _build_reason_text]
	_build_reason_label.position = _safe_rect_for_size(size, Vector2(360.0, 54.0), Vector2(size.x * 0.5 - 180.0, size.y * 0.26)).position
	_build_reason_label.size = Vector2(360.0, 54.0)
	_build_reason_label.visible = true


func clear_build_refusal() -> void:
	_clear_build_reason()


func get_reason_text(reason_code: StringName) -> String:
	return str(REASON_TEXT.get(reason_code, "当前目标无法建设"))


func _clear_build_reason() -> void:
	_build_reason_code = &""
	_build_reason_text = ""
	if _build_reason_label != null:
		_build_reason_label.visible = false


func _orientation_text(edge: StringName) -> String:
	return {&"north": "北", &"east": "东", &"south": "南", &"west": "西"}.get(edge, "未选择")


func _placement_text(kind: StringName) -> String:
	return {&"new_build": "新建", &"same_cell_replacement": "同格替换", &"same_cell_upgrade": "同格升级", &"dual_target_replacement": "容量替换"}.get(kind, str(kind))


func _foundation_text(foundation: Dictionary) -> String:
	var state := StringName(str(foundation.get("foundation_state", &"stable")))
	if state == &"stable":
		return "稳定"
	if state == &"collapse_due":
		return "坍塌到期"
	return "失基恢复窗口"

func set_reserved_rects(rects: Array) -> void:

	_reserved_rects.clear()
	for rect in rects:
		if rect is Rect2 and (rect as Rect2).size.x > 0.0 and (rect as Rect2).size.y > 0.0:
			_reserved_rects.append(rect)
	if _panel != null and _panel.visible:
		_panel.position = get_safe_panel_rect(size).position
	if _candidate_panel != null and _candidate_panel.visible:
		_candidate_panel.position = _safe_rect_for_size(size, CANDIDATE_SIZE, _candidate_screen_position).position
	if _build_panel != null and _build_panel.visible:
		_position_build_panel()
	if _build_reason_label != null and _build_reason_label.visible:
		_build_reason_label.position = _safe_rect_for_size(size, _build_reason_label.size, Vector2(size.x * 0.5 - 180.0, size.y * 0.26)).position

func _toggle_build_details() -> void:
	_build_details.visible = not _build_details.visible
	_build_details_toggle.text = "收起" if _build_details.visible else "详情"
	call_deferred("_position_build_panel")


func _position_build_panel() -> void:
	var panel_size := BUILD_PENDING_SIZE.max(_build_panel.get_combined_minimum_size())
	_build_panel.size = panel_size
	if _build_anchor.is_finite():
		for candidate in [
			_build_anchor - Vector2(panel_size.x * 0.5, panel_size.y + 24),
			_build_anchor + Vector2(24, -panel_size.y * 0.5),
			_build_anchor - Vector2(panel_size.x + 24, panel_size.y * 0.5),
			_build_anchor + Vector2(-panel_size.x * 0.5, 24),
		]:
			if _rect_is_safe(Rect2(candidate, panel_size), size, 16):
				_build_panel.position = candidate
				return
	_build_panel.position = _safe_rect_for_size(size, panel_size, _build_anchor).position


func close_pinned() -> bool:

	if _panel == null or not _panel.visible:
		return false
	clear()
	return true

func clear() -> void:

	clear_transient(&"clear", true)

func clear_transient(_reason: StringName = &"cleanup", emit_close: bool = false) -> void:

	var was_visible := (_hover_label != null and _hover_label.visible) \
		or (_panel != null and _panel.visible) \
		or (_candidate_panel != null and _candidate_panel.visible) \
		or (_build_panel != null and _build_panel.visible)
	if _hover_label != null:
		_hover_label.visible = false
	if _panel != null:
		_panel.visible = false
		_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hide_candidates()
	clear_build_pending()
	_clear_build_reason()
	_view_model.clear()
	_target_ref.clear()
	_candidates.clear()
	_candidate_screen_position = Vector2.INF
	if emit_close and was_visible:
		detail_closed.emit()

func get_safe_panel_rect(viewport_size: Vector2) -> Rect2:

	var panel_size := _panel.size.max(PANEL_SIZE) if is_instance_valid(_panel) else PANEL_SIZE
	return _safe_rect_for_size(viewport_size, panel_size)

func get_debug_snapshot() -> Dictionary:

	return {
		"view_model": _view_model.duplicate(true),
		"target_ref": _target_ref.duplicate(true),
		"root_mouse_filter": mouse_filter,
		"panel_mouse_filter": _panel.mouse_filter if _panel != null else Control.MOUSE_FILTER_IGNORE,
		"panel_visible": _panel != null and _panel.visible,
		"hover_visible": _hover_label != null and _hover_label.visible,
		"candidate_count": _candidates.size() if _candidate_panel != null and _candidate_panel.visible else 0,
		"candidate_kinds": _candidates.map(func(candidate: Dictionary) -> StringName: return StringName(str(candidate.get("target_kind", &"")))) if _candidate_panel != null and _candidate_panel.visible else [],
		"candidate_mouse_filter": _candidate_panel.mouse_filter if _candidate_panel != null else Control.MOUSE_FILTER_IGNORE,
		"activate_disabled": _activate_button.disabled if _activate_button != null else true,
		"details_text": _details.text if _details != null else "",
		"garrison_disabled": int(_view_model.get("garrison_slots_total", 0)) > 0 and not bool(_view_model.get("garrison_slots_enabled", false)),
		"safe_rect": get_safe_panel_rect(size),
		"build_pending": _build_panel != null and _build_panel.visible,
		"build_cell": _build_pending_fact.get("piece_anchor_cell", _build_pending_fact.get("cell", Vector2i(-1, -1))),
		"build_fact": _build_pending_fact.duplicate(true),
		"build_direction": StringName(str(_build_pending_fact.get("orientation_edge", &""))),
		"build_details_text": _build_details.text if _build_details != null else "",
		"reason_code": _build_reason_code,
		"reason_text": _build_reason_text,
		"reason_visible": _build_reason_label != null and _build_reason_label.visible,
		"confirm_disabled": _build_confirm_button.disabled if _build_confirm_button != null else true,
		"confirm_mouse_filter": _build_confirm_button.mouse_filter if _build_confirm_button != null else Control.MOUSE_FILTER_IGNORE,
		"reselect_mouse_filter": _build_reselect_button.mouse_filter if _build_reselect_button != null else Control.MOUSE_FILTER_IGNORE,
		"cancel_mouse_filter": _build_cancel_button.mouse_filter if _build_cancel_button != null else Control.MOUSE_FILTER_IGNORE,
	}

func _refresh_labels() -> void:

	if _title == null:
		return
	var cell := _view_model.get("cell", Vector2i.ZERO) as Vector2i
	_title.text = str(_view_model.get("title", "Structure"))
	_details.text = "位置 (%d,%d) · H%d\n核心耐久 %d/%d · %s" % [cell.x, cell.y, int(_view_model.get("height", 0)), int(_view_model.get("integrity_current", 0)), int(_view_model.get("integrity_max", 0)), {"intact":"完好","damaged":"受损","destroyed":"已毁","breached":"破口"}.get(str(_view_model.get("status", "intact")),str(_view_model.get("status", "")))]
	_garrison.text = "驻军请使用棋子的驻防指令" if int(_view_model.get("garrison_slots_total", 0)) > 0 else ""
	var available := false
	var unavailable_reason := "Unavailable"
	for action in _view_model.get("available_actions", []) as Array:
		if action is Dictionary and StringName(str((action as Dictionary).get("action_id", &""))) == &"activate_building_interface":
			available = bool((action as Dictionary).get("available", false))
			unavailable_reason = str((action as Dictionary).get("reason", unavailable_reason))
	_activate_button.disabled = not available
	_activate_button.text = "发动接口"
	for action in _view_model.get("available_actions", []):
		if action.get("action_id") == &"activate_building_interface" and not str(action.get("preview", "")).is_empty():
			_details.text += "\n主动：%s\n费用：%s（每回合一次）" % [action.preview, action.get("cost", "")]
			_activate_button.text = "发动：" + str(action.get("cost", ""))
	_details.text += "\n" + str(_view_model.get("rules_text", ""))
	if not available:
		_details.text += "\n暂不可发动：%s" % unavailable_reason

func _candidate_less(left: Dictionary, right: Dictionary) -> bool:

	var ranks := {&"structure_module": 0, &"structure_core": 1, &"tactical_cell": 2}
	var left_kind := StringName(str(left.get("target_kind", &"")))
	var right_kind := StringName(str(right.get("target_kind", &"")))
	var left_rank := int(ranks.get(left_kind, 99))
	var right_rank := int(ranks.get(right_kind, 99))
	if left_rank != right_rank:
		return left_rank < right_rank
	return "%s:%s:%s" % [left.get("structure_id", ""), left.get("module_id", ""), left.get("edge", "")] < "%s:%s:%s" % [right.get("structure_id", ""), right.get("module_id", ""), right.get("edge", "")]

func _rebuild_candidate_buttons() -> void:

	for child in _candidate_box.get_children():
		_candidate_box.remove_child(child)
		child.queue_free()
	var title := Label.new()
	title.text = "Select target"
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_candidate_box.add_child(title)
	for candidate in _candidates:
		var button := Button.new()
		var kind := StringName(str(candidate.get("target_kind", &"")))
		button.text = _candidate_label(candidate)
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		button.pressed.connect(func() -> void:
			candidate_selected.emit(candidate.duplicate(true))
			_hide_candidates()
		)
		button.set_meta("target_kind", kind)
		_candidate_box.add_child(button)

func _candidate_label(candidate: Dictionary) -> String:

	match StringName(str(candidate.get("target_kind", &""))):
		&"structure_module": return "Module · %s" % str(candidate.get("edge", ""))
		&"structure_core": return "Structure core"
		&"tactical_cell": return "Board cell"
	return "Target"

func _hide_candidates() -> void:

	if _candidate_panel != null:
		_candidate_panel.visible = false
		_candidate_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_candidate_screen_position = Vector2.INF

func _safe_rect_for_size(viewport_size: Vector2, panel_size: Vector2, preferred: Vector2 = Vector2.INF) -> Rect2:

	var margin := 16.0
	var candidates: Array[Vector2] = []
	if preferred != Vector2.INF:
		candidates.append(preferred + Vector2(14.0, 14.0))
	candidates.append_array([
		Vector2(viewport_size.x * 0.5 - panel_size.x * 0.5, 18.0),
		Vector2(viewport_size.x * 0.5 - panel_size.x * 0.5, viewport_size.y * 0.30),
		Vector2(18.0, viewport_size.y * 0.28),
		Vector2(viewport_size.x - panel_size.x - 18.0, viewport_size.y * 0.28),
	])
	for position in candidates:
		var rect := Rect2(position, panel_size)
		if _rect_is_safe(rect, viewport_size, margin):
			return rect
	var max_x := maxi(16, int(viewport_size.x - panel_size.x - margin))
	var max_y := maxi(16, int(viewport_size.y - panel_size.y - margin))
	for y in range(16, max_y + 1, 24):
		for x in range(16, max_x + 1, 24):
			var rect := Rect2(Vector2(x, y), panel_size)
			if _rect_is_safe(rect, viewport_size, margin):
				return rect
	var fallback := Vector2(
		clampf(viewport_size.x * 0.5 - panel_size.x * 0.5, margin, maxf(margin, viewport_size.x - panel_size.x - margin)),
		clampf(viewport_size.y * 0.5 - panel_size.y * 0.5, margin, maxf(margin, viewport_size.y - panel_size.y - margin))
	)
	return Rect2(fallback, panel_size)

func _rect_is_safe(rect: Rect2, viewport_size: Vector2, margin: float) -> bool:

	if rect.position.x < margin or rect.position.y < margin or rect.end.x > viewport_size.x - margin or rect.end.y > viewport_size.y - margin:
		return false
	for reserved in _reserved_rects:
		if rect.intersects(reserved):
			return false
	return true

func _clamp_hover_position(position: Vector2) -> Vector2:

	return Vector2(clampf(position.x, 12.0, maxf(12.0, size.x - 220.0)), clampf(position.y, 12.0, maxf(12.0, size.y - 36.0)))

func _position_pinned_detail() -> void:
	if is_instance_valid(_panel) and _panel.visible:
		_panel.size = Vector2(PANEL_SIZE.x, maxf(PANEL_SIZE.y, _panel.get_combined_minimum_size().y))
		_panel.position = get_safe_panel_rect(size).position
