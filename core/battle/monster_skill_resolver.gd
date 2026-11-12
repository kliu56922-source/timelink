extends RefCounted
class_name MonsterSkillResolver
## Phase 27E: 怪兽主动技能 resolver 白名单注册表
## 每个 resolver 接收 (battle_system, card, target, state, skill_def) → Dictionary

static var _resolvers: Dictionary = {}

static func _ensure_resolvers() -> void:
	if not _resolvers.is_empty(): return
	_resolvers[&"resolve_ignition_leap"] = _resolve_ignition_leap
	_resolvers[&"resolve_stream_cannon"] = _resolve_stream_cannon
	_resolvers[&"resolve_bulwark_advance"] = _resolve_bulwark_advance
	_resolvers[&"resolve_spark_assault"] = _resolve_spark_assault
	_resolvers[&"resolve_chain_relay"] = _resolve_chain_relay

static func resolve(bs: Object, card, target, state: Object, active_def: Dictionary, options: Dictionary = {}) -> Dictionary:
	_ensure_resolvers()
	var resolver_id: StringName = StringName(str(active_def.get("resolver_id", "")))
	var fn: Callable = _resolvers.get(resolver_id, Callable())
	if not fn.is_valid():
		return {"ok": false, "reason_code": "unknown_resolver", "resolver_id": resolver_id}
	return fn.call(bs, card, target, state, active_def, options)


static func _commit_skill_heat(bs: Object, card, skill_id: StringName, amount: int, options: Dictionary) -> Dictionary:
	if amount <= 0 or bs == null or bs.context == null:
		return {"ok": false, "reason_code": &"context_missing"}
	var source_id := StringName("hero_skill:%s" % str(skill_id))
	var transaction_id := StringName(options.get("heat_transaction_id", &""))
	var descriptor: Dictionary = bs.build_heat_source_descriptor(&"hero_skill", source_id, card) if bs.has_method("build_heat_source_descriptor") else {}
	return bs.context.add_heat(amount, source_id, transaction_id, {
		"source_descriptor": descriptor,
		"occurrence_id": skill_id,
		"board_cell": bs.get_unit_cell(card) if bs.has_method("get_unit_cell") else Vector2i(-1, -1),
	})


# ═══════════════════════════════════════
# P02: 点火跃迁
# ═══════════════════════════════════════

static func _resolve_ignition_leap(bs, card, target: Vector2i, state, active_def: Dictionary, options: Dictionary = {}) -> Dictionary:
	var result: Dictionary = {
		"ok": false, "reason_code": "resolution_failed", "skill_id": "ignition_leap",
		"cost": 0, "point_delta": 0,
		"source_cell": state.board_cell, "destination_cell": state.board_cell,
		"stacks_before": 0, "stacks_consumed": 0,
		"od_delta": 0, "atk_bonus": 0, "layer_at_cast": 0,
	}
	var layer_now: int = 1
	if bs.context and bs.context.od_mode:
		layer_now = bs.context.od_mode.get_engine_layer()
	result["layer_at_cast"] = layer_now

	# 1. 获得施放前余烬层数
	var stacks: int = state.get_skill_stack(&"ember_stacks")
	result["stacks_before"] = stacks

	# 2. 消耗全部余烬
	var consumed: int = state.consume_all_skill_stacks(&"ember_stacks")
	result["stacks_consumed"] = consumed

	# 3. 移动到目标格
	var old_cell: Vector2i = state.board_cell
	bs._set_unit_board_cell(state, target)
	result["destination_cell"] = target

	# 4. 根据消耗层数给予奖励
	match consumed:
		0:
			result["atk_bonus"] = 1
			state.add_turn_attack_bonus(1)
		1:
			result["atk_bonus"] = 1
			result["od_delta"] = 1
			state.add_turn_attack_bonus(1)
			_commit_skill_heat(bs, card, &"ignition_leap", 1, options)
		2:
			result["atk_bonus"] = 2
			result["od_delta"] = 1
			state.add_turn_attack_bonus(2)
			_commit_skill_heat(bs, card, &"ignition_leap", 1, options)

	# 5. Layer≥4 且消耗≥1层时返还1点
	if layer_now >= 4 and consumed >= 1:
		result["refund"] = 1

	result["ok"] = true
	result["reason_code"] = "ok"
	return result


# ═══════════════════════════════════════
# P07: 贯流轰击
# ═══════════════════════════════════════

