extends Control
## Read-only, visible drop targets. Only these badges enlarge the input area.
var targets: Array[Dictionary] = []
var instruction := ""
var reserved_rects: Array[Rect2] = []
var _banner: Panel
var _instruction_label: Label
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_banner = Panel.new()
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.05, 0.08, 0.94)
	style.border_color = Color("79ffe1")
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	_banner.add_theme_stylebox_override("panel", style)
	add_child(_banner)
	_instruction_label = Label.new()
	_instruction_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_instruction_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_instruction_label.add_theme_font_size_override("font_size", 17)
	_banner.add_child(_instruction_label)
	_instruction_label.position = Vector2(12,8)
	resized.connect(_layout_banner)
	_layout_banner()
func _layout_banner() -> void:
	if not is_instance_valid(_banner): return
	_banner.visible = not instruction.is_empty()
	_instruction_label.text = instruction
	var width := minf(780, maxf(80, size.x - 24))
	_instruction_label.size = Vector2(width-24, 0)
	_banner.size = Vector2(width, maxf(38,_instruction_label.get_minimum_size().y+16))
	_place_banner(Vector2((size.x - _banner.size.x) * 0.5, size.y * 0.19))
func _place_banner(preferred: Vector2) -> void:
	var candidates: Array[Vector2] = [preferred]
	if not reserved_rects.is_empty():
		for offset in [Vector2(-110,0),Vector2(110,0),Vector2(-220,0),Vector2(220,0),Vector2(0,_banner.size.y+52),Vector2(0,-_banner.size.y-20),Vector2(-_banner.size.x-12,0),Vector2(_banner.size.x+12,0)]:
			candidates.append(preferred+offset)
		for band in [0.42,0.66,0.2]:
			candidates.append(Vector2((size.x-_banner.size.x)*0.5,size.y*band))
	for candidate in candidates:
		candidate = candidate.clamp(Vector2(12,12),(size-_banner.size-Vector2(12,12)).max(Vector2(12,12)))
		var clear := true
		for reserved: Rect2 in reserved_rects:
			if Rect2(candidate,_banner.size).intersects(reserved): clear=false; break
		if clear:
			_banner.position=candidate
			return
	# Dense boards may have no free rectangle; keep the text within the viewport.
	_banner.position=preferred.clamp(Vector2(12,12),(size-_banner.size-Vector2(12,12)).max(Vector2(12,12)))
func instruction_rect() -> Rect2:
	return _banner.get_rect() if is_instance_valid(_banner) else Rect2()
func show_targets(items: Array[Dictionary], text: String) -> void:
	targets = items.duplicate(true)
	instruction = text
	_layout_banner()
	queue_redraw()
func clear() -> void:
	targets.clear()
	instruction = ""
	_layout_banner()
	queue_redraw()
func target_at(point: Vector2) -> Dictionary:
	var found: Dictionary = {}
	for target in targets:
		if (target.rect as Rect2).has_point(point):
			if not found.is_empty(): return {} # Never guess between overlapping badges.
			found = target.hit
	return found.duplicate(true)
func _draw() -> void:
	if instruction.is_empty(): return
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.05, 0.08, 0.94)
	style.border_color = Color("79ffe1")
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	for target in targets:
		var rect: Rect2 = target.rect
		var color := Color("79ffe1")
		draw_line(target.anchor, rect.get_center(), color, 2, true)
		draw_circle(target.anchor, 5, color)
		draw_style_box(style, rect)
		draw_string(ThemeDB.fallback_font, rect.position + Vector2(6, 22), target.label, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 12, 14, color)
