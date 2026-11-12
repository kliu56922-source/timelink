extends Control
class_name CommandEconomyHUD
## Phase 27D-R3: Persistent tactical command economy HUD.
## Read-only: consumes snapshots, never writes to BattleSystem.
##
## API:
##   configure(snapshot_provider: Callable) -> void
##   refresh() -> void
##   preview_cost(cost: int) -> void
##   clear_preview() -> void
##   play_gain(amount: int) -> void
##   play_spend(amount: int) -> void
##   play_refund(amount: int) -> void
##   cancel_all() -> void

const DOT_SIZE: float = 6.0
const DOT_GAP: float = 3.0
const MAX_DOTS_PER_ROW: int = 10

var _snapshot_provider: Callable
var _title_label: Label = null
var _value_label: Label = null
var _dot_container: HBoxContainer = null
var _dots: Array = []
var _next_turn_label: Label = null
var _depth_label: Label = null
var _preview_mode: bool = false
var _preview_cost: int = 0
var _tween: Tween = null
var _depth_context_provider: Callable


func _ready() -> void:
	_snapshot_provider = _default_empty_dict
	_depth_context_provider = _default_depth_dict
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_layout()

func _default_empty_dict() -> Dictionary:
	return {}

func _default_depth_dict() -> Dictionary:
	return {"depth": 0, "max": 6}


func configure(provider: Callable) -> void:
	_snapshot_provider = provider


func set_depth_provider(provider: Callable) -> void:
	_depth_context_provider = provider


func _build_layout() -> void:
	# Phase 27D-R5-R1: semi-transparent background for readability on any scene
	var bg := ColorRect.new()
	bg.name = "HUDBackground"
	bg.color = Color(0.05, 0.05, 0.08, 0.72)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Main vertical container
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.name = "EconomyVBox"
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 0)
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 4
	vbox.offset_top = 4
	vbox.offset_right = -4
	vbox.offset_bottom = -4
	add_child(vbox)

	# Row 0: Title + Value
	var title_row: HBoxContainer = HBoxContainer.new()
	title_row.name = "TitleRow"
	title_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(title_row)

	_title_label = Label.new()
	_title_label.name = "TitleLabel"
	_title_label.text = "战术指令"
	_title_label.add_theme_font_size_override("font_size", 13)
	_title_label.add_theme_color_override("font_color", Color(0.65, 0.82, 0.95, 1))
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_row.add_child(_title_label)

	_value_label = Label.new()
	_value_label.name = "ValueLabel"
	_value_label.text = "?/?"
	_value_label.add_theme_font_size_override("font_size", 22)
	_value_label.add_theme_color_override("font_color", Color(0.3, 0.95, 0.95, 1))
	_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_value_label.custom_minimum_size = Vector2(55, 0)
	title_row.add_child(_value_label)

	# Row 1: Segmented dots
	_dot_container = HBoxContainer.new()
	_dot_container.name = "DotRow"
	_dot_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dot_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_dot_container.add_theme_constant_override("separation", int(DOT_GAP))
	vbox.add_child(_dot_container)

	# Row 2: Next-turn gain
	_next_turn_label = Label.new()
	_next_turn_label.name = "NextTurnLabel"
	_next_turn_label.text = ""
	_next_turn_label.add_theme_font_size_override("font_size", 10)
	_next_turn_label.add_theme_color_override("font_color", Color(0.45, 0.75, 0.55, 1))
	_next_turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_next_turn_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_next_turn_label)

	# Row 3: Depth
	_depth_label = Label.new()
	_depth_label.name = "DepthLabel"
	_depth_label.text = "Depth ?/6"
	_depth_label.add_theme_font_size_override("font_size", 10)
	_depth_label.add_theme_color_override("font_color", Color(0.3, 0.6, 1.0, 1))
	_depth_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_depth_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_depth_label)


