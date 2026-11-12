extends Node
const Model=preload("res://ui/hand_semantics_168a1.gd")
const Face=preload("res://ui/semantic_card_face_168a1.gd")
var owner_ref: WeakRef
var faces: Dictionary={}
var highlighted_uids: Array=[]
var entry_highlighted:=false
var detail_box: VBoxContainer
var detail_title: Label
var detail_cost: Label
var detail_state: Label
var detail_text: Label
var detail_full: Label
var _detail_hidden: Dictionary={}
var _entry_styles: Dictionary={}
var _focus_uid:=0
var _elapsed:=0.0
var _original_detail_fill:=0
func setup168a1(owner_scene: Node) -> void:
 owner_ref=weakref(owner_scene);name="HandSemantics168A1";process_priority=200
 _make_detail168a1();refresh168a1()
 s().player_table.card_detail_panel.reading_requested168a1.connect(_native_read_requested168a1)
func s():return owner_ref.get_ref() if owner_ref!=null else null
func _make_detail168a1() -> void:
 var box: VBoxContainer=s().player_table.card_detail_panel.get_node("ScrollContainer/VBoxContainer")
 _original_detail_fill=box.size_flags_horizontal
 detail_box=VBoxContainer.new();detail_box.name="SemanticDetail168A1";detail_box.mouse_filter=Control.MOUSE_FILTER_IGNORE;detail_box.add_theme_constant_override("separation",8);box.add_child(detail_box);box.move_child(detail_box,1);detail_box.hide()
 for field: String in ["detail_title","detail_cost","detail_state","detail_text","detail_full"]:
  var l:=Label.new();l.name=field;l.mouse_filter=Control.MOUSE_FILTER_IGNORE;l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;l.size_flags_horizontal=Control.SIZE_EXPAND_FILL;l.add_theme_font_size_override("font_size",14);detail_box.add_child(l);set(field,l)
 detail_title.add_theme_font_size_override("font_size",17)
 detail_cost.add_theme_color_override("font_color",Color("ffe5a2"))
 detail_state.add_theme_color_override("font_color",Color("80e9db"))
func _process(delta: float) -> void:
 if not is_instance_valid(s()):return
 _elapsed+=delta
 if _elapsed>=0.12:_elapsed=0;refresh168a1()
 _refresh_detail168a1();_refresh_highlights168a1()
func refresh168a1() -> void:
 var scene=s()
 if not is_instance_valid(scene):return
 var live: Dictionary={}
 for card: CardData in scene.context.player.hand:
  if not Model.recognized(card):continue
  var ui: CardUI=scene._live_hand_ui(card)
  if not is_instance_valid(ui) or ui.is_queued_for_deletion() or ui.get_display_mode()!=CardUI.CardDisplayMode.HAND:continue
  var uid: int=card.get_instance_id();live[uid]=true
  var face: Control=ui.get_node_or_null("SemanticFace168A1")
  if face==null:
   face=Face.new();ui.add_child(face)
   # Native signals and CardUI continue handling hover, selection and dragging.
   if not ui.card_hovered.is_connected(_hover168a1):ui.card_hovered.connect(_hover168a1)
   if not ui.card_unhovered.is_connected(_unhover168a1.bind(uid)):ui.card_unhovered.connect(_unhover168a1.bind(uid))
  faces[uid]=weakref(face)
  var old: Control=ui.get_node_or_null("HandFrameOverlay")
  if old!=null:old.hide()
  face.update168a1(Model.build(scene,card))
 for uid: int in faces.keys():
  var face: Control=faces[uid].get_ref()
  if not live.has(uid) or not is_instance_valid(face):
   if is_instance_valid(face):
    var ui: CardUI=face.get_parent()
    var old: Control=ui.get_node_or_null("HandFrameOverlay")
    if old!=null:old.visible=ui.get_display_mode()==CardUI.CardDisplayMode.HAND
    face.queue_free()
   faces.erase(uid)
 if not live.has(_focus_uid):_focus_uid=0
func _hover168a1(card: CardData) -> void:
 if is_instance_valid(card):_focus_uid=card.get_instance_id()
func _unhover168a1(uid: int) -> void:
 if _focus_uid==uid:_focus_uid=0
