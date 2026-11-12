extends "res://scenes/playtest/phase168a_training.gd"
var ready168a1:=false
var semantics168a1: Node
const Detail168a1=preload("res://ui/semantic_detail_panel_168a1.gd")
func _setup_tables() -> void:
 # The native table constructs the panel synchronously. Adapt it before ready,
 # preserving its identity, wiring and all inherited @onready initialization.
 get_tree().node_added.connect(_adapt_detail168a1)
 super._setup_tables()
 get_tree().node_added.disconnect(_adapt_detail168a1)
func _adapt_detail168a1(node: Node) -> void:
 if node is CardDetailPanel and is_ancestor_of(node) and not node.is_node_ready():node.set_script(Detail168a1)
func _ready() -> void:
 await super._ready()
 # Native hover enlargement may extend above this old clipping rectangle.
 # Keep the native transform and input path; allow the full reading surface.
 get_node("HandArea").clip_contents=false
 semantics168a1=preload("res://ui/hand_semantics_presenter_168a1.gd").new();add_child(semantics168a1);semantics168a1.setup168a1(self)
 ready168a1=true
func _refresh_weakpoint162a() -> void:
 super._refresh_weakpoint162a()
 if is_instance_valid(weakpoint_label):weakpoint_label.text=weakpoint_label.text.replace("168A ","168A1 ")
func _get_detail_panel_display_rect(pinned: bool) -> Rect2:
 var rect: Rect2=super._get_detail_panel_display_rect(pinned)
 var card: CardData=null
 if player_table!=null and player_table.card_detail_panel!=null and player_table.card_detail_panel.has_method("reading_card168a1"):card=player_table.card_detail_panel.reading_card168a1()
 if preload("res://ui/hand_semantics_168a1.gd").recognized(card) and context!=null and card in context.player.hand:
  # Same native detail surface, wider only while reading an adapted hand card.
  var lower: float=rect.end.y;var right: float=rect.end.x
  rect.size=Vector2(450,400);rect.position=Vector2(maxf(20,right-rect.size.x),maxf(240,lower-rect.size.y))
 return rect
func axis155_navigate(nav: String) -> void:
 if not ready168a1 or nav not in ["restart","home"]:return
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
 var path: String="res://scenes/playtest/phase168a1_hand_semantics.tscn" if nav=="restart" else "res://scenes/menu/demo_home.tscn"
 if get_tree().change_scene_to_file(path)!=OK:_gb1_restarting=false;push_error("168A1 navigation failed")
