extends "res://core/battle/first_core_damage_heat_trial.gd"
## Optional pending scalar packet. No live card reference or early heat publication.
var _pending: Dictionary={}
var _last_settlement: Dictionary={}
func snapshot(battle) -> Dictionary:
	var result := super.snapshot(battle)
	result.amount=1 if profile=="ascended-delayed-core-heat" else result.amount
	result["pending"]=_pending.duplicate(true);result["last_settlement"]=_last_settlement.duplicate(true)
	return result
func commit(battle,actor: CardData,command_id: String,actual_hp_loss: int) -> Dictionary:
	if profile!="ascended-delayed-core-heat":return super.commit(battle,actor,command_id,actual_hp_loss)
	return commit_paid(battle,actor,command_id,actual_hp_loss,0)
func commit_paid(battle,actor: CardData,command_id: String,actual_hp_loss: int,command_cost: int) -> Dictionary:
	var result := {"applied":0,"reason":"no_committed_core_hp_hit","actual_hp_loss":actual_hp_loss,"command_cost":command_cost}
	var ctx=battle.context;var st=battle._state_for_card(actor)
	if ctx==null or ctx.player==null or ctx.enemy==null or ctx.player.hp<=0 or ctx.enemy.hp<=0:result.reason="ended";return result
	if actual_hp_loss<=0 or st==null or st.owner_side!=&"player" or st.is_dead() or command_id!="attack_core":return result
	if actor.card_id!="A01" or not actor.is_ascension_form or not ctx.player.field.has(actor):result.reason="not_ascended_hero";return result
	if command_cost<=0:result.reason="unpaid_core_hit";return result
	if not battle.get_command_economy_snapshot("player").get("turn_open",false):result.reason="closed";return result
	if _used_turn==ctx.turn_count:result.reason="already_used";return result
	if not _pending.is_empty() and ctx.turn_count>int(_pending.created_turn)+1:_expire(battle)
	if not _pending.is_empty():result.reason="packet_pending";return result
	_used_turn=ctx.turn_count
	_pending={"event_key":"core_ember:turn:%d"%ctx.turn_count,"created_turn":ctx.turn_count,"actor_id":actor.card_id,"actor_runtime_id":actor.get_instance_id(),"command_id":command_id,"command_cost":command_cost,"actual_hp_loss":actual_hp_loss,"amount":1}
	result.merge({"event_key":_pending.event_key,"turn":ctx.turn_count,"actor_id":actor.card_id,"actor_runtime_id":actor.get_instance_id(),"command_id":command_id,"heat_before":ctx.od_mode.current_od,"heat_after":ctx.od_mode.current_od,"pending":1,"reason":"deferred"},true)
	_last_receipt=result.duplicate(true)
	return result
func _expire(battle) -> Dictionary:
	var result := _pending.duplicate(true);_pending.clear()
	result.merge({"applied":0,"reason":"expired","turn":battle.context.turn_count,"heat_before":battle.context.od_mode.current_od,"heat_after":battle.context.od_mode.current_od},true)
	_last_settlement=result.duplicate(true)
	return result
func settle(battle) -> Dictionary:
	var result := {"applied":0,"reason":"no_pending"}
	if _pending.is_empty():return result
	var ctx=battle.context
	if ctx==null or ctx.player==null or ctx.enemy==null:return result
	if ctx.turn_count<=int(_pending.created_turn):result.reason="not_next_player_window";return result
	if ctx.turn_count>int(_pending.created_turn)+1:return _expire(battle)
	if not battle.get_command_economy_snapshot("player").get("turn_open",false):result.reason="closed";return result
	# Consume before real heat callbacks, even cancellation/full heat/shared cap.
	var packet := _pending.duplicate(true);_pending.clear()
	result.merge(packet,true);result["turn"]=ctx.turn_count;result["heat_before"]=ctx.od_mode.current_od
	var actor: CardData=null
	for card: CardData in ctx.player.field:
		if card.get_instance_id()==int(packet.actor_runtime_id):actor=card;break
	var state=battle._state_for_card(actor) if actor!=null else null
	if ctx.player.hp<=0 or ctx.enemy.hp<=0:result.reason="ended"
	elif actor==null or state==null or state.is_dead() or state.owner_side!=&"player" or actor.card_id!="A01" or not actor.is_ascension_form:result.reason="source_not_alive"
	else:
		var paid: Dictionary=ctx._apply_stable_combat_od(&"first_core_damage_ember",int(packet.amount),true)
		result["stable_receipt"]=paid.duplicate(true);result.applied=int(paid.get("applied",0));result.reason=str(paid.get("reason",""))
	result["heat_after"]=ctx.od_mode.current_od
	_last_settlement=result.duplicate(true)
	return result
