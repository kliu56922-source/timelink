extends "res://scenes/playtest/phase165a_advance_weakpoint.gd"
var ready166:=false
var recipe166: Node
var recipe_panel166: CanvasLayer
var recipe_fx166: Control
var _recipe_nav166:=""
func _create_battle_system() -> BattleSystem:return preload("res://core/battle/key_recipe_battle_system.gd").new()
func _refresh_weakpoint162a() -> void:
	super._refresh_weakpoint162a()
	if is_instance_valid(weakpoint_label) and weakpoint_label.text.begins_with("165A "):weakpoint_label.text="166A "+weakpoint_label.text.substr(5)
func _has_non_presentation_end_turn_busy(drag_takeover_card: CardData=null) -> bool:
	if ready166 and recipe166.running:return true
	return super._has_non_presentation_end_turn_busy(drag_takeover_card)
func _on_od_feedback_event_committed(event: Dictionary) -> void:
	if str(event.get("transaction_id","")).begins_with("recipe166:"):
		# The root's spatial presenter owns this one receipt, including heat.
		# Keep native telemetry/HUD; don't queue a second independent mini-scene
		# that would survive the user's acceleration/skip request.
		if _playtest!=null and _playtest.has_method("record_od_feedback_event"):_playtest.record_od_feedback_event(event)
		_refresh_od_engine_greybox();return
	super._on_od_feedback_event_committed(event)
func _ready() -> void:
	await super._ready()
	recipe166=preload("res://battle/analysis/key_recipe_runner.gd").new();add_child(recipe166);recipe166.setup(self)
	var fx_layer:=CanvasLayer.new();fx_layer.layer=61;add_child(fx_layer)
	recipe_fx166=preload("res://ui/key_recipe_board_fx.gd").new();fx_layer.add_child(recipe_fx166);recipe_fx166.setup(self)
	recipe_panel166=preload("res://ui/key_recipe_panel.gd").new();add_child(recipe_panel166);recipe_panel166.setup(self)
	get_node("IntegratedPlaytestTools").guide_window.dialog_text+="\n\n166A：左侧双关键展开→阵型→棋盘主锚点→确认。整套需P02/P05和1指令，热+4/盾+3/负荷+2，生成一个衍生学徒。组合替代key单用登场/检索。前场需2空位、建筑需1空位；每场一次，召唤病保留。确认后全额结算，再现场演出；×4/跳过只改表现。新首回合部署限制尚未实施。"
	ready166=true
func _process(delta: float) -> void:
	super._process(delta)
	if ready166 and not recipe166.running and not advance165.running and not axis155.running and axis155_native_ready():battle.recipe166_prune()
func _input(event: InputEvent) -> void:
	if _exit_modal_active:return
	if not ready166:super._input(event);return
	if event is InputEventMouse and recipe_panel166.owns_pointer(event.position):return
	if recipe166.running:
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode==KEY_ESCAPE:recipe166.skip()
			elif event.keycode==KEY_SPACE:recipe166.accelerate()
		get_viewport().set_input_as_handled();return
	if recipe_panel166.panel.visible:
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode==KEY_ESCAPE:recipe_panel166.dismiss();get_viewport().set_input_as_handled();return
			if event.keycode==KEY_ENTER:recipe_panel166.submit();get_viewport().set_input_as_handled();return
		if recipe_panel166.selecting and event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed:
			recipe_panel166.pointer(event.position);get_viewport().set_input_as_handled();return
	super._input(event)
func _coordinates_needed164() -> bool:
	return super._coordinates_needed164() or (ready166 and recipe_panel166.panel.visible and recipe_panel166.selecting)
func _on_card_clicked(card_ui: CardUI) -> void:
	if ready166 and recipe166.running:return
	if ready166:recipe_panel166.dismiss()
	await super._on_card_clicked(card_ui)
func _on_building_interact(card: CardData) -> void:
	if ready166 and recipe166.running:return
	if ready166:recipe_panel166.dismiss()
	await super._on_building_interact(card)
func _open_monster_command_menu(card: CardData) -> void:
	if ready166 and recipe166.running:return
	if ready166:recipe_panel166.dismiss()
	super._open_monster_command_menu(card)
func _on_end_turn() -> void:
	if ready166 and recipe166.running:return
	if ready166:recipe_panel166.dismiss()
	await super._on_end_turn()
func integrated_navigation_ready() -> bool:
	if ready166 and recipe166.running:return false
	return super.integrated_navigation_ready()
func axis155_native_ready() -> bool:
	if ready166 and recipe166.running:return false
	return super.axis155_native_ready()
func axis155_navigate(nav: String) -> void:
	if not ready166:return
	if recipe166.running:_recipe_nav166=nav;recipe166.skip();return
	if advance165.running:_advance_nav165=nav;advance165.stop("导航");return
	if axis155.running:_axis155_navigation=nav;axis155.stop("导航");return
	if nav not in ["restart","home"] or _gb1_restarting or not axis155_native_ready():return
	recipe_panel166.dismiss();advance165.stop("navigation");axis155.stop("navigation");_gb1_restarting=true
	if nav=="home":_cleanup_structure_presentation_lifecycle(&"return_to_menu");_cancel_monster_summon_interaction(&"return_to_menu")
	var err:=get_tree().change_scene_to_file("res://scenes/playtest/phase166a_key_recipe.tscn" if nav=="restart" else "res://scenes/menu/demo_home.tscn")
	if err!=OK:_gb1_restarting=false;push_error("166A navigation failed")
func recipe166_finished() -> void:
	if not _recipe_nav166.is_empty():
		var nav:=_recipe_nav166;_recipe_nav166="";axis155_navigate(nav)
