extends "res://scenes/playtest/phase164_interaction_repairs.gd"
var ready165:=false
var advance165: Node
var advance_panel165: CanvasLayer
var _advance_nav165:=""
var _move_visual165: Dictionary={}
var _move_animating165:=false
func _sync_3d_field_tokens() -> void:
	# Deferred native HUD refreshes may reposition roots; the current tween owns this visual only.
	var token: Node3D=_move_visual165.token.get_ref() if _move_animating165 and not _move_visual165.is_empty() else null
	var visual: Transform3D=token.transform if is_instance_valid(token) else Transform3D.IDENTITY
	super._sync_3d_field_tokens()
	if is_instance_valid(token) and _move_animating165:token.transform=visual
func _create_battle_system() -> BattleSystem:return preload("res://core/battle/advance_weakpoint_battle_system.gd").new()
func _ready() -> void:
	await super._ready()
	advance165=preload("res://battle/analysis/advance_weakpoint_runner.gd").new();advance165.name="AdvanceWeakpoint165A";add_child(advance165);advance165.setup(self)
	advance_panel165=preload("res://ui/advance_weakpoint_panel.gd").new();add_child(advance_panel165);advance_panel165.setup(self)
	get_node("IntegratedPlaytestTools").guide_window.dialog_text+="\n\n165A：点棋子或左上来源按钮→要害→必要时选路线→确认，连续最多两次原生移动和一次要害攻击。Esc停止后续，已付款保留。多个路线不替你选择，不自动清守卫/OD/结束回合。"
	ready165=true
func _refresh_weakpoint162a() -> void:
	super._refresh_weakpoint162a()
	if is_instance_valid(weakpoint_label) and weakpoint_label.text.begins_with("164 "):weakpoint_label.text="165A "+weakpoint_label.text.substr(4)
func advance165_commit(step: Dictionary) -> Dictionary:
	var actor: CardData=advance165.resolve(step.actor_uid)
	if actor==null:return {"ok":false,"reason":"来源失效"}
	_move_visual165.clear()
	var before_token: Node3D=_get_3d_token_for_card(actor)
	var before_transform: Transform3D=before_token.global_transform if is_instance_valid(before_token) else Transform3D.IDENTITY
	var receipt: Dictionary=battle.execute_unit_command(actor,"move",step.cell) if step.kind=="move" else battle.execute_weakpoint_attack(actor,step.part_id)
	if receipt.get("ok",false):
		_play_command_economy_spend(int(receipt.cost));_refresh_tables();_refresh_weakpoint162a()
		if step.kind=="move":
			var token: Node3D=_get_3d_token_for_card(actor)
			if is_instance_valid(token):_move_visual165={"token":weakref(token),"from":token.get_parent_node_3d().global_transform.affine_inverse()*before_transform,"to":token.transform}
		if _playtest:_playtest.record_event("advance165_"+step.kind,{"cost":receipt.cost,"source":actor.card_id,"part":step.part_id})
		if step.kind=="part":
			if action_feed:action_feed.push_message(receipt.message,TC.ACCENT_GOLD,"",2.0)
			_show_floating_text(receipt.message,TC.ACCENT_GOLD,1.8,18);check_battle_end()
	return receipt
