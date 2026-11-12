class_name DrawEffect
extends BaseEffect

@export var amount: int = 1

func execute(ctx: EffectContext) -> void:
	ctx.tags.append("draw")

	var bonus = ctx.battle_context.combo_system.get_draw_bonus()
	var total = amount + bonus

	print("[DRAW] %d (+%d combo)" % [amount, bonus])

	# Phase 24B: route through authoritative resolver when available
	if ctx.battle_system:
		ctx.battle_system.draw_player_cards(total, "DrawEffect:%s" % (ctx.source_card.card_id if ctx.source_card else "unknown"))
	else:
		ctx.player.draw(total, "DrawEffect:fallback")