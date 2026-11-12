extends RefCounted
## Audit-only request order. Native selector owns the ordinary action;
## native command and paid-growth service own the two separate payments.
const Payoff := preload("res://battle/analysis/current_core_payoff_preview.gd")

func inspect(battle: Variant, growth: RefCounted, picker: RefCounted, actor: CardData) -> Dictionary:
	var out := {"eligible":false,"reason":&"unavailable","actor_runtime_id":0,"core":{},"growth":{},
		"growth_cost_after_core":0,"combined_cost":0,"selector":{},"scope":&"two_current_paid_requests_no_future_board"}
	if battle==null or growth==null or picker==null: return out
	var q: Dictionary=growth.inspect(battle,actor)
	out.growth=q
	if not q.ok:out.reason=q.reason;return out
	var core: Dictionary=Payoff.new().inspect(battle,actor,&"attack_core")
	out.core=core
	if not core.ok or not core.comparable or core.cost<=0 or core.hp_loss<=0 or core.hp_loss>=battle.context.enemy.hp:
		out.reason=&"core_payoff_unknown_or_terminal";return out
	var choice: Dictionary=picker.get_decision(battle)
	out.selector={"ok":choice.get("ok",false),"command":str(choice.get("command",&"")),"cost":choice.get("cost",0),
		"actor_runtime_id":choice.actor.get_instance_id() if is_instance_valid(choice.get("actor")) else 0,
		"origin":str(choice.get("origin",Vector2i(-1,-1)))}
	if not choice.get("ok",false) or choice.get("actor")!=actor or choice.get("command")!=&"attack_core" or int(choice.get("cost",0))!=int(core.cost):
		out.reason=&"original_selector_other_request";return out
	var ctx: Variant=battle.context
	var econ: Dictionary=battle.get_command_economy_snapshot("player")
	var rules: Variant=battle.tactical_command_economy_rules
	var gain := 0
	for threshold: int in rules.get_depth_thresholds():
		if threshold>int(econ.gross_spent) and threshold<=int(econ.gross_spent)+int(core.cost) and not threshold in econ.crossed_thresholds:
			gain+=rules.get_depth_per_threshold()
	var depth_after_core: int=int(ctx.depth_pressure)+maxi(0,gain-int(ctx.pending_depth_reduction))
	var st: Variant=battle._state_for_card(actor)
	# Native ordinary payment consumes a negative local modifier once. Warning
	# starts at four in the existing BattleContext; re-quote again after commit.
	var surcharge: int=rules.get_skill_surcharge("Warning" if depth_after_core>=4 else "Stable")
	var next_fee: int=maxi(1,rules.get_active_skill_cost()+maxi(0,st.get_command_cost_modifier())+surcharge)
	out.growth_cost_after_core=next_fee;out.combined_cost=int(core.cost)+next_fee
	var combined_gain := 0
	for threshold: int in rules.get_depth_thresholds():
		if threshold>int(econ.gross_spent) and threshold<=int(econ.gross_spent)+int(out.combined_cost) and not threshold in econ.crossed_thresholds:
			combined_gain+=rules.get_depth_per_threshold()
	if int(ctx.depth_pressure)+maxi(0,combined_gain-int(ctx.pending_depth_reduction))>=ctx.get_depth_max_value():
		out.reason=&"combined_payment_backlash_boundary";return out
	if int(econ.current_points)<int(out.combined_cost):out.reason=&"both_payments_do_not_fit";return out
	out.actor_runtime_id=actor.get_instance_id();out.eligible=true;out.reason=&"original_selected_core_then_paid_growth"
	return out
