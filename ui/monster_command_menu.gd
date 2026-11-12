extends Panel
class_name MonsterCommandMenu
## Compact monster command menu.
## API is intentionally stable: BattleScene calls setup(), then listens to command_selected.

signal command_selected(action: String, card: CardData)

const BTN_WIDTH := 46
const BTN_HEIGHT := 26
const BTN_GAP := 3
const MENU_PAD := 6

var _card: CardData = null
var _buttons: Array[Button] = []
var _skill_btn: Button = null  # Phase 27E-R1
var _garrison_btn: Button = null  # Elevated Grid Phase D1
var _garrison_guidance: Label = null
var _ascension_guidance: Label = null
var _title_label: Label = null          # Phase 27I-R0-R2
var _piece_info_panel: Panel = null     # Phase 27I-R0-R2
var _focus_scroll: ScrollContainer
var _focus_width:=0.0
var _focus_height:=0.0
var _focus_body: VBoxContainer
var _menu_hbox: HBoxContainer = null    # Phase 27I-R0-R2


func _ready() -> void:
	z_index = 500
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_style()
	_build_title()
	_build_piece_info()
	_build_buttons()
	_garrison_guidance = Label.new()
	_garrison_guidance.name = "GarrisonGuidanceLabel"
	_garrison_guidance.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_garrison_guidance.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_garrison_guidance.add_theme_font_size_override("font_size", 12)
	_garrison_guidance.add_theme_color_override("font_color", Color(0.75, 0.93, 0.89))
	_garrison_guidance.visible = false
	add_child(_garrison_guidance)
	_ascension_guidance = Label.new()
	_ascension_guidance.name = "AscensionGuidanceLabel"
	_ascension_guidance.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ascension_guidance.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ascension_guidance.add_theme_font_size_override("font_size", 12)
	_ascension_guidance.add_theme_color_override("font_color", Color(1.0, 0.89, 0.55))
	_ascension_guidance.visible = false
	add_child(_ascension_guidance)
	_build_arrow()


