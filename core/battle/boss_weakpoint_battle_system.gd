extends "res://battle/battle_system.gd"
## Explicit 162A system. The original BattleSystem and ordinary scene remain default.
const WeakState=preload("res://core/battle/boss_weakpoint_state.gd")
signal weakpoint_attack_committed(receipt: Dictionary)
var _weakpoint_committing:=false
var _weakpoint_resolver_pending:=false
var _active_weakpoint_id:=""
var _active_actor_id:=0
func init(ctx: BattleContext) -> void:
	super.init(ctx)
	context.boss_weakpoint_state=_create_weakpoint_state()
func _create_weakpoint_state() -> RefCounted:
	return WeakState.new()
func get_weakpoint_snapshot(_id: String="") -> Dictionary:
	return {} if context==null or context.boss_weakpoint_state==null else context.boss_weakpoint_state.snapshot()
func _reject_weakpoint(reason: String) -> Dictionary:
	return {"ok":false,"reason_code":StringName(reason),"reason":reason}
func get_weakpoint_attack_status(card: CardData,id: String) -> Dictionary:
	if _weakpoint_committing:return _reject_weakpoint("weakpoint_busy")
	return get_unit_command_status(card,"attack_core",null,{"weakpoint_id":id})
func get_unit_command_status(card: CardData,command_type: String,target: Variant=null,payload: Dictionary={}) -> Dictionary:
	if not payload.has("weakpoint_id"):return super.get_unit_command_status(card,command_type,target,payload)
	if command_type!="attack_core" or target!=null or payload.get("piece_enhanced",false) or not str(payload.get("piece_payment_mode","")).is_empty():return _reject_weakpoint("weakpoint_basic_attack_only")
	var weak:=get_weakpoint_snapshot(str(payload.weakpoint_id))
	if weak.is_empty() or str(payload.weakpoint_id)!=str(weak.id):return _reject_weakpoint("weakpoint_unknown")
	if weak.broken:return _reject_weakpoint("weakpoint_already_broken")
	if not weak.get("exposed",true):return _reject_weakpoint("weakpoint_not_exposed")
	if _is_battle_terminal():return _reject_weakpoint("battle_terminal")
	if not get_command_economy_snapshot("player").get("turn_open",false):return _reject_weakpoint("player_turn_closed")
	if not is_instance_valid(card):return _reject_weakpoint("card_missing")
	var st: Variant=_state_for_card(card)
	if st==null or st.owner_side!=&"player":return _reject_weakpoint("weakpoint_player_source_required")
	var native: Dictionary=super.get_unit_command_status(card,command_type,target,payload)
	# Quote remains native even when geometry/summoning sickness rejects the action.
	native.cost=get_action_command_cost(card,"attack_core")
	if not native.get("ok",false):return native
	if int(weak.column)>=0 and get_unit_cell(card).x!=int(weak.column):return _reject_weakpoint("weakpoint_wrong_column")
	var amount:=get_effective_unit_attack(card)+get_normal_attack_bonus(card)
	if amount<=0:return _reject_weakpoint("weakpoint_no_attack_damage")
	native["weakpoint"]=weak;native["part_damage"]=amount
	return native
func execute_weakpoint_attack(card: CardData,id: String) -> Dictionary:
	return execute_unit_command(card,"attack_core",null,{"weakpoint_id":id})
func execute_unit_command(card: CardData,command_type: String,target: Variant=null,payload: Dictionary={}) -> Dictionary:
	if _weakpoint_committing:return _reject_weakpoint("weakpoint_busy")
	if not payload.has("weakpoint_id"):return super.execute_unit_command(card,command_type,target,payload)
	var status:=get_unit_command_status(card,command_type,target,payload)
	if not status.get("ok",false):return status
	_weakpoint_committing=true;_weakpoint_resolver_pending=true;_active_weakpoint_id=str(payload.weakpoint_id);_active_actor_id=card.get_instance_id()
	# Native debit, rollback, gross/Depth thresholds, discounts and action counters own payment.
	var receipt: Dictionary=super.execute_unit_command(card,command_type,target,payload)
	if receipt.get("ok",false) and card.piece_payload_id==&"p03_vanguard_formation":
		receipt["formation_shield"]=_piece_p03_maybe_formation_shield(card)
	_active_weakpoint_id="";_active_actor_id=0;_weakpoint_resolver_pending=false
	if receipt.get("ok",false):weakpoint_attack_committed.emit(receipt.duplicate(true))
	_weakpoint_committing=false
	return receipt
func _commit_weakpoint_hit(amount: int) -> Dictionary:
	return context.boss_weakpoint_state._commit_hit(amount)
func resolve_monster_attack(attacker: CardData,target: CardData=null,release_bonus: int=0) -> Dictionary:
	if _active_weakpoint_id.is_empty():return super.resolve_monster_attack(attacker,target,release_bonus)
	if not _weakpoint_committing or not is_instance_valid(attacker) or attacker.get_instance_id()!=_active_actor_id or target!=null:return _reject_weakpoint("weakpoint_resolver_context_lost")
	if not _weakpoint_resolver_pending:return _reject_weakpoint("weakpoint_resolver_already_used")
	# Consume before any HP/unit-state signal can synchronously reenter this resolver.
	_weakpoint_resolver_pending=false
	var weak:=get_weakpoint_snapshot(_active_weakpoint_id)
	if weak.is_empty() or weak.broken or str(weak.id)!=_active_weakpoint_id:return _reject_weakpoint("weakpoint_resolver_target_lost")
	var amount:=get_effective_unit_attack(attacker)+get_normal_attack_bonus(attacker)
	var hit: Dictionary=_commit_weakpoint_hit(amount)
	var before: int=context.enemy.hp
	if hit.just_broken:
		context.enemy.set_hp_authoritative(maxi(0,before-int(weak.rupture_damage)),"Weakpoint rupture162A")
		if context.enemy.hp>0:_weakpoint_phase_entries()
	mark_monster_attacked(attacker,true)
	_bishop_consume(attacker)
	if basic_card_trial!=null:basic_card_trial.consume_blade(attacker)
	var loss:=before-context.enemy.hp
	return {"ok":true,"result":"hit_weakpoint","attacker":attacker,"target":null,"damage":amount,"integrity_loss":hit.integrity_loss,"weakpoint_broken":hit.just_broken,"actual_hp_loss":loss,"weakpoint":get_weakpoint_snapshot(_active_weakpoint_id),"destroyed_units":[],"stable_od_events":[],"stable_od_gained":0,"message":"%s：耐久 -%d%s"%[weak.name,hit.integrity_loss,"，击破！本体 -%d"%loss if hit.just_broken else ""]}
func _weakpoint_phase_entries() -> void:
	if not context.are_boss_phase_locks_enabled():return
	for phase in [2,3]:
		var done: bool=context.boss_phase1_triggered if phase==2 else context.boss_phase2_triggered
		var rule: Dictionary=context.get_boss_phase_lock(phase)
		if done or context.enemy.hp>int(rule.hp_threshold):continue
		if phase==2:context.boss_phase1_triggered=true
		else:context.boss_phase2_triggered=true
		context.phases_locked_this_turn+=1
		# This source preserves the actual post-rupture HP and never converts overflow.
		context.enemy.apply_phase_lock_state(context.enemy.hp,int(rule.shield_gain),phase,"Weakpoint phase162A")
		if phase==3 and context.enemy.od<8:context.enemy.modify_od(8-context.enemy.od)
