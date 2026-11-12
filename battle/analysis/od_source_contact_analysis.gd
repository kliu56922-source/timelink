extends RefCounted
## Audit-only owned zones and current contact. Never forecasts Boss moves or acts.
const Opportunity := preload("res://battle/analysis/od_opportunity_analysis.gd")

func inspect(b: Variant) -> Dictionary:
	var result := {"sources": [], "scope": "owned-zone audit; enemy contact is current geometry, not a future attack prediction"}
	if b == null or b.context == null: return result
	var opportunity: Dictionary = Opportunity.new().inspect(b)
	var seen := {}
	for zone: String in ["field", "hand", "deck", "graveyard"]:
		var cards: Array = b.context.player.get(zone)
		for card: CardData in cards:
			if not is_instance_valid(card) or not card.piece_enabled or card.piece_type != &"knight": continue
			var identity := card.get_instance_id()
			if seen.has(identity): continue
			seen[identity] = true
			var row := {"id": card.card_id, "runtime_id": identity, "zone": zone,
				"hp": -1, "cell": [], "summoned_this_turn": false, "current_attackers": [],
				"play_ok": false, "play_reason": "", "legal_summon_cells": [],
				"release_ready": false, "release_reason": "not_in_field", "opportunity": {}}
			if zone == "hand":
				var play: Dictionary = b.get_card_play_status(card)
				row.play_ok = bool(play.get("ok", false))
				row.play_reason = str(play.get("reason_code", ""))
				if row.play_ok:
					for cell: Vector2i in b.get_legal_summon_cells(&"player"):
						if b.get_monster_summon_cell_status(card, cell, &"player").get("ok", false):
							row.legal_summon_cells.append([cell.x, cell.y])
			if zone == "field":
				var state: Dictionary = b.get_unit_combat_state(card)
				var cell: Vector2i = b.get_unit_cell(card)
				row.hp = int(state.get("current_hp", -1))
				row.cell = [cell.x, cell.y] if cell != b.INVALID_GRID_CELL else []
				row.summoned_this_turn = bool(state.get("summoned_this_turn", false))
				var status: Dictionary = b.get_od_release_source_status(card)
				row.release_ready = bool(status.get("ok", false))
				row.release_reason = str(status.get("reason_code", ""))
				for enemy: CardData in b.context.enemy.field:
					if is_instance_valid(enemy) and card in b.get_legal_attack_targets(enemy):
						row.current_attackers.append(enemy.get_instance_id())
				for item: Dictionary in opportunity.knights:
					if item.runtime_id == identity: row.opportunity = item.duplicate(true); break
			result.sources.append(row)
	return result
