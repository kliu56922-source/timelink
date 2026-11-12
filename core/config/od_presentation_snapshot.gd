extends RefCounted
class_name ODPresentationSnapshot
## Phase 27K-R0: 纯表现层 OD ENGINE 灰盒视觉快照。
## 所有数值只用于表现（颜色/文字/纹章/动效时长），绝不作为战斗合法性或费用权威。
## 与 ODReleaseRuleSnapshot 一样：不可变、可降级、to_snapshot() 返回副本。

var _values: Dictionary = {}
var _used_fallback := false
var _validation_errors: Array[String] = []


func _init(values: Dictionary = {}, fallback_used := false, errors: Array[String] = []) -> void:
	_values = values.duplicate(true)
	_used_fallback = fallback_used
	_validation_errors = errors.duplicate()


## 缺失/损坏配置时的安全默认值（战斗仍能正常进行）。
static func default_snapshot(errors: Array[String] = []):
	return new({
		"schema_version": 1,
		"heat": {
			"max_segments": 10,
			"zones": [
				{"id": "Calm", "min": 0, "max": 3, "label_zh": "平稳", "label_en": "Calm", "color": "#5A8FB8", "token_id": "ring_closed", "token_text": "○"},
				{"id": "Heated", "min": 4, "max": 7, "label_zh": "炽热", "label_en": "Heated", "color": "#C8A24B", "token_id": "furnace_section", "token_text": "△"},
				{"id": "Overdrive", "min": 8, "max": 10, "label_zh": "过载", "label_en": "Overdrive", "color": "#D8432A", "token_id": "warning_ring", "token_text": "!"}
			],
		},
		"charge": {
			"label_zh": "充能",
			"format": "{value}/{capacity}",
		},
		"layers": {
			"count": 5,
			"tokens": ["I", "II", "III", "IV", "V"],
			"names": ["点火", "稳压", "增压", "过热", "爆发"],
		},
		"release": {
			"labels": {
				"ready": "可释放",
				"insufficient_heat": "热量不足(需{threshold})",
				"insufficient_command_points": "指令不足",
				"not_player_turn": "未到玩家回合",
				"no_legal_source": "无可用棋子",
				"wrong_side": "非玩家侧",
				"release_busy": "释放中",
				"source_selection": "选择棋子",
				"target_selection": "选择目标",
				"unknown": "状态未知",
			},
		},
		"timing": {
			"normal_refresh_seconds": 0.6,
			"threshold_change_seconds": 1.2,
			"reduced_motion_enabled": false,
			"reduced_motion_seconds": 0.0,
		},
	}, true, errors)


func is_fallback() -> bool:
	return _used_fallback


func get_validation_errors() -> Array[String]:
	return _validation_errors.duplicate()


func to_snapshot() -> Dictionary:
	return _values.duplicate(true)


# ── Heat ──

func get_heat_max_segments() -> int:
	return int(_values.get("heat", {}).get("max_segments", 10))


## 依据表现区间映射把热量数值映射到区域 id（Calm/Heated/Overdrive）。
func get_heat_zone(heat: int) -> String:
	var zones: Array = _values.get("heat", {}).get("zones", [])
	for zone in zones:
		if not zone is Dictionary:
			continue
		var zmin := int(zone.get("min", -1))
		var zmax := int(zone.get("max", -2))
		if heat >= zmin and heat <= zmax:
			return str(zone.get("id", ""))
	return "Calm"


## 返回指定区域的三重标识调色板（颜色/纹章/文字）。
func get_zone_palette(zone_id: String) -> Dictionary:
	var zones: Array = _values.get("heat", {}).get("zones", [])
	for zone in zones:
		if zone is Dictionary and str(zone.get("id", "")) == zone_id:
			var palette: Dictionary = zone.duplicate(true)
			palette["color"] = _html_color(str(zone.get("color", "#5A8FB8")))
			return palette
	return {
		"id": zone_id,
		"min": 0,
		"max": 10,
		"label_zh": zone_id,
		"label_en": zone_id,
		"color": _html_color("#5A8FB8"),
		"token_id": "ring_closed",
		"token_text": "○",
	}


func get_zone_ids() -> Array[String]:
	var zones: Array = _values.get("heat", {}).get("zones", [])
	var ids: Array[String] = []
	for zone in zones:
		if zone is Dictionary:
			ids.append(str(zone.get("id", "")))
	return ids


# ── Charge ──

func get_charge_format() -> String:
	return str(_values.get("charge", {}).get("format", "{value}/{capacity}"))


func get_charge_label_zh() -> String:
	return str(_values.get("charge", {}).get("label_zh", "充能"))


# ── Layers ──

func get_layer_count() -> int:
	return int(_values.get("layers", {}).get("count", 5))


func get_layer_tokens() -> Array:
	var tokens: Array = _values.get("layers", {}).get("tokens", ["I", "II", "III", "IV", "V"])
	return tokens.duplicate()


func get_layer_names() -> Array:
	var names: Array = _values.get("layers", {}).get("names", ["点火", "稳压", "增压", "过热", "爆发"])
	return names.duplicate()


# ── Release ──

## 把权威释放状态代码映射为可读文字；code 支持 {threshold} 占位符替换。
## 阈值从 Overdrive 区间下限推导（表现提示，不参与合法性）。
func get_release_label(code: StringName) -> String:
	var labels: Dictionary = _values.get("release", {}).get("labels", {})
	var raw: String = str(labels.get(str(code), labels.get("unknown", "状态未知")))
	if raw.contains("{threshold}"):
		var threshold := 8
		var zones: Array = _values.get("heat", {}).get("zones", [])
		for zone in zones:
			if zone is Dictionary and str(zone.get("id", "")) == "Overdrive":
				threshold = int(zone.get("min", threshold))
				break
		raw = raw.replace("{threshold}", str(threshold))
	return raw


# ── Timing ──

func get_timing() -> Dictionary:
	return (_values.get("timing", {}) as Dictionary).duplicate(true)


func get_normal_refresh_seconds() -> float:
	return float(_values.get("timing", {}).get("normal_refresh_seconds", 0.6))


func get_threshold_change_seconds() -> float:
	return float(_values.get("timing", {}).get("threshold_change_seconds", 1.2))


func is_reduced_motion() -> bool:
	return bool(_values.get("timing", {}).get("reduced_motion_enabled", false))


func get_reduced_motion_seconds() -> float:
	return float(_values.get("timing", {}).get("reduced_motion_seconds", 0.0))


# ── 内部工具 ──

static func _html_color(hex: String) -> Color:
	var text := hex.strip_edges()
	if text.begins_with("#"):
		text = text.substr(1)
	if text.length() != 6:
		return Color(0.5, 0.56, 0.72, 1)
	var r := text.substr(0, 2).hex_to_int() / 255.0
	var g := text.substr(2, 2).hex_to_int() / 255.0
	var b := text.substr(4, 2).hex_to_int() / 255.0
	return Color(r, g, b, 1.0)
