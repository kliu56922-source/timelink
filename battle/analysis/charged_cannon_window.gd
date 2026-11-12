extends RefCounted
## Audit facts only; current cost is authoritative and no future damage is predicted.
func inspect(battle: Variant, used: bool) -> Dictionary:
	var q := {"eligible":false,"scope":&"current_full_thermal_core_only","reason":&"no_current_cannon"}
	if used:q.reason=&"already_sampled";return q
	if battle==null or battle.context==null:return q
	var ctx: Variant=battle.context
	if ctx.player==null or ctx.enemy==null or ctx.player.hp<=0 or ctx.enemy.hp<=0:q.reason=&"ended";return q
	if battle._od_release_resolving or battle._siege_command_in_progress or not battle.get_core_command_state().get("player_turn_open",false):q.reason=&"busy_or_closed";return q
	var ritual: Dictionary=battle.get_final_convergence_status("player")
	if not ctx.arsenal_mid_used or not ritual.get("used",false) or ritual.get("last_receipt",{}).is_empty():q.reason=&"route_not_invested";return q
	for actor: CardData in ctx.player.field:
		if not is_instance_valid(actor) or actor.card_id!="P07":continue
		var state: Variant=battle._state_for_card(actor)
		if state==null or state.get_skill_stack(&"thermal_stacks")!=3:continue
		var status: Dictionary=battle.get_unit_skill_command_status(actor,&"stream_cannon")
		if not status.get("ok",false) or not status.get("can_target_boss_core",false):continue
		q.merge({"eligible":true,"reason":&"full_thermal_current_core","actor":actor,"actor_id":actor.card_id,"actor_runtime_id":actor.get_instance_id(),"cell":battle.get_unit_cell(actor),"stacks":status.stack_count,"cost":status.cost,"base_cost":status.base_cost,"points":status.current_points,"engine_layer":ctx.od_mode.get_engine_layer(),"heat":ctx.od_mode.current_od,"depth":ctx.depth_pressure},true)
		return q
	return q
