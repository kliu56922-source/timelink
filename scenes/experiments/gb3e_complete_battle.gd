extends "res://scenes/experiments/gb2b_integrated_battle.gd"
## Complete-route candidate. Reuses all GB2B authorities, ownership and fail-closed startup.
const COMPLETE_ENTRY := "res://scenes/experiments/gb3e_complete_battle.tscn"
const COMPLETE_ORDER: Array[String] = [
	"P01", "P02", "P05", "P07", "P08", "P23",
	"P06", "P18", "P22", "P03", "P09", "P10",
	"P11", "P14", "P04", "P13", "P17", "P20",
]

func _gb1_fixed_order_problems(by_id: Dictionary) -> Array[String]:
	var problems: Array[String] = super._gb1_fixed_order_problems(by_id)
	var seen := {}
	for id in COMPLETE_ORDER:
		if not by_id.has(id): problems.append("complete route card missing: " + id)
		if seen.has(id): problems.append("duplicate complete route card: " + id)
		seen[id] = true
	return problems

func _gb1_prepare_startup() -> void:
	super._gb1_prepare_startup()
	if not _gb1_startup_ok: return
	_gb1_selected_cards.clear()
	for id in COMPLETE_ORDER:
		_gb1_selected_cards.append(_gb1_cards_by_id[id])

func restart_gb1_battle() -> void:
	if _gb1_restarting: return
	_gb1_restarting = true
	if is_instance_valid(_gb1_restart_button): _gb1_restart_button.disabled = true
	var error := get_tree().change_scene_to_file(COMPLETE_ENTRY)
	if error != OK:
		_gb1_restarting = false
		if is_instance_valid(_gb1_restart_button): _gb1_restart_button.disabled = false
		push_error("Complete battle restart failed: %d" % error)
