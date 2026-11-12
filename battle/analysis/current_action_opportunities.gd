extends RefCounted
## Current public facts only. A short list is not a proof that no other actions exist.
var card_probe=preload("res://battle/analysis/live_play_coach.gd").new()
var unit_probe=preload("res://battle/analysis/player_siege_decision.gd").new()
func inspect(s: Variant) -> Dictionary:
	var result:={"rows":[],"blocked":[],"threat":"","remind":false,"reason":"","units":[]}
	if s==null or s.context==null or s.battle==null:return result
	result.threat=str(s.context.enemy.get_boss_status_snapshot().get("intent_text",""))
	if s.battle_ended:result.reason="本局已结束";return result
	var continuous: bool=s.has_method("advance165_manual") and is_instance_valid(s.advance165)
	if continuous:
		var selection: String=s.advance165.input_hint()
		if not selection.is_empty():result.reason=selection;return result
	if not s.integrated_navigation_ready() or s._has_non_presentation_end_turn_busy() or s._presentation_end_turn_blocked:
		result.reason="动作正在结算，请等待完成。" if s._presentation_end_turn_blocked else "当前不能行动；若已无其他操作，可点「结束回合」，等Boss行动后再选单位。"
		if continuous and not s.context.player.field.is_empty():
			var help: String=s.advance165.actor_guidance(s.context.player.field[0])
			if not help.is_empty():result.reason=help
		return result
	var b: Variant=s.battle
	var units: Dictionary=unit_probe.get_decision(b)
	var next_cost:=0
	if continuous and not s.context.player.field.is_empty():
		var selected: CardData=s.context.player.field[0]
		var available: Dictionary=s.advance165.availability(selected)
		for actor: CardData in s.context.player.field:
			var option: Dictionary=s.advance165.availability(actor)
			if option.ok:selected=actor;available=option;break
		result.rows.append(_row("unit",selected,"%s · %s\n点击选要害/路线；整段费用看预览"%[selected.get_display_name(),available.label]))
		if not available.ok:result.blocked.append(available.reason)
	elif units.get("ok",false):
		var candidate: Dictionary=units.candidates[0]
		next_cost=int(candidate.cost)
		var verbs: Dictionary={&"move":"推进",&"attack":"攻击",&"attack_core":"攻击Boss本体",&"turn":"回防"}
		result.rows.append(_row("unit",candidate.actor,"%s · %s
%d共享指令；点击查看原操作菜单"%[candidate.actor.get_display_name(),verbs.get(candidate.command,"行动"),candidate.cost]))
		result.remind=candidate.command in [&"attack",&"attack_core"]
	var hand: Array[CardData]=[]
	for card: CardData in s.context.player.hand:
		var status: Dictionary=b.get_card_play_status(card)
		if status.get("ok",false) and not card_probe._card_hint(s,card).is_empty():
			if card.is_building_card() and b.get_legal_structure_build_cells(card).is_empty():continue
			hand.append(card)
		elif not status.get("ok",false):result.blocked.append(card.get_display_name()+"："+str(status.get("reason","当前不可用")))
	if not hand.is_empty():result.rows.append(_row("hand",hand[0],"手牌 · %s
查看当前效果；需要目标时仍须选定"%hand[0].get_display_name()))
	for actor: CardData in s.context.player.field:
		var quote: Dictionary=b.get_od_release_source_status(actor)
		if quote.get("ok",false) and (not quote.get("legal_targets",[]).is_empty() or not quote.get("legal_cells",[]).is_empty()):
			result.rows.append(_row("od",actor,"普通OD · %s
%d热 / %d指令；点击选择来源和落点"%[actor.get_display_name(),quote.get("heat_cost",b.od_release_rules.get_release_heat_cost()),quote.get("command_cost",0)]));result.remind=true;break
	if result.rows.size()<3:
		for facility: CardData in s.context.player.traps:
			var quote: Dictionary=s.timing_advisor.inspect_facility(facility,next_cost)
			if not quote.get("ok",false) or not quote.get("recommended",false):continue
			var benefit: String="下条%d指令的Depth减压"%next_cost if facility.card_id=="P13" else "当前护盾 +%d"%quote.shield_gain
			result.rows.append(_row("facility",facility,"设施 · %s\n%d热 / %d充能；%s"%[facility.get_display_name(),quote.heat_cost,quote.charge_cost,benefit]));break
	if result.rows.size()<3 and next_cost==0:
		for cell: Vector2i in b.tactical_grid_rules.get_all_cells():
			var advice: Dictionary=s.timing_advisor.inspect_build(cell,false,&"north",true)
			var quote: Dictionary=advice.quote
			if not quote.get("ok",false) or not advice.get("recommended",false):continue
			result.rows.append({"kind":"engineering","uid":0,"cell":cell,"text":"工程 · 余下指令可投入施工
%d共享指令；查看占地与完工时机"%quote.command_cost});break
	if result.rows.size()>3:result.rows.resize(3)
	for actor: CardData in s.context.player.field:
		var state: Variant=b._state_for_card(actor)
		if state==null or state.is_dead():continue
		var attack: Dictionary=b.get_unit_command_status(actor,"attack")
		var move: Dictionary=b.get_unit_command_status(actor,"move")
		var available: bool=attack.get("ok",false) or move.get("ok",false) or s._get_garrison_command_status(actor).get("ok",false)
		var skills: Variant=b.get_monster_hero_skills()
		if skills!=null and skills.has_skill(actor.card_id):
			var skill: Dictionary=skills.get_active(actor.card_id)
			if not skill.is_empty():available=available or b.get_unit_skill_command_status(actor,StringName(str(skill.id))).get("ok",false)
		var reason: String=str(attack.get("reason_text",attack.get("reason_code","查看棋子菜单的限制")))
		var short: String={"summoning_sickness":"刚登场","insufficient_command_points":"指令不足","action_spent":"已行动","no_legal_target":"无攻击目标"}.get(str(attack.get("reason_code","")),"查看限制")
		result.units.append({"card":actor,"cell":b.get_unit_cell(actor),"available":available,"label":"可调度" if available else short})
		if not available:result.blocked.append(actor.get_display_name()+"："+reason)
	return result
func _row(kind: String,source: CardData,text: String) -> Dictionary:
	return {"kind":kind,"uid":source.get_instance_id(),"text":text}
func resolve(s: Variant,row: Dictionary) -> Dictionary:
	# Clicks are never promises; object identity and availability are queried again.
	for current: Dictionary in inspect(s).rows:
		if current.kind==row.get("kind") and current.uid==row.get("uid") and current.get("cell")==row.get("cell"):return current
	return {}
func source(s: Variant,row: Dictionary) -> CardData:
	for collection in [s.context.player.hand,s.context.player.field,s.context.player.traps]:
		for card: CardData in collection:
			if card.get_instance_id()==row.get("uid",0):return card
	return null
