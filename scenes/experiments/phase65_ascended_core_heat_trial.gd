extends "res://scenes/experiments/phase63_core_damage_heat_trial.gd"
@export_enum("original","ascended-core-heat") var hero_heat_profile := "ascended-core-heat"
func _setup_game() -> void:
	core_damage_heat_profile=hero_heat_profile
	super._setup_game()
func restart_gb1_battle() -> void:
	if _gb1_restarting:return
	_gb1_restarting=true
	var path := "res://scenes/experiments/phase65_original_core_heat_trial.tscn" if hero_heat_profile=="original" else "res://scenes/experiments/phase65_ascended_core_heat_trial.tscn"
	var err := get_tree().change_scene_to_file(path)
	if err!=OK:_gb1_restarting=false;push_error("Hero core heat restart failed: %d"%err)
