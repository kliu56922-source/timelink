extends "res://scenes/playtest/phase166d_integrated.gd"
const Clarity167A=preload("res://battle/analysis/operation_clarity_167a.gd")
var ready167a:=false
var building_preview167a: ConfirmationDialog
var building_uid167a:=0
var building_quote167a: Dictionary={}
var building_committing167a:=false
var _building_empty_tutor167a:=""
func _create_battle_system() -> BattleSystem:return preload("res://core/battle/operation_clarity_battle_167a.gd").new()
func _ready() -> void:
	await super._ready()
	var telemetry167a:=preload("res://core/debug/playtest_telemetry_167a.gd").new()
	telemetry167a.adopt167a(_playtest,context);_playtest=telemetry167a
	# Preserve the runner object and its existing signal connections. No plan exists at startup.
	advance165.set_script(preload("res://battle/analysis/advance_runner_167a.gd"));advance165.setup(self)
	get_node("CurrentActionPanel").analyzer=preload("res://battle/analysis/action_opportunities_167a.gd").new()
	flow166d.body_button.free();flow166d.free()
	flow166d=preload("res://ui/encounter_flow_167a.gd").new();add_child(flow166d);flow166d.setup(self)
	building_preview167a=ConfirmationDialog.new();building_preview167a.title="建筑效果预览 · 确认才付款"
	building_preview167a.ok_button_text="确认发动";building_preview167a.cancel_button_text="取消 · 不付款";building_preview167a.exclusive=true
	building_preview167a.dialog_hide_on_ok=false
	add_child(building_preview167a)
	building_preview167a.confirmed.connect(_confirm_building167a)
	building_preview167a.canceled.connect(func():building_uid167a=0;building_quote167a={})
	battle.boss_card_committed167a.connect(func(card):
		if _playtest!=null:_playtest.record_event("boss_card_played",{"card":card.card_name,"card_id":card.card_id,"source_kind":"native_boss_commit"}))
	get_node("IntegratedPlaytestTools").guide_window.dialog_text+="\n167A：点建筑先显示费用和实际效果，确认才发动；取消不付款。本体就绪和限制沿用原生攻核查询。结算总出牌含已消耗关键牌，不含独立衍生牌；Depth记录局内峰值。"
	ready167a=true
func _process(delta: float) -> void:
	super._process(delta)
	_sync_card_stats167a()
func _sync_card_stats167a() -> void:
	if _playtest==null:return
	if _playtest.has_method("observe_cards167a"):_playtest.observe_cards167a()
	_stat_total_cards=_playtest.total_cards_played
func _on_depth_changed(new_depth: int,depth_zone: String) -> void:
	if _playtest!=null:_playtest.max_depth=maxi(_playtest.max_depth,new_depth)
	super._on_depth_changed(new_depth,depth_zone)
func _end_battle(victory: bool) -> void:
	_sync_card_stats167a()
	if _playtest!=null:
		_stat_total_cards=_playtest.total_cards_played
		_playtest.max_depth=maxi(_playtest.max_depth,context.depth_pressure)
	if is_instance_valid(building_preview167a):building_preview167a.hide();building_uid167a=0
	super._end_battle(victory)
	if _playtest!=null and is_instance_valid(result_panel):
		result_panel.info_label.text+="\n己方%d回合（含部署） · 出牌%d · Depth峰值%d · Boss出牌%d"%[battle.opening166b.player_round,_playtest.total_cards_played,_playtest.max_depth,_playtest.boss_cards_played]
func _on_boss_instant_card_played(card) -> void:
	# Preserve optional legacy visuals; committed cards are counted by BattleSystem.
	if card==null:return
	_play_boss_action_vfx("instant")
	var am = _am()
	if am:am.play_boss_action()
	await _play_boss_instant_card_visual(card)
func _building_preview_open167a() -> bool:return is_instance_valid(building_preview167a) and building_preview167a.visible
func axis155_native_ready() -> bool:
	return not _building_preview_open167a() and not building_committing167a and super.axis155_native_ready()
func integrated_navigation_ready() -> bool:
	return not _building_preview_open167a() and not building_committing167a and super.integrated_navigation_ready()
func _input(event: InputEvent) -> void:
	if _building_preview_open167a():return
	super._input(event)
