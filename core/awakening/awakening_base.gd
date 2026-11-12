extends RefCounted
class_name AwakeningBase

var awakening_name: String = "Base"

func get_od_cost(_card: CardData) -> int:
	return _card.od_cost

func get_extra_repeat() -> int:
	return 0

func get_combo_grant() -> int:
	return 0