func setup(card: CardData, ascend_status: Dictionary, active_status: Dictionary = {}, attack_status: Dictionary = {}, combat_state: Dictionary = {}, move_status: Dictionary = {}, turn_status: Dictionary = {}, od_breach_status: Dictionary = {}, economy_snapshot: Dictionary = {}, skill_status: Dictionary = {}, garrison_status: Dictionary = {}) -> void:  # Phase D1: +garrison_status
	_card = card
	if _garrison_guidance != null:
		_garrison_guidance.text = str(garrison_status.get("guidance_text", ""))
		_garrison_guidance.visible = not _garrison_guidance.text.is_empty()
	if _ascension_guidance != null:
		_ascension_guidance.text = str(ascend_status.get("preview", "")) if ascend_status.get("has_target", false) else ""
		if ascend_status.get("has_target", false) and not ascend_status.get("ok", false):
			_ascension_guidance.text += "：" + str(ascend_status.get("reason", "条件不满足"))
		_ascension_guidance.visible = not _ascension_guidance.text.is_empty()
	_apply_title(card, combat_state, economy_snapshot, skill_status)
	# Phase 27I-R0-R2: 切换怪兽时清空棋子信息区（无棋型怪兽不显示，不累加旧内容）
	if _piece_info_panel:
		_piece_info_panel.visible = false
		var badge_label := _piece_info_panel.get_node_or_null("PieceBadgeLabel") as Label
		if badge_label:
			badge_label.text = ""
		var summary := _piece_info_panel.get_node_or_null("PieceSummaryLabel") as Label
		if summary:
			summary.text = ""
	_resize_to_fit()

	var attack_ok := bool(attack_status.get("ok", false))
	var attack_cost := str(attack_status.get("cost", "2"))
	var attack_reason := _clean_reason(str(attack_status.get("reason", "不可攻击")), "不可攻击")
	# Phase 27E-R3: extract legal target count and short reason
	var attack_legal_count: int = (attack_status.get("legal_targets", []) as Array).size()
	if attack_legal_count == 0 and bool(attack_status.get("core_attack_ok", false)):
		attack_legal_count = 1  # boss core counts as a target
	var attack_short_reason := _short_attack_reason(attack_status)
	var move_ok := bool(move_status.get("ok", false))
	var move_cost := str(move_status.get("cost", "1"))
	var move_reason := _clean_reason(str(move_status.get("reason", "不可移动")), "不可移动")
	var move_hint := _clean_reason(str(move_status.get("hint", "")), "")
	var turn_ok := bool(turn_status.get("ok", false))
	var turn_cost := str(turn_status.get("cost", "1"))
	var turn_reason := _clean_reason(str(turn_status.get("reason", "不可回防")), "不可回防")
	var active_ok := bool(active_status.get("ok", false))
	var active_reason := _clean_reason(str(active_status.get("reason", "")), "条件不满足")
	var active_label := _clean_reason(str(active_status.get("label", "")), "效果")
	var ascend_ok := bool(ascend_status.get("ok", false))
	var ascend_reason := _clean_reason(str(ascend_status.get("reason", "")), "无可用目标")
	var od_breach_ok := bool(od_breach_status.get("ok", false))
	var od_breach_cost := str(od_breach_status.get("cost", "3"))

	for i in range(_buttons.size()):
		var btn := _buttons[i]
		match _button_action(i):
			"attack":
				# Phase 27E-R3: show short reason in button text, full reason + target count in tooltip
				var atk_text: String = "攻击 · " + attack_cost if attack_ok else ("攻击锁定·" + attack_short_reason)
				var atk_tip: String = ""
				if not attack_ok:
					atk_tip = attack_reason
					if attack_legal_count > 0:
						atk_tip += " | 可攻击目标：" + str(attack_legal_count)
				_set_btn(btn, attack_ok, atk_text, atk_tip, Color(1.0, 0.55, 0.2))
			"move":
				var mv_text: String = "移动 · " + move_cost if move_ok else ("移动锁定·" + _short_move_reason(move_status))
				var mv_tip: String = ""
				if not move_ok:
					mv_tip = move_reason
				elif move_hint != "":
					mv_tip = move_hint
				_set_btn(btn, move_ok, mv_text, mv_tip, Color(0.3, 0.85, 0.85))
			"turn":
				_set_btn(btn, turn_ok, "回防 · " + turn_cost if turn_ok else "回防锁定", "" if turn_ok else turn_reason, Color(0.6, 0.75, 1.0))
			"od_breach":
				_set_btn(btn, od_breach_ok, "突击 · " + od_breach_cost if od_breach_ok else "突击锁定", "" if od_breach_ok else "OD不足/条件不满足", Color(1.0, 0.35, 0.15))
			"effect":
				_set_btn(btn, active_ok, "效果" if active_ok else "效果锁定", active_label if active_ok else active_reason, Color(0.4, 0.85, 1.0))
			"ascend":
				var verb := "合体" if ascend_status.get("label") == "FUSION" else "升格"
				_set_btn(btn, ascend_ok, verb if ascend_ok else verb + "锁定", str(ascend_status.get("preview", "")) if ascend_ok else ascend_reason, Color(1.0, 0.85, 0.2))
			"detail":
				_set_btn(btn, true, "详情", "", Color(0.72, 0.72, 0.88))
			"cancel":
				_set_btn(btn, true, "关闭", "", Color(0.56, 0.56, 0.62))

			"skill":
				var sk_ok := bool(skill_status.get("ok", false))
				var sk_cost := str(skill_status.get("cost", "?"))
				var sk_reason := _clean_reason(str(skill_status.get("reason_text", "")), "")
				var sk_name := _clean_reason(str(skill_status.get("skill_name", "")), "技能")
				var sk_enable := sk_ok and not skill_status.is_empty()
				var sk_label: String = "%s · %s" % [sk_name, sk_cost] if sk_enable else "技能锁定"
				_set_btn(btn, sk_enable, sk_label, "" if sk_enable else sk_reason, Color(0.9, 0.75, 0.2))
				btn.visible = not skill_status.is_empty()
			"garrison":
				var mode := StringName(str(garrison_status.get("mode", &"enter")))
				var ga_ok := bool(garrison_status.get("ok", false))
				var ga_cost := str(garrison_status.get("action_cost", garrison_status.get("cost", "?")))
				var ga_reason := _clean_reason(str(garrison_status.get("reason_text", "")), "当前不可驻防")
				var ga_verb := "撤离" if mode in [&"exit", &"displaced"] else "驻防"
				var ga_label := "%s · %s" % [ga_verb, ga_cost]
				_set_btn(btn, ga_ok, ga_label, "" if ga_ok else ga_reason, Color(0.35, 0.9, 0.86))
				btn.visible = not garrison_status.is_empty()

	_resize_to_fit()


