extends "res://scenes/experiments/gb3o_engineering_package.gd"
## Thin run adapter. Parent remains the one startup and combat authority.
signal encounter_started(token: String, fact: Dictionary)
signal encounter_completed(token: String, result: Dictionary)
signal startup_failed(token: String, reason: String)
signal run_startup_finished
const RunConfig = preload("res://core/run/run_foundation_config.gd")
const BossLibrary = preload("res://core/deck/boss_card_library.gd")
var _run_contract: Dictionary={}
var _run_completed := false
var run_startup_pending := true
var run_input_enabled := false
var run_host: WeakRef
func configure_run(contract: Dictionary) -> Dictionary:
 if is_inside_tree():return {"ok":false,"reason_code":&"already_in_tree"}
 var errors: Array[String]=RunConfig.validate_contract(contract,BossLibrary.get_supported_card_ids())
 if not errors.is_empty():return {"ok":false,"reason_code":&"invalid_contract","errors":errors}
 _run_contract=contract.duplicate(true)
 return {"ok":true}
func _get_battle_encounter() -> Dictionary:
 return _run_contract.encounter.duplicate(true)
func _get_gb1_boss_seed() -> int:
 return int(_run_contract.boss_seed)
func _gb1_prepare_startup() -> void:
 super._gb1_prepare_startup()
 if not _gb1_startup_ok:return
 if _run_contract.is_empty():
  _gb1_startup_ok=false;_gb1_load_problems.append("远征合同未配置");return
 _gb1_selected_cards.clear()
 for id: String in _run_contract.deck_order:
  if not _gb1_cards_by_id.has(id):
   _gb1_startup_ok=false;_gb1_load_problems.append("远征牌缺失："+id);return
  _gb1_selected_cards.append(_gb1_cards_by_id[id])
func _setup_game() -> void:
 super._setup_game()
 context.player.hp=int(_run_contract.player_hp)
 context.enemy.player_name=str(_run_contract.display_name)
 if not _run_contract.inherit_boss_deck:
  boss_deck.configure_deck(_run_contract.boss_deck)
func _ready() -> void:
 set_process_input(false)
 await super._ready()
 run_startup_pending=false
 run_startup_finished.emit()
 if not is_inside_tree():return
 if not _gb1_startup_ok:
  startup_failed.emit(str(_run_contract.get("token","")),"；".join(_gb1_load_problems));return
 _live_coach_panel.set_mode(&"related")
 var opening: Array[String]=[]
 for card: CardData in context.player.hand:opening.append(str(card.card_id))
 encounter_started.emit(_run_contract.token,{"boss_seed":boss_deck.get_rng_seed(),"opening":opening,"player_hp":context.player.hp,"boss_hp":context.enemy.hp,"deck_order":_run_contract.deck_order.duplicate(),"run_seed":_run_contract.run_seed,"deck_seed":_run_contract.deck_seed})
func set_run_input(value: bool) -> void:
 run_input_enabled=value
 set_process_input(value)
func prepare_run_release() -> void:
 # Retire without recording a win/loss or emitting another result.
 set_run_input(false)
 _run_completed=true
 battle_ended=true
 if _battle_presentation_director!=null and is_instance_valid(_battle_presentation_director):
  _battle_presentation_director.cancel_all(&"run_release")
 if battle!=null and battle.reaction_trial!=null:battle.reaction_trial.finish_event()
func _input(event: InputEvent) -> void:
 if not run_input_enabled:return
 super._input(event)
func _end_battle(victory: bool) -> void:
 if _run_completed or battle_ended:return
 _run_completed=true
 super._end_battle(victory)
 set_run_input(false)
 encounter_completed.emit(_run_contract.token,{"victory":victory,"raw_hp":context.player.hp,"turns":context.turn_count,"boss_seed":boss_deck.get_rng_seed()})
func restart_gb1_battle() -> void:
 _on_retry()
func _on_retry() -> void:
 var host=run_host.get_ref() if run_host!=null else null
 if is_instance_valid(host):host.retry_run(true)
func _on_return_to_menu() -> void:
 var host=run_host.get_ref() if run_host!=null else null
 if is_instance_valid(host):host.return_to_menu()
