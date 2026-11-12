extends "res://scenes/experiments/gb3n_arsenal_lifecycle.gd"
## Independent mixed deck. Existing decks and shared confirmation semantics are retained.
const ENGINEERING_ENTRY := "res://scenes/experiments/gb3o_engineering_package.tscn"
const ENGINEERING_ORDER: Array[String]=["P05","S01","E01","E02","P01","R01","P23","P22","P07","P10","P08","P06","P02","P15","P03","P11","S03","P13","S02"]
const ENGINEERING_TARGET_INTENT := &"engineering_target"
var _live_coach_panel: Control
func _load_gb1_packs() -> Array:
	var packs := super._load_gb1_packs()
	var raw=JSON.parse_string(FileAccess.get_file_as_string("res://data/experiments/engineering_package.json"))
	if not raw is Dictionary or raw.get("schema_version")!=1 or not raw.get("cards") is Array:
		_gb1_load_problems.append("工程包数据无效");return packs
	var loader := GB1Catalog.new();var cards: Array[CardData]=[]
	for row: Dictionary in raw.cards:
		var card := loader.convert_to_carddata(row)
		card.art_path="";card.thumb_path="";card.detail_path="";cards.append(card)
	loader.free();packs.append(cards);return packs
func _gb1_prepare_startup() -> void:
	super._gb1_prepare_startup()
	if not _gb1_startup_ok: return
	_gb1_selected_cards.clear()
	for id in ENGINEERING_ORDER:
		if not _gb1_cards_by_id.has(id):
			_gb1_load_problems.append("工程牌缺失："+id);_gb1_startup_ok=false;return
		_gb1_selected_cards.append(_gb1_cards_by_id[id])
func _setup_game() -> void:
	super._setup_game();battle.configure_engineering_trial(true)
func _ready() -> void:
	await super._ready()
	if not _gb1_startup_ok: return
	_expansion_guide._button.text="工程小轴 · 查看短组合"
	_expansion_guide._dialog.title="筑城 → 测绘 → 工程 → 局部补给"
	_live_coach_panel=preload("res://ui/live_play_coach_panel.gd").new()
	_live_coach_panel.name="LivePlayCoach"
	_live_coach_panel.scene_ref=weakref(self)
	add_child(_live_coach_panel)
	battle.od_release_event.connect(_live_coach_panel.coach.note_release)
func _get_structure_reserved_ui_rects() -> Array[Rect2]:
	var rects: Array[Rect2]=super._get_structure_reserved_ui_rects()
	if is_instance_valid(_live_coach_panel):rects.append(_live_coach_panel.reserved_rect())
	return rects
func _build_expansion_route_view() -> Dictionary:
	var view := super._build_expansion_route_view()
	view.text="短组合：先建炉基座 → 锅炉学徒登场找导体 → 测绘支付1热，二选一找修补/升高 → 正常使用找来的牌 → 前沿补给保护工程附近的一名棋子。\n修补需要受损的墙/门楼，基座没有墙；起手可先找升高，抬高学徒相邻的空地。\n\n测绘与补给同名每回合一次；测绘不因取消/缺目标/满手而付费。补给免费，以卡位和成功工程为前置，不挡Boss法术，只减下一次棋子交战伤害1。与护送取较大值，至下次己方回合开始到期，离场消失。\n工程预览或失败不算准备，补给不能反过来解锁自己。打完短组合仍需正常召唤、移动、攻城；OD继续由原任务与卡牌积累。\n\n"+str(view.text)
	var preparation := "先选本局要兑现的收益：两枚不同棋子成功攻击，准备攻击仪式；完成驻军并成功使用控制牌，准备防守仪式。炉心汇流不需要指定释放棋子。移动到平台入口后，若驻军提示没有可用移动行动，可留在入口附近等下一回合再驻军。\n\n热量和引擎层数分开：攒到8热可以释放，转换热量才推进层数；只把热量存满不会直接达到L3。炉基座主动强化优先付2充能，否则付2热；热沉准备减压会付1热（热量不足时才用冷却充能）。想攒OD时，可先保留这些主动接口。\n\n普通战术释放需要对应棋型的棋子。本牌组的燃芯使魔可作为来源；学徒和两种导体可通过普通攻击准备仪式，但不能直接作为普通战术释放来源。以「普通OD」按钮的当前合法来源为准。想接终场合体，可选择P15→A04作为中级武库，保留燃芯继续普通释放升层；提前升格守卫会失去它原来的蓄压与技能防守。到L5/Burst还需外场导体、另一枚存活蒸汽素材与3HP，新合体仍要等下回合才能攻击。\n\nL1只有两个前场名额；要衔接燃芯的升层与武库，可以先给它保留位置，并选择后排合法格登场，等召唤病解除。\n\n"
	if context!=null and battle!=null:
		preparation="当前：热量%d/10 · 引擎L%d · 前场%d/%d。\n\n" % [context.od_mode.current_od,context.od_mode.get_engine_layer(),context.player.field.size(),context.od_mode.get_front_slot_limit()]+preparation
	view.text=preparation+str(view.text)
	return view
