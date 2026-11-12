extends "res://scenes/experiments/phase61_ascension_barrier_trial.gd"
const Phase62Validator := preload("res://core/config/config_validator.gd")
const Phase62ODRules := preload("res://core/config/od_release_rule_snapshot.gd")
@export_enum("original","ready-seven") var od_readiness_profile := "original"
func _setup_game() -> void:
	super._setup_game()
	if od_readiness_profile not in ["original","ready-seven"]:push_error("Invalid readiness profile before startup");return
	var raw: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://data/config/od_release_rules.json"))
	if not raw is Dictionary:push_error("Original readiness rule table unavailable");return
	var rules: Dictionary=raw.duplicate(true)
	rules.ritual_readiness_threshold=8
	if od_readiness_profile=="ready-seven":rules.readiness_threshold=7
	var errors: Array[String]=Phase62Validator.validate_od_release_rules_table(rules)
	if not errors.is_empty():push_error("Readiness rule table rejected: %s" % str(errors));return
	battle.configure_od_release_rules(Phase62ODRules.new(rules,false,[]))
	_refresh_od_release_control()
func restart_gb1_battle() -> void:
	if _gb1_restarting:return
	_gb1_restarting=true
	var path := "res://scenes/experiments/phase62_ready_seven_trial.tscn" if od_readiness_profile=="ready-seven" else "res://scenes/experiments/phase62_original_readiness_trial.tscn"
	var err := get_tree().change_scene_to_file(path)
	if err!=OK:_gb1_restarting=false;push_error("Readiness restart failed: %d" % err)
