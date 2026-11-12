extends RefCounted
class_name TableLayoutConfig

## TableLayoutConfig — 从 JSON 读取牌桌/卡牌位置配置
## Phase 5C: 统一布局配置文件

const JSON_PATH := "res://data/config/card_table_layout.json"

var _data: Dictionary = {}

## 默认值（JSON 加载失败时使用）
const DEFAULTS := {
	"resolution": {"w": 1600, "h": 900},
	"hand_card_size": {"w": 152, "h": 192},
	"field_card_size": {"w": 108, "h": 76},
	"detail_card_size": {"w": 180, "h": 240},
	"feed_card_size": {"w": 100, "h": 64},
	"front_slot_size": {"w": 112, "h": 86},
	"back_slot_size": {"w": 112, "h": 72},
	"slot_gap": 14,
	"hand_fan_angle": 4.0,
	"hand_spacing_min": 72.0,
	"hand_spacing_preferred": 130.0,
}


func _init() -> void:
	_reload()


func _reload() -> void:
	if not FileAccess.file_exists(JSON_PATH):
		push_warning("[TableLayoutConfig] JSON not found — using defaults.")
		_data = DEFAULTS.duplicate(true)
		return

	var file := FileAccess.open(JSON_PATH, FileAccess.READ)
	if file == null:
		_data = DEFAULTS.duplicate(true)
		return

	var text := file.get_as_text()
	file.close()

	var json := JSON.new()
	if json.parse(text) != OK:
		push_warning("[TableLayoutConfig] JSON parse error — using defaults.")
		_data = DEFAULTS.duplicate(true)
		return

	var parsed: Variant = json.get_data()
	if parsed is Dictionary:
		_data = parsed
		print("[TableLayoutConfig] Loaded layout from %s" % JSON_PATH)
	else:
		_data = DEFAULTS.duplicate(true)


## 热重载（开发期使用）
func hot_reload() -> void:
	print("[TableLayoutConfig] Hot reload...")
	_reload()
	print("[TableLayoutConfig] Reload done.")


## 获取矩形配置（返回 Dictionary {x, y, w, h} 或 {w, h}）
func get_rect(key: String) -> Dictionary:
	var v: Variant = _data.get(key, DEFAULTS.get(key, {}))
	if v is Dictionary:
		return v
	return {}


func get_vector2(key: String) -> Vector2:
	var d := get_rect(key)
	return Vector2(d.get("w", 100), d.get("h", 80))


func get_size(key: String) -> Vector2:
	return get_vector2(key)


## 手牌区全局矩形
func get_hand_area_rect() -> Rect2:
	var d := get_rect("hand_area")
	return Rect2(d.get("x", 200), d.get("y", 680), d.get("w", 1200), d.get("h", 210))


## 手牌卡片尺寸
func get_hand_card_size() -> Vector2:
	return get_vector2("hand_card_size")


## 场上卡片尺寸
func get_field_card_size() -> Vector2:
	return get_vector2("field_card_size")


## 详情卡片尺寸
func get_detail_card_size() -> Vector2:
	return get_vector2("detail_card_size")


func get_feed_card_size() -> Vector2:
	return get_vector2("feed_card_size")


## 前场槽位尺寸
func get_front_slot_size() -> Vector2:
	return get_vector2("front_slot_size")


## 后场槽位尺寸
func get_back_slot_size() -> Vector2:
	return get_vector2("back_slot_size")


## 槽间距
func get_slot_gap() -> int:
	return _data.get("slot_gap", DEFAULTS["slot_gap"])


## 手牌扇形角度
func get_hand_fan_angle() -> float:
	return _data.get("hand_fan_angle", DEFAULTS["hand_fan_angle"])


func get_hand_spacing_min() -> float:
	return _data.get("hand_spacing_min", DEFAULTS["hand_spacing_min"])


func get_hand_spacing_preferred() -> float:
	return _data.get("hand_spacing_preferred", DEFAULTS["hand_spacing_preferred"])


## 获取详情面板尺寸
func get_detail_panel_size(expanded: bool = false) -> Vector2:
	var d := get_rect("detail_panel")
	if expanded:
		return Vector2(d.get("expanded_w", 260), d.get("expanded_h", 460))
	return Vector2(d.get("w", 220), d.get("h", 360))


# ============================================================
# Phase 5C-6: Rect 位置应用方法
# ============================================================

## 从配置读取命名区域的 Rect2
## key: JSON 中的区域键名 (如 "hand_area", "right_track")
## fallback: 默认 Rect2
func get_rect2(key: String, fallback: Rect2 = Rect2(0, 0, 200, 100)) -> Rect2:
	var d := get_rect(key)
	if d.is_empty():
		return fallback
	var x: int = d.get("x", fallback.position.x)
	var y: int = d.get("y", fallback.position.y)
	var w: int = d.get("w", fallback.size.x)
	var h: int = d.get("h", fallback.size.y)
	return Rect2(x, y, w, h)


## 将配置中的命名区域应用到 Control 节点
## 设置节点的 position 和 size（如果是顶层节点则用 offset）
func apply_rect_to_control(ctrl: Control, key: String, fallback: Rect2 = Rect2(0, 0, 200, 100)) -> void:
	if ctrl == null or not is_instance_valid(ctrl):
		return
	var r := get_rect2(key, fallback)
	ctrl.position = r.position
	ctrl.size = r.size
	ctrl.custom_minimum_size = r.size


## 获取手牌区 Rect2
func get_hand_area() -> Rect2:
	return get_rect2("hand_area", Rect2(200, 680, 1200, 210))


## 获取详情面板 Rect2 (compact)
func get_detail_panel_compact_rect() -> Rect2:
	var d := get_rect("detail_panel")
	var r := get_rect2("detail_panel", Rect2(20, 140, 220, 360))
	# Override with compact-specific w/h if present
	if d.has("w"):
		r.size.x = d.get("w", 220)
	if d.has("h"):
		r.size.y = d.get("h", 360)
	return r


## 获取详情面板 Rect2 (expanded)
func get_detail_panel_expanded_rect() -> Rect2:
	var d := get_rect("detail_panel")
	var r := get_rect2("detail_panel", Rect2(20, 140, 260, 460))
	if d.has("expanded_w"):
		r.size.x = d.get("expanded_w", 260)
	if d.has("expanded_h"):
		r.size.y = d.get("expanded_h", 460)
	return r


## 获取右侧轨道 Rect2
func get_right_track_rect() -> Rect2:
	return get_rect2("right_track", Rect2(1380, 40, 200, 820))


## 获取核心状态面板 Rect2
func get_core_status_rect() -> Rect2:
	return get_rect2("core_status_panel", Rect2(10, 10, 200, 120))


## 获取玩家前场行 Rect2
func get_player_front_row_rect() -> Rect2:
	return get_rect2("player_front_row", Rect2(350, 700, 860, 116))


## 获取玩家后场行 Rect2
func get_player_back_row_rect() -> Rect2:
	return get_rect2("player_back_row", Rect2(350, 870, 860, 86))


## 获取 Boss 前场行 Rect2
func get_boss_front_row_rect() -> Rect2:
	return get_rect2("boss_front_row", Rect2(350, -30, 860, 95))


## 获取 Boss 后场行 Rect2
func get_boss_back_row_rect() -> Rect2:
	return get_rect2("boss_back_row", Rect2(350, -150, 860, 72))


## 获取战斗桌面 Rect2
func get_battle_table_rect() -> Rect2:
	return get_rect2("battle_table", Rect2(0, 0, 1600, 900))
