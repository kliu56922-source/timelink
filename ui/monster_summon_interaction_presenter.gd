extends Control
## Screen-space only feedback for the explicit monster-summon interaction.
## This presenter owns no card, cell, payment, or legality authority.

signal confirm_requested
signal reselect_requested
signal cancel_requested

const DRAG_COLOR := Color("#52E8F2")
const PENDING_COLOR := Color("#F4C95D")
const PANEL_SIZE := Vector2(260.0, 148.0)
const KNOWN_CARD_CAST_PROFILES := [
	&"engineering_target",
	&"basic_unit_target",
	&"monster_summon", &"structure_build", &"friendly_anchor_spell",
	&"tripwire_anchor", &"directed_spell", &"cast_lane", &"finisher_cast",
	&"area_cell",
]

var _source := Vector2.INF
var _target := Vector2.INF
var _tether_color := DRAG_COLOR
var _tether_points := PackedVector2Array()
var _phase := 0.0
var _reduced_motion := false
var _motion_active := false
var _success_tween: Tween
var _panel: PanelContainer
var _prompt_label: Label
var _confirm_button: Button
var _reselect_button: Button
var _cancel_button: Button
var _card_cast_fact: Dictionary = {}
var _pointer_proxy_visible := false
var _cast_lane_visible := false
var _cast_lane_legal := false
var _pending_kind: StringName = &""
var _cast_lane_rect := Rect2()
var _profile_fallback_used := false
var _profile_label := ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel = PanelContainer.new()
	_panel.name = "SummonPanel"
	var pending_style := StyleBoxFlat.new()
	pending_style.bg_color=Color("101c2b")
	pending_style.border_color=PENDING_COLOR
	pending_style.set_border_width_all(1)
	pending_style.set_corner_radius_all(6)
	pending_style.content_margin_left=8
	pending_style.content_margin_right=8
	pending_style.content_margin_top=8
	pending_style.content_margin_bottom=8
	_panel.add_theme_stylebox_override("panel",pending_style)
	_panel.size = PANEL_SIZE
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.visible = false
	add_child(_panel)
	var contents := VBoxContainer.new()
	contents.add_theme_constant_override("separation", 6)
	_panel.add_child(contents)
	_prompt_label = Label.new()
	_prompt_label.name = "PromptLabel"
	_prompt_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_prompt_label.custom_minimum_size = Vector2(228.0, 38.0)
	contents.add_child(_prompt_label)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 5)
	contents.add_child(buttons)
	_confirm_button = _make_button("ConfirmButton", "确认召唤", confirm_requested)
	_reselect_button = _make_button("ReselectButton", "重新选位", reselect_requested)
	_cancel_button = _make_button("CancelButton", "取消", cancel_requested)
	buttons.add_child(_confirm_button)
	buttons.add_child(_reselect_button)
	buttons.add_child(_cancel_button)
	set_process(false)


func _make_button(button_name: String, label: String, requested: Signal) -> Button:
	var button := Button.new()
	button.name = button_name
	button.text = label
	button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.pressed.connect(requested.emit)
	return button


func show_drag(source: Vector2, target: Vector2, reduced_motion: bool) -> void:
	show_card_drag({
		"source_screen_position": source,
		"pointer_screen_position": target,
		"target_screen_position": target,
		"legal": true,
		"presentation_profile_id": &"monster_summon",
	}, reduced_motion)


func show_pending(source: Vector2, target: Vector2, card_name: String, candidate: Vector2i, reduced_motion: bool, terrain_context: Dictionary = {}) -> void:
	show_card_pending({
		"source_screen_position": source,
		"pointer_screen_position": target,
		"target_screen_position": target,
		"candidate_target": {"target_kind": &"tactical_cell", "board_cell": candidate},
		"legal": true,
		"presentation_profile_id": &"monster_summon",
	}, _format_pending_prompt(card_name, candidate, terrain_context), "确认召唤", "重新选位", reduced_motion)


func update_target(target: Vector2) -> void:
	if not target.is_finite():
		return
	_target = target
	_rebuild_tether()
	if _panel != null and _panel.visible:
		_place_panel(target)


func show_reselect(source: Vector2, target: Vector2, reduced_motion: bool) -> void:
	show_drag(source, target, reduced_motion)


func play_success(source: Vector2, target: Vector2, reduced_motion: bool) -> void:
	play_card_cast_success({
		"source_screen_position": source,
		"pointer_screen_position": target,
		"target_screen_position": target,
		"legal": true,
		"presentation_profile_id": &"monster_summon",
	}, reduced_motion)


func show_card_drag(preview_fact: Dictionary, reduced_motion: bool = false) -> void:
	_card_cast_fact = preview_fact.duplicate(true)
	_update_card_cast_profile_state()
	_pointer_proxy_visible = true
	_cast_lane_visible = false
	_cast_lane_legal = false
	_pending_kind = &""
	var source := _fact_position(&"source_screen_position", Vector2.INF)
	var target := _fact_position(&"target_screen_position", _fact_position(&"pointer_screen_position", Vector2.INF))
	_show_tether(source, target, PENDING_COLOR if bool(_card_cast_fact.get("legal", false)) else DRAG_COLOR, reduced_motion)
	_set_panel_pending(false)
	queue_redraw()


