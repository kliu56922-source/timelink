extends Control
## Functional, non-modal suggestions. Highlight controls pass all pointer input through.
var scene_ref: WeakRef
var coach=preload("res://battle/analysis/live_play_coach.gd").new()
var advisor=preload("res://battle/analysis/card_relation_advisor.gd").new()
var mode: StringName=&"teaching"
var teaching_allowed := true
var relation_view: Dictionary={}
var _mode_picker: OptionButton
var _hover_candidate: CardData
var _hover_started := 0
var _hover_grace_until := 0
var _pointer_position: Variant=null
var enabled := true
var current_hint: Dictionary={}
var markers: Array[Rect2]=[]
var source_marker_count := 0
var _panel: PanelContainer
var _toggle: Button
var _text: Label
var _progress: Label
var _clock := 0.0
func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	z_index=105
	_panel=PanelContainer.new();_panel.position=Vector2(18,290);_panel.size=Vector2(280,242)
	var style := StyleBoxFlat.new();style.bg_color=Color(0.025,0.04,0.065,1);style.content_margin_left=10;style.content_margin_right=10;style.content_margin_top=8;style.content_margin_bottom=8
	_panel.add_theme_stylebox_override("panel",style);add_child(_panel)
	_panel.add_to_group("card_relation_hint_panel")
	var column := VBoxContainer.new();column.add_theme_constant_override("separation",6);_panel.add_child(column)
	var heading := HBoxContainer.new();column.add_child(heading)
	_toggle=Button.new();_toggle.text="教学 · 收起" if mode==&"teaching" else "联想 · 收起";_toggle.add_theme_font_size_override("font_size",15);_toggle.size_flags_horizontal=Control.SIZE_EXPAND_FILL;heading.add_child(_toggle)
	_toggle.pressed.connect(func():set_enabled(not enabled))
	_mode_picker=OptionButton.new();_mode_picker.add_theme_font_size_override("font_size",14)
	if teaching_allowed:_mode_picker.add_item("教学引导",0)
	_mode_picker.add_item("选牌联想",1);heading.add_child(_mode_picker)
	_mode_picker.select(0 if mode==&"teaching" or not teaching_allowed else 1)
	_mode_picker.item_selected.connect(func(index:int):set_mode(&"teaching" if _mode_picker.get_item_id(index)==0 else &"related"))
	_progress=Label.new();_progress.add_theme_font_size_override("font_size",12);_progress.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;column.add_child(_progress)
	var scroll := ScrollContainer.new();scroll.custom_minimum_size=Vector2(260,176);scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;column.add_child(scroll)
	_text=Label.new();_text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;_text.custom_minimum_size=Vector2(248,0);_text.size_flags_horizontal=Control.SIZE_EXPAND_FILL;_text.add_theme_font_size_override("font_size",16);scroll.add_child(_text)
	refresh()
func set_enabled(value: bool) -> void:
	enabled=value
	if not value:_hover_candidate=null;_hover_grace_until=0
	_toggle.text=("教学" if mode==&"teaching" else "联想")+(" · 收起" if enabled else " · 开启")
	_progress.visible=enabled
	_text.get_parent().visible=enabled
	_panel.size=Vector2(280,242 if enabled else 34)
	refresh()
func set_mode(value: StringName) -> void:
	if value not in [&"teaching",&"related"] or (value==&"teaching" and not teaching_allowed):return
	mode=value;_hover_candidate=null;_hover_started=0;_hover_grace_until=0
	if is_instance_valid(_mode_picker):_mode_picker.select(0 if value==&"teaching" or not teaching_allowed else 1)
	set_enabled(enabled)
func focus_card() -> CardData:
	var s=scene_ref.get_ref() if scene_ref!=null else null
	if not is_instance_valid(s):return null
	if s._is_monster_summon_interaction_active():
		var card: Variant=s._monster_drag_session.get("card")
		return _selection_focus(card)
	if s._is_piece_selection_active():
		var card: Variant=s._piece_context.get("card")
		return _selection_focus(card)
	if s._is_lane_selection_active():return _selection_focus(s._lane_selection_card)
	if is_instance_valid(s._selected_attacker):return _selection_focus(s._selected_attacker)
	if is_instance_valid(s._structure_interaction_presenter):
		var details: Dictionary=s._structure_interaction_presenter.get_debug_snapshot()
		if details.get("panel_visible",false):
			var structure: Dictionary=s.battle.get_structure_snapshot().get("structures",{}).get(details.get("target_ref",{}).get("structure_id",&""),{})
			for card: CardData in s.context.player.traps:
				if is_instance_valid(card) and card.get_instance_id()==int(structure.get("source_runtime_id",-1)):return card
	if s.player_table==null:return null
	var card: Variant=s.player_table._detail_preview_card
	if card==null:
		if is_instance_valid(_hover_candidate) and current_hint.get("card")==_hover_candidate and (Time.get_ticks_msec()<_hover_grace_until or _pointer_over_panel()):return _hover_candidate
		_hover_candidate=null;return null
	if not is_instance_valid(card):_hover_candidate=null;return null
	if s.player_table.is_detail_pinned():return card
	if card!=_hover_candidate:_hover_candidate=card;_hover_started=Time.get_ticks_msec()
	if Time.get_ticks_msec()-_hover_started<350:return null
	_hover_grace_until=Time.get_ticks_msec()+900
	return card
