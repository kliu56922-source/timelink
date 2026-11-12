extends RefCounted
## Phase 100 opt-in prototype. Book actions never masquerade as hand plays.
const Loader := preload("res://core/deck/card_catalog_loader.gd")
const TYPES := ["P13", "P16"]
const COMMAND_COST := 2
const RUSH_HEAT := 2
const TOTAL_CAP := 4
var _battle: WeakRef
var _book: Array[String] = ["P13", "P16"]
var _cursor := 0
var _plan: CardData
var _from_hand := false
var _begun_turn := -1
var _used_turn := -1
var _staged_turn := -1
var _serial := 0
var _resolving := false
var _pending: Array[Dictionary] = []
var _entities: Array[CardData] = []
var _receipts: Array[Dictionary] = []

func _init(battle: Variant) -> void:
	_battle=weakref(battle)

func _card(id: String) -> CardData:
	var loader := Loader.new()
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/cards/player_cards_20.json"))
	for row: Dictionary in data.cards:
		if row.id==id:
			var card: CardData=loader.convert_to_carddata(row)
			_battle.get_ref().context.add_child(card)
			loader.free();return card
	loader.free();return null

func _guard() -> String:
	var b: Variant=_battle.get_ref()
	if b==null or b.context==null:return "unavailable"
	if _resolving or b._od_release_resolving or b._siege_command_in_progress or b._core_command_resolving or b._core_damage_heat_resolving:return "resolution_busy"
	if b.context.player.hp<=0 or b.context.enemy.hp<=0:return "battle_ended"
	if not b.get_command_economy_snapshot("player").get("turn_open",false):return "not_player_turn"
	if b.context.is_abyss_locked():return "backlash_restricted"
	return ""

func snapshot() -> Dictionary:
	var orders: Array[Dictionary]=[]
	for order: Dictionary in _pending:
		orders.append({"transaction_id":order.transaction_id,"card_id":order.card.card_id,"cell":order.cell,"due_turn":order.due_turn,"reason":order.get("reason","")})
	return {"plan":_plan.card_id if _plan!=null else "","from_hand":_from_hand,"book":_book.duplicate(),"cursor":_cursor,"begun_turn":_begun_turn,"used_turn":_used_turn,"staged_turn":_staged_turn,"pending":orders,"completed":_entities.size(),"receipts":_receipts.duplicate(true)}

func begin_player_turn() -> void:
	if _guard()!="":return
	var b: Variant=_battle.get_ref()
	if _begun_turn==b.context.turn_count:return
	_begun_turn=b.context.turn_count
	_lock(true)
	# One attempt per real own turn. A blocked paid order is retained, without repayment.
	for order: Dictionary in _pending.duplicate():
		if int(order.due_turn)>_begun_turn:continue
		var result := _complete(order)
		if result.ok:_pending.erase(order)
		else:order.reason=result.reason_code
	if _plan==null:
		_plan=_card(_book[_cursor % _book.size()]);_cursor+=1;_from_hand=false
	_lock(false)

func _lock(value: bool) -> void:
	var b: Variant=_battle.get_ref()
	_resolving=value
	b._siege_command_in_progress=value;b._od_release_resolving=value;b._core_command_resolving=value;b._core_damage_heat_resolving=value

func stage(card: CardData) -> Dictionary:
	var reason:=_guard()
	if reason!="":return {"ok":false,"reason_code":reason}
	var b: Variant=_battle.get_ref()
	if _plan!=null:return {"ok":false,"reason_code":"engineering_slot_occupied"}
	if _staged_turn==b.context.turn_count:return {"ok":false,"reason_code":"already_staged_this_turn"}
	if card==null or card.card_id not in TYPES or card not in b.context.player.hand:return {"ok":false,"reason_code":"invalid_hand_blueprint"}
	_staged_turn=b.context.turn_count;_plan=card;_from_hand=true
	b.context.player.hand.erase(card)
	return {"ok":true,"reason_code":"staged","source_runtime_id":card.get_instance_id()}

## Phase101 extension points; defaults preserve the sealed100 reservation profile.
func _admission_count() -> int:
	return _entities.size()+_pending.size()

func _pending_capacity_count() -> int:
	return _pending.size()

func _on_order_paid(_order: Dictionary, _quote: Dictionary) -> void:
	pass

func inspect(cell: Vector2i, rush: bool=false, edge: StringName=&"north") -> Dictionary:
	var reason:=_guard()
	if reason!="":return {"ok":false,"reason_code":reason}
	var b: Variant=_battle.get_ref()
	if _plan==null:return {"ok":false,"reason_code":"no_engineering_plan"}
	if _used_turn==b.context.turn_count:return {"ok":false,"reason_code":"already_built_this_turn"}
	if _admission_count()>=TOTAL_CAP:return {"ok":false,"reason_code":"engineering_total_cap"}
	if b.context.count_active_buildings()+_pending_capacity_count()>=b.context.ACTIVE_BUILDING_LIMIT:return {"ok":false,"reason_code":"active_building_cap"}
	if b.context.player.traps.size()+_pending_capacity_count()>=b.MAX_TRAP_SIZE:return {"ok":false,"reason_code":"back_row_cap"}
	for order: Dictionary in _pending:
		if order.cell==cell:return {"ok":false,"reason_code":"engineering_cell_reserved"}
	var layout: Dictionary=b.get_engineering_structure_layout_status(_plan,cell,{"orientation_edge":edge})
	if not layout.ok:return layout
	var econ: Dictionary=b.get_command_economy_snapshot("player")
	if not b.can_pay_command_cost("player",COMMAND_COST):return {"ok":false,"reason_code":"insufficient_command_points"}
	var heat_cost:=RUSH_HEAT if rush else 0
	if b.context.od_mode.current_od<heat_cost:return {"ok":false,"reason_code":"insufficient_heat"}
	var crossed: Array[int]=[]
	for threshold: int in b.tactical_command_economy_rules.get_depth_thresholds():
		if threshold>int(econ.gross_spent) and threshold<=int(econ.gross_spent)+COMMAND_COST and threshold not in econ.crossed_thresholds:crossed.append(threshold)
	var depth_gain: int=crossed.size()*b.tactical_command_economy_rules.get_depth_per_threshold()
	# Prototype restriction, consistent with paid growth: no committing through a Backlash reset.
	if b.context.depth_pressure+maxi(0,depth_gain-int(b.context.pending_depth_reduction))>=b.context.get_depth_max_value():return {"ok":false,"reason_code":"payment_backlash_boundary"}
	return {"ok":true,"reason_code":"ok","turn":b.context.turn_count,"cell":cell,"edge":edge,"rush":rush,"command_cost":COMMAND_COST,"heat_cost":heat_cost,"points_before":econ.current_points,"gross_before":econ.gross_spent,"heat_before":b.context.od_mode.current_od,"depth_before":b.context.depth_pressure,"crossed":crossed,"source_runtime_id":_plan.get_instance_id(),"layout":layout}