func show_card_pending(
		preview_fact: Dictionary,
		title: String,
		confirm_text: String,
		reselect_text: String,
		reduced_motion: bool = false
) -> void:
	_card_cast_fact = preview_fact.duplicate(true)
	_update_card_cast_profile_state()
	_pointer_proxy_visible = true
	_cast_lane_visible = false
	_cast_lane_legal = false
	_pending_kind = StringName(str(_card_cast_fact.get("intent_kind", &"")))
	var source := _fact_position(&"source_screen_position", Vector2.INF)
	var target := _fact_position(&"target_screen_position", _fact_position(&"pointer_screen_position", Vector2.INF))
	_show_tether(source, target, PENDING_COLOR, reduced_motion)
	_prompt_label.text = title
	_confirm_button.text = confirm_text
	_reselect_button.text = reselect_text
	_cancel_button.text = "取消"
	_set_panel_pending(true)
	_place_panel(target)
	queue_redraw()


func show_cast_lane(preview_fact: Dictionary, reduced_motion: bool = false) -> void:
	_card_cast_fact = preview_fact.duplicate(true)
	_update_card_cast_profile_state()
	_pointer_proxy_visible = true
	_cast_lane_visible = true
	_cast_lane_legal = bool(_card_cast_fact.get("legal", false))
	_pending_kind = &""
	var source := _fact_position(&"source_screen_position", Vector2.INF)
	var target := _fact_position(&"pointer_screen_position", _fact_position(&"target_screen_position", Vector2.INF))
	var supplied_rect: Variant = _card_cast_fact.get("cast_lane_rect", null)
	_cast_lane_rect = supplied_rect if supplied_rect is Rect2 else Rect2(
		Vector2(size.x * 0.28, size.y * 0.69), Vector2(size.x * 0.44, size.y * 0.12))
	_show_tether(source, target, PENDING_COLOR if _cast_lane_legal else DRAG_COLOR, reduced_motion)
	_set_panel_pending(false)
	queue_redraw()


func play_card_cast_success(preview_fact: Dictionary, reduced_motion: bool = false) -> void:
	_card_cast_fact = preview_fact.duplicate(true)
	_update_card_cast_profile_state()
	_pointer_proxy_visible = true
	_cast_lane_visible = false
	_pending_kind = &""
	var source := _fact_position(&"source_screen_position", Vector2.INF)
	var target := _fact_position(&"target_screen_position", _fact_position(&"pointer_screen_position", Vector2.INF))
	_show_tether(source, target, PENDING_COLOR, reduced_motion)
	_set_panel_pending(false)
	if reduced_motion:
		clear_card_cast()
		return
	_success_tween = create_tween()
	_success_tween.tween_property(self, "modulate:a", 0.0, 0.14)
	_success_tween.tween_callback(clear_card_cast)


func clear_card_cast() -> void:
	clear()


func get_card_cast_debug_snapshot() -> Dictionary:
	var snapshot := get_debug_snapshot()
	snapshot.merge({
		"fact": _card_cast_fact.duplicate(true),
		"pointer_proxy_visible": _pointer_proxy_visible,
		"cast_lane_visible": _cast_lane_visible,
		"cast_lane_legal": _cast_lane_legal,
		"cast_lane_rect": _cast_lane_rect,
		"pending_kind": _pending_kind,
		"profile_fallback_used": _profile_fallback_used,
		"profile_label": _profile_label,
	}, true)
	return snapshot


func _update_card_cast_profile_state() -> void:
	var profile := StringName(str(_card_cast_fact.get("presentation_profile_id", &"")))
	_profile_fallback_used = profile not in KNOWN_CARD_CAST_PROFILES
	_profile_label = "通用施放预览" if _profile_fallback_used else (
		"范围中心预览" if profile == &"area_cell" else "")


func _fact_position(key: StringName, fallback: Vector2) -> Vector2:
	var value: Variant = _card_cast_fact.get(key, fallback)
	return value if value is Vector2 and (value as Vector2).is_finite() else fallback


func clear() -> void:
	if _success_tween != null and is_instance_valid(_success_tween) and _success_tween.is_running():
		_success_tween.kill()
	_success_tween = null
	_source = Vector2.INF
	_target = Vector2.INF
	_tether_points = PackedVector2Array()
	_phase = 0.0
	_motion_active = false
	_card_cast_fact = {}
	_profile_fallback_used = false
	_profile_label = ""
	_pointer_proxy_visible = false
	_cast_lane_visible = false
	_cast_lane_legal = false
	_pending_kind = &""
	_cast_lane_rect = Rect2()
	set_process(false)
	_set_panel_pending(false)
	modulate.a = 1.0
	queue_redraw()


