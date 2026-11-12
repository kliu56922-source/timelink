# keyword_system.gd
class_name KeywordSystem
extends Node

# ============================================================
# 关键词触发入口（由 BattleSystem.play_card 调用）
# ============================================================
static func on_card_play(card: CardData, ctx: BattleContext, transaction_id: StringName = &""):
	if card == null or ctx == null:
		return
	for kw in card.keywords:
		_apply_keyword(kw, card, ctx, transaction_id)


# ============================================================
# 关键词逻辑
# ============================================================
static func _apply_keyword(kw: String, card: CardData, ctx: BattleContext, transaction_id: StringName = &""):
	match kw:
		"overload":
			_do_overload(ctx, transaction_id)

		"rapid":
			_do_rapid(ctx)

		"jam":
			_do_jam(ctx)

		"shield":
			_do_shield(ctx)

		"echo":
			_do_echo(card, ctx)

		_:
			print("[KEYWORD] Unknown keyword '%s' on %s — skipped" % [kw, card.card_name])


# ============================================================
# overload — 玩家 OD +2
# ============================================================
static func _do_overload(ctx: BattleContext, transaction_id: StringName = &""):
	if ctx == null:
		return
	if ctx.has_method("add_heat"):
		var source_id := &"keyword:overload"
		var descriptor := ctx.get_heat_source_descriptor(&"keyword", source_id)
		ctx.add_heat(2, source_id, transaction_id, {
			"source_descriptor": descriptor,
			"occurrence_id": &"keyword:overload",
		})
		print("[KEYWORD] overload: self OD +2 (now %d)" % ctx.get_current_od())
	else:
		print("[KEYWORD] overload: no OD system available — skipped")


# ============================================================
# rapid — 抽 1 张牌
# ============================================================
static func _do_rapid(ctx: BattleContext):
	if ctx == null or ctx.player == null:
		return
	if ctx.player.has_method("draw"):
		ctx.player.draw(1, "Keyword:Rapid")
		print("[KEYWORD] rapid: draw 1 (hand size: %d, deck left: %d)" % [ctx.player.hand.size(), ctx.player.deck.size()])
	else:
		print("[KEYWORD] rapid: player has no draw method — skipped")


# ============================================================
# jam — Boss OD -2
# ============================================================
static func _do_jam(ctx: BattleContext):
	if ctx == null or ctx.enemy == null:
		return
	if ctx.enemy.has_method("modify_od"):
		ctx.enemy.modify_od(-2)
		print("[KEYWORD] jam: enemy OD -2 (now %d)" % ctx.enemy.od)
	else:
		print("[KEYWORD] jam: enemy has no OD system — skipped")


# ============================================================
# shield — 玩家获得 2 护盾
# ============================================================
static func _do_shield(ctx: BattleContext):
	if ctx == null or ctx.player == null:
		return
	if "shield" in ctx.player:
		ctx.player.shield += 2
		print("[KEYWORD] shield: +2 (total: %d)" % ctx.player.shield)
	else:
		print("[KEYWORD] shield: player has no shield field — skipped")


# ============================================================
# echo — 本回合下一张同路线卡伤害 +2
# ============================================================
static func _do_echo(card: CardData, ctx: BattleContext):
	if ctx == null or card == null:
		return
	var route: String = card.route_id
	if route == "":
		print("[KEYWORD] echo: card '%s' has no route_id — echo wasted" % card.card_name)
		return

	# 将 echo 状态写入 BattleContext，下一张同 route_id 的卡消费
	ctx.set_echo_bonus(route, 2)
	print("[KEYWORD] echo: '%s' activates! Next '%s' card gets +2 damage" % [card.card_name, route])
