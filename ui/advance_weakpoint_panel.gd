extends CanvasLayer
## Direct choices only; the runner owns authorization and native commits.
var scene_ref: WeakRef
var panel: PanelContainer
var config: VBoxContainer
var progress: VBoxContainer
var source_bar: HBoxContainer
var source_title: Label
var source_buttons: Array[Button]=[]
var part_buttons: Dictionary={}
var route_buttons: Array[Button]=[]
var route_box: VBoxContainer
var route_scroll: ScrollContainer
var content_scroll: ScrollContainer
var title: Label
var summary: Label
var progress_text: Label
var confirm_button: Button
var stop_button: Button
var manual_button: Button
var quote: Dictionary={}
var actor_uid:=0
var part_id:=""
var progress_seen:=false
var lines: Control
var route_cells: Array=[]
var _source_key: Array=[]
var _elapsed:=0.0
func s() -> Variant:
	var owner: Variant=scene_ref.get_ref() if scene_ref!=null else null
	return owner if is_instance_valid(owner) and owner.is_inside_tree() else null
func button(parent: Node,text: String,callback: Callable) -> Button:
	var b:=Button.new();b.text=text;b.add_theme_font_size_override("font_size",13);b.custom_minimum_size.y=26
	b.pressed.connect(callback);parent.add_child(b);return b
func label(parent: Node,text: String) -> Label:
	var node:=Label.new();node.text=text;node.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	node.add_theme_font_size_override("font_size",13);node.mouse_filter=Control.MOUSE_FILTER_IGNORE;parent.add_child(node);return node
func setup(owner: Node) -> void:
	scene_ref=weakref(owner);name="AdvanceWeakpointPanel165A";layer=65
	lines=Control.new();lines.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(lines);lines.draw.connect(draw_route)
	source_bar=HBoxContainer.new();source_bar.position=Vector2(16,160);source_bar.add_theme_constant_override("separation",5);add_child(source_bar)
	source_title=label(source_bar,"连续进攻 · 点单位：");source_title.autowrap_mode=TextServer.AUTOWRAP_OFF
	source_bar.size=Vector2(620,30)
	panel=PanelContainer.new();add_child(panel)
	var style:=StyleBoxFlat.new();style.bg_color=Color(0.025,0.045,0.07,1);style.border_color=Color("78ddeb");style.set_border_width_all(1);style.set_corner_radius_all(6);style.set_content_margin_all(8);panel.add_theme_stylebox_override("panel",style)
	var body:=VBoxContainer.new();body.add_theme_constant_override("separation",4);panel.add_child(body)
	config=VBoxContainer.new();config.add_theme_constant_override("separation",4);body.add_child(config)
	config.size_flags_vertical=Control.SIZE_EXPAND_FILL
	content_scroll=ScrollContainer.new();content_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;content_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;config.add_child(content_scroll)
	var choices:=VBoxContainer.new();choices.size_flags_horizontal=Control.SIZE_EXPAND_FILL;content_scroll.add_child(choices)
	title=label(choices,"选择进攻单位")
	for part: Dictionary in owner.battle.get_weakpoint_snapshots():
		var id: String=part.id
		part_buttons[id]=button(choices,part.name,choose_part.bind(id))
	label(choices,"选择路线（保留中间格差异）")
	route_scroll=ScrollContainer.new();route_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;route_scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;route_scroll.custom_minimum_size.y=60;choices.add_child(route_scroll)
	route_box=VBoxContainer.new();route_box.size_flags_horizontal=Control.SIZE_EXPAND_FILL;route_box.add_theme_constant_override("separation",3);route_scroll.add_child(route_box)
	summary=label(choices,"先选要害；选择和预览不付费。")
	choices.move_child(summary,1)
	confirm_button=button(config,"执行已选路线",submit)
	var actions:=HBoxContainer.new();config.add_child(actions)
	manual_button=button(actions,"手动操作",manual);button(actions,"收起",dismiss)
	progress=VBoxContainer.new();body.add_child(progress)
	progress.size_flags_vertical=Control.SIZE_EXPAND_FILL
	var receipt_scroll:=ScrollContainer.new();receipt_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;receipt_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;progress.add_child(receipt_scroll)
	progress_text=label(receipt_scroll,"准备执行");progress_text.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	stop_button=button(progress,"停止后续（Esc）",func():s().advance165.stop("用户停止"))
	var nav:=HBoxContainer.new();progress.add_child(nav)
	button(nav,"返回首页",func():s().axis155_navigate("home"));button(nav,"重开",func():s().axis155_navigate("restart"));button(progress,"收起",dismiss)
	owner.advance165.changed.connect(sync)
	owner.advance165.step_committed.connect(func(i,r):progress_text.text="%d步已提交 · %d指令\n%s\n当前动作完成后可停止，不退已付款。"%[i+1,r.cost,"移动" if i<route_cells.size()-1 else "攻击要害"])
	panel.hide();progress.hide();confirm_button.disabled=true;refresh_sources();set_process(true)
