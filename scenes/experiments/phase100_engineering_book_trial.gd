extends "res://scenes/experiments/phase76_partial_hero_growth_trial.gd"
## A player-operated opt-in trial. No resource or position injection.
const Engineering := preload("res://core/battle/building_engineering_trial.gd")
var engineering: RefCounted
var _engineering_button: Button
var _engineering_window: Window
var _engineering_text: Label
var _engineering_cells: OptionButton
var _engineering_edges: OptionButton
var _engineering_hand: OptionButton
var _engineering_confirm: ConfirmationDialog
var _engineering_quote: Dictionary = {}
var _engineering_frame := 0

func _setup_game() -> void:
	super._setup_game()
	engineering=Engineering.new(battle)
	engineering.begin_player_turn()
	call_deferred("_build_engineering_controls")

func _start_player_turn_rules(initial: bool=false) -> void:
	super._start_player_turn_rules(initial)
	if engineering!=null:
		engineering.begin_player_turn()
		_refresh_tables();_refresh_command_economy_surfaces()

func _build_engineering_controls() -> void:
	var layer:=CanvasLayer.new();layer.name="EngineeringTrialControls";layer.layer=31;add_child(layer)
	_engineering_button=Button.new();_engineering_button.name="EngineeringBookButton"
	_engineering_button.text="工程册 · 查看计划";_engineering_button.position=Vector2(16,530);_engineering_button.size=Vector2(192,40)
	layer.add_child(_engineering_button)
	_engineering_window=Window.new();_engineering_window.visible=false;_engineering_window.name="EngineeringBookWindow";_engineering_window.title="工程册 · 建筑原型";_engineering_window.size=Vector2i(590,460);add_child(_engineering_window)
	_engineering_window.close_requested.connect(_engineering_window.hide)
	_engineering_button.pressed.connect(func():_refresh_engineering();_engineering_window.popup_centered())
	var body:=VBoxContainer.new();body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);body.offset_left=18;body.offset_right=-18;body.offset_top=14;body.offset_bottom=-14;_engineering_window.add_child(body)
	_engineering_text=Label.new();_engineering_text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;_engineering_text.custom_minimum_size=Vector2(540,168);body.add_child(_engineering_text)
	_engineering_cells=OptionButton.new();_engineering_cells.name="EngineeringTargetCell";body.add_child(_engineering_cells)
	for cell: Vector2i in battle.tactical_grid_rules.get_all_cells():
		_engineering_cells.add_item("建造位置：第%d列，第%d行"%[cell.x+1,cell.y+1]);_engineering_cells.set_item_metadata(_engineering_cells.item_count-1,cell)
	_engineering_edges=OptionButton.new();_engineering_edges.name="EngineeringOrientation";body.add_child(_engineering_edges)
	for edge: String in ["北","东","南","西"]:_engineering_edges.add_item("围护墙朝向："+edge)
	_engineering_cells.item_selected.connect(func(_i):_refresh_engineering(false))
	_engineering_edges.item_selected.connect(func(_i):_refresh_engineering(false))
	for rush: bool in [false,true]:
		var button:=Button.new();button.name="RushBuild" if rush else "SteadyBuild";button.text="急筑：2指令＋2热 · 立即完工" if rush else "稳筑：2指令 · 下个己方回合完工";body.add_child(button)
		button.pressed.connect(_preview_engineering.bind(rush))
	_engineering_hand=OptionButton.new();_engineering_hand.name="HandBlueprintSelection";body.add_child(_engineering_hand)
	var stage_button:=Button.new();stage_button.name="StageBlueprint";stage_button.text="整备选中的手牌 → 空工程位（本回合一次）";body.add_child(stage_button)
	stage_button.pressed.connect(_stage_engineering_hand)
	var close:=Button.new();close.text="返回战场";body.add_child(close);close.pressed.connect(_engineering_window.hide)
	_engineering_confirm=ConfirmationDialog.new();_engineering_confirm.title="确认建筑投入";_engineering_confirm.ok_button_text="支付并安排";_engineering_confirm.cancel_button_text="取消";_engineering_confirm.min_size=Vector2i(470,210);add_child(_engineering_confirm)
	_engineering_confirm.confirmed.connect(_commit_engineering)
	_engineering_confirm.canceled.connect(func():_engineering_quote={})

func _engineering_edge() -> StringName:
	return [&"north",&"east",&"south",&"west"][_engineering_edges.selected]

func _selected_engineering_cell() -> Vector2i:
	return _engineering_cells.get_item_metadata(_engineering_cells.selected)

