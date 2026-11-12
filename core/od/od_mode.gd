extends Node
class_name ODMode

const TC = preload("res://core/theme/theme_colors.gd")
const BattleRuleSnapshotClass := preload("res://core/config/battle_rule_snapshot.gd")
const ODFlowFeedbackSnapshotClass := preload("res://core/config/od_flow_feedback_snapshot.gd")
const ODFeedbackLedgerClass := preload("res://core/od/od_feedback_ledger.gd")

# ===== 三段式 OD Zone 枚举（保留兼容）=====
enum Zone {
	CALM = 0,
	HEATED = 1,
	OVERDRIVE = 2
}

# ═══════════════════════════════════════════
# Phase 7A-1: 五层引擎系统常量
# ═══════════════════════════════════════════

## 五层引擎总层数
const ENGINE_LAYER_COUNT := 5

## 每层 Engine OD 容量（逐层递增）
# Phase 15E: increased to slow early progression (was [0,3,4,4,5,5])
const ENGINE_LAYER_CAPACITY := [0, 4, 5, 6, 6, 7]  # index 1-5, index 0 unused

## 每层前场怪兽槽位限制
const ENGINE_FRONT_SLOT_LIMIT := [0, 2, 3, 4, 5, 5]

## 每层每回合怪兽可打出上限（保留，暂不接入）
const ENGINE_MONSTER_PLAY_LIMIT := [0, 1, 2, 2, 3, 3]

## Burst 基础持续回合
const BURST_BASE_TURNS := 1
## Burst 最多持续回合
const BURST_MAX_TURNS := 2

# ═══════════════════════════════════════════
# 五层引擎运行时字段
# ═══════════════════════════════════════════

## 当前引擎层 (1-5)
var engine_layer: int = 1

## 当前层内的 Engine OD 充能 (0 ~ 当前层容量)
var engine_charge: int = 0

## 累计总 OD 点数（所有正向 gain 之和）
var engine_total_points: int = 0

## Burst 剩余回合（>0 表示处于爆发状态）
var burst_turns_remaining: int = 0

## 本回合 Engine OD 正向 gain 合计
var turn_engine_gain: int = 0

## 本回合升层次数
var turn_layers_gained: int = 0

## Phase 27J-R0: 短周期热量与长期转换统计
var heat_total_gained: int = 0
var turn_heat_gained: int = 0
var heat_total_converted: int = 0
var turn_heat_converted: int = 0
var peak_heat: int = 0

## 同一提交事务内，同一来源只接收一次基础热量。
var _heat_receipts: Dictionary = {}

## Phase 27K-R1-A: read-only committed-event audit. These objects never own
## Heat rules; ODMode remains the sole numeric authority.
var _flow_feedback_snapshot: RefCounted = ODFlowFeedbackSnapshotClass.default_snapshot()
var _feedback_ledger: RefCounted = ODFeedbackLedgerClass.new()

# ═══════════════════════════════════════════
# 旧系统兼容字段（保持不变）
# ═══════════════════════════════════════════

## 兼容 OD 值 (0-10)，由 _sync_compat_current_od() 自动同步
var current_od: int = 0

## Older scenes retain Load penalties; current GB3J uses explicit Depth pressure.
var legacy_load_penalty_enabled: bool = true

## 外部引用
var context

## 当前回合累计 Load
var load: int = 0

# ===== 旧常量（保留兼容）=====
const CALM_MAX := 3
const HEATED_MAX := 7
const MAX_OD := 10
var max_value: int = MAX_OD

# Phase 25B: 规则快照驱动
var _rule_snapshot = BattleRuleSnapshotClass.default_snapshot()

func configure_rules(snapshot) -> void:
	_rule_snapshot = snapshot if snapshot != null else BattleRuleSnapshotClass.default_snapshot()
	max_value = _rule_snapshot.od_max
	_sync_compat_current_od()

# ===== 区间名称与颜色 =====
const ZONE_NAMES := {
	Zone.CALM: "Calm",
	Zone.HEATED: "Heated",
	Zone.OVERDRIVE: "Overdrive",
}

const ZONE_COLORS := {
	Zone.CALM: TC.ZONE_CALM,
	Zone.HEATED: TC.ZONE_HEATED,
	Zone.OVERDRIVE: TC.ZONE_OVERDRIVE,
}

