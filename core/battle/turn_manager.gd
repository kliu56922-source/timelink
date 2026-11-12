extends Node
class_name TurnManager

var context: BattleContext

func start_turn():
	print("=== Start Turn ===")

	context.advance_turn_count()

	# 重置本回合出牌计数（Charge Core 首牌奖励等依赖此值）
	context.cards_played_this_turn = 0

	# Phase 26A: each player turn has a fresh stable combat-OD window.
	context.reset_player_turn_stable_combat_od()

	if context.od_mode:
		context.od_mode.reset_turn()

	if context.combo_system:
		context.combo_system.reset()

	if context.chain_system:
		context.chain_system.reset_turn()

	if context.has_method("reset_echo"):
		context.reset_echo()

	# Phase 3B-1: 重置 OD Depth（每回合开始时 Depth 归零）
	if context.has_method("reset_turn_depth"):
		context.reset_turn_depth()

func end_turn():
	print("=== End Turn ===")

	# Phase 23B-R2-R-H2: 回合末 Depth -2 释放，清除 Backlash
	if context.has_method("settle_depth_end_turn"):
		var depth_result: Dictionary = context.settle_depth_end_turn()
		print("[TURN VENT] Depth %d -> %d" % [
			depth_result.get("before", 0),
			depth_result.get("after", 0),
		])

	# 退出觉醒
	if context.has_method("exit_awakening"):
		context.exit_awakening()

	if context.od_mode:
		context.od_mode.on_turn_end()

	# 回合末解除觉醒状态
	context.player.is_awakened = false

	# Buff结算
	for buff in context.player.buffs.duplicate():
		if buff.has_method("on_turn_end"):
			buff.on_turn_end(context)
