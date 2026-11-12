extends CanvasLayer
const Model=preload("res://battle/analysis/boss_target_read_model_167b.gd")
var scene_ref: WeakRef
var models: Dictionary={}
var buttons: Dictionary={}
var anchors: Dictionary={}
var model_root: Node3D
var drawer: PanelContainer
var details: Label
var blockers: Label
var actors: VBoxContainer
var actor_buttons: Array[Button]=[]
var actor_ids: Array=[]
var preview: Label
var lines: Control
var selected_id:=""
var _elapsed:=0.0
var _drawer_data: Dictionary={}
var _route_reveal_key: Array=[]
var _route_reveal_frames:=0
func scene() -> Variant:
	var s: Variant=scene_ref.get_ref() if scene_ref!=null else null
	return s if is_instance_valid(s) and s.is_inside_tree() else null
func setup(s: Node) -> void:
	name="BossTargets167B";layer=64;scene_ref=weakref(s)
	model_root=Node3D.new();model_root.name="BossPartsGreybox167B";s._get_3d_stage().add_child(model_root)
	lines=Control.new();lines.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(lines);lines.draw.connect(draw_links)
	for part: Dictionary in s.battle.get_weakpoint_snapshots():
		var mesh:=MeshInstance3D.new();var box:=BoxMesh.new();box.size=Vector3(0.38,0.30,0.30);mesh.mesh=box
		mesh.name=part.id;mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var material:=StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mesh.material_override=material
		if part.id=="core_ring":mesh.rotation.y=PI/4.0
		model_root.add_child(mesh);models[part.id]=mesh
		var button:=Button.new();button.custom_minimum_size=Vector2(156,54);button.size=Vector2(156,54)
		button.add_theme_font_size_override("font_size",13);button.clip_text=true;button.pressed.connect(open_target.bind(part.id))
		add_child(button);buttons[part.id]=button
	drawer=PanelContainer.new();add_child(drawer)
	var style:=StyleBoxFlat.new();style.bg_color=Color("101c28");style.border_color=Color("70dce5");style.set_border_width_all(1);style.set_content_margin_all(8);drawer.add_theme_stylebox_override("panel",style)
	var body:=VBoxContainer.new();drawer.add_child(body)
	var scroll:=ScrollContainer.new();scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;body.add_child(scroll)
	var column:=VBoxContainer.new();column.size_flags_horizontal=Control.SIZE_EXPAND_FILL;column.add_theme_constant_override("separation",8);scroll.add_child(column)
	details=_label(column);actors=VBoxContainer.new();column.add_child(actors);blockers=_label(column)
	var close:=Button.new();close.text="收起 · 不付款";close.pressed.connect(dismiss);body.add_child(close);drawer.hide()
	preview=_label(s.advance_panel165.config);preview.name="TargetPrediction167B";preview.get_parent().move_child(preview,0);preview.hide()
	refresh_markers();set_process(true)
func _label(parent: Node) -> Label:
	var label:=Label.new();label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;label.add_theme_font_size_override("font_size",13)
	label.mouse_filter=Control.MOUSE_FILTER_IGNORE;label.size_flags_horizontal=Control.SIZE_EXPAND_FILL;parent.add_child(label);return label