const DAMAGE_TAKEN_MULTIPLIER := {
	Zone.CALM: 1.0,
	Zone.HEATED: 1.2,
	Zone.OVERDRIVE: 1.5,
}

const LOAD_LIMIT_BY_ZONE := {
	Zone.CALM: 5,
	Zone.HEATED: 4,
	Zone.OVERDRIVE: 4,
}

const OVERLOAD_BASE_DAMAGE := 1

const OVERLOAD_PENALTY_MULTIPLIER := {
	Zone.CALM: 1.0,
	Zone.HEATED: 1.5,
	Zone.OVERDRIVE: 2.0,
}

# ===== 五层名称与颜色映射 =====
const ENGINE_LAYER_NAMES := {
	1: "Ignition",
	2: "Regulation",
	3: "Pressurization",
	4: "Superheat",
	5: "Detonation",
}

const ENGINE_LAYER_NAMES_CN := {
	1: "点火",
	2: "稳压",
	3: "增压",
	4: "过热",
	5: "爆发",
}

const ENGINE_LAYER_COLORS := {
	1: Color(0.18, 0.80, 0.25, 1),   # 绿
	2: Color(0.00, 0.81, 0.82, 1),    # 青
	3: Color(0.20, 0.60, 0.86, 1),    # 蓝
	4: Color(0.56, 0.27, 0.68, 1),    # 紫
	5: Color(1.0, 0.25, 0.06, 1),     # 红金
}

# =========================
# 初始化
# =========================
func setup(_context):
	context = _context
	_feedback_ledger.call("configure", _flow_feedback_snapshot)


func configure_flow_feedback(snapshot: RefCounted) -> void:
	_flow_feedback_snapshot = snapshot if snapshot != null else ODFlowFeedbackSnapshotClass.default_snapshot()
	_feedback_ledger.call("configure", _flow_feedback_snapshot)


func get_feedback_events_after(after_sequence: int) -> Array[Dictionary]:
	return _feedback_ledger.call("get_events_after", after_sequence)


func get_feedback_sequence() -> int:
	return int(_feedback_ledger.call("get_latest_sequence"))


func get_heat_flow_snapshot() -> Dictionary:
	var result := get_heat_cycle_snapshot()
	result["latest_sequence"] = get_feedback_sequence()
	result["buffered_event_count"] = (get_feedback_events_after(0) as Array).size()
	result["saturation_enabled"] = false
	return result.duplicate(true)


func get_heat_source_descriptor(source_kind: StringName, source_id: StringName, card_id: String = "") -> Dictionary:
	if _flow_feedback_snapshot != null and _flow_feedback_snapshot.has_method("get_source_descriptor"):
		return _flow_feedback_snapshot.get_source_descriptor(source_kind, source_id, card_id)
	return {
		"classified": false,
		"source_kind": source_kind,
		"source_id": source_id,
		"source_family": &"unclassified",
		"source_policy": &"bounded_existing",
		"presentation_tier": &"micro",
	}


# ═══════════════════════════════════════════
# Phase 7A-1: 五层引擎核心方法
# ═══════════════════════════════════════════

## 获取当前引擎层 (1-5)
func get_engine_layer() -> int:
	return engine_layer


## 获取当前层名称（英文）
func get_engine_layer_name() -> String:
	return ENGINE_LAYER_NAMES.get(engine_layer, "Unknown")


## 获取当前层中文名称
func get_engine_layer_name_cn() -> String:
	return ENGINE_LAYER_NAMES_CN.get(engine_layer, "未知")


## 获取当前层 Engine OD 充能
func get_engine_charge() -> int:
	return engine_charge


## 获取当前层容量
func get_engine_capacity() -> int:
	return ENGINE_LAYER_CAPACITY[clampi(engine_layer, 1, 5)]


## 获取当前层进度 (0.0 ~ 1.0)
func get_engine_progress_ratio() -> float:
	var cap := get_engine_capacity()
	if cap <= 0:
		return 0.0
	return clampf(float(engine_charge) / float(cap), 0.0, 1.0)


# ═══════════════════════════════════════════
# Phase 26C: 引擎充能消费权威 API
# ═══════════════════════════════════════════

## 检查是否可以消费指定数量的 engine_charge
func can_spend_engine_charge(amount: int) -> bool:
	return amount > 0 and engine_charge >= amount