func _selection_focus(card: Variant) -> CardData:
	_hover_candidate=null;_hover_grace_until=0
	return card if is_instance_valid(card) else null
func _pointer_over_panel() -> bool:
	var point: Vector2=get_global_mouse_position() if _pointer_position==null else _pointer_position
	return is_instance_valid(_panel) and _panel.is_visible_in_tree() and _panel.get_global_rect().has_point(point)
func _input(event: InputEvent) -> void:
	if event is InputEventMouse:_pointer_position=event.position
func _process(delta: float) -> void:
	_clock+=delta
	if _clock>=0.25:_clock=0;refresh()
func refresh() -> void:
	markers.clear()
	source_marker_count=0
	var s=scene_ref.get_ref() if scene_ref!=null else null
	if s==null or not is_instance_valid(s):queue_redraw();return
	if not enabled:queue_redraw();return
	if mode==&"related":_refresh_relations(s);return
	_panel.size=Vector2(280,242);_progress.visible=true;_text.get_parent().visible=true
	current_hint=coach.get_hint(s)
	_progress.text=current_hint.get("progress","")
	_text.text="%s\n\n%s\n\n%s" % [current_hint.title,current_hint.how,current_hint.why]
	var card: CardData=current_hint.get("card")
	if card!=null:
		var source: CardUI=s._live_hand_ui(card)
		if is_instance_valid(source):markers.append(source.get_global_rect().grow(4))
	var actor: CardData=current_hint.get("actor")
	if actor!=null:_mark_cell(s,s.battle.get_unit_cell(actor))
	source_marker_count=markers.size()
	var target: Variant=current_hint.get("target")
	if target is CardData and current_hint.kind!=&"ascend":_mark_cell(s,s.battle.get_unit_cell(target))
	elif target is Vector2i:_mark_cell(s,target)
	if current_hint.has("cell"):_mark_cell(s,current_hint.cell)
	if current_hint.kind==&"reward" and is_instance_valid(s._od_release_control):markers.append(s._od_release_control._final_button.get_global_rect().grow(4))
	if current_hint.kind==&"od" and is_instance_valid(s._od_release_control):markers.append(s._od_release_control._button.get_global_rect().grow(4))
	if current_hint.kind==&"end_turn" and is_instance_valid(s._end_turn_control):markers.append(s._end_turn_control.get_global_rect().grow(4))
	queue_redraw()
func _refresh_relations(s: Variant) -> void:
	relation_view=advisor.get_relations(s,focus_card())
	var card: CardData=relation_view.get("focus")
	current_hint={"kind":&"related_idle" if card==null else &"related","card":card,"title":"卡牌联想","how":"","why":""}
	_progress.visible=false;_text.get_parent().visible=card!=null
	_panel.size=Vector2(280,242 if card!=null else 34)
	_toggle.tooltip_text="选中或停留一张卡，查看当前可见的配合；蓝框表示关联。"
	if card==null:queue_redraw();return
	var lines: Array[String]=[card.get_display_name()+" · 关联"]
	if relation_view.has("od_window"):
		lines.append(str(relation_view.od_window.text))
	if relation_view.has("focus_status"):
		var status: Dictionary=relation_view.focus_status
		lines.append("主动接口："+str(status.get("preview","可检查费用与目标")) if status.get("ok",false) else "主动接口："+str(status.get("reason","当前不可用")))
	if relation_view.suppressed:lines.append("当前正在结算或不在己方行动窗口；稍后重查。")
	elif relation_view.items.is_empty():lines.append("当前可见牌里没有明确配合；可直接查看这张牌的效果。")
	else:
		var states := {&"ready":"现在可配合",&"blocked":"当前不可用",&"prepare":"还需准备",&"present":"已有关系"}
		var zones := {&"hand":"手牌",&"field":"场上",&"back":"后场",&"arsenal":"武库"}
		for row: Dictionary in relation_view.items:
			lines.append("%s · %s / %s\n%s\n%s" % [row.card.get_display_name(),zones.get(row.zone,""),states.get(row.state,"已有关系"),row.effect,row.reason])
			var ui: CardUI=s._live_hand_ui(row.card)
			if is_instance_valid(ui):markers.append(ui.get_global_rect().grow(3))
	_text.text="\n\n".join(lines)
	queue_redraw()
func _mark_cell(s: Variant,cell: Vector2i) -> void:
	var point: Vector2=s._project_tactical_cell_to_screen(cell)
	if point.is_finite():markers.append(Rect2(point-Vector2(42,24),Vector2(84,48)))
func _draw() -> void:
	for index in range(markers.size()):
		var rect := markers[index]
		var source := index<source_marker_count
		var color := Color(0.4,0.75,1) if mode==&"related" else Color(1,0.87,0.35) if source else Color(0.3,1,0.65)
		draw_rect(rect,color,false,3)
		draw_string(ThemeDB.fallback_font,rect.position+Vector2(2,-5),"关联" if mode==&"related" else "操作这里" if source else "推荐目标",HORIZONTAL_ALIGNMENT_LEFT,-1,14,color)
func reserved_rect() -> Rect2:
	return _panel.get_global_rect().grow(6) if is_instance_valid(_panel) else Rect2()
