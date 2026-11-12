extends "res://scenes/playtest/phase162b_triple_weakpoint_playtest.gd"
const BATTLE163="res://scenes/playtest/phase163_weakpoint_pacing.tscn"
const HOME163="res://scenes/menu/demo_home.tscn"
var ready163:=false
func _create_battle_system() -> BattleSystem:
	return preload("res://core/battle/pacing_weakpoint_battle_system.gd").new()
func _short_profile161() -> Dictionary:
	return preload("res://core/config/weakpoint_pacing_profile.gd").values()
func _ready() -> void:
	await super._ready()
	var tools: Variant=get_node("IntegratedPlaytestTools")
	tools.guide_window.dialog_text=tools.guide_window.dialog_text.replace("162B 三要害灰盒","163 三要害节奏校准").replace("未做十回合平衡验收。","十回合是试玩目标，仍以实际路线为准。")+"\n\n163：本场双方守卫只拦所在列，邻列可突破；同列仍需清障。通常移动1、攻击单位2、攻击要害3指令。已到位主力可保留站位，不必重复OD换位。外围间用原生移动换列，核心暴露后无需再换列。"
	ready163=true
	tools.guide_window.dialog_text+="\n前两层基础指令提高到5（之后5/6/7），支持两步换位+一次要害攻击；原费用、压力阈值与回合清空规则不变。"
	tools.guide_window.dialog_text=tools.guide_window.dialog_text.replace("盾5/8","盾3/4")+"\n阶段赠盾调整为3/4，第三阶段OD入场照常；30/40血量与10/10/12击破伤害不变。"
	tools.guide_window.dialog_text+="\n核心击破额外清除当前本体护盾（包含本次阶段赠盾）；只触发一次，Boss后续补盾正常。"
	tools.guide_window.dialog_text+="\n守卫须留在自己的防区才能拦截同列：Boss侧1/2行，玩家侧4/5行。冲出防区的守卫仍可作战，但不再保护远处核心。"
func _refresh_weakpoint162a() -> void:
	super._refresh_weakpoint162a()
	if is_instance_valid(weakpoint_label):weakpoint_label.text=weakpoint_label.text.replace("162B ","163 ")
func axis155_navigate(nav: String) -> void:
	if not ready163:return
	if nav not in ["restart","home"]:super.axis155_navigate(nav);return
	if is_instance_valid(axis155) and axis155.running:_axis155_navigation=nav;axis155.stop("重开" if nav=="restart" else "返回");return
	if _gb1_restarting or not axis155_native_ready():return
	axis155.stop("navigation");_gb1_restarting=true
	if nav=="home":
		_cleanup_structure_presentation_lifecycle(&"return_to_menu");_cancel_monster_summon_interaction(&"return_to_menu")
	var err:=get_tree().change_scene_to_file(BATTLE163 if nav=="restart" else HOME163)
	if err!=OK:_gb1_restarting=false;push_error("163 navigation failed")
