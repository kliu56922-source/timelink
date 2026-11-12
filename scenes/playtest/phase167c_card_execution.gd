extends "res://scenes/playtest/phase167b_boss_targets.gd"
var ready167c:=false
func _create_battle_system() -> BattleSystem:return preload("res://core/battle/card_execution_battle_167c.gd").new()
func _ready() -> void:
	await super._ready()
	recipe166.set_script(preload("res://battle/analysis/recipe_execution_runner_167c.gd"));recipe166.setup(self)
	recipe_fx166.set_script(preload("res://ui/recipe_execution_fx_167c.gd"));recipe_fx166.setup(self)
	get_node("IntegratedPlaytestTools").guide_window.dialog_text="167C：确认后两key、费用、学徒已经整套结算一次。战场随后显示关键牌离手→炉基座→燃芯使魔→独立池学徒→连接；空格/×4加速，Esc/跳过只结束观看，不撤回付款/生成。仍由你选择阵型与主锚点，不接管后续回合或进攻决定。\n\n"+get_node("IntegratedPlaytestTools").guide_window.dialog_text
	var stamp:=Node.new();stamp.name="Phase167CStamp";stamp.set_script(preload("res://ui/phase_stamp_167c.gd"));add_child(stamp);stamp.owner_ref=weakref(self)
	ready167c=true
func _sync_3d_field_tokens() -> void:
	super._sync_3d_field_tokens()
	if ready167c and recipe_fx166.active:recipe_fx166.mask167c.enforce()
func _refresh_tables() -> void:
	super._refresh_tables()
	if ready167c and recipe_fx166.active:recipe_fx166.mask167c.enforce()
func _input(event: InputEvent) -> void:
	if ready167c and recipe166.running:
		if _exit_modal_active:return
		if event is InputEventMouse:
			if recipe_panel166.owns_pointer(event.position) or _view_controls._exit_button.get_global_rect().has_point(event.position):return
			get_viewport().set_input_as_handled();return
	super._input(event)
func axis155_navigate(nav: String) -> void:
	if not ready167c or nav not in ["restart","home"]:return
	if building_committing167a:return
	if _building_preview_open167a():building_preview167a.hide();building_uid167a=0
	if body_busy166d or transition166d:_nav166d=nav;return
	if support166c.running:_support_nav166c=nav;support166c.skip();return
	if recipe166.running:_recipe_nav166=nav;recipe166.skip();return
	if advance165.running:_advance_nav165=nav;advance165.stop("导航");return
	if axis155.running:_axis155_navigation=nav;axis155.stop("导航");return
	if _gb1_restarting or not axis155_native_ready():return
	targets167b.dismiss();support_panel166c.dismiss();recipe_panel166.dismiss();advance_panel165.dismiss();advance165.stop("navigation");axis155.stop("navigation");_gb1_restarting=true
	if nav=="home":_cleanup_structure_presentation_lifecycle(&"return_to_menu");_cancel_monster_summon_interaction(&"return_to_menu")
	var path: String="res://scenes/playtest/phase167c_card_execution.tscn" if nav=="restart" else "res://scenes/menu/demo_home.tscn"
	if get_tree().change_scene_to_file(path)!=OK:_gb1_restarting=false;push_error("167C navigation failed")

func _refresh_back_row_readability() -> void:
	super._refresh_back_row_readability()
	if not ready167c or not recipe_fx166.active or not is_instance_valid(_back_row_readability):return
	var filtered: Array[Dictionary]=[]
	for row: Dictionary in _back_row_readability.items:
		var hidden:=false
		for card: CardData in context.player.traps:
			if card.card_id!=row.card_id or not recipe_fx166.mask167c.is_hidden167c(card.get_instance_id()):continue
			var sid: StringName=context.tactical_structure_board_state.get_source_structure_id(card.get_instance_id())
			var cell: Vector2i=context.tactical_structure_board_state.get_foundation_status(sid).get("cell",Vector2i(-1,-1))
			if _project_tactical_cell_to_screen(cell).distance_to(row.position)<0.5:hidden=true;break
		if not hidden:filtered.append(row)
	_back_row_readability.refresh(filtered,_back_row_readability.reserved)
func _refresh_weakpoint162a() -> void:
	super._refresh_weakpoint162a()
	if is_instance_valid(weakpoint_label):weakpoint_label.text=weakpoint_label.text.replace("167B ","167C ")
