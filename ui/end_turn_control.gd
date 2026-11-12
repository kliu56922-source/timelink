extends Control
class_name EndTurnControl
## Phase 27D-R5-R2: Compact end turn control
##
## Replaces the old full-height right rail end turn button.
## States: READY_WITH_POINTS | READY_EMPTY | CONFIRM | BUSY

# ═══════════════════════════════════════════
# State management
# ═══════════════════════════════════════════

signal end_turn_requested()

enum State { READY_WITH_POINTS, READY_EMPTY, CONFIRM, BUSY }

var _state: State = State.READY_WITH_POINTS
var _economy_callback: Callable = Callable()
var _end_turn_callback: Callable = Callable()
var _current_points: int = 0
var _max_points: int = 0
var _busy_text: String = ""
var _preparation_mode:=false
func set_preparation_mode(enabled: bool) -> void:
	if enabled==_preparation_mode:return
	_preparation_mode=enabled
	if _state!=State.BUSY:cancel_confirm()

var _main_btn: Button = null
var _confirm_panel: Control = null
var _sub_label: Label = null


func _ready() -> void:
	custom_minimum_size = Vector2(140, 56)
	size = Vector2(160, 70)
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true  # Phase 27D-R5-R2-R: prevent child overflow
	_build_ui()


func _build_ui() -> void:
	# Main button
	_main_btn = Button.new()
	_main_btn.name = "EndTurnMainBtn"
	_main_btn.text = "结束回合"
	_main_btn.custom_minimum_size = Vector2(140, 56)
	_main_btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	_main_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_main_btn)

	# Sub label — Phase 27D-R5-R2-R: text fully inside button, positive offsets only
	_sub_label = Label.new()
	_sub_label.name = "SubLabel"
	_sub_label.text = ""
	_sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_sub_label.add_theme_font_size_override("font_size", 10)
	_sub_label.add_theme_color_override("font_color", Color(0.7, 0.8, 0.95, 1))
	_sub_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Phase 27D-R5-R2-R: manual anchors with positive offsets (all inside 70px control)
	_sub_label.anchor_left = 0.0
	_sub_label.anchor_top = 0.0
	_sub_label.anchor_right = 1.0
	_sub_label.anchor_bottom = 0.0
	_sub_label.offset_left = 8
	_sub_label.offset_top = 48
	_sub_label.offset_right = -8
	_sub_label.offset_bottom = 66
	add_child(_sub_label)

	_apply_style()
	_main_btn.pressed.connect(_on_main_pressed)

	# Confirm panel (hidden by default)
	_confirm_panel = Control.new()
	_confirm_panel.name = "ConfirmPanel"
	_confirm_panel.visible = false
	_confirm_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_confirm_panel)

	_build_confirm_panel()


func _apply_style() -> void:
	if _main_btn == null:
		return

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.08, 0.10, 0.18, 0.97)  # Phase 27D-R5-R2-R: alpha 0.97 blocks bg text
	normal.border_color = Color(0.2, 0.5, 0.7, 1.0)
	normal.border_width_left = 1; normal.border_width_right = 1
	normal.border_width_top = 1; normal.border_width_bottom = 1
	normal.set_corner_radius_all(8)
	_main_btn.add_theme_stylebox_override("normal", normal)

	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(0.12, 0.16, 0.26, 0.97)
	hover.border_color = Color(0.9, 0.7, 0.2, 1.0)
	hover.border_width_left = 1; hover.border_width_right = 1
	hover.border_width_top = 1; hover.border_width_bottom = 1
	hover.set_corner_radius_all(8)
	_main_btn.add_theme_stylebox_override("hover", hover)

	var pressed := StyleBoxFlat.new()
	pressed.bg_color = Color(0.15, 0.20, 0.32, 0.96)
	pressed.border_color = Color(0.9, 0.6, 0.1, 1.0)
	pressed.border_width_left = 1; pressed.border_width_right = 1
	pressed.border_width_top = 1; pressed.border_width_bottom = 1
	pressed.set_corner_radius_all(8)
	_main_btn.add_theme_stylebox_override("pressed", pressed)

	var disabled_style := StyleBoxFlat.new()
	disabled_style.bg_color = Color(0.05, 0.07, 0.12, 0.72)  # Phase 27D-R5-R2-R: alpha 0.72 reduced but visible
	disabled_style.border_color = Color(0.15, 0.2, 0.3, 0.6)
	disabled_style.border_width_left = 1; disabled_style.border_width_right = 1
	disabled_style.border_width_top = 1; disabled_style.border_width_bottom = 1
	disabled_style.set_corner_radius_all(8)
	_main_btn.add_theme_stylebox_override("disabled", disabled_style)

	_main_btn.add_theme_font_size_override("font_size", 15)
	_main_btn.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0, 1))
	_main_btn.add_theme_color_override("font_hover_color", Color(0.9, 0.95, 1.0, 1))
	_main_btn.add_theme_color_override("font_disabled_color", Color(0.4, 0.4, 0.5, 0.7))


