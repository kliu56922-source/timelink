extends RefCounted
## Read-only analysis for gameplay trials. Does not execute, simulate or expose hidden state.
## Re-query after every committed command; current geometry is not a future-board forecast.
func get_decision(battle: Variant) -> Dictionary:
	var blank := {"ok":false,"reason":&"no_current_action","scope":&"current_legal_actions_no_future_board","candidates":[]}
	if battle == null or battle.context == null:
		blank.reason=&"battle_missing";return blank
	if not battle.get_core_command_state().get("player_turn_open",false):
		blank.reason=&"not_player_turn";return blank
	var candidates: Array[Dictionary]=[]
	var breach: int=battle.tactical_core_facing_rules.get_breach_rank(&"player")
	var facing: int=battle.tactical_core_facing_rules.get_default_facing(&"player")
	for actor: CardData in battle.context.player.field:
		if not is_instance_valid(actor):continue
		var origin: Vector2i=battle.get_unit_cell(actor)
		var state: Variant=battle._state_for_card(actor)
		if state==null or state.is_dead() or state.owner_side!=&"player":continue
		var power: int=battle.get_effective_unit_attack(actor)
		var core: Dictionary=battle.get_unit_command_status(actor,"attack_core")
		if core.get("ok",false):
			candidates.append(_candidate(actor,&"attack_core",null,core,100,power,origin))
		if origin.y==breach and state.get_facing_rank_delta()!=facing:
			var turn: Dictionary=battle.get_unit_command_status(actor,"turn")
			if turn.get("ok",false):candidates.append(_candidate(actor,&"turn",null,turn,90,power,origin))
		var attack: Dictionary=battle.get_unit_command_status(actor,"attack")
		if attack.get("ok",false):
			var geometry: Dictionary=battle.get_core_attack_cell_status(actor)
			for target in attack.get("legal_targets",[]):
				var actual: Dictionary=battle.get_unit_command_status(actor,"attack",target)
				if not actual.get("ok",false):continue
				var priority:=70
				var value:=power
				if target is CardData:
					var target_state: Variant=battle._state_for_card(target)
					if target_state!=null:
						value=mini(power,maxi(0,target_state.current_hp))
						if target_state.current_hp<=power:value+=10
					if target.get_instance_id()==int(geometry.get("interceptor_runtime_id",0)):priority=90
				candidates.append(_candidate(actor,&"attack",target,actual,priority,value,origin))
		var move: Dictionary=battle.get_unit_command_status(actor,"move")
		if not move.get("ok",false):continue
		for cell: Vector2i in move.get("legal_cells",[]):
			if absi(cell.y-breach)>=absi(origin.y-breach):continue
			var geometry: Dictionary=battle.get_unit_move_cell_status(actor,cell,battle.MOVE_SELF)
			var cost: Dictionary=battle.get_unit_command_status(actor,"move",cell)
			if not geometry.get("ok",false) or not cost.get("ok",false):continue
			candidates.append(_candidate(actor,&"move",cell,cost,60,100-absi(cell.y-breach)*10,origin))
	candidates.sort_custom(_comes_first)
	if candidates.is_empty():return blank
	var result: Dictionary=candidates[0].duplicate()
	result["ok"]=true;result["reason"]=&"current_legal_action"
	result["scope"]=blank.scope;result["candidates"]=candidates
	return result

func _candidate(actor: CardData,command: StringName,target: Variant,query: Dictionary,priority: int,value: int,origin: Vector2i) -> Dictionary:
	return {"actor":actor,"actor_id":actor.card_id,"command":command,"target":target,"cost":int(query.get("cost",0)),"priority":priority,"value":value,"origin":origin}
func _comes_first(a: Dictionary,b: Dictionary) -> bool:
	if a.priority!=b.priority:return a.priority>b.priority
	if a.value!=b.value:return a.value>b.value
	if a.cost!=b.cost:return a.cost<b.cost
	if a.actor_id!=b.actor_id:return a.actor_id<b.actor_id
	if a.origin!=b.origin:return a.origin.y<b.origin.y if a.origin.y!=b.origin.y else a.origin.x<b.origin.x
	if a.target is Vector2i and b.target is Vector2i:return a.target.y<b.target.y if a.target.y!=b.target.y else a.target.x<b.target.x
	return false
