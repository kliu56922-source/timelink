extends "res://scenes/presentation/card_target_guidance.gd"
## Read-only committed receipt. Missing recipients stay at their source.
var source := Vector2.ZERO
var target := Vector2.ZERO
var message := ""
var elapsed := 0.0
var reduced := false
const LIFETIME := 3.0
func _ready() -> void:
	super._ready()
	var no_targets: Array[Dictionary] = []
	show_targets(no_targets, message)
func _layout_banner() -> void:
	if not is_instance_valid(_banner): return
	_banner.visible = not instruction.is_empty()
	_instruction_label.text = instruction
	var width := minf(480, maxf(80, size.x-24))
	_instruction_label.size = Vector2(width-24,0)
	_banner.size = Vector2(width,maxf(38,_instruction_label.get_minimum_size().y+16))
	_place_banner(Vector2(target.x-width*0.5,target.y-_banner.size.y-26))
# Consecutive receipts can fill the preferred bands. Search the remaining
# viewport only after those source-local placements have all been blocked.
func _place_banner(preferred: Vector2) -> void:
	super._place_banner(preferred)
	if not reserved_rects.any(func(rect):return rect.intersects(_banner.get_rect())):return
	for y in range(12,maxi(13,int(size.y-_banner.size.y-12)+1),24):
		for x in range(12,maxi(13,int(size.x-_banner.size.x-12)+1),64):
			var candidate := Rect2(Vector2(x,y),_banner.size)
			if reserved_rects.all(func(rect):return not rect.intersects(candidate)):
				_banner.position=candidate.position
				return
func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= LIFETIME:
		queue_free()
		return
	modulate.a = clampf((LIFETIME-elapsed)/0.3,0,1)
	queue_redraw()
func _draw() -> void:
	var color := Color("79ffe1")
	if not reduced and source != target:
		draw_line(source,target,Color(color,0.5),2,true)
		draw_circle(source.lerp(target,clampf(elapsed/0.35,0,1)),4,color)
		draw_arc(target,16+minf(elapsed,0.9)*20,0,TAU,32,color,2,true)
	# Static source identification survives reduced motion.
	if is_instance_valid(_banner):
		draw_line(target,Vector2(clampf(target.x,_banner.position.x,_banner.position.x+_banner.size.x),_banner.position.y+_banner.size.y),Color(color,0.5),1,true)
