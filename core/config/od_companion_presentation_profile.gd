extends RefCounted
class_name ODCompanionPresentationProfile

## Phase 26D: OD 伙伴表现不可变配置快照
## 由 GameConfig.create_od_companion_presentation_profile() 构造，创建后只读。
##
## 一场战斗只创建一次，Presenter 不直接读取 JSON。
## 所有视觉参数来自 od_companion_presentation.json，不含业务规则。

# ── 站点顺序 ──
var _station_order: Array[StringName] = []

# ── 站点缩放 ──
var _station_scale: Dictionary = {}

# ── 碰撞体积 ──
var _hitbox_size: Vector3 = Vector3(1.0, 0.45, 1.0)

# ── 标签高度偏移 ──
var _label_height: float = 0.32

# ── 安全边距 (px) ──
var _safe_margin_px: int = 12

# ── 动画时长 ──
var _pulse_seconds: float = 0.65
var _evolution_seconds: float = 1.0

# ── Depth 抖动幅度 ──
var _depth_jitter_amplitude: float = 0.03

# ── Layer 颜色 (L1–L5) ──
var _layer_colors: Array[Color] = []

# ── Phase 26D-R1: 视觉偏移 ──
var _station_visual_offset: Dictionary = {}
var _floating_labels_visible: bool = false
var _surface_plaque_rotation_degrees_x: float = -90.0
var _deck_stack_layers: int = 4

# ── 元数据 ──
var _used_fallback: bool = false
var _validation_errors: Array[String] = []


# ═══════════════════════════════════════════════════════════════
# 构造函数
# ═══════════════════════════════════════════════════════════════

func _init(table: Dictionary = {}, is_fallback: bool = false, errors: Array[String] = []) -> void:
	_used_fallback = is_fallback
	_validation_errors = errors.duplicate()

	if table.is_empty():
		_apply_defaults()
		return

	# station_order
	var raw_order: Array = table.get("station_order", [])
	for entry in raw_order:
		_station_order.append(StringName(str(entry)))
	if _station_order.is_empty():
		_station_order.clear()
		_station_order.append_array([&"player_graveyard", &"od_companion", &"player_deck"])

	# station_scale
	var raw_scale: Dictionary = table.get("station_scale", {})
	for key in raw_scale:
		var val = raw_scale[key]
		if val is float or val is int:
			_station_scale[StringName(str(key))] = clampf(float(val), 0.25, 2.0)

	# hitbox_size
	var hb: Dictionary = table.get("hitbox_size", {})
	_hitbox_size = Vector3(
		clampf(float(hb.get("x", 1.0)), 0.1, 4.0),
		clampf(float(hb.get("y", 0.45)), 0.1, 4.0),
		clampf(float(hb.get("z", 1.0)), 0.1, 4.0)
	)

	# label_height
	_label_height = clampf(float(table.get("label_height", 0.32)), 0.05, 2.0)

	# safe_margin_px
	var raw_margin = table.get("safe_margin_px", 12)
	if raw_margin is int:
		_safe_margin_px = clampi(raw_margin, 0, 64)
	elif raw_margin is float:
		_safe_margin_px = clampi(int(raw_margin), 0, 64)

	# pulse / evolution seconds
	_pulse_seconds = clampf(float(table.get("pulse_seconds", 0.65)), 0.05, 3.0)
	_evolution_seconds = clampf(float(table.get("evolution_seconds", 1.0)), 0.05, 3.0)

	# depth_jitter_amplitude
	_depth_jitter_amplitude = clampf(float(table.get("depth_jitter_amplitude", 0.03)), 0.0, 0.2)

	# layer_colors
	var raw_colors: Array = table.get("layer_colors", [])
	for entry in raw_colors:
		var color_str: String = str(entry)
		if color_str.begins_with("#"):
			_layer_colors.append(Color(color_str))

	# R1: station_visual_offset
	var raw_offsets: Dictionary = table.get("station_visual_offset", {})
	_station_visual_offset.clear()
	for key in raw_offsets:
		var vo: Dictionary = raw_offsets[key]
		var offset_vec := Vector3(
			clampf(float(vo.get("x", 0.0)), -8.0, 8.0),
			clampf(float(vo.get("y", 0.0)), -0.25, 0.50),
			clampf(float(vo.get("z", 0.0)), -8.0, 8.0)
		)
		_station_visual_offset[StringName(str(key))] = offset_vec

	# R1: floating_labels_visible
	var raw_flv = table.get("floating_labels_visible", null)
	_floating_labels_visible = raw_flv if raw_flv is bool else false

	# R1: surface_plaque_rotation_degrees_x
	var raw_spr = table.get("surface_plaque_rotation_degrees_x", null)
	if raw_spr is float or raw_spr is int:
		_surface_plaque_rotation_degrees_x = clampf(float(raw_spr), -180.0, 180.0)

	# R1: deck_stack_layers
	var raw_dsl = table.get("deck_stack_layers", null)
	if raw_dsl is int:
		_deck_stack_layers = clampi(raw_dsl, 1, 8)
	elif raw_dsl is float:
		_deck_stack_layers = clampi(int(raw_dsl), 1, 8)


