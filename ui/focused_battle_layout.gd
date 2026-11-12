extends Node
## Presentation adapter for the existing battle surface; no authority mutations.
var scene_ref: WeakRef
var engine_button: Button
func setup(scene: Variant) -> void:
	name="FocusedBattleLayout";scene_ref=weakref(scene)
	var tools: Variant=scene.get_node("IntegratedPlaytestTools")
	tools.vitals.reparent(tools,false)
	# Keep original OD handlers and all source/fee checks; move only the live control.
	if is_instance_valid(scene._od_release_control):scene._od_release_control.reparent(tools,false)
	if is_instance_valid(scene._od_release_control._mission_box):
		var mission: Control=scene._od_release_control._mission_box
		mission.reparent(tools.status.get_parent(),false)
		mission.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		mission.custom_minimum_size=Vector2(280,150)
	if is_instance_valid(scene._core_status_panel):scene._core_status_panel.hide()
	if is_instance_valid(scene._command_economy_hud):scene._command_economy_hud.hide()
	engine_button=Button.new();engine_button.text="引擎详细状态";tools.status.get_parent().add_child(engine_button)
	engine_button.pressed.connect(func():
		if is_instance_valid(scene._core_status_panel):scene._core_status_panel.visible=not scene._core_status_panel.visible)
	if is_instance_valid(scene._core_status_panel):scene._core_status_panel.reparent(tools,false)
	if is_instance_valid(scene._view_controls):
		scene._view_controls._base_button.text="战斗视角"
		scene._view_controls._free_button.hide()
	get_viewport().size_changed.connect(_resize)
	call_deferred("_resize")
	var actions: CanvasLayer=preload("res://ui/current_action_panel.gd").new()
	scene.add_child(actions);actions.setup(scene)
	set_process(true)
func _resize() -> void:
	var scene: Variant=scene_ref.get_ref()
	if scene==null or not is_instance_valid(scene._camera_state):return
	if scene._camera_state.active_preset!=BattleViewCameraState.Preset.FREE:
		scene._safe_kill_camera_tween()
		scene._apply_camera_snapshot(scene._camera_target_snapshot("top" if scene._camera_state.active_preset==BattleViewCameraState.Preset.TOP else "base"))
	_place_controls(scene)
	if is_instance_valid(scene._monster_command_menu):dock_command_menu(scene._monster_command_menu)
	if is_instance_valid(scene._detail_panel_slot) and scene._detail_panel_slot.visible:
		scene._set_detail_panel_expanded(true,true,scene.player_table.is_detail_pinned())
func _place_controls(scene: Variant) -> void:
	var viewport: Vector2=scene.get_viewport_rect().size
	var tools: Variant=scene.get_node("IntegratedPlaytestTools")
	tools.vitals.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	tools.vitals.position=Vector2(viewport.x*0.68,48)
	tools.vitals.size=Vector2(viewport.x*0.31-16,92)
	if is_instance_valid(scene._relation_coach_panel):scene._relation_coach_panel.hide()
	var feed: Control=scene.get_node_or_null("BattleFX/ActionFeedSafeLane")
	if is_instance_valid(feed):
		feed.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		feed.custom_minimum_size=Vector2(280,76);feed.position=Vector2(16,96);feed.size=Vector2(300,76)
	if is_instance_valid(scene._od_release_control):
		scene._od_release_control.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		scene._od_release_control.position=Vector2(viewport.x*0.83,viewport.y*0.22)
		scene._od_release_control.size=Vector2(viewport.x*0.16-12,40)

	if is_instance_valid(scene._end_turn_control):
		scene._end_turn_control.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		# Resetting offsets uses the 56px minimum; the native subtitle needs its 70px surface.
		scene._end_turn_control.size=Vector2(160,70)
		scene._end_turn_control.position=Vector2(viewport.x*0.83,viewport.y*0.72)
	if is_instance_valid(scene._core_status_panel):
		scene._core_status_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		scene._core_status_panel.position=Vector2(16,96);scene._core_status_panel.size=Vector2(280,200)
func dock_command_menu(menu: Control) -> void:
	var scene: Variant=scene_ref.get_ref()
	if scene==null:return
	var rect: Rect2=scene.focus_dock_rect()
	menu.use_focus_dock(rect.size.x,rect.size.y);menu.position=rect.position
	_fit_wrapped_labels(menu)
func _process(_delta: float) -> void:
	var scene: Variant=scene_ref.get_ref()
	if scene==null or scene.context==null or scene.battle==null:return
	var tools: Variant=scene.get_node_or_null("IntegratedPlaytestTools")
	if tools==null:return
	var economy: Dictionary=scene.battle.get_command_economy_snapshot("player")
	tools.vitals.text="核心生命：%d  护盾：%d\n热 %d/10 · Depth %d/%d · 指令 %d/%d\n引擎L%d · 充能%d"%[scene.context.player.hp,scene.context.player.shield,scene.context.od_mode.current_od,scene.context.depth_pressure,scene.context.get_depth_max_value(),int(economy.get("current_points",0)),int(economy.get("turn_max_points",0)),scene.context.od_mode.engine_layer,scene.context.od_mode.engine_charge]
	_place_controls(scene)
	if is_instance_valid(scene._monster_command_menu):_fit_wrapped_labels(scene._monster_command_menu)
	if is_instance_valid(scene.player_table.card_detail_panel):_fit_wrapped_labels(scene.player_table.card_detail_panel)

func _fit_wrapped_labels(node: Node) -> void:
	# Explicit measured height avoids collapsed wrapped labels in the narrow drawer.
	for child: Node in node.get_children():
		if child is Label and child.autowrap_mode!=TextServer.AUTOWRAP_OFF and child.is_visible_in_tree():
			var width: float=maxf(80,child.size.x)
			var key: String=child.text+"|"+str(width)
			if child.get_meta("focus_measure","")!=key:
				var font: Font=child.get_theme_font("font")
				var measured: Vector2=font.get_multiline_string_size(child.text,HORIZONTAL_ALIGNMENT_LEFT,width,child.get_theme_font_size("font_size"))
				child.custom_minimum_size.y=maxf(18,measured.y+2)
				child.set_meta("focus_measure",key)
		_fit_wrapped_labels(child)