## 原子消费 engine_charge，返回结构化结果 Dictionary
## 不回退 engine_layer，不修改 engine_total_points
# PHASE55_BEGIN_REFUND
## Failed paid action refund: no earned points, layer advancement or Burst.
func refund_engine_charge(amount: int, source: StringName = &"") -> Dictionary:
	if amount<=0:return {"ok":false,"reason_code":&"invalid_amount","restored":0}
	var before: int=engine_charge
	engine_charge=mini(get_engine_capacity(),engine_charge+amount)
	_sync_compat_current_od();_sync_to_player()
	if context:context.emit_signal("od_changed",current_od,0,get_zone())
	return {"ok":true,"source":source,"requested":amount,"restored":engine_charge-before,"charge_before":before,"charge_after":engine_charge,"layer":engine_layer}
# PHASE55_END_REFUND
func spend_engine_charge(amount: int, source: StringName = &"") -> Dictionary:
	var before_charge := engine_charge
	var before_layer := engine_layer
	var before_od := current_od
	var before_zone := get_zone()

	if amount <= 0:
		return _charge_spend_result(false, &"invalid_amount", amount, source,
			before_charge, before_layer, before_od, before_zone)
	if engine_charge < amount:
		return _charge_spend_result(false, &"insufficient_charge", amount, source,
			before_charge, before_layer, before_od, before_zone)

	engine_charge -= amount
	_sync_compat_current_od()
	var after_zone := get_zone()

	# 信号：od_changed 通过 context 发出
	if context:
		context.emit_signal("od_changed", current_od, 0, after_zone)
	if after_zone != before_zone and context:
		context.emit_signal("od_zone_changed", after_zone, before_zone)

	_sync_to_player()
	return _charge_spend_result(true, &"", amount, source,
		before_charge, before_layer, before_od, before_zone)


func _charge_spend_result(ok: bool, reason_code: StringName, amount: int, source: StringName,
		charge_before: int, layer_before: int, od_before: int, zone_before: int) -> Dictionary:
	return {
		"ok": ok,
		"reason_code": reason_code,
		"source": source,
		"amount": amount,
		"charge_before": charge_before,
		"charge_after": engine_charge if ok else charge_before,
		"layer_before": layer_before,
		"layer_after": engine_layer if ok else layer_before,
		"od_before": od_before,
		"od_after": current_od if ok else od_before,
		"zone_before": zone_before,
		"zone_after": get_zone() if ok else zone_before,
	}


## 获取前场怪兽槽位限制（五层驱动）
func get_front_slot_limit() -> int:
	return ENGINE_FRONT_SLOT_LIMIT[clampi(engine_layer, 1, 5)]


## 获取每回合怪兽打出上限（保留）
func get_monster_play_limit() -> int:
	return ENGINE_MONSTER_PLAY_LIMIT[clampi(engine_layer, 1, 5)]


## 是否处于 Burst 爆发状态
func is_burst_active() -> bool:
	return burst_turns_remaining > 0


## 五层引擎摘要（供 UI/详情面板使用）
func get_engine_summary() -> Dictionary:
	return {
		"layer": engine_layer,
		"layer_name": get_engine_layer_name(),
		"layer_name_cn": get_engine_layer_name_cn(),
		"charge": engine_charge,
		"capacity": get_engine_capacity(),
		"progress": get_engine_progress_ratio(),
		"front_slots": get_front_slot_limit(),
		"monster_play_limit": get_monster_play_limit(),
		"burst_turns": burst_turns_remaining,
		"compat_od": current_od,
		"total_points": engine_total_points,
		"turn_gain": turn_engine_gain,
		"turn_layers": turn_layers_gained,
		"heat": current_od,
		"zone": get_zone_name(),
		"peak_heat": peak_heat,
		"total_heat_gained": heat_total_gained,
		"turn_heat_gained": turn_heat_gained,
		"total_heat_converted": heat_total_converted,
		"turn_heat_converted": turn_heat_converted,
	}


# ═══════════════════════════════════════════
# Phase 7A-1: 兼容 current_od 同步
# ═══════════════════════════════════════════

## Phase 27J-R0: current_od 是短周期热量权威，不再由 Layer 反推。
func _sync_compat_current_od() -> void:
	current_od = _rule_snapshot.clamp_od(current_od)
	peak_heat = maxi(peak_heat, current_od)


