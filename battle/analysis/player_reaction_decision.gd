extends RefCounted
## Read-only bounded survival policy. Caller still selects through ReactionTrial.
func get_decision(battle:Variant)->Dictionary:
	var denied:={"ok":false,"reason":&"no_current_window","mode":"pass","scope":&"current_public_attack_no_future_board"}
	if battle==null or battle.reaction_trial==null:return denied
	var status:Dictionary=battle.reaction_trial.get_response_status()
	if not status.get("ok",false):
		denied.reason=status.get("reason",&"no_current_window");return denied
	var saves:bool=status.base.ok and status.hp_after_pass<=0 and status.base.hp_after>0
	var reason:="base_preserves_target" if saves else "retain_resources"
	if status.damage<=0:reason="already_protected"
	elif not status.base.ok:reason="base_unavailable"
	elif not saves and status.hp_after_pass<=0:reason="base_still_lethal"
	return {"ok":true,"reason":StringName(reason),"mode":"base" if saves else "pass","event_id":status.event_id,"scope":status.scope,"status":status}
