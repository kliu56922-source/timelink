extends RefCounted
## Suggestions only. Never execute actions or read future turns/hidden decks.
var ordinary_seen := false
# Teaching keeps its existing safe policy; impact is an explicit audit option.
var od_landing_preference: StringName = &"safe"
func note_release(event_id: StringName, receipt: Dictionary) -> void:
	if event_id==&"od_release_committed" and receipt.get("ok",false): ordinary_seen=true
func get_hint(s: Variant) -> Dictionary:
	if s==null or s.battle==null or s.context==null: return _hint(&"wait","正在准备对局","稍等片刻。","")
	var b=s.battle
	var c=s.context
	var engineering: Dictionary=b.engineering_trial.snapshot()
	var ritual: Dictionary=b._ritual_trial_snapshot()
	var learned: Array[bool]=[engineering.used.has("E02"),ritual.get("used",false),ordinary_seen,c.arsenal_mid_used,c.arsenal_final_used]
	var result: Dictionary
	if s.battle_ended:
		result=_hint(&"finished","本局结束","点击「再来一局」重新体验。","可以关闭提示尝试自己的组合。")
	elif b.reaction_trial.waiting:
		var reaction: Dictionary=preload("res://battle/analysis/player_reaction_decision.gd").new().get_decision(b)
		result=_hint(&"reaction","先处理应急偏转","选择基础反制。" if reaction.get("mode","")=="base" else "可选择放弃反制。","按当前目标生命与真实费用判断；不提前消耗牌。")
	elif not b.get_command_economy_snapshot("player").get("turn_open",false):
		result=_hint(&"wait","敌方正在行动","等待你的下一回合。","提示会在局面变化后重新判断。")
	elif s._is_monster_summon_interaction_active() or s._is_piece_selection_active() or s._garrison_context.get("active",false) or s._od_release_context.get("active",false) or s._skill_context.get("active",false) or s._is_structure_build_drag_active() or s._is_lane_selection_active():
		result=_selection_hint(s)
	elif s._card_being_played or s._has_non_presentation_end_turn_busy() or s._presentation_end_turn_blocked:
		result=_hint(&"wait","正在结算操作","等待当前操作完成。","确认成功后，才会推荐下一步。")
	else:
		result=_next(s,learned,ritual)
	result["learned"]=learned
	result["progress"]="工程%s → 奖励%s → OD%s → 升格%s → 合体%s" % learned.map(func(done):return "✓" if done else "·")
	return result
