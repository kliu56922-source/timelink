extends RefCounted
##105 read-only advice; actual rules/fees remain owned by the native battle.
var _scene: WeakRef
var _engineering: RefCounted
func _init(scene: Node, engineering: RefCounted) -> void:
	_scene=weakref(scene);_engineering=engineering

func _guard() -> String:
	var scene: Variant=_scene.get_ref()
	if scene==null or scene.context==null:return "unavailable"
	var b: Variant=scene.battle
	if scene.context.player.hp<=0 or scene.context.enemy.hp<=0 or scene.get("battle_ended")==true:return "battle_ended"
	if not b.get_command_economy_snapshot("player").get("turn_open",false):return "not_player_turn"
	if scene.get("_facility_running")==true:return "resolution_busy"
	# Reuse existing selection ownership without treating our own confirmation as a blocker.
	if scene.has_method("_has_non_presentation_end_turn_busy") and scene._has_non_presentation_end_turn_busy():return "resolution_busy"
	if scene.get("_presentation_end_turn_blocked")==true or scene.get("_exit_modal_active")==true:return "resolution_busy"
	var director: Variant=scene.get("_battle_presentation_director")
	if director!=null and is_instance_valid(director) and director.is_busy():return "resolution_busy"

	if b._siege_command_in_progress or b._od_release_resolving or b._core_command_resolving or b._core_damage_heat_resolving:return "resolution_busy"
	return ""

func live_engineered_bodies() -> int:
	var scene: Variant=_scene.get_ref()
	var count:=0
	for source: CardData in _engineering._entities:
		if source not in scene.context.player.traps:continue
		var id: StringName=scene.context.tactical_structure_board_state.get_source_structure_id(source.get_instance_id())
		var body: Dictionary=scene.context.tactical_structure_board_state.get_foundation_status(id)
		if not body.is_empty() and int(body.integrity_current)>0:count+=1
	# An admitted site also reserves the original building slot.
	for order: Dictionary in _engineering._pending:
		if order.get("site_admitted",false):
			var body: Dictionary=scene.battle.get_structure_at_cell(order.cell)
			if not body.is_empty() and body.source_runtime_id==order.card.get_instance_id() and int(body.integrity_current)>0:count+=1
	return count

func inspect_build(cell: Vector2i, rush: bool=false, edge: StringName=&"north", after_actions: bool=false) -> Dictionary:
	var quote: Dictionary=_engineering.inspect(cell,rush,edge)
	var result:={"ok":quote.get("ok",false),"quote":quote,"recommended":false,"advice_code":str(quote.get("reason_code","unavailable")),"warnings":[]}
	if not result.ok:return result
	var scene: Variant=_scene.get_ref()
	var threshold: int=scene.battle.od_release_rules.get_readiness_threshold()
	if rush and int(quote.heat_before)>=threshold and int(quote.heat_before)-int(quote.heat_cost)<threshold:result.warnings.append("rush_breaks_od_readiness")
	if scene.battle.get_od_release_status("player").get("ok",false):result.warnings.append("current_od_opportunity_first")
	if live_engineered_bodies()>=1 or not _engineering._pending.is_empty():result.advice_code="reserve_existing_building_route"
	elif not after_actions:result.advice_code="finish_combat_actions_first"
	elif rush and int(quote.heat_before)>=threshold and int(quote.heat_before)-int(quote.heat_cost)<threshold:result.advice_code="rush_breaks_od_readiness"
	elif scene.battle.get_od_release_status("player").get("ok",false):result.advice_code="current_od_opportunity_first"
	else:result.recommended=true;result.advice_code="remaining_command_construction"
	result.live_engineered_bodies=live_engineered_bodies()
	return result

func inspect_facility(card: CardData, next_command_cost: int=0) -> Dictionary:
	var reason:=_guard()
	if reason!="":return {"ok":false,"reason_code":reason}
	var scene: Variant=_scene.get_ref()
	var b: Variant=scene.battle
	if card==null or not is_instance_valid(card) or card.card_id not in ["P13","P16"] or card not in scene.context.player.traps or card.has_meta("engineering_site_tx"):return {"ok":false,"reason_code":"facility_source_unavailable"}
	var board: Variant=scene.context.tactical_structure_board_state
	var id: StringName=board.get_source_structure_id(card.get_instance_id())
	var body: Dictionary=board.get_foundation_status(id)
	if body.is_empty() or body.owner_side!=&"player" or int(body.integrity_current)<=0 or int(body.source_runtime_id)!=card.get_instance_id():return {"ok":false,"reason_code":"facility_source_unavailable"}
	var native: Dictionary=b.get_building_interface_status(card,scene.context.player)
	if not native.ok:return {"ok":false,"reason_code":str(native.reason_code)}
	if next_command_cost<0:return {"ok":false,"reason_code":"invalid_next_command_cost"}
	var state: Dictionary=b.get_building_state(card)
	var heat: int=scene.context.od_mode.current_od
	var heat_cost:=1 if card.card_id=="P13" and scene.context.player.od>=1 else 0
	var charge_cost:=1 if (card.card_id=="P13" and heat_cost==0) or (card.card_id=="P16" and int(state.charge)>=1) else 0
	var economy: Dictionary=b.get_command_economy_snapshot("player")
	var gain:=0
	for threshold: int in b.tactical_command_economy_rules.get_depth_thresholds():
		if threshold>int(economy.gross_spent) and threshold<=int(economy.gross_spent)+maxi(0,next_command_cost) and threshold not in economy.crossed_thresholds:gain+=b.tactical_command_economy_rules.get_depth_per_threshold()
	var advice:="no_current_facility_need"
	var recommended:=false
	if card.card_id=="P13":
		var threshold: int=b.od_release_rules.get_readiness_threshold()
		if heat>=threshold and heat-heat_cost<threshold:advice="facility_breaks_od_readiness"
		elif next_command_cost>0 and not b.can_pay_command_cost("player",next_command_cost):advice="next_action_unaffordable"
		elif int(scene.context.pending_depth_reduction)>=gain and int(scene.context.pending_depth_reduction)>0:advice="depth_guard_already_prepared"
		elif gain>int(scene.context.pending_depth_reduction):advice="prepare_known_depth_crossing";recommended=true
	else:
		var threat: bool=scene.context.player.hp<35
		for enemy: CardData in scene.context.enemy.field:
			var st: Variant=b._state_for_card(enemy)
			if st!=null and not st.is_dead():threat=true
		if scene.context.player.shield<2 and threat:advice="shield_for_current_pressure";recommended=true
	return {"ok":true,"reason_code":"ok","recommended":recommended,"advice_code":advice,"source_runtime_id":card.get_instance_id(),"card_id":card.card_id,"turn":scene.context.turn_count,"body":body.duplicate(true),"native":native.duplicate(true),"state":state.duplicate(true),"heat_before":heat,"legacy_heat_before":scene.context.player.od,"heat_cost":heat_cost,"charge_cost":charge_cost,"shield_gain":(3 if charge_cost>0 else 2) if card.card_id=="P16" else 0,"shield_before":scene.context.player.shield,"points_before":economy.current_points,"gross_before":economy.gross_spent,"depth_before":scene.context.depth_pressure,"pending_before":scene.context.pending_depth_reduction,"next_command_cost":next_command_cost,"projected_depth_gain":gain,"structure_revision":board.get_revision(),"source_deck_ids":_deck_ids()}

func _deck_ids() -> Array[int]:
	var result: Array[int]=[]
	for card: CardData in _scene.get_ref().context.player.deck:result.append(card.get_instance_id())
	return result
