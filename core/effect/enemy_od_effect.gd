extends Node
class_name EnemyODEffect

var amount: int = -2

func execute(ctx: EffectContext) -> void:
	ctx.tags.append("enemy_od")
	if ctx.enemy and ctx.enemy.has_method("modify_od"):
		ctx.enemy.modify_od(amount)
		print("[ENEMY OD] Enemy OD %+d" % amount)
	else:
		print("[ENEMY OD] Enemy has no OD system — skipped")
