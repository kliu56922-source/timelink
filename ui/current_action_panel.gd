extends CanvasLayer
## Opens native inspection/selection only. It never commits a card or command.
var scene_ref: WeakRef
var analyzer=preload("res://battle/analysis/current_action_opportunities.gd").new()
var panel: PanelContainer
var scroll: ScrollContainer
var threat: Label
var limits: Label
var buttons: Array[Button]=[]
var current: Dictionary={}
var elapsed:=0.0
var reminded_turn:=-1
var markers: Control
var reminder: Label
func setup(s: Variant) -> void:
	name="CurrentActionPanel";layer=41;scene_ref=weakref(s)
	markers=Control.new();markers.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(markers);markers.draw.connect(draw_markers)
	panel=PanelContainer.new();add_child(panel)
	scroll=ScrollContainer.new();scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;panel.add_child(scroll)
	var column:=VBoxContainer.new();column.size_flags_horizontal=Control.SIZE_EXPAND_FILL;column.add_theme_constant_override("separation",8);scroll.add_child(column)
	var title:=Label.new();title.text="本回合可选机会";column.add_child(title)
	threat=Label.new();threat.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;threat.custom_minimum_size=Vector2(0,44);column.add_child(threat)
	for index in range(3):
		var button:=Button.new();button.custom_minimum_size=Vector2(0,66);button.add_theme_font_size_override("font_size",14);button.clip_text=true;column.add_child(button);buttons.append(button)
		button.pressed.connect(func():activate(index))
	limits=Label.new();limits.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;limits.custom_minimum_size=Vector2(0,54);limits.add_theme_font_size_override("font_size",12);column.add_child(limits)
	reminder=Label.new();reminder.hide();reminder.add_theme_font_size_override("font_size",12);add_child(reminder)
	s._end_turn_control._main_btn.pressed.connect(note_end_turn)
	refresh()
func _process(delta: float) -> void:
	elapsed+=delta
	if elapsed>=0.25:elapsed=0;refresh()
func refresh() -> void:
	var s: Variant=scene_ref.get_ref()
	if s==null:return
	current=analyzer.inspect(s)
	var occupied: bool=is_instance_valid(s._monster_command_menu) or s._detail_panel_slot.visible or s.get_node("IntegratedPlaytestTools").panel.visible
	for window: Window in [s._engineering_window,s._facility_window,s._fort_window]:occupied=occupied or window.visible
	panel.visible=not occupied and not s.battle_ended
	var dock: Rect2=s.focus_dock_rect();panel.position=dock.position;panel.size=dock.size
	threat.text="预告："+(current.threat if not current.threat.is_empty() else "当前未公开；不预判具体目标")
	threat.tooltip_text=threat.text
	for index in range(3):
		buttons[index].visible=index<current.rows.size()
		if index<current.rows.size():buttons[index].text=current.rows[index].text;buttons[index].tooltip_text=current.rows[index].text
	limits.text=str(current.reason) if not str(current.reason).is_empty() else "点击只查看，不会自动付款。
其他技能/驻防可从棋子菜单查看。"
	if not current.blocked.is_empty() and str(current.reason).is_empty():limits.text="限制："+str(current.blocked[0])+"\n其余操作可点棋子查看。"
	markers.visible=panel.visible;markers.queue_redraw()
	limits.tooltip_text="
".join(current.blocked)
	reminder.position=Vector2(dock.position.x,s.get_viewport_rect().size.y*0.83)
	reminder.visible=reminded_turn==s.context.turn_count and not s.battle_ended
func activate(index: int) -> void:
	var s: Variant=scene_ref.get_ref()
	if s==null or index<0 or index>=current.get("rows",[]).size():return
	var row: Dictionary=analyzer.resolve(s,current.rows[index])
	if row.is_empty():refresh();return
	var actor: CardData=analyzer.source(s,row)
	match row.kind:
		"hand":s.player_table._on_card_selected_detail(actor)
		"unit":s._open_monster_command_menu(actor)
		"od":s._begin_od_release_selection()
		"facility":s._open_facilities()
		"engineering":s._engineering_button.pressed.emit()
	refresh()
func note_end_turn() -> void:
	var s: Variant=scene_ref.get_ref()
	if s==null or reminded_turn==s.context.turn_count or not current.get("remind",false):return
	reminded_turn=s.context.turn_count;reminder.text="本回合仍可查看攻击或OD；
也可直接结束。";reminder.show()

func draw_markers() -> void:
	var s: Variant=scene_ref.get_ref()
	if s==null:return
	for unit: Dictionary in current.get("units",[]):
		var point: Vector2=s._project_tactical_cell_to_screen(unit.cell)+Vector2(-26,28)
		if not point.is_finite():continue
		var color:=Color(0.2,0.95,0.85) if unit.available else Color(0.7,0.7,0.72)
		markers.draw_circle(point,5,color)
		markers.draw_string(ThemeDB.fallback_font,point+Vector2(9,5),unit.label,HORIZONTAL_ALIGNMENT_LEFT,-1,12,color)
