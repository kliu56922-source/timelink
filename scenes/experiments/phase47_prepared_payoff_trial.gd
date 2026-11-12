extends "res://scenes/experiments/phase38_od_decision_trial.gd"
## Isolated payoff comparison: same early-knight deck and normal handlers.
@export_enum("original", "prepared_breach") var ritual_payoff_profile: String = "prepared_breach"

func _setup_game() -> void:
	super._setup_game()
	if not battle.configure_ritual_payoff_profile(StringName(ritual_payoff_profile)):
		push_error("Prepared payoff profile rejected before startup")

func restart_gb1_battle() -> void:
	if _gb1_restarting: return
	_gb1_restarting=true
	var path := "res://scenes/experiments/phase47_original_payoff_trial.tscn" if ritual_payoff_profile=="original" else "res://scenes/experiments/phase47_prepared_breach_trial.tscn"
	var err := get_tree().change_scene_to_file(path)
	if err!=OK:
		_gb1_restarting=false
		push_error("Prepared payoff restart failed: %d" % err)
