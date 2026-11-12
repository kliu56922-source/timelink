extends "res://ui/key_recipe_board_fx.gd"
var source_name:=""
func begin(receipt: Dictionary) -> void:
	layout=receipt.layout.duplicate(true);legal_anchors=[];active=true;previewing=false;t=0.0;_tokens.clear()
	source_name=receipt.source_name;queue_redraw()
func _draw() -> void:
	super._draw()
	if not active or layout.is_empty() or not is_instance_valid(s()):return
	var destination: Vector2=s()._project_tactical_cell_to_screen(layout[0].cell)
	if not destination.is_finite():return
	var origin:=Vector2(300,180);var progress:=clampf(t/0.8,0.0,1.0)
	draw_string_outline(ThemeDB.fallback_font,origin+Vector2(-60,-10),source_name+" · 维护",HORIZONTAL_ALIGNMENT_LEFT,-1,14,3,Color.BLACK)
	draw_string(ThemeDB.fallback_font,origin+Vector2(-60,-10),source_name+" · 维护",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("79f4de"))
	draw_line(origin,origin.lerp(destination,progress),Color("79f4de"),3,true)
	if progress<1.0:draw_circle(origin.lerp(destination,progress),6,Color("f3ca71"))
	draw_arc(destination,18+12*clampf((t-0.5)/0.9,0.0,1.0),0,TAU,32,Color("f3ca71"),2,true)