func _process(delta: float) -> void:
	var owner: Variant=s()
	if owner==null:return
	_elapsed+=delta
	if _elapsed>=0.25:_elapsed=0;refresh_sources()
	source_bar.size=Vector2(620,30)
	panel.position=owner.focus_dock_rect().position;panel.size=owner.focus_dock_rect().size
	var opportunity: Node=owner.get_node_or_null("CurrentActionPanel")
	if opportunity!=null:opportunity.visible=not panel.visible
	if is_instance_valid(owner.axis155_panel):owner.axis155_panel.entry_bar.visible=false
	lines.queue_redraw()
func refresh_sources() -> void:
	var owner: Variant=s()
	if owner==null:return
	var key: Array=[]
	for actor: CardData in owner.context.player.field:key.append(actor.get_instance_id())
	source_title.text="连续进攻：先部署单位，下回合再用" if key.is_empty() else "连续进攻 · 点单位："
	if owner.battle.has_method("preparation_active166b") and owner.battle.preparation_active166b():source_title.text="部署阶段 · 进攻待交战启用："
	if key!=_source_key:
		for b: Button in source_buttons:source_bar.remove_child(b);b.queue_free()
		source_buttons.clear();_source_key=key
		for actor: CardData in owner.context.player.field:
			var cell: Vector2i=owner.battle.get_unit_cell(actor)
			source_buttons.append(button(source_bar,"%s %d列%d行"%[actor.get_display_name(),cell.x+1,cell.y+1],open_actor.bind(actor)))
	for i in range(source_buttons.size()):
		var actor: CardData=owner.context.player.field[i]
		var cell: Vector2i=owner.battle.get_unit_cell(actor)
		var availability: Dictionary=owner.advance165.availability(actor)
		source_buttons[i].text="%s %d列%d行 · %s"%[actor.get_display_name(),cell.x+1,cell.y+1,availability.label]
		source_buttons[i].disabled=owner.advance165.running or owner.battle_ended
		source_buttons[i].tooltip_text=availability.reason+"\n点击查看；不会自动替你选择单位。"
func open_actor(actor: CardData) -> void:
	var owner: Variant=s()
	if owner==null or owner.advance165.running:return
	var gate: String=owner.advance165._gate()
	if not gate.is_empty():
		quote={};route_cells=[];owner.advance165.invalidate();_clear_routes()
		panel.show();config.hide();progress.show();progress_text.text="暂不能开始连续进攻：\n"+(actor_help(actor) if not actor_help(actor).is_empty() else gate+"\n若已无其他操作，可结束回合，等Boss行动后再选单位。");stop_button.disabled=true;stop_button.hide();return
	owner._close_monster_command_menu();owner.advance165.invalidate()
	actor_uid=actor.get_instance_id();part_id="";quote={};route_cells=[];progress_seen=false
	title.text=actor.get_display_name()+" · 推进并攻击要害"
	content_scroll.scroll_vertical=0
	_clear_routes();summary.text="连续进攻 1/3 · 点上方可攻击的要害\n再选路线→点「执行已选路线」。\n最多两次移动与一次攻击；预览不付费。"
	var actor_status: Dictionary=owner.battle.advance_actor_status(actor)
	if not actor_status.get("ok",false):
		summary.text="当前不能连续进攻："+str(actor_status.get("reason","单位暂不能行动"))+"\n"+actor_help(actor)+"请先处理上述原因，再点单位或要害。"
	else:
		var availability: Dictionary=owner.advance165.availability(actor)
		if not availability.ok:summary.text=availability.reason+"\n可收起后改点标有「可连续」的单位；手动调整属于跨回合准备。"
	for part: Dictionary in owner.battle.get_weakpoint_snapshots():
		var b: Button=part_buttons[part.id]
		b.text=part.name+(" · 已破坏" if part.broken else " · 先破外围" if not part.exposed else " · %d/%d"%[part.integrity,part.max_integrity])
		b.disabled=part.broken or not part.exposed;b.tooltip_text=b.text
	panel.show();config.show();progress.hide();confirm_button.disabled=true
func actor_help(actor: CardData) -> String:
	return s().advance165.actor_guidance(actor)
func _clear_routes() -> void:
	for b: Button in route_buttons:route_box.remove_child(b);b.queue_free()
	route_buttons.clear();route_scroll.scroll_vertical=0