func restart_gb1_battle() -> void:
	if _gb1_restarting: return
	_gb1_restarting=true
	if battle!=null and battle.reaction_trial!=null: battle.reaction_trial.finish_event()
	var err := get_tree().change_scene_to_file(ENGINEERING_ENTRY)
	if err!=OK: _gb1_restarting=false;push_error("Engineering trial restart failed: %d" % err)
func _is_engineering_target_card(card: CardData) -> bool:
	return card!=null and card.card_id in ["E01","E02"]
func _classify_board_drag_intent(card: CardData) -> StringName:
	return ENGINEERING_TARGET_INTENT if _is_engineering_target_card(card) else super._classify_board_drag_intent(card)
func _is_card_cast_drag_intent(intent: StringName) -> bool:
	return intent==ENGINEERING_TARGET_INTENT or super._is_card_cast_drag_intent(intent)
func _begin_engineering_target(card_ui: CardUI, origin: StringName) -> bool:
	if battle_ended or _card_being_played or not is_instance_valid(card_ui): return false
	var card := card_ui.card_data
	if not _is_engineering_target_card(card) or _has_non_presentation_end_turn_busy(card) or _presentation_end_turn_blocked: return false
	if not battle.can_play_card(card): _show_unplayable_reason(card);return false
	if _is_monster_summon_interaction_active():
		if _monster_drag_session.get("card")!=card: _cleanup_monster_drag_summon(&"card_switch")
		elif _monster_summon_state()==MONSTER_SUMMON_PENDING_CONFIRM: return false
		else:
			_monster_drag_session.state=MONSTER_SUMMON_DRAGGING if origin==&"drag" else MONSTER_SUMMON_RESELECTING
			_monster_drag_session.origin=origin
			_monster_summon_drop_target.set_board_drag_active(origin==&"drag",ENGINEERING_TARGET_INTENT)
			_refresh_card_target_guidance();return true
	if not _start_card_cast_drag_session(card_ui,card,ENGINEERING_TARGET_INTENT): return false
	_monster_drag_session.origin=origin
	_monster_drag_session.state=MONSTER_SUMMON_DRAGGING if origin==&"drag" else MONSTER_SUMMON_RESELECTING
	_monster_summon_drop_target.set_board_drag_active(origin==&"drag",ENGINEERING_TARGET_INTENT)
	_refresh_card_target_guidance();return true
func _on_card_clicked(card_ui: CardUI) -> void:
	if is_instance_valid(card_ui) and _is_engineering_target_card(card_ui.card_data): _begin_engineering_target(card_ui,&"click");return
	if _monster_drag_session.get("intent")==ENGINEERING_TARGET_INTENT: _cleanup_monster_drag_summon(&"card_switch")
	await super._on_card_clicked(card_ui)
func _on_player_hand_drag_started(card_ui: CardUI) -> void:
	if is_instance_valid(card_ui) and _is_engineering_target_card(card_ui.card_data): _begin_engineering_target(card_ui,&"drag");return
	super._on_player_hand_drag_started(card_ui)
func _engineering_hit_target(hit: Dictionary) -> Variant:
	if _monster_drag_session.card.card_id=="E01": return hit.get("engineering_choice")
	var target: CardData=hit.get("card")
	if target==null and hit.get("board_cell") is Vector2i: target=battle.get_unit_at_cell(hit.board_cell)
	return target
