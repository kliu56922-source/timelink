extends "res://scenes/experiments/gb3l_basic_resources.gd"
## Five basic actions, opt-in deck; reuse the shared drag/confirmation lifecycle.
const COMBINATIONS_ENTRY := "res://scenes/experiments/gb3m_basic_combinations.tscn"
const COMBINATIONS_ORDER: Array[String] = ["B04","S01","B01","B02","B03","P05","S02","P07","B01","P08","B02","P02","B03","P10","B05","P03","S03","P11","R01"]
const BASIC_TARGET_INTENT := &"basic_unit_target"
var _relation_coach_panel: Control
func _gb1_prepare_startup() -> void:
	super._gb1_prepare_startup()
	if not _gb1_startup_ok: return
	for id in ["B01","B02","B03"]:
		if not _gb1_cards_by_id.has(id):
			_gb1_load_problems.append("基础牌缺失："+id);_gb1_startup_ok=false;return
	_gb1_selected_cards.clear()
	var seen: Array[String]=[]
	for id in COMBINATIONS_ORDER:
		var card: CardData=_gb1_cards_by_id[id]
		var selected: CardData=CardData.clone_card_entity(card) if id in seen else card
		if selected != card:_gb1_owned_cards.append(selected)
		_gb1_selected_cards.append(selected)
		seen.append(id)
func _ready() -> void:
	await super._ready()
	if not _gb1_startup_ok: return
	_expansion_guide._button.text="基础组合 · 查看用途"
	_expansion_guide._dialog.title="先解决场面，再组合体系"
	_relation_coach_panel=preload("res://ui/live_play_coach_panel.gd").new()
	_relation_coach_panel.name="CardRelations"
	_relation_coach_panel.scene_ref=weakref(self)
	_relation_coach_panel.mode=&"related"
	_relation_coach_panel.teaching_allowed=false
	_relation_coach_panel.advisor=preload("res://battle/analysis/od_current_window_relation_advisor.gd").new()
	add_child(_relation_coach_panel)
func _get_structure_reserved_ui_rects() -> Array[Rect2]:
	var rects: Array[Rect2]=super._get_structure_reserved_ui_rects()
	if is_instance_valid(_relation_coach_panel):rects.append(_relation_coach_panel.reserved_rect())
	return rects
func _build_expansion_route_view() -> Dictionary:
	var view := super._build_expansion_route_view()
	var inherited_text := str(view.text)
	var separator := inherited_text.find("\n\n")
	var axis_text := inherited_text.substr(separator+2) if separator>=0 else ""
	view.text="打击：付1热，选敌方棋子打2；清残血守卫。\n赋刃：付1热，选己方棋子，下次普通攻击伤害+2。\n护卫：付1热，选己方棋子，下次棋子交战减伤2。\n蓄火：获得2热；排压：付1热，Depth减2。\n每种同名每回合一次。点击或拖拽定向牌，看棋子绿色标记，再确认。\n\n进攻：清守卫→强化已就位的棋子→正常攻击。\n防守：护卫保住棋子→次回合正常推进或驻军。\n赋刃不送行动或范围；拆墙与技能不消耗它。护卫不挡Boss法术。\n\n"+axis_text
	return view
func restart_gb1_battle() -> void:
	if _gb1_restarting: return
	_gb1_restarting=true
	if battle!=null and battle.reaction_trial!=null: battle.reaction_trial.finish_event()
	var err := get_tree().change_scene_to_file(COMBINATIONS_ENTRY)
	if err!=OK: _gb1_restarting=false;push_error("Basic combinations restart failed: %d" % err)
func _is_basic_target_card(card: CardData) -> bool:
	return card!=null and card.card_id in ["B01","B02","B03"]
func _classify_board_drag_intent(card: CardData) -> StringName:
	return BASIC_TARGET_INTENT if _is_basic_target_card(card) else super._classify_board_drag_intent(card)
func _is_card_cast_drag_intent(intent: StringName) -> bool:
	return intent==BASIC_TARGET_INTENT or super._is_card_cast_drag_intent(intent)
