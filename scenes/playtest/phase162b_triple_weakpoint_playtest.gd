extends "res://scenes/playtest/phase162a_single_weakpoint_playtest.gd"
const BATTLE162B="res://scenes/playtest/phase162b_triple_weakpoint_playtest.tscn"
const HOME162B="res://scenes/menu/demo_home.tscn"
var ready162b:=false
func _create_battle_system() -> BattleSystem:
	return preload("res://core/battle/triple_weakpoint_battle_system.gd").new()
func _short_profile161() -> Dictionary:
	return preload("res://core/config/triple_weakpoint_profile.gd").values()
func _ready() -> void:
	await super._ready()
	weakpoint_label.name="Weakpoints162B"
	weakpoint_label.add_theme_font_size_override("font_size",14)
	weakpoint_label.offset_bottom=70
	get_node("IntegratedPlaytestTools").guide_window.dialog_text="162B 三要害灰盒：玩家30 / 熔炉守卫40\n外围任选顺序：承压护臂〔2列〕、供能阀门〔4列〕，耐久各2，击破各使本体损血10。两处外围均破坏，炉心约束环才暴露：耐久4，击破本体损血12，可从任一合法攻核列攻击。\n单位菜单选择目标，沿用攻核费用（通常3指令）和压力；须满足合法通路、无召唤病等限制。普通本体攻击始终可用。击破伤害不被盾、护甲或锁血截断，原阶段26/12、盾5/8仍结算。\n本轮无减伤/降OD奖励；未做十回合平衡验收。\n\n"+HINT160.od_help()
	ready162b=true
	_refresh_weakpoint162a()
func _refresh_weakpoint162a() -> void:
	if not is_instance_valid(weakpoint_label):return
	var parts: Array=battle.get_weakpoint_snapshots()
	var outer: Array[String]=[]
	for i in range(2):
		var p: Dictionary=parts[i]
		outer.append("%s〔%d列〕%s"%[p.name,int(p.column)+1,"已破坏" if p.broken else "%d/2 · 破坏−10"%p.integrity])
	var core: Dictionary=parts[2]
	weakpoint_label.text="162B "+" ｜ ".join(outer)+"\n炉心约束环："+("已破坏" if core.broken else "已暴露 %d/4 · 破坏−12 · 任一合法攻核列"%core.integrity if core.exposed else "锁定 · 先破坏两处外围要害")
func _open_monster_command_menu(card: CardData) -> void:
	if not ready162b:return
	super._open_monster_command_menu(card)
	if not is_instance_valid(_monster_command_menu):return
	var menu: Variant=_monster_command_menu
	var single: Node=menu._focus_body.get_node_or_null("AttackWeakpoint162A")
	if single!=null:menu._focus_body.remove_child(single);single.queue_free()
	for index in range(3):
		var p: Dictionary=battle.get_weakpoint_snapshots()[index]
		var q: Dictionary=battle.get_weakpoint_attack_status(card,p.id)
		var cost: int=battle.get_action_command_cost(card,"attack_core")
		var button:=Button.new();button.name="AttackWeakpoint162B_"+str(p.id)
		button.text="攻击%s · %d指令"%[p.name,cost]
		button.disabled=not q.get("ok",false) or not axis155_native_ready()
		var reason:=""
		match str(q.get("reason_code","")):
			"weakpoint_not_exposed":reason="需先破坏两处外围要害，核心才会暴露；暴露后不再关闭。"
			"weakpoint_wrong_column":reason="需要到%d列取得合法攻核通路。"%(int(p.column)+1)
			"weakpoint_already_broken":reason="此要害已破坏，本局不会重生或重复奖励。"
			"player_turn_closed":reason="等待Boss结算结束，回到己方行动窗口。"
			"battle_terminal":reason="本局已经结束。"
			_:
				if not q.get("ok",false):reason="需合法攻核通路、足够指令，且没有召唤病或其他行动限制。"
		button.tooltip_text="%s：耐久%d/%d，击破本体损血%d。仅基础攻击，费用与压力沿用攻核。\n%s"%[p.name,p.integrity,p.max_integrity,p.rupture_damage,reason]
		button.pressed.connect(_attack_weakpoint162b.bind(card,str(p.id)))
		menu._focus_body.add_child(button);menu._focus_body.move_child(button,3+index)
func _attack_weakpoint162b(card: CardData,id: String) -> Dictionary:
	if not ready162b or _gb1_restarting or battle_ended or not is_instance_valid(card) or not axis155_native_ready() or _is_piece_selection_active() or _is_monster_summon_interaction_active():return {"ok":false,"reason":"当前正在结算或等待其他选择"}
	var receipt: Dictionary=battle.execute_weakpoint_attack(card,id)
	_close_monster_command_menu()
	if not receipt.get("ok",false):
		_show_floating_text("当前无法攻击此要害：请检查通路、指令、召唤病及要害状态。",TC.WARNING,1.2,14);return receipt
	if action_feed:action_feed.push_message(receipt.message,TC.ACCENT_GOLD,"",2.5)
	if _playtest:_playtest.record_event("weakpoint_attack",{"target":id,"cost":receipt.cost,"integrity_loss":receipt.integrity_loss,"actual_hp_loss":receipt.actual_hp_loss,"broken":receipt.weakpoint_broken})
	_show_floating_text(receipt.message,TC.ACCENT_GOLD,1.8,18)
	_play_command_economy_spend(int(receipt.cost));_refresh_tables();_refresh_weakpoint162a();check_battle_end()
	return receipt
func axis155_navigate(nav: String) -> void:
	if not ready162b:return
	if nav not in ["restart","home"]:super.axis155_navigate(nav);return
	if is_instance_valid(axis155) and axis155.running:_axis155_navigation=nav;axis155.stop("重开" if nav=="restart" else "返回");return
	if _gb1_restarting or not axis155_native_ready():return
	axis155.stop("navigation");_gb1_restarting=true
	if nav=="home":
		_cleanup_structure_presentation_lifecycle(&"return_to_menu");_cancel_monster_summon_interaction(&"return_to_menu")
	var err:=get_tree().change_scene_to_file(BATTLE162B if nav=="restart" else HOME162B)
	if err!=OK:_gb1_restarting=false;push_error("162B navigation failed")
