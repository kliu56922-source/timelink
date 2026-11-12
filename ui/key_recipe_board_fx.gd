extends Control
## Greybox geometry follows actual cells. This presenter never applies rules.
var scene_ref: WeakRef
var layout: Array=[]
var active:=false
var previewing:=false
var valid:=false
var t:=0.0
var _tokens: Dictionary={}
var legal_anchors: Array[Vector2i]=[]
func show_anchors(cells: Array[Vector2i]) -> void:
	legal_anchors=cells.duplicate();previewing=true;queue_redraw()
func setup(owner: Node) -> void:
	scene_ref=weakref(owner);mouse_filter=Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
func s() -> Variant:return scene_ref.get_ref() if scene_ref!=null else null
func preview(q: Dictionary) -> void:
	if active:return
	layout=q.get("layout",[]).duplicate(true);valid=q.get("ok",false);previewing=true;queue_redraw()
func clear_preview() -> void:
	if active:return
	layout=[];legal_anchors=[];previewing=false;queue_redraw()
func begin(receipt: Dictionary) -> void:
	layout=receipt.layout.duplicate(true);legal_anchors=[];active=true;previewing=false;t=0.0;_tokens.clear()
	var owner: Variant=s()
	for i in range(layout.size()):
		var c: CardData=owner.battle.get_unit_at_cell(layout[i].cell)
		if i==1:
			for building: CardData in owner.context.player.traps:
				if building.card_id=="P05":c=building;break
		if c==null:continue
		var token: Node3D=owner._get_3d_token_for_card(c)
		if is_instance_valid(token):_tokens[i]={"ref":weakref(token),"scale":token.scale}
	present(0.0)
func present(seconds: float) -> void:
	t=seconds
	for i: int in _tokens:
		var token: Node3D=_tokens[i].ref.get_ref()
		if is_instance_valid(token):
			var amount:=clampf((t-(0.0 if i==0 else 0.2 if i==1 else 0.55))/0.65,0.03,1.0)
			token.scale=_tokens[i].scale*amount
	queue_redraw()
func finish() -> void:
	for i: int in _tokens:
		var token: Node3D=_tokens[i].ref.get_ref()
		if is_instance_valid(token):token.scale=_tokens[i].scale
	_tokens.clear();active=false;layout=[];queue_redraw()
func _process(_delta: float) -> void:
	if active or previewing:queue_redraw()
func _draw() -> void:
	var owner: Variant=s()
	if not is_instance_valid(owner):return
	for cell: Vector2i in legal_anchors:
		var point: Vector2=owner._project_tactical_cell_to_screen(cell)
		if point.is_finite():draw_circle(point,7,Color("79f4de"));draw_arc(point,12,0,TAU,24,Color("79f4de"),2,true)
	if layout.is_empty():return
	var points: Array[Vector2]=[]
	for i in range(layout.size()):
		var p: Vector2=owner._project_tactical_cell_to_screen(layout[i].cell)
		if not p.is_finite():return
		points.append(p)
		var color:=Color("79f4de") if valid or active else Color("ff8f8f")
		var onset:=0.0 if i==0 else 0.2 if i==1 else 0.55
		var phase:=clampf((t-onset)/0.8,0.0,1.0) if active else 1.0
		var ring:=PackedVector2Array([p+Vector2(-44,-15),p+Vector2(36,-15),p+Vector2(44,15),p+Vector2(-36,15),p+Vector2(-44,-15)])
		color.a=0.8 if previewing else phase
		draw_colored_polygon(ring,Color(color,0.12*color.a));draw_polyline(ring,color,2,true)
		var text: String=layout[i].name+" %d列%d行"%[layout[i].cell.x+1,layout[i].cell.y+1]
		var label_point:=p+Vector2(-58,34+i%2*17)
		draw_string_outline(ThemeDB.fallback_font,label_point,text,HORIZONTAL_ALIGNMENT_LEFT,-1,13,4,Color(0,0,0,color.a))
		draw_string(ThemeDB.fallback_font,label_point,text,HORIZONTAL_ALIGNMENT_LEFT,-1,13,color)
	if points.size()!=3:return
	for index: int in [0,2]:
		var start:=points[1];var finish_point:=points[index]
		var progress:=1.0 if previewing else clampf((t-0.9)/0.9,0.0,1.0)
		var col:=Color("f3ca71") if active else Color("79f4de")
		draw_line(start,start.lerp(finish_point,progress),col,3,true)
		if active and progress>0 and progress<1:draw_circle(start.lerp(finish_point,progress),6,col)
func _exit_tree() -> void:finish()
