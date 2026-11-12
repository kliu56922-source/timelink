extends Control

## Presentation/input bridge for native CardUI drops over the 3D board.
## BattleScene supplies both Callables and remains the interaction coordinator;
## this Control owns no card, cell, cost, or summon rules.

var _can_drop_handler: Callable
var _drop_handler: Callable
var _drag_active := false
var _can_drop_calls := 0
var _drop_calls := 0
var _last_local_position := Vector2.INF
var _last_screen_position := Vector2.INF
var _last_can_drop := false
var _drag_intent: StringName = &""


func _ready() -> void:
	set_drag_active(false)


func configure(can_drop_handler: Callable, drop_handler: Callable) -> void:
	_can_drop_handler = can_drop_handler
	_drop_handler = drop_handler


func set_drag_active(active: bool) -> void:
	set_board_drag_active(active, &"monster_summon" if active else &"")


func set_board_drag_active(active: bool, intent: StringName = &"") -> void:
	if active:
		_can_drop_calls = 0
		_drop_calls = 0
		_last_local_position = Vector2.INF
		_last_screen_position = Vector2.INF
		_last_can_drop = false
	_drag_active = active
	_drag_intent = intent if active else &""
	visible = active
	mouse_filter = Control.MOUSE_FILTER_STOP if active else Control.MOUSE_FILTER_IGNORE


func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	_can_drop_calls += 1
	_last_local_position = at_position
	_last_screen_position = get_global_transform() * at_position
	_last_can_drop = _drag_active and _can_drop_handler.is_valid() \
		and bool(_can_drop_handler.call(_last_screen_position, data))
	return _last_can_drop


func _drop_data(at_position: Vector2, data: Variant) -> void:
	_drop_calls += 1
	_last_local_position = at_position
	_last_screen_position = get_global_transform() * at_position
	if _drag_active and _drop_handler.is_valid():
		_drop_handler.call(_last_screen_position, data)


func get_debug_snapshot() -> Dictionary:
	return {
		"active": _drag_active,
		"visible": visible,
		"mouse_filter": mouse_filter,
		"can_drop_calls": _can_drop_calls,
		"drop_calls": _drop_calls,
		"last_local_position": _last_local_position,
		"last_screen_position": _last_screen_position,
		"last_can_drop": _last_can_drop,
		"intent": _drag_intent,
	}
