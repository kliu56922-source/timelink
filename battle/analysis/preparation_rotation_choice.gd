extends "res://battle/analysis/od_source_risk_choice.gd"
## Audit-only current ordering. Investment uses instance identity; no prediction or action.
var preparation_policy: StringName = &"original"
var preparation_observations: Array[Dictionary] = []

func get_decision(battle: Variant) -> Dictionary:
	var original: Dictionary=super.get_decision(battle)
	var selected: Dictionary=original
	var preparation: Dictionary={}
	if battle!=null and battle.context!=null:
		preparation=battle._ritual_trial_snapshot()
	var participants: Array=preparation.get("attack_participants",[])
	var eligible: bool=original.get("ok",false) and original.get("command")==&"attack_core" and not preparation.is_empty() and not preparation.get("used",false) and not preparation.get("attack_ready",false) and participants.has(original.actor.get_instance_id())
	if preparation_policy==&"prepare-other" and eligible:
		for candidate: Dictionary in original.candidates:
			if candidate.command==&"attack_core" and not participants.has(candidate.actor.get_instance_id()):
				selected=candidate.duplicate()
				selected.merge({"ok":true,"reason":original.reason,"scope":original.scope,"candidates":original.candidates})
				break
	var candidates: Array[Dictionary]=[]
	for candidate: Dictionary in original.get("candidates",[]):candidates.append(encoder._encode_choice(candidate,battle))
	preparation_observations.append({"index":preparation_observations.size(),"turn":battle.context.turn_count if battle!=null and battle.context!=null else -1,"policy":preparation_policy,"preparation":preparation.duplicate(true),"eligible":eligible,"original":encoder._encode_choice(original,battle),"selected":encoder._encode_choice(selected,battle),"candidates":candidates,"changed":selected!=original})
	return selected
