extends Node
class_name DamageEffect

var base_damage: int = 1
var od_ratio: float = 0.0

## Value-only projection. Echo consumption and all effects remain with execute.
static func calculate_values(base_damage: int, od: int, od_ratio: float, zone_bonus: int, echo_bonus: int, combo_mul: float, zone_mul: float) -> Dictionary:
	var base_value: int = base_damage + int(od * od_ratio) + zone_bonus + echo_bonus
	return {"base_value": base_value, "final_value": int(base_value * combo_mul * zone_mul)}

func execute(ctx: EffectContext) -> void:
	ctx.tags.append("damage")
	var combo_mul = ctx.battle_context.combo_system.get_od_multiplier()
	var zone_mul = ctx.battle_context.od_mode.get_damage_taken_multiplier()
	var zone = ctx.battle_context.od_mode.get_zone()

	# Zone 效果配置文件（source_card 可覆盖各区间伤害加成）
	var zone_bonus = _get_zone_damage_bonus(ctx.source_card, zone)

	# Echo 加成：上一张同路线卡触发了 echo
	var echo_bonus: int = 0
	if ctx.battle_context.has_method("consume_echo_bonus") and ctx.source_card.route_id != "":
		echo_bonus = ctx.battle_context.consume_echo_bonus(ctx.source_card.route_id)

	var values := calculate_values(base_damage, ctx.player.od, od_ratio, zone_bonus, echo_bonus, combo_mul, zone_mul)
	ctx.base_value = values.base_value
	ctx.final_value = values.final_value
	print("[DMG] %d (+%d zone, +%d echo) x%.2f x%.2f(zone) = %d" % [ctx.base_value - echo_bonus, zone_bonus, echo_bonus, combo_mul, zone_mul, ctx.final_value])

	if ctx.siege_cast_plan.is_empty():
		# ADR-0007: 按 target_type 选择伤害目标
		match ctx.target_type:
			EffectContext.TargetType.TARGET_PLAYER:
				ctx.player.take_damage(ctx.final_value)
				print("[DMG] %d damage to PLAYER" % ctx.final_value)
			_:  # TARGET_ENEMY (默认，向后兼容玩家卡)
				ctx.enemy.take_damage(ctx.final_value)
	# 命中音效（安全获取：不依赖当前Node是否在scene tree）
	var tree := Engine.get_main_loop() as SceneTree
	var am = null
	if tree and tree.root:
		am = tree.root.get_node_or_null("AudioManager")
	if not ctx.siege_cast_plan.is_empty():
		ctx.siege_cast_plan["hit_sounds"] = int(ctx.siege_cast_plan.get("hit_sounds", 0)) + 1
	elif am and am.has_method("play_sfx"):
		am.play_sfx("hit")

	# Overdrive 反伤
	if zone == ODMode.Zone.OVERDRIVE and ctx.source_card.overdrive_self_damage > 0:
		ctx.player.take_damage(ctx.source_card.overdrive_self_damage)
		print("[DMG] Overdrive recoil: %d to self" % ctx.source_card.overdrive_self_damage)


func _get_zone_damage_bonus(card: CardData, zone: int) -> int:
	match zone:
		ODMode.Zone.CALM:
			return card.calm_damage_bonus
		ODMode.Zone.HEATED:
			return card.heated_damage_bonus
		ODMode.Zone.OVERDRIVE:
			return card.overdrive_damage_bonus
	return 0
