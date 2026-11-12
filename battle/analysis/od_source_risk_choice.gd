extends "res://battle/analysis/player_siege_decision.gd"
## Audit-only: a legal forward move is an alternative, never a promise of safety.
const Risk := preload("res://battle/analysis/current_unit_combat_risk.gd")
const Encoder := preload("res://battle/analysis/od_source_attack_order.gd")
var risk_policy: StringName = &"greedy"
var risk_observations: Array[Dictionary] = []
var inspector := Risk.new()
var encoder := Encoder.new()

func get_decision(battle: Variant) -> Dictionary:
	var original: Dictionary = super.get_decision(battle)
	var selected: Dictionary = original
	var risk := {"prediction_available":false,"reason":&"not_knight_attack"}
	var knights := 0
	if battle != null and battle.context != null:
		for card: CardData in battle.context.player.field:
			var state: Variant = battle._state_for_card(card)
			if card.piece_enabled and card.piece_type == &"knight" and state != null and not state.is_dead():knights += 1
	if original.ok and original.command == &"attack" and original.actor.piece_enabled and original.actor.piece_type == &"knight" and original.target is CardData:
		risk = inspector.inspect(battle,original.actor,original.target)
		if risk_policy == &"preserve-source" and knights == 1 and risk.get("prediction_available",false) and risk.get("actor_will_die",false):
			for candidate: Dictionary in original.candidates:
				if candidate.actor == original.actor and candidate.command == &"move":
					selected = candidate.duplicate()
					selected.merge({"ok":true,"reason":original.reason,"scope":original.scope,"candidates":original.candidates})
					break
	var candidates: Array[Dictionary] = []
	for candidate: Dictionary in original.get("candidates",[]):candidates.append(encoder._encode_choice(candidate,battle))
	risk_observations.append({"index":risk_observations.size(),"turn":battle.context.turn_count if battle != null and battle.context != null else -1,
		"policy":risk_policy,"knights":knights,"risk":risk,"original":encoder._encode_choice(original,battle),
		"selected":encoder._encode_choice(selected,battle),"candidates":candidates,"changed":selected != original})
	return selected