func _refresh_engineering(refresh_hand: bool=true) -> void:
	if engineering==null or not is_instance_valid(_engineering_text):return
	var state: Dictionary=engineering.snapshot()
	var q: Dictionary=engineering.inspect(_selected_engineering_cell(),false,_engineering_edge())
	var plan_name: String={"P13":"冷却设施","P16":"围护设施（现有1×1）"}.get(state.plan,"工程位空闲")
	var pending:=""
	for order: Dictionary in state.pending:
		pending+="\n待完工：%s，第%d列第%d行%s"%[{"P13":"冷却设施","P16":"围护设施"}.get(order.card_id,"设施"),order.cell.x+1,order.cell.y+1,"（条件受阻，后续回合重试）" if order.reason!="" else ""]
	_engineering_text.text="当前计划：%s\n工程位用完后下回合翻出；每回合一次施工。\n稳筑等待期间没有实体、不会阻挡或提供防护。\n急筑消耗当前热量，与OD/精炼竞争，不增加长期充能。\n当前位置：%s\n已完工%d / 本场工程预算4%s\n格边墙门、施工中受击和大尺寸将在后续阶段加入。"%[plan_name,"可建造" if q.ok else _engineering_reason(str(q.reason_code)),state.completed,pending]
	if refresh_hand:
		_engineering_hand.clear()
		for card: CardData in context.player.hand:
			if card.card_id in Engineering.TYPES:
				_engineering_hand.add_item(card.get_display_name());_engineering_hand.set_item_metadata(_engineering_hand.item_count-1,card.get_instance_id())
		if _engineering_hand.item_count==0:_engineering_hand.add_item("手中没有可整备的冷却/围护建筑牌");_engineering_hand.set_item_metadata(0,0)

func _engineering_reason(reason: String) -> String:
	return {"already_built_this_turn":"本回合已安排施工","no_engineering_plan":"先等待计划或整备手牌","engineering_slot_occupied":"工程位已有计划，先安排当前工程","engineering_cell_reserved":"已有付费计划预订此格","insufficient_heat":"当前热量不足","insufficient_command_points":"当前指令不足","frontline_support_required":"此格需要前线支持","structure_cell_occupied_by_core":"此格已有建筑","structure_cell_occupied_by_unit":"此格有单位","engineering_quote_stale":"局面已变化，请重新查看费用","payment_backlash_boundary":"这次投入会触发反噬，原型暂不开放","engineering_total_cap":"本场工程预算已用完","not_player_turn":"等待己方回合","battle_ended":"战斗已结束","resolution_busy":"等待当前行动完成","backlash_restricted":"反噬期间无法施工"}.get(reason,"当前位置或施工条件不满足")

func _preview_engineering(rush: bool) -> void:
	_engineering_quote=engineering.inspect(_selected_engineering_cell(),rush,_engineering_edge())
	_engineering_confirm.get_ok_button().disabled=not _engineering_quote.ok
	_engineering_confirm.dialog_text=("支付%d指令%s。\n%s\n工程位施工不视为手牌出牌，不推进连锁。\n预订位置之后若受阻，将保留已付费计划等待重试。"%[_engineering_quote.command_cost,"和%d热"%_engineering_quote.heat_cost if rush else "","本回合尝试完工。" if rush else "下个己方回合尝试完工。"] if _engineering_quote.ok else _engineering_reason(str(_engineering_quote.reason_code)))
	_engineering_confirm.popup_centered()

func _commit_engineering() -> void:
	if not _engineering_quote.get("ok",false):return
	var result: Dictionary=engineering.execute(_engineering_quote.cell,_engineering_quote.rush,_engineering_quote,_engineering_quote.edge)
	if result.ok:_refresh_tables();_play_command_economy_spend(int(result.command_cost))
	_engineering_quote={};print("[ENGINEERING_ORDER] ",JSON.stringify(result));_refresh_engineering()
	if not result.ok:_engineering_text.text=_engineering_reason(str(result.reason_code))+"\n"+_engineering_text.text

func _stage_engineering_hand() -> void:
	var uid: int=int(_engineering_hand.get_selected_metadata())
	for card: CardData in context.player.hand:
		if card.get_instance_id()==uid:
			var result: Dictionary=engineering.stage(card)
			if result.ok:player_table.refresh()
			_refresh_engineering()
			if not result.ok:_engineering_text.text=_engineering_reason(str(result.reason_code))+"\n"+_engineering_text.text
			return

func _process(delta: float) -> void:
	super._process(delta)
	_engineering_frame+=1
	if _engineering_frame%15==0 and is_instance_valid(_engineering_window) and _engineering_window.visible:_refresh_engineering(false)

func restart_gb1_battle() -> void:
	if _gb1_restarting:return
	_gb1_restarting=true
	var err:=get_tree().change_scene_to_file("res://scenes/experiments/phase100_engineering_book_trial.tscn")
	if err!=OK:_gb1_restarting=false;push_error("Engineering trial restart failed: %d"%err)
