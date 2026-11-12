extends "res://scenes/experiments/phase52_thermal_refund_trial.gd"
@export_enum("original","first-barrier") var ascension_barrier_profile := "original"
var protection_core_receipts: Array[Dictionary]=[]
var barrier_event_records: Array[Dictionary]=[]
func _setup_game() -> void:
	super._setup_game()
	if not battle.configure_ascension_barrier_trial(ascension_barrier_profile):push_error("Ascension barrier profile rejected before startup")
	battle.seal_ascension_barrier_configuration()
	battle.ascension_barrier_resolved.connect(_record_barrier_event)
func _record_barrier_event(receipt: Dictionary) -> void:
	var target: CardData=battle.get_unit_at_cell(battle.get_unit_cell(_barrier_target(receipt.target_runtime_id)))
	var source: CardData
	for card: CardData in context.player.graveyard:
		if card.get_instance_id()==receipt.source_runtime_id:source=card;break
	barrier_event_records.append({"index":barrier_event_records.size(),"receipt":receipt.duplicate(true),"native_resolution_locked":battle._siege_command_in_progress,"economy":battle.get_command_economy_snapshot("player"),"core":battle.get_core_command_state(),"hp":context.player.hp,"shield":context.player.shield,"boss_hp":context.enemy.hp,"source_player_grave_count":context.player.graveyard.count(source),"source_mirror_grave_count":battle.graveyard_system.player_graveyard.count(source),"target_state":battle.get_unit_combat_state(target).duplicate(true)})
func _barrier_target(runtime_id: int) -> CardData:
	for card: CardData in context.player.field:
		if card.get_instance_id()==runtime_id:return card
	return null
func _handle_core_command_result(result: Dictionary) -> void:
	protection_core_receipts.append(result.duplicate(true))
	super._handle_core_command_result(result)
func restart_gb1_battle() -> void:
	if _gb1_restarting:return
	_gb1_restarting=true
	var path := "res://scenes/experiments/phase61_first_barrier_trial.tscn" if ascension_barrier_profile=="first-barrier" else "res://scenes/experiments/phase61_original_barrier_trial.tscn"
	var err := get_tree().change_scene_to_file(path)
	if err!=OK:_gb1_restarting=false;push_error("Ascension barrier restart failed: %d" % err)
