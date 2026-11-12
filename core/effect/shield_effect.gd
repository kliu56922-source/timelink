extends Node
class_name ShieldEffect

var amount: int = 2

func execute(ctx: EffectContext) -> void:
	ctx.tags.append("shield")
	if ctx.player and "shield" in ctx.player:
		ctx.player.shield += amount
		print("[SHIELD] +%d shield (total: %d)" % [amount, ctx.player.shield])
	else:
		print("[SHIELD] Player has no 'shield' field — skipped (+%d would apply)" % amount)
