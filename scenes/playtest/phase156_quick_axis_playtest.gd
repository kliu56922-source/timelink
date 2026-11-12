extends "res://scenes/playtest/phase155_tactical_axis_playtest.gd"
const QUICK156="res://scenes/playtest/phase156_quick_axis_playtest.tscn"
func _ready() -> void:
	await super._ready()
	var previous: CanvasLayer=axis155_panel
	previous.queue_free()
	axis155_panel=preload("res://ui/quick_tactical_axis_panel.gd").new();add_child(axis155_panel);axis155_panel.setup(self)
	await get_tree().process_frame
func axis155_navigate(nav: String) -> void:
	if nav!="restart":super.axis155_navigate(nav);return
	if is_instance_valid(axis155) and axis155.running:_axis155_navigation=nav;axis155.stop("重开");return
	if _gb1_restarting or not axis155_native_ready():return
	axis155.stop("navigation");_gb1_restarting=true
	var err:=get_tree().change_scene_to_file(QUICK156)
	if err!=OK:_gb1_restarting=false;push_error("156 restart failed")
func _input(event: InputEvent) -> void:
	if is_instance_valid(axis155_panel) and axis155_panel.has_method("open_axis") and event is InputEventMouse and not axis155.running:
		for control: Control in [axis155_panel.entry_bar,axis155_panel.progress]:
			if control.visible and control.get_global_rect().has_point(event.position):return
	super._input(event)
func _get_structure_reserved_ui_rects() -> Array[Rect2]:
	var rects: Array[Rect2]=super._get_structure_reserved_ui_rects()
	if is_instance_valid(axis155_panel) and axis155_panel.has_method("open_axis"):
		for control: Control in [axis155_panel.entry_bar,axis155_panel.progress]:
			if control.visible:rects.append(control.get_global_rect())
	return rects
