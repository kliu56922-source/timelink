extends "res://core/battle/pacing_weakpoint_battle_system.gd"
## Read-only projections for the165A bounded queue. All commits remain inherited.
func advance_actor_status(card: CardData) -> Dictionary:
	if _is_battle_terminal():return {"ok":false,"reason":"战斗已结束"}
	if not _core_command_player_turn_open or not get_command_economy_snapshot("player").get("turn_open",false):return {"ok":false,"reason":"等待己方行动窗口"}
	if not is_instance_valid(card) or card not in context.player.field:return {"ok":false,"reason":"原单位不在我方前场"}
	var st: Variant=_state_for_card(card)
	if st==null or st.is_dead():return {"ok":false,"reason":"单位已离场"}
	var attack: Dictionary=can_monster_attack(card)
	if not attack.get("ok",false):return attack
	if not monster_combat_rules.direct_attack_enabled:return {"ok":false,"reason":"当前规则不允许攻击Boss"}
	return {"ok":true}
func project_advance_moves(card: CardData,origin: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i]=[]
	if not advance_actor_status(card).ok or not monster_combat_rules.movement_enabled:return result
	var assignment:=get_garrison_state_for_unit(card)
	if assignment.get("state",&"") in [&"active",&"displaced_pending_exit"]:return result
	var ignores: bool=tactical_pattern_snapshot.ignores_engagement_for_move(get_unit_tactical_pattern(card))
	if not ignores and tactical_core_facing_rules.engagement_locks_self_move():
		for enemy: CardData in context.enemy.field:
			var enemy_state: Variant=_state_for_card(enemy)
			if enemy_state==null or enemy_state.is_dead():continue
			var enemy_cell:=get_unit_cell(enemy)
			if enemy_cell==INVALID_GRID_CELL:continue
			if origin in _get_pattern_attack_cells(enemy,enemy_cell,&"boss"):return result
	for cell: Vector2i in _get_pattern_move_cells(card,origin,&"player",MOVE_SELF):
		if edge_fortification_trial!=null and not edge_fortification_trial.can_traverse(origin,cell,&"player"):continue
		result.append(cell)
	return result
func project_advance_part(card: CardData,id: String,origin: Vector2i) -> Dictionary:
	var gate:=advance_actor_status(card)
	if not gate.ok:return gate
	var part:=get_weakpoint_snapshot(id)
	if part.is_empty():return {"ok":false,"reason":"要害不存在"}
	if part.broken:return {"ok":false,"reason":"该要害已破坏"}
	if not part.exposed:return {"ok":false,"reason":"先破坏两处外围要害"}
	if origin.y!=tactical_core_facing_rules.get_breach_rank(&"player"):return {"ok":false,"reason":"需先到Boss侧突破行"}
	if part.column>=0 and origin.x!=int(part.column):return {"ok":false,"reason":"需要%d列通路"%(int(part.column)+1)}
	var st: Variant=_state_for_card(card)
	if st.get_facing_rank_delta()!=tactical_core_facing_rules.get_default_facing(&"player"):return {"ok":false,"reason":"当前朝向背离Boss"}
	for enemy: CardData in context.enemy.field:
		var enemy_state: Variant=_state_for_card(enemy)
		if enemy_state==null or enemy_state.is_dead():continue
		var cell:=get_unit_cell(enemy)
		if cell==INVALID_GRID_CELL:continue
		if enemy.is_guard_card and cell.y<=tactical_core_facing_rules.get_threat_rank(&"player") and absi(cell.x-origin.x)<=tactical_core_facing_rules.get_guard_intercept_column_radius():
			return {"ok":false,"reason":"%s〔%d列%d行〕守卫拦截；先清障或另选路线"%[enemy.get_display_name(),cell.x+1,cell.y+1]}
	for cell: Vector2i in _get_pattern_attack_cells(card,origin,&"player"):
		var enemy: CardData=get_unit_at_cell(cell)
		if enemy!=null and enemy in context.enemy.field and not _state_for_card(enemy).is_dead():return {"ok":false,"reason":"前方敌棋阻挡；先清障或另选路线"}
	if get_effective_unit_attack(card)+get_normal_attack_bonus(card)<=0:return {"ok":false,"reason":"没有可造成的要害伤害"}
	return {"ok":true,"part":part}
func project_advance_budget(card: CardData,moves: int) -> Dictionary:
	if moves<0 or moves>2 or not advance_actor_status(card).ok:return {"ok":false,"reason":"本段最多两次移动和一次攻击"}
	var st: Variant=_state_for_card(card)
	var economy:=get_command_economy_snapshot("player")
	var costs: Array[int]=[]
	var gross: int=economy.gross_spent
	var depth: int=context.depth_pressure
	var pending: int=context.pending_depth_reduction
	var total:=0
	for i in range(moves+1):
		var verb:="move" if i<moves else "attack_core"
		var cost: int=get_action_command_cost(card,verb) if i==0 else maxi(tactical_command_economy_rules.get_minimum_paid_cost(),tactical_command_economy_rules.get_base_command_cost(verb)+maxi(0,st.get_command_cost_modifier()))
		costs.append(cost);total+=cost
		for threshold: int in tactical_command_economy_rules.get_depth_thresholds():
			if threshold>gross and threshold<=gross+cost and threshold not in economy.crossed_thresholds:
				var gain: int=tactical_command_economy_rules.get_depth_per_threshold()
				var reduction:=mini(pending,gain);pending-=reduction
				depth=mini(context.get_depth_max_value(),depth+gain-reduction)
		gross+=cost
	if total>int(economy.current_points):return {"ok":false,"reason_code":"insufficient_command_points","required_cost":total,"shortfall":total-int(economy.current_points),"reason":"本段需%d指令，当前%d，还差%d。可换单位/路线，或结束回合后重新预览；手动攻击也需支付费用。"%[total,int(economy.current_points),total-int(economy.current_points)]}
	if depth>=context.get_depth_max_value() and context.depth_pressure<context.get_depth_max_value():return {"ok":false,"reason":"本段会触发新的深渊制动，请分步决定"}
	return {"ok":true,"costs":costs,"total_cost":total,"depth_cap":depth,"pending_after":pending}
