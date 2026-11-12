extends RefCounted
## Audit only: actual current exchange and public board geometry, never a future turn.
const Risk := preload("res://battle/analysis/current_unit_combat_risk.gd")
var risk := Risk.new()
func inspect(battle: Variant,attempted: bool=false) -> Dictionary:
	var q := {"eligible":false,"reason":&"unavailable","source_runtime_id":0,"source_id":"","source_cell":Vector2i(-1,-1),"source_hp":0,"charge_cost":1,"risks":[],"candidates":[],"cell":Vector2i(-1,-1),"scope":&"current_geometry_not_future_safety"}
	if battle==null or battle.context==null:return q
	var ctx: Variant=battle.context
	if attempted:q.reason=&"attempt_already_used";return q
	if ctx.player==null or ctx.enemy==null or ctx.player.hp<=0 or ctx.enemy.hp<=0:return q
	if not battle.get_final_convergence_status("player").get("used",false) or ctx.arsenal_mid_used:q.reason=&"ritual_or_mid_gate";return q
	var source: CardData
	for card: CardData in ctx.player.field:
		if card.card_id=="P02" and card.piece_type==&"knight" and battle.get_unit_current_hp(card)>0:source=card;break
	if source==null:q.reason=&"source_missing";return q
	q.source=source;q.source_id=source.card_id;q.source_runtime_id=source.get_instance_id();q.source_cell=battle.get_unit_cell(source);q.source_hp=battle.get_unit_current_hp(source)
	var first: CardData
	for card: CardData in ctx.player.field:
		if (card.card_family=="monster" or card.card_type==CardData.CardType.UNIT) and battle.get_unit_lane(card)>=0:first=card;break
	if first!=source:q.reason=&"gui_source_mismatch";return q
	var fatal := false
	for target: CardData in battle.get_legal_attack_targets(source):
		var current: Dictionary=risk.inspect(battle,source,target)
		q.risks.append(current)
		if current.get("prediction_available",false) and current.get("actor_will_die",false):fatal=true
	if not fatal:q.reason=&"no_known_fatal_exchange";return q
	var cells: Array[Vector2i]=battle.get_legal_move_cells(source,battle.MOVE_CORE_REDEPLOY)
	cells.sort_custom(func(a: Vector2i,b: Vector2i):
		var da: int=absi(a.x-q.source_cell.x)+absi(a.y-q.source_cell.y);var db: int=absi(b.x-q.source_cell.x)+absi(b.y-q.source_cell.y)
		return da<db if da!=db else a.y<b.y if a.y!=b.y else a.x<b.x)
	for cell: Vector2i in cells:
		var native: Dictionary=battle.get_core_command_status(&"redeploy",{"card":source,"cell":cell})
		var outgoing: Array[int]=[]
		for target: CardData in battle.get_legal_attack_targets(source,cell):outgoing.append(target.get_instance_id())
		var incoming: Array[int]=[]
		for target: CardData in ctx.enemy.field:
			if cell in battle.get_legal_attack_cells(target):incoming.append(target.get_instance_id())
		var accepted: bool=native.get("ok",false) and outgoing.is_empty() and incoming.is_empty()
		q.candidates.append({"cell":cell,"native":native,"outgoing":outgoing,"incoming":incoming,"accepted":accepted})
		if accepted:q.eligible=true;q.reason=&"current_paid_protection_window";q.cell=cell;break
	if not q.eligible:q.reason=&"no_current_legal_protection_cell"
	return q