func _refresh_detail168a1() -> void:
 var scene=s();var table=scene.player_table;var panel: CardDetailPanel=table.card_detail_panel
 var card: CardData=panel.reading_card168a1()
 if not panel.visible or not Model.recognized(card) or card not in scene.context.player.hand:
  _release_detail168a1();return
 var face: Control=faces[card.get_instance_id()].get_ref() if faces.has(card.get_instance_id()) else null
 var facts: Dictionary=face.facts if is_instance_valid(face) else Model.build(scene,card)
 detail_box.get_parent().size_flags_horizontal=Control.SIZE_EXPAND_FILL
 if _detail_hidden.is_empty():
  scene._set_detail_panel_expanded(true,true,panel.is_detail_pinned_mode())
  for child: Control in detail_box.get_parent().get_children():
   if child==detail_box or child.name=="PreviewHintLabel":continue
   _detail_hidden[child.get_instance_id()]={"ref":weakref(child),"visible":child.visible}
 for data: Dictionary in _detail_hidden.values():
  var child: Control=data.ref.get_ref()
  if is_instance_valid(child):child.hide()
 detail_box.show();detail_title.text=facts.name+"\n"+facts.type+" · "+facts.role+(" · "+facts.stats if not facts.stats.is_empty() else "")
 detail_cost.text="单用："+facts.cost+" / "+facts.load+"\n指令与选位账单以原确认预览为准"
 detail_state.text="当前："+facts.status
 var text: String=facts.detail
 if not facts.combo.is_empty() and not panel.is_detail_pinned_mode():
  var d: Dictionary=scene.battle.recipe166_definition
  var single: String="登场检索炉心建筑；出场回合不能攻击。" if card.card_id=="P02" else "建成盾+3。每回合主动一次：优先2充能或2热→最早棋子+1/+1；无棋子，1热→下次Depth增长减免1。"
  text="单独使用："+single+"\n\n组合使用：与"+facts.combo.partner_name+"组成炉心阵地。点「连续展开」→阵型→锚点→确认。\n整套%d指令 / 负荷+%d，热+%d、盾+%d；独立池生成1学徒，保留容量/休整。本场限%d次，替代原登场/检索。\n%s\n\n可作为维护素材：交战后修补/替换，费用与目标见原预览。"%[d.command_cost,d.load_cost,d.heat_gain,d.shield_gain,d.per_battle_limit,facts.combo.text]
 detail_text.text=text
 detail_full.visible=panel.is_detail_pinned_mode();detail_full.text="完整原生说明\n"+facts.full if panel.is_detail_pinned_mode() else ""
func _native_read_requested168a1(card: CardData) -> void:
 # Release before native show_card populates its own labels. Never redraw a
 # cached hand card over graveyard/back-row/direct native requests.
 _release_detail168a1()
 if is_instance_valid(card):s()._set_detail_panel_expanded(true,true,s().player_table.card_detail_panel.is_detail_pinned_mode())
func _release_detail168a1() -> void:
 if not is_instance_valid(detail_box):return
 detail_box.hide()
 if _detail_hidden.is_empty():return
 for data: Dictionary in _detail_hidden.values():
  var child: Control=data.ref.get_ref()
  if is_instance_valid(child):child.visible=data.visible
 _detail_hidden.clear()
 detail_box.get_parent().size_flags_horizontal=_original_detail_fill
func _refresh_highlights168a1() -> void:
 var scene=s();var allow: bool=scene.axis155_native_ready() and not scene._has_non_presentation_end_turn_busy() and not scene._exit_modal_active and not scene.recipe_panel166.panel.visible and not scene.support_panel166c.panel.visible and not scene.advance_panel165.panel.visible
 var partner_uid:=0
 var key_focused:=false
 if allow and _focus_uid!=0:
  for card: CardData in scene.context.player.hand:
   if card.get_instance_id()!=_focus_uid or card.card_id not in ["P02","P05"]:continue
   var ui: CardUI=scene._live_hand_ui(card)
   if not is_instance_valid(ui) or ui._is_dragging:break
   key_focused=true
   var face: Control=faces[card.get_instance_id()].get_ref() if faces.has(card.get_instance_id()) else null
   if is_instance_valid(face):partner_uid=int(face.facts.combo.partner_uid)
 highlighted_uids.clear()
 for uid: int in faces.keys():
  var face: Control=faces[uid].get_ref()
  if not is_instance_valid(face):continue
  var on: bool=uid==partner_uid
  face.highlight168a1(on)
  if on:highlighted_uids.append(uid)
 _set_entry168a1(allow and key_focused)
func _set_entry168a1(on: bool) -> void:
 if on==entry_highlighted:return
 var entry: Button=s().recipe_panel166.entry
 if on:
  for key: String in ["normal","hover"]:
   _entry_styles[key]=entry.get_theme_stylebox(key) if entry.has_theme_stylebox_override(key) else null
   var box:=StyleBoxFlat.new();box.bg_color=Color("12362f");box.border_color=Color("80e9db");box.set_border_width_all(2);box.set_corner_radius_all(4);box.set_content_margin_all(4);entry.add_theme_stylebox_override(key,box)
 else:
  for key: String in _entry_styles:
   if _entry_styles[key]!=null:entry.add_theme_stylebox_override(key,_entry_styles[key])
   else:entry.remove_theme_stylebox_override(key)
  _entry_styles.clear()
 entry_highlighted=on