func _refresh_card_target_guidance() -> void:
	if _monster_drag_session.get("intent")!=ENGINEERING_TARGET_INTENT: super._refresh_card_target_guidance();return
	if _monster_summon_state() not in [MONSTER_SUMMON_DRAGGING,MONSTER_SUMMON_RESELECTING]:
		if is_instance_valid(_card_target_guidance): _card_target_guidance.clear()
		return
	if not is_instance_valid(_card_target_guidance):
		_card_target_guidance=preload("res://scenes/presentation/card_target_guidance.gd").new()
		$MonsterSummonConfirmationLayer.add_child(_card_target_guidance)
	var card: CardData=_monster_drag_session.card
	var targets: Array[Dictionary]=[]
	var availability: Dictionary=battle.get_card_play_status(card)
	if not availability.get("ok",false):
		_card_target_guidance.show_targets(targets,("测绘" if card.card_id=="E01" else "补给")+"："+str(availability.get("reason","当前不可用"))+"；未付费，右键/Escape取消")
		return
	if card.card_id=="E01":
		var choices: Array[String]=battle.engineering_trial.choices()
		for i in range(choices.size()):
			var id: String=choices[i]
			if not battle.get_engineering_cast_status(card,id).get("ok",false): continue
			var point := Vector2(get_viewport_rect().size.x/2.0+(i-(choices.size()-1)/2.0)*240,get_viewport_rect().size.y*0.30)
			targets.append({"rect":Rect2(point-Vector2(108,26),Vector2(216,52)),"anchor":point,"label":"找修补：耐久+1" if id=="P22" else "找升高：高度+1","hit":{"ok":true,"target_kind":&"engineering_choice","engineering_choice":id}})
	else:
		for target: CardData in context.player.field:
			var status: Dictionary=battle.get_engineering_cast_status(card,target)
			if not status.get("ok",false): continue
			var point := _project_tactical_cell_to_screen(battle.get_unit_cell(target))
			if point.is_finite(): targets.append({"rect":Rect2(point-Vector2(72,24),Vector2(144,48)),"anchor":point,"label":target.get_display_name(),"hit":{"ok":true,"target_kind":&"unit","card":target}})
	_card_target_guidance.show_targets(targets,"测绘：付1热找修补/升高加入手牌，需再施放；松手或点击后确认，右键/Escape取消" if card.card_id=="E01" else "补给：免费选绿色普通友军，下一次交战减伤1；不挡Boss法术，与护送取较大，次己方开始到期；右键/Escape取消")
func _update_card_cast_drag_hit(hit: Dictionary, pointer_screen_position: Vector2 = Vector2.INF) -> Dictionary:
	if _monster_drag_session.get("intent")!=ENGINEERING_TARGET_INTENT: return super._update_card_cast_drag_hit(hit,pointer_screen_position)
	if _monster_summon_state() not in [MONSTER_SUMMON_DRAGGING,MONSTER_SUMMON_RESELECTING]: return {"ok":false}
	if not pointer_screen_position.is_finite(): pointer_screen_position=_monster_source_screen_anchor()
	hit=_guided_card_target(hit,pointer_screen_position)
	var selection: Variant=_engineering_hit_target(hit)
	var status: Dictionary=battle.get_engineering_cast_status(_monster_drag_session.card,selection)
	var candidate: Dictionary={"engineering_choice":selection} if selection is String else {"target_runtime_id":selection.get_instance_id()} if selection is CardData else {}
	var point := _project_tactical_cell_to_screen(battle.get_unit_cell(selection)) if selection is CardData else pointer_screen_position
	var fact := _make_card_cast_preview_fact(pointer_screen_position,point,candidate,status.get("ok",false),&"ok" if status.get("ok",false) else &"engineering_target_invalid")
	fact.engineering_status=status.duplicate(true)
	_monster_drag_session.last_pointer_screen_position=pointer_screen_position
	_monster_drag_session.candidate_target=candidate
	_monster_summon_interaction_presenter.show_card_drag(fact,_is_reduced_motion_presentation())
	if not status.get("ok",false) and action_feed: action_feed.push_message(status.get("reason","请选择棋子"),TC.WARNING,"",1.0)
	return {"ok":status.get("ok",false),"preview_fact":fact,"reason_code":fact.reason_code}