func get_debug_snapshot() -> Dictionary:
	var panel_rect := Rect2()
	if _panel != null:
		panel_rect = Rect2(_panel.position, _panel.size)
	return {
		"tether_points": _tether_points.size(),
		"panel_visible": _panel != null and _panel.visible,
		"panel_rect": panel_rect,
		"prompt": _prompt_label.text if _prompt_label != null else "",
		"button_count": 3 if _confirm_button != null and _reselect_button != null and _cancel_button != null else 0,
		"panel_mouse_filter": _panel.mouse_filter if _panel != null else Control.MOUSE_FILTER_IGNORE,
		"motion_processing": _motion_active,
		"active_tweens": 1 if _success_tween != null and is_instance_valid(_success_tween) and _success_tween.is_running() else 0,
		"reduced_motion": _reduced_motion,
	}


func _show_tether(source: Vector2, target: Vector2, color: Color, reduced_motion: bool) -> void:
	if _success_tween != null and is_instance_valid(_success_tween) and _success_tween.is_running():
		_success_tween.kill()
	_success_tween = null
	modulate.a = 1.0
	_source = source
	_target = target
	_tether_color = color
	_reduced_motion = reduced_motion
	_phase = 0.0
	_motion_active = not reduced_motion
	set_process(_motion_active)
	_rebuild_tether()


func _set_panel_pending(pending: bool) -> void:
	if _panel == null:
		return
	_panel.visible = pending
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP if pending else Control.MOUSE_FILTER_IGNORE
	for button in [_confirm_button, _reselect_button, _cancel_button]:
		if button != null:
			button.mouse_filter = Control.MOUSE_FILTER_STOP if pending else Control.MOUSE_FILTER_IGNORE


func _format_cell(candidate: Vector2i) -> String:
	return str(candidate)


func _format_pending_prompt(card_name: String, candidate: Vector2i, terrain_context: Dictionary) -> String:
	var height := int(terrain_context.get("height", 0))
	return "召唤「%s」\n格 (%d,%d) · H%d\n状态：可召唤" % [card_name, candidate.x, candidate.y, height]


func _place_panel(target: Vector2) -> void:
	var desired := target + Vector2(28.0, -112.0)
	if desired.x + _panel.size.x > size.x - 16.0:
		desired.x = target.x - _panel.size.x - 28.0
	desired.x = clampf(desired.x, 16.0, size.x - _panel.size.x - 16.0)
	desired.y = clampf(desired.y, 16.0, size.y - _panel.size.y - 150.0)
	_panel.position = desired


func _rebuild_tether() -> void:
	_tether_points = PackedVector2Array()
	# Off-screen/rebuilt card views can temporarily have no screen anchor.
	# Keep the pending interaction; only its decorative line waits for finite input.
	if not _source.is_finite() or not _target.is_finite():
		_motion_active = false
		set_process(false)
		queue_redraw()
		return
	_motion_active = not _reduced_motion
	set_process(_motion_active)
	var distance := _source.distance_to(_target)
	var lift := clampf(distance * 0.32, 72.0, 220.0)
	var control := (_source + _target) * 0.5 + Vector2.UP * lift
	for index in range(25):
		var t := float(index) / 24.0
		var inv := 1.0 - t
		_tether_points.append(inv * inv * _source + 2.0 * inv * t * control + t * t * _target)
	queue_redraw()


func _process(delta: float) -> void:
	_phase = fmod(_phase + delta * 3.0, 1.0)
	queue_redraw()


func _draw() -> void:
	if _cast_lane_visible and _cast_lane_rect.has_area():
		var lane_color := PENDING_COLOR if _cast_lane_legal else DRAG_COLOR.darkened(0.35)
		draw_style_box(_lane_style(lane_color), _cast_lane_rect)
	if _tether_points.size() == 25:
		draw_polyline(_tether_points, _tether_color, 3.5, true)
		if _motion_active:
			var index := int(_phase * 21.0)
			draw_line(_tether_points[index], _tether_points[index + 3], _tether_color.lightened(0.35), 5.0, true)
	if _pointer_proxy_visible and _target.is_finite():
		var proxy_color := PENDING_COLOR if bool(_card_cast_fact.get("legal", false)) else DRAG_COLOR
		var points := PackedVector2Array([
			_target + Vector2(0.0, -12.0),
			_target + Vector2(12.0, 0.0),
			_target + Vector2(0.0, 12.0),
			_target + Vector2(-12.0, 0.0),
		])
		draw_colored_polygon(points, Color(proxy_color, 0.26))
		draw_polyline(PackedVector2Array([points[0], points[1], points[2], points[3], points[0]]), proxy_color, 2.0, true)
		if not _profile_label.is_empty():
			draw_string(
				ThemeDB.fallback_font, _target + Vector2(18.0, 5.0), _profile_label,
				HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13, proxy_color)


func _lane_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(color, 0.12)
	style.border_color = Color(color, 0.72)
	style.set_border_width_all(2)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	return style
