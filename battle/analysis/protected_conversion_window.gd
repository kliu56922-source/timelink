extends RefCounted
## Audit-only current ordinary window after the caller's actual paid protection.
const Tradeoff := preload("res://battle/analysis/empty_knight_od_tradeoff.gd")
func inspect(battle: Variant,protected_runtime_id: int,attempted: bool=false) -> Dictionary:
	var q := {"eligible":false,"reason":&"unavailable","source_runtime_id":0,"source_id":"","source_cell":Vector2i(-1,-1),"source_hp":0,"cell":Vector2i(-1,-1),"command_cost":0,"od_cost":0,"tradeoff":{},"native":{},"scope":&"current_protected_empty_conversion_only"}
	if battle==null or battle.context==null:return q
	if attempted:q.reason=&"attempt_already_used";return q
	var ctx: Variant=battle.context
	if protected_runtime_id<=0:q.reason=&"no_paid_protected_source";return q
	if ctx.player==null or ctx.enemy==null or ctx.player.hp<=0 or ctx.enemy.hp<=0:return q
	if not battle.get_final_convergence_status("player").get("used",false) or ctx.arsenal_mid_used:q.reason=&"ritual_or_mid_gate";return q
	var source: CardData
	for card: CardData in ctx.player.field:
		if card.get_instance_id()==protected_runtime_id and card.card_id=="P02" and card.piece_type==&"knight" and battle.get_unit_current_hp(card)>0:source=card;break
	if source==null:q.reason=&"protected_source_missing";return q
	q.source=source;q.source_runtime_id=protected_runtime_id;q.source_id=source.card_id;q.source_cell=battle.get_unit_cell(source);q.source_hp=battle.get_unit_current_hp(source)
	q.tradeoff=Tradeoff.new().inspect(battle)
	if not q.tradeoff.hold:q.reason=&"not_current_empty_hold";return q
	if q.tradeoff.source_runtime_id!=protected_runtime_id:q.reason=&"other_source_first";return q
	var plan: Dictionary=battle.get_od_release_source_status(source)
	if not plan.get("ok",false):q.reason=&"source_not_legal";return q
	var cells: Array=plan.get("legal_cells",[]).duplicate()
	cells.sort_custom(func(a: Vector2i,b: Vector2i):return a.y<b.y if a.y!=b.y else a.x<b.x)
	if cells.is_empty():q.reason=&"no_legal_cell";return q
	q.cell=cells[0];q.native=battle.get_od_release_target_status(source,q.cell)
	q.command_cost=int(q.native.get("command_cost",0));q.od_cost=int(q.native.get("od_cost",0))
	if not q.native.get("ok",false):q.reason=&"target_not_legal";return q
	q.eligible=true;q.reason=&"current_paid_empty_conversion"
	return q
