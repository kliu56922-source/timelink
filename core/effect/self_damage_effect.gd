class_name SelfDamageEffect
extends BaseEffect

@export var amount: int = 1

func execute(ctx: EffectContext) -> void:
	ctx.tags.append("self_damage")
	ctx.player.take_damage(amount)