# ═══════════════════════════════════════════════════════════════
# 公开 Getter
# ═══════════════════════════════════════════════════════════════

func get_station_order() -> Array[StringName]:
	return _station_order.duplicate()


func get_station_scale(station_id: StringName) -> float:
	return float(_station_scale.get(station_id, 1.0))


func get_hitbox_size() -> Vector3:
	return _hitbox_size


func get_label_height() -> float:
	return _label_height


func get_safe_margin_px() -> int:
	return _safe_margin_px


func get_pulse_seconds() -> float:
	return _pulse_seconds


func get_evolution_seconds() -> float:
	return _evolution_seconds


func get_depth_jitter_amplitude() -> float:
	return _depth_jitter_amplitude


func get_layer_color(layer: int) -> Color:
	var idx := clampi(layer - 1, 0, _layer_colors.size() - 1)
	if _layer_colors.is_empty():
		return Color.WHITE
	return _layer_colors[idx]


# ── Phase 26D-R1 Getters ──

func get_station_visual_offset(station_id: StringName) -> Vector3:
	if _station_visual_offset.has(station_id):
		return _station_visual_offset[station_id] as Vector3
	return Vector3.ZERO


func are_floating_labels_visible() -> bool:
	return _floating_labels_visible


func get_surface_plaque_rotation_degrees_x() -> float:
	return _surface_plaque_rotation_degrees_x


func get_deck_stack_layers() -> int:
	return _deck_stack_layers


func is_fallback() -> bool:
	return _used_fallback


func get_validation_errors() -> Array[String]:
	return _validation_errors.duplicate()


# ═══════════════════════════════════════════════════════════════
# 内部方法
# ═══════════════════════════════════════════════════════════════

func _apply_defaults() -> void:
	_station_order.clear()
	_station_order.append_array([&"player_graveyard", &"od_companion", &"player_deck"])
	_station_scale = {
		&"player_graveyard": 0.78,
		&"od_companion": 1.0,
		&"player_deck": 0.78
	}
	_hitbox_size = Vector3(1.0, 0.45, 1.0)
	_label_height = 0.32
	_safe_margin_px = 12
	_pulse_seconds = 0.65
	_evolution_seconds = 1.0
	_depth_jitter_amplitude = 0.03
	_layer_colors = [
		Color("#41D17A"),
		Color("#2FD0D0"),
		Color("#4C96E8"),
		Color("#9B59C6"),
		Color("#FF4D24"),
	]
	# R1 defaults
	_station_visual_offset.clear()
	_station_visual_offset[&"player_graveyard"] = Vector3(-2.98, 0.02, -2.36)
	_station_visual_offset[&"od_companion"] = Vector3(-2.49, 0.02, -0.15)
	_station_visual_offset[&"player_deck"] = Vector3(-1.71, 0.02, -0.77)
	_floating_labels_visible = false
	_surface_plaque_rotation_degrees_x = -90.0
	_deck_stack_layers = 4