func _stage_card_cast_candidate(card_ui: CardUI, fact: Dictionary) -> Dictionary:
	var result := super._stage_card_cast_candidate(card_ui,fact)
	if result.get("ok",false) and _monster_drag_session.get("intent")==ENGINEERING_TARGET_INTENT:
		var card: CardData=_monster_drag_session.card
		var status: Dictionary=fact.engineering_status
		_monster_summon_interaction_presenter.show_card_pending(fact,"%s\n%s\n热量 %d→%d" % [card.get_display_name(),status.preview,status.heat,status.heat-(1 if card.card_id=="E01" else 0)],"确认施放","重新选择",_is_reduced_motion_presentation())
		_refresh_card_target_guidance()
	return result
func _dispatch_3d_click_hit(hit: Dictionary) -> bool:
	if _monster_drag_session.get("intent")==ENGINEERING_TARGET_INTENT:
		if _monster_summon_state()==MONSTER_SUMMON_RESELECTING:
			var hover := _update_card_cast_drag_hit(hit,get_viewport().get_mouse_position())
			var ref: WeakRef=_monster_drag_session.get("card_ui_ref")
			if hover.get("ok",false) and ref!=null and is_instance_valid(ref.get_ref()): _stage_card_cast_candidate(ref.get_ref(),hover.preview_fact)
		return true
	return super._dispatch_3d_click_hit(hit)
func _begin_card_cast_reselect() -> void:
	super._begin_card_cast_reselect()
	if _monster_drag_session.get("intent")==ENGINEERING_TARGET_INTENT: _refresh_card_target_guidance()
func _cleanup_card_cast_interaction(reason: StringName = &"cleanup", allow_committing: bool = false) -> void:
	super._cleanup_card_cast_interaction(reason,allow_committing)
	if is_instance_valid(_card_target_guidance): _card_target_guidance.clear()
func _confirm_pending_card_cast() -> Dictionary:
	if _monster_drag_session.get("intent")!=ENGINEERING_TARGET_INTENT: return await super._confirm_pending_card_cast()
	if _monster_summon_state()!=MONSTER_SUMMON_PENDING_CONFIRM: return {"ok":false}
	var card: CardData=_monster_drag_session.card
	var fact: Dictionary=_monster_drag_session.locked_preview_fact
	var selection: Variant=fact.candidate_target.get("engineering_choice") if card.card_id=="E01" else battle._find_field_card_by_runtime_id(fact.candidate_target.get("target_runtime_id",0),&"player")
	var ref: WeakRef=_monster_drag_session.get("card_ui_ref")
	if ref==null or not is_instance_valid(ref.get_ref()) or ref.get_ref().card_data!=card:
		_cleanup_card_cast_interaction(&"source_stale");return {"ok":false}
	var result: Dictionary=battle.play_card(card,-1,battle.INVALID_GRID_CELL,{"engineering_selection":selection,"expected_engineering_status":fact.engineering_status})
	if not result.get("ok",false):
		if action_feed: action_feed.push_message(result.get("reason","请重新选择目标"),TC.WARNING,"",1.5)
		_begin_card_cast_reselect();return result
	var cell: Vector2i=fact.engineering_status.get("cell",battle.INVALID_GRID_CELL)
	ref.get_ref().accept_board_drop()
	_cleanup_card_cast_interaction(&"engineering_success",true)
	_stat_total_cards+=1
	if boss_deck and boss_deck.has_method("check_player_card_reaction"): boss_deck.check_player_card_reaction(context.cards_played_this_turn)
	_refresh_tables()
	if card.card_id=="E02": _show_committed_source_feedback(card,cell,"补给就绪：交战减伤1",fact.source_screen_position)
	if action_feed: action_feed.push_message(str(result.package.message),TC.SUCCESS,"",2.5)
	check_battle_end()
	return result
func _draw_frontline() -> void:
	super._draw_frontline()
	if battle==null or battle.engineering_trial==null: return
	for unit: CardData in context.player.field:
		if battle.frontline_trial.escort_amount(unit)!=1: continue
		var point := _project_tactical_cell_to_screen(battle.get_unit_cell(unit))
		if not point.is_finite(): continue
		var rect := Rect2(point-Vector2(65,66),Vector2(130,28))
		_frontline_overlay.draw_rect(rect,Color(0.02,0.10,0.12,0.96))
		_frontline_overlay.draw_string(ThemeDB.fallback_font,rect.position+Vector2(7,19),"补给：交战减伤1",HORIZONTAL_ALIGNMENT_LEFT,118,14,Color("79ffe1"))
