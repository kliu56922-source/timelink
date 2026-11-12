extends RefCounted
## Independent optional profile; only native successful committed core HP hits call commit.
## Positive heat uses the existing shared stable-combat cap and committed-heat event pipeline.
var profile := "original"
var _used_turn := -1
var _last_receipt: Dictionary = {}
func _init(value: String) -> void:
	profile=value
func snapshot(battle) -> Dictionary:
	return {"profile":profile,"amount":1 if profile in ["first-core-heat","ascended-core-heat"] else 0,"used":_used_turn==battle.context.turn_count,"turn":battle.context.turn_count,"last_receipt":_last_receipt.duplicate(true)}
func commit(battle,actor: CardData,command_id: String,actual_hp_loss: int) -> Dictionary:
	var result := {"applied":0,"reason":"disabled","actual_hp_loss":actual_hp_loss}
	if profile not in ["first-core-heat","ascended-core-heat"]:return result
	var ctx = battle.context
	var st = battle._state_for_card(actor)
	if ctx==null or ctx.player==null or ctx.enemy==null or ctx.player.hp<=0 or ctx.enemy.hp<=0:
		result.reason="ended";return result
	if actual_hp_loss<=0 or st==null or st.owner_side!=&"player" or st.is_dead() or command_id not in ["attack_core","stream_cannon"]:
		result.reason="no_committed_core_hp_hit";return result
	# PHASE65_BEGIN_HERO_GATE
	if profile=="ascended-core-heat" and (actor.card_id!="A01" or not actor.is_ascension_form or not ctx.player.field.has(actor)):
		result.reason="not_ascended_hero";return result
	# PHASE65_END_HERO_GATE
	if not battle.get_command_economy_snapshot("player").get("turn_open",false):
		result.reason="closed";return result
	if _used_turn==ctx.turn_count:
		result.reason="already_used";return result
	# Reserve before add_heat publishes any callbacks, including P07's native charge event.
	_used_turn=ctx.turn_count
	var before: int=ctx.od_mode.current_od
	var receipt: Dictionary=ctx._apply_stable_combat_od(&"first_core_damage",1,true)
	result.merge({"event_key":"first_core_damage:turn:%d"%ctx.turn_count,"turn":ctx.turn_count,"actor_id":actor.card_id,"actor_runtime_id":actor.get_instance_id(),"command_id":command_id,"heat_before":before,"heat_after":ctx.od_mode.current_od,"applied":int(receipt.get("applied",0)),"reason":str(receipt.get("reason","")),"stable_receipt":receipt.duplicate(true)},true)
	_last_receipt=result.duplicate(true)
	return result
