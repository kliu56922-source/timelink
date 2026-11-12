extends RefCounted
## Audit-only current window. Base heat arithmetic is not a full cast simulation.
## Actual card, target and resource authority remains in the battle handlers.
func inspect(battle: Variant, card: CardData) -> Dictionary:
	var result := {"check_before_cooling": false, "reason": "not_current_cooling", "heat": 0,
		"threshold": 0, "base_heat_after": 0, "base_heat_delta": 0, "known_hits": []}
	if battle == null or battle.context == null: return result
	var ctx: BattleContext = battle.context
	result.heat = ctx.od_mode.current_od
	result.threshold = battle.od_release_rules.get_readiness_threshold()
	if not is_instance_valid(card) or card.card_id != "P11" or card not in ctx.player.hand: return result
	if not battle.get_command_economy_snapshot("player").get("turn_open", false) or not battle.get_card_play_status(card).get("ok", false):
		result.reason = "card_unavailable"; return result
	if ctx.is_abyss_locked():
		result.reason = "recovery_priority"; return result
	var final: Dictionary = battle.get_final_convergence_status("player")
	if final.get("ok", false) and (final.get("attack_ready", false) or final.get("guard_ready", false)):
		result.reason = "prepared_reward_priority"; return result
	var base_delta: int = ctx.od_mode.get_od_gain(card)
	for effect: Node in card.effects:
		if effect is ODEffect: base_delta += effect.amount * ctx.get_effect_repeat()
	result.base_heat_delta = base_delta
	result.base_heat_after = maxi(0, result.heat + base_delta)
	if base_delta >= 0 or result.heat < result.threshold or result.base_heat_after >= result.threshold:
		result.reason = "no_base_threshold_crossing"; return result
	for actor: CardData in ctx.player.field:
		if not is_instance_valid(actor) or actor.piece_type != &"knight": continue
		var source: Dictionary = battle.get_od_release_source_status(actor)
		if not source.get("ok", false): continue
		for cell: Vector2i in source.get("legal_cells", []):
			var q: Dictionary = battle.get_knight_od_landing_preview(actor, cell)
			if q.get("ok", false) and q.get("prediction_available", false) and is_instance_valid(q.get("target")):
				result.known_hits.append({"source_runtime_id": actor.get_instance_id(), "source": actor.card_id,
					"cell": [cell.x,cell.y], "target_runtime_id": q.target.get_instance_id()})
	result.check_before_cooling = not result.known_hits.is_empty()
	result.reason = "current_hit_near_threshold" if result.check_before_cooling else "no_available_known_hit"
	return result
