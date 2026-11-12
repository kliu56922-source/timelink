extends "res://scenes/experiments/phase104_integrated_engineering_trial.gd"
const TimingAdvisor := preload("res://battle/analysis/construction_timing_advisor.gd")
var timing_advisor: RefCounted
var _facility_window: Window
var _facility_sources: OptionButton
var _facility_next_cost: OptionButton
var _facility_text: Label
var _facility_confirm: ConfirmationDialog
var _facility_pending_quote: Dictionary={}
var _facility_running:=false
var last_facility_receipt: Dictionary={}
var facility_receipts: Array[Dictionary]=[]

func _setup_game() -> void:
	super._setup_game()
	timing_advisor=TimingAdvisor.new(self,engineering)
	call_deferred("_build_facility_controls")

func _build_engineering_controls() -> void:
	super._build_engineering_controls()
	_engineering_window.size=Vector2i(590,590)
	var body: VBoxContainer=_engineering_text.get_parent()
	var access:=Button.new();access.name="FinishedFacilityAccess";access.text="已完工设施 · 查看 / 使用";body.add_child(access);body.move_child(access,body.get_child_count()-2);access.pressed.connect(_open_facilities)
	var hint:=Label.new();hint.text="先完成卡牌/OD/单位动作，再考虑余下指令；建议保留一个建筑名额。";hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;hint.add_theme_font_size_override("font_size",14);body.add_child(hint);body.move_child(hint,1)

func _build_facility_controls() -> void:
	_facility_window=Window.new();_facility_window.name="FinishedFacilityWindow";_facility_window.visible=false;_facility_window.title="已完工设施 · 原生能力";_facility_window.size=Vector2i(560,360);_facility_window.transient=true;_facility_window.exclusive=true;add_child(_facility_window)
	_facility_window.close_requested.connect(func():
		if not _facility_running:_facility_window.hide())
	var body:=VBoxContainer.new();body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);body.offset_left=16;body.offset_right=-16;body.offset_top=14;body.offset_bottom=-14;_facility_window.add_child(body)
	_facility_sources=OptionButton.new();_facility_sources.name="ActualCompletedSources";body.add_child(_facility_sources)
	_facility_next_cost=OptionButton.new();_facility_next_cost.name="KnownNextCommandCost";body.add_child(_facility_next_cost)
	for amount: int in range(7):_facility_next_cost.add_item("待执行动作费用：%d指令%s"%[amount,"（未知/仅看状态）" if amount==0 else ""])
	_facility_text=Label.new();_facility_text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;_facility_text.custom_minimum_size=Vector2(520,160);body.add_child(_facility_text)
	var use:=Button.new();use.name="PreviewNativeFacility";use.text="查看真实费用并确认使用";body.add_child(use);use.pressed.connect(_preview_facility)
	var close:=Button.new();close.text="返回战场";body.add_child(close);close.pressed.connect(func():
		if not _facility_running:_facility_window.hide())
	for picker: OptionButton in [_facility_sources,_facility_next_cost]:picker.item_selected.connect(func(_i):_refresh_facility_text())
	_facility_confirm=ConfirmationDialog.new();_facility_confirm.name="ConfirmActualFacility";_facility_confirm.title="确认使用已有设施";_facility_confirm.ok_button_text="按原费用使用";_facility_confirm.cancel_button_text="取消";_facility_confirm.min_size=Vector2i(480,220);_facility_window.add_child(_facility_confirm)
	_facility_confirm.confirmed.connect(_commit_facility);_facility_confirm.canceled.connect(func():_facility_pending_quote={})

func _open_facilities() -> void:
	if not is_instance_valid(_facility_window):return
	if timing_advisor._guard()!="":return
	_engineering_window.hide();_refresh_facilities();_facility_window.popup_centered()

func _facility_card(uid: int) -> CardData:
	for card: CardData in context.player.traps:
		if card.get_instance_id()==uid:return card
	return null

func _refresh_facilities() -> void:
	if not is_instance_valid(_facility_sources):return
	var selected:=int(_facility_sources.get_selected_metadata()) if _facility_sources.item_count>0 else 0
	_facility_sources.clear()
	for card: CardData in context.player.traps:
		if card.card_id not in ["P13","P16"] or card.has_meta("engineering_site_tx") or battle.get_building_state(card).is_empty():continue
		var id: StringName=context.tactical_structure_board_state.get_source_structure_id(card.get_instance_id())
		var body: Dictionary=context.tactical_structure_board_state.get_foundation_status(id)
		if body.is_empty() or body.owner_side!=&"player" or int(body.integrity_current)<=0:continue
		_facility_sources.add_item("%s · 第%d列第%d行"%[card.get_display_name(),body.cell.x+1,body.cell.y+1]);_facility_sources.set_item_metadata(_facility_sources.item_count-1,card.get_instance_id())
		if card.get_instance_id()==selected:_facility_sources.select(_facility_sources.item_count-1)
	if _facility_sources.item_count==0:_facility_sources.add_item("暂无已完工的冷却/围护设施");_facility_sources.set_item_metadata(0,0)
	_refresh_facility_text()

func _facility_quote() -> Dictionary:
	var uid:=int(_facility_sources.get_selected_metadata())
	return timing_advisor.inspect_facility(_facility_card(uid),_facility_next_cost.selected)

