extends Control
## Value-only restoration feedback; shares no gameplay authority.
signal impact_requested(cue: String)
var _preview: Dictionary = {}
var _committed: Dictionary = {}
var _elapsed := 0.0
var _last_transaction: StringName = &""

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	set_process(false)

func show_preview(snapshot: Dictionary) -> void:
	_preview = snapshot.duplicate(true)
	queue_redraw()

func present_committed(fact: Dictionary) -> void:
	if not fact.get("ok", false) or fact.get("transaction_id", &"") == _last_transaction:
		return
	_last_transaction = fact.transaction_id
	_preview = {}
	_committed = fact.duplicate(true)
	_elapsed = 0.0
	impact_requested.emit("card_play")
	set_process(true)
	queue_redraw()

func update_committed_geometry(view: Dictionary) -> void:
	for key in ["target_screen_position", "edge_points"]:
		if view.has(key):
			_committed[key] = view[key]
	queue_redraw()

func clear(_reason: StringName) -> void:
	_preview = {}
	_committed = {}
	set_process(false)
	queue_redraw()

func get_debug_snapshot() -> Dictionary:
	return {"preview_active": not _preview.is_empty(), "preview": _preview.duplicate(true),
		"committed": _committed.duplicate(true), "active_tweens": 0,
		"marker_count": int(not _preview.is_empty()) + int(not _committed.is_empty())}

func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= 1.25:
		clear(&"finished")
	queue_redraw()

func _draw() -> void:
	var view := _committed if not _committed.is_empty() else _preview
	if view.is_empty():
		return
	var point: Vector2 = view.get("target_screen_position", Vector2.INF)
	if not point.is_finite():
		return
	if view.has("reason_text"):
		var origin := Vector2(clampf(point.x + 18, 8, maxf(8, size.x - 340)), clampf(point.y - 45, 8, maxf(8, size.y - 55)))
		draw_style_box(_reason_style(), Rect2(origin, Vector2(330, 40)))
		draw_string(ThemeDB.fallback_font, origin + Vector2(10, 26), view.reason_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("ffce8a"))
		return
	var cyan := Color("79ffe1")
	var points: PackedVector2Array = view.get("edge_points", PackedVector2Array())
	if points.size() == 2:
		draw_line(points[0], points[1], Color(0.2, 1, 0.8, 0.25), 14.0, true)
		draw_line(points[0], points[1], cyan, 4.0, true)
	if not _committed.is_empty():
		var lift := 0.0 if view.get("reduced_motion", false) else minf(_elapsed * 18.0, 16.0)
		point += Vector2(0, -34 - lift)
		draw_circle(point, 16, Color(0.015, 0.08, 0.08, 0.9))
		draw_line(point - Vector2(8, 0), point + Vector2(8, 0), cyan, 3)
		draw_line(point - Vector2(0, 8), point + Vector2(0, 8), cyan, 3)
		draw_string(ThemeDB.fallback_font, point + Vector2(24, 6), "修复 +%d · 耐久 %d" % [view.actual_steps, view.wall_after], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, cyan)

func _reason_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.04, 0.06, 0.95)
	style.set_corner_radius_all(5)
	return style