static func _resolve_stream_cannon(bs, card, target, state, active_def: Dictionary, _options: Dictionary = {}) -> Dictionary:
	var result: Dictionary = {
		"ok": false, "reason_code": "resolution_failed", "skill_id": "stream_cannon",
		"cost": 0, "point_delta": 0,
		"source_cell": state.board_cell, "destination_cell": state.board_cell,
		"stacks_before": 0, "stacks_consumed": 0,
		"damage": 0, "bonus_damage": 0, "od_delta": 0, "depth_delta": 0,
		"destroyed_units": [], "advanced": false,
	}
	var layer_now: int = 1
	if bs.context and bs.context.od_mode:
		layer_now = bs.context.od_mode.get_engine_layer()

	# 1. 获取热流层数
	var stacks: int = state.get_skill_stack(&"thermal_stacks")
	result["stacks_before"] = stacks
	var consumed: int = state.consume_all_skill_stacks(&"thermal_stacks")
	result["stacks_consumed"] = consumed

	# 2. 复用普通攻击管线: 执行一次对目标的攻击（不额外扣费）
	var atk_result: Dictionary = bs._execute_unit_attack_internal(card, target)
	result["damage"] = int(atk_result.get("damage", 0))
	result["destroyed_units"] = atk_result.get("destroyed_units", [])

	# 3. 每层热流追加1点技能伤害
	var bonus: int = consumed
	if layer_now >= 5 and consumed >= 3: bonus += 2
	if bonus > 0:
		result["damage"] += bs._apply_skill_attack_damage(card, target, bonus, "skill:stream_cannon")
		if target is CardData:
			var target_state = bs._state_for_card(target)
			if target_state != null and target_state.is_dead() and not target in result["destroyed_units"]:
				result["destroyed_units"].append(target)
	result["bonus_damage"] = bonus

	# 4. 满3层：自动前进1格
	if consumed >= 3:
		if is_instance_valid(card) and card is CardData:
			var move_target: Vector2i = _find_forward_cell(bs, state, target)
			if move_target != Vector2i(-999, -999):
				bs._set_unit_board_cell(state, move_target)
				result["destination_cell"] = move_target
				result["advanced"] = true

	# 5. Layer=5 爆发
	if layer_now >= 5 and consumed >= 3:
		result["depth_delta"] = 1
		if bs.context:
			bs.context.depth_pressure += 1

	result["ok"] = true
	result["reason_code"] = "ok"
	return result


static func _find_forward_cell(bs: Object, state, target) -> Vector2i:
	# 从P07当前格向目标方向找最近的合法空格
	if is_instance_valid(target) and target is CardData:
		var target_state = bs._state_for_card(target)
		if target_state:
			var dir: Vector2i = target_state.board_cell - state.board_cell
			if dir == Vector2i.ZERO:
				dir = Vector2i(0, -1)
			# 归一化方向
			if abs(dir.x) > abs(dir.y):
				dir = Vector2i(signi(dir.x), 0)
			else:
				dir = Vector2i(0, signi(dir.y))
			var forward: Vector2i = state.board_cell + dir
			if bs._is_cell_legal_and_empty(forward):
				return forward
	return Vector2i(-999, -999)


# ═══════════════════════════════════════
# P15: 壁垒推进
# ═══════════════════════════════════════

static func _resolve_bulwark_advance(bs, card, target: Vector2i, state, active_def: Dictionary, _options: Dictionary = {}) -> Dictionary:
	var result: Dictionary = {
		"ok": false, "reason_code": "resolution_failed", "skill_id": "bulwark_advance",
		"cost": 0, "point_delta": 0,
		"source_cell": state.board_cell, "destination_cell": state.board_cell,
		"stacks_before": 0, "stacks_consumed": 0,
		"shield_delta": 0, "depth_delta": 0,
	}

	# 1. 移动（如果不是原地防守）
	if target != state.board_cell:
		bs._set_unit_board_cell(state, target)
		result["destination_cell"] = target

	# 2. 消耗全部压力层数
	var stacks: int = state.get_skill_stack(&"pressure_stacks")
	result["stacks_before"] = stacks
	var consumed: int = state.consume_all_skill_stacks(&"pressure_stacks")
	result["stacks_consumed"] = consumed

	# 3. 基础护盾+2，每层压力+1
	result["shield_delta"] = 2 + consumed
	if bs.context and bs.context.player:
		bs.context.player.shield += 2 + consumed

	# 4. 消耗2层且Depth≥3: Depth-1
	if consumed >= 2 and bs.context and bs.context.depth_pressure >= 3:
		bs.context.depth_pressure -= 1
		result["depth_delta"] = -1

	result["ok"] = true
	result["reason_code"] = "ok"
	return result


# ═══════════════════════════════════════
# P03: 火花突击 (Spark Assault)
# ═══════════════════════════════════════