func _apply_title(card: CardData, combat_state: Dictionary = {}, economy_snapshot: Dictionary = {}, skill_status: Dictionary = {}) -> void:  # Phase 27E-R1
	var title_label := get_node_or_null(NodePath("TitleLabel")) as Label
	if title_label == null:
		return
	# Phase 27E-R3: prepend card_id badge (e.g. "P07 · ")
	var card_id_str := ""
	if card != null and not card.card_id.is_empty():
		card_id_str = card.card_id + " · "
	var card_name := "怪兽"
	if card != null:
		card_name = card.get_display_name() if card.has_method("get_display_name") else card.card_name
	card_name = _clean_reason(card_name, "怪兽")
	var max_name_len := 10
	if card_id_str.length() > 0:
		max_name_len = 8
	if card_name.length() > max_name_len:
		card_name = card_name.substr(0, max_name_len) + "…"
	# Line 1: monster name + ATK/HP
	var line1: String = ""
	if not combat_state.is_empty():
		line1 = card_id_str + "%s  ATK %d  HP %d/%d" % [card_name, card.unit_power, int(combat_state.get("current_hp", 0)), int(combat_state.get("max_hp", card.unit_defense))]
	else:
		line1 = card_id_str + card_name
	# Line 2: command economy
	var line2: String = ""
	if not economy_snapshot.is_empty():
		var current: int = int(economy_snapshot.get("current_points", 0))
		var maximum: int = int(economy_snapshot.get("turn_max_points", 0))
		line2 = "\n战术指令 %d/%d" % [current, maximum]
	# Phase 27E-R1: skill info line
	var line3: String = ""
	if not skill_status.is_empty():
		var sk_passive: String = skill_status.get("passive_name", "")
		var sk_name: String = skill_status.get("skill_name", "")
		var sk_stacks: int = int(skill_status.get("stack_count", 0))
		var sk_max: int = int(skill_status.get("max_stacks", 0))
		if sk_passive != "":
			line3 = "\n%s %d/%d" % [sk_passive, sk_stacks, sk_max]
		if sk_name != "":
			line3 += " | %s" % sk_name
	title_label.text = line1 + line2 + line3


## Phase 27I-R0-R2: 显示棋型、基础/强化与权威费用（只读，不计算合法性）。
## 写入独立的 PieceInfoPanel，不再向 TitleLabel 追加多行。
func set_piece_info(piece_name: String, base_desc: String, enhanced_desc: String, cost_desc: String) -> void:
	var panel := get_node_or_null("PieceInfoPanel") as Control
	if panel == null:
		return
	var badge_label := panel.get_node_or_null("PieceBadgeLabel") as Label
	if badge_label:
		badge_label.text = piece_name
	var summary := panel.get_node_or_null("PieceSummaryLabel") as Label
	if summary:
		summary.text = base_desc
		if enhanced_desc != "":
			summary.text += " | 强化：%s" % enhanced_desc
		if cost_desc != "":
			summary.text += " | %s" % cost_desc
	# 完整强化说明与费用放 tooltip，不在菜单堆长文本
	panel.tooltip_text = base_desc
	if enhanced_desc != "":
		panel.tooltip_text += "\n强化：" + enhanced_desc
	if cost_desc != "":
		panel.tooltip_text += "\n" + cost_desc
	panel.visible = piece_name != ""
	_resize_to_fit()


# Phase 27E-R3: Short attack reason for button text (fits in narrow button)
func _short_attack_reason(status: Dictionary) -> String:
	if bool(status.get("ok", false)):
		return ""
	var rc: StringName = status.get("reason_code", &"")
	match rc:
		&"insufficient_command_points": return "指令不足"
		&"no_legal_target": return "无目标"
		&"no_legal_cell": return "无攻击格"
		&"no_geometric_cells": return "无攻击格"
		&"summoning_sickness": return "召唤病"
		&"state_missing": return "状态缺失"
		&"card_missing": return "卡牌缺失"
		&"not_on_board": return "不在场上"
		&"action_spent": return "已行动"
		&"engaged": return "被牵制"
		&"attack_locked": return "不可攻击"
		&"selection_busy": return "结算中"
		_: return "不可攻击"


