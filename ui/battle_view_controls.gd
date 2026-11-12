class_name BattleViewControls
extends CanvasLayer
## Phase 23A-V2-R: Isolated view-control UI with responsive layout.
## CanvasLayer → screen-space, never inherits camera transforms.
## No access to BattleSystem / Camera3D / GameManager.

# ── Signals ──
signal base_view_requested
signal top_view_requested
signal camera_free_view_toggled(enabled: bool)
signal exit_modal_opened
signal exit_modal_closed
signal return_to_menu_confirmed

# ── Theme colors ──
const ACTIVE_BORDER := Color(0.85, 0.65, 0.25, 1)    # gold / bronze
const ACTIVE_BG := Color(0.18, 0.12, 0.04, 0.92)       # dark gold tint
const ACTIVE_HOVER := Color(0.24, 0.16, 0.06, 0.94)     # brighter gold
const ACTIVE_PRESSED := Color(0.13, 0.08, 0.02, 0.90)    # darker
const ACTIVE_FONT := Color(0.97, 0.80, 0.18, 1)          # warm gold
const ACTIVE_GLOW := Color(0.97, 0.80, 0.18, 0.35)

const INACTIVE_BORDER := Color(0.27, 0.85, 0.76, 1)     # cyan / steel
const INACTIVE_HOVER := Color(0.16, 0.20, 0.26, 0.94)
const INACTIVE_FONT := Color(0.55, 0.55, 0.64, 1)       # secondary grey

const MODAL_OVERLAY := Color(0.0, 0.0, 0.0, 0.55)
const MODAL_PANEL_BG := Color(0.08, 0.08, 0.13, 0.97)
const BTN_BG := Color(0.09, 0.09, 0.14, 0.88)
const BTN_HOVER := Color(0.14, 0.14, 0.21, 0.92)
const BTN_PRESSED := Color(0.06, 0.06, 0.09, 0.90)

const DANGER_BG := Color(0.18, 0.06, 0.04, 0.95)
const DANGER_HOVER := Color(0.28, 0.09, 0.05, 0.95)
const DANGER_FONT := Color(1.0, 0.85, 0.7, 1)

const PANEL_X: float = 280.0
const PANEL_Y: float = 140.0
const EDGE_MARGIN: float = 8.0

# ── Internal nodes ──
var _root: Control = null
var _exit_button: Button = null
var _base_button: Button = null
var _top_button: Button = null
var _free_button: Button = null
var _modal_overlay: Control = null
var _confirm_panel: Panel = null
var _continue_button: Button = null
var _confirm_exit_button: Button = null
var _modal_open: bool = false
var _active_preset: String = "base"
var _free_view_active: bool = false


func _ready() -> void:
	layer = 100
	_build_ui()
	_update_active_style()
	_modal_overlay.visible = false


## Set the active view preset and update button styles.
func set_active_preset(preset_name: StringName) -> void:
	var s: String = str(preset_name).to_lower()
	if s == "base" or s == "top":
		_active_preset = s
	elif s == "free":
		_active_preset = "free"
	_update_active_style()


## Toggle the explicit camera adjustment mode without changing preset state.
func set_free_view_active(enabled: bool) -> void:
	_free_view_active = enabled
	_update_active_style()


## Returns true if the exit confirmation modal is currently open.
func is_modal_open() -> bool:
	return _modal_open


## Open the exit confirmation modal. Emits exit_modal_opened.
func open_exit_modal() -> void:
	if _modal_open:
		return
	_modal_open = true
	_modal_overlay.visible = true
	_modal_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	if _continue_button:
		_continue_button.grab_focus()
	exit_modal_opened.emit()


## Close the exit confirmation modal. Emits exit_modal_closed.
func close_exit_modal() -> void:
	if not _modal_open:
		return
	_modal_open = false
	_modal_overlay.visible = false
	_modal_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	exit_modal_closed.emit()


# ══════════════════════════════════════════════════════════════
# Private: Build the UI tree
# ══════════════════════════════════════════════════════════════

func _build_ui() -> void:
	# ── Root Control: full screen, MOUSE_FILTER_IGNORE ──
	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_build_exit_button()
	_build_view_toggles()
	_build_modal()


## 左上角 — 返回主菜单按钮
func _build_exit_button() -> void:
	_exit_button = _make_button("ExitButton", "返回主菜单")
	_exit_button.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_exit_button.position = Vector2(12, EDGE_MARGIN)
	_exit_button.custom_minimum_size = Vector2(80, 26)
	_exit_button.pressed.connect(_on_exit_pressed)
	_root.add_child(_exit_button)


## 顶部中央 — CenterContainer 包裹 HBox，真正水平居中
func _build_view_toggles() -> void:
	var host: CenterContainer = CenterContainer.new()
	host.name = "TopCenterHost"
	host.set_anchors_preset(Control.PRESET_TOP_WIDE)
	host.offset_top = int(EDGE_MARGIN)
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(host)

	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.name = "ViewToggleHBox"
	hbox.add_theme_constant_override("separation", 0)
	host.add_child(hbox)

	_base_button = _make_toggle_button("BaseViewButton", "基础视角")
	_base_button.pressed.connect(_on_base_pressed)
	hbox.add_child(_base_button)

	_top_button = _make_toggle_button("TopViewButton", "顶视角")
	_top_button.pressed.connect(_on_top_pressed)
	hbox.add_child(_top_button)

	_free_button = _make_toggle_button("FreeViewButton", "调整视角")
	_free_button.custom_minimum_size = Vector2(82, 26)
	_free_button.pressed.connect(_on_free_pressed)
	hbox.add_child(_free_button)