static func _resolve_spark_assault(bs, card, target, state, active_def: Dictionary, options: Dictionary = {}) -> Dictionary:
	var result: Dictionary = {
		"ok": false, "reason_code": "resolution_failed", "skill_id": "spark_assault",
		"cost": 0, "point_delta": 0,
		"source_cell": state.board_cell, "destination_cell": state.board_cell,
		"stacks_before": 0, "stacks_consumed": 0,
		"damage": 0, "od_delta": 0, "destroyed_units": [],
	}

	# 1. 获取先锋动能层数
	var stacks: int = state.get_skill_stack(&"vanguard_stacks")
	result["stacks_before"] = stacks
	if stacks <= 0:
		result["reason_code"] = "insufficient_stacks"; return result

	# 2. 消耗全部层数
	var consumed: int = state.consume_all_skill_stacks(&"vanguard_stacks")
	result["stacks_consumed"] = consumed

	# 3. 执行技能攻击（复用权威攻击管线）
	var atk_result: Dictionary = bs._execute_unit_attack_internal(card, target)
	result["damage"] = int(atk_result.get("damage", 0))

	# 4. 每消耗一层追加1点技能伤害
	var bonus: int = consumed
	result["destroyed_units"] = atk_result.get("destroyed_units", [])
	if bonus > 0:
		result["damage"] += bs._apply_skill_attack_damage(card, target, bonus, "skill:spark_assault")
		if target is CardData:
			var tgt_state = bs._state_for_card(target)
			if tgt_state != null and tgt_state.is_dead() and not target in result["destroyed_units"]:
				result["destroyed_units"].append(target)

	# 5. 成功命中后玩家 OD +1
	result["od_delta"] = 1
	_commit_skill_heat(bs, card, &"spark_assault", 1, options)

	result["ok"] = true
	result["reason_code"] = "ok"
	return result


# ═══════════════════════════════════════
# P10: 链路转接 (Chain Relay)
# ═══════════════════════════════════════

static func _resolve_chain_relay(bs, card, target: Vector2i, state, active_def: Dictionary, _options: Dictionary = {}) -> Dictionary:
	var result: Dictionary = {
		"ok": false, "reason_code": "resolution_failed", "skill_id": "chain_relay",
		"cost": 0, "point_delta": 0,
		"source_cell": state.board_cell, "destination_cell": state.board_cell,
		"stacks_before": 0, "stacks_consumed": 0,
		"depth_delta": 0, "beneficiary_ids": [], "bonus_value": 0,
	}

	# 1. 获取链路充能层数
	var stacks: int = state.get_skill_stack(&"conductor_stacks")
	result["stacks_before"] = stacks
	if stacks <= 0:
		result["reason_code"] = "insufficient_stacks"; return result

	# 2. 消耗全部层数
	var consumed: int = state.consume_all_skill_stacks(&"conductor_stacks")
	result["stacks_consumed"] = consumed

	# 3. 如果目标是不同格，执行移动（使用原子接口）
	if target != state.board_cell:
		var move_result: Dictionary = bs._assign_unit_cell_atomic(card, target, &"skill_move", true)
		if not bool(move_result.get("ok", false)):
			result["reason_code"] = "cell_occupied"; return result
		result["destination_cell"] = target

	# 4. 查找P10自身 + 正交相邻友军
	var beneficiaries: Array = []
	var p10_cell: Vector2i = state.board_cell  # 使用移动后的cell
	# 自身
	beneficiaries.append(card.get_instance_id())

	# 查找正交相邻友军
	var orth_offsets := [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]
	for off in orth_offsets:
		var check_cell: Vector2i = p10_cell + off
		var occupant = bs.get_unit_at_cell(check_cell)
		if occupant != null and occupant != card:
			if is_instance_valid(occupant):
				var occ_state = bs._state_for_card(occupant)
				if occ_state and occ_state.owner_side == &"player" and not occ_state.is_dead():
					beneficiaries.append(occupant.get_instance_id())

	result["beneficiary_ids"] = beneficiaries
	var bonus: int = consumed
	result["bonus_value"] = bonus

	# 5. 为所有受益单位添加临时ATK
	for rid in beneficiaries:
		var b_card = null
		for c in bs.context.player.field:
			if is_instance_valid(c) and c.get_instance_id() == rid:
				b_card = c
				break
		if b_card:
			var b_state = bs._state_for_card(b_card)
			if b_state:
				b_state.add_turn_attack_bonus(bonus)

	# 6. 消耗2层时 Depth +1
	if consumed >= 2:
		if bs.context:
			bs.context.depth_pressure += 1
			result["depth_delta"] = 1

	result["ok"] = true
	result["reason_code"] = "ok"
	return result
