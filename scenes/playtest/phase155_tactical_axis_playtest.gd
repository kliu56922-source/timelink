extends "res://scenes/playtest/preart_engineering_playtest.gd"
const AXIS155_PATH="res://scenes/playtest/phase155_tactical_axis_playtest.tscn"
var axis155: Node
var axis155_panel: CanvasLayer
var _axis155_navigation := ""
func _gb1_prepare_startup() -> void:
	super._gb1_prepare_startup()
	# Explicit greybox opening order only: same 19 identities, no created/free card.
	var index:=-1
	for i in range(_gb1_selected_cards.size()):
		if _gb1_selected_cards[i].card_id=="P05":index=i;break
	if index>=6:
		var original: CardData=_gb1_selected_cards[5]
		_gb1_selected_cards[5]=_gb1_selected_cards[index]
		_gb1_selected_cards[index]=original
func _ready() -> void:
	await super._ready()
	axis155=preload("res://battle/analysis/tactical_axis_runner.gd").new();axis155.name="TacticalAxis155";add_child(axis155);axis155.setup(self)
	axis155_panel=preload("res://ui/tactical_axis_panel.gd").new();add_child(axis155_panel);axis155_panel.setup(self)
func axis155_native_ready() -> bool:return super.integrated_navigation_ready()
func axis155_sequence_finished() -> void:
	if not _axis155_navigation.is_empty():
		var nav:=_axis155_navigation;_axis155_navigation="";axis155_navigate(nav)
func axis155_navigate(nav: String) -> void:
	if nav not in ["home","restart"]:return
	if is_instance_valid(axis155) and axis155.running:
		_axis155_navigation=nav;axis155.stop("返回" if nav=="home" else "重开");return
	if not axis155_native_ready():return
	if is_instance_valid(axis155):axis155.stop("navigation")
	if nav=="home":super.return_to_integrated_menu()
	else:
		_gb1_restarting=true
		var err:=get_tree().change_scene_to_file(AXIS155_PATH)
		if err!=OK:_gb1_restarting=false;push_error("155 restart failed")
func return_to_integrated_menu() -> void:axis155_navigate("home")
func restart_gb1_battle() -> void:axis155_navigate("restart")
func _input(event: InputEvent) -> void:
	if is_instance_valid(axis155) and axis155.running:
		if event is InputEventKey:
			if event.pressed and event.keycode==KEY_ESCAPE:axis155.stop()
			get_viewport().set_input_as_handled()
		return
	if is_instance_valid(axis155_panel) and axis155_panel.panel.visible and event is InputEventMouse and axis155_panel.panel.get_global_rect().has_point(event.position):return
	super._input(event)
func _get_structure_reserved_ui_rects() -> Array[Rect2]:
	var rects: Array[Rect2]=super._get_structure_reserved_ui_rects()
	if is_instance_valid(axis155_panel) and axis155_panel.panel.visible:rects.append(axis155_panel.panel.get_global_rect())
	return rects
func _on_end_turn() -> void:
	if is_instance_valid(axis155) and axis155.running:return
	await super._on_end_turn()
func _on_card_clicked(card_ui: CardUI) -> void:
	if is_instance_valid(axis155) and axis155.running:return
	await super._on_card_clicked(card_ui)
func _on_building_interact(card: CardData) -> void:
	if is_instance_valid(axis155) and axis155.running:return
	await super._on_building_interact(card)
func axis155_commit(step: Dictionary) -> Dictionary:
	var card: CardData=axis155.resolve(step.uid,step.zone)
	if card==null:return {"ok":false,"reason":"来源失效"}
	var r: Dictionary={}
	match step.kind:
		"build":
			await super._on_card_clicked(_live_hand_ui(card))
			_confirm_piece_anchor({"type":&"cell","cell":step.cell})
			_choose_piece_play_payment(false,&"none")
			r=_confirm_pending_structure_build()
		"summon":r=await _commit_monster_summon(_live_hand_ui(card),card,step.cell,&"click")
		"facility":
			var before: Dictionary=battle.get_building_state(card).duplicate(true)
			await super._on_building_interact(card)
			r={"ok":not before.get("used_this_turn",true) and battle.get_building_state(card).get("used_this_turn",false)}
		"move":
			_lane_selection_card=card
			await _confirm_move_cell(step.cell)
			r={"ok":battle.get_unit_cell(card)==step.cell}
		"attack":
			var before: int=int(battle.get_command_economy_snapshot("player").get("gross_spent",0))
			_lane_selection_card=card
			await _confirm_attack_on_cell(step.cell)
			r={"ok":int(battle.get_command_economy_snapshot("player").get("gross_spent",0))>before}
	for frame in range(600):
		if axis155_native_ready():break
		await get_tree().process_frame
	return r