func refresh() -> void:
	if _snapshot_provider == null:
		return
	var snap: Dictionary = _snapshot_provider.call()
	if snap.is_empty():
		return

	var current: int = int(snap.get("current_points", 0))
	var maximum: int = int(snap.get("turn_max_points", 0))
	var scheduled_bonus: int = int(snap.get("scheduled_next_turn", 0))
	var scheduled_penalty: int = int(snap.get("scheduled_next_turn_penalty", 0))
	var next_gain: int = scheduled_bonus - scheduled_penalty
	var depth_info: Dictionary = _depth_context_provider.call()

	# Update value label
	_update_value_display(current, maximum)
	# Update dot row
	_update_dots(current, maximum)
	# Update next-turn label
	_update_next_turn(next_gain)
	# Update depth
	_update_depth(depth_info)


func preview_cost(cost: int) -> void:
	if not _preview_mode:
		_preview_mode = true
	_preview_cost = cost
	var snap: Dictionary = _snapshot_provider.call()
	if snap.is_empty():
		return
	var current: int = int(snap.get("current_points", 0))
	var maximum: int = int(snap.get("turn_max_points", 0))
	var after: int = current - cost
	_update_value_display(after, maximum)
	_update_dots_preview(current, after, maximum)


func clear_preview() -> void:
	_preview_mode = false
	_preview_cost = 0
	refresh()


func play_gain(amount: int) -> void:
	if amount <= 0:
		return
	_kill_tween()
	var snap: Dictionary = _snapshot_provider.call()
	var current: int = int(snap.get("current_points", 0))
	var maximum: int = int(snap.get("turn_max_points", 0))
	var prev: int = current - amount

	# Flash +N label
	_title_label.text = "指令 +%d" % amount
	_title_label.add_theme_color_override("font_color", Color(0.3, 0.95, 0.95, 1))
	_title_label.add_theme_font_size_override("font_size", 15)

	# Animate value scale
	_update_value_display(current, maximum)
	if _value_label:
		_value_label.pivot_offset = _value_label.size * 0.5
		_tween = create_tween()
		_tween.tween_property(_value_label, "scale", Vector2(1.35, 1.35), 0.15).set_trans(Tween.TRANS_BACK)
		_tween.tween_property(_value_label, "scale", Vector2(1.0, 1.0), 0.25).set_trans(Tween.TRANS_SINE)
		_tween.tween_callback(_restore_title)

	# Dot animation: fill from dark
	var dots_full: int = clampi(current, 0, _dots.size())
	var dots_prev: int = clampi(prev, 0, _dots.size())
	for i in range(dots_prev, dots_full):
		if i < _dots.size() and is_instance_valid(_dots[i]):
			var dot: ColorRect = _dots[i]
			dot.color = _dot_color_full()
			var dt: Tween = create_tween()
			dt.tween_property(dot, "modulate:a", 1.0, 0.1).from(0.3)


func play_spend(amount: int) -> void:
	if amount <= 0:
		return
	_kill_tween()
	var snap: Dictionary = _snapshot_provider.call()
	var current: int = int(snap.get("current_points", 0))
	var maximum: int = int(snap.get("turn_max_points", 0))

	_title_label.text = "指令 -%d" % amount
	_title_label.add_theme_color_override("font_color", Color(1.0, 0.55, 0.2, 1))
	_title_label.add_theme_font_size_override("font_size", 15)

	_update_value_display(current, maximum)
	if _value_label:
		_value_label.pivot_offset = _value_label.size * 0.5
		_tween = create_tween()
		_tween.tween_property(_value_label, "scale", Vector2(1.3, 1.3), 0.12).set_trans(Tween.TRANS_BACK)
		_tween.tween_property(_value_label, "scale", Vector2(1.0, 1.0), 0.25).set_trans(Tween.TRANS_SINE)
		_tween.tween_callback(_restore_title)

	# Dim consumed dots
	var dots_full: int = clampi(current + amount, 0, _dots.size())
	var dots_now: int = clampi(current, 0, _dots.size())
	for i in range(dots_now, dots_full):
		if i < _dots.size() and is_instance_valid(_dots[i]):
			var dot: ColorRect = _dots[i]
			var dt: Tween = create_tween()
			dt.tween_property(dot, "modulate:a", 0.18, 0.15)


