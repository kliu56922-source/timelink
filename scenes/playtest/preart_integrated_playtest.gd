extends "res://scenes/experiments/phase105_timing_facility_trial.gd"
## Player-operated integrated entry; keeps native rule ownership and legacy entries.
const ENTRY_PATH="res://scenes/playtest/preart_integrated_playtest.tscn"
var _focused_layout: Node
var _integrated_return: Button

func _setup_game() -> void:
	super._setup_game()
	# Replace the still-empty construction service before the first player turn.
	if battle.hand_structure_build_committed.is_connected(engineering._record_hand_build):
		battle.hand_structure_build_committed.disconnect(engineering._record_hand_build)
	engineering=preload("res://core/battle/scaled_facility_footprint_trial.gd").new(battle,prepared_blueprints)
	engineering.begin_player_turn()
	fortification=Fortification.new(battle,engineering);fortification.begin_player_turn()
	timing_advisor=TimingAdvisor.new(self,engineering)

func _build_engineering_controls() -> void:
	super._build_engineering_controls()
	for child in _engineering_text.get_parent().get_children():
		if child is Label and child.text.begins_with("空间试验："):
			child.text="冷却设施：1×1耐久2 / 1×2耐久3 / 2×2耐久4。原能力/费用；围护1×1。"
			child.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART


func _ready() -> void:
	await super._ready()
	if not _gb1_startup_ok:return
	_integrated_return=Button.new();_integrated_return.name="IntegratedReturnMenu"
	_integrated_return.text="返回主菜单"
	_integrated_return.tooltip_text="当前动作处理完成后可返回。"
	get_node("GB1HelpLayer/GB1HelpPanel/Body").add_child(_integrated_return)
	_integrated_return.pressed.connect(return_to_integrated_menu)
	var tools: Variant=preload("res://ui/integrated_playtest_tools.gd").new()
	add_child(tools);tools.setup(self)
	_focused_layout=preload("res://ui/focused_battle_layout.gd").new()
	add_child(_focused_layout);_focused_layout.setup(self)
	get_tree().process_frame.connect(_update_integrated_navigation)
	_update_integrated_navigation()

func integrated_navigation_ready() -> bool:
	if _card_being_played or _facility_running or _presentation_end_turn_blocked or _spell_end_turn_blocked or battle==null:return false
	if is_instance_valid(spell_activation_presenter) and spell_activation_presenter.is_active():return false
	if is_instance_valid(_battle_presentation_director) and _battle_presentation_director.is_busy():return false
	for key: String in ["_od_release_resolving","_siege_command_in_progress","_core_command_resolving","_core_damage_heat_resolving"]:
		if bool(battle.get(key)):return false
	return battle_ended or bool(battle.get_command_economy_snapshot("player").get("turn_open",false))

func _update_integrated_navigation() -> void:
	var blocked:=not integrated_navigation_ready()
	if is_instance_valid(_integrated_return):_integrated_return.disabled=blocked
	if is_instance_valid(_gb1_restart_button):_gb1_restart_button.disabled=blocked or _gb1_restarting
	if is_instance_valid(result_panel):
		if is_instance_valid(result_panel.retry_button):result_panel.retry_button.disabled=blocked or _gb1_restarting
		if is_instance_valid(result_panel.return_button):result_panel.return_button.disabled=blocked or _return_to_menu_guard

func restart_gb1_battle() -> void:
	if _gb1_restarting or not integrated_navigation_ready():return
	_gb1_restarting=true
	var err:=get_tree().change_scene_to_file(ENTRY_PATH)
	if err!=OK:_gb1_restarting=false;push_error("Integrated playtest restart failed: %d"%err)

func return_to_integrated_menu() -> void:
	if not integrated_navigation_ready():return
	_on_return_to_menu()

func _on_return_to_menu() -> void:
	if not integrated_navigation_ready():return
	super._on_return_to_menu()

func _sync_gb1_help_panel() -> void:
	if is_instance_valid(_gb1_help_panel):_gb1_help_panel.hide()

func _preview_engineering(rush: bool) -> void:
	super._preview_engineering(rush)
	if not _engineering_quote.get("ok",false):return
	var cells: Array=_engineering_quote.get("layout",{}).get("_structure_plan",{}).get("structure",{}).get("footprint_cells",[_engineering_quote.cell])
	_engineering_confirm.dialog_text+="\n占地：%d格；本体耐久上限%d。付款后固定，不会免费挪动。"%[cells.size(),int(_engineering_quote.layout._structure_plan.structure.integrity_max)]
	for cell: Vector2i in cells:
		if cell.y>=4:
			_engineering_confirm.dialog_text+="\n后排占位可能阻挡己方退守，请考虑完整占地。";break

