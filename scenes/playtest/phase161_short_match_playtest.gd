extends "res://scenes/playtest/phase160_clear_hints_playtest.gd"
const SHORT161=preload("res://core/config/short_match_profile.gd")
const BATTLE161="res://scenes/playtest/phase161_short_match_playtest.tscn"
const HOME161="res://scenes/menu/demo_home.tscn"
func _short_profile161() -> Dictionary:return SHORT161.values()
func _get_battle_encounter() -> Dictionary:
	var result: Dictionary=super._get_battle_encounter();var short: Dictionary=_short_profile161()
	result.boss_start_hp=short.boss_hp;result.phase_locks=short.phase_locks.duplicate(true);return result
func _setup_game() -> void:
	super._setup_game()
	# Initialization only, before any turn, damage, payment, reward or draw.
	context.player.hp=int(_short_profile161().player_hp)
func _ready() -> void:
	await super._ready()
	var tools: Variant=get_node("IntegratedPlaytestTools");var short: Dictionary=_short_profile161()
	tools.guide_window.dialog_text=tools.guide_window.dialog_text.replace("玩家80 / 熔炉守卫40","玩家%d / 熔炉守卫%d"%[short.player_hp,short.boss_hp])
	var text: String=tools.guide_window.dialog_text
	var start:=text.find("工程融合练习：")
	if start>=0:
		var end:=text.find("\n\n",start)
		if end>=0:text=text.left(start)+text.substr(end+2)
	tools.guide_window.dialog_text=text
func axis155_navigate(nav: String) -> void:
	if not ready160:return
	if nav not in ["restart","home"]:super.axis155_navigate(nav);return
	if is_instance_valid(axis155) and axis155.running:_axis155_navigation=nav;axis155.stop("重开" if nav=="restart" else "返回");return
	if _gb1_restarting or not axis155_native_ready():return
	axis155.stop("navigation");_gb1_restarting=true
	if nav=="home":
		_cleanup_structure_presentation_lifecycle(&"return_to_menu");_cancel_monster_summon_interaction(&"return_to_menu")
	var err:=get_tree().change_scene_to_file(BATTLE161 if nav=="restart" else HOME161)
	if err!=OK:_gb1_restarting=false;push_error("161 navigation failed")
