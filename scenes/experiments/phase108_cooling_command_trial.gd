extends "res://scenes/experiments/phase105_timing_facility_trial.gd"

func restart_gb1_battle() -> void:
	if _gb1_restarting or _facility_running:return
	_gb1_restarting=true
	var err:=get_tree().change_scene_to_file("res://scenes/experiments/phase108_cooling_command_trial.tscn")
	if err!=OK:_gb1_restarting=false;push_error("Cooling command restart failed: %d"%err)
