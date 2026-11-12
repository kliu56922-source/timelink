extends "res://scenes/playtest/phase158_spatial_axis_playtest.gd"
const VICTORY159="res://scenes/playtest/phase159_victory_practice.tscn"
const PROFILE159=preload("res://core/config/victory_practice_profile.gd")
func _get_battle_encounter() -> Dictionary:
	return PROFILE159.practice_encounter(super._get_battle_encounter())
func _ready() -> void:
	await super._ready()
	var tools: Variant=get_node("IntegratedPlaytestTools")
	(axis155_panel.text.get_parent().get_child(0) as Label).text="战术小轴 · 格表随镜头排列，格号不变\n选齐看预览，仍由你确认行动"
	tools.toggle.text="练习159 · 战术工具 ▾"
	tools.guide_window.dialog_text="159较短练习：玩家80 / Boss40；阶段26 / 12，原护盾5 / 8。\n先出蓄火和燃芯使魔，给普通OD留出来源与指令；不要先用学徒＋导体占满两单位位。\n原158的55HP和153包保留。\n\n"+tools.guide_window.dialog_text.replace("Boss55","Boss40")
func axis155_navigate(nav: String) -> void:
	if nav!="restart":super.axis155_navigate(nav);return
	if is_instance_valid(axis155) and axis155.running:_axis155_navigation=nav;axis155.stop("重开");return
	if _gb1_restarting or not axis155_native_ready():return
	axis155.stop("navigation");_gb1_restarting=true
	var err:=get_tree().change_scene_to_file(VICTORY159)
	if err!=OK:_gb1_restarting=false;push_error("159 restart failed")
