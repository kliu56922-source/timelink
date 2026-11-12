extends Node
class_name StructureRepairEffect
## State changes belong to the validated BattleSystem transaction.
var amount: int = 1

func execute(ctx: EffectContext) -> void:
	if ctx == null or ctx.structure_repair_plan.is_empty() or ctx.battle_system == null:
		return
	if ctx.source_card == null or ctx.source_card.get_instance_id() != ctx.structure_repair_plan.expectations.card_runtime_id:
		return
	ctx.battle_system._apply_p22_repair_effect(ctx)
