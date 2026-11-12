extends Label

var _tween: Tween

func setup(value: int, crit := false) -> void:
	text = str(value)

	if crit:
		add_theme_color_override("font_color", Color(1, 0.15, 0.05, 1))
		add_theme_font_size_override("font_size", 30)
		scale = Vector2(1.3, 1.3)
	else:
		add_theme_color_override("font_color", Color(1, 0.9, 0.3, 1))
		add_theme_font_size_override("font_size", 22)

	position.y = -20
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(self, "position:y", position.y - 45, 0.65)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "modulate:a", 0.0, 0.55).set_delay(0.1)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_tween.chain().tween_callback(queue_free)