# ═══════════════════════════════════════════
# Zone 查询（保留旧 API 完全兼容）
# ═══════════════════════════════════════════

## Phase 25B: 获取旧 Zone 枚举 — 由快照 current_od 判定
func get_zone() -> int:
	match _rule_snapshot.get_od_zone_id(current_od):
		"Heated": return Zone.HEATED
		"Overdrive": return Zone.OVERDRIVE
		_: return Zone.CALM


func get_zone_name() -> String:
	return _rule_snapshot.get_od_zone_id(current_od)


func get_zone_color() -> Color:
	return ZONE_COLORS.get(get_zone(), Color.WHITE)


func is_calm() -> bool:
	return get_zone() == Zone.CALM


func is_heated() -> bool:
	return get_zone() == Zone.HEATED


func is_overdrive() -> bool:
	return get_zone() == Zone.OVERDRIVE


func get_current_zone() -> int:
	return get_zone()


func get_current_zone_name() -> String:
	return get_zone_name()


func get_current_zone_color() -> Color:
	return get_zone_color()


func get_damage_taken_multiplier() -> float:
	return DAMAGE_TAKEN_MULTIPLIER.get(get_zone(), 1.0)


# =========================
# Load 系统（不改）
# =========================
func get_load_limit() -> int:
	return LOAD_LIMIT_BY_ZONE.get(get_zone(), 5)


func get_load_info() -> Dictionary:
	return {
		"current": load,
		"limit": get_load_limit(),
		"zone": get_zone_name(),
	}


func is_overloaded() -> bool:
	return legacy_load_penalty_enabled and load > get_load_limit()


func would_overload(extra_load: int) -> bool:
	return legacy_load_penalty_enabled and (load + extra_load) > get_load_limit()


# ═══════════════════════════════════════════
# Phase 7A-1: OD 增减（五层引擎核心）
# ═══════════════════════════════════════════

func get_od_gain(card) -> int:
	# Phase 7A-5: engine_gain 优先，-999 fallback to od_cost
	# Phase 8A-Hotfix: 移除 card.has() — CardData 不是 Dictionary
	if card == null:
		return 0
	if card.engine_gain != -999:
		return maxi(0, card.engine_gain)
	return maxi(0, card.od_cost)


## 增加 OD — Phase 7A-1 重写：引擎充能 + 层推进
func add_od(value: int):
	return add_heat(value, &"legacy:add_od", &"")


## Phase 27J-R0: 短周期热量唯一写入口。
## 非空 transaction_id + source 形成幂等收据；不同来源仍可显式叠加。
func add_heat(amount: int, source: StringName = &"", transaction_id: StringName = &"", options: Dictionary = {}) -> Dictionary:
	var notifications: Array[Dictionary] = []
	var deferred: bool = bool(options.get("defer_signal", false))
	var heat_before := current_od
	var zone_before := get_zone()
	var charge_before := engine_charge
	var layer_before := engine_layer
	var depth_before := int(context.depth_pressure) if context != null and "depth_pressure" in context else 0
	var receipt_key := ""
	if transaction_id != &"":
		receipt_key = "%s|%s" % [String(transaction_id), String(source)]
		if _heat_receipts.has(receipt_key):
			return _heat_result(true, &"", amount, 0, source, transaction_id, true,
				heat_before, zone_before)

	var heat_after := clampi(current_od + amount, 0, max_value)
	var applied := heat_after - current_od
	current_od = heat_after
	if receipt_key != "":
		_heat_receipts[receipt_key] = applied
	if applied > 0:
		heat_total_gained += applied
		turn_heat_gained += applied
		peak_heat = maxi(peak_heat, current_od)

	if applied != 0:
		_deliver_card_notification({"kind": &"audio", "sound": "od_up" if applied > 0 else "od_down"}, deferred, notifications)

	_sync_to_player()
	var zone_after := get_zone()
	if context:
		_deliver_card_notification({"kind": &"od_changed", "args": [current_od, 0, zone_after]}, deferred, notifications)
		if zone_after != zone_before:
			_deliver_card_notification({"kind": &"od_zone_changed", "args": [zone_after, zone_before]}, deferred, notifications)
	if zone_after != zone_before:
		print("[HEAT] Zone changed: %s -> %s (Heat=%d, Layer=%d, Charge=%d/%d)" % [
			ZONE_NAMES.get(zone_before, "?"), ZONE_NAMES.get(zone_after, "?"),
			current_od, engine_layer, engine_charge, get_engine_capacity()])
	if heat_before < max_value and current_od >= max_value:
		notifications.append_array(on_full(options))
	var payload := _build_feedback_payload(source, options, amount, applied,
		heat_before, current_od, charge_before, engine_charge, layer_before, engine_layer,
		zone_before, zone_after, depth_before)
	var event_kind := &"heat_committed" if amount > 0 else &"heat_cooled"
	if amount != 0:
		var event: Dictionary = _commit_feedback_event(event_kind, transaction_id, payload, deferred)
		if deferred and not bool(event.get("deduplicated", false)):
			notifications.append({"kind": &"feedback", "event": event.duplicate(true)})
	if zone_after != zone_before:
		var event: Dictionary = _commit_feedback_event(&"zone_changed", transaction_id, payload, deferred)
		if deferred and not bool(event.get("deduplicated", false)):
			notifications.append({"kind": &"feedback", "event": event.duplicate(true)})
	var result := _heat_result(true, &"", amount, applied, source, transaction_id, false, heat_before, zone_before)
	if deferred:
		result.notifications = notifications
	return result


