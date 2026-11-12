extends Control
## Value-only screen presentation. No battle owner, permissions or payment state.
var _preview: Dictionary = {}
var _intent: Dictionary = {}
var _committed: Dictionary = {}
var _elapsed := 0.0
var _duration := 0.0
var _frames: Array[Dictionary] = []
var _impact_played := false
signal impact_requested(cue_name: String)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	set_process(false)

func show_preview(snapshot: Dictionary) -> void:
	_preview = snapshot.duplicate(true)
	queue_redraw()

func show_intent(snapshot: Dictionary) -> void:
	_intent = snapshot.duplicate(true) if snapshot.get("active", false) else {}
	queue_redraw()

func present_committed(fact: Dictionary) -> void:
	if not fact.get("ok", false):
		return
	_committed = fact.duplicate(true)
	_preview = {}
	_frames = _result_frames(fact)
	_elapsed = 0.0
	_impact_played = false
	_duration = 0.45 if _frames.is_empty() else 1.1 + maxf(0, _frames.size() - 1) * 0.34
	if fact.get("reduced_motion", false):
		_emit_impact()
	set_process(true)
	queue_redraw()

# Geometry can follow the camera without restarting the effect or replaying sound.
func update_committed_geometry(view: Dictionary) -> void:
	if _committed.is_empty():
		return
	for key in ["target_screen_position", "source_screen_position", "secondary_screen_position", "edge_points"]:
		if view.has(key):
			_committed[key] = view[key]
	queue_redraw()

func clear(_reason: StringName) -> void:
	_preview = {}
	_intent = {}
	_committed = {}
	_frames.clear()
	_elapsed = 0.0
	_duration = 0.0
	set_process(false)
	queue_redraw()

func get_debug_snapshot() -> Dictionary:
	return {"marker_count": int(not _preview.is_empty()) + int(not _intent.is_empty()) + int(not _committed.is_empty()),
		"active_tweens": 0, "preview_active": not _preview.is_empty(), "preview": _preview.duplicate(true),
		"intent": _intent.duplicate(true), "committed": _committed.duplicate(true),
		"result_frames": _frames.duplicate(true), "elapsed": _elapsed, "impact_played": _impact_played}

