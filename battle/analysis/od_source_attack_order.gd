extends "res://battle/analysis/player_siege_decision.gd"
## Audit-only current action ordering; no future combat/death prediction.
var order_policy: StringName = &"greedy"
var order_observations: Array[Dictionary] = []

func get_decision(battle: Variant) -> Dictionary:
	var original: Dictionary = super.get_decision(battle)
	var selected: Dictionary = original
	if order_policy == &"other-first" and original.ok and original.command == &"attack" and original.actor.piece_type == &"knight":
		for candidate: Dictionary in original.candidates:
			if candidate.command == &"attack" and candidate.actor.piece_type != &"knight":
				selected = candidate.duplicate()
				selected.merge({"ok":true,"reason":original.reason,"scope":original.scope,"candidates":original.candidates})
				break
	var rows: Array[Dictionary] = []
	for candidate: Dictionary in original.get("candidates",[]):rows.append(_encode_choice(candidate,battle))
	order_observations.append({"index":order_observations.size(),"turn":battle.context.turn_count if battle != null and battle.context != null else -1,"policy":order_policy,"original":_encode_choice(original,battle),"selected":_encode_choice(selected,battle),"candidates":rows,"reordered":selected != original})
	return selected

func _encode_choice(choice: Dictionary, battle: Variant) -> Dictionary:
	if not choice.has("actor"):return {"ok":false}
	var actor: CardData = choice.actor
	var target: Variant = choice.target
	var encoded: Dictionary = {"kind":"none"}
	if target is CardData:
		encoded = {"kind":"unit","runtime_id":target.get_instance_id(),"card_id":target.card_id,"cell":battle.get_unit_cell(target)}
	elif target is Vector2i:encoded = {"kind":"cell","cell":target}
	elif target is Dictionary:encoded = {"kind":"structure","value":target.duplicate(true)}
	var state: Variant = battle._state_for_card(actor)
	return {"ok":true,"actor_id":actor.card_id,"actor_runtime_id":actor.get_instance_id(),"piece":actor.piece_type,"hp":state.current_hp if state != null else -1,"command":choice.command,"target":encoded,"cost":choice.cost,"priority":choice.priority,"value":choice.value,"origin":choice.origin}