func _heat_result(ok: bool, reason_code: StringName, requested: int, applied: int,
		source: StringName, transaction_id: StringName, deduplicated: bool,
		heat_before: int, zone_before: int) -> Dictionary:
	return {
		"ok": ok,
		"reason_code": reason_code,
		"source": source,
		"transaction_id": transaction_id,
		"requested": requested,
		"applied": applied,
		"deduplicated": deduplicated,
		"heat_before": heat_before,
		"heat_after": current_od if ok else heat_before,
		"zone_before": zone_before,
		"zone_after": get_zone() if ok else zone_before,
	}


func clear_heat_transaction(transaction_id: StringName) -> void:
	if transaction_id == &"":
		return
	var prefix := "%s|" % String(transaction_id)
	for key in _heat_receipts.keys():
		if str(key).begins_with(prefix):
			_heat_receipts.erase(key)


func get_heat_cycle_snapshot() -> Dictionary:
	return {
		"heat": current_od,
		"heat_max": max_value,
		"zone": get_zone_name(),
		"layer": engine_layer,
		"charge": engine_charge,
		"capacity": get_engine_capacity(),
		"total_gained": heat_total_gained,
		"turn_gained": turn_heat_gained,
		"total_converted": heat_total_converted,
		"turn_converted": turn_heat_converted,
		"peak_heat": peak_heat,
	}


func can_convert_heat(amount: int) -> bool:
	return amount > 0 and current_od >= amount


## 将已提交的短周期热量转换为长期引擎进度。Layer 永不回退。
func convert_heat(amount: int, source: StringName = &"", options: Dictionary = {}) -> Dictionary:
	var heat_before := current_od
	var layer_before := engine_layer
	var charge_before := engine_charge
	var zone_before := get_zone()
	if amount <= 0:
		return _heat_conversion_result(false, &"invalid_amount", amount, source,
			heat_before, layer_before, charge_before, zone_before)
	if current_od < amount:
		return _heat_conversion_result(false, &"insufficient_heat", amount, source,
			heat_before, layer_before, charge_before, zone_before)

	current_od -= amount
	_add_engine_charge(amount)
	turn_engine_gain += amount
	engine_total_points += amount
	heat_total_converted += amount
	turn_heat_converted += amount
	_sync_to_player()
	var zone_after := get_zone()
	if context:
		context.emit_signal("od_changed", current_od, 0, zone_after)
		if zone_after != zone_before:
			context.emit_signal("od_zone_changed", zone_after, zone_before)
	var transaction_id := StringName(options.get("transaction_id", &""))
	var depth_before := int(context.depth_pressure) if context != null and "depth_pressure" in context else 0
	var payload := _build_feedback_payload(source, options, -amount, -amount,
		heat_before, current_od, charge_before, engine_charge, layer_before, engine_layer,
		zone_before, zone_after, depth_before)
	payload["conversion_amount"] = amount
	_commit_feedback_event(&"heat_converted", transaction_id, payload)
	if engine_layer > layer_before:
		_commit_feedback_event(&"layer_advanced", transaction_id, payload)
	if zone_after != zone_before:
		_commit_feedback_event(&"zone_changed", transaction_id, payload)
	return _heat_conversion_result(true, &"", amount, source,
		heat_before, layer_before, charge_before, zone_before)