func _begin_basic_target(card_ui: CardUI, origin: StringName) -> bool:
	if battle_ended or _card_being_played or not is_instance_valid(card_ui): return false
	var card := card_ui.card_data
	if not _is_basic_target_card(card) or _has_non_presentation_end_turn_busy(card) or _presentation_end_turn_blocked: return false
	if not battle.can_play_card(card): _show_unplayable_reason(card);return false
	if _is_monster_summon_interaction_active():
		if _monster_drag_session.get("card")!=card: _cleanup_monster_drag_summon(&"card_switch")
		elif _monster_summon_state()==MONSTER_SUMMON_PENDING_CONFIRM: return false
		else:
			_monster_drag_session.state=MONSTER_SUMMON_DRAGGING if origin==&"drag" else MONSTER_SUMMON_RESELECTING
			_monster_drag_session.origin=origin
			_monster_summon_drop_target.set_board_drag_active(origin==&"drag",BASIC_TARGET_INTENT)
			_refresh_card_target_guidance();return true
	if not _start_card_cast_drag_session(card_ui,card,BASIC_TARGET_INTENT): return false
	_monster_drag_session.origin=origin
	_monster_drag_session.state=MONSTER_SUMMON_DRAGGING if origin==&"drag" else MONSTER_SUMMON_RESELECTING
	_monster_summon_drop_target.set_board_drag_active(origin==&"drag",BASIC_TARGET_INTENT)
	_refresh_card_target_guidance();return true
func _on_card_clicked(card_ui: CardUI) -> void:
	if is_instance_valid(card_ui) and _is_basic_target_card(card_ui.card_data): _begin_basic_target(card_ui,&"click");return
	if _monster_drag_session.get("intent")==BASIC_TARGET_INTENT: _cleanup_monster_drag_summon(&"card_switch")
	await super._on_card_clicked(card_ui)
func _on_player_hand_drag_started(card_ui: CardUI) -> void:
	if is_instance_valid(card_ui) and _is_basic_target_card(card_ui.card_data): _begin_basic_target(card_ui,&"drag");return
	super._on_player_hand_drag_started(card_ui)
func _basic_hit_target(hit: Dictionary) -> CardData:
	var target: CardData=hit.get("card")
	if target==null and hit.get("board_cell") is Vector2i: target=battle.get_unit_at_cell(hit.board_cell)
	return target
func _refresh_card_target_guidance() -> void:
	if _monster_drag_session.get("intent")!=BASIC_TARGET_INTENT: super._refresh_card_target_guidance();return
	if _monster_summon_state() not in [MONSTER_SUMMON_DRAGGING,MONSTER_SUMMON_RESELECTING]:
		if is_instance_valid(_card_target_guidance): _card_target_guidance.clear()
		return
	if not is_instance_valid(_card_target_guidance):
		_card_target_guidance=preload("res://scenes/presentation/card_target_guidance.gd").new()
		$MonsterSummonConfirmationLayer.add_child(_card_target_guidance)
	var card: CardData=_monster_drag_session.card
	var field: Array=context.enemy.field if card.card_id=="B01" else context.player.field
	var targets: Array[Dictionary]=[]
	for target: CardData in field:
		var status: Dictionary=battle.basic_card_trial.target_status(card,target)
		if not status.get("ok",false): continue
		var point := _project_tactical_cell_to_screen(battle.get_unit_cell(target))
		if point.is_finite(): targets.append({"rect":Rect2(point-Vector2(61,24),Vector2(122,48)),"anchor":point,"label":target.get_display_name(),"hit":{"ok":true,"target_kind":&"unit","card":target}})
	_card_target_guidance.show_targets(targets,"%s：选%s棋子绿色标记，预览后确认；右键或 Escape 取消" % [card.get_display_name(),"敌方" if card.card_id=="B01" else "己方"])
func _update_card_cast_drag_hit(hit: Dictionary, pointer_screen_position: Vector2 = Vector2.INF) -> Dictionary:
	if _monster_drag_session.get("intent")!=BASIC_TARGET_INTENT: return super._update_card_cast_drag_hit(hit,pointer_screen_position)
	if _monster_summon_state() not in [MONSTER_SUMMON_DRAGGING,MONSTER_SUMMON_RESELECTING]: return {"ok":false}
	if not pointer_screen_position.is_finite(): pointer_screen_position=_monster_source_screen_anchor()
	hit=_guided_card_target(hit,pointer_screen_position)
	var target := _basic_hit_target(hit)
	var status: Dictionary=battle.basic_card_trial.target_status(_monster_drag_session.card,target)
	var candidate := {"target_runtime_id":target.get_instance_id()} if target!=null else {}
	var point := _project_tactical_cell_to_screen(battle.get_unit_cell(target)) if target!=null else pointer_screen_position
	var fact := _make_card_cast_preview_fact(pointer_screen_position,point,candidate,status.get("ok",false),&"ok" if status.get("ok",false) else &"basic_target_invalid")
	fact.basic_status=status.duplicate(true)
	_monster_drag_session.last_pointer_screen_position=pointer_screen_position
	_monster_drag_session.candidate_target=candidate
	_monster_summon_interaction_presenter.show_card_drag(fact,_is_reduced_motion_presentation())
	if not status.get("ok",false) and action_feed: action_feed.push_message(status.get("reason","请选择棋子"),TC.WARNING,"",1.0)
	return {"ok":status.get("ok",false),"preview_fact":fact,"reason_code":fact.reason_code}
