extends "res://scenes/playtest/phase156_quick_axis_playtest.gd"
const SPATIAL158="res://scenes/playtest/phase158_spatial_axis_playtest.tscn"
func _ready() -> void:
	await super._ready()
	var old: CanvasLayer=axis155_panel;old.queue_free()
	axis155_panel=preload("res://ui/spatial_tactical_axis_panel.gd").new();add_child(axis155_panel);axis155_panel.setup(self)
	await get_tree().process_frame
func axis155_navigate(nav: String) -> void:
	if nav!="restart":super.axis155_navigate(nav);return
	if is_instance_valid(axis155) and axis155.running:_axis155_navigation=nav;axis155.stop("重开");return
	if _gb1_restarting or not axis155_native_ready():return
	axis155.stop("navigation");_gb1_restarting=true
	var err:=get_tree().change_scene_to_file(SPATIAL158)
	if err!=OK:_gb1_restarting=false;push_error("158 restart failed")
