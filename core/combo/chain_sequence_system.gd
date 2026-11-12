extends Node
class_name ChainSequenceSystem

# =========================
# 路线追踪状态（跨回合保留）
# =========================
var current_route_id: String = ""
var current_step: int = 0
var route_history: Array[String] = []
var _next_expected: Array[String] = []

# Phase 27J: committed OD releases also form a flexible tactical Chain.
# The card route above remains unchanged.  Tactical qualification is based on
# three different piece types, so players can choose the order and exact cards.
var _tactical_history: Array[StringName] = []
var _tactical_piece_types: Array[String] = []
var _tactical_transactions: Dictionary = {}

# 路线定义（route_id -> 信息）
var route_definitions: Dictionary = {
	"heat_route": {
		"display_name": "Heat Route",
		"color": Color(1.0, 0.4, 0.1, 1),
		"total_steps": 4,
		"combo_reward": "Final Slash 额外触发一次",
		"sequence": ["Ember Familiar", "Ignite Blade", "Pressure Relay", "Final Slash"]
	},
	"overdrive_route": {
		"display_name": "Overdrive Route",
		"color": Color(1.0, 0.15, 0.05, 1),
		"total_steps": 4,
		"combo_reward": "Overdrive Eruption 伤害+5",
		"sequence": ["Warm-Up Rite", "Overclock Pulse", "Chain Conductor", "Overdrive Eruption"]
	},
	"control_route": {
		"display_name": "Control Route",
		"color": Color(0.2, 0.5, 1.0, 1),
		"total_steps": 3,
		"combo_reward": "Chain Breaker 额外 Boss OD -2",
		"sequence": ["Jam Signal", "Cooldown", "Chain Breaker"]
	}
}

# 最近完成的路线名（一次性，读取后清除）
var _last_completed_route: String = ""

# 步骤推进信号（供 BattleScene 做视觉反馈）
signal step_advanced(route_id: String, route_name: String, step: int, total: int)


# =========================
# 公开 API
# =========================

## 启动新路线（仅 step 1 允许）
func start_route(route_id: String) -> void:
	current_route_id = route_id
	current_step = 0
	route_history.clear()
	_next_expected.clear()
	var def: Dictionary = route_definitions.get(route_id, {})
	var display_name: String = def.get("display_name", route_id)
	print("[CHAIN] Route started: %s" % display_name)


## 推进路线（由 BattleContext.on_card_played 调用）
func advance_route(card: CardData, options: Dictionary = {}) -> Array[Dictionary]:
	var notifications: Array[Dictionary] = []
	if card == null:
		return notifications

	var card_route: String = card.route_id
	var card_step: int = card.route_step

	# 无路线：非路线卡，不影响当前路线进度
	if card_route == "":
		return notifications

	# ── 情况 A：没有活跃路线，尝试启动 ──
	if current_route_id == "":
		if card_step != 1:
			print("[CHAIN] '%s' wants to start '%s' but is step %d (must be step 1) — ignored" % [card.card_name, card_route, card_step])
			return notifications
		notifications.append_array(_do_start(card, card_route, card_step, options))
		return notifications

	# ── 情况 B：与当前路线相同，检查步进 ──
	if card_route == current_route_id:
		if card_step == current_step + 1:
			notifications.append_array(_do_advance(card, card_step, options))
		elif card_step <= current_step:
			print("[CHAIN] '%s' is step %d but route is already at step %d — out of order, ignored" % [card.card_name, card_step, current_step])
		else:
			print("[CHAIN] '%s' is step %d but route expects step %d — skipped too far ahead" % [card.card_name, card_step, current_step + 1])
		return notifications

	# ── 情况 C：不同路线，放弃旧路线，开启新路线 ──
	if card_step == 1:
		var old_name: String = _get_route_display_name(current_route_id)
		print("[CHAIN] Abandoning '%s' (reached step %d) to start '%s'" % [old_name, current_step, card_route])
		notifications.append_array(_do_start(card, card_route, card_step, options))
	else:
		print("[CHAIN] '%s' is from '%s' step %d but active route is '%s' — cannot start mid-route" % [card.card_name, card_route, card_step, _get_route_display_name(current_route_id)])

	return notifications

# =========================
# 内部：启动 / 推进
# =========================

func _do_start(card: CardData, route_id: String, step: int, options: Dictionary = {}) -> Array[Dictionary]:
	start_route(route_id)
	current_step = step
	route_history.append(card.card_name)
	_next_expected = card.next_cards.duplicate()

	var def: Dictionary = route_definitions.get(route_id, {})
	var display_name: String = def.get("display_name", route_id)
	var total: int = def.get("total_steps", 4)
	print("[CHAIN] Step %d/%d of '%s' — played %s" % [step, total, display_name, card.card_name])

	var notifications: Array[Dictionary] = []
	_deliver_route_notification({"kind": &"route_step", "args": [route_id, display_name, step, total]}, options, notifications)
	notifications.append_array(_check_route_completion(options))
	return notifications


func _do_advance(card: CardData, step: int, options: Dictionary = {}) -> Array[Dictionary]:
	current_step = step
	route_history.append(card.card_name)
	_next_expected = card.next_cards.duplicate()

	var def: Dictionary = route_definitions.get(current_route_id, {})
	var display_name: String = def.get("display_name", current_route_id)
	var total: int = def.get("total_steps", 4)
	print("[CHAIN] Step %d/%d of '%s' — played %s" % [step, total, display_name, card.card_name])

	var notifications: Array[Dictionary] = []
	_deliver_route_notification({"kind": &"route_step", "args": [current_route_id, display_name, step, total]}, options, notifications)
	notifications.append_array(_check_route_completion(options))
	return notifications


