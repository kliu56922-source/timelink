extends RefCounted
## Opt-in L3/L4 furnace conversion. No ordinary piece identity or free growth.
## One caller-owned instance per battle; its default profile cannot execute.
const HEAT_COST := 5
var profile := "original"
var used_turn := -1
var resolving := false
var last_receipt: Dictionary = {}

func _init(value: String = "original") -> void:
	profile = value if value in ["original", "paid-hero-growth", "partial-hero-growth"] else "original"

func inspect(battle: Variant, actor: CardData, amount: int = HEAT_COST) -> Dictionary:
	var out := {"ok":false,"reason":&"unavailable","heat_cost":amount,"long_points":amount,
		"command_cost":0,"remaining_points":0,"actor_runtime_id":0,"turn":0,"layer_after":0,"charge_after":0,
		"scope":&"candidate_paid_L3_L4_conversion_once_per_turn_no_attack_lock"}
	if profile not in ["paid-hero-growth", "partial-hero-growth"]: out.reason=&"disabled";return out
	if amount<1 or amount>HEAT_COST or (profile=="paid-hero-growth" and amount!=HEAT_COST):
		out.reason=&"invalid_growth_amount";return out
	if battle==null or battle.context==null: return out
	var ctx: Variant = battle.context
	if ctx.player==null or ctx.enemy==null or ctx.od_mode==null: return out
	if resolving or battle._od_release_resolving or battle._siege_command_in_progress or battle._core_command_resolving or battle._core_damage_heat_resolving:
		out.reason=&"resolution_busy";return out
	if ctx.player.hp<=0 or ctx.enemy.hp<=0: out.reason=&"battle_ended";return out
	var econ: Dictionary = battle.get_command_economy_snapshot("player")
	if not econ.get("turn_open",false): out.reason=&"not_player_turn";return out
	if used_turn==ctx.turn_count: out.reason=&"already_used_this_turn";return out
	if not is_instance_valid(actor) or actor.card_id!="A01" or actor not in ctx.player.field:
		out.reason=&"ascended_source_missing";return out
	var st: Variant = battle._state_for_card(actor)
	if st==null or st.is_dead() or st.owner_side!=&"player" or battle.get_unit_cell(actor)==battle.INVALID_GRID_CELL or battle.get_unit_at_cell(battle.get_unit_cell(actor))!=actor:
		out.reason=&"source_not_live_on_board";return out
	var proof: Dictionary = battle.get_ascension_barrier_trial_status().get("last_receipt",{})
	if not ctx.arsenal_mid_used or not proof.get("qualified",false) or int(proof.get("target_runtime_id",0))!=actor.get_instance_id() or proof.get("source_id","")!="P02":
		out.reason=&"native_ascension_not_proven";return out
	if st.summoned_this_turn: out.reason=&"summoning_sickness";return out
	var assignment: Dictionary = battle.get_garrison_state_for_unit(actor)
	if assignment.get("state",&"") in [&"active",&"displaced_pending_exit"]: out.reason=&"withdraw_first";return out
	if ctx.is_abyss_locked(): out.reason=&"backlash_restricted";return out
	var od: Variant = ctx.od_mode
	if od.engine_layer<3 or od.engine_layer>=5: out.reason=&"outside_L3_L4_trial";return out
	if od.current_od<amount: out.reason=&"insufficient_heat";return out
	# Match the native skill path; generic unit-command lookup does not own
	# active-skill base costs and would silently fall back to one point.
	var rules: Variant = battle.tactical_command_economy_rules
	var cost: int = maxi(1,rules.get_active_skill_cost()+st.get_command_cost_modifier()+rules.get_skill_surcharge(battle._get_command_depth_zone()))
	out.command_cost=cost;out.remaining_points=int(econ.current_points)-cost
	if not battle.can_pay_command_cost("player",cost): out.reason=&"insufficient_command_points";return out
	var crossed: Array[int] = []
	for threshold: int in battle.tactical_command_economy_rules.get_depth_thresholds():
		if threshold>int(econ.gross_spent) and threshold<=int(econ.gross_spent)+cost and not threshold in econ.crossed_thresholds: crossed.append(threshold)
	var depth_gain: int = crossed.size()*battle.tactical_command_economy_rules.get_depth_per_threshold()
	var effective_gain: int = maxi(0,depth_gain-int(ctx.pending_depth_reduction))
	# Keep this bounded trial out of payments which themselves trigger Backlash.
	if int(ctx.depth_pressure)+effective_gain>=ctx.get_depth_max_value(): out.reason=&"payment_backlash_boundary";return out
	var layer: int=od.engine_layer
	var charge: int=od.engine_charge
	var remaining := amount
	while remaining>0:
		var space: int=int(od.ENGINE_LAYER_CAPACITY[layer])-charge
		if remaining<=space: charge+=remaining;remaining=0
		else: remaining-=space;layer+=1;charge=0
	out.merge({"ok":true,"reason":&"paid_growth_available","actor_runtime_id":actor.get_instance_id(),"turn":ctx.turn_count,
		"heat_before":od.current_od,"heat_after":od.current_od-amount,"points_before":econ.current_points,
		"layer_before":od.engine_layer,"charge_before":od.engine_charge,"layer_after":layer,"charge_after":charge,
		"depth_before":ctx.depth_pressure,"depth_gain_before_mitigation":depth_gain,"crossed_depth_thresholds":crossed,
		"ordinary_readiness_unchanged":battle.od_release_rules.get_readiness_threshold()},true)
	return out