func _next(s: Variant, learned: Array[bool], ritual: Dictionary) -> Dictionary:
	var b=s.battle
	var c=s.context
	var final: Dictionary=b.get_final_convergence_status("player")
	if final.get("ok",false) and (final.get("guard_ready",false) or final.get("attack_ready",false)):
		var path := "guard" if final.get("guard_ready",false) else "attack"
		var h := _hint(&"reward","准备已齐，可以领取奖励","点「领取奖励」→「防守仪式（正常）」。" if path=="guard" else "点「领取奖励」→「攻击仪式（正常）」。","点菜单选项即结算，支付%d热；不选透支。" % final.release_heat_cost)
		h["path"]=path;return h
	# Spend heat to build engine layers, but keep a ready reward affordable first.
	if learned[1] or not ritual.get("guard_ready",false) and not ritual.get("attack_ready",false):
		for actor: CardData in c.player.field:
			var q: Dictionary=b.get_od_release_source_status(actor)
			if not q.get("ok",false):continue
			var targets: Array=q.get("legal_targets",[])
			if targets.is_empty():targets=q.get("legal_cells",[]).duplicate()
			if targets.is_empty():continue
			if targets[0] is Vector2i:targets=[choose_od_landing(b,actor,targets)]
			var h := _hint(&"od","把热量转换成引擎成长","点「普通OD」→"+actor.get_display_name()+"→亮框目标，再确认。","当前费用：%d热、%d共享指令；存热和升层是两件事。" % [q.get("heat_cost",b.od_release_rules.get_release_heat_cost()),q.get("command_cost",0)])
			h["actor"]=actor;h["target"]=targets[0];return h
	for actor: CardData in c.player.field:
		if c.arsenal_final_used or c.od_mode.get_engine_layer()<5 and not c.od_mode.is_burst_active():break
		var q: Dictionary=_ascension_quote(s,actor)
		if not q.get("ok",false):continue
		var target: CardData=q.get("target")
		if target==null or target.card_id=="A01" or target.card_id=="A04" and c.od_mode.get_engine_layer()<5 and not c.od_mode.is_burst_active():continue
		if target.card_id=="A06" and c.player.hp<=3:continue
		var h := _hint(&"ascend","组合可以接到"+target.get_display_name(),"点击"+actor.get_display_name()+"，核对菜单费用；点「升格」即结算。","合体支付3HP；新棋子需等下回合才能攻击。" if target.card_id=="A06" else "保留普通OD来源，再准备两枚蒸汽素材。")
		h["actor"]=actor;h["target"]=target;return h
	# Initial association chain, then supply missing engine/guard pieces.
	var order: Array[String]=["P05","S01","E01","P23","E02","P01","P08","P06","P11","P13","P02","P15","S02","P07","P10","R01","P03","S03"]
	if learned[1]:order=["P02","P15","P06","P13","P01","S02","P07","P10","P03","P11","S03","R01"]
	for id in order:
		var card := _hand(c,id)
		if card==null:continue
		if id=="P08" and ritual.get("garrison_count",0)==0 and not c.player.field.any(func(unit):return b.get_unit_cell(unit).y<=1):continue
		if learned[0] and id in ["E01","E02","P23"]:continue
		if id=="P05" and not b.get_structure_snapshot().get("structures",{}).is_empty():continue
		var h := _card_hint(s,card)
		if not h.is_empty():return h
	if not learned[1] and ritual.get("garrison_count",0)==0:
		var guard := _guard_hint(s)
		if not guard.is_empty():return guard
	var bulwark := _field(c,"P15")
	if bulwark!=null and not c.arsenal_mid_used:
		var shield: Dictionary=b.get_unit_skill_command_status(bulwark,&"bulwark_advance")
		if shield.get("ok",false) and b.get_unit_combat_state(bulwark).get("actions_used",0)==0 and b.get_unit_combat_state(bulwark).get("last_action",&"")!=&"active_skill":
			var h := _hint(&"skill","壁垒兽能守住这一回合","点击热压壁垒兽→「技能」→自己的格子，再确认。","保留它作为武库来源，先使用防守技能。")
			h["actor"]=bulwark;h["cell"]=b.get_unit_cell(bulwark);return h
	var siege: Dictionary=preload("res://battle/analysis/player_siege_decision.gd").new().get_decision(b)
	var titan := _titan_hint(s)
	if not titan.is_empty():return titan
	# P15 remains a guard; other units continue to advance and attack.
	for candidate: Dictionary in siege.get("candidates",[]):
		if candidate.actor.card_id=="P15" and not c.arsenal_mid_used:continue
		if candidate.actor.card_id=="P02" and c.od_mode.get_engine_layer()<5 and not c.od_mode.is_burst_active():continue
		var names := {&"move":"移动",&"attack":"攻击",&"attack_core":"攻击",&"turn":"回防"}
		var h := _hint(&"command","继续推进："+candidate.actor.get_display_name(),"点击棋子→「%s」→%s。" % [names[candidate.command],"敌方核心" if candidate.command==&"attack_core" else "亮框目标"],"当前共享指令费用%d；每次操作后重新检查目标。" % candidate.cost)
		h.merge(candidate,true);h.kind=&"command";return h
	var why := "当前没有推荐的合法操作，点「结束回合」；会有新的抽牌和指令。"
	if not learned[1] and ritual.get("guard_ready",false):why="驻军＋控制已经准备好；等热量达到%d再领取奖励。" % final.readiness_threshold
	elif not learned[1] and ritual.get("garrison_count",0)>0:why="驻军已完成；留意冷却回路等控制牌，成功使用后准备奖励。"
	return _hint(&"end_turn","可以结束这一回合","点击右侧「结束回合」，有确认时再确认。",why)