func _short_move_reason(status: Dictionary) -> String:
	if bool(status.get("ok", false)):
		return ""
	var rc: StringName = status.get("reason_code", &"")
	match rc:
		&"insufficient_command_points": return "指令不足"
		&"no_legal_cell": return "无可用格"
		&"no_geometric_cells": return "无可用格"
		&"summoning_sickness": return "召唤病"
		&"state_missing": return "状态缺失"
		&"card_missing": return "卡牌缺失"
		&"not_on_board": return "不在场上"
		&"action_spent": return "已行动"
		&"engaged": return "被牵制"
		&"selection_busy": return "结算中"
		_: return "不可移动"


func _clean_reason(value: String, fallback: String) -> String:
	var text := value.strip_edges()
	var bad_markers := ["�", "鈥", "閸", "鍗", "缁", "鐨", "瀵", "濡", "澧", "宸", "閫", "绁", "镭", "鏀", "鏁", "鍏", "璇", "瑕", "锛"]
	for marker in bad_markers:
		if text.find(marker) >= 0:
			return fallback
	if text == "":
		return fallback
	return text


func _set_btn(btn: Button, enabled: bool, text: String, tooltip: String, color: Color) -> void:
	btn.disabled = not enabled
	btn.text = text
	btn.tooltip_text = tooltip
	btn.add_theme_color_override("font_color", color if enabled else Color(0.52, 0.52, 0.56))
	_apply_btn_styles(btn, color, enabled)


func _build_style() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.055, 0.115, 0.96)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.30, 0.50, 0.72, 0.92)
	style.set_corner_radius_all(5)
	add_theme_stylebox_override("panel", style)


func _build_title() -> void:
	var title := Label.new()
	title.name = "TitleLabel"
	title.text = ""
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.add_theme_font_size_override("font_size", 10)
	title.add_theme_color_override("font_color", Color(0.82, 0.82, 0.95, 1))
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_left = MENU_PAD
	title.offset_right = -MENU_PAD
	title.offset_top = MENU_PAD
	title.offset_bottom = MENU_PAD + 20
	add_child(title)
	_title_label = title


## Phase 27I-R0-R2: 独立的棋子信息条（标题与按钮之间；只读展示棋型与强化）
func _build_piece_info() -> void:
	var panel := Panel.new()
	panel.name = "PieceInfoPanel"
	panel.visible = false
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.anchor_left = 0.0
	panel.anchor_right = 1.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.05, 0.09, 0.9)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.50, 0.42, 0.20, 0.7)
	style.set_corner_radius_all(3)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var badge := Label.new()
	badge.name = "PieceBadgeLabel"
	badge.add_theme_font_size_override("font_size", 10)
	badge.add_theme_color_override("font_color", Color(0.95, 0.9, 0.45, 1))
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.set_anchors_preset(Control.PRESET_TOP_WIDE)
	badge.offset_top = 1
	badge.offset_bottom = 15
	panel.add_child(badge)

	var summary := Label.new()
	summary.name = "PieceSummaryLabel"
	summary.add_theme_font_size_override("font_size", 9)
	summary.add_theme_color_override("font_color", Color(0.75, 0.8, 0.92, 1))
	summary.clip_text = true
	summary.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	summary.set_anchors_preset(Control.PRESET_TOP_WIDE)
	summary.offset_left = 4
	summary.offset_right = -4
	summary.offset_top = 14
	summary.offset_bottom = 26
	panel.add_child(summary)

	_piece_info_panel = panel


func _build_buttons() -> void:
	var hbox := HBoxContainer.new()
	hbox.name = "MenuHBox"
	hbox.set_anchors_preset(Control.PRESET_TOP_WIDE)
	hbox.offset_left = MENU_PAD
	hbox.offset_right = -MENU_PAD
	hbox.offset_top = MENU_PAD + 22
	hbox.offset_bottom = MENU_PAD + 22 + BTN_HEIGHT
	hbox.add_theme_constant_override("separation", BTN_GAP)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(hbox)
	_menu_hbox = hbox

	_buttons.clear()
	_add_button(hbox, "攻击", "attack", Color(1.0, 0.55, 0.2))
	_add_button(hbox, "移动", "move", Color(0.3, 0.85, 0.85))
	_add_button(hbox, "回防", "turn", Color(0.6, 0.75, 1.0))
	_add_button(hbox, "效果", "effect", Color(0.4, 0.85, 1.0))
	_add_button(hbox, "升格", "ascend", Color(1.0, 0.85, 0.2))
	_add_button(hbox, "详情", "detail", Color(0.72, 0.72, 0.88))
	_add_button(hbox, "关闭", "cancel", Color(0.56, 0.56, 0.62))
	# Phase 27E-R1: skill button (hidden by default)
	_skill_btn = Button.new()
	_skill_btn.text = "技能"
	_skill_btn.clip_text = true
	_skill_btn.custom_minimum_size = Vector2(BTN_WIDTH, BTN_HEIGHT)
	_skill_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	_skill_btn.add_theme_font_size_override("font_size", 11)
	_skill_btn.add_theme_color_override("font_color", Color(0.9, 0.75, 0.2))
	_skill_btn.pressed.connect(_on_button_pressed.bind("skill"))
	_skill_btn.visible = false
	hbox.add_child(_skill_btn)
	_buttons.append(_skill_btn)
	# Elevated Grid Phase D1: append after every existing command so indices
	# 0..7 remain byte-for-byte compatible with earlier command routing.
	_add_button(hbox, "驻防", "garrison", Color(0.35, 0.9, 0.86))
	_garrison_btn = _buttons[_buttons.size() - 1]
	_garrison_btn.visible = false
	_resize_to_fit()