func _check_route_completion(options: Dictionary = {}) -> Array[Dictionary]:
	var notifications: Array[Dictionary] = []
	if current_route_id == "":
		return notifications
	var def: Dictionary = route_definitions.get(current_route_id, {})
	var total: int = def.get("total_steps", 4)
	if current_step >= total:
		_last_completed_route = current_route_id
		var display_name: String = def.get("display_name", current_route_id)
		var reward: String = def.get("combo_reward", "")
		print("")
		print("══════════════════════════════════════════")
		print("  >> CHAIN COMPLETE: %s <<" % display_name)
		print("  >> Reward: %s" % reward)
		print("  >> Cards: %s" % ", ".join(route_history))
		print("══════════════════════════════════════════")
		print("")

		# 发射信号给 BattleScene 做视觉反馈
		var parent = get_parent()
		if parent and parent.has_signal("chain_completed"):
			_deliver_route_notification({"kind": &"route_complete", "args": [current_route_id, display_name, reward]}, options, notifications)
	return notifications


# =========================
# 完成路线消费 + 查询
# =========================

## 取出并清除最近完成的路线（供 battle_system 使用）
func consume_completed_route() -> String:
	var r: String = _last_completed_route
	_last_completed_route = ""
	return r


func is_route_just_completed() -> bool:
	return _last_completed_route != ""


## Phase 4C-3: 查询路线是否已完成（不消费）
func is_route_completed(route_id: String) -> bool:
	return _last_completed_route == route_id


func record_tactical_event(event_id: StringName, transaction_id: StringName = &"", committed: bool = true) -> Dictionary:
	if not committed or not String(event_id).begins_with("od_release:"):
		return get_tactical_chain_snapshot()
	if transaction_id != &"" and _tactical_transactions.has(transaction_id):
		return get_tactical_chain_snapshot()
	if transaction_id != &"":
		_tactical_transactions[transaction_id] = true
	_tactical_history.append(event_id)
	var piece_type := String(event_id).trim_prefix("od_release:")
	if piece_type != "" and piece_type not in _tactical_piece_types:
		_tactical_piece_types.append(piece_type)
	return get_tactical_chain_snapshot()


func get_tactical_chain_snapshot() -> Dictionary:
	return {
		"committed_count": _tactical_history.size(),
		"distinct_count": _tactical_piece_types.size(),
		"events": _tactical_history.duplicate(),
		"piece_types": _tactical_piece_types.duplicate(),
		"qualifying": has_qualifying_tactical_chain(),
	}


func has_qualifying_tactical_chain() -> bool:
	return _tactical_piece_types.size() >= 3


## Phase 4C-3: 匹配时消费已完成路线，返回是否成功
func consume_completed_route_if(route_id: String) -> bool:
	if _last_completed_route == route_id:
		_last_completed_route = ""
		return true
	return false


func get_next_cards() -> Array[String]:
	return _next_expected.duplicate()


func get_progress_text() -> String:
	if current_route_id == "":
		return "—"
	var def: Dictionary = route_definitions.get(current_route_id, {})
	var total: int = def.get("total_steps", 4)
	var display_name: String = def.get("display_name", current_route_id)
	return "%s %d/%d" % [display_name, current_step, total]


func get_route_display_name() -> String:
	return _get_route_display_name(current_route_id)


func get_route_color() -> Color:
	if current_route_id == "":
		return Color(0.6, 0.6, 0.6, 1)
	var def: Dictionary = route_definitions.get(current_route_id, {})
	return def.get("color", Color(0.6, 0.6, 0.6, 1))


func is_card_in_active_route(card: CardData) -> bool:
	if card == null or current_route_id == "":
		return false
	return card.route_id == current_route_id


func is_card_next_in_route(card: CardData) -> bool:
	if card == null or current_route_id == "":
		return false
	if card.route_id != current_route_id:
		return false
	if card.route_step != current_step + 1:
		return false
	return true


func was_previous_card(card_name: String) -> bool:
	if route_history.is_empty():
		return false
	return route_history[route_history.size() - 1] == card_name


# =========================
# 回合重置（仅清除完成标记，路线进度跨回合保留）
# =========================
func reset_turn() -> void:
	if _last_completed_route != "":
		print("[CHAIN] Completed route '%s' consumed at end of turn" % _last_completed_route)
	_last_completed_route = ""


# =========================
# 内部辅助
# =========================
func _get_route_display_name(route_id: String) -> String:
	if route_id == "":
		return "(none)"
	var def: Dictionary = route_definitions.get(route_id, {})
	return def.get("display_name", route_id)


func _deliver_route_notification(event: Dictionary, options: Dictionary, notifications: Array[Dictionary]) -> void:
	if bool(options.get("defer_signal", false)):
		notifications.append(event.duplicate(true))
	else:
		publish_route_notifications([event])


func publish_route_notifications(notifications: Array[Dictionary]) -> void:
	var pending := notifications.duplicate(true)
	notifications.clear()
	for event: Dictionary in pending:
		var args: Array = event.get("args", [])
		if event.get("kind") == &"route_step":
			step_advanced.emit(args[0], args[1], args[2], args[3])
		elif event.get("kind") == &"route_complete":
			var parent := get_parent()
			if parent and parent.has_signal("chain_completed"):
				parent.emit_signal("chain_completed", args[0], args[1], args[2])