func _on_end_turn() -> void:
	if _building_preview_open167a() or building_committing167a:return
	_sync_card_stats167a()
	await super._on_end_turn()
func _on_card_clicked(card_ui: CardUI) -> void:
	if _building_preview_open167a() or building_committing167a:return
	await super._on_card_clicked(card_ui)
func _on_building_interact(card: CardData) -> void:
	# The facilities window has already previewed, revalidated and confirmed.
	# Its own execution lock must not be mistaken for an unrelated busy action.
	if ready167a and _facility_running and not building_committing167a and not _building_preview_open167a() and not _exit_modal_active and not battle_ended:
		await super._on_building_interact(card)
		return
	if not ready167a or _building_preview_open167a() or building_committing167a or not axis155_native_ready() or _exit_modal_active:return
	if not recipe166._gate().is_empty() or not is_instance_valid(card) or card not in context.player.traps:return
	var q:=Clarity167A.building_status(self,card)
	building_quote167a=q.signature.duplicate(true)
	building_uid167a=card.get_instance_id();building_preview167a.dialog_text=card.get_display_name()+"\n\n"+q.text+"\n\n预览不付款；取消保留资源。"
	building_preview167a.get_ok_button().disabled=not q.ok
	building_preview167a.popup_centered(Vector2i(540,240))
func _confirm_building167a() -> void:
	var uid:=building_uid167a;var expected:=building_quote167a.duplicate(true)
	building_uid167a=0;building_quote167a={};building_preview167a.hide()
	if uid==0 or building_committing167a or not axis155_native_ready() or _exit_modal_active or not recipe166._gate().is_empty():return
	var card: CardData
	for c: CardData in context.player.traps:
		if c.get_instance_id()==uid:card=c;break
	if card==null:return
	var q:=Clarity167A.building_status(self,card)
	if not q.ok:
		if action_feed:action_feed.push_message("建筑条件已变化："+str(q.text),TC.WARNING)
		return
	if q.signature!=expected:
		_on_building_interact(card)
		building_preview167a.dialog_text="条件有变化，请核对后重新确认。\n"+building_preview167a.dialog_text
		return
	building_committing167a=true
	_building_empty_tutor167a=card.get_display_name() if card.card_id=="P05" and card.tutor_enabled and card.tutor_timing=="on_building_activate" and battle.find_cards_in_deck(battle._card_tutor_criteria(card)).is_empty() else ""
	await super._on_building_interact(card)
	_building_empty_tutor167a="";building_committing167a=false
func _on_tutor_failed(source_card_name: String,reason: String) -> void:
	if building_committing167a and not _building_empty_tutor167a.is_empty() and source_card_name==_building_empty_tutor167a:
		if action_feed:action_feed.push_message("建筑效果已结算；附带检索：牌库没有匹配牌，本次未取得卡牌。",TC.TEXT_SECONDARY)
		return
	super._on_tutor_failed(source_card_name,reason)
func axis155_navigate(nav: String) -> void:
	if not ready167a:return
	if nav not in ["restart","home"]:return
	if building_committing167a:return
	if _building_preview_open167a():building_preview167a.hide();building_uid167a=0
	if body_busy166d or transition166d:_nav166d=nav;return
	if support166c.running:_support_nav166c=nav;support166c.skip();return
	if recipe166.running:_recipe_nav166=nav;recipe166.skip();return
	if advance165.running:_advance_nav165=nav;advance165.stop("导航");return
	if axis155.running:_axis155_navigation=nav;axis155.stop("导航");return
	if _gb1_restarting or not axis155_native_ready():return
	support_panel166c.dismiss();recipe_panel166.dismiss();advance_panel165.dismiss();advance165.stop("navigation");axis155.stop("navigation");_gb1_restarting=true
	if nav=="home":_cleanup_structure_presentation_lifecycle(&"return_to_menu");_cancel_monster_summon_interaction(&"return_to_menu")
	var destination: String="res://scenes/playtest/phase167a_operation_clarity.tscn" if nav=="restart" else "res://scenes/menu/demo_home.tscn"
	var error:=get_tree().change_scene_to_file(destination)
	if error!=OK:_gb1_restarting=false;push_error("167A navigation failed")