func _build_arrow() -> void:
	var arrow := ColorRect.new()
	arrow.name = "ArrowPolygon"
	arrow.color = Color(0.055, 0.055, 0.115, 0.96)
	arrow.size = Vector2(10, 6)
	arrow.pivot_offset = Vector2(5, 0)
	arrow.rotation_degrees = 45
	arrow.visible = false
	add_child(arrow)


func _add_button(parent: HBoxContainer, text: String, action: String, color: Color) -> void:
	var btn := Button.new()
	btn.text = text
	btn.clip_text = true
	btn.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	btn.custom_minimum_size = Vector2(BTN_WIDTH, BTN_HEIGHT)
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.add_theme_font_size_override("font_size", 11)
	btn.add_theme_color_override("font_color", color)
	btn.pressed.connect(_on_button_pressed.bind(action))
	parent.add_child(btn)
	_buttons.append(btn)
	_apply_btn_styles(btn, color, true)


func _apply_btn_styles(btn: Button, color: Color, enabled: bool) -> void:
	var base_bg := Color(0.06, 0.06, 0.10, 1)
	var norm := _make_btn_box(base_bg, Color(color.r, color.g, color.b, 0.65), 1)
	var hover := _make_btn_box(Color(base_bg.r + 0.08, base_bg.g + 0.08, base_bg.b + 0.12, 1), Color(color.r, color.g, color.b, 0.88), 1)
	var pressed := _make_btn_box(Color(0.03, 0.03, 0.06, 1), Color(color.r, color.g, color.b, 0.55), 2)
	var disabled := _make_btn_box(Color(0.08, 0.08, 0.09, 0.7), Color(0.15, 0.15, 0.17, 0.5), 1)

	btn.add_theme_stylebox_override("normal", norm)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("disabled", disabled)
	btn.add_theme_stylebox_override("focus", hover if enabled else disabled)


