extends "res://scenes/experiments/phase51_charged_cannon_trial.gd"
@export_enum("original","first-full-refund") var thermal_refund_profile := "original"
func _setup_game() -> void:
	super._setup_game()
	if not battle.configure_thermal_refund_trial(thermal_refund_profile):push_error("Thermal refund profile rejected before startup")
func restart_gb1_battle() -> void:
	if _gb1_restarting:return
	_gb1_restarting=true
	var path := "res://scenes/experiments/phase52_original_refund_trial.tscn" if thermal_refund_profile=="original" else "res://scenes/experiments/phase52_first_refund_trial.tscn"
	var err := get_tree().change_scene_to_file(path)
	if err!=OK:_gb1_restarting=false;push_error("Thermal refund restart failed: %d" % err)