func _result_frames(fact: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if fact.get("mode") == &"p18_siege":
		for hit: Dictionary in fact.get("hits", []):
			var broken := int(hit.get("wall_before", 0)) > 0 and int(hit.get("wall_after", 0)) == 0
			var text := "破墙！" if broken else "墙体受击"
			if int(hit.get("wall_damage", 0)) == 0:
				text = "贯穿"
			text += "  耐久 %d→%d" % [hit.get("wall_before", 0), hit.get("wall_after", 0)]
			if int(hit.get("unit_damage", 0)) > 0:
				text += "  驻防 -%d HP" % hit.unit_damage
			elif int(hit.get("core_damage", 0)) > 0:
				text += "  核心 -%d" % hit.core_damage
			elif int(hit.get("wall_damage", 0)) == 0:
				text += "  无追加伤害"
			result.append({"text": text, "broken": broken, "secondary": int(hit.get("unit_damage", 0)) + int(hit.get("core_damage", 0)) > 0})
	elif fact.has("structure_fact"):
		var hit: Dictionary = fact.structure_fact
		var before := int(hit.get("before", {}).get("integrity_current", 0))
		var after := int(hit.get("after", {}).get("integrity_current", 0))
		var wall: bool = fact.get("resolved_target", {}).get("target_kind") == &"structure_module"
		var broken := before > 0 and after == 0
		var title := ("破墙！" if broken else "墙体受击") if wall else ("核心摧毁！" if broken else "核心受击")
		result.append({"text": "%s  耐久 %d→%d" % [title, before, after], "broken": broken, "secondary": false})
	return result

func _emit_impact() -> void:
	if _impact_played or _frames.is_empty():
		return
	_impact_played = true
	# P18 already publishes its hit audio through BattleSystem. Do not double it.
	if _committed.get("mode") != &"p18_siege":
		impact_requested.emit("card_destroy" if _frames[0].broken else "monster_hit")

func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= 0.32:
		_emit_impact()
	if _elapsed >= _duration:
		_committed = {}
		_frames.clear()
		set_process(false)
	queue_redraw()

func _draw() -> void:
	_draw_fact(_preview, Color("f4c95d"), false)
	_draw_fact(_intent, Color("fb9468"), true)
	if _committed.is_empty():
		return
	var target: Vector2 = _committed.get("target_screen_position", Vector2.INF)
	if not target.is_finite():
		return
	var reduced: bool = _committed.get("reduced_motion", false)
	var source: Vector2 = _committed.get("source_screen_position", Vector2.INF)
	var color := Color("8effcd")
	if not reduced and _elapsed < 0.32 and source.is_finite():
		draw_arc(source, 19.0, 0, TAU, 32, color, 3.0, true)
		var travel := clampf((_elapsed - 0.12) / 0.20, 0, 1)
		draw_line(source, target, Color(0.5, 1, 0.8, 0.3), 2.0, true)
		draw_circle(source.lerp(target, travel), 7.0, Color.WHITE)
		return
	_draw_fact(_committed, color, false)
	if _frames.is_empty():
		return
	var index := clampi(int(maxf(0, _elapsed - 0.32) / 0.34), 0, _frames.size() - 1)
	var frame: Dictionary = _frames[index]
	color = Color("ffd080") if frame.broken else color
	if not reduced:
		var age := maxf(0, _elapsed - 0.32 - index * 0.34)
		var radius := 14.0 + minf(age / 0.24, 1.0) * 28.0
		draw_arc(target, radius, 0, TAU, 32, color, 3.0, true)
		if frame.broken:
			for i in range(8):
				var direction := Vector2.from_angle(i * TAU / 8.0)
				draw_line(target + direction * radius, target + direction * (radius + 10), color, 4.0, true)
	var secondary: Vector2 = _committed.get("secondary_screen_position", Vector2.INF)
	if frame.secondary and secondary.is_finite():
		draw_line(target, secondary, color, 5.0, true)
		draw_arc(secondary, 22.0, 0, TAU, 28, color, 4.0, true)
	# Keep all resolved hits readable in Reduced Motion; no camera movement required.
	var lines: Array[String] = []
	if reduced:
		for i in range(_frames.size()):
			lines.append(("%d. " % (i + 1) if _frames.size() > 1 else "") + _frames[i].text)
	else:
		lines.append(("%d/%d  " % [index + 1, _frames.size()] if _frames.size() > 1 else "") + frame.text)
	var width := minf(460.0, size.x - 24.0)
	var origin := target + Vector2(-width * 0.5, -74.0 - (lines.size() - 1) * 25.0)
	origin.x = clampf(origin.x, 12, maxf(12, size.x - width - 12))
	origin.y = clampf(origin.y, 12, maxf(12, size.y - 38 - lines.size() * 25))
	var rect := Rect2(origin, Vector2(width, 16 + lines.size() * 25))
	draw_style_box(_label_style(), rect)
	for i in range(lines.size()):
		draw_string(ThemeDB.fallback_font, origin + Vector2(12, 27 + i * 25), lines[i], HORIZONTAL_ALIGNMENT_LEFT, width - 24, 18, color)

func _draw_fact(fact: Dictionary, color: Color, dashed: bool) -> void:
	if fact.is_empty():
		return
	var edge: PackedVector2Array = fact.get("edge_points", PackedVector2Array())
	if edge.size() == 2 and edge[0].is_finite() and edge[1].is_finite():
		if dashed:
			draw_dashed_line(edge[0], edge[1], color, 5.0, 9.0)
		else:
			draw_line(edge[0], edge[1], color, 6.0, true)
	var point: Vector2 = fact.get("target_screen_position", Vector2.INF)
	if point.is_finite():
		if dashed:
			draw_colored_polygon(PackedVector2Array([point + Vector2(0, -14), point + Vector2(12, 9), point + Vector2(-12, 9)]), color)
		else:
			draw_arc(point, 12.0, 0.0, TAU, 24, color, 3.0, true)
	var secondary: Vector2 = fact.get("secondary_screen_position", Vector2.INF)
	if secondary.is_finite() and point.is_finite():
		draw_line(point, secondary, color, 2.0, true)
		draw_rect(Rect2(secondary - Vector2(7, 7), Vector2(14, 14)), color, false, 2.0)
	if dashed:
		var label: String = fact.get("label", "B-07 预备攻城")
		var rect: Rect2 = fact.get("label_rect", Rect2(330, 95, 720, 52))
		draw_style_box(_label_style(), rect)
		draw_string(ThemeDB.fallback_font, rect.position + Vector2(10, 21), label, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 20, 15, color)
		draw_string(ThemeDB.fallback_font, rect.position + Vector2(10, 43), "下个 Boss 回合：卡牌结算后、战术行动开始时执行", HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 20, 14, Color.WHITE)

func _label_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.08, 0.13, 0.94)
	style.border_color = Color("fb9468")
	style.set_border_width_all(1)
	return style

func _exit_tree() -> void:
	set_process(false)
