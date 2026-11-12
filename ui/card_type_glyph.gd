extends Control
## 卡牌类型图标：星（法术）/ 兵（棋子）/ 塔（建筑）/ 菱（反制）
## 纯绘制，不依赖美术资源。

var kind := "spell"
var col := Color(0.5, 0.5, 0.5)


func setup(k: String, c: Color) -> void:
	kind = k
	col = c
	queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.30
	match kind:
		"spell":
			var pts := PackedVector2Array([
				c + Vector2(0, -r),
				c + Vector2(r * 0.30, -r * 0.30),
				c + Vector2(r, 0),
				c + Vector2(r * 0.30, r * 0.30),
				c + Vector2(0, r),
				c + Vector2(-r * 0.30, r * 0.30),
				c + Vector2(-r, 0),
				c + Vector2(-r * 0.30, -r * 0.30),
			])
			draw_colored_polygon(pts, col)
		"monster":
			draw_circle(c + Vector2(0, -r * 0.45), r * 0.42, col)
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(-r * 0.68, r),
				c + Vector2(r * 0.68, r),
				c + Vector2(r * 0.32, -r * 0.05),
				c + Vector2(-r * 0.32, -r * 0.05),
			]), col)
		"building":
			draw_rect(Rect2(c + Vector2(-r * 0.66, -r * 0.42), Vector2(r * 1.32, r * 1.42)), col)
			for i in range(3):
				var x := c.x - r * 0.66 + i * r * 0.48
				draw_rect(Rect2(Vector2(x, c.y - r), Vector2(r * 0.32, r * 0.62)), col)
			draw_rect(Rect2(c + Vector2(-r * 0.18, r * 0.30), Vector2(r * 0.36, r * 0.70)),
				Color(0.09, 0.11, 0.13, 1))
		_:
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(0, -r), c + Vector2(r, 0),
				c + Vector2(0, r), c + Vector2(-r, 0),
			]), col)
