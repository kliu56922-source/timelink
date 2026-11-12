extends "res://core/awakening/awakening_base.gd"
class_name OverdriveAwakening

func _init() -> void:
	awakening_name = "Overdrive"

func get_od_cost(_card: CardData) -> int:
	return 0

func get_extra_repeat() -> int:
	return 1

func get_combo_grant() -> int:
	return 2
