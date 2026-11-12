extends Node
class_name ODEffect

## OD变化量（正数=涨OD，负数=降OD）
var amount: int = 1

func execute(ctx: EffectContext) -> void:
	ctx.tags.append("od")

	# 优先走 od_mode 确保 OD 同步正确
	if ctx.battle_context and ctx.battle_context.od_mode:
		var card_id := str(ctx.source_card.card_id) if ctx.source_card != null else "unknown"
		var source_id := StringName("effect:%s:%d:repeat:%d" % [card_id, ctx.effect_index, ctx.effect_repeat_index])
		var descriptor := ctx.heat_source_descriptor.duplicate(true)
		descriptor["source_kind"] = &"card_effect"
		descriptor["source_id"] = source_id
		ctx.battle_context.add_heat(amount, source_id, ctx.heat_transaction_id, {
			"source_descriptor": descriptor,
			"occurrence_id": StringName("effect:%d:repeat:%d" % [ctx.effect_index, ctx.effect_repeat_index]),
			"card_id": card_id,
		})
		print("[OD EFFECT] Player OD %+d (via od_mode)" % amount)
		return

	# 降级：直接修改 player.od
	if ctx.player and ctx.player.has_method("modify_od"):
		ctx.player.modify_od(amount)
		print("[OD EFFECT] Player OD %+d (fallback)" % amount)
		return

	print("[OD EFFECT] No OD system available — skipped")
