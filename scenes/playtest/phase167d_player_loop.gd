extends "res://scenes/playtest/phase167c_card_execution.gd"
var ready167d:=false
var metrics167d: Node
func _ready() -> void:
 await super._ready()
 var old: Variant=support_panel166c
 var legacy: Button=recipe_panel166.select_row.get_child(recipe_panel166.select_row.get_child_count()-1)
 legacy.pressed.disconnect(old.open);old.free()
 support_panel166c=preload("res://ui/maintenance_target_panel_167d.gd").new();add_child(support_panel166c);support_panel166c.setup(self)
 support166c.changed.connect(support_panel166c.sync);legacy.pressed.connect(support_panel166c.open)
 var body: Button=flow166d.body_button
 flow166d.set_script(preload("res://ui/player_loop_flow_167d.gd"));flow166d.scene_ref=weakref(self);flow166d.body_button=body;flow166d.setup167d();flow166d.process_priority=10
 metrics167d=preload("res://ui/player_loop_metrics_167d.gd").new();add_child(metrics167d);metrics167d.setup167d(self)
 get_node("IntegratedPlaytestTools").guide_window.dialog_text="167D：部署结束由你点「部署完成」进入交战。点场上Boss部位→单位→有分支时路线→确认，途中可停止；费用逐步支付。受伤单位可点「维护此单位」，再选手牌素材与确认；取消不付款，不强迫每局维护。三要害全破后点单位→攻击Boss本体，不再选择要害路线。\n\n"+get_node("IntegratedPlaytestTools").guide_window.dialog_text
 var clearance:=preload("res://ui/marker_clearance_167d.gd").new();clearance.owner_ref=weakref(self);clearance.process_priority=100;add_child(clearance)
 ready167d=true
func _input(event: InputEvent) -> void:
 if is_instance_valid(metrics167d):metrics167d.observe167d(event)
 super._input(event)
func maintain167d(uid: int) -> Dictionary:
 var gate: String=support166c._gate()
 if not gate.is_empty():return {"ok":false,"reason":gate}
 var actor: CardData=advance165.resolve(uid)
 if actor==null or actor not in context.player.field:return {"ok":false,"reason":"原单位已离场，重新选择"}
 targets167b.dismiss();support_panel166c.open_target167d(actor)
 return {"ok":true,"target_uid":uid,"preview_only":true}
func _refresh_weakpoint162a() -> void:
 super._refresh_weakpoint162a()
 if is_instance_valid(weakpoint_label):weakpoint_label.text=weakpoint_label.text.replace("167C ","167D ")

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
 var path: String="res://scenes/playtest/phase167d_player_loop.tscn" if nav=="restart" else "res://scenes/menu/demo_home.tscn"
 if get_tree().change_scene_to_file(path)!=OK:_gb1_restarting=false;push_error("167D navigation failed")


func _raycast_3d_click(screen_pos: Vector2) -> Dictionary:
 # Native piece moves already prioritize legal green cells through tokens.
 # Apply that same picker to the apprentice's classic move selection as well.
 if ready167d and _is_lane_selection_active() and _lane_selection_mode==LANE_SELECT_MOVE and is_instance_valid(_lane_selection_card) and not _exit_modal_active:
  var vpc: SubViewportContainer=get_node("Battle3DViewport")
  var vp: SubViewport=vpc.get_node("SubViewport")
  var cam: Camera3D=_get_3d_camera();var rect: Rect2=vpc.get_global_rect()
  if cam!=null and rect.has_point(screen_pos) and vp.find_world_3d()!=null:
   var point:=screen_pos-rect.position;var origin:=cam.project_ray_origin(point)
   var hit: Dictionary=_raycast_active_move_cell(vp.find_world_3d().direct_space_state,origin,origin+cam.project_ray_normal(point)*30.0)
   if hit.get("selection_mode",&"")==LANE_SELECT_MOVE and battle.get_unit_move_cell_status(_lane_selection_card,hit.get("board_cell",Vector2i(-1,-1)),battle.MOVE_SELF).get("ok",false):return hit
 return super._raycast_3d_click(screen_pos)