func _process(delta: float) -> void:
	var s: Variant=scene()
	if s==null:return
	if s.advance_panel165.panel.visible and not s.advance_panel165.part_id.is_empty():selected_id=s.advance_panel165.part_id
	refresh_markers();_elapsed+=delta
	if drawer.visible:
		if not Model.board_input_owner(s).is_empty() or s.advance_panel165.panel.visible or s.recipe_panel166.panel.visible or s.support_panel166c.panel.visible or s._building_preview_open167a() or s._exit_modal_active or not s.axis155_native_ready():dismiss()
		elif _elapsed>=0.25:refresh_drawer()
	if _elapsed>=0.25:_elapsed=0
	var opportunities: Node=s.get_node_or_null("CurrentActionPanel")
	if opportunities!=null:opportunities.visible=not drawer.visible and not s.advance_panel165.panel.visible
	s.phase_label166b.text=s.phase_label166b.text.replace("167A","167B")
	drawer.position=s.focus_dock_rect().position;drawer.size=s.focus_dock_rect().size
	preview.visible=s.advance_panel165.panel.visible and s.advance_panel165.config.visible and not s.advance_panel165.part_id.is_empty()
	if preview.visible:
		var actor: CardData=s.advance165.resolve(s.advance_panel165.actor_uid)
		var q:=Model.predict(s,s.advance_panel165.part_id,actor)
		var part: Dictionary=s.battle.get_weakpoint_snapshot(s.advance_panel165.part_id)
		preview.text=str(part.get("name","部位"))+"\n"+str(q.get("text","请选择有效单位"))
	var native_panel: Variant=s.advance_panel165
	var reveal_key: Array=[native_panel.actor_uid,native_panel.part_id,native_panel.route_buttons.map(func(b):return b.get_instance_id())]
	if reveal_key!=_route_reveal_key:
		_route_reveal_key=reveal_key;_route_reveal_frames=2
	elif _route_reveal_frames>0:
		_route_reveal_frames-=1
		if _route_reveal_frames==0 and native_panel.panel.visible and native_panel.config.visible and native_panel.quote.is_empty() and not native_panel.route_buttons.is_empty():native_panel.content_scroll.ensure_control_visible(native_panel.route_buttons[0])
	lines.queue_redraw()
func refresh_markers() -> void:
	var s: Variant=scene()
	if s==null:return
	var cam: Camera3D=s._get_3d_camera();var vp: SubViewportContainer=s.get_node("Battle3DViewport")
	var parts: Array=s.battle.get_weakpoint_snapshots();var screen: Vector2=s.get_viewport_rect().size
	var placements: Array=[];var input_gate: String=Model.gate(s)
	var native_pick: bool=not Model.board_input_owner(s).is_empty()
	for part: Dictionary in parts:
		var id: String=part.id;var col: int=int(part.column) if int(part.column)>=0 else 2
		var a: Node3D=s._get_3d_surface_anchor_for_cell(Vector2i(col,0));var b: Node3D=s._get_3d_surface_anchor_for_cell(Vector2i(col,1))
		if a==null or b==null or cam==null:buttons[id].hide();continue
		var position: Vector3=a.global_position+(a.global_position-b.global_position)*0.55+Vector3.UP*0.25
		models[id].global_position=position
		var material: StandardMaterial3D=models[id].material_override
		material.albedo_color=Color("46505b") if part.broken else Color("727580") if not part.exposed else Color("64dded") if id=="pressure_arm" else Color("e7b765") if id=="energy_valve" else Color("f2dd68")
		models[id].scale=Vector3.ONE*(0.55 if part.broken else 1.0)
		var button: Button=buttons[id]
		button.text=("[残骸] " if part.broken else "[锁] " if not part.exposed else "[部位] ")+part.name+"\n"+("已破坏" if part.broken else "锁定 · 先破外围" if not part.exposed else "%d/%d · 击破−%d"%[part.integrity,part.max_integrity,part.rupture_damage])+"\n"+("任一合法攻核列" if int(part.column)<0 else "第%d列通路"%(int(part.column)+1))
		button.tooltip_text="点击查看部位、可选单位、通路与击破收益；不付款。" if input_gate.is_empty() else input_gate
		button.disabled=not input_gate.is_empty();button.modulate=Color("ffe5a0") if selected_id==id else Color.WHITE
		# Original target picking owns the board. Models have no collider; remove
		# marker hit areas completely rather than blocking the original legal target.
		if native_pick:button.hide();continue
		if cam.is_position_behind(position):button.hide();continue
		button.show();var point: Vector2=vp.get_global_rect().position+cam.unproject_position(position)
		anchors[id]=point;placements.append({"id":id,"point":point,"x":clampf(point.x-78,screen.x*0.12,screen.x*0.78-156),"y":clampf(point.y-70,screen.y*0.18,screen.y*0.65)})
	placements.sort_custom(func(a,b):return a.point.x<b.point.x)
	for i in range(placements.size()):
		var p: Dictionary=placements[i]
		if i>0:p.x=maxf(float(p.x),float(placements[i-1].x)+164.0)
	if not placements.is_empty():
		var overflow: float=maxf(0.0,float(placements[-1].x)+156.0-screen.x*0.80)
		for p: Dictionary in placements:buttons[p.id].position=Vector2(float(p.x)-overflow,float(p.y))
