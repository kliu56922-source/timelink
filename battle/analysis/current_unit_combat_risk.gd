extends RefCounted
## Current player direct exchange only. Does not simulate a turn or commit protection.
func inspect(battle: Variant, actor: CardData, target: CardData) -> Dictionary:
	var unknown := {"ok":false,"prediction_available":false,"reason":&"unavailable","cost":0}
	if battle == null or battle.context == null or not is_instance_valid(actor) or not is_instance_valid(target):return unknown
	var status: Dictionary = battle.get_unit_command_status(actor,"attack",target)
	unknown.ok = bool(status.get("ok",false));unknown.cost = int(status.get("cost",0))
	if not unknown.ok:
		unknown.reason = status.get("reason_code", &"illegal_attack");return unknown
	if actor not in battle.context.player.field or target not in battle.context.enemy.field or battle.core_siege_trial == null:
		unknown.reason = &"unsupported_exchange";return unknown
	if battle.reaction_trial != null and not battle.reaction_trial.event.is_empty():
		unknown.reason = &"pending_reaction";return unknown
	# The existing player preview covers attacker P05 and escort, but not target escort.
	if battle.frontline_trial != null and battle.frontline_trial.escort_amount(target) > 0:
		unknown.reason = &"target_protection_not_previewed";return unknown
	var preview: Dictionary = battle.core_siege_trial.preview_unit(actor,target)
	if not preview.get("ok",false):
		unknown.reason = &"special_confirmation_required";return unknown
	var result: Dictionary = preview.duplicate(true)
	result.merge({"prediction_available":true,"reason":&"current_direct_exchange",
		"actor_runtime_id":actor.get_instance_id(),"target_runtime_id":target.get_instance_id(),
		"actor_will_die":int(preview.actor_hp_after) <= 0,"target_will_die":int(preview.target_hp_after) <= 0,
		"scope":&"current_direct_exchange_not_future_board"})
	return result
