extends "res://scenes/experiments/phase35_early_knight_trial.gd"
const PHASE38_ENTRY := "res://scenes/experiments/phase38_od_decision_trial.tscn"
func _ready() -> void:
	await super._ready()
	if is_instance_valid(_relation_coach_panel):
		_relation_coach_panel.advisor = preload("res://battle/analysis/od_cooling_relation_advisor.gd").new()
		_relation_coach_panel.refresh()
func restart_gb1_battle() -> void:
	if _gb1_restarting: return
	_gb1_restarting = true
	if battle != null and battle.reaction_trial != null: battle.reaction_trial.finish_event()
	var error := get_tree().change_scene_to_file(PHASE38_ENTRY)
	if error != OK:
		_gb1_restarting = false
		push_error("OD relation trial restart failed: %d" % error)
