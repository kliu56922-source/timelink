extends RefCounted
## Current read-only opportunity after an actually completed new ritual; no action or forecast.
const Planner := preload("res://battle/analysis/player_siege_decision.gd")
func inspect(battle: Variant, claimed_now: bool) -> Dictionary:
	var result := {"eligible":false,"reason":&"not_new_ritual","scope":&"current_core_hp_window_only"}
	if not claimed_now:return result
	if battle==null or battle.context==null or battle.context.player==null or battle.context.enemy==null:
		result.reason=&"battle_missing";return result
	if battle._od_release_resolving or not battle.get_core_command_state().get("player_turn_open",false):
		result.reason=&"busy_or_closed";return result
	if battle.context.player.hp<=0 or battle.context.enemy.hp<=0:
		result.reason=&"battle_ended";return result
	var ritual: Dictionary=battle.get_final_convergence_status("player")
	if not ritual.get("used",false) or ritual.get("last_receipt",{}).is_empty():return result
	var choice: Dictionary=Planner.new().get_decision(battle)
	if not choice.get("ok",false) or choice.get("command")!=&"attack_core" or battle.core_siege_trial==null:
		result.reason=&"no_core_action";return result
	var preview: Dictionary=battle.core_siege_trial.preview_core(choice.actor)
	if not preview.get("ok",false) or int(preview.get("hp_loss",0))<=0:
		result.reason=&"no_current_hp_gain";return result
	result.merge({"eligible":true,"reason":&"current_core_hp_gain","actor":choice.actor,"actor_runtime_id":choice.actor.get_instance_id(),"actor_id":choice.actor.card_id,"cost":choice.cost,"preview":preview,"heat":battle.context.od_mode.current_od,"depth":battle.context.depth_pressure},true)
	return result
