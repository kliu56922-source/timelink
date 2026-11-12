extends RefCounted
## Describes current visible relationships only; never executes or predicts a draw.
const LIMIT := 3
func get_relations(s: Variant, focus: CardData) -> Dictionary:
	var result := {"focus":null,"items":[],"suppressed":false}
	if s==null or s.context==null or s.battle==null: return result
	var visible := _owned_cards(s)
	if not is_instance_valid(focus) or focus not in visible or _dead(s,focus): return result
	result.focus=focus
	if focus.is_building_card() and focus in s.context.player.traps:
		result["focus_status"]=s.battle.get_building_interface_status(focus,s.context.player)
	if s.battle_ended or s._card_being_played or s._presentation_end_turn_blocked or not s.battle.get_command_economy_snapshot("player").get("turn_open",false):
		result.suppressed=true;return result
	var rows: Array[Dictionary]=[]
	for card: CardData in visible:
		if card==focus or _dead(s,card): continue
		var row := _relation(s,focus,card)
		if not row.is_empty():rows.append(row)
	# Public arsenal already belongs to the scene; reuse it without loading catalogs.
	if is_instance_valid(s._arsenal_panel):
		for card: CardData in s._arsenal_panel._mid_cards+s._arsenal_panel._final_cards:
			if not card.is_ascension_form or focus.card_id not in card.ascends_from_ids:continue
			var q: Dictionary=s.battle.can_ascend_card(focus,card,s.context.player) if focus in s.context.player.field else {"ok":false,"reason":"需先登场，再检查升格条件"}
			rows.append(_row(card,&"ascension",&"ready" if q.get("ok",false) else &"prepare",str(q.get("reason","当前升格条件已齐")),card.ascension_text_cn,&"arsenal",2))
	rows.sort_custom(func(a,b):
		if a.rank!=b.rank:return a.rank<b.rank
		if a.state!=b.state:return a.state==&"ready"
		return a.card.card_id<b.card.card_id if a.card.card_id!=b.card.card_id else a.card.get_instance_id()<b.card.get_instance_id())
	for row: Dictionary in rows:
		if result.items.size()>=LIMIT:break
		result.items.append(row)
	return result
func _owned_cards(s: Variant) -> Array[CardData]:
	var cards: Array[CardData]=[]
	for collection in [s.context.player.hand,s.context.player.field,s.context.player.traps]:
		for card: CardData in collection:
			if is_instance_valid(card) and card not in cards:cards.append(card)
	return cards
func _dead(s: Variant,card: CardData) -> bool:
	if card not in s.context.player.field:return false
	var state=s.battle._state_for_card(card)
	return state!=null and state.is_dead()
