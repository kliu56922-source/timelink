extends "res://scenes/playtest/phase168b_single_guard.gd"
const Situation168b2=preload("res://ui/maintenance_situation_168b2.gd")
var ready168b2:=false
func maintenance_situation168b2() -> Dictionary:return Situation168b2.build(self)
func _ready() -> void:
 await super._ready()
 _adapt168b(training_panel168a,preload("res://ui/training_panel_168b2.gd"),["owner_ref","entry","window","text","card_select","status","tab168a"])
 _adapt168b(journal168a,preload("res://battle/analysis/training_journal_168b2.gd"),["owner_ref","entries","_last_state","_elapsed","started_us"])
 _adapt168b(flow166d,preload("res://ui/training_flow_168b2.gd"),["scene_ref","body_button","maintenance167d"])
 training_panel168a.entry.text="168B2 受损维护 · 规则与记录";training_panel168a.window.title="168B2 受损与维护 · 不计普通胜率"
 _playtest.run_label="168B2_maintenance_not_winrate"
 get_node("IntegratedPlaytestTools").guide_window.dialog_text="168B2：受伤后点单位→维护此单位→选使魔或炉基座→确认；学徒离场后从连续操作选择补回学徒与合法落点。维护最多恢复2血，不刷新行动；补位保留休整。每回合一次/本场两次/补位一次。1指令、热+2、负荷+1，素材不额外登场或检索；取消不付款。是否维护由你决定，满血/学徒在场时无需维护。"
 ready168b2=true;training_panel168a.refresh168a();flow166d.refresh()
 journal168a.capture168a("maintenance_training_ready",{"source":"readonly_guidance_no_scene_damage"})
func training_snapshot168a() -> Dictionary:
 var state: Dictionary=super.training_snapshot168a();state.mode="168B2_maintenance_training";state.maintenance_situation=maintenance_situation168b2();return state
func _refresh_weakpoint162a() -> void:
 super._refresh_weakpoint162a()
 if is_instance_valid(weakpoint_label):weakpoint_label.text=weakpoint_label.text.replace("168B ","168B2 ")
func _end_battle(victory: bool) -> void:
 if battle_ended:return
 super._end_battle(victory)
 if is_instance_valid(result_panel):result_panel.info_label.text=result_panel.info_label.text.replace("168A训练完成","168B2训练完成")
func axis155_navigate(nav: String) -> void:
 if not ready168b2 or nav not in ["restart","home"]:return
 if is_instance_valid(training_panel168a):training_panel168a.close168a()
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
 var path: String="res://scenes/playtest/phase168b2_maintenance.tscn" if nav=="restart" else "res://scenes/menu/demo_home.tscn"
 if get_tree().change_scene_to_file(path)!=OK:_gb1_restarting=false;push_error("168B2 navigation failed")

func _raycast_3d_click(screen_pos: Vector2) -> Dictionary:
 var first: Dictionary=super._raycast_3d_click(screen_pos)
 # During a pending native attack only, a nearer friendly front token must
 # not hide a legal enemy which the same pointer ray actually intersects.
 if not ready168b2 or _exit_modal_active or not _is_lane_selection_active() or _lane_selection_mode!=LANE_SELECT_ATTACK or not is_instance_valid(_lane_selection_card):return first
 if first.get("side","")!="player" or first.get("zone","")!="front":return first
 var vpc: SubViewportContainer=get_node("Battle3DViewport");var vp: SubViewport=vpc.get_node("SubViewport");var cam: Camera3D=_get_3d_camera()
 if cam==null or not vpc.get_global_rect().has_point(screen_pos) or vp.find_world_3d()==null:return first
 var point:=screen_pos-vpc.get_global_rect().position;var origin:=cam.project_ray_origin(point);var endpoint:=origin+cam.project_ray_normal(point)*30.0
 var excluded: Array[RID]=[]
 for i in range(16):
  var query:=PhysicsRayQueryParameters3D.create(origin,endpoint);query.collision_mask=TOKEN_CLICK_COLLISION_LAYER;query.collide_with_areas=true;query.collide_with_bodies=false;query.exclude=excluded
  var result: Dictionary=vp.find_world_3d().direct_space_state.intersect_ray(query)
  if result.is_empty():return first
  var node: Node=result.get("collider")
  while node!=null and not (node.has_meta("card") and node.has_meta("side") and node.has_meta("zone")):node=node.get_parent()
  # Structures, other markers and non-card surfaces retain native priority.
  if node==null:return first
  var card: CardData=node.get_meta("card")
  if node.get_meta("side")=="player" and node.get_meta("zone")=="front":excluded.append(result.rid);continue
  if is_instance_valid(card) and card in context.enemy.field and battle.get_unit_command_status(_lane_selection_card,"attack",card).get("ok",false):
   return {"ok":true,"card":card,"side":node.get_meta("side"),"zone":node.get_meta("zone"),"index":node.get_meta("field_index",node.get_meta("slot_index",-1)),"token":node}
  return first
 return first
