extends "res://scenes/experiments/phase101_construction_site_trial.gd"
const Fortification := preload("res://core/battle/edge_fortification_trial.gd")
var fortification: RefCounted
var _edge_intent_label: Label
var _fort_button: Button
var _fort_window: Window
var _fort_cell: OptionButton
var _fort_edge: OptionButton
var _fort_kind: OptionButton
var _fort_text: Label
var _fort_confirm: ConfirmationDialog
var _fort_quote: Dictionary={}
var _fort_visuals: Node3D
var _fort_draw_revision:=-1

func _setup_game() -> void:
	super._setup_game();fortification=Fortification.new(battle,engineering);fortification.begin_player_turn()
	call_deferred("_build_fortification_controls")

func _start_player_turn_rules(initial: bool=false) -> void:
	super._start_player_turn_rules(initial)
	if fortification!=null:fortification.begin_player_turn();_draw_fortifications();_refresh_edge_intent()

func _run_boss_turn_rules_before_tactics() -> Dictionary:
	var result:=super._run_boss_turn_rules_before_tactics()
	if fortification!=null:
		var breach: Dictionary=fortification.resolve_boss_intent()
		if breach.ok:print("[EDGE_BOSS_SIEGE] ",JSON.stringify(breach));_refresh_tables();_refresh_command_economy_surfaces();_draw_fortifications()
	_refresh_edge_intent()
	return result

func _build_fortification_controls() -> void:
	var layer:=CanvasLayer.new();layer.name="FortificationControls102";layer.layer=32;add_child(layer)
	_edge_intent_label=Label.new();_edge_intent_label.name="EdgeSiegeIntent";_edge_intent_label.position=Vector2(16,624);_edge_intent_label.size=Vector2(230,80);_edge_intent_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;_edge_intent_label.add_theme_font_size_override("font_size",15);_edge_intent_label.add_theme_color_override("font_color",Color(1,0.78,0.4));layer.add_child(_edge_intent_label)
	_fort_button=Button.new();_fort_button.name="BasicFortificationButton";_fort_button.text="基础城防 · 墙与门";_fort_button.position=Vector2(16,576);_fort_button.size=Vector2(192,40);layer.add_child(_fort_button)
	_fort_window=Window.new();_fort_window.visible=false;_fort_window.name="BasicFortificationWindow";_fort_window.title="基础城防 · 沿格边施工";_fort_window.size=Vector2i(530,360);add_child(_fort_window)
	_fort_window.close_requested.connect(_fort_window.hide)
	var body:=VBoxContainer.new();body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);body.offset_left=16;body.offset_right=-16;body.offset_top=14;body.offset_bottom=-14;_fort_window.add_child(body)
	_fort_text=Label.new();_fort_text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;_fort_text.custom_minimum_size=Vector2(490,116);body.add_child(_fort_text)
	_fort_cell=OptionButton.new();_fort_cell.name="FortificationCell";body.add_child(_fort_cell)
	for cell: Vector2i in battle.tactical_grid_rules.get_all_cells():
		_fort_cell.add_item("第%d列，第%d行"%[cell.x+1,cell.y+1]);_fort_cell.set_item_metadata(_fort_cell.item_count-1,cell)
	_fort_edge=OptionButton.new();_fort_edge.name="FortificationEdge";body.add_child(_fort_edge)
	for label: String in ["北边","东边","南边","西边"]:_fort_edge.add_item(label)
	_fort_kind=OptionButton.new();_fort_kind.name="FortificationKind";_fort_kind.add_item("墙段 · 2指令");_fort_kind.add_item("门段 · 3指令");body.add_child(_fort_kind)
	var preview:=Button.new();preview.text="查看当前费用 / 改建";body.add_child(preview);preview.pressed.connect(_preview_fortification)
	var close:=Button.new();close.text="返回战场";body.add_child(close);close.pressed.connect(_fort_window.hide)
	_fort_button.pressed.connect(func():_refresh_fortification_text();_fort_window.popup_centered())
	for picker: OptionButton in [_fort_cell,_fort_edge,_fort_kind]:picker.item_selected.connect(func(_i):_refresh_fortification_text())
	_fort_confirm=ConfirmationDialog.new();_fort_confirm.title="确认城防投入";_fort_confirm.ok_button_text="支付并施工";_fort_confirm.cancel_button_text="取消";_fort_confirm.min_size=Vector2i(470,200);add_child(_fort_confirm)
	_fort_confirm.confirmed.connect(_commit_fortification);_fort_confirm.canceled.connect(func():_fort_quote={})
	_fort_visuals=Node3D.new();_fort_visuals.name="SharedEdgeGreybox102";_tactical_terrain_presenter.add_child(_fort_visuals)
	_draw_fortifications();_refresh_edge_intent()

func _fort_selection() -> Dictionary:
	return {"cell":_fort_cell.get_selected_metadata(),"edge":[&"north",&"east",&"south",&"west"][_fort_edge.selected],"kind":&"gate" if _fort_kind.selected==1 else &"wall"}

func _refresh_fortification_text() -> void:
	if not is_instance_valid(_fort_text):return
	var selection:=_fort_selection()
	var current: Dictionary=fortification.get_edge(selection.cell,selection.edge)
	var state: Dictionary=fortification.snapshot()
	_fort_text.text="常驻城防：不需要抽到墙或门卡。与建筑共用施工次数。\n工地1耐久，存活到下个己方回合完工为3耐久。\n墙阻挡地面跨边与近战，远距普通交战方向掩护1。\n门只为友军移动放行；改建1指令，保留损伤。\n施工预算%d/4%s"%[engineering.snapshot().admissions," · 当前%d/%d"%[current.hp,current.max_hp] if not current.is_empty() else ""]
	if not state.intent.is_empty() and not state.intent.get("resolved",false):_fort_text.text+="\nB-07已预告：下个Boss战术窗口攻击防线。"

