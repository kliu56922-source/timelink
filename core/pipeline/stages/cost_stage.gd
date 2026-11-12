class_name CostStage
extends RefCounted

func run(ctx: PipelineContext) -> void:
	ctx.od_cost = ctx.card_data.od_cost
	ctx.battle_context.cost_modifier_chain.apply(ctx)
	if ctx.player.od < ctx.od_cost:
		ctx.is_cancelled = true
		return
	ctx.player.modify_od(-ctx.od_cost)
