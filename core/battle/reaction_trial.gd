extends RefCounted
## GB3G only. Selection reserves a response; resources commit at damage resolution.
var _battle_ref: WeakRef
var event: Dictionary = {}
var sequence := 0
var hand_used := false
var skip_turn := false
var waiting := false
var selected := ""
var history: Array[Dictionary] = []
const HAND_HEAT_COST := 1
const BASE_PREVENTION := 2
const ENHANCED_PREVENTION := 3
const ENHANCED_DEPTH_LIMIT := 5

func _init(battle: Node) -> void:
	_battle_ref = weakref(battle)

func _bt() -> Variant:
	return _battle_ref.get_ref()

func begin_turn() -> void:
	finish_event()
	hand_used = false
	skip_turn = false

func owns(card: CardData) -> bool:
	return card != null and card.card_id in ["P04", "R01"]

func deployed_count() -> int:
	var count := 0
	for card in _bt().context.player.traps:
		if owns(card): count += 1
	return count

func watch_cells(card: CardData) -> Array:
	var bt = _bt()
	var entry: Dictionary = bt._piece_anchor_by_runtime_id.get(card.get_instance_id(), {})
	if entry.is_empty(): return []
	var cells: Array = bt.project_piece_cells(&"piece_pawn", entry.anchor_cell, &"player", &"attack", 0)
	if entry.get("enhanced", false):
		for cell in bt.project_piece_cells(&"piece_pawn", entry.anchor_cell, &"player", &"attack", 1):
			if not cells.has(cell): cells.append(cell)
	return cells

func _hand_card() -> CardData:
	for card in _bt().context.player.hand:
		if card.card_id == "R01": return card
	return null

func _legal_candidate(candidate: Dictionary) -> bool:
	var bt = _bt()
	if bt.context.player.hp <= 0 or bt.context.enemy.hp <= 0: return false
	if not bt.get_command_economy_snapshot("boss").get("turn_open", false): return false
	var actor: CardData = bt._find_field_card_by_runtime_id(candidate.get("actor_runtime_id", 0), &"boss")
	if actor == null: return false
	var cmd: String = candidate.get("command_id", "")
	var target: Variant = candidate.get("target_cell") if cmd == "move" else bt._find_field_card_by_runtime_id(candidate.get("target_runtime_id", 0), &"player")
	if cmd not in ["move", "attack"] or target == null: return false
	return bt.get_unit_command_status(actor, cmd, target).get("ok", false)

func begin_event(candidate: Dictionary) -> Dictionary:
	finish_event()
	sequence += 1
	if not _legal_candidate(candidate): return {}
	event = candidate.duplicate(true)
	event["event_id"] = sequence
	event["reduced"] = false
	var bt = _bt()
	var actor: CardData = bt._find_field_card_by_runtime_id(event.actor_runtime_id, &"boss")
	event["actor_name"] = actor.get_display_name()
	if event.command_id == "attack":
		var target: CardData = bt._find_field_card_by_runtime_id(event.target_runtime_id, &"player")
		event["target_name"] = target.get_display_name()
		event.merge(_attack_damage_preview(actor, target), true)
		waiting = not skip_turn and not hand_used and _hand_card() != null and bt.context.od_mode.current_od >= HAND_HEAT_COST and event.damage_after_prepared > 0
	event["waiting"] = waiting
	return event.duplicate(true)


## Current public damage only. Does not consume P05/escort/garrison/prepared defenses.
func _attack_damage_preview(actor: CardData, target: CardData) -> Dictionary:
	var bt = _bt()
	var damage: int = bt.get_effective_unit_attack(actor)
	damage = maxi(0, damage - bt._apply_p05_mitigation(target, damage, false))
	var escort := 0
	var cover: Dictionary = {}
	if bt.frontline_trial != null:
		var prepared: int = bt.frontline_trial.escort_amount(target)
		escort = mini(damage, prepared)
		damage = maxi(0, damage - escort)
		cover = bt.frontline_trial.guard_for(target)
		if damage <= 0 or (escort > 0 and prepared == 1): cover = {}
		damage = maxi(0, damage - int(cover.get("reduction", 0)))
	var cell: Vector2i = bt.get_unit_cell(target)
	var automatic := 0
	for card in bt.context.player.traps:
		if card.card_id == "R01" and watch_cells(card).has(cell): automatic += 3
	return {"damage_before": damage, "damage_after_prepared": maxi(0, damage - automatic), "escort_prevention": escort, "garrison_cover": cover.duplicate(true)}

