extends "res://scenes/experiments/phase47_prepared_payoff_trial.gd"
## Observation only: original authoritative handler and presentation remain in charge.
var phase51_skill_records: Array[Dictionary]=[]
var phase51_skill_finished := 0
func _setup_game() -> void:
	super._setup_game()
	battle.init_monster_hero_skills(GameConfig.create_monster_hero_skill_snapshot())
func _present_committed_skill(facts: Dictionary) -> void:
	var receipt := facts.duplicate(true)
	var actor: CardData=facts.card
	receipt["actor_id"]=actor.card_id;receipt["actor_runtime_id"]=actor.get_instance_id()
	receipt["boss_core_target"]=facts.target==null
	for key in ["card","target","target_position","destroyed_units"]:receipt.erase(key)
	phase51_skill_records.append(receipt)
	await super._present_committed_skill(facts)
	phase51_skill_finished+=1
func restart_gb1_battle() -> void:
	if _gb1_restarting:return
	_gb1_restarting=true
	var err := get_tree().change_scene_to_file("res://scenes/experiments/phase51_charged_cannon_trial.tscn")
	if err!=OK:_gb1_restarting=false;push_error("Charged cannon restart failed: %d" % err)
