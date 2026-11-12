extends RefCounted
## Current visible single-action payoff only. No execution, cached state or future turn.
func inspect(battle: Variant,actor: CardData,command: StringName) -> Dictionary:
	var out := {"ok":false,"comparable":false,"reason":&"unavailable","actor_id":"","actor_runtime_id":0,"command":str(command),"cost":0,"refund":0,"hp_loss":0,"shield_loss":0,"stacks_consumed":0,"packets":[],"scope":&"current_single_action_no_future_board"}
	if battle==null or battle.context==null or battle.context.player==null or battle.context.enemy==null:return out
	if not is_instance_valid(actor) or actor not in battle.context.player.field:return out
	if battle._core_damage_heat_resolving or battle._siege_command_in_progress or battle._od_release_resolving or battle._core_command_resolving:
		out.reason=&"resolution_busy";return out
	if battle.context.player.hp<=0 or battle.context.enemy.hp<=0:return out
	out.actor_id=actor.card_id;out.actor_runtime_id=actor.get_instance_id();out["cell"]=str(battle.get_unit_cell(actor))
	out["current_points"]=int(battle.get_command_economy_snapshot("player").current_points)
	out["remaining_points"]=null
	out["refund_qualification_used"]=bool(battle.get_thermal_refund_trial_status().used)
	out["will_consume_refund_opportunity"]=false;out["refund_reason"]=&"not_requested"
	if command==&"attack_core":
		if battle.core_siege_trial==null:return out
		var q: Dictionary=battle.core_siege_trial.preview_core(actor)
		if not q.get("ok",false):out.reason=str(q.get("reason","unavailable"));return out
		out.merge({"ok":true,"comparable":true,"reason":&"current_native_preview","cost":int(q.cost),"hp_loss":int(q.hp_loss),"shield_loss":int(q.shield_before)-int(q.shield_after),"packets":[int(q.damage)],"phase_lock":int(q.phase_lock)},true)
		if int(q.phase_lock)>0 or _phase_boundary(battle,int(q.hp_after)):out.comparable=false;out.reason=&"phase_boundary";return out
		if _payment_backlash_boundary(battle,int(q.cost)):out.comparable=false;out.reason=&"payment_backlash_unknown";return out
		out.remaining_points=out.current_points-out.cost
		return out
	if command!=&"stream_cannon" or actor.card_id!="P07":return out
	var q: Dictionary=battle.get_unit_skill_command_status(actor,&"stream_cannon")
	if not q.get("ok",false) or not q.get("can_target_boss_core",false):out.reason=str(q.get("reason_code","unavailable"));return out
	out.ok=true;out.cost=int(q.cost);out.stacks_consumed=int(q.stack_count)
	var state: Variant=battle._state_for_card(actor)
	var layer: int=battle.context.od_mode.get_engine_layer()
	var packets: Array[int]=[actor.unit_power+state.get_turn_attack_bonus(),int(q.stack_count)+(2 if layer>=5 and int(q.stack_count)>=3 else 0)]
	out.packets=packets.duplicate()
	var enemy: Enemy=battle.context.enemy
	var hp: int=enemy.hp;var shield: int=enemy.boss_shield
	for damage: int in packets:
		if damage<=0:continue
		# The original cannon applies two normal shield/armor packets independently.
		var hit: Dictionary=enemy.preview_damage(damage,false,shield)
		hp-=int(hit.hp_loss);shield=int(hit.shield_after)
		if _phase_boundary(battle,hp):out.reason=&"phase_boundary";return out
	out.hp_loss=enemy.hp-hp;out.shield_loss=enemy.boss_shield-shield
	if _payment_backlash_boundary(battle,int(q.cost)):out.reason=&"payment_backlash_unknown";return out
	# L5 changes Depth before refund: keep this future boundary explicitly unknown.
	if layer>=5 and int(q.stack_count)>=3:out.reason=&"depth_after_burst_unknown";return out
	var refund: Dictionary=_refund(battle,actor,hp,int(q.stack_count))
	out.refund=refund.granted;out.will_consume_refund_opportunity=refund.consume;out.refund_reason=refund.reason
	out.remaining_points=out.current_points-out.cost+out.refund
	out.merge({"comparable":true,"reason":&"current_native_packets"},true)
	return out

