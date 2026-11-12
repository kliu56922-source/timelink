extends RefCounted
class_name TacticalCellState

var cell: Vector2i
var height: int
var surface: StringName
var revision: int


func _init(
	board_cell: Vector2i,
	initial_height: int = 0,
	initial_surface: StringName = &"flat",
	initial_revision: int = 0
) -> void:
	cell = board_cell
	height = initial_height
	surface = initial_surface
	revision = initial_revision


func snapshot() -> Dictionary:
	return {
		"cell": cell,
		"height": height,
		"surface": surface,
		"revision": revision,
	}


func copy_with(next_height: int, next_surface: StringName) -> RefCounted:
	return get_script().new(cell, next_height, next_surface, revision + 1)
