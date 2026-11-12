extends "res://battle/analysis/advance_weakpoint_runner.gd"
const Clarity=preload("res://battle/analysis/operation_clarity_167a.gd")
func availability(actor: CardData) -> Dictionary:
	var s: Variant=scene()
	if s!=null and Clarity.body_mode(s):return Clarity.body_status(s,actor)
	return super.availability(actor)
