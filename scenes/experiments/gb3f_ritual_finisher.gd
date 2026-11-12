extends "res://scenes/experiments/gb3e_complete_battle.gd"
## Isolated ritual-finisher comparison. GB3E remains the unchanged baseline.
const RITUAL_ENTRY := "res://scenes/experiments/gb3f_ritual_finisher.tscn"
const RITUAL_ORDER: Array[String] = [
	"P01", "P02", "P05", "P07", "P08", "P23",
	"P06", "P22", "P03", "P09", "P10", "P11",
	"P14", "P04", "P13", "P17",
]

func _gb1_fixed_order_problems(by_id: Dictionary) -> Array[String]:
	var problems: Array[String] = super._gb1_fixed_order_problems(by_id)
	var seen := {}
	for card_id in RITUAL_ORDER:
		if not by_id.has(card_id): problems.append("ritual card missing: " + card_id)
		if seen.has(card_id): problems.append("duplicate ritual card: " + card_id)
		seen[card_id] = true
	return problems

func _gb1_prepare_startup() -> void:
	super._gb1_prepare_startup()
	if not _gb1_startup_ok:
		return
	_gb1_selected_cards.clear()
	for card_id in RITUAL_ORDER:
		_gb1_selected_cards.append(_gb1_cards_by_id[card_id])

func _setup_game() -> void:
	super._setup_game()
	battle.configure_ritual_finisher_trial(true)

func restart_gb1_battle() -> void:
	if _gb1_restarting:
		return
	_gb1_restarting = true
	if is_instance_valid(_gb1_restart_button):
		_gb1_restart_button.disabled = true
	var err := get_tree().change_scene_to_file(RITUAL_ENTRY)
	if err != OK:
		_gb1_restarting = false
		if is_instance_valid(_gb1_restart_button):
			_gb1_restart_button.disabled = false
		push_error("Ritual trial restart failed: %d" % err)
