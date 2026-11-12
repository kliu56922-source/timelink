extends RefCounted
class_name CardPieceTraitSnapshot

## Phase 27I-R0: 不可变卡牌棋子身份快照
## 由 GameConfig 在 battle start 一次性创建，注入 BattleSystem。
## 保存：棋子名称、增强支付规则、profile（几何/锚点/家族）、payload（效果数值）。
## 所有返回的 Array/Dictionary 均为深拷贝；不保存 Node、CardData 或运行时 ID。

var piece_names: Dictionary = {}
var enhanced_payment: Dictionary = {}
var profiles: Dictionary = {}
var payloads: Dictionary = {}
var used_fallback := false
var validation_errors: Array[String] = []

func _init(values: Dictionary = {}, fallback_used := false, errors: Array[String] = []) -> void:
	used_fallback = fallback_used
	validation_errors = errors.duplicate()
	if values.is_empty():
		return
	piece_names = _deep_copy(values.get("piece_names", {}))
	enhanced_payment = _deep_copy(values.get("enhanced_payment", {}))
	var raw_profiles: Dictionary = values.get("profiles", {})
	for key in raw_profiles:
		var entry: Dictionary = raw_profiles[key]
		if not entry is Dictionary:
			continue
		profiles[StringName(str(key))] = _deep_copy(entry)
	var raw_payloads: Dictionary = values.get("payloads", {})
	for key in raw_payloads:
		var entry: Dictionary = raw_payloads[key]
		if not entry is Dictionary:
			continue
		payloads[StringName(str(key))] = _deep_copy(entry)

static func default_snapshot(errors: Array[String] = []) -> CardPieceTraitSnapshot:
	var inst := new()
	inst.used_fallback = true
	inst.validation_errors = errors.duplicate()
	inst.piece_names = {"pawn": "兵卒", "knight": "骑士"}
	inst.enhanced_payment = {"command_cost": 1, "depth_cost": 1, "depth_zone_required": "Overdrive"}
	return inst

func to_snapshot() -> Dictionary:
	return {
		"piece_names": _deep_copy(piece_names),
		"enhanced_payment": _deep_copy(enhanced_payment),
		"profiles": _deep_copy(profiles),
		"payloads": _deep_copy(payloads),
		"used_fallback": used_fallback,
	}

# ── 纯查询 API ──

## 是否存在该棋型 profile
func has_profile(profile_id: StringName) -> bool:
	return profiles.has(profile_id)

## 是否存在该载荷 payload
func has_payload(payload_id: StringName) -> bool:
	return payloads.has(payload_id)

## 深拷贝返回 profile；未知返回 {}
func get_profile(profile_id: StringName) -> Dictionary:
	if not profiles.has(profile_id):
		return {}
	return _deep_copy(profiles[profile_id])

## 深拷贝返回 payload；未知返回 {}
func get_payload(payload_id: StringName) -> Dictionary:
	if not payloads.has(payload_id):
		return {}
	return _deep_copy(payloads[payload_id])

## 棋型类型的中文名；未知返回空字符串
func get_piece_type_name(piece_type: StringName) -> String:
	var raw: Variant = piece_names.get(piece_type, "")
	return str(raw)

## 增强指令费用
func get_enhance_command_cost() -> int:
	return int(enhanced_payment.get("command_cost", 1))

## 增强 Depth 费用
func get_enhance_depth_cost() -> int:
	return int(enhanced_payment.get("depth_cost", 1))

## Depth 支付所需 OD 区域
func get_depth_payment_zone() -> StringName:
	return StringName(str(enhanced_payment.get("depth_zone_required", "Overdrive")))

## 从 CardData 获取 profile_id 对应的 profile（深拷贝）；卡不可用或 profile 缺失返回 {}
func get_profile_for_card(card) -> Dictionary:
	if card == null:
		return {}
	var pid: StringName = StringName(str(card.get("piece_effect_profile_id")))
	if pid == StringName(""):
		return {}
	return get_profile(pid)

## 从 CardData 获取 payload（深拷贝）
func get_payload_for_card(card) -> Dictionary:
	if card == null:
		return {}
	var payload_id: StringName = StringName(str(card.get("piece_payload_id")))
	if payload_id == StringName(""):
		return {}
	return get_payload(payload_id)

func is_fallback() -> bool:
	return used_fallback

# ── 内部工具 ──

func _deep_copy(src: Variant) -> Variant:
	if src is Dictionary:
		var out := {}
		for key in src:
			out[key] = _deep_copy(src[key])
		return out
	if src is Array:
		var out: Array = []
		for item in src:
			out.append(_deep_copy(item))
		return out
	return src