func _refresh_facility_text() -> void:
	if not is_instance_valid(_facility_text):return
	var q:=_facility_quote()
	if not q.ok:_facility_text.text=_facility_reason(str(q.reason_code));return
	_facility_text.text="%s · %s\n本回合一次；费用：%s。\n%s\n当前热量%d，冷却/封压充能%d/%d。\n设施使用不算出牌，不赠连锁或长期点。"%[q.native.preview,"可使用",q.native.cost,_facility_reason(str(q.advice_code)),q.heat_before,q.state.charge,q.state.charge_max]

func _preview_facility() -> void:
	if _facility_running:return
	_facility_pending_quote=_facility_quote()
	_facility_confirm.get_ok_button().disabled=not _facility_pending_quote.ok
	var q:=_facility_pending_quote
	_facility_confirm.dialog_text=("%s\n费用：%s；本回合一次。\n%s\n确认时会重新核对同一设施、回合与资源。"%[q.native.preview,q.native.cost,_facility_reason(str(q.advice_code))] if q.ok else _facility_reason(str(q.reason_code)))
	_facility_confirm.popup_centered()

func _capture_facility_state(card: CardData) -> Dictionary:
	return {"turn":context.turn_count,"source_runtime_id":card.get_instance_id(),"heat":context.od_mode.current_od,"pending_depth_reduction":context.pending_depth_reduction,"depth":context.depth_pressure,"shield":context.player.shield,"state":battle.get_building_state(card).duplicate(true),"economy":battle.get_command_economy_snapshot("player"),"cards_played":context.cards_played_this_turn,"chain":context.chain_system.get_tactical_chain_snapshot().duplicate(true),"long_points":context.od_mode.engine_total_points}

func _commit_facility() -> void:
	if _facility_running:return
	_facility_confirm.hide()
	var expected:=_facility_pending_quote;_facility_pending_quote={}
	if not expected.get("ok",false):last_facility_receipt={"ok":false,"reason_code":"no_facility_quote"};return
	var current:=_facility_quote()
	if not current.ok or current!=expected:last_facility_receipt={"ok":false,"reason_code":"facility_quote_stale"};_refresh_facilities();return
	var card:=_facility_card(int(expected.source_runtime_id))
	var before:=_capture_facility_state(card)
	_facility_running=true
	await _on_building_interact(card)
	var after:=_capture_facility_state(card)
	_facility_running=false
	var committed: bool=not before.state.get("used_this_turn",true) and after.state.get("used_this_turn",false)
	last_facility_receipt={"ok":committed,"reason_code":"facility_used" if committed else "native_facility_not_committed","source_runtime_id":card.get_instance_id(),"card_id":card.card_id,"turn":before.turn,"quote":expected,"before":before,"after":after}
	if committed:facility_receipts.append(last_facility_receipt.duplicate(true))
	print("[TIMED_FACILITY_USED] ",JSON.stringify(last_facility_receipt));_refresh_facilities()

func _facility_reason(code: String) -> String:
	return {"facility_source_unavailable":"没有可用的完工设施；工地或已离场来源不能发动。","building_interface_used":"本回合已使用，等待下一己方回合。","not_player_turn":"等待己方回合。","battle_ended":"战斗已经结束。","resolution_busy":"等待当前行动完成。","building_interface_requirements":"当前热量/设施充能不足。","structure_interface_paused_undermined":"地基失稳，主动能力暂停。","facility_breaks_od_readiness":"建议先考虑OD：此次会使热量跌破当前OD门槛。","prepare_known_depth_crossing":"下一动作将跨Depth阈值，可先准备减免。","next_action_unaffordable":"当前指令不足以支付这项动作，暂不为它预备减免。","depth_guard_already_prepared":"已有足够Depth减免，暂不必重复准备。","shield_for_current_pressure":"当前护盾偏低且已有压力，可先补防护。","no_current_facility_need":"当前没有明确需求，可保留本回合使用机会。","finish_combat_actions_first":"先完成手牌、OD与单位动作，再看剩余指令。","reserve_existing_building_route":"建议保留一个建筑名额给原地基—堡垒路线。","rush_breaks_od_readiness":"急筑会跌破当前OD门槛，建议先考虑OD。","current_od_opportunity_first":"当前已有可用OD来源，建议先处理OD。","remaining_command_construction":"动作完成后，可用剩余指令安排施工。"}.get(code,"当前位置或使用条件不满足。")

func _preview_engineering(rush: bool) -> void:
	super._preview_engineering(rush)
	if timing_advisor==null or not _engineering_quote.get("ok",false):return
	var advice: Dictionary=timing_advisor.inspect_build(_engineering_quote.cell,rush,_engineering_quote.edge,false)
	_engineering_confirm.dialog_text+="\n时机提醒："+_facility_reason(str(advice.advice_code))
	for warning: String in advice.get("warnings",[]):
		if warning!=str(advice.advice_code):_engineering_confirm.dialog_text+="\n"+_facility_reason(warning)

func _on_end_turn() -> void:
	if _facility_running:return
	await super._on_end_turn()

func restart_gb1_battle() -> void:
	if _gb1_restarting or _facility_running:return
	_gb1_restarting=true
	var err:=get_tree().change_scene_to_file("res://scenes/experiments/phase105_timing_facility_trial.tscn")
	if err!=OK:_gb1_restarting=false;push_error("Timing facility restart failed: %d"%err)
