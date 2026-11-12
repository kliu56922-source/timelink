extends PanelContainer
class_name ODCoreCommandPanel

## Phase 26C: OD Core Command Panel — view-only, emits intent signals only.
## Does not hold BattleSystem, does not mutate battle state.

signal command_requested(command_id: StringName)
signal close_requested

var _surge_button: Button
var _vent_button: Button
var _redeploy_button: Button
var _redeploy_actor: OptionButton
var _usage_label: Label
var _charge_label: Label
var _reason_label: Label
var _title_label: Label

func setup() -> void:
	custom_minimum_size = Vector2(220, 0)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.025, 0.04, 0.06, 0.98)
	panel_style.border_color = Color(0.2, 0.65, 0.72)
	panel_style.set_border_width_all(1)
	panel_style.content_margin_left = 8
	panel_style.content_margin_right = 8
	panel_style.content_margin_top = 8
	panel_style.content_margin_bottom = 8
	add_theme_stylebox_override("panel", panel_style)

	var vbox := VBoxContainer.new()
	vbox.name = "CommandPanelVBox"
	vbox.size_flags_horizontal = Control.SIZE_FILL
	add_child(vbox)

	# Title
	_title_label = Label.new()
	_title_label.name = "TitleLabel"
	_title_label.text = "核心指令"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_title_label)

	# Charge label
	_charge_label = Label.new()
	_charge_label.name = "ChargeLabel"
	_charge_label.text = "充能 0/0"
	_charge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_charge_label)

	# Usage label
	_usage_label = Label.new()
	_usage_label.name = "UsageLabel"
	_usage_label.text = "本回合 0/1"
	_usage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_usage_label)

	# Separator
	var sep := HSeparator.new()
	vbox.add_child(sep)

	# Surge button
	_surge_button = Button.new()
	_surge_button.name = "SurgeButton"
	_surge_button.text = "增压"
	_surge_button.size_flags_horizontal = Control.SIZE_FILL
	_surge_button.pressed.connect(_on_surge_pressed)
	vbox.add_child(_surge_button)

	# Vent button
	_vent_button = Button.new()
	_vent_button.name = "VentButton"
	_vent_button.text = "泄压"
	_vent_button.size_flags_horizontal = Control.SIZE_FILL
	_vent_button.pressed.connect(_on_vent_pressed)
	vbox.add_child(_vent_button)

	# Redeploy button (Phase 26E-R1 Task 6)
	var actor_label := Label.new()
	actor_label.text = "调轨棋子"
	vbox.add_child(actor_label)
	_redeploy_actor = OptionButton.new()
	_redeploy_actor.name = "RedeployActor"
	_redeploy_actor.size_flags_horizontal = Control.SIZE_FILL
	_redeploy_actor.tooltip_text = "先选棋子，再选落点；确认后支付原调轨费用。"
	vbox.add_child(_redeploy_actor)
	set_redeploy_actors([])
	_redeploy_button = Button.new()
	_redeploy_button.name = "RedeployButton"
	_redeploy_button.text = "调轨"
	_redeploy_button.size_flags_horizontal = Control.SIZE_FILL
	_redeploy_button.pressed.connect(_on_redeploy_pressed)
	vbox.add_child(_redeploy_button)

	# Reason label
	_reason_label = Label.new()
	_reason_label.name = "ReasonLabel"
	_reason_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reason_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_reason_label.custom_minimum_size = Vector2(200, 0)
	vbox.add_child(_reason_label)
	for button: BaseButton in [_surge_button, _vent_button, _redeploy_button, _redeploy_actor]:
		button.custom_minimum_size.y = 32
		button.add_theme_color_override("font_color", Color(0.88, 0.95, 0.98))
		button.add_theme_color_override("font_hover_color", Color.WHITE)
		button.add_theme_color_override("font_pressed_color", Color.WHITE)
		button.add_theme_color_override("font_disabled_color", Color(0.55, 0.61, 0.65))
		var button_style := StyleBoxFlat.new()
		button_style.bg_color = Color(0.07, 0.14, 0.18)
		button_style.border_color = Color(0.16, 0.35, 0.42)
		button_style.set_border_width_all(1)
		button.add_theme_stylebox_override("normal", button_style)
		button.add_theme_stylebox_override("disabled", button_style)
		var hover_style := button_style.duplicate() as StyleBoxFlat
		hover_style.bg_color = Color(0.1, 0.24, 0.3)
		button.add_theme_stylebox_override("hover", hover_style)
		button.add_theme_stylebox_override("pressed", hover_style)


func set_redeploy_actors(actors: Array[Dictionary]) -> void:
	if not is_instance_valid(_redeploy_actor): return
	_redeploy_actor.clear()
	_redeploy_actor.add_item("默认棋子")
	_redeploy_actor.set_item_metadata(0, 0)
	for actor: Dictionary in actors:
		_redeploy_actor.add_item(str(actor.get("label", "棋子")))
		_redeploy_actor.set_item_metadata(_redeploy_actor.item_count - 1, int(actor.get("runtime_id", 0)))
	_redeploy_actor.select(0)


func get_redeploy_actor_uid() -> int:
	if not is_instance_valid(_redeploy_actor) or _redeploy_actor.selected < 0: return 0
	return int(_redeploy_actor.get_item_metadata(_redeploy_actor.selected))


func apply_view_model(view: Dictionary) -> void:
	if _usage_label:
		_usage_label.text = str(view.get("usage_text", "本回合 0/1"))
	if _charge_label:
		_charge_label.text = str(view.get("charge_text", "充能 0/0"))

	if _surge_button:
		_surge_button.disabled = not bool(view.get("surge_enabled", false))
		_surge_button.tooltip_text = str(view.get("surge_reason_text", ""))

	if _vent_button:
		_vent_button.disabled = not bool(view.get("vent_enabled", false))
		_vent_button.tooltip_text = str(view.get("vent_reason_text", ""))

	if _redeploy_button:
		_redeploy_button.disabled = not bool(view.get("redeploy_enabled", false))
		_redeploy_button.tooltip_text = str(view.get("redeploy_reason_text", ""))

	if _reason_label:
		_reason_label.text = ""


func _on_surge_pressed() -> void:
	command_requested.emit(&"surge")


func _on_vent_pressed() -> void:
	command_requested.emit(&"vent")


func _on_redeploy_pressed() -> void:
	command_requested.emit(&"redeploy")
