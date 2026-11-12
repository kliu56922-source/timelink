extends "res://core/battle/building_footprint_trial.gd"
## Integrated prototype: larger P13 cores trade continuous board space for durability.
## Native price, timing, active ability, card/Chain/OD rules are inherited unchanged.
func augment_layout(card: CardData, cell: Vector2i, plan: Dictionary, terrain: Array[Dictionary], result: Dictionary) -> Dictionary:
	var status: Dictionary=super.augment_layout(card,cell,plan,terrain,result)
	if not status.get("ok",false) or card.card_id!="P13":return status
	var count: int=plan.structure.footprint_cells.size()
	var bonus: int=1 if count==2 else 2 if count==4 else 0
	plan.structure.integrity_max=int(plan.structure.integrity_max)+bonus
	var b: Variant=_battle.get_ref()
	var existing: Dictionary=b.get_structure_at_cell(cell)
	if not existing.is_empty() and int(existing.source_runtime_id)==card.get_instance_id():
		plan.structure.integrity_current=mini(int(existing.integrity_current),int(plan.structure.integrity_max))
	else:plan.structure.integrity_current=int(plan.structure.integrity_current)+bonus
	result.preview_integrity_max=plan.structure.integrity_max
	return status
