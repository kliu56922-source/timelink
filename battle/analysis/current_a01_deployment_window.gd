extends RefCounted
## Audit only. Current paid placement for an actual retained-source ascension.
## It never moves a unit to obtain a quote or predicts a later Boss decision.
func projected_core(battle: Variant,actor: CardData,cell: Vector2i) -> Dictionary:
	var st: Variant=battle._state_for_card(actor)
	var q := {"ok":false,"reason":&"not_breach_rank","interceptor_runtime_id":0,"blocked_runtime_id":0}
	if cell.y!=battle.tactical_core_facing_rules.get_breach_rank(&"player"):return q
	if st.get_facing_rank_delta()!=battle.tactical_core_facing_rules.get_default_facing(&"player"):q.reason=&"facing_away_from_core";return q
	var radius: int=battle.tactical_core_facing_rules.get_guard_intercept_column_radius()
	for guard: CardData in battle.context.enemy.field:
		var gs: Variant=battle._state_for_card(guard)
		var gc: Vector2i=battle.get_unit_cell(guard)
		if guard.is_guard_card and gs!=null and not gs.is_dead() and gc!=battle.INVALID_GRID_CELL and absi(gc.x-cell.x)<=radius:
			q.reason=&"guard_intercepted";q.interceptor_runtime_id=guard.get_instance_id();return q
	for target_cell: Vector2i in battle._get_pattern_attack_cells(actor,cell,&"player"):
		var other: CardData=battle.get_unit_at_cell(target_cell)
		var os: Variant=battle._state_for_card(other) if other!=null else null
		if os!=null and not os.is_dead() and os.owner_side!=&"player":q.reason=&"front_arc_blocked";q.blocked_runtime_id=other.get_instance_id();return q
	q.ok=true;q.reason=&"ok";return q
func inspect(battle: Variant,ascended_runtime_id: int,attempted: bool=false) -> Dictionary:
	var q := {"eligible":false,"reason":&"unavailable","source_runtime_id":0,"source_id":"","source_cell":Vector2i(-1,-1),"source_hp":0,"charge_cost":1,"candidates":[],"cell":Vector2i(-1,-1),"scope":&"current_paid_a01_core_geometry_only"}
	if attempted:q.reason=&"attempt_already_used";return q
	if battle==null or battle.context==null:return q
	var ctx: Variant=battle.context
	if ctx.player==null or ctx.enemy==null or ctx.player.hp<=0 or ctx.enemy.hp<=0:return q
	if not battle.get_final_convergence_status("player").get("used",false) or not ctx.arsenal_mid_used:q.reason=&"ritual_or_mid_gate";return q
	var actor: CardData
	for card: CardData in ctx.player.field:
		if card.get_instance_id()==ascended_runtime_id and card.card_id=="A01" and battle.get_unit_current_hp(card)>0:actor=card;break
	if actor==null:q.reason=&"ascended_source_missing";return q
	q.source=actor;q.source_runtime_id=actor.get_instance_id();q.source_id=actor.card_id;q.source_cell=battle.get_unit_cell(actor);q.source_hp=battle.get_unit_current_hp(actor)
	var first: CardData
	for card: CardData in ctx.player.field:
		if (card.card_family=="monster" or card.card_type==CardData.CardType.UNIT) and battle.get_unit_lane(card)>=0:first=card;break
	if first!=actor:q.reason=&"gui_source_mismatch";return q
	var st: Variant=battle._state_for_card(actor)
	if st==null or st.owner_side!=&"player" or not battle.can_monster_attack(actor).get("ok",false) or st.actions_used>0 or st.attacks_used>0:q.reason=&"source_not_ready";return q
	if st.get_facing_rank_delta()!=battle.tactical_core_facing_rules.get_default_facing(&"player"):q.reason=&"source_wrong_facing";return q
	if battle.get_core_attack_cell_status(actor).get("ok",false):q.reason=&"already_current_core_access";return q
	var cells: Array[Vector2i]=battle.get_legal_move_cells(actor,battle.MOVE_CORE_REDEPLOY)
	cells.sort_custom(func(a: Vector2i,b: Vector2i):
		var da: int=absi(a.x-q.source_cell.x)+absi(a.y-q.source_cell.y);var db: int=absi(b.x-q.source_cell.x)+absi(b.y-q.source_cell.y)
		return da<db if da!=db else a.y<b.y if a.y!=b.y else a.x<b.x)
	for cell: Vector2i in cells:
		if cell.y!=battle.tactical_core_facing_rules.get_breach_rank(&"player"):continue
		var native: Dictionary=battle.get_core_command_status(&"redeploy",{"card":actor,"cell":cell});var geometry := projected_core(battle,actor,cell)
		var accepted: bool=native.get("ok",false) and geometry.ok
		q.candidates.append({"cell":cell,"native":native,"geometry":geometry,"accepted":accepted})
		if accepted:q.eligible=true;q.reason=&"current_paid_a01_deployment";q.cell=cell;return q
	q.reason=&"no_current_legal_core_cell";return q