func _make_btn_box(bg: Color, border: Color, width: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_width_left = width
	box.border_width_right = width
	box.border_width_top = width
	box.border_width_bottom = width
	box.border_color = border
	box.set_corner_radius_all(3)
	return box


func _button_action(index: int) -> String:
	var actions := ["attack", "move", "turn", "effect", "ascend", "detail", "cancel", "skill", "garrison"]
	if index < 0 or index >= actions.size():
		return ""
	return actions[index]


func _resize_to_fit() -> void:
	if is_instance_valid(_focus_scroll):
		_resize_focus_dock();return
	var total_w := BTN_WIDTH * _buttons.size() + BTN_GAP * (_buttons.size() - 1) + MENU_PAD * 2
	# Measure title and both piece labels before placing the action row.
	var title_h: float = 24.0
	if _title_label:
		title_h = maxf(20.0, _title_label.get_minimum_size().y)
	var piece_h := 0.0
	if _piece_info_panel and _piece_info_panel.visible:
		piece_h = 18.0
		for child in _piece_info_panel.get_children():
			if child is Label:
				piece_h = maxf(piece_h, child.position.y + child.get_combined_minimum_size().y + 3.0)
	var title_bottom := MENU_PAD + title_h
	var guidance_top := title_bottom + piece_h + BTN_HEIGHT + 4
	var guidance_h := 0.0
	if _garrison_guidance != null and _garrison_guidance.visible:
		var font := _garrison_guidance.get_theme_font("font")
		guidance_h = font.get_multiline_string_size(_garrison_guidance.text, HORIZONTAL_ALIGNMENT_LEFT, total_w - MENU_PAD * 2, 12).y + 6.0
		_garrison_guidance.position = Vector2(MENU_PAD, guidance_top)
		_garrison_guidance.size = Vector2(total_w - MENU_PAD * 2, guidance_h)
		guidance_h = maxf(guidance_h, _garrison_guidance.get_minimum_size().y)
	var ascension_h := 0.0
	if _ascension_guidance != null and _ascension_guidance.visible:
		var font := _ascension_guidance.get_theme_font("font")
		ascension_h = font.get_multiline_string_size(_ascension_guidance.text, HORIZONTAL_ALIGNMENT_LEFT, total_w - MENU_PAD * 2, 12).y + 6.0
		_ascension_guidance.position = Vector2(MENU_PAD, guidance_top + guidance_h)
		_ascension_guidance.size = Vector2(total_w - MENU_PAD * 2, ascension_h)
		ascension_h = maxf(ascension_h, _ascension_guidance.get_minimum_size().y)
	custom_minimum_size = Vector2(total_w, guidance_top + guidance_h + ascension_h + MENU_PAD)
	size = custom_minimum_size
	# 布局：标题 → 棋子信息条 → 按钮（三个区域互不相交）
	if _title_label:
		_title_label.offset_left = MENU_PAD
		_title_label.offset_right = -MENU_PAD
		_title_label.offset_top = MENU_PAD
		_title_label.offset_bottom = title_bottom
	if _piece_info_panel:
		_piece_info_panel.offset_left = MENU_PAD
		_piece_info_panel.offset_right = -MENU_PAD
		_piece_info_panel.offset_top = title_bottom
		_piece_info_panel.offset_bottom = title_bottom + piece_h
		_piece_info_panel.visible = piece_h > 0
	if _menu_hbox:
		_menu_hbox.offset_left = MENU_PAD
		_menu_hbox.offset_right = -MENU_PAD
		_menu_hbox.offset_top = title_bottom + piece_h
		_menu_hbox.offset_bottom = title_bottom + piece_h + BTN_HEIGHT


func _on_button_pressed(action: String) -> void:
	command_selected.emit(action, _card)


func _exit_tree() -> void:
	_buttons.clear()

## Opt-in presentation only: original buttons, signals, legality and reasons stay native.
func use_focus_dock(width: float,height: float) -> void:
	_focus_width=width;_focus_height=height
	if not is_instance_valid(_focus_scroll):
		_focus_scroll=ScrollContainer.new();_focus_scroll.name="FocusCommandScroll";_focus_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;add_child(_focus_scroll)
		_focus_body=VBoxContainer.new();_focus_body.size_flags_horizontal=Control.SIZE_EXPAND_FILL;_focus_body.add_theme_constant_override("separation",8);_focus_scroll.add_child(_focus_body)
		for node: Control in [_title_label,_piece_info_panel]:
			node.reparent(_focus_body);node.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT);node.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		_title_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;_title_label.clip_text=false;_title_label.add_theme_font_size_override("font_size",14)
		_piece_info_panel.custom_minimum_size.y=32
		var grid:=GridContainer.new();grid.name="FocusCommands";grid.columns=3;grid.add_theme_constant_override("h_separation",5);grid.add_theme_constant_override("v_separation",6);_focus_body.add_child(grid)
		for button: Button in _buttons:
			button.reparent(grid);button.custom_minimum_size=Vector2(66,34);button.size_flags_horizontal=Control.SIZE_EXPAND_FILL;button.add_theme_font_size_override("font_size",12)
		_menu_hbox.hide()
		for node: Label in [_garrison_guidance,_ascension_guidance]:
			node.reparent(_focus_body);node.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT);node.size_flags_horizontal=Control.SIZE_EXPAND_FILL;node.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	_resize_focus_dock()
func _resize_focus_dock() -> void:
	var grid: GridContainer=_focus_body.get_node("FocusCommands")
	grid.columns=3 if _focus_width-32>=208 else 2 if _focus_width-32>=137 else 1
	custom_minimum_size=Vector2(_focus_width,0);size=Vector2(_focus_width,_focus_height)
	_focus_scroll.position=Vector2(8,8);_focus_scroll.size=size-Vector2(16,16)
	for label: Label in [_title_label,_garrison_guidance,_ascension_guidance]:label.custom_minimum_size.x=maxf(100,_focus_width-48)
