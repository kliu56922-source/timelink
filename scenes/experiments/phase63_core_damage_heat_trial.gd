extends "res://scenes/experiments/phase62_od_readiness_trial.gd"
@export_enum("original","first-core-heat") var core_damage_heat_profile := "original"
func _setup_game() -> void:
	super._setup_game()
	if not battle.configure_core_damage_heat_trial(core_damage_heat_profile):push_error("Core damage heat profile rejected at startup");return
	battle.seal_core_damage_heat_trial_configuration()
func restart_gb1_battle() -> void:
	if _gb1_restarting:return
	_gb1_restarting=true
	var path := "res://scenes/experiments/phase63_first_core_heat_trial.tscn" if core_damage_heat_profile=="first-core-heat" else "res://scenes/experiments/phase63_original_core_heat_trial.tscn"
	var err := get_tree().change_scene_to_file(path)
	if err!=OK:_gb1_restarting=false;push_error("Core damage heat restart failed: %d"%err)

func _on_end_turn() -> void:
	if battle!=null and battle._core_damage_heat_resolving:return
	await super._on_end_turn()
func _on_monster_command(action: String,card: CardData) -> void:
	if battle!=null and battle._core_damage_heat_resolving:return
	super._on_monster_command(action,card)