func append_feedback_event(event_kind: StringName, transaction_id: StringName, payload: Dictionary) -> Dictionary:
	return _commit_feedback_event(event_kind, transaction_id, payload)


func build_feedback_state_payload(source: StringName, options: Dictionary = {}) -> Dictionary:
	var zone := get_zone()
	var depth := int(context.depth_pressure) if context != null and "depth_pressure" in context else 0
	return _build_feedback_payload(source, options, 0, 0,
		current_od, current_od, engine_charge, engine_charge, engine_layer, engine_layer,
		zone, zone, depth)


func _build_feedback_payload(source: StringName, options: Dictionary, raw_delta: int, applied_delta: int,
		heat_before: int, heat_after: int, charge_before: int, charge_after: int,
		layer_before: int, layer_after: int, zone_before: int, zone_after: int,
		depth_before: int) -> Dictionary:
	var descriptor: Dictionary = options.get("source_descriptor", {})
	if descriptor.is_empty() and _flow_feedback_snapshot != null:
		var kind := StringName(str(source).split(":")[0] if str(source).contains(":") else "unclassified")
		if str(source).begins_with("base_card:"):
			kind = &"card_base"
		descriptor = _flow_feedback_snapshot.call("get_source_descriptor", kind, source)
	var event_kind := StringName(options.get("event_kind", &"heat_committed"))
	var family := StringName(descriptor.get("source_family", &"unclassified"))
	var tier := StringName(descriptor.get("presentation_tier", &""))
	if tier == &"" and _flow_feedback_snapshot != null:
		tier = _flow_feedback_snapshot.call("get_event_tier", event_kind)
	var coalescing := StringName(options.get("coalescing_key", &""))
	if coalescing == &"" and _flow_feedback_snapshot != null:
		coalescing = _flow_feedback_snapshot.call("get_coalescing_key", event_kind, family)
	return {
		"actor_side": StringName(options.get("actor_side", &"player")),
		"source_kind": StringName(descriptor.get("source_kind", &"unclassified")),
		"source_id": StringName(descriptor.get("source_id", source)),
		"source_family": family,
		"source_policy": StringName(descriptor.get("source_policy", &"bounded_existing")),
		"classified": bool(descriptor.get("classified", false)),
		"raw_heat_delta": raw_delta,
		"saturation_penalty": 0,
		"applied_heat_delta": applied_delta,
		"wasted_at_cap": maxi(0, raw_delta - applied_delta) if raw_delta > 0 else 0,
		"heat_before": heat_before,
		"heat_after": heat_after,
		"charge_before": charge_before,
		"charge_after": charge_after,
		"layer_before": layer_before,
		"layer_after": layer_after,
		"zone_before": StringName(ZONE_NAMES.get(zone_before, "Calm")),
		"zone_after": StringName(ZONE_NAMES.get(zone_after, "Calm")),
		"depth_before": depth_before,
		"depth_after": int(context.depth_pressure) if context != null and "depth_pressure" in context else depth_before,
		"saturation_step_before": 0,
		"saturation_step_after": 0,
		"relief_action_family": &"",
		"conversion_reason": StringName(options.get("conversion_reason", &"")),
		"board_cell": options.get("board_cell", Vector2i(-1, -1)),
		"target_cell": options.get("target_cell", Vector2i(-1, -1)),
		"piece_type": StringName(options.get("piece_type", &"")),
		"presentation_tier": tier if tier != &"" else &"micro",
		"coalescing_key": coalescing,
		"occurrence_id": StringName(options.get("occurrence_id", &"0")),
	}


func _commit_feedback_event(event_kind: StringName, transaction_id: StringName, payload: Dictionary, defer_signal: bool = false) -> Dictionary:
	var prepared := payload.duplicate(true)
	prepared["event_kind"] = event_kind
	if _flow_feedback_snapshot != null:
		prepared["presentation_tier"] = _flow_feedback_snapshot.call("get_event_tier", event_kind)
		prepared["coalescing_key"] = _flow_feedback_snapshot.call("get_coalescing_key", event_kind, StringName(prepared.get("source_family", &"unclassified")))
	var event: Dictionary = _feedback_ledger.call("append_committed_event", event_kind, transaction_id, prepared)
	if not defer_signal and not bool(event.get("deduplicated", false)) and context != null and context.has_signal("od_feedback_event_committed"):
		context.emit_signal("od_feedback_event_committed", event.duplicate(true))
	return event


