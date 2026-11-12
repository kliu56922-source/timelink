extends RefCounted
## Audit-only choice. Queries current authoritative preview; never commits a release.
## Candidates retain their caller's original order, including the empty-hit fallback.
func choose(battle: Variant, actor: CardData, candidates: Array, policy: StringName = &"coordinate") -> Vector2i:
	if candidates.is_empty(): return battle.INVALID_GRID_CELL
	if policy == &"current-hit":
		for cell: Vector2i in candidates:
			var preview: Dictionary = battle.get_knight_od_landing_preview(actor, cell)
			if preview.get("ok", false) and preview.get("prediction_available", false) and preview.get("target") != null:
				return cell
	return candidates[0]