func execute(cell: Vector2i, rush: bool=false, expected: Dictionary={}, edge: StringName=&"north") -> Dictionary:
	var quote:=inspect(cell,rush,edge)
	if not quote.ok:return quote
	if not expected.is_empty() and quote!=expected:return {"ok":false,"reason_code":"engineering_quote_stale"}
	var b: Variant=_battle.get_ref()
	var ctx: Variant=b.context
	var econ: Dictionary=b._economy_for_side("player")
	_serial+=1
	var tx:="engineering:%d:%d:turn:%d"%[get_instance_id(),_serial,ctx.turn_count]
	# Reserve slot, once, fee, and gross before any native callback.
	_resolving=true;_used_turn=ctx.turn_count
	b._siege_command_in_progress=true;b._od_release_resolving=true;b._core_command_resolving=true;b._core_damage_heat_resolving=true
	var entity: CardData=CardData.clone_card_entity(_plan)
	b.context.add_child(entity)
	if _from_hand:ctx.player.discard.append(_plan)
	_plan=null;_from_hand=false
	econ.current_points-=COMMAND_COST;econ.gross_spent+=COMMAND_COST
	for threshold: int in quote.crossed:econ.crossed_thresholds.append(threshold)
	var order:={"transaction_id":tx,"card":entity,"cell":cell,"edge":edge,"due_turn":ctx.turn_count+(0 if rush else 1)}
	_pending.append(order)
	_on_order_paid(order,quote)
	if rush:ctx.add_heat(-RUSH_HEAT,&"engineering_rush",StringName(tx))
	for threshold: int in quote.crossed:ctx.add_depth_pressure(b.tactical_command_economy_rules.get_depth_per_threshold(),"command_gross_%d"%threshold)
	var completion: Dictionary={"ok":false,"reason_code":"scheduled"}
	if rush:
		completion=_complete(order)
		if completion.ok:_pending.erase(order)
		else:order.reason=completion.reason_code
	var receipt:={"ok":true,"reason_code":"paid","transaction_id":tx,"source_runtime_id":quote.source_runtime_id,"entity_runtime_id":entity.get_instance_id(),"card_id":entity.card_id,"cell":cell,"command_cost":COMMAND_COST,"heat_cost":quote.heat_cost,"points_before":quote.points_before,"points_after":econ.current_points,"gross_after":econ.gross_spent,"depth_before":quote.depth_before,"depth_after":ctx.depth_pressure,"heat_before":quote.heat_before,"heat_after":ctx.od_mode.current_od,"long_points":0,"completion":completion}
	_receipts.append(receipt.duplicate(true))
	b._siege_command_in_progress=false;b._od_release_resolving=false;b._core_command_resolving=false;b._core_damage_heat_resolving=false
	_resolving=false
	return receipt.duplicate(true)

func _complete(order: Dictionary) -> Dictionary:
	var b: Variant=_battle.get_ref()
	var card: CardData=order.card
	if b.context.count_active_buildings()>=b.context.ACTIVE_BUILDING_LIMIT:return {"ok":false,"reason_code":"active_building_cap"}
	if b.context.player.traps.size()>=b.MAX_TRAP_SIZE:return {"ok":false,"reason_code":"back_row_cap"}
	var layout: Dictionary=b.get_engineering_structure_layout_status(card,order.cell,{"orientation_edge":order.edge})
	if not layout.ok:return layout
	var terrain_plan: Array[Dictionary]=b._typed_structure_terrain_plan(layout.get("_terrain_plan",[]))
	var terrain: Dictionary=b.get_cell_state_change_status(terrain_plan)
	var board: Variant=b.context.tactical_structure_board_state
	if not terrain.ok or not board.get_change_status(layout._structure_plan).ok:return {"ok":false,"reason_code":"engineering_target_stale"}
	# Native source_kind describes the live CardData holder, not acquisition.
	# Keep "card" for siege/cleanup; engineering provenance stays in the receipt.
	var skipped: Array[StringName]=[]
	var terrain_fact: Dictionary=b._commit_cell_state_changes_composed(terrain_plan,&"engineering_complete",{},skipped)
	if not terrain_fact.ok:return terrain_fact
	var fact: Dictionary=board.commit_prevalidated(layout._structure_plan)
	if not fact.ok:return fact
	# Facility behavior becomes active only after a genuine board entity exists.
	b.context.player.traps.append(card);b._ensure_legacy_building_runtime_once(card)
	_entities.append(card)
	return {"ok":true,"reason_code":"completed","structure":fact,"transaction_id":order.transaction_id}