## 模态框：半透明覆盖层 + 居中面板
func _build_modal() -> void:
	# ── Full-screen overlay ──
	_modal_overlay = Control.new()
	_modal_overlay.name = "ModalOverlay"
	_modal_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_modal_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_modal_overlay)

	var dim: ColorRect = ColorRect.new()
	dim.name = "ModalDimBg"
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = MODAL_OVERLAY
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(_on_modal_bg_clicked)
	_modal_overlay.add_child(dim)

	# ── Centered confirm panel ──
	_confirm_panel = Panel.new()
	_confirm_panel.name = "ConfirmPanel"
	_confirm_panel.set_anchors_preset(Control.PRESET_CENTER)
	_confirm_panel.size = Vector2(PANEL_X, PANEL_Y)
	_confirm_panel.position = Vector2(-PANEL_X * 0.5, -PANEL_Y * 0.5)
	var ps: StyleBoxFlat = StyleBoxFlat.new()
	ps.bg_color = MODAL_PANEL_BG
	ps.border_color = ACTIVE_BORDER
	ps.border_width_left = 1
	ps.border_width_right = 1
	ps.border_width_top = 1
	ps.border_width_bottom = 1
	ps.set_corner_radius_all(8)
	_confirm_panel.add_theme_stylebox_override("panel", ps)
	_confirm_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_modal_overlay.add_child(_confirm_panel)

	# Title
	var title: Label = Label.new()
	title.name = "ModalTitle"
	title.text = "退出本场战斗？"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color.WHITE)
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 16
	_confirm_panel.add_child(title)

	# Subtitle
	var sub: Label = Label.new()
	sub.name = "ModalSubtitle"
	sub.text = "当前战斗进度不会保存"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 12)
	sub.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65, 1))
	sub.set_anchors_preset(Control.PRESET_TOP_WIDE)
	sub.offset_top = 42
	_confirm_panel.add_child(sub)

	# ── Button row: CenterContainer anchored to panel bottom ──
	var btn_host: CenterContainer = CenterContainer.new()
	btn_host.name = "ModalButtonHost"
	btn_host.anchor_left = 0.0
	btn_host.anchor_right = 1.0
	btn_host.anchor_bottom = 1.0
	btn_host.anchor_top = 1.0
	btn_host.offset_top = -36
	btn_host.offset_bottom = -6
	btn_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_confirm_panel.add_child(btn_host)

	var btn_row: HBoxContainer = HBoxContainer.new()
	btn_row.name = "ModalButtonRow"
	btn_row.add_theme_constant_override("separation", 16)
	btn_host.add_child(btn_row)

	_continue_button = _make_modal_button("ContinueButton", "继续战斗", false)
	_continue_button.pressed.connect(_on_continue_pressed)
	btn_row.add_child(_continue_button)

	_confirm_exit_button = _make_modal_button("ConfirmExitButton", "返回主菜单", true)
	_confirm_exit_button.pressed.connect(_on_confirm_exit_pressed)
	btn_row.add_child(_confirm_exit_button)


# ══════════════════════════════════════════════════════════════
# Button factories
# ══════════════════════════════════════════════════════════════

func _make_button(p_name: String, p_text: String) -> Button:
	var btn: Button = Button.new()
	btn.name = p_name
	btn.text = p_text
	btn.add_theme_font_size_override("font_size", 11)
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	_set_btn_states(btn, BTN_BG, BTN_HOVER, BTN_PRESSED, INACTIVE_BORDER, INACTIVE_FONT)
	return btn


func _make_toggle_button(p_name: String, p_text: String) -> Button:
	var btn: Button = Button.new()
	btn.name = p_name
	btn.text = p_text
	btn.custom_minimum_size = Vector2(72, 26)
	btn.add_theme_font_size_override("font_size", 11)
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	return btn


func _make_modal_button(p_name: String, p_text: String, danger: bool) -> Button:
	var btn: Button = Button.new()
	btn.name = p_name
	btn.text = p_text
	btn.custom_minimum_size = Vector2(100, 28)
	btn.add_theme_font_size_override("font_size", 12)
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	if danger:
		_set_btn_states(btn, DANGER_BG, DANGER_HOVER, BTN_PRESSED, ACTIVE_BORDER, DANGER_FONT)
	else:
		_set_btn_states(btn, BTN_BG, BTN_HOVER, BTN_PRESSED, INACTIVE_BORDER, INACTIVE_FONT)
	return btn


