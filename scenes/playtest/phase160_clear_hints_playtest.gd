extends "res://scenes/playtest/phase159_victory_practice.gd"
const HINT160=preload("res://ui/practice_action_hints.gd")
const BATTLE160="res://scenes/playtest/phase160_clear_hints_playtest.tscn"
const HOME160="res://scenes/menu/demo_home.tscn"
var ready160:=false
func _ready() -> void:
	await super._ready()
	var tools: Variant=get_node("IntegratedPlaytestTools")
	tools.toggle.text="战术工具 ▾"
	var inherited: String=tools.guide_window.dialog_text
	inherited=inherited.substr(inherited.find("\n\n")+2)
	tools.guide_window.dialog_text="玩家80 / 熔炉守卫40\n"+HINT160.od_help()+"\n\n攻击单位与攻击核心费用分别显示；以目标预览和真实回执为准。\n核心被守卫拦截时，先清敌或检查再部署；再部署需充能，不能绕过召唤病。\n\n"+inherited
	_refresh_od_release_control()
	ready160=true
func _open_monster_command_menu(card: CardData) -> void:
	super._open_monster_command_menu(card)
	if not is_instance_valid(_monster_command_menu) or battle==null:return
	var menu: Variant=_monster_command_menu
	var unit: Dictionary=battle.get_unit_command_status(card,"attack")
	var core: Dictionary=battle.get_unit_command_status(card,"attack_core")
	# Native status may return before assigning cost for summoning sickness.
	unit.cost=battle.get_action_command_cost(card,"attack")
	core.cost=battle.get_action_command_cost(card,"attack_core")
	var hint: Dictionary=HINT160.attack_hint(unit,core,battle.get_core_attack_cell_status(card))
	for i in range(menu._buttons.size()):
		if menu._button_action(i)=="attack":
			menu._buttons[i].text="攻击"
			menu._buttons[i].tooltip_text=hint.detail
	var info:=Label.new();info.name="AttackHint160";info.text=hint.detail
	info.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;info.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	info.mouse_filter=Control.MOUSE_FILTER_IGNORE;info.add_theme_font_size_override("font_size",12)
	menu._focus_body.add_child(info);menu._focus_body.move_child(info,2)
func _refresh_od_release_control() -> void:
	super._refresh_od_release_control()
	if not is_instance_valid(_od_release_control):return
	var control: Variant=_od_release_control
	if not str(control._snapshot.get("selection_stage","")).is_empty():return
	control._button.text="普通OD"
	control._button.tooltip_text=HINT160.od_help()
	var used: bool=control._snapshot.get("used",false)
	var prepared: bool=control._snapshot.get("attack_ready",false) or control._snapshot.get("guard_ready",false)
	control._final_button.text="仪式已用" if used else "仪式领奖" if prepared else "应急·一次"
	control._final_button.tooltip_text=HINT160.od_help()+"\n"+control._final_button.tooltip_text
func axis155_navigate(nav: String) -> void:
	if not ready160:return
	if nav not in ["restart","home"]:super.axis155_navigate(nav);return
	if is_instance_valid(axis155) and axis155.running:_axis155_navigation=nav;axis155.stop("重开" if nav=="restart" else "返回");return
	if _gb1_restarting or not axis155_native_ready():return
	axis155.stop("navigation");_gb1_restarting=true
	if nav=="home":
		_cleanup_structure_presentation_lifecycle(&"return_to_menu")
		_cancel_monster_summon_interaction(&"return_to_menu")
	var err:=get_tree().change_scene_to_file(BATTLE160 if nav=="restart" else HOME160)
	if err!=OK:_gb1_restarting=false;push_error("160 navigation failed")
func _on_return_to_menu() -> void:
	axis155_navigate("home")
