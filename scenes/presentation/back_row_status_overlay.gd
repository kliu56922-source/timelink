extends Control
## Read-only labels follow projected anchors; they never take board input.
var items: Array[Dictionary] = []
var occupied: Array[Rect2] = []
var reserved: Array[Rect2] = []
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
func refresh(rows: Array[Dictionary], hud_rects: Array[Rect2] = []) -> void:
	items = rows.duplicate(true)
	reserved = hud_rects.duplicate()
	occupied.clear()
	for item in items:
		var point: Vector2 = item.position
		var preferred := point + Vector2(-90, -100)
		var rect := Rect2(preferred, Vector2(180, 86))
		for offset in [Vector2.ZERO, Vector2(0,-90), Vector2(-186,0), Vector2(186,0), Vector2(0,90), Vector2(-186,-90), Vector2(186,-90)]:
			var candidate := Rect2(preferred + offset, rect.size)
			candidate.position = candidate.position.clamp(Vector2(12,12), (size-candidate.size-Vector2(12,12)).max(Vector2(12,12)))
			var clear := true
			for other in occupied + reserved:
				if candidate.intersects(other): clear = false; break
			if clear: rect = candidate; break
		item["rect"] = rect
		occupied.append(rect)
	queue_redraw()
func _fit(text: String, width: float, font_size: int) -> String:
	var font := ThemeDB.fallback_font
	if font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= width: return text
	while not text.is_empty() and font.get_string_size(text + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > width:
		text = text.left(text.length()-1)
	return text + "…"
func _draw() -> void:
	for item in items:
		var point: Vector2 = item.position
		var rect: Rect2 = item.rect
		draw_line(point, rect.get_center(), Color(0.45,1.0,0.84,0.35), 1, true)
		draw_rect(rect, Color(0.015, 0.035, 0.065, 0.91))
		draw_string(ThemeDB.fallback_font, rect.position + Vector2(6,16), _fit(item.title,168,14), HORIZONTAL_ALIGNMENT_LEFT, 168, 14, Color.WHITE)
		draw_string(ThemeDB.fallback_font, rect.position + Vector2(6,34), _fit(item.state,168,12), HORIZONTAL_ALIGNMENT_LEFT, 168, 12, Color("79ffe1"))
		var cost := str(item.get("cost","")).replace(" OD","热量")
		var benefit := str(item.get("benefit","")).split("；")[0]
		draw_string(ThemeDB.fallback_font, rect.position + Vector2(6,51), _fit("费用："+cost if not cost.is_empty() else "条件尚未满足",168,12), HORIZONTAL_ALIGNMENT_LEFT,168,12,Color("ffd083"))
		# Full rules and named targets remain in the pinned building detail.
		draw_string(ThemeDB.fallback_font, rect.position + Vector2(6,70), _fit(benefit,168,12), HORIZONTAL_ALIGNMENT_LEFT,168,12,Color.WHITE)