func _card_hint(s: Variant, card: CardData) -> Dictionary:
	var b=s.battle
	if not b.get_card_play_status(card).get("ok",false):return {}
	var h := _hint(&"play","现在用："+card.get_display_name(),"点击亮框手牌；需要目标时选绿色目标，再确认。","可以先使用基础效果，熟悉后再尝试棋型强化。")
	h["card"]=card
	if card.card_id in ["P05","P08"]:
		var cells: Array=b.get_legal_structure_build_cells(card)
		cells.sort_custom(func(a,d):return a.distance_squared_to(Vector2i(2,3))<d.distance_squared_to(Vector2i(2,3)))
		for cell: Vector2i in cells:
			if not b.get_structure_build_status(card,cell).get("ok",false):continue
			h.kind=&"build";h["cell"]=cell;h.how="点击亮框手牌→亮框格→「使用基础效果」，确认建造。"
			h.why="炉基座让测绘可用，也可作为烽堡的地基。" if card.card_id=="P05" else "烽堡有前方平台；棋子驻军＋控制牌可以准备防守奖励。"
			return h
		return {}
	if card.card_id in ["E01","E02"]:
		var targets: Array=b.engineering_trial.choices() if card.card_id=="E01" else s.context.player.field
		if card.card_id=="E01" and targets.has("P23"):targets=["P23"]
		for target in targets:
			var q: Dictionary=b.get_engineering_cast_status(card,target)
			if not q.get("ok",false):continue
			h.kind=&"engineering";h["target"]=target
			h.how="点击攻城测绘→「找升高」→「确认施放」。" if target is String and target=="P23" else "点击亮框手牌→绿色选项或棋子→「确认施放」。"
			h.why="付1热，把升高加入手牌；接下来还要真正使用它。" if card.card_id=="E01" else "成功工程让附近棋子能补给：免费，下一次交战减伤1。"
			return h
		return {}
	if card.card_id=="P23":
		for unit: CardData in s.context.player.field:
			for offset in [Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP]:
				var cell: Vector2i=b.get_unit_cell(unit)+offset
				if b.get_unit_at_cell(cell)!=null or not b.get_structure_at_cell(cell).is_empty():continue
				var ref: Dictionary=b.make_terrain_raise_target_ref(cell)
				if not b.get_p23_terrain_raise_cast_status(card,ref).get("ok",false):continue
				h.kind=&"raise";h["cell"]=cell;h["target"]=ref
				h.how="点击地脉隆起→棋子旁的亮框空地→确认施放。";h.why="真实升高完成后，附近的前沿补给才会解锁。";return h
		return {}
	if card.card_family=="monster" and card.is_front_row_card():
		var cells: Array=b.get_legal_summon_cells(&"player")
		cells.sort_custom(func(a,d):return a.y>d.y if a.y!=d.y else absi(a.x-2)<absi(d.x-2))
		if card.card_id=="S01":cells.sort_custom(func(a,d):return a.distance_squared_to(Vector2i(1,3))<d.distance_squared_to(Vector2i(1,3)))
		elif card.card_id=="P02":cells.sort_custom(func(a,d):return _risk(b,a)<_risk(b,d) if _risk(b,a)!=_risk(b,d) else a.y>d.y if a.y!=d.y else absi(a.x-2)<absi(d.x-2))
		elif card.card_id in ["P07","P10","P15"]:
			var preferred := Vector2i(3,3) if card.card_id=="P07" else Vector2i(1,3)
			cells.sort_custom(func(a,d):return a.distance_squared_to(preferred)<d.distance_squared_to(preferred))
		for cell: Vector2i in cells:
			if not b.get_monster_summon_cell_status(card,cell).get("ok",false):continue
			h.kind=&"summon";h["cell"]=cell;h.how="点击亮框手牌→亮框合法格→「确认召唤」。"
			h.why="学徒登场会找导体加入手牌；现在接测绘和升高。" if card.card_id=="S01" else "燃芯留作普通OD来源；召唤病解除后再释放。" if card.card_id=="P02" else "本回合刚召唤的棋子不能立即攻击。";return h
		return {}
	if card.card_id=="P01":h.why="使用基础效果可以补牌、增加热量；锚点选友军还可护送。"
	if card.card_id=="P11":h.why="冷却回路同时完成控制准备；减少热量后，奖励可能要再等一回合。"
	if card.card_id=="R01":h.why="先准备应急偏转；遇到反制窗口再按费用决定是否使用。"
	return h
