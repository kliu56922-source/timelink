extends Control
## Optional reference route. Reads a live provider on open; never grants progress.
var provider: Callable
var _button: Button
var _dialog: AcceptDialog
var _text: Label
func _ready() -> void:
	position = Vector2(18,730)
	size = Vector2(280,30)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_button = Button.new()
	_button.text = "建堡展开 · 查看参考路线"
	_button.size = size
	_button.tooltip_text = "查看起手、中转、初步终场和当前缺少的条件；可自由穿插其他牌。"
	add_child(_button)
	_dialog = AcceptDialog.new()
	_dialog.title = "建堡展开 · 参考路线"
	_dialog.min_size = Vector2i(670,500)
	_dialog.ok_button_text = "继续对局"
	add_child(_dialog)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(640,430)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_dialog.add_child(scroll)
	_text = Label.new()
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(620,0)
	_text.add_theme_font_size_override("font_size",17)
	scroll.add_child(_text)
	_button.pressed.connect(show_route)

func show_route() -> void:
	if not provider.is_valid(): return
	var view: Dictionary = provider.call()
	_text.text = str(view.get("text",""))
	_dialog.popup_centered()
