extends Control
## Public read-only threat, same information under reduced motion.
var _snapshot: Dictionary = {}
var _point := Vector2.INF
var _selection_active := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func present(snapshot: Dictionary, point: Vector2, selection_active: bool = false) -> void:
	_snapshot = snapshot.duplicate(true)
	_point = point
	_selection_active = selection_active
	queue_redraw()

func _draw() -> void:
	if _snapshot.is_empty() or _snapshot.get("status", &"none") == &"none": return
	var color := Color("ffad67")
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.05, 0.08, 0.96)
	style.border_color = color
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	# Keep the warning in the top-left information area, above the board rank.
	var width := minf(260, size.x * 0.2)
	var rect := Rect2(Vector2(12, 210), Vector2(width, 82))
	var title := "断层轰击 · H%d → H%d" % [_snapshot.get("height_before", 0), _snapshot.get("height_after", 0)]
	var detail := "下个Boss回合卡牌后、战术前降地\n" + ("将失基，可先升地" if _snapshot.get("will_undermine", false) else "地基仍可支撑")
	if not _snapshot.get("ok", false):
		title = "断层轰击 · 目标已失效"
		detail = "到结算时取消\n不会转移攻击其他建筑"
	if _snapshot.get("status") == &"resolved":
		title = "降地完成 · H%d → H%d" % [_snapshot.height_before, _snapshot.height_after]
		detail = "地基失稳：下个完整玩家回合\n可升地恢复或撤离" if _snapshot.get("will_undermine", false) else "地基仍然稳定\n提前升地保住了阵地"
	elif _snapshot.get("status") == &"cancelled":
		title = "断层轰击已取消"
		detail = "原目标不再满足条件\n本次没有降低其他地块"
	if not _selection_active:
		draw_style_box(style, rect)
		draw_string(ThemeDB.fallback_font, rect.position + Vector2(12, 23), title, HORIZONTAL_ALIGNMENT_LEFT, width - 24, 18, color)
		draw_multiline_string(ThemeDB.fallback_font, rect.position + Vector2(12, 46), detail, HORIZONTAL_ALIGNMENT_LEFT, width - 24, 14, 2, Color.WHITE)
	if _snapshot.get("active", false) and _point.is_finite():
		draw_arc(_point, 37, 0, TAU, 40, color, 3, true)
		draw_string(ThemeDB.fallback_font, _point + Vector2(-50, -44), "降地目标", HORIZONTAL_ALIGNMENT_CENTER, 100, 16, color)
