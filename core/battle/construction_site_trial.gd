extends "res://core/battle/building_engineering_trial.gd"
## Opt-in101 physical sites. Native100 reservation semantics remain the default.
var _cancelled: Array[Dictionary]=[]
var _known: Dictionary={}
var _discoveries: Array[Dictionary]=[]

func _init(battle: Variant, selected: Array[String]=["P13","P16"]) -> void:
	super._init(battle)
	var prepared: Array[String]=[]
	for id: String in selected:
		if id in TYPES and id not in prepared:prepared.append(id)
	if prepared.is_empty():prepared.append("P13")
	_book.assign(prepared)
	for id: String in _book:_known[id]=true
	battle.hand_structure_build_committed.connect(_record_hand_build)

func _admission_count() -> int:
	return _serial

func _pending_capacity_count() -> int:
	var count:=0
	for order: Dictionary in _pending:
		if not order.get("site_admitted",false):count+=1
	return count

func site_card(cell: Vector2i) -> CardData:
	for order: Dictionary in _pending:
		if order.cell==cell and order.get("site_admitted",false):return order.card
	return null

func snapshot() -> Dictionary:
	var result:=super.snapshot()
	var sites: Array[Dictionary]=[]
	var b: Variant=_battle.get_ref()
	for order: Dictionary in _pending:
		sites.append({"cell":order.cell,"transaction_id":order.transaction_id,"admitted":order.get("site_admitted",false),"source_runtime_id":order.card.get_instance_id(),"structure":b.get_structure_at_cell(order.cell).duplicate(true)})
	result.merge({"profile":"physical-sites","sites":sites,"cancelled":_cancelled.duplicate(true),"discoveries":_discoveries.duplicate(true),"admissions":_serial})
	return result

func _on_order_paid(order: Dictionary, quote: Dictionary) -> void:
	order.rush=quote.rush
	if quote.rush:return
	var started:=_start_site(order)
	order.reason=started.get("reason_code","") if not started.ok else ""

func _start_site(order: Dictionary) -> Dictionary:
	var b: Variant=_battle.get_ref()
	var card: CardData=order.card
	if b.context.count_active_buildings()>=b.context.ACTIVE_BUILDING_LIMIT:return {"ok":false,"reason_code":"active_building_cap"}
	if b.context.player.traps.size()>=b.MAX_TRAP_SIZE:return {"ok":false,"reason_code":"back_row_cap"}
	var layout: Dictionary=b.get_engineering_structure_layout_status(card,order.cell,{"orientation_edge":order.edge})
	if not layout.ok:return layout
	var plan: Dictionary=layout._structure_plan.duplicate(true)
	# Scaffold wall is weaker than a finished wall; no completed facility behavior.
	for module: Dictionary in plan.modules:
		module.integrity_current=1;module.integrity_max=1
	var board: Variant=b.context.tactical_structure_board_state
	if not board.get_change_status(plan).ok:return {"ok":false,"reason_code":"site_target_stale"}
	var changes: Array[Dictionary]=b._typed_structure_terrain_plan(layout._terrain_plan)
	var skip: Array[StringName]=[]
	var terrain: Dictionary=b._commit_cell_state_changes_composed(changes,&"construction_site",{"defer_signal":true},skip)
	if not terrain.ok:return terrain
	b.context.player.traps.append(card)
	card.set_meta("engineering_site_tx",order.transaction_id)
	var fact:=_commit_site_structure(plan)
	if not fact.ok:
		b.context.player.traps.erase(card);card.remove_meta("engineering_site_tx")
		board.rollback_foundation_reconcile(terrain.get("foundation",{}))
		b.context.tactical_board_state.rollback_changes(terrain.get("terrain",terrain))
		return fact
	order.site_admitted=true;order.site_id=fact.structure.structure_id
	order.initial_core=plan.structure.duplicate(true)
	order.initial_modules=(plan.modules as Array).duplicate(true)
	# Publish only after terrain, structure, source, and paid order are coherent.
	b.context.tactical_board_state.publish_changes_fact(terrain.get("terrain",terrain))
	board.publish_foundation_fact(terrain.get("foundation",{}))
	return {"ok":true,"reason_code":"site_started","structure":fact}

func _commit_site_structure(plan: Dictionary) -> Dictionary:
	return _battle.get_ref().context.tactical_structure_board_state.commit_prevalidated(plan)

func _complete(order: Dictionary) -> Dictionary:
	if order.get("rush",false):return super._complete(order)
	var b: Variant=_battle.get_ref()
	var card: CardData=order.card
	if not order.get("site_admitted",false):
		var started:=_start_site(order)
		if started.ok:
			order.due_turn=b.context.turn_count+1
			return {"ok":false,"reason_code":"site_needs_construction_turn"}
		return started
	var current: Dictionary=b.get_structure_at_cell(order.cell)
	if current.is_empty() or current.get("structure_id")!=order.site_id or int(current.get("source_runtime_id",0))!=card.get_instance_id() or int(current.get("integrity_current",0))<=0 or card not in b.context.player.traps:
		var cancellation:={"ok":true,"reason_code":"site_destroyed_or_replaced","transaction_id":order.transaction_id,"cell":order.cell,"source_runtime_id":card.get_instance_id()}
		_cancelled.append(cancellation.duplicate(true));card.remove_meta("engineering_site_tx")
		return cancellation
	var layout: Dictionary=b.get_engineering_site_completion_status(card,order.cell,order.transaction_id,order.edge)
	if not layout.ok:return layout
	var plan: Dictionary=layout._structure_plan.duplicate(true)
	plan.structure.integrity_current=mini(int(current.integrity_current),int(plan.structure.integrity_max))
	var board: Variant=b.context.tactical_structure_board_state
	for module: Dictionary in plan.modules:
		var existing: Dictionary=board.get_module_at_edge(order.cell,module.edge)
		var initial: Dictionary={}
		for entry: Dictionary in order.initial_modules:
			if entry.edge==module.edge:initial=entry;break
		if existing.is_empty() or initial.is_empty():return {"ok":false,"reason_code":"site_module_identity_changed"}
		if int(existing.integrity_current)<=0:module.integrity_current=0
		else:module.integrity_current=maxi(0,int(module.integrity_max)-(int(initial.integrity_max)-int(existing.integrity_current)))
	var fact: Dictionary=board.commit_prevalidated(plan)
	if not fact.ok:return fact
	card.remove_meta("engineering_site_tx")
	b._ensure_legacy_building_runtime_once(card)
	_entities.append(card)
	return {"ok":true,"reason_code":"site_completed","structure":fact,"transaction_id":order.transaction_id}

func _record_hand_build(card: CardData, fact: Dictionary) -> void:
	var b: Variant=_battle.get_ref()
	if card==null or card.card_id not in TYPES or _known.has(card.card_id) or card not in b.context.player.traps:return
	var spatial: Dictionary=fact.get("structure",{}).get("structure",{})
	if spatial.is_empty() or int(spatial.get("source_runtime_id",0))!=card.get_instance_id() or spatial.get("source_card_id")!=StringName(card.card_id) or card.has_meta("engineering_site_tx"):return
	_known[card.card_id]=true;_book.append(card.card_id)
	_discoveries.append({"card_id":card.card_id,"source_runtime_id":card.get_instance_id(),"turn":b.context.turn_count,"structure_id":spatial.structure_id,"source":"native_hand_build_success"})
