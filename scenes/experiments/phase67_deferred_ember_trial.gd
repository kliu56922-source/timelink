extends "res://scenes/experiments/phase65_ascended_core_heat_trial.gd"
@export_enum("original","ascended-delayed-core-heat") var ember_profile := "ascended-delayed-core-heat"
func _setup_game() -> void:
	hero_heat_profile=ember_profile
	super._setup_game()
func _start_player_turn_rules(initial: bool=false) -> void:
	if battle!=null and battle._core_damage_heat_resolving:return
	super._start_player_turn_rules(initial)
	if not initial and battle!=null:battle.resolve_pending_core_damage_heat()
func restart_gb1_battle() -> void:
	if _gb1_restarting:return
	_gb1_restarting=true
	var path := "res://scenes/experiments/phase67_original_ember_trial.tscn" if ember_profile=="original" else "res://scenes/experiments/phase67_deferred_ember_trial.tscn"
	var err := get_tree().change_scene_to_file(path)
	if err!=OK:_gb1_restarting=false;push_error("Deferred core heat restart failed: %d"%err)