func open_target(id: String) -> void:
	var s: Variant=scene()
	if s==null or not Model.gate(s).is_empty():return
	var data:=Model.inspect(s,id)
	if data.is_empty():return
	selected_id=id
	var panel: Variant=s.advance_panel165
	if panel.panel.visible and panel.config.visible and s.advance165.resolve(panel.actor_uid)!=null and data.part.exposed and not data.part.broken:
		panel.choose_part(id);dismiss();return
	panel.dismiss();s._close_monster_command_menu();drawer.show();refresh_drawer()
func refresh_drawer() -> void:
	var s: Variant=scene()
	if s==null:return
	var data:=Model.inspect(s,selected_id)
	if data.is_empty():dismiss();return
	_drawer_data=data
	details.text=data.detail
	var ids: Array=data.candidates.map(func(c):return c.uid)
	if ids!=actor_ids:
		for button: Button in actor_buttons:actors.remove_child(button);button.queue_free()
		actor_buttons.clear();actor_ids=ids
		for uid: int in ids:
			var button:=Button.new();button.custom_minimum_size.y=58;button.add_theme_font_size_override("font_size",13);button.clip_text=true
			button.pressed.connect(choose_actor.bind(uid));actors.add_child(button);actor_buttons.append(button)
	for i in range(actor_buttons.size()):
		var candidate: Dictionary=data.candidates[i]
		actor_buttons[i].text=candidate.name+" · "+candidate.cost_text+"\n"+("选此单位，继续看路线/预览" if candidate.ok else str(candidate.reason))
		actor_buttons[i].tooltip_text=str(candidate.reason) if not candidate.ok else candidate.prediction.text
	var text: Array[String]=[]
	for blocker: Dictionary in data.blockers:text.append("%s：%s〔%d列%d行〕"%[blocker.get("kind","守卫"),blocker.name,blocker.cell.x+1,blocker.cell.y+1])
	if not text.is_empty():text.append("先清障，或改走其他合法通路；核心不限中列。")
	blockers.text="\n".join(text)
func choose_actor(uid: int) -> void:
	var s: Variant=scene()
	if s==null or not Model.gate(s).is_empty():return
	var data:=Model.inspect(s,selected_id);var actor: CardData=s.advance165.resolve(uid)
	if data.is_empty() or actor==null or data.part.broken or not data.part.exposed:refresh_drawer();return
	s.advance_panel165.open_actor(actor);s.advance_panel165.choose_part(selected_id);dismiss()
	var p:=Model.predict(s,selected_id,actor);preview.text=str(p.get("text",""));preview.show()
func dismiss() -> void:
	if is_instance_valid(drawer):drawer.hide()
func owns_pointer(point: Vector2) -> bool:
	var s: Variant=scene()
	if s==null or not Model.board_input_owner(s).is_empty():return false
	if is_instance_valid(drawer) and drawer.visible and drawer.get_global_rect().has_point(point):return true
	for button: Button in buttons.values():
		if button.is_visible_in_tree() and button.get_global_rect().has_point(point):return true
	return false
func draw_links() -> void:
	var s: Variant=scene()
	if s==null:return
	for id: String in buttons:
		var button: Button=buttons[id]
		if button.visible and anchors.has(id):
			lines.draw_line(button.get_global_rect().get_center(),anchors[id],Color("85b8be"),1.5,true);lines.draw_circle(anchors[id],4,Color("9ee5ee"))
	if selected_id.is_empty():return
	var part: Dictionary=s.battle.get_weakpoint_snapshot(selected_id)
	if part.is_empty():return
	var columns: Array=[0,1,2,3,4] if int(part.column)<0 else [int(part.column)]
	for col: int in columns:
		var p: Vector2=s._project_tactical_cell_to_screen(Vector2i(col,0))
		if p.is_finite():lines.draw_circle(p,8,Color("ffd477"),false,2.0,true)
	var data: Dictionary=_drawer_data if drawer.visible else {}
	for blocker: Dictionary in data.get("blockers",[]):
		var p: Vector2=s._project_tactical_cell_to_screen(blocker.cell)
		if p.is_finite():lines.draw_rect(Rect2(p-Vector2(26,20),Vector2(52,40)),Color("ff9d72"),false,2.0)
func _exit_tree() -> void:
	if is_instance_valid(model_root) and not model_root.is_queued_for_deletion():model_root.queue_free()