func choose_part(id: String) -> void:
	var owner: Variant=s()
	if owner==null or owner.advance165.running:return
	owner.advance165.invalidate();part_id=id;quote={};route_cells=[];_clear_routes();confirm_button.disabled=true
	var actor: CardData=owner.advance165.resolve(actor_uid)
	var result: Dictionary=owner.advance165.routes(actor,id)
	if not result.ok:
		summary.text="当前不能进攻："+str(result.reason)+"\n可改选要害/单位；点「手动操作」保留逐步选择。"
		content_scroll.ensure_control_visible(summary);return
	for route: Dictionary in result.routes:
		var cells: Array=route.cells
		var text:="原地攻击" if cells.is_empty() else "→".join(cells.map(func(c):return "%d列%d行"%[c.x+1,c.y+1]))
		var b:=button(route_box,text+"\n最多%d指令 · Depth≤%d"%[route.budget.total_cost,route.budget.depth_cap],choose_route.bind(cells))
		b.set_meta("cells",cells.duplicate());b.tooltip_text=b.text;route_buttons.append(b)
	summary.text="连续进攻 2/3 · 点一条路线\n有%d条路线；绿色连线显示经过的格子。\n选好后再执行，当前未付款。"%route_buttons.size()
	if route_buttons.size()==1:choose_route(result.routes[0].cells)
	else:content_scroll.ensure_control_visible(route_buttons[0])
func choose_route(cells: Array) -> void:
	var owner: Variant=s()
	if owner==null or owner.advance165.running:return
	owner.advance165.invalidate()
	var actor: CardData=owner.advance165.resolve(actor_uid)
	quote=owner.advance165.prepare(actor,part_id,cells)
	confirm_button.disabled=not quote.get("ok",false)
	if not quote.get("ok",false):summary.text=quote.get("reason","当前不可用");quote={};return
	route_cells=[owner.battle.get_unit_cell(actor)]+cells
	summary.text="连续进攻 3/3 · 点「执行已选路线」\n%d次移动＋攻击要害\n费用上限%d指令 · Depth≤%d\n途中可点停止或按Esc；新情况自动停下。\n已完成动作不退款；不会自动结束回合。"%[cells.size(),quote.total_cost,quote.depth_cap]
	for b: Button in route_buttons:b.modulate=Color("9fffe0") if b.get_meta("cells")==cells else Color.WHITE
	content_scroll.ensure_control_visible(summary)
func submit() -> void:
	var owner: Variant=s()
	if owner==null or owner.advance165.running or quote.is_empty():return
	var chosen:=quote.duplicate(true);quote={};confirm_button.disabled=true
	progress_text.text="执行已确认路线；费用逐步支付。";config.hide();progress.show();progress_seen=true
	var result: Dictionary=await owner.advance165.execute(chosen)
	if s()==null:return
	var receipt_lines: Array[String]=["%s · 已执行%d步"%["完成，交回控制" if result.get("ok",false) else "已停止",result.get("receipts",[]).size()],"实际%d指令 · 剩余%d指令"%[int(result.get("actual_cost",0)),int(owner.battle.get_command_economy_snapshot("player").current_points)]]
	for receipt: Dictionary in result.get("receipts",[]):
		if receipt.get("result","")=="hit_weakpoint":receipt_lines.append(str(receipt.message));receipt_lines.append("Boss生命：%d · 要害剩余耐久%d"%[owner.context.enemy.hp,int(receipt.get("weakpoint",{}).get("integrity",0))])
	if not str(result.get("reason","")).is_empty():receipt_lines.append(str(result.reason))
	receipt_lines.append("可收起后选择其他单位/补充部署；没有其他操作时点「结束回合」。已执行动作不退款。")
	progress_text.text="\n".join(receipt_lines)
	stop_button.disabled=true;route_cells=[];sync()
func sync() -> void:
	var owner: Variant=s()
	if owner==null:return
	for b: Button in source_buttons:b.disabled=owner.advance165.running
	stop_button.disabled=not owner.advance165.running
	stop_button.visible=owner.advance165.running
func dismiss() -> void:
	var owner: Variant=s()
	if owner==null or owner.advance165.running:return
	owner.advance165.invalidate();quote={};route_cells=[];panel.hide()
func manual() -> void:
	var owner: Variant=s();var actor: CardData=owner.advance165.resolve(actor_uid)
	dismiss()
	if actor!=null:owner.advance165_manual(actor)
func owns_pointer(point: Vector2) -> bool:return (panel.visible and panel.get_global_rect().has_point(point)) or (source_bar.visible and source_bar.get_global_rect().has_point(point))
func draw_route() -> void:
	var owner: Variant=s()
	if owner==null or not panel.visible or route_cells.size()<2:return
	var points:=PackedVector2Array()
	for cell: Vector2i in route_cells:
		var point: Vector2=owner._project_tactical_cell_to_screen(cell)
		if not point.is_finite():return
		points.append(point)
	lines.draw_polyline(points,Color("73ffe1"),3,true)