## Re-query an open response; cached event damage is never a live rescue promise.
func get_response_status() -> Dictionary:
	var denied := {"ok": false, "reason": &"no_current_window"}
	if not waiting or event.is_empty() or event.get("command_id", "") != "attack" or event.get("reduced", false): return denied
	if not _legal_candidate(event): return {"ok": false, "reason": &"original_action_invalid"}
	var bt = _bt()
	var actor: CardData = bt._find_field_card_by_runtime_id(event.actor_runtime_id, &"boss")
	var target: CardData = bt._find_field_card_by_runtime_id(event.target_runtime_id, &"player")
	var state = bt._state_for_card(target)
	if state == null or state.is_dead(): return {"ok": false, "reason": &"target_unavailable"}
	var preview := _attack_damage_preview(actor, target)
	var damage: int = preview.damage_after_prepared
	var heat: int = bt.context.od_mode.current_od
	var available: bool = not hand_used and not skip_turn and _hand_card() != null and heat >= HAND_HEAT_COST and damage > 0
	var hp: int = state.current_hp
	var base_damage := maxi(0, damage - BASE_PREVENTION)
	var enhanced_damage := maxi(0, damage - ENHANCED_PREVENTION)
	return {"ok": true, "reason": &"current_response", "scope": &"current_public_attack_no_future_board", "event_id": event.event_id, "target_runtime_id": target.get_instance_id(), "target_hp": hp, "damage": damage, "hp_after_pass": maxi(0, hp - damage), "heat": heat, "depth": bt.context.depth_pressure, "preview": preview,
		"base": {"ok": available, "heat_cost": HAND_HEAT_COST, "depth_cost": 0, "prevention": BASE_PREVENTION, "remaining_damage": base_damage, "hp_after": maxi(0, hp - base_damage)},
		"enhanced": {"ok": available and bt.context.depth_pressure < ENHANCED_DEPTH_LIMIT, "heat_cost": HAND_HEAT_COST, "depth_cost": 1, "prevention": ENHANCED_PREVENTION, "remaining_damage": enhanced_damage, "hp_after": maxi(0, hp - enhanced_damage)}}

func choose(id: int, mode: String) -> Dictionary:
	if not waiting or event.get("event_id", -1) != id: return {"ok": false, "reason": "响应窗口已结束"}
	if mode not in ["base", "enhanced", "pass", "skip"]: return {"ok": false, "reason": "未知选择"}
	if mode in ["base", "enhanced"]:
		if not _legal_candidate(event): return {"ok": false, "reason": "原行动已失效，请放过"}
		if hand_used or _hand_card() == null or _bt().context.od_mode.current_od < HAND_HEAT_COST:
			return {"ok": false, "reason": "手牌或 OD 不足，请放过"}
		if mode == "enhanced" and _bt().context.depth_pressure >= ENHANCED_DEPTH_LIMIT:
			return {"ok": false, "reason": "Depth 达到 5，不能透支"}
	selected = mode
	skip_turn = mode == "skip" or skip_turn
	waiting = false
	return {"ok": true}

func _consume(card: CardData) -> void:
	var bt = _bt()
	bt.context.player.hand.erase(card)
	bt.context.player.traps.erase(card)
	bt.move_card_to_graveyard_once(card)

func intercept_move(actor: CardData, destination: Vector2i) -> bool:
	if event.get("command_id", "") != "move" or event.get("actor_runtime_id", 0) != actor.get_instance_id() or event.get("target_cell") != destination: return false
	var bt = _bt()
	var origin: Vector2i = bt.get_unit_cell(actor)
	for card in bt.context.player.traps.duplicate():
		if card.card_id != "P04": continue
		var cells := watch_cells(card)
		if not cells.has(destination) or cells.has(origin): continue
		var source_cell: Vector2i = bt._anchor_cell_of_rid(card.get_instance_id())
		_consume(card)
		history.append({"kind": "tripwire", "event_id": sequence, "cell": destination})
		if bt.core_siege_trial != null: bt.core_siege_trial.suppress_column(destination.x)
		bt.back_row_triggered.emit(card, {"kind": &"tripwire", "source_cell": source_cell, "target_cell": destination, "opened_column": destination.x if bt.core_siege_trial != null else -1, "consumed": true, "event_id": sequence})
		return true
	return false

func reduce_damage(target: CardData, amount: int, source: String) -> int:
	if event.get("command_id", "") != "attack" or event.get("target_runtime_id", 0) != target.get_instance_id() or event.get("reduced", false) or source != "simultaneous": return amount
	event["reduced"] = true
	var bt = _bt()
	var remaining := amount
	for card in bt.context.player.traps.duplicate():
		if remaining <= 0: break
		if card.card_id != "R01" or not watch_cells(card).has(bt.get_unit_cell(target)): continue
		var prevented := mini(3, remaining)
		var source_cell: Vector2i = bt._anchor_cell_of_rid(card.get_instance_id())
		remaining = maxi(0, remaining - 3)
		_consume(card)
		history.append({"kind": "prepared", "event_id": sequence, "prevented": prevented})
		bt.back_row_triggered.emit(card, {"kind": &"prepared", "source_cell": source_cell, "target_cell": bt.get_unit_cell(target), "prevented": prevented, "remaining_damage": remaining, "consumed": true, "event_id": sequence})
	if remaining > 0 and selected in ["base", "enhanced"] and not hand_used and _hand_card() != null and bt.context.od_mode.current_od >= HAND_HEAT_COST:
		if selected != "enhanced" or bt.context.depth_pressure < ENHANCED_DEPTH_LIMIT:
			var card := _hand_card()
			hand_used = true
			_consume(card)
			bt.context.od_mode.add_heat(-HAND_HEAT_COST, &"reaction_hand")
			if selected == "enhanced": bt.context.add_depth(1, "应急偏转")
			var prevention := ENHANCED_PREVENTION if selected == "enhanced" else BASE_PREVENTION
			history.append({"kind": "hand", "event_id": sequence, "prevented": mini(prevention, remaining)})
			remaining = maxi(0, remaining - prevention)
	return remaining

func finish_event() -> void:
	event = {}
	waiting = false
	selected = ""