func _heat_conversion_result(ok: bool, reason_code: StringName, amount: int,
		source: StringName, heat_before: int, layer_before: int,
		charge_before: int, zone_before: int) -> Dictionary:
	return {
		"ok": ok,
		"reason_code": reason_code,
		"source": source,
		"amount": amount,
		"heat_before": heat_before,
		"heat_after": current_od if ok else heat_before,
		"layer_before": layer_before,
		"layer_after": engine_layer if ok else layer_before,
		"charge_before": charge_before,
		"charge_after": engine_charge if ok else charge_before,
		"zone_before": zone_before,
		"zone_after": get_zone() if ok else zone_before,
	}


## 内部：将正向 OD 注入引擎充能，自动推进层级
func _add_engine_charge(amount: int) -> void:
	var remaining := amount
	while remaining > 0 and engine_layer <= ENGINE_LAYER_COUNT:
		var cap := get_engine_capacity()
		var space := cap - engine_charge
		if space <= 0:
			# 当前层已满 → 升层
			_advance_layer()
			continue
		if remaining <= space:
			engine_charge += remaining
			remaining = 0
		else:
			# 填充当前层，剩余进入下一层
			engine_charge = cap
			remaining -= space
			_advance_layer()


## 内部：推进到下一层（如有）
func _advance_layer() -> void:
	if engine_layer >= ENGINE_LAYER_COUNT:
		# 已在最高层 → 触发/延长 Burst
		if burst_turns_remaining <= 0:
			burst_turns_remaining = BURST_BASE_TURNS
		else:
			burst_turns_remaining = mini(burst_turns_remaining + 1, BURST_MAX_TURNS)
		engine_charge = 0  # Layer 5 溢出后重置充能
		return

	var old_layer := engine_layer
	engine_layer += 1
	engine_charge = 0
	turn_layers_gained += 1
	print("[ENGINE] Layer advanced: %d (%s) -> %d (%s) | Total Points: %d" % [
		old_layer,
		ENGINE_LAYER_NAMES.get(old_layer, "?"),
		engine_layer,
		ENGINE_LAYER_NAMES.get(engine_layer, "?"),
		engine_total_points
	])


# ═══════════════════════════════════════════
# 旧系统兼容（不变）
# ═══════════════════════════════════════════

## Phase 25B-R1: player.od 镜像 current_od；player.od_phase 由快照 Zone 直接写入
func _sync_to_player():
	if context and is_instance_valid(context.player):
		context.player.od = current_od
		context.player.od_phase = get_zone()


func on_full(options: Dictionary = {}) -> Array[Dictionary]:
	print("[OD] FULL! Awakening available. Layer=%d (%s)" % [engine_layer, get_engine_layer_name_cn()])
	if context.has_method("enter_awakening"):
		if bool(options.get("defer_signal", false)):
			return context.enter_awakening(options)
		context.enter_awakening()
	return []


# ═══════════════════════════════════════════
# Phase 7A-1: 回合重置
# ═══════════════════════════════════════════

func reset_turn():
	load = 0
	turn_engine_gain = 0
	turn_layers_gained = 0
	turn_heat_gained = 0
	turn_heat_converted = 0
	_heat_receipts.clear()

	# Burst 倒计时
	if burst_turns_remaining > 0:
		burst_turns_remaining -= 1
		if burst_turns_remaining <= 0:
			print("[ENGINE] Burst ended. Layer stays at %d (%s)" % [engine_layer, get_engine_layer_name_cn()])
			# 注意：Burst 结束后不回退 engine_layer，但旧 Zone 映射会从 OVERDRIVE 变回

	if context and context.player:
		context.player.temp_damage_bonus = 0


func on_turn_end():
	pass


func get_card_od_cost(card):
	return get_od_gain(card)


