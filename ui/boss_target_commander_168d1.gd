extends "res://ui/boss_target_commander_167b.gd"
var actor_reasons168d1: Array[Label]=[]
var reason_ids168d1: Array=[]
var unit_bar_origin168d1:=Vector2(16,160)
func _process(delta: float) -> void:
 super._process(delta)
 avoid_occupied_bar168d1()
func avoid_occupied_bar168d1() -> void:
 var s: Variant=scene()
 if s==null:return
 var bar: HBoxContainer=s.advance_panel165.source_bar
 bar.position=unit_bar_origin168d1
 if not bar.is_visible_in_tree():return
 var overlap:=false;var top:=INF;var bottom:=0.0
 for marker: Button in buttons.values():
  if not marker.is_visible_in_tree():continue
  var rect: Rect2=marker.get_global_rect();top=minf(top,rect.position.y);bottom=maxf(bottom,rect.end.y)
  for unit: Button in s.advance_panel165.source_buttons:
   if unit.is_visible_in_tree() and unit.get_global_rect().intersects(rect):overlap=true
 if not overlap:return
 # Prefer the real gap below the HUD and above the targets. Moving below the
 # targets unnecessarily covers the front board when this gap is available.
 var above:=Rect2(Vector2(unit_bar_origin168d1.x,top-bar.size.y),bar.size)
 var fits: bool=above.position.y>=0 and not above.intersects(s._boss_status_hud.get_global_rect()) and not above.intersects(s.training_panel168a.entry.get_global_rect())
 bar.position.y=above.position.y if fits else bottom+6
func refresh_drawer() -> void:
 super.refresh_drawer()
 if _drawer_data.is_empty():return
 if reason_ids168d1!=actor_ids:
  for label: Label in actor_reasons168d1:
   if is_instance_valid(label):label.get_parent().remove_child(label);label.queue_free()
  actor_reasons168d1.clear();reason_ids168d1=actor_ids.duplicate()
  for i in range(actor_ids.size()):
   var label: Label=_label(actors);actors.move_child(label,i*2+1);actor_reasons168d1.append(label)
 for i in range(actor_buttons.size()):
  var candidate: Dictionary=_drawer_data.candidates[i]
  actor_buttons[i].text=candidate.name+" · "+candidate.cost_text+"\n"+("选此单位，继续看路线/预览" if candidate.ok else "点单位查看准备方式")
  actor_reasons168d1[i].text=str(candidate.reason)+"\n可查看手动准备，或结束回合后重新预览；现在未付款。" if not candidate.ok else ""
  actor_reasons168d1[i].visible=not candidate.ok