## Apply StyleBoxFlat for all four states: normal / hover / pressed / focus.
func _set_btn_states(btn: Button, bg: Color, hover_bg: Color, pressed_bg: Color, border: Color, font_c: Color) -> void:
	var normal: StyleBoxFlat = StyleBoxFlat.new()
	normal.bg_color = bg
	normal.border_color = border
	normal.border_width_left = 1
	normal.border_width_right = 1
	normal.border_width_top = 1
	normal.border_width_bottom = 1
	normal.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("normal", normal)

	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = hover_bg
	btn.add_theme_stylebox_override("hover", hover)

	var pressed: StyleBoxFlat = normal.duplicate()
	pressed.bg_color = pressed_bg
	btn.add_theme_stylebox_override("pressed", pressed)

	var focus: StyleBoxFlat = normal.duplicate()
	btn.add_theme_stylebox_override("focus", focus)

	btn.add_theme_color_override("font_color", font_c)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_pressed_color", font_c)
	btn.add_theme_color_override("font_focus_color", Color.WHITE)


# ══════════════════════════════════════════════════════════════
# Active / inactive visual update — all four states
# ══════════════════════════════════════════════════════════════

func _update_active_style() -> void:
	_apply_toggle_style(_base_button, _active_preset == "base")
	_apply_toggle_style(_top_button, _active_preset == "top")
	_apply_toggle_style(_free_button, _free_view_active)
	if _free_button:
		_free_button.text = "锁定视角" if _free_view_active else "调整视角"


func _apply_toggle_style(btn: Button, active: bool) -> void:
	if btn == null:
		return
	if active:
		var normal: StyleBoxFlat = StyleBoxFlat.new()
		normal.bg_color = ACTIVE_BG
		normal.border_color = ACTIVE_BORDER
		normal.border_width_left = 2
		normal.border_width_right = 2
		normal.border_width_top = 2
		normal.border_width_bottom = 2
		normal.set_corner_radius_all(4)
		normal.shadow_color = ACTIVE_GLOW
		normal.shadow_size = 4
		normal.shadow_offset = Vector2(0, 0)
		btn.add_theme_stylebox_override("normal", normal)

		var hover: StyleBoxFlat = normal.duplicate()
		hover.bg_color = ACTIVE_HOVER
		btn.add_theme_stylebox_override("hover", hover)

		var pressed: StyleBoxFlat = normal.duplicate()
		pressed.bg_color = ACTIVE_PRESSED
		pressed.shadow_size = 2
		btn.add_theme_stylebox_override("pressed", pressed)

		var focus: StyleBoxFlat = normal.duplicate()
		btn.add_theme_stylebox_override("focus", focus)

		btn.add_theme_color_override("font_color", ACTIVE_FONT)
		btn.add_theme_color_override("font_hover_color", Color.WHITE)
		btn.add_theme_color_override("font_pressed_color", ACTIVE_FONT)
		btn.add_theme_color_override("font_focus_color", Color.WHITE)
	else:
		var normal: StyleBoxFlat = StyleBoxFlat.new()
		normal.bg_color = BTN_BG
		normal.border_color = INACTIVE_BORDER
		normal.border_width_left = 1
		normal.border_width_right = 1
		normal.border_width_top = 1
		normal.border_width_bottom = 1
		normal.set_corner_radius_all(4)
		btn.add_theme_stylebox_override("normal", normal)

		var hover: StyleBoxFlat = normal.duplicate()
		hover.bg_color = INACTIVE_HOVER
		btn.add_theme_stylebox_override("hover", hover)

		var pressed: StyleBoxFlat = normal.duplicate()
		pressed.bg_color = BTN_PRESSED
		btn.add_theme_stylebox_override("pressed", pressed)

		var focus: StyleBoxFlat = normal.duplicate()
		btn.add_theme_stylebox_override("focus", focus)

		btn.add_theme_color_override("font_color", INACTIVE_FONT)
		btn.add_theme_color_override("font_hover_color", Color.WHITE)
		btn.add_theme_color_override("font_pressed_color", INACTIVE_FONT)
		btn.add_theme_color_override("font_focus_color", Color.WHITE)


# ══════════════════════════════════════════════════════════════
# Signal handlers
# ══════════════════════════════════════════════════════════════

func _on_exit_pressed() -> void:
	open_exit_modal()


func _on_base_pressed() -> void:
	base_view_requested.emit()


func _on_top_pressed() -> void:
	top_view_requested.emit()


func _on_free_pressed() -> void:
	_free_view_active = not _free_view_active
	camera_free_view_toggled.emit(_free_view_active)
	_update_active_style()


func _on_continue_pressed() -> void:
	close_exit_modal()


func _on_confirm_exit_pressed() -> void:
	return_to_menu_confirmed.emit()
	close_exit_modal()


func _on_modal_bg_clicked(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		close_exit_modal()


# ══════════════════════════════════════════════════════════════
# Keyboard input
# ══════════════════════════════════════════════════════════════

func _unhandled_input(event: InputEvent) -> void:
	if not _modal_open:
		return

	if event.is_action_pressed("ui_cancel"):
		close_exit_modal()
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("ui_accept"):
		if _confirm_exit_button and _confirm_exit_button.has_focus():
			return_to_menu_confirmed.emit()
			close_exit_modal()
			get_viewport().set_input_as_handled()
		return