func _apply_confirm_btn_style(btn: Button, border_c: Color) -> void:
	if btn == null:
		return
	var ns := StyleBoxFlat.new()
	ns.bg_color = Color(0.08, 0.10, 0.18, 0.94)
	ns.border_color = border_c
	ns.border_width_left = 1; ns.border_width_right = 1
	ns.border_width_top = 1; ns.border_width_bottom = 1
	ns.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("normal", ns)

	var hs := StyleBoxFlat.new()
	hs.bg_color = Color(0.14, 0.18, 0.28, 0.95)
	hs.border_color = Color(0.9, 0.7, 0.2, 1.0)
	hs.border_width_left = 1; hs.border_width_right = 1
	hs.border_width_top = 1; hs.border_width_bottom = 1
	hs.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("hover", hs)

	btn.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0, 1))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0, 1))

	var ds := StyleBoxFlat.new()
	ds.bg_color = Color(0.05, 0.07, 0.12, 0.72)
	ds.border_color = Color(0.3, 0.3, 0.4, 0.5)
	ds.border_width_left = 1; ds.border_width_right = 1
	ds.border_width_top = 1; ds.border_width_bottom = 1
	ds.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("disabled", ds)
	btn.add_theme_color_override("font_disabled_color", Color(0.4, 0.4, 0.5, 0.7))


func _build_confirm_panel() -> void:
	if _confirm_panel == null:
		return

	var panel_bg := Panel.new()
	panel_bg.name = "ConfirmBg"
	panel_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.06, 0.08, 0.15, 0.97)  # Phase 27D-R5-R2-R: alpha 0.97
	bg_style.border_color = Color(0.8, 0.45, 0.1, 0.9)
	bg_style.border_width_left = 1; bg_style.border_width_right = 1
	bg_style.border_width_top = 1; bg_style.border_width_bottom = 1
	bg_style.set_corner_radius_all(6)
	panel_bg.add_theme_stylebox_override("panel", bg_style)
	_confirm_panel.add_child(panel_bg)

	var title := Label.new()
	title.name = "ConfirmTitle"
	title.text = "确认结束？"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 12)  # Phase 27D-R5-R2-R: 12pt to fit 70px
	title.add_theme_color_override("font_color", Color(0.9, 0.85, 0.4, 1))
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.anchor_left = 0; title.anchor_right = 1
	title.offset_top = 2; title.offset_bottom = 18
	_confirm_panel.add_child(title)

	var hint := Label.new()
	hint.name = "ConfirmHint"
	hint.text = "将放弃 N 点战术指令"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 9)  # Phase 27D-R5-R2-R: 9pt to fit 70px
	hint.add_theme_color_override("font_color", Color(0.75, 0.7, 0.6, 1))
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.anchor_left = 0; hint.anchor_right = 1
	hint.offset_top = 20; hint.offset_bottom = 34
	_confirm_panel.add_child(hint)

	var btn_box := HBoxContainer.new()
	btn_box.name = "ConfirmBtnBox"
	btn_box.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_box.add_theme_constant_override("separation", 8)
	btn_box.anchor_left = 0; btn_box.anchor_right = 1
	btn_box.offset_top = 36; btn_box.offset_bottom = 66
	_confirm_panel.add_child(btn_box)

	var yes_btn := Button.new()
	yes_btn.name = "ConfirmYes"
	yes_btn.text = "确认"
	yes_btn.custom_minimum_size = Vector2(48, 24)  # Phase 27D-R5-R2-R: compact to fit 70px
	yes_btn.add_theme_font_size_override("font_size", 11)
	_apply_confirm_btn_style(yes_btn, Color(0.8, 0.45, 0.1, 1.0))
	yes_btn.pressed.connect(_on_confirm_yes)
	btn_box.add_child(yes_btn)

	var no_btn := Button.new()
	no_btn.name = "ConfirmNo"
	no_btn.text = "取消"
	no_btn.custom_minimum_size = Vector2(48, 24)  # Phase 27D-R5-R2-R: compact to fit 70px
	no_btn.add_theme_font_size_override("font_size", 11)
	_apply_confirm_btn_style(no_btn, Color(0.4, 0.5, 0.6, 1.0))
	no_btn.pressed.connect(_on_confirm_no)
	btn_box.add_child(no_btn)


# ═══════════════════════════════════════════
# Public API
# ═══════════════════════════════════════════

func configure_economy(cb: Callable) -> void:
	_economy_callback = cb


func set_end_turn_callback(cb: Callable) -> void:
	_end_turn_callback = cb


func set_confirm_callback(cb: Callable) -> void:
	# Alias for set_end_turn_callback — smoke tests use both names
	_end_turn_callback = cb


func refresh() -> void:
	if _economy_callback.is_valid():
		var snapshot: Dictionary = _economy_callback.call()
		_current_points = int(snapshot.get("current_points", 0))
		_max_points = int(snapshot.get("turn_max_points", 0))

	# Preserve transient lifecycle states while external HUD refreshes update the cache.
	if _state == State.BUSY:
		return
	if _state == State.CONFIRM:
		if _sub_label:
			_sub_label.text = "将放弃 %d 点 · 再次点击" % _current_points
		return
	_update_display()