func _stage_card_cast_candidate(card_ui: CardUI, fact: Dictionary) -> Dictionary:
	var result := super._stage_card_cast_candidate(card_ui,fact)
	if result.get("ok",false) and _monster_drag_session.get("intent")==BASIC_TARGET_INTENT:
		var card: CardData=_monster_drag_session.card
		var status: Dictionary=fact.basic_status
		var target: CardData=battle._find_field_card_by_runtime_id(status.target_runtime_id,&"boss" if card.card_id=="B01" else &"player")
		_monster_summon_interaction_presenter.show_card_pending(fact,"%s → %s\n热量 %d→%d\n%s" % [card.get_display_name(),target.get_display_name(),status.heat,status.heat-1,status.preview],"确认施放","重新选择",_is_reduced_motion_presentation())
		_refresh_card_target_guidance()
	return result
func _dispatch_3d_click_hit(hit: Dictionary) -> bool:
	if _monster_drag_session.get("intent")==BASIC_TARGET_INTENT:
		if _monster_summon_state()==MONSTER_SUMMON_RESELECTING:
			var hover := _update_card_cast_drag_hit(hit,get_viewport().get_mouse_position())
			var ref: WeakRef=_monster_drag_session.get("card_ui_ref")
			if hover.get("ok",false) and ref!=null and is_instance_valid(ref.get_ref()): _stage_card_cast_candidate(ref.get_ref(),hover.preview_fact)
		return true
	return super._dispatch_3d_click_hit(hit)
func _begin_card_cast_reselect() -> void:
	super._begin_card_cast_reselect()
	if _monster_drag_session.get("intent")==BASIC_TARGET_INTENT: _refresh_card_target_guidance()
func _cleanup_card_cast_interaction(reason: StringName = &"cleanup", allow_committing: bool = false) -> void:
	super._cleanup_card_cast_interaction(reason,allow_committing)
	if is_instance_valid(_card_target_guidance): _card_target_guidance.clear()
func _confirm_pending_card_cast() -> Dictionary:
	if _monster_drag_session.get("intent")!=BASIC_TARGET_INTENT: return await super._confirm_pending_card_cast()
	if _monster_summon_state()!=MONSTER_SUMMON_PENDING_CONFIRM: return {"ok":false}
	var card: CardData=_monster_drag_session.card
	var fact: Dictionary=_monster_drag_session.locked_preview_fact
	var target: CardData=battle._find_field_card_by_runtime_id(fact.candidate_target.get("target_runtime_id",0),&"boss" if card.card_id=="B01" else &"player")
	var ref: WeakRef=_monster_drag_session.get("card_ui_ref")
	if ref==null or not is_instance_valid(ref.get_ref()) or ref.get_ref().card_data!=card:
		_cleanup_card_cast_interaction(&"source_stale");return {"ok":false}
	var result: Dictionary=battle.play_card(card,-1,battle.INVALID_GRID_CELL,{"basic_target":target,"expected_basic_status":fact.basic_status})
	if not result.get("ok",false):
		if action_feed: action_feed.push_message(result.get("reason","请重新选择目标"),TC.WARNING,"",1.5)
		_begin_card_cast_reselect();return result
	var cell: Vector2i=fact.basic_status.cell
	ref.get_ref().accept_board_drop()
	_cleanup_card_cast_interaction(&"basic_success",true)
	_stat_total_cards+=1
	if boss_deck and boss_deck.has_method("check_player_card_reaction"): boss_deck.check_player_card_reaction(context.cards_played_this_turn)
	_refresh_tables()
	var text := "实际伤害 %d" % result.package.damage.applied if card.card_id=="B01" else "下次普通攻击 +2" if card.card_id=="B02" else "护卫已就绪：交战减伤2"
	_show_committed_source_feedback(card,cell,text,fact.source_screen_position)
	check_battle_end()
	return result
func _draw_frontline() -> void:
	super._draw_frontline()
	if not is_instance_valid(_monster_command_menu) or not _monster_command_menu.visible: return
	var unit: CardData=_monster_command_menu._card
	if unit==null or battle.basic_card_trial==null: return
	var bonus: int=battle.basic_card_trial.blade_amount(unit)
	if bonus>0: _frontline_overlay.draw_string(ThemeDB.fallback_font,Vector2(26,523),"基础赋刃：下次普通攻击+2；本回合到期",HORIZONTAL_ALIGNMENT_LEFT,340,13,Color("79ffe1"))
