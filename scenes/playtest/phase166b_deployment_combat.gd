extends "res://scenes/playtest/phase166a_key_recipe.gd"
var ready166b:=false
var phase_label166b: Label
func _create_battle_system() -> BattleSystem:return preload("res://core/battle/deployment_combat_battle_system.gd").new()
func _start_player_turn_rules(initial: bool=false) -> void:
	battle.opening166b.begin_player_turn()
	if is_instance_valid(_end_turn_control):_end_turn_control.set_preparation_mode(battle.preparation_active166b())
	super._start_player_turn_rules(initial)
	if ready166b:_update_phase166b()
func _ready() -> void:
	await super._ready()
	phase_label166b=Label.new();phase_label166b.position=Vector2(210,52);phase_label166b.size=Vector2(310,44)
	phase_label166b.add_theme_font_size_override("font_size",14);phase_label166b.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(phase_label166b)
	context.enemy.intent_text="蓄压护盾：热+2 / 盾+2 · 首轮不攻击"
	context.enemy.intent_danger="LOW";context.enemy.notify_intent_changed()
	var guide: Variant=get_node("IntegratedPlaytestTools").guide_window
	guide.dialog_text=guide.dialog_text.replace("新首回合部署限制尚未实施。","")+"\n166B：首回合部署，只能使用已审核的部署/防护/控压牌；移动、攻击、技能和OD待交战开启。点部署完成一次进入首Boss准备轮，余点不结转；Boss原热+2/盾+2，不攻击。第二己方回合恢复原生指令、抽牌和召唤病规则。准备回合计入总时长。"
	ready166b=true;_update_phase166b()
func _process(delta: float) -> void:
	super._process(delta)
	if ready166b:_update_phase166b()
func _update_phase166b() -> void:
	var state: Dictionary=battle.opening166b.snapshot()
	phase_label166b.text="166B · 部署回合\n展开 / 建造 / 控压" if state.phase=="deployment" else "166B · Boss蓄压准备" if state.phase=="boss_preparation" else "166B · 交战\n第%d个己方回合（含部署）"%state.player_round
	_end_turn_control.set_preparation_mode(battle.preparation_active166b())
func _refresh_weakpoint162a() -> void:
	super._refresh_weakpoint162a()
	if is_instance_valid(weakpoint_label):weakpoint_label.text=weakpoint_label.text.replace("166A ","166B ")
func axis155_navigate(nav: String) -> void:
	if not ready166b:return
	if recipe166.running:_recipe_nav166=nav;recipe166.skip();return
	if advance165.running:_advance_nav165=nav;advance165.stop("导航");return
	if axis155.running:_axis155_navigation=nav;axis155.stop("导航");return
	if nav not in ["restart","home"] or _gb1_restarting or not axis155_native_ready():return
	recipe_panel166.dismiss();advance_panel165.dismiss();advance165.stop("navigation");axis155.stop("navigation");_gb1_restarting=true
	if nav=="home":_cleanup_structure_presentation_lifecycle(&"return_to_menu");_cancel_monster_summon_interaction(&"return_to_menu")
	var target: String="res://scenes/playtest/phase166b_deployment_combat.tscn" if nav=="restart" else "res://scenes/menu/demo_home.tscn"
	var error:=get_tree().change_scene_to_file(target)
	if error!=OK:_gb1_restarting=false;push_error("166B navigation failed")