func _update_display() -> void:
	if _state == State.BUSY:
		# Still update sub label text for busy description
		if _sub_label and _busy_text.length() > 0:
			_sub_label.text = _busy_text
		return
	if _preparation_mode:
		_state=State.READY_WITH_POINTS if _current_points>0 else State.READY_EMPTY
		_main_btn.text="部署完成 · 进入交战"
		if _sub_label:_sub_label.text="余点不结转 · Boss先蓄压"
		if _confirm_panel:_confirm_panel.hide()
		return

	if _current_points <= 0:
		_state = State.READY_EMPTY
		_main_btn.text = "结束回合"
		if _sub_label:
			_sub_label.text = "指令耗尽"
	else:
		_state = State.READY_WITH_POINTS
		_main_btn.text = "结束回合"
		if _sub_label:
			_sub_label.text = "剩余 %d 点" % _current_points

	if _confirm_panel:
		_confirm_panel.visible = false


func press_end_turn() -> void:
	if _state == State.BUSY:
		return
	if _preparation_mode:
		_execute_end_turn();return

	# Phase 27E-R5: re-read authoritative snapshot to avoid stale cache
	if _economy_callback.is_valid():
		var snapshot: Dictionary = _economy_callback.call()
		_current_points = int(snapshot.get("current_points", 0))
		_max_points = int(snapshot.get("turn_max_points", 0))

	# Compact-control fail-safe: the same visible button commits an armed confirm.
	if _state == State.CONFIRM:
		_execute_end_turn()
		return

	if _current_points <= 0:
		# Direct end — no confirm needed
		_execute_end_turn()
		return

	# Enter confirm state
	_state = State.CONFIRM
	_show_confirm()


func _show_confirm() -> void:
	# The old full-rect overlay could be clipped in the battle CanvasLayer while it
	# still disabled the main button.  Keep the node for API compatibility, but use
	# an explicit two-press confirmation on the always-visible compact control.
	if _confirm_panel:
		_confirm_panel.visible = false
		var hint: Label = _confirm_panel.find_child("ConfirmHint", true, false)
		if hint:
			hint.text = "将放弃 %d 点战术指令" % _current_points

	if _main_btn:
		_main_btn.disabled = false
		_main_btn.text = "确认结束?"
	if _sub_label:
		_sub_label.text = "将放弃 %d 点 · 再次点击" % _current_points


func confirm_end_turn() -> void:
	_execute_end_turn()


func cancel_confirm() -> void:
	if _confirm_panel:
		_confirm_panel.visible = false
	if _main_btn:
		_main_btn.disabled = false
	_update_display()


func reset_state() -> void:
	cancel_confirm()
	_state = State.READY_WITH_POINTS if _current_points > 0 else State.READY_EMPTY
	_update_display()


func set_busy(busy: bool, text: String = "") -> void:
	if busy:
		_state = State.BUSY
		_busy_text = text
		if _main_btn:
			_main_btn.disabled = true
			_main_btn.text = "处理中"
		if _sub_label:
			_sub_label.text = text
		if _confirm_panel:
			_confirm_panel.visible = false
	else:
		_state = State.READY_WITH_POINTS if _current_points > 0 else State.READY_EMPTY
		_busy_text = ""
		if _main_btn:
			_main_btn.disabled = false
		_update_display()


func is_busy() -> bool:
	return _state == State.BUSY


func get_state() -> String:
	match _state:
		State.READY_WITH_POINTS: return "READY_WITH_POINTS"
		State.READY_EMPTY: return "READY_EMPTY"
		State.CONFIRM: return "CONFIRM"
		State.BUSY: return "BUSY"
		_: return "UNKNOWN"


func get_busy_text() -> String:
	return _busy_text


func get_state_info() -> Dictionary:
	return {"state": get_state(), "current": _current_points, "max": _max_points}


func get_economy_source() -> String:
	return "BattleSystem.get_command_economy_snapshot"


# ═══════════════════════════════════════════
# Internal
# ═══════════════════════════════════════════

func _on_main_pressed() -> void:
	press_end_turn()


func _on_confirm_yes() -> void:
	_execute_end_turn()


func _on_confirm_no() -> void:
	cancel_confirm()


func _execute_end_turn() -> void:
	# Prevent double-fire
	if _state == State.BUSY:
		return
	_state = State.BUSY
	if _main_btn:
		_main_btn.disabled = true
	if _confirm_panel:
		_confirm_panel.visible = false

	end_turn_requested.emit()
	if _end_turn_callback.is_valid():
		_end_turn_callback.call()


# ═══════════════════════════════════════════
# Input handling (Esc/right-click cancel)
# ═══════════════════════════════════════════

func _gui_input(event: InputEvent) -> void:
	if _state != State.CONFIRM:
		return
	if event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed:
		cancel_confirm()
		accept_event()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		cancel_confirm()
		accept_event()
		return