func _payment_backlash_boundary(battle: Variant,cost: int) -> bool:
	var ctx: Variant=battle.context
	if ctx.is_abyss_locked() or ctx.depth_pressure>=ctx.get_depth_max_value():return false
	var economy: Dictionary=battle.get_command_economy_snapshot("player")
	var gain := 0
	for threshold: int in battle.tactical_command_economy_rules.get_depth_thresholds():
		if threshold>int(economy.gross_spent) and threshold<=int(economy.gross_spent)+cost and threshold not in economy.crossed_thresholds:
			gain+=battle.tactical_command_economy_rules.get_depth_per_threshold()
	return ctx.depth_pressure+maxi(0,gain-int(ctx.pending_depth_reduction))>=ctx.get_depth_max_value()

func _phase_boundary(battle: Variant,hp: int) -> bool:
	var ctx: Variant=battle.context
	if not ctx.are_boss_phase_locks_enabled():return false
	if ctx.phases_locked_this_turn>=1:return true
	return not ctx.boss_phase1_triggered and hp<=int(ctx.get_boss_phase_lock(2).get("hp_threshold",51)) or not ctx.boss_phase2_triggered and hp<=int(ctx.get_boss_phase_lock(3).get("hp_threshold",25))

func _refund(battle: Variant,actor: CardData,hp_after: int,stacks: int) -> Dictionary:
	var result := {"granted":0,"consume":false,"reason":&"not_qualified"}
	var q: Dictionary=battle.get_thermal_refund_trial_status()
	var ritual: Dictionary=battle.get_final_convergence_status("player")
	if hp_after<=0 or stacks!=3 or not battle.context.arsenal_mid_used or not ritual.get("used",false) or ritual.get("last_receipt",{}).is_empty():return result
	if q.profile!="first-full-refund":result.reason=&"profile_original";return result
	if q.used:result.reason=&"already_attempted";return result
	result.consume=true
	var rules: Variant=battle.tactical_command_economy_rules
	if rules.blocks_instant_refund(battle._get_command_depth_zone()):result.reason=&"depth_refund_locked";return result
	var economy: Dictionary=battle.get_command_economy_snapshot("player")
	var key := "hero_skill:stream_cannon:%d"%actor.get_instance_id()
	if int(economy.refund_by_trigger.get(key,0))>=rules.get_refund_default_per_trigger_cap():result.reason=&"trigger_cap_reached";return result
	if int(economy.instant_refund_total)>=rules.get_refund_total_per_turn_cap():result.reason=&"total_cap_reached";return result
	result.granted=1;result.reason=&"first_full_paid_core";return result

func compare(battle: Variant) -> Dictionary:
	var result := {"ok":false,"scope":&"current_single_action_no_future_board","candidates":[],"best":{}}
	if battle==null or battle.context==null or battle.context.player==null:return result
	for actor: CardData in battle.context.player.field:
		var normal: Dictionary=inspect(battle,actor,&"attack_core")
		if normal.ok:result.candidates.append(normal)
		if actor.card_id=="P07":
			var cannon: Dictionary=inspect(battle,actor,&"stream_cannon")
			if cannon.ok and cannon.stacks_consumed==3:result.candidates.append(cannon)
	var known: Array=[]
	for q: Dictionary in result.candidates:
		if q.comparable:known.append(q)
	known.sort_custom(func(a: Dictionary,b: Dictionary):
		if a.hp_loss!=b.hp_loss:return a.hp_loss>b.hp_loss
		if a.cost-a.refund!=b.cost-b.refund:return a.cost-a.refund<b.cost-b.refund
		if a.actor_id!=b.actor_id:return a.actor_id<b.actor_id
		if a.command!=b.command:return a.command<b.command
		if a.cell!=b.cell:return a.cell<b.cell
		return a.actor_runtime_id<b.actor_runtime_id)
	if not known.is_empty():result.ok=true;result.best=known[0].duplicate(true)
	return result
