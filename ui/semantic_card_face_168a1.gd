extends Control
## Greybox reading surface. Native CardUI remains the sole input owner.
var labels: Dictionary={}
var highlighted:=false
var facts: Dictionary={}
func _ready() -> void:
 name="SemanticFace168A1";mouse_filter=Control.MOUSE_FILTER_IGNORE;z_index=45
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 for spec: Array in [["CardName",4,22,14],["TypeRole",27,18,12],["Cost",46,18,11],["Load",46,18,11],["Stats",66,18,12],["Effect",69,70,14],["State",143,16,11],["Combo",159,16,11],["ComboEntry",175,16,11]]:
  var l:=Label.new();l.name=spec[0];l.position=Vector2(8,spec[1]);l.size=Vector2(136,spec[2]);l.mouse_filter=Control.MOUSE_FILTER_IGNORE
  l.add_theme_font_size_override("font_size",spec[3]);l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;l.clip_text=true
  if spec[0]=="State":l.max_lines_visible=1;l.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
  l.add_theme_color_override("font_color",Color("eaf3fa"));add_child(l);labels[spec[0]]=l
 labels.Cost.size.x=86;labels.Load.position.x=96;labels.Load.size.x=48
 labels.TypeRole.add_theme_color_override("font_color",Color("ffe5a2"))
 labels.Load.add_theme_color_override("font_color",Color("c1d4de"))
 labels.Combo.add_theme_color_override("font_color",Color("80e9db"))
 labels.ComboEntry.add_theme_color_override("font_color",Color("80e9db"))
 queue_redraw()
func update168a1(data: Dictionary) -> void:
 if facts!=data:
  facts=data
  labels.CardName.text=data.name;labels.TypeRole.text=data.type+" · "+data.role;labels.Cost.text=data.cost;labels.Load.text=data.load
  labels.Stats.text=data.stats;labels.Stats.visible=not data.stats.is_empty()
  labels.Effect.position.y=86 if labels.Stats.visible else 69;labels.Effect.size.y=52 if labels.Stats.visible else 70
  labels.Effect.text=data.summary;labels.State.text=data.status
  labels.State.add_theme_color_override("font_color",Color("c4dfed") if data.ok else Color("ffcc9c"))
  labels.Combo.text="";labels.ComboEntry.text=""
  if not data.combo.is_empty():labels.Combo.text=data.combo.partner_name+"→炉心阵地";labels.ComboEntry.text="点「连续展开」预览"
 # Counter the original 'unplayable' dim on this reading surface only.
 var p: Color=get_parent().modulate
 modulate=Color(1.0/maxf(p.r,0.1),1.0/maxf(p.g,0.1),1.0/maxf(p.b,0.1),1)
func highlight168a1(value: bool) -> void:
 if highlighted==value:return
 highlighted=value;queue_redraw()
func _draw() -> void:
 draw_style_box(_panel168a1(),Rect2(Vector2.ZERO,size))
func _panel168a1() -> StyleBoxFlat:
 var box:=StyleBoxFlat.new();box.bg_color=Color("101d2c");box.border_color=Color("80e9db") if highlighted else Color("68819a");box.set_border_width_all(2 if highlighted else 1);box.set_corner_radius_all(4)
 return box
