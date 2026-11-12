extends Control
## One short visual sequence reads an already committed receipt. Never writes combat.
signal finished
var receipt: Dictionary = {}
var geometry: Dictionary = {}
var elapsed := 0.0
var reduced_motion := false
var duration := 1.45
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	set_process(false)
func present(result: Dictionary, positions: Dictionary, reduced: bool = false) -> void:
	receipt = result.duplicate(true)
	geometry = positions.duplicate(true)
	reduced_motion = reduced
	elapsed = 0.0
	duration = 1.0 if str(receipt.get("ritual_path", "early")) == "early" else 1.45
	set_process(true)
	queue_redraw()
func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= duration:
		set_process(false)
		finished.emit()
		return
	queue_redraw()
func _text(point: Vector2, text: String, color: Color, font_size: int = 20) -> void:
	draw_string_outline(ThemeDB.fallback_font, point, text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, 4, Color(0.015,0.025,0.04))
	draw_string(ThemeDB.fallback_font, point, text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, color)
func _draw() -> void:
	if receipt.is_empty() or geometry.is_empty(): return
	var engine: Vector2 = geometry.engine
	var boss: Vector2 = geometry.boss
	var player: Vector2 = geometry.player
	if not engine.is_finite() or not boss.is_finite() or not player.is_finite(): return
	var path := str(receipt.get("ritual_path", "early"))
	var full := path != "early"
	var color := Color("79ffe1") if path == "guard" else Color("ffb642")
	var name := "阵地导流" if path == "guard" else "锋线点火" if path == "attack" else "应急释放"
	var alpha := clampf((duration - elapsed) / 0.25, 0.0, 1.0)
	color.a = alpha
	_text(Vector2(boss.x - 94, boss.y - 12), "炉心汇流 · " + name, color, 24 if full else 18)
	if not reduced_motion and full and elapsed < 0.42:
		var phase := elapsed / 0.42
		draw_arc(engine, 12 + phase * 34, 0, TAU, 48, color, 3, true)
		for source in geometry.get("sources", []):
			var point: Vector2 = source.position
			draw_arc(point, 22 + phase * 12, 0, TAU, 32, color, 2, true)
			draw_line(point, engine, Color(color, 0.35), 2, true)
			draw_circle(point.lerp(engine, phase), 5, color)
		return
	if not reduced_motion:
		var impact := clampf((elapsed - (0.42 if full else 0.0)) / 0.55, 0.0, 1.0)
		draw_line(engine, boss, Color(color, 0.25), 3 if full else 1, true)
		draw_arc(boss, 20 + impact * (95 if full else 35), 0, TAU, 48, color, 3, true)
		for hit in geometry.get("hits", []):
			var point: Vector2 = hit.position
			draw_line(boss, point, Color(color, 0.4), 2, true)
			draw_arc(point, 14 + impact * 28, 0, TAU, 32, color, 3, true)

		if int(receipt.get("ritual_shield_gained", 0)) > 0:
			draw_arc(player, 40 + impact * 140, PI, TAU, 64, color, 5, true)
			draw_arc(player, 24 + impact * 105, PI, TAU, 64, Color(color, 0.45), 2, true)
	for hit in geometry.get("hits", []):
		_text(hit.position + Vector2(-24,-24), "HP -%d" % int(hit.hp_loss), color, 18)
	_text(boss + Vector2(-74, 18), "破盾%d · HP -%d" % [int(receipt.get("ritual_boss_shield_removed_total", 0)), int(receipt.get("final_actual_hp_loss", 0))], color, 18)
	var od_change := int(receipt.get("ritual_boss_od_after", 0)) - int(receipt.get("ritual_boss_od_before", 0))
	if od_change != 0: _text(boss + Vector2(-48, 41), "Boss OD %+d" % od_change, color, 16)
	if int(receipt.get("ritual_shield_gained", 0)) > 0:
		_text(player + Vector2(-67, -20), "护盾 +%d" % int(receipt.ritual_shield_gained), color, 22)
	if elapsed > 0.88 or reduced_motion:
		var hand: Vector2 = geometry.hand
		var count := int(receipt.get("ritual_cards_drawn", 0))
		if not reduced_motion:
			var phase := clampf((elapsed - 0.88) / 0.3, 0, 1)
			for i in range(mini(5, count)):
				var point: Vector2 = engine.lerp(hand + Vector2((i - count * 0.5) * 22, 0), phase)
				draw_rect(Rect2(point - Vector2(10,14), Vector2(20,28)), Color(color,0.25))
				draw_rect(Rect2(point - Vector2(10,14), Vector2(20,28)), color, false, 2)
		_text(hand + Vector2(-86,-45), "抽牌 %d/%d · 已入手" % [count, int(receipt.get("ritual_draw_requested", 0))], color, 18)
	var depth_change := int(receipt.get("ritual_depth_after", 0)) - int(receipt.get("ritual_depth_before", 0))
	if depth_change != 0: _text(player + Vector2(-52, 6), "透支 Depth %+d" % depth_change, Color(1.0,0.4,0.25,alpha), 16)