func _guard_hint(s: Variant) -> Dictionary:
	var b=s.battle
	var platforms: Array[Vector2i]=[]
	for st: Dictionary in b.get_structure_snapshot().get("structures",{}).values():
		if st.get("owner_side")!=&"player" or st.get("source_card_id")!="P08":continue
		for cell: Vector2i in st.get("footprint_cells",[]):
			if cell==st.cell:continue
			platforms.append(cell)
	if platforms.is_empty():return {}
	for actor: CardData in s.context.player.field:
		var q: Dictionary=s._get_garrison_command_status(actor)
		if q.get("ok",false) and q.get("mode")==&"enter":
			var h := _hint(&"garrison","驻军让防守奖励更近一步","点击"+actor.get_display_name()+"→「驻防」→亮起的平台→确认驻防。","驻防需要可用移动行动；再成功使用一张控制牌即可完成准备。")
			h["actor"]=actor;h["target"]=q.candidates[0];h["cell"]=platforms[0];return h
		var origin: Vector2i=b.get_unit_cell(actor)
		var goal: Vector2i=platforms[0]
		if origin.distance_squared_to(goal)<=1 and b.get_unit_move_command_status(actor,b.MOVE_SELF).get("actions_remaining",0)<=0:
			return _hint(&"end_turn","已经到达平台入口","留在入口，点「结束回合」。","本回合移动行动可能已用完，下一回合重新检查驻防。")
		var move: Dictionary=b.get_unit_command_status(actor,"move")
		var cells: Array=move.get("legal_cells",[]).duplicate()
		cells.sort_custom(func(a,d):return a.distance_squared_to(goal)<d.distance_squared_to(goal))
		for cell: Vector2i in cells:
			if cell.distance_squared_to(goal)>=origin.distance_squared_to(goal):continue
			if not b.get_unit_command_status(actor,"move",cell).get("ok",false):continue
			var h := _hint(&"command","先靠近烽堡的平台入口","点击"+actor.get_display_name()+"→「移动」→亮框格，使用基础移动。","靠近后再检查驻防；不要把入口当作立即驻军。")
			h["actor"]=actor;h["command"]=&"move";h["target"]=cell;h["cost"]=move.get("cost",0);return h
	return {}
func _risk(b: Variant, cell: Vector2i) -> int:
	var risk := 0
	for enemy: CardData in b.context.enemy.field:
		if cell in b.get_legal_attack_cells(enemy):risk+=10
		risk+=maxi(0,5-int(b.get_unit_cell(enemy).distance_to(cell)))
	return risk
func choose_od_landing(b: Variant, actor: CardData, candidates: Array) -> Vector2i:
	var choices := candidates.duplicate()
	if od_landing_preference == &"impact":
		var hits: Array = []
		for cell: Vector2i in choices:
			var preview: Dictionary = b.get_knight_od_landing_preview(actor, cell)
			if preview.get("ok", false) and preview.get("prediction_available", false) and preview.get("target") != null:
				hits.append(cell)
		if not hits.is_empty(): choices = hits
	choices.sort_custom(func(a,d):return _risk(b,a)<_risk(b,d) if _risk(b,a)!=_risk(b,d) else a.y>d.y)
	return choices[0] if not choices.is_empty() else b.INVALID_GRID_CELL
func _ascension_quote(s: Variant, actor: CardData) -> Dictionary:
	# The scene already owns an immutable preview catalog. Reuse its data while
	# checking current authority; the generic preview getter loads a fresh catalog.
	if not is_instance_valid(s._arsenal_panel):return {}
	for target: CardData in s._arsenal_panel._mid_cards+s._arsenal_panel._final_cards:
		if not is_instance_valid(target) or not target.is_ascension_form or actor.card_id not in target.ascends_from_ids:continue
		var q: Dictionary=s.battle.can_ascend_card(actor,target,s.context.player)
		q["target"]=target
		return q
	return {}
