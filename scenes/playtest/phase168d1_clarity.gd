extends "res://scenes/playtest/phase168c_compact.gd"
var ready168d1:=false
func adapt_ui168d1(node: Node,script: Script) -> void:
 var saved: Dictionary={}
 for property: Dictionary in node.get_property_list():
  if int(property.usage)&PROPERTY_USAGE_SCRIPT_VARIABLE:saved[property.name]=node.get(property.name)
 node.set_script(script)
 for key: String in saved:node.set(key,saved[key])
func _ready() -> void:
 get_tree().create_timer(0.45).timeout.connect(_release_close_guide)
 await super._ready()
 # Empty container background must not swallow a marker below this CanvasLayer.
 # Children retain their original STOP behavior and explicit selection callbacks.
 advance_panel165.source_bar.mouse_filter=Control.MOUSE_FILTER_IGNORE
 adapt_ui168d1(compact168c,preload("res://ui/compact_actions_168d1.gd"))
 adapt_ui168d1(support_panel166c,preload("res://ui/compact_maintenance_panel_168d1.gd"))
 adapt_ui168d1(training_panel168a,preload("res://ui/training_panel_168d1.gd"))
 adapt_ui168d1(flow166d,preload("res://ui/training_flow_168d1.gd"))
 adapt_ui168d1(targets167b,preload("res://ui/boss_target_commander_168d1.gd"))
 targets167b.unit_bar_origin168d1=advance_panel165.source_bar.position
 adapt_ui168d1(journal168a,preload("res://battle/analysis/training_journal_168d1.gd"))
 training_panel168a.entry.text="168D1 操作提示修复 · 规则与记录";training_panel168a.window.title="168D1 真实规则训练 · 不计普通胜率"
 _playtest.run_label="168D1_clarity_not_winrate"
 ready168d1=true;training_panel168a.refresh168a();flow166d.refresh();journal168a.capture168a("clarity_training_ready")
func training_snapshot168a() -> Dictionary:
 var result: Dictionary=super.training_snapshot168a();result.mode="168D1_player_clarity";return result
func _refresh_weakpoint162a() -> void:
 super._refresh_weakpoint162a()
 if is_instance_valid(weakpoint_label):weakpoint_label.text=weakpoint_label.text.replace("168C ","168D1 ")
func _end_battle(victory: bool) -> void:
 if battle_ended:return
 super._end_battle(victory)
 if is_instance_valid(result_panel):result_panel.info_label.text=result_panel.info_label.text.replace("168C训练完成","168D1训练完成")
func axis155_navigate(nav: String) -> void:
 if not ready168d1 or nav not in ["restart","home"]:return
 if _compact_preview_open168c():compact168c.cancel_attack168c()
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
 var path: String="res://scenes/playtest/phase168d1_clarity.tscn" if nav=="restart" else "res://scenes/menu/demo_home.tscn"
 if get_tree().change_scene_to_file(path)!=OK:_gb1_restarting=false;push_error("168D1 navigation failed")


func _release_close_guide() -> void:
 if not is_instance_valid(training_panel168a):
  return
 var w: Window = training_panel168a.window
 if w == null:
  return
 w.size = Vector2i(720, 320)
 if w.visible:
  training_panel168a.close168a()
