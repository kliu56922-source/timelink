extends VBoxContainer
class_name ActionFeed

## ActionFeed — 顺序消息队列
## Phase 4B-1: 消息不再全部同时出现，改为 FIFO 队列，逐条展示。
## 同一时间最多显示 MAX_VISIBLE 条，超出时最旧消息淡出。
## 公开 API push_message() 签名完全兼容旧版。

const TC = preload("res://core/theme/theme_colors.gd")

# ── 队列参数 ──
const MAX_VISIBLE: int = 3
const DEQUEUE_INTERVAL_MIN: float = 0.35
const DEQUEUE_INTERVAL_MAX: float = 0.60
const MESSAGE_LIFETIME: float = 2.5
const FADE_IN_TIME: float = 0.15
const FADE_OUT_TIME: float = 0.25

# ── 状态 ──
var _message_queue: Array[Dictionary] = []
var _visible_labels: Array[Label] = []
var _dequeue_timer: Timer
var _rng: RandomNumberGenerator


func _ready() -> void:
	z_index = 30
	alignment = BoxContainer.ALIGNMENT_BEGIN
	add_theme_constant_override("separation", 2)
	_apply_bg()

	_rng = RandomNumberGenerator.new()
	_rng.randomize()

	_dequeue_timer = Timer.new()
	_dequeue_timer.one_shot = true
	_dequeue_timer.timeout.connect(_dequeue_next)
	add_child(_dequeue_timer)


func _apply_bg() -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.02, 0.06, 0.75)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_color = Color(TC.BORDER_DEFAULT.r, TC.BORDER_DEFAULT.g, TC.BORDER_DEFAULT.b, 0.3)
	style.set_corner_radius_all(4)
	add_theme_stylebox_override("panel", style)


## 公开 API — 与旧版签名完全兼容
## text: 消息文本
## color: 消息颜色
## _icon: 保留参数，当前未使用
## duration: 消息可见时长（秒），默认 MESSAGE_LIFETIME
func push_message(text: String, color: Color = TC.TEXT_PRIMARY, _icon: String = "", duration: float = MESSAGE_LIFETIME) -> void:
	_message_queue.append({
		"text": _sanitize_visible_text(text),
		"color": color,
		"duration": duration,
	})

	# 如果队列处理未启动，立刻取出第一条
	if not _dequeue_timer.is_stopped():
		return
	_dequeue_next()


## 从队列取出一条消息并展示
func _dequeue_next() -> void:
	if _message_queue.is_empty():
		return

	var data: Dictionary = _message_queue.pop_front()
	var text: String = data.get("text", "")
	var color: Color = data.get("color", TC.TEXT_PRIMARY)
	var duration: float = data.get("duration", MESSAGE_LIFETIME)

	_show_entry(text, color, duration)

	# 如果还有排队消息，随机间隔后继续
	if not _message_queue.is_empty():
		var interval: float = _rng.randf_range(DEQUEUE_INTERVAL_MIN, DEQUEUE_INTERVAL_MAX)
		_dequeue_timer.start(interval)


## 创建一条可见消息 Label
func _show_entry(text: String, color: Color, duration: float) -> void:
	# 超出上限时，最旧的消息快速淡出
	while _visible_labels.size() >= MAX_VISIBLE:
		var oldest: Label = _visible_labels.pop_back() as Label
		if is_instance_valid(oldest):
			var fade_tween: Tween = create_tween()
			fade_tween.tween_property(oldest, "modulate:a", 0.0, FADE_OUT_TIME)
			fade_tween.tween_callback(oldest.queue_free)

	# 新建 Label
	var label: Label = Label.new()
	label.text = _sanitize_visible_text(text)
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", color)
	label.modulate.a = 0.0
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	add_child(label)
	move_child(label, 0)  # 新消息在顶部
	_visible_labels.push_front(label)

	# 淡入 → 停留 → 淡出 → 移除
	var label_ref: WeakRef = weakref(label)
	var tween: Tween = create_tween()
	tween.tween_property(label, "modulate:a", 1.0, FADE_IN_TIME)
	tween.tween_interval(maxf(0.1, duration - FADE_IN_TIME - FADE_OUT_TIME))
	tween.tween_property(label, "modulate:a", 0.0, FADE_OUT_TIME)
	tween.tween_callback(_remove_entry.bind(label_ref))


func _sanitize_visible_text(text: String) -> String:
	var clean := str(text).strip_edges()
	if clean.is_empty():
		return ""
	for marker in ["�", "鈥", "閸", "鍗", "缁", "鐨", "瀵", "濡", "澧", "宸", "閫", "绁", "镭"]:
		if clean.find(marker) >= 0:
			return "事件更新"
	return clean


## 移除一条已淡出的消息
func _remove_entry(label_ref: WeakRef) -> void:
	var label: Label = label_ref.get_ref() as Label
	if label == null:
		return
	_visible_labels.erase(label)
	if is_instance_valid(label):
		label.queue_free()


## 清空队列和所有可见消息
func clear() -> void:
	_message_queue.clear()
	if _dequeue_timer:
		_dequeue_timer.stop()

	var old_labels: Array[Label] = _visible_labels.duplicate()
	_visible_labels.clear()
	for entry: Label in old_labels:
		if is_instance_valid(entry):
			entry.queue_free()
