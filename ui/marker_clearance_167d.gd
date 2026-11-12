extends Node
## Keep existing target badges/leader lines, but leave visible unit hit areas free.
var owner_ref: WeakRef
func _process(_delta: float) -> void:
 var s: Variant=owner_ref.get_ref() if owner_ref!=null else null
 if not is_instance_valid(s):return
 var avoid: Array[Rect2]=[s._boss_status_hud.get_global_rect().grow(4)]
 for card: CardData in s.context.player.field+s.context.enemy.field:
  var point: Vector2=s._project_3d_token_to_screen(s._get_3d_token_for_card(card))
  if point.is_finite():avoid.append(Rect2(point-Vector2(46,40),Vector2(92,84)))
 var bounds:=Rect2(Vector2(12,12),Vector2(s.focus_dock_rect().position.x-24,s.get_viewport_rect().size.y*0.6-12))
 var buttons: Array=s.targets167b.buttons.values()
 var offsets: Array[Vector2]=[Vector2.ZERO,Vector2(0,-68),Vector2(0,68),Vector2(-164,0),Vector2(164,0),Vector2(-328,0),Vector2(328,0),Vector2(-164,68),Vector2(164,68),Vector2(0,136)]
 for b: Button in buttons:
  if not b.visible:continue
  var original: Vector2=b.position
  for offset: Vector2 in offsets:
   var rect:=Rect2(original+offset,b.size)
   if not bounds.encloses(rect) or avoid.any(func(r):return r.intersects(rect)):continue
   var overlap:=false
   for other: Button in buttons:
    if other!=b and other.visible and other.get_global_rect().grow(3).intersects(rect):overlap=true;break
   if overlap:continue
   b.position=original+offset;break
 s.targets167b.lines.queue_redraw()
