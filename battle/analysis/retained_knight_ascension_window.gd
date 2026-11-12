extends "res://battle/analysis/a01_end_turn_window.gd"
## Audit-only gate. No resources or game policy are changed by observing a receipt.
var policy := "immediate"
var seen: Dictionary={}
var releases: Array[Dictionary]=[]
# Capture at the native synchronous event, before any delayed observer can reinterpret it.
var _battle_ref: WeakRef
var _commits: Dictionary={}
func is_bound(battle: Variant) -> bool:
	return _battle_ref!=null and _battle_ref.get_ref()==battle
func bind(battle: Variant) -> void:
	if battle==null or (_battle_ref!=null and _battle_ref.get_ref()==battle):return
	var previous: Variant=_battle_ref.get_ref() if _battle_ref!=null else null
	if is_instance_valid(previous) and previous.od_release_event.is_connected(_capture_commit):previous.od_release_event.disconnect(_capture_commit)
	_battle_ref=weakref(battle);_commits.clear()
	battle.od_release_event.connect(_capture_commit)
func _capture_commit(kind: StringName,fact: Dictionary) -> void:
	if kind!=&"od_release_committed":return
	var battle: Variant=_battle_ref.get_ref() if _battle_ref!=null else null
	if not is_instance_valid(battle) or battle.context==null:return
	var tx := str(fact.get("transaction_id",""))
	if tx.is_empty() or _commits.has(tx) or not battle._od_release_transactions.has(StringName(tx)):return
	var ritual: Dictionary=battle.get_final_convergence_status("player")
	_commits[tx]={"fact":fact.duplicate(true),"ritual_claimed":ritual.get("used",false) and not ritual.get("last_receipt",{}).is_empty(),"turn":battle.context.turn_count}
func snapshot() -> Dictionary:
	return {"policy":policy,"seen":seen.keys().duplicate(),"releases":releases.duplicate(true)}
func observe_release(battle: Variant,kind: StringName,fact: Dictionary) -> bool:
	if kind!=&"od_release_committed" or battle==null or battle.context==null:return false
	var tx := str(fact.get("transaction_id",""))
	if _battle_ref==null or _battle_ref.get_ref()!=battle or tx.is_empty() or seen.has(tx) or not _commits.has(tx):return false
	var captured: Dictionary=_commits[tx]
	if captured.fact!=fact:return false
	seen[tx]=true
	var source: CardData=fact.get("source")
	var ritual: Dictionary=battle.get_final_convergence_status("player")
	if not captured.ritual_claimed or int(captured.turn)!=battle.context.turn_count or not ritual.get("used",false) or ritual.get("last_receipt",{}).is_empty():return false
	if not is_instance_valid(source) or source.card_id!="P02" or source.piece_type!=&"knight" or source not in battle.context.player.field:return false
	var state: Variant=battle._state_for_card(source)
	if state==null or state.owner_side!=&"player" or state.current_hp<=0:return false
	var action: Dictionary=fact.get("action_result",{});var move: Dictionary=action.get("move",{});var conversion: Dictionary=fact.get("conversion",{})
	var cost: int=int(battle.od_release_rules.get_piece_command_cost(&"knight"));var amount: int=int(battle.od_release_rules.get_converted_heat())
	if conversion.get("source")!=&"od_release:knight":return false
	if not fact.get("ok",false) or not action.get("ok",false) or not move.get("ok",false) or not conversion.get("ok",false):return false
	if move.get("card")!=source or move.get("owner_side")!="player" or move.get("to_cell")!=battle.get_unit_cell(source) or fact.get("target")!=move.get("to_cell"):return false
	if fact.get("piece_type")!=&"knight" or int(fact.get("command_cost",-1))!=cost or int(action.get("cost",-1))!=cost:return false
	if int(action.get("points_before",0))-int(action.get("points_after",0))!=cost:return false
	if int(conversion.get("amount",0))!=amount or int(fact.get("converted_heat",0))!=amount or int(fact.get("heat_before",0))-int(fact.get("heat_after",0))!=amount:return false
	releases.append({"source_id":source.card_id,"source_runtime_id":source.get_instance_id(),"transaction_id":tx,"turn":battle.context.turn_count,"command_cost":cost,"conversion":conversion.duplicate(true),"from_cell":move.get("from_cell"),"to_cell":move.get("to_cell"),"points_before":action.get("points_before"),"points_after":action.get("points_after")})
	return true
func inspect(battle: Variant) -> Dictionary:
	var q := super.inspect(battle)
	var base: Dictionary=q.duplicate(true);base.erase("source");base.erase("target")
	var ready := false
	for receipt: Dictionary in releases:
		if receipt.source_runtime_id==q.get("source_runtime_id",0):ready=true;break
	q["base_query"]=base;q["retention_policy"]=policy;q["retention_state"]=snapshot();q["post_ritual_conversion_ready"]=ready
	if policy=="retain-after-conversion" and q.eligible and not ready:
		q.eligible=false;q.reason=&"waiting_same_source_conversion"
	return q