func _relation(s: Variant,a: CardData,b: CardData) -> Dictionary:
	var zone := _zone(s,b)
	var target := _target_pair(s,a,b)
	if not target.is_empty():return target
	if (a.card_id=="E01" and b.is_building_card()) or (b.card_id=="E01" and a.is_building_card()):
		var engineering: CardData=a if a.card_id=="E01" else b
		var q: Dictionary=s.battle.get_card_play_status(engineering)
		return _row(b,&"engineering",&"present" if q.get("ok",false) else &"prepare",str(q.get("reason","测绘仍需选检索项并确认")),"完好己方建筑是测绘前置；找来的工程牌还需正常使用。",zone,1)
	if (a.card_id in ["P22","P23"] and b.card_id=="E02") or (b.card_id in ["P22","P23"] and a.card_id=="E02"):
		var supply: CardData=a if a.card_id=="E02" else b
		var q: Dictionary=s.battle.get_card_play_status(supply)
		return _row(b,&"engineering",&"present" if q.get("ok",false) else &"prepare",str(q.get("reason","仍需选择工程附近的普通棋子")),"真实修补或升高准备补给；预览不算成功工程。",zone,1)
	var declared: bool=b.card_name in a.related_cards or a.card_name in b.related_cards or b.card_name in a.next_cards or a.card_name in b.next_cards
	if not a.route_id.is_empty() and a.route_id==b.route_id and a.route_step>0 and b.route_step>0 and (absi(a.route_step-b.route_step)==1 or declared):
		var chain=s.context.chain_system
		var expected: int=chain.current_step+1 if chain.current_route_id==b.route_id else 1
		var q: Dictionary=s.battle.get_card_play_status(b) if zone==&"hand" else {}
		var continuous: bool=b.route_step==a.route_step+1
		var reason := "连锁前序未完成；需第%d步，当前关联牌是第%d步" % [expected,b.route_step]
		var state: StringName=&"prepare"
		if zone!=&"hand":state=&"present";reason="已在场上；登场步骤已结算，不会重复推进连锁"
		elif expected==b.route_step:
			state=&"present" if q.get("ok",false) else &"blocked"
			reason="连锁次序吻合；仍按卡牌的目标与费用确认" if q.get("ok",false) else str(q.get("reason","当前不可用"))
		return _row(b,&"chain",state,reason,"连锁下一步：%d→%d。%s" % [a.route_step,b.route_step,b.short_description] if continuous else "同一连锁，第%d步与第%d步；并非直接相接。%s" % [a.route_step,b.route_step,b.short_description],zone,3)
	if declared:
		var is_interface: bool=b.is_building_card() and zone==&"back"
		var q: Dictionary=s.battle.get_card_play_status(b) if zone==&"hand" else s.battle.get_building_interface_status(b,s.context.player) if is_interface else {}
		var blocked: bool=(zone==&"hand" or is_interface) and not q.get("ok",false)
		return _row(b,&"declared",&"blocked" if blocked else &"present",str(q.get("reason","")) if blocked else "卡牌资料中的配合；目标和接口仍需逐项检查",b.short_description,zone,4)
	return {}
func _target_pair(s: Variant,a: CardData,b: CardData) -> Dictionary:
	var cast: CardData
	var unit: CardData
	if a.card_id in ["B02","B03","E02"] and a in s.context.player.hand and b.card_family=="monster":cast=a;unit=b
	elif b.card_id in ["B02","B03","E02"] and b in s.context.player.hand and a.card_family=="monster":cast=b;unit=a
	else:return {}
	if unit.is_arsenal_card:return {}
	var effect: String="本回合下次普通攻击伤害+2；不提供行动或射程" if cast.card_id=="B02" else "下次棋子交战减伤2，至下次己方回合开始；不挡Boss法术" if cast.card_id=="B03" else "工程附近普通棋子，下次交战减伤1，至下次己方回合开始；不挡Boss法术"
	if unit not in s.context.player.field:
		return _row(b,&"target",&"prepare","需先登场，再检查费用和合法目标",effect,_zone(s,b),0)
	var q: Dictionary=s.battle.get_engineering_cast_status(cast,unit) if cast.card_id=="E02" else s.battle.basic_card_trial.target_status(cast,unit) if s.battle.basic_card_trial!=null else {"ok":false,"reason":"此入口未启用该接口"}
	var play: Dictionary=s.battle.get_card_play_status(cast)
	if not play.get("ok",false):q=play
	return _row(b,&"target",&"ready" if q.get("ok",false) else &"blocked","当前费用与该目标已通过；仍需确认施放" if q.get("ok",false) else str(q.get("reason","当前不能配合")),effect,_zone(s,b),0)
func _zone(s: Variant,card: CardData) -> StringName:
	return &"hand" if card in s.context.player.hand else &"field" if card in s.context.player.field else &"back"
func _row(card: CardData,kind: StringName,state: StringName,reason: String,effect: String,zone: StringName,rank: int) -> Dictionary:
	return {"card":card,"kind":kind,"state":state,"reason":reason,"effect":effect,"zone":zone,"rank":rank}
