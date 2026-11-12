extends Node
class_name ConditionalDamageEffect

## 额外伤害值
var amount: int = 0
## 触发条件: "overdrive" | "heated" | "enemy_overdrive" | "prev_charge_core"
var condition: String = ""

func execute(ctx: EffectContext) -> void:
	ctx.tags.append("conditional_damage")

	var should_trigger := false

	match condition:
		"overdrive":
			if ctx.battle_context and ctx.battle_context.od_mode:
				should_trigger = ctx.battle_context.od_mode.is_overdrive()
			else:
				print("[CONDITIONAL DMG] od_mode not found — skipped")
				return

		"heated":
			if ctx.battle_context and ctx.battle_context.od_mode:
				should_trigger = ctx.battle_context.od_mode.is_heated()
			else:
				print("[CONDITIONAL DMG] od_mode not found — skipped")
				return

		"enemy_overdrive":
			if ctx.enemy and "od" in ctx.enemy:
				should_trigger = ctx.enemy.od >= 8
			else:
				print("[CONDITIONAL DMG] Enemy has no OD — skipped")
				return

		"prev_charge_core":
			if ctx.battle_context and ctx.battle_context.chain_system:
				should_trigger = ctx.battle_context.chain_system.was_previous_card("Charge Core")
			else:
				print("[CONDITIONAL DMG] chain_system not found — skipped")
				return

		_:
			print("[CONDITIONAL DMG] Unknown condition '%s' — skipped" % condition)
			return

	if should_trigger:
		if ctx.enemy and ctx.enemy.has_method("take_damage"):
			ctx.enemy.take_damage(amount)
			print("[CONDITIONAL DMG] +%d (%s)" % [amount, condition])
		else:
			print("[CONDITIONAL DMG] No valid target — skipped")
	else:
		print("[CONDITIONAL DMG] Condition '%s' not met — skipped" % condition)