func execute(battle: Variant, actor: CardData, amount: int = HEAT_COST) -> Dictionary:
	var quote := inspect(battle,actor,amount)
	if not quote.ok: return quote
	var ctx: Variant=battle.context
	var st: Variant=battle._state_for_card(actor)
	var econ: Dictionary=battle._economy_for_side("player")
	var tx := StringName("paid_hero_growth:%d:turn:%d" % [actor.get_instance_id(),ctx.turn_count])
	# Reserve the full committed payment before native layer/heat callbacks.
	resolving=true;used_turn=ctx.turn_count
	battle._od_release_resolving=true;battle._siege_command_in_progress=true;battle._core_damage_heat_resolving=true;battle._core_command_resolving=true
	econ.current_points-=int(quote.command_cost)
	econ.gross_spent+=int(quote.command_cost)
	for threshold: int in quote.crossed_depth_thresholds: econ.crossed_thresholds.append(threshold)
	if st.get_command_cost_modifier()<0: st.set_command_cost_modifier(0)
	st.last_action=&"paid_hero_growth"
	var conversion: Dictionary=ctx.convert_heat(amount,&"paid_hero_growth",{
		"transaction_id":tx,"conversion_reason":&"paid_hero_growth","occurrence_id":&"conversion",
		"source_descriptor":{"source_kind":&"hero_conversion","source_id":&"paid_hero_growth","source_family":&"paid_growth","source_policy":&"conversion","classified":true},
		"board_cell":battle.get_unit_cell(actor)})
	for threshold: int in quote.crossed_depth_thresholds:
		ctx.add_depth_pressure(battle.tactical_command_economy_rules.get_depth_per_threshold(),"command_gross_%d" % threshold)
	last_receipt={"ok":conversion.get("ok",false),"reason":conversion.get("reason_code",&"conversion_failed"),"transaction_id":tx,
		"actor_runtime_id":actor.get_instance_id(),"turn":used_turn,"command_cost":quote.command_cost,
		"points_before":quote.points_before,"points_after":econ.current_points,"heat_cost":amount,
		"conversion":conversion.duplicate(true),"long_points":amount,"depth_after":ctx.depth_pressure,
		"layer_after":ctx.od_mode.engine_layer,"charge_after":ctx.od_mode.engine_charge}
	battle._od_release_resolving=false;battle._siege_command_in_progress=false;battle._core_damage_heat_resolving=false;battle._core_command_resolving=false
	resolving=false
	battle._emit_unit_state(actor)
	return last_receipt.duplicate(true)