func _preview_fortification() -> void:
	var selection:=_fort_selection();_fort_quote=fortification.inspect(selection.cell,selection.edge,selection.kind)
	_fort_confirm.get_ok_button().disabled=not _fort_quote.ok
	_fort_confirm.dialog_text=("支付%d共享指令。\n%s\n与工程册共用本回合一次施工，计入原Depth阈值。\n不增加热量、长期充能或连锁。"%[_fort_quote.command_cost,"改建保留当前耐久，不会修满。" if _fort_quote.conversion else "立即放置1耐久工地，下个己方回合存活才完工。"] if _fort_quote.ok else _engineering_reason(str(_fort_quote.reason_code)))
	_fort_confirm.popup_centered()

func _commit_fortification() -> void:
	if not _fort_quote.get("ok",false):return
	var q:=_fort_quote;_fort_quote={}
	var receipt: Dictionary=fortification.execute(q.cell,q.edge,q.kind,q)
	if receipt.ok:_play_command_economy_spend(int(receipt.command_cost));_draw_fortifications();_refresh_fortification_text()
	print("[EDGE_CONSTRUCTION] ",JSON.stringify(receipt))

func _draw_fortifications() -> void:
	if fortification==null or not is_instance_valid(_fort_visuals):return
	var state: Dictionary=fortification.snapshot()
	if int(state.revision)==_fort_draw_revision:return
	_fort_draw_revision=state.revision
	for child: Node in _fort_visuals.get_children():_fort_visuals.remove_child(child);child.queue_free()
	for edge: Dictionary in state.edges.values():
		if int(edge.hp)<=0:continue
		var a: Node3D=_tactical_terrain_presenter.get_surface_anchor(edge.a)
		var b: Node3D=_tactical_terrain_presenter.get_surface_anchor(edge.b)
		if not is_instance_valid(a) or not is_instance_valid(b):continue
		var group:=Node3D.new();group.name="EdgeFortification";_fort_visuals.add_child(group)
		group.global_position=(a.global_position+b.global_position)*0.5+Vector3.UP*0.25
		var normal: Vector3=b.global_position-a.global_position;normal.y=0
		group.look_at(group.global_position+normal,Vector3.UP)
		var spacing: float=Vector2(normal.x,normal.z).length()
		var material:=StandardMaterial3D.new();material.albedo_color=Color(0.55,0.64,0.74) if edge.kind==&"gate" else Color(0.7,0.64,0.46)
		if edge.stage=="construction":material.albedo_color=Color(0.7,0.47,0.2)
		for index: int in range(2 if edge.kind==&"gate" else 1):
			var mesh:=MeshInstance3D.new();var box:=BoxMesh.new();box.size=Vector3(spacing*(0.22 if edge.kind==&"gate" else 0.82),0.5,0.1);mesh.mesh=box;mesh.material_override=material;group.add_child(mesh)
			if edge.kind==&"gate":mesh.position.x=spacing*(-0.3 if index==0 else 0.3)
		var label:=Label3D.new();label.text=("门" if edge.kind==&"gate" else "墙")+(" · 施工" if edge.stage=="construction" else "")+" %d/%d"%[edge.hp,edge.max_hp];label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;label.pixel_size=0.004;label.font_size=40;label.no_depth_test=true;label.position.y=0.5;group.add_child(label)

func _process(delta: float) -> void:
	super._process(delta)
	if _engineering_frame%15==0:_draw_fortifications();_refresh_edge_intent();_refresh_fortification_text()

func _refresh_edge_intent() -> void:
	if fortification==null or not is_instance_valid(_edge_intent_label):return
	var state: Dictionary=fortification.snapshot()
	var intent: Dictionary=state.intent
	_edge_intent_label.visible=false
	if intent.is_empty() or intent.get("resolved",false) or int(intent.turn)!=context.turn_count:return
	var body: Dictionary=state.edges.get(intent.target.key,{})
	if body.is_empty() or body.id!=intent.target.edge_id or int(body.revision)!=int(intent.target.revision) or int(body.hp)<=0:return
	var source: CardData
	for actor: CardData in context.enemy.field:
		if actor.get_instance_id()==int(intent.actor_runtime_id):source=actor;break
	if source==null:return
	var delta: Vector2i=body.b-body.a
	var direction: String={Vector2i.UP:"北边",Vector2i.RIGHT:"东边",Vector2i.DOWN:"南边",Vector2i.LEFT:"西边"}.get(delta,"")
	_edge_intent_label.text="B-07 %s · 第%d列第%d行\n下个Boss战术窗口：第%d列第%d行%s%s −1耐久"%[source.name,battle.get_unit_cell(source).x+1,battle.get_unit_cell(source).y+1,body.a.x+1,body.a.y+1,direction,"门" if body.kind==&"gate" else "墙"]
	_edge_intent_label.visible=true

func restart_gb1_battle() -> void:
	if _gb1_restarting:return
	_gb1_restarting=true
	var err:=get_tree().change_scene_to_file("res://scenes/experiments/phase102_edge_fortification_trial.tscn")
	if err!=OK:_gb1_restarting=false;push_error("Edge trial restart failed: %d"%err)