# =========================
# 出牌触发（保持兼容）
# =========================
func on_card_played(card, transaction_id: StringName = &"", source_descriptor: Dictionary = {}, options: Dictionary = {}) -> Array[Dictionary]:
	# 1. 基础热量：同一出牌事务仅接收一次，不直接推进 Layer。
	var gain = get_od_gain(card)
	var card_key := str(card.card_id) if card != null and "card_id" in card else str(card.get_instance_id())
	var source_id := StringName("base_card:%s" % card_key)
	var descriptor := source_descriptor.duplicate(true)
	if descriptor.is_empty():
		descriptor = get_heat_source_descriptor(&"card_base", source_id, card_key)
	var heat: Dictionary = add_heat(gain, source_id, transaction_id, {
		"defer_signal": bool(options.get("defer_signal", false)),
		"source_descriptor": descriptor,
		"occurrence_id": &"base",
		"card_id": card_key,
	})
	print("[LOAD] Playing '%s' | Heat+%d (now %d, Layer %d) | Load+%d -> %d/%d" % [
		card.card_name,
		gain,
		current_od,
		engine_layer,
		card.load_cost,
		load + card.load_cost,
		get_load_limit()
	])

	# 2. Load 累加
	load += card.load_cost

	# 3. 过载检测
	var notifications: Array[Dictionary] = []
	notifications.append_array(heat.get("notifications", []))
	notifications.append_array(check_overload(transaction_id, options))
	return notifications


# =========================
# 过载检测（不改）
# =========================
func check_overload(transaction_id: StringName = &"", options: Dictionary = {}) -> Array[Dictionary]:
	if not legacy_load_penalty_enabled: return []
	var limit := get_load_limit()
	if load > limit:
		return apply_overload_penalty(transaction_id, options)
	return []


# =========================
# 过载惩罚（不改）
# =========================
func apply_overload_penalty(transaction_id: StringName = &"", options: Dictionary = {}) -> Array[Dictionary]:
	if not legacy_load_penalty_enabled: return []
	var zone = get_zone()
	var zone_name: String = ZONE_NAMES.get(zone, "?")
	var mult: float = OVERLOAD_PENALTY_MULTIPLIER.get(zone, 1.0)
	var dmg := ceili(OVERLOAD_BASE_DAMAGE * mult)

	context.player.hp -= dmg
	context.player.temp_damage_bonus -= dmg

	var source_id := &"pressure:overload_penalty"
	var heat: Dictionary = add_heat(1, source_id, transaction_id, {
		"defer_signal": bool(options.get("defer_signal", false)),
		"source_descriptor": get_heat_source_descriptor(&"pressure", source_id),
		"occurrence_id": &"pressure:overload_penalty",
	})

	print("[OVERLOAD] Load %d > %d in %s zone! Player takes %d damage (x%.1f). OD -> %d, HP -> %d" % [
		load,
		get_load_limit(),
		zone_name,
		dmg,
		mult,
		current_od,
		context.player.hp
	])

	var notifications: Array[Dictionary] = []
	notifications.append_array(heat.get("notifications", []))
	_deliver_card_notification({"kind": &"shake", "strength": 15}, bool(options.get("defer_signal", false)), notifications)
	return notifications


func _am():
	return get_node_or_null("/root/AudioManager")


## Caller-owned receipts only. Drain before callbacks so the same receipt cannot
## be published twice by a synchronous observer. No ledger/state mutation here.
func publish_card_notifications(notifications: Array[Dictionary]) -> void:
	var pending := notifications.duplicate(true)
	notifications.clear()
	for event: Dictionary in pending:
		match event.get("kind", &""):
			&"audio":
				var am = _am()
				if am:
					am.play_sfx(event.sound)
			&"od_changed":
				if context:
					context.emit_signal("od_changed", event.args[0], event.args[1], event.args[2])
			&"od_zone_changed":
				if context:
					context.emit_signal("od_zone_changed", event.args[0], event.args[1])
			&"feedback":
				if context:
					context.emit_signal("od_feedback_event_committed", event.event.duplicate(true))
			&"awakening":
				if context:
					var awakening_receipts: Array[Dictionary] = [event]
					context.publish_card_notifications(awakening_receipts)
			&"shake":
				if context and context.get_parent() and context.get_parent().get("fx"):
					context.get_parent().fx.shake(event.strength)


func _deliver_card_notification(event: Dictionary, deferred: bool, notifications: Array[Dictionary]) -> void:
	if deferred:
		notifications.append(event.duplicate(true))
	else:
		publish_card_notifications([event])
