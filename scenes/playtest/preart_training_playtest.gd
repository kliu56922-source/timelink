extends "res://scenes/playtest/preart_integrated_playtest.gd"
## Public encounter difficulty. All differences are fixed before the first turn.
const DemoProfile=preload("res://core/config/demo_playtest_profile.gd")
const TRAINING_PATH="res://scenes/playtest/preart_training_playtest.tscn"
func _get_battle_encounter() -> Dictionary:
	var encounter: Dictionary=super._get_battle_encounter()
	encounter=DemoProfile.practice_encounter(encounter)
	return encounter
func _setup_game() -> void:
	super._setup_game()
	# Still within initialization: no turns, damage, payments or rewards have run.
	context.player.hp=DemoProfile.PLAYER_HP
func _ready() -> void:
	await super._ready()
	if not _gb1_startup_ok:return
	var tools: Variant=get_node("IntegratedPlaytestTools")
	tools.toggle.text="练习 · 战术工具 ▾"
	tools.guide_window.dialog_text="练习难度：玩家80生命 / Boss55生命。
阶段切换：Boss36 / 16生命；原阶段护盾5 / 8保留。
标准挑战仍为玩家35 / Boss85生命；这是不同难度，不代表标准平衡通过。

"+tools.guide_window.dialog_text
func restart_gb1_battle() -> void:
	if _gb1_restarting or not integrated_navigation_ready():return
	_gb1_restarting=true
	var err:=get_tree().change_scene_to_file(TRAINING_PATH)
	if err!=OK:_gb1_restarting=false;push_error("Training restart failed: %d"%err)