func advance165_present(step: Dictionary,receipt: Dictionary) -> void:
	var facts: Dictionary=receipt.duplicate(true);facts.status=&"committed"
	if step.kind=="move":
		facts["duration"]=0.18;facts["path_cells"]=[receipt.from_cell,receipt.to_cell]
	else:
		# Reuse the physical Boss lunge only; this copy cannot alter native part damage.
		facts["result"]="hit_core";facts["damage"]=int(receipt.get("actual_hp_loss",0))
	await _play_monster_presentation(&"move" if step.kind=="move" else &"attack",facts)
	if step.kind=="move" and not _move_visual165.is_empty():
		var token: Node3D=_move_visual165.token.get_ref()
		if is_instance_valid(token) and is_instance_valid(_tactical_presenter):
			_move_animating165=true
			token.transform=_move_visual165.from
			_tactical_presenter.play_move(token,_move_visual165.from,_move_visual165.to,0.18)
			var visual_tween: Tween=_tactical_presenter.get("_tween")
			var completed: Array[bool]=[false]
			if visual_tween!=null and visual_tween.is_valid():visual_tween.finished.connect(func():completed[0]=true,CONNECT_ONE_SHOT)
			var deadline:=Time.get_ticks_msec()+2000
			while Time.get_ticks_msec()<deadline:
				if not is_instance_valid(token) or visual_tween==null or not visual_tween.is_valid() or not visual_tween.is_running():break
				await get_tree().process_frame
			_move_animating165=false
			if not completed[0] or not is_instance_valid(token):
				if visual_tween!=null and visual_tween.is_valid():visual_tween.kill()
				if is_instance_valid(token):token.transform=_move_visual165.to
				else:_refresh_tables()
				advance165.stop("移动演出中断，后续未执行")
	_move_visual165.clear()
	for i in range(600):
		if battle_ended or axis155_native_ready():return
		await get_tree().process_frame
func advance165_finished() -> void:
	if not _advance_nav165.is_empty():
		var nav:=_advance_nav165;_advance_nav165="";axis155_navigate(nav)
func axis155_navigate(nav: String) -> void:
	if not ready165:return
	if is_instance_valid(advance165) and advance165.running:_advance_nav165=nav;advance165.stop("重开" if nav=="restart" else "返回");return
	if is_instance_valid(axis155) and axis155.running:_axis155_navigation=nav;axis155.stop("navigation");return
	if nav not in ["restart","home"] or _gb1_restarting or not axis155_native_ready():return
	advance165.stop("navigation");axis155.stop("navigation");_gb1_restarting=true
	if nav=="home":_cleanup_structure_presentation_lifecycle(&"return_to_menu");_cancel_monster_summon_interaction(&"return_to_menu")
	var err:=get_tree().change_scene_to_file("res://scenes/playtest/phase165a_advance_weakpoint.tscn" if nav=="restart" else "res://scenes/menu/demo_home.tscn")
	if err!=OK:_gb1_restarting=false;push_error("165A navigation failed")
func _input(event: InputEvent) -> void:
	if _exit_modal_active:return
	if is_instance_valid(advance_panel165) and event is InputEventMouse and advance_panel165.owns_pointer(event.position):return
	if is_instance_valid(advance165) and advance165.running:
		if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_ESCAPE:advance165.stop()
		get_viewport().set_input_as_handled();return
	if is_instance_valid(advance_panel165) and advance_panel165.panel.visible and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_ESCAPE:advance_panel165.dismiss();get_viewport().set_input_as_handled();return
		if event.keycode==KEY_ENTER:advance_panel165.submit();get_viewport().set_input_as_handled();return
	super._input(event)
func _on_card_clicked(card_ui: CardUI) -> void:
	if is_instance_valid(advance165) and advance165.running:return
	if is_instance_valid(advance_panel165):advance_panel165.dismiss()
	await super._on_card_clicked(card_ui)
func _on_end_turn() -> void:
	if is_instance_valid(advance165) and advance165.running:return
	if is_instance_valid(advance_panel165):advance_panel165.dismiss()
	await super._on_end_turn()
func _on_building_interact(card: CardData) -> void:
	if is_instance_valid(advance165) and advance165.running:return
	await super._on_building_interact(card)
func _open_monster_command_menu(card: CardData) -> void:
	if is_instance_valid(advance165) and advance165.running:return
	if ready165 and is_instance_valid(advance_panel165):advance_panel165.open_actor(card);return
	super._open_monster_command_menu(card)
func advance165_manual(card: CardData) -> void:super._open_monster_command_menu(card)
