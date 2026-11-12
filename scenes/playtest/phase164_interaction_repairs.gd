extends "res://scenes/playtest/phase163_weakpoint_pacing.gd"
## Presentation repair candidate. Rules and 163 portable package stay intact.
var ready164:=false
var coordinate_hints164: Control
func _ready() -> void:
	await super._ready()
	# Compact Boss information above the first rank, without hiding its intent.
	_boss_status_hud.custom_minimum_size=Vector2(440,84)
	_boss_status_hud.offset_top=48;_boss_status_hud.offset_bottom=132
	var hp: Control=_boss_status_hud.get_node("HPStack")
	hp.offset_top=27;hp.offset_bottom=44
	var meta: Control=_boss_status_hud.get_node("MetaRow")
	meta.offset_top=45;meta.offset_bottom=63
	var intent: Control=_boss_status_hud.get_node("IntentRow")
	intent.offset_top=63;intent.offset_bottom=82
	_boss_status_hud.remove_child(weakpoint_label);add_child(weakpoint_label)
	weakpoint_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	weakpoint_label.autowrap_mode=TextServer.AUTOWRAP_OFF
	weakpoint_label.clip_text=true
	weakpoint_label.position=Vector2(210,6);weakpoint_label.size=Vector2(500,40)
	weakpoint_label.z_index=220
	coordinate_hints164=Control.new();coordinate_hints164.name="CoordinateHints164"
	coordinate_hints164.mouse_filter=Control.MOUSE_FILTER_IGNORE;coordinate_hints164.z_index=150
	add_child(coordinate_hints164)
	for y in range(5):
		for x in range(5):
			var label:=Label.new();label.text="%d列%d行"%[x+1,y+1]
			label.mouse_filter=Control.MOUSE_FILTER_IGNORE
			label.add_theme_font_size_override("font_size",12)
			label.add_theme_color_override("font_color",Color.WHITE)
			label.add_theme_color_override("font_outline_color",Color.BLACK)
			label.add_theme_constant_override("outline_size",5)
			coordinate_hints164.add_child(label)
	get_node("IntegratedPlaytestTools").guide_window.dialog_text+="\n\n164操作修正：建筑确认使用1起始列行；烽堡需选择连接目标后确认。打击（B01）攻击敌方单位；赋刃仅本回合下一次普通攻击有效，不能预存到次回合。召唤前检查前场容量；有剩余指令结束回合需再点一次确认。"
	ready164=true
func _refresh_weakpoint162a() -> void:
	super._refresh_weakpoint162a()
	if is_instance_valid(weakpoint_label) and weakpoint_label.text.begins_with("163 "):
		weakpoint_label.text="164 "+weakpoint_label.text.substr(4)
func _process(delta: float) -> void:
	super._process(delta)
	if not ready164:return
	coordinate_hints164.visible=_coordinates_needed164() and not _exit_modal_active
	if coordinate_hints164.visible:
		for i in range(25):
			var label: Label=coordinate_hints164.get_child(i)
			var p:=_project_tactical_cell_to_screen(Vector2i(i%5,i/5))
			label.visible=p.is_finite()
			if label.visible:label.position=p+Vector2(-24,20)
func _coordinates_needed164() -> bool:
	return _is_piece_selection_active() or _is_lane_selection_active() or (_is_monster_summon_interaction_active() and _monster_summon_state()!=MONSTER_SUMMON_PENDING_CONFIRM)
func _open_monster_command_menu(card: CardData) -> void:
	super._open_monster_command_menu(card)
	if not ready164 or not is_instance_valid(_monster_command_menu):return
	var menu: Variant=_monster_command_menu
	var background: StyleBoxFlat=menu.get_theme_stylebox("panel").duplicate()
	background.bg_color.a=1.0
	menu.add_theme_stylebox_override("panel",background)
	var geometry: Dictionary=battle.get_core_attack_cell_status(card)
	var guard: CardData=battle._find_guard_interceptor(card,&"player") if str(geometry.get("reason",""))=="guard_intercepted" else null
	var guard_text:=""
	if guard!=null:
		var cell: Vector2i=battle.get_unit_cell(guard)
		guard_text="%s〔%d列%d行〕保护该列；可清守卫或改选其他合法列。"%[guard.get_display_name(),cell.x+1,cell.y+1]
	var info: Label=menu._focus_body.get_node_or_null("AttackHint160")
	if info!=null:
		info.text=info.text.replace("攻击核心：","攻击Boss本体：").replace("核心受守卫拦截。", "Boss本体与要害受守卫拦截。")
		if not guard_text.is_empty():info.text="攻击单位：%d指令\n攻击Boss本体：%d指令\n%s"%[battle.get_action_command_cost(card,"attack"),battle.get_action_command_cost(card,"attack_core"),guard_text]
	for p: Dictionary in battle.get_weakpoint_snapshots():
		var button: Button=menu._focus_body.get_node("AttackWeakpoint162B_"+str(p.id))
		var q: Dictionary=battle.get_weakpoint_attack_status(card,p.id)
		if not q.get("ok",false):
			var reason:="查看通路和行动限制"
			var code:=str(q.get("reason_code",""))
			if code=="no_legal_target" and not geometry.get("ok",false):code=str(geometry.get("reason",code))
			match code:
				"weakpoint_not_exposed":reason="锁定：先破坏两处外围"
				"weakpoint_already_broken":reason="已破坏"
				"weakpoint_wrong_column":reason="需到%d列"%(int(p.column)+1)
				"summoning_sickness":reason="刚登场，本回合不能攻击"
				"insufficient_command_points":reason="指令不足"
				"guard_intercepted":reason="守卫拦截"
				"not_breach_rank":reason="先到敌侧突破行"
				"front_arc_blocked":reason="前方敌棋阻挡"
				"facing_away_from_core":reason="当前朝向背离Boss"
				"attack_already_used", "already_attacked", "action_spent":reason="本回合已攻击"
			button.text+="\n"+reason
			if not guard_text.is_empty():button.tooltip_text+="\n"+guard_text
func axis155_navigate(nav: String) -> void:
	if not ready164:return
	if nav not in ["restart","home"]:super.axis155_navigate(nav);return
	if is_instance_valid(axis155) and axis155.running:_axis155_navigation=nav;axis155.stop("重开" if nav=="restart" else "返回");return
	if _gb1_restarting or not axis155_native_ready():return
	axis155.stop("navigation");_gb1_restarting=true
	if nav=="home":
		_cleanup_structure_presentation_lifecycle(&"return_to_menu");_cancel_monster_summon_interaction(&"return_to_menu")
	var err:=get_tree().change_scene_to_file("res://scenes/playtest/phase164_interaction_repairs.tscn" if nav=="restart" else "res://scenes/menu/demo_home.tscn")
	if err!=OK:_gb1_restarting=false;push_error("164 navigation failed")
