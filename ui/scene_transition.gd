extends Control
class_name SceneTransition

## SceneTransition — 统一转场组件
## 使用方式：
##   1. 调用 play_exit(title, subtitle, Callable) → 淡入黑幕 → 回调（切场景）
##   2. 新场景调用 play_enter() → 黑幕淡出 → queue_free

signal exit_complete

@onready var black_fade: ColorRect = $BlackFade
@onready var title_label: Label = $VBox/TitleLabel
@onready var subtitle_label: Label = $VBox/SubtitleLabel


# ============================================================
# 退出动画：当前场景 → 黑幕 → 回调
# ============================================================
func play_exit(title_text: String, subtitle_text: String, on_complete: Callable) -> void:
	if not is_instance_valid(black_fade) or not is_instance_valid(title_label):
		if on_complete.is_valid():
			on_complete.call()
		return
	title_label.text = title_text
	subtitle_label.text = subtitle_text

	# 初始状态
	black_fade.modulate.a = 0.0
	title_label.modulate.a = 0.0
	subtitle_label.modulate.a = 0.0

	# 黑幕淡入
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(black_fade, "modulate:a", 1.0, 0.35)
	# 文字稍后显现
	t.tween_property(title_label, "modulate:a", 1.0, 0.25).set_delay(0.15)
	t.tween_property(subtitle_label, "modulate:a", 1.0, 0.25).set_delay(0.2)

	# 短暂停留 → 回调
	var t2 := create_tween()
	t2.tween_interval(0.4)
	t2.tween_callback(func():
		exit_complete.emit()
		if on_complete.is_valid():
			on_complete.call()
	)


# ============================================================
# 进入动画：黑幕 → 透明 → 自毁
# ============================================================
func play_enter(on_complete: Callable = Callable()) -> void:
	# 初始：全黑
	black_fade.modulate.a = 1.0
	title_label.modulate.a = 0.0
	subtitle_label.modulate.a = 0.0

	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(black_fade, "modulate:a", 0.0, 0.5)
	t.tween_property(title_label, "modulate:a", 0.0, 0.3)

	if on_complete.is_valid():
		var t2 := create_tween()
		t2.tween_interval(0.55)
		t2.tween_callback(on_complete)

	# 延迟自毁
	var t3 := create_tween()
	t3.tween_interval(0.6)
	t3.tween_callback(queue_free)


# ============================================================
# 便捷：跳过所有动画，立即黑屏然后回调
# ============================================================
func instant_black(on_complete: Callable) -> void:
	black_fade.modulate.a = 1.0
	title_label.text = ""
	subtitle_label.text = ""
	if on_complete.is_valid():
		on_complete.call()