func play_refund(amount: int) -> void:
	if amount <= 0:
		return
	_kill_tween()
	_title_label.text = "退款 +%d" % amount
	_title_label.add_theme_color_override("font_color", Color(0.5, 0.9, 0.5, 1))
	_title_label.add_theme_font_size_override("font_size", 15)

	_tween = create_tween()
	_tween.tween_interval(0.6)
	_tween.tween_callback(_restore_title)
	refresh()


func cancel_all() -> void:
	_kill_tween()
	clear_preview()
	_restore_title()


func _restore_title() -> void:
	if _title_label and is_instance_valid(_title_label):
		_title_label.text = "战术指令"
		_title_label.add_theme_font_size_override("font_size", 13)
		_title_label.add_theme_color_override("font_color", Color(0.65, 0.82, 0.95, 1))


func _kill_tween() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = null


func _update_value_display(current: int, maximum: int) -> void:
	if _value_label == null:
		return
	var ratio: float = float(current) / float(maximum) if maximum > 0 else 0.0
	var color: Color
	if current <= 0:
		color = Color(1.0, 0.15, 0.1, 1)  # red
	elif ratio < 0.35:
		color = Color(1.0, 0.55, 0.1, 1)  # orange
	else:
		color = Color(0.3, 0.95, 0.95, 1)  # cyan
	_value_label.text = "%d/%d" % [current, maximum]
	_value_label.add_theme_color_override("font_color", color)
	_value_label.add_theme_font_size_override("font_size", 20 if ratio >= 0.35 else 22)


func _update_dots(current: int, maximum: int) -> void:
	_rebuild_dots(maximum)
	for i in range(_dots.size()):
		if i < current:
			_dots[i].color = _dot_color_full()
			_dots[i].modulate.a = 1.0
		else:
			_dots[i].color = _dot_color_empty()
			_dots[i].modulate.a = 0.22


func _update_dots_preview(current: int, after: int, maximum: int) -> void:
	_rebuild_dots(maximum)
	var spent: int = current - after
	for i in range(_dots.size()):
		if i < after:
			_dots[i].color = _dot_color_full()
			_dots[i].modulate.a = 1.0
		elif i < current:
			# These dots will be consumed — show preview
			_dots[i].color = Color(1.0, 0.45, 0.2, 1)
			_dots[i].modulate.a = 0.65
		else:
			_dots[i].color = _dot_color_empty()
			_dots[i].modulate.a = 0.22


func _rebuild_dots(count: int) -> void:
	var diff: int = count - _dots.size()
	if diff == 0:
		return
	elif diff > 0:
		for _i in range(diff):
			var dot: ColorRect = ColorRect.new()
			dot.name = "Dot%d" % _dots.size()
			dot.custom_minimum_size = Vector2(DOT_SIZE, DOT_SIZE)
			dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
			dot.color = _dot_color_full()
			_dot_container.add_child(dot)
			_dots.append(dot)
	else:
		for _i in range(-diff):
			if _dots.is_empty():
				break
			var last: Variant = _dots.pop_back()
			if is_instance_valid(last):
				last.queue_free()


func _update_next_turn(gain: int) -> void:
	if _next_turn_label == null:
		return
	if gain != 0:
		var sign: String = "+" if gain > 0 else ""
		_next_turn_label.text = "下回合 %s%d" % [sign, gain]
		_next_turn_label.visible = true
	else:
		_next_turn_label.text = "下回合 —"
		_next_turn_label.visible = true


func _update_depth(info: Dictionary) -> void:
	if _depth_label == null:
		return
	var depth: int = int(info.get("depth", 0))
	var max_depth: int = int(info.get("max", 6))
	var zone: String = str(info.get("zone", ""))
	_depth_label.text = "Depth %d/%d" % [depth, max_depth]
	var zone_color: Color = Color(0.3, 0.6, 1.0, 1)
	match zone:
		"Backlash":
			zone_color = Color(0.95, 0.05, 0.2, 1)
		"Warning":
			zone_color = Color(1.0, 0.55, 0.1, 1)
	_depth_label.add_theme_color_override("font_color", zone_color)


func _dot_color_full() -> Color:
	return Color(0.15, 0.85, 0.85, 1)


func _dot_color_empty() -> Color:
	return Color(0.28, 0.28, 0.35, 1)


func _exit_tree() -> void:
	_kill_tween()
	_dots.clear()
