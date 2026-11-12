extends "res://scenes/playtest/phase167a_operation_clarity.gd"
var targets167b: CanvasLayer
var ready167b:=false
func _ready() -> void:
	await super._ready()
	targets167b=preload("res://ui/boss_target_commander_167b.gd").new();add_child(targets167b);targets167b.setup(self)
	get_node("IntegratedPlaytestTools").guide_window.dialog_text="167B：场上Boss边缘三个部位可点。点部位→选单位→有分支时选路线→确认；查看与预览不付款。外围可任选顺序，核心要先破两外围，且允许任一合法攻核列。灰色残骸不再受击/重复奖励。守卫橙框及名称提示需先清障或换通路，原单位先选入口仍保留。\n\n"+get_node("IntegratedPlaytestTools").guide_window.dialog_text
	ready167b=true
func _input(event: InputEvent) -> void:
	if is_instance_valid(targets167b) and event is InputEventMouse and targets167b.owns_pointer(event.position):
		# Matching releases finish gestures that began on the board, even when
		# the new foreground controls own the pointer at release time.
		if event is InputEventMouseButton and not event.pressed:
			if event.button_index==MOUSE_BUTTON_RIGHT:_camera_orbit_dragging=false
			elif event.button_index==MOUSE_BUTTON_MIDDLE:_cancel_camera_pan()
		return
	super._input(event)
func _refresh_weakpoint162a() -> void:
	super._refresh_weakpoint162a()
	if is_instance_valid(weakpoint_label):weakpoint_label.text=weakpoint_label.text.replace("166D ","167B ")
func _on_end_turn() -> void:
	if is_instance_valid(targets167b):targets167b.dismiss()
	await super._on_end_turn()
func _on_card_clicked(card_ui: CardUI) -> void:
	if is_instance_valid(targets167b):targets167b.dismiss()
	await super._on_card_clicked(card_ui)
func _on_building_interact(card: CardData) -> void:
	if is_instance_valid(targets167b):targets167b.dismiss()
	await super._on_building_interact(card)
func _open_monster_command_menu(card: CardData) -> void:
	if is_instance_valid(targets167b):targets167b.dismiss()
	super._open_monster_command_menu(card)
func axis155_navigate(nav: String) -> void:
	if not ready167b or nav not in ["restart","home"]:return
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
	var destination: String="res://scenes/playtest/phase167b_boss_targets.tscn" if nav=="restart" else "res://scenes/menu/demo_home.tscn"
	var error:=get_tree().change_scene_to_file(destination)
	if error!=OK:_gb1_restarting=false;push_error("167B navigation failed")