func _draw_frontline() -> void:
	# Keep original board highlights; fixed side text lives in the tools drawer.
	if battle==null or context==null:return
	var font:=ThemeDB.fallback_font
	if not _frontline_build_preview.is_empty():
		for cell: Vector2i in _frontline_build_preview.get("core",{}).get("footprint_cells",[]):
			var point: Vector2=_project_tactical_cell_to_screen(cell)
			if point.is_finite():_frontline_overlay.draw_rect(Rect2(point-Vector2(48,25),Vector2(96,50)),Color(1,0.85,0.25),false,3)
	for structure: Dictionary in battle.get_structure_snapshot().get("structures",{}).values():
		var cells: Array=structure.get("footprint_cells",[])
		if cells.size()!=2:continue
		var core: Vector2=_project_tactical_cell_to_screen(cells[0]);var platform: Vector2=_project_tactical_cell_to_screen(cells[1])
		if not core.is_finite() or not platform.is_finite():continue
		_frontline_overlay.draw_line(core,platform,Color(0.1,0.7,0.8,0.75),5)
		_frontline_overlay.draw_rect(Rect2(platform-Vector2(44,20),Vector2(88,40)),Color(0.03,0.22,0.25,0.55))
		_frontline_overlay.draw_rect(Rect2(platform-Vector2(44,20),Vector2(88,40)),Color.CYAN,false,2)
		_frontline_overlay.draw_string(font,platform+Vector2(-40,5),"驻防平台 %d/%d"%[structure.integrity_current,structure.integrity_max],HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color.WHITE)
		var assigned: Dictionary=context.tactical_structure_board_state.get_garrison_for_slot(structure.structure_id,&"garrison_0")
		if assigned.get("state",&"")!=&"active":continue
		for offset: Vector2i in [Vector2i.ZERO,Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var point: Vector2=_project_tactical_cell_to_screen(cells[1]+offset)
			if point.is_finite():_frontline_overlay.draw_arc(point,28,0,TAU,24,Color(0.25,0.9,0.65,0.72),2)
	if is_instance_valid(_monster_command_menu) and _monster_command_menu.visible:
		var unit: CardData=_monster_command_menu._card
		if unit!=null and unit in context.player.field:
			for cell: Vector2i in battle.get_legal_attack_cells(unit):
				var point: Vector2=_project_tactical_cell_to_screen(cell)
				if point.is_finite():_frontline_overlay.draw_arc(point,31,0,TAU,24,Color(1,0.55,0.15),2)

func _end_battle(victory: bool) -> void:
	if battle_ended:return
	# Discard unpaid previews before native result handling; never refund paid sites.
	_engineering_quote={};_facility_pending_quote={};_fort_quote={}
	_growth_pending_quote={};_growth_pending_uid=0
	for dialog: Window in [_engineering_window,_engineering_confirm,_facility_window,_facility_confirm,_fort_window,_fort_confirm,_growth_confirm]:
		if is_instance_valid(dialog):dialog.hide()
	var tools: Variant=get_node_or_null("IntegratedPlaytestTools")
	if tools!=null:
		tools.refresh_vitals()
		if is_instance_valid(tools.guide_window):tools.guide_window.hide()
	super._end_battle(victory)

func _on_retry() -> void:
	if _gb1_restarting or not integrated_navigation_ready():return
	_cleanup_structure_presentation_lifecycle(&"retry")
	restart_gb1_battle()

func focus_safe_rect() -> Rect2:
	var viewport:=get_viewport_rect().size
	return Rect2(Vector2(viewport.x*0.035,viewport.y*0.20),Vector2(viewport.x*0.775,viewport.y*0.54))
func focus_dock_rect() -> Rect2:
	var viewport:=get_viewport_rect().size
	return Rect2(Vector2(viewport.x*0.83,viewport.y*0.29),Vector2(viewport.x*0.16-12.0,viewport.y*0.41))
func focus_world_points() -> Array[Vector3]:
	var frame:=_compute_tactical_grid_frame()
	var points: Array[Vector3]=[]
	if not frame.get("ok",false):return points
	var half_x: float=frame.width_world/8.0
	var half_z: float=frame.depth_world/8.0
	for cell: Vector2i in battle.tactical_grid_rules.get_all_cells():
		var surface: Node3D=_get_3d_surface_anchor_for_cell(cell)
		if not is_instance_valid(surface):continue
		for x: float in [-half_x,half_x]:
			for z: float in [-half_z,half_z]:
				points.append(surface.global_position+Vector3(x,0,z))
		points.append(surface.global_position+Vector3(0,0.60,0))
	return points
func _camera_target_snapshot(preset_name: String) -> Dictionary:
	var fallback:=super._camera_target_snapshot(preset_name)
	if battle==null or not is_instance_valid(_get_3d_camera()):return fallback
	var container: SubViewportContainer=get_node_or_null("Battle3DViewport")
	if container==null or container.size.x<=0:return fallback
	var safe:=focus_safe_rect();safe.position-=container.get_global_rect().position
	var result: Dictionary=preload("res://scenes/presentation/battle_focus_framer.gd").fit(focus_world_points(),_camera_rig_origin,_get_3d_camera().get_camera_projection(),container.size,safe,90.0,82.0 if preset_name=="top" else 54.0)
	if not result.get("ok",false):return fallback
	result.active_preset=BattleViewCameraState.Preset.TOP if preset_name=="top" else BattleViewCameraState.Preset.BASE
	return result

func _open_monster_command_menu(card: CardData) -> void:
	super._open_monster_command_menu(card)
	if is_instance_valid(_focused_layout) and is_instance_valid(_monster_command_menu):_focused_layout.dock_command_menu(_monster_command_menu)
func _get_detail_panel_display_rect(_pinned: bool) -> Rect2:
	return focus_dock_rect()

func _on_monster_command(action: String,card: CardData) -> void:
	super._on_monster_command(action,card)
	if action=="detail" and card!=null and is_instance_valid(player_table):
		player_table._on_card_selected_detail(card)
