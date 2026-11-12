extends "res://scenes/playtest/phase161_short_match_playtest.gd"
const BATTLE162A="res://scenes/playtest/phase162a_single_weakpoint_playtest.tscn"
const HOME162A="res://scenes/menu/demo_home.tscn"
var ready162a:=false
var weakpoint_label: Label
func _create_battle_system() -> BattleSystem:
	return preload("res://core/battle/boss_weakpoint_battle_system.gd").new()
func _short_profile161() -> Dictionary:
	return preload("res://core/config/single_weakpoint_profile.gd").values()
func _ready() -> void:
	await super._ready()
	weakpoint_label=Label.new();weakpoint_label.name="Weakpoint162A"
	weakpoint_label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	weakpoint_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	weakpoint_label.add_theme_font_size_override("font_size",16)
	weakpoint_label.add_theme_color_override("font_color",Color(1.0,0.85,0.35))
	var background:=StyleBoxFlat.new();background.bg_color=Color(0.025,0.025,0.035,0.96)
	background.content_margin_left=8;background.content_margin_right=8;background.content_margin_top=3;background.content_margin_bottom=3
	weakpoint_label.add_theme_stylebox_override("normal",background)
	_boss_status_hud.add_child(weakpoint_label)
	weakpoint_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	weakpoint_label.offset_top=6;weakpoint_label.offset_bottom=64
	_refresh_weakpoint162a()
	var tools: Variant=get_node("IntegratedPlaytestTools")
	tools.guide_window.dialog_text="162A 单要害灰盒：玩家30 / 熔炉守卫40\n承压护臂在2列，耐久2；从单位菜单选择攻击要害，沿用攻核报价（通常3指令）。仍需合法突破通路，不能绕过守卫与召唤病。\n击破本体真实损血10；阶段26/12和原盾5/8仍结算，崩坏不被锁血截断。普通攻核继续可用。仅基础攻击；本阶段不含减伤/降OD或三要害，不是十回合平衡验收。\n\n"+HINT160.od_help()
	ready162a=true
func _refresh_weakpoint162a() -> void:
	if not is_instance_valid(weakpoint_label):return
	var weak: Dictionary=battle.get_weakpoint_snapshot()
	weakpoint_label.text="162A 承压护臂〔2列〕 %d/2 · %s\n单位菜单选择要害；须有该列合法攻核通路"%[weak.integrity,"已破坏，本体攻击仍可用" if weak.broken else "击破：本体 −10"]
func _open_monster_command_menu(card: CardData) -> void:
	super._open_monster_command_menu(card)
	if not ready162a or not is_instance_valid(_monster_command_menu):return
	var menu: Variant=_monster_command_menu
	var q: Dictionary=battle.get_weakpoint_attack_status(card,"pressure_arm")
	var cost: int=battle.get_action_command_cost(card,"attack_core")
	var button:=Button.new();button.name="AttackWeakpoint162A"
	button.text="攻击要害 · %d指令"%cost
	button.disabled=not q.get("ok",false) or not axis155_native_ready()
	var reason:=""
	match str(q.get("reason_code","")):
		"weakpoint_wrong_column":reason="需要到2列取得合法攻核通路，当前列不能攻击此要害。"
		"weakpoint_already_broken":reason="要害已破坏，本局不会重生；可继续普通本体攻击。"
		"player_turn_closed":reason="等待Boss结算结束，回到己方行动窗口。"
		"battle_terminal":reason="本局已经结束。"
		_:
			if not q.get("ok",false):reason="请查看上方攻核说明：需合法通路、足够指令，且没有召唤病或其他行动限制。"
	button.tooltip_text="承压护臂〔2列〕，耐久2，击破本体 −10。仅基础攻击；报价与压力沿用攻核。\n"+reason
	button.pressed.connect(_attack_weakpoint162a.bind(card))
	menu._focus_body.add_child(button);menu._focus_body.move_child(button,3)
func _attack_weakpoint162a(card: CardData) -> Dictionary:
	if not ready162a or _gb1_restarting or battle_ended or not is_instance_valid(card) or not axis155_native_ready() or _is_piece_selection_active() or _is_monster_summon_interaction_active():return {"ok":false,"reason":"当前正在结算或等待其他选择"}
	var receipt: Dictionary=battle.execute_weakpoint_attack(card,"pressure_arm")
	_close_monster_command_menu()
	if not receipt.get("ok",false):
		_show_floating_text("当前无法攻击要害：请检查2列通路、指令、召唤病或要害是否已破坏。",TC.WARNING,1.2,14);return receipt
	if action_feed:action_feed.push_message(receipt.message,TC.ACCENT_GOLD,"",2.5)
	if _playtest:_playtest.record_event("weakpoint_attack",{"cost":receipt.cost,"integrity_loss":receipt.integrity_loss,"actual_hp_loss":receipt.actual_hp_loss,"broken":receipt.weakpoint_broken})
	_show_floating_text(receipt.message,TC.ACCENT_GOLD,1.8,18)
	_play_command_economy_spend(int(receipt.cost));_refresh_tables();_refresh_weakpoint162a();check_battle_end()
	return receipt
func axis155_navigate(nav: String) -> void:
	if not ready162a:return
	if nav not in ["restart","home"]:super.axis155_navigate(nav);return
	if is_instance_valid(axis155) and axis155.running:_axis155_navigation=nav;axis155.stop("重开" if nav=="restart" else "返回");return
	if _gb1_restarting or not axis155_native_ready():return
	axis155.stop("navigation");_gb1_restarting=true
	if nav=="home":
		_cleanup_structure_presentation_lifecycle(&"return_to_menu");_cancel_monster_summon_interaction(&"return_to_menu")
	var err:=get_tree().change_scene_to_file(BATTLE162A if nav=="restart" else HOME162A)
	if err!=OK:_gb1_restarting=false;push_error("162A navigation failed")