func _titan_hint(s: Variant) -> Dictionary:
	var b=s.battle
	var actor := _field(s.context,"A06")
	if actor==null:return {}
	var core: Dictionary=b.get_unit_command_status(actor,"attack_core")
	var geometry: Dictionary=b.get_core_attack_cell_status(actor)
	var origin: Vector2i=b.get_unit_cell(actor)
	var command := &""
	var target: Variant=null
	var quote: Dictionary={}
	var title := "机神已成形，继续攻城"
	if core.get("ok",false):command=&"attack_core";quote=core
	elif geometry.get("reason")==b.REASON_GUARD_INTERCEPTED:
		var goals: Array[int]=[]
		for column in range(5):
			var covered := false
			for enemy: CardData in s.context.enemy.field:
				if enemy.is_guard_card and b.get_unit_current_hp(enemy)>0 and absi(b.get_unit_cell(enemy).x-column)<=b.tactical_core_facing_rules.get_guard_intercept_column_radius():covered=true
			if not covered:goals.append(column)
		goals.sort_custom(func(a,d):return absi(a-origin.x)<absi(d-origin.x))
		if not goals.is_empty():
			var moves: Dictionary=b.get_unit_command_status(actor,"move")
			var cells: Array=moves.get("legal_cells",[]).duplicate()
			cells.sort_custom(func(a,d):return absi(a.x-goals[0])+a.y*5<absi(d.x-goals[0])+d.y*5)
			for cell: Vector2i in cells:
				if absi(cell.x-goals[0])+cell.y*5>=absi(origin.x-goals[0])+origin.y*5:continue
				var actual: Dictionary=b.get_unit_command_status(actor,"move",cell)
				if actual.get("ok",false):command=&"move";target=cell;quote=actual;title="核心被护卫拦截，先绕到空列";break
	if command==&"":
		var attack: Dictionary=b.get_unit_command_status(actor,"attack")
		if attack.get("ok",false) and not attack.get("legal_targets",[]).is_empty():command=&"attack";target=attack.legal_targets[0];quote=b.get_unit_command_status(actor,"attack",target)
		else:
			var siege: Dictionary=preload("res://battle/analysis/player_siege_decision.gd").new().get_decision(b)
			for action: Dictionary in siege.get("candidates",[]):
				if action.actor==actor:command=action.command;target=action.target;quote={"ok":true,"cost":action.cost};break
	if command==&"" or not quote.get("ok",false):return {}
	var names := {&"attack_core":"攻击",&"attack":"攻击",&"move":"移动",&"turn":"回防"}
	var h := _hint(&"command",title,"点击机神→「%s」→%s。" % [names[command],"敌方核心" if command==&"attack_core" else "绿色推荐目标"],"按当前场面选择，实际共享指令费用%d；完成后重新判断。" % quote.cost)
	h["actor"]=actor;h["command"]=command;h["target"]=target;h["cost"]=quote.cost;return h
func _selection_hint(s: Variant) -> Dictionary:
	var how := "点当前亮起的合法目标；已选好则点当前确认按钮。"
	var why := "右键 / Escape 取消或重新选择，不会推进引导。"
	if s._is_piece_selection_active():
		match s._piece_context.get("stage"):
			&"anchor":how="点击绿色位置、友军或己方核心，指定施放位置。"
			&"payment":how="先点「使用基础效果」；想尝试强化时再选择其他费用。";why="基础效果可能立即结算；以当前预览为准。右键 / Escape 可取消。"
			&"target":how="点击当前高亮的合法目标，使用基础效果；需要确认时再确认。"
	elif s._od_release_context.get("active",false):
		how="点击普通OD的高亮来源棋子。" if s._od_release_context.get("stage")==&"source" else "点击高亮的释放目标，核对费用后确认。"
	elif s._is_monster_summon_interaction_active():
		if s._monster_summon_state()==s.MONSTER_SUMMON_PENDING_CONFIRM:how="目标已选好，点「确认施放」「确认召唤」或「确认建造」。"
		elif s._monster_drag_session.get("intent")==s.ENGINEERING_TARGET_INTENT:how="测绘点「找升高」；补给点绿色棋子，再点「确认施放」。"
		else:how="点击绿色合法格；建筑再选朝向、基础效果，最后确认。"
	return _hint(&"selection","完成眼前的选择",how,why)
func _hand(c: Variant,id: String) -> CardData:
	for card: CardData in c.player.hand:
		if card.card_id==id:return card
	return null
func _field(c: Variant,id: String) -> CardData:
	for card: CardData in c.player.field:
		if card.card_id==id:return card
	return null
func _hint(kind: StringName,title: String,how: String,why: String) -> Dictionary:
	return {"kind":kind,"title":title,"how":how,"why":why}
