extends "res://ui/tactical_axis_panel.gd"
## 156 keeps the existing quote/commit authority. Only selection and display change.
var entry_buttons: Dictionary={}
var cell_buttons: Dictionary={}
var source_buttons: Array[Button]=[]
var progress: PanelContainer
var progress_text: Label
var progress_stop: Button
var progress_close: Button
var entry_bar: HBoxContainer
var source_box: VBoxContainer
var quick_box: VBoxContainer
var build_slot: Button
var unit_slot: Button
var target_slot: Label
var _slot:="build"
var _revision:=0
var _quick_ready:=false
func setup(scene: Node) -> void:
	super.setup(scene)
	var col: VBoxContainer=text.get_parent()
	(col.get_child(0) as Label).text="小轴156 · 选齐后显示预览，确认后看行动\n测试牌序沿155，原19牌与费用不变"
	entry_bar=HBoxContainer.new();entry_bar.position=Vector2(16,160);add_child(entry_bar)
	for key: String in ["establish","move","attack"]:
		var title: String={"establish":"建立阵地","move":"冷却后移动","attack":"冷却后攻击"}[key]
		entry_buttons[key]=_button(entry_bar,title,open_axis.bind(key))
	quick_box=VBoxContainer.new();col.add_child(quick_box);col.move_child(quick_box,1)
	source_box=VBoxContainer.new();quick_box.add_child(source_box)
	var slots:=HBoxContainer.new();quick_box.add_child(slots)
	build_slot=_button(slots,"建筑：未选",func():_slot="build";_refresh_marks())
	unit_slot=_button(slots,"学徒：未选",func():_slot="unit";_refresh_marks())
	target_slot=Label.new();quick_box.add_child(target_slot)
	var grid:=GridContainer.new();grid.columns=5;quick_box.add_child(grid)
	for y in range(5):
		for x in range(5):
			var cell:=Vector2i(x,y)
			var b:=_button(grid,"%d列·%d行"%[x+1,y+1],_pick_cell.bind(cell))
			b.add_theme_font_size_override("font_size",12);b.custom_minimum_size=Vector2(76,25);cell_buttons[cell]=b
	progress=PanelContainer.new();progress.position=Vector2(16,195);progress.custom_minimum_size=Vector2(440,0);add_child(progress)
	var style:=StyleBoxFlat.new();style.bg_color=Color(0.035,0.045,0.055,0.95);progress.add_theme_stylebox_override("panel",style)
	var body:=VBoxContainer.new();progress.add_child(body)
	progress_text=Label.new();progress_text.custom_minimum_size=Vector2(430,65);progress_text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;body.add_child(progress_text)
	var controls:=HBoxContainer.new();body.add_child(controls)
	progress_stop=_button(controls,"停止后续",func():scene.axis155.stop())
	_button(controls,"返回首页",func():scene.axis155_navigate("home"))
	_button(controls,"重开本局",func():scene.axis155_navigate("restart"))
	progress_close=_button(controls,"收起",func():progress.hide())
	scene.axis155.step_finished.connect(func(i,r):progress_text.text="%d/2步完成 · %s\n热量%+d / 指令%d / Depth %d→%d"%[i+1,"继续已选行动" if r.ok else "未提交",r.heat_delta,r.command_spent,r.depth_before,r.depth_after])
	_quick_ready=true;toggle.hide();preview_button.hide();progress.hide();panel.hide();_invalidate();_sync()
func open_axis(axis: String) -> void:
	var s: Variant=_scene.get_ref()
	if s.axis155.running:return
	progress.hide();mode.select(0 if axis=="establish" else 1);verb.select(1 if axis=="attack" else 0)
	_refresh_sources();build_cell.select(0);unit_cell.select(0);target.select(0)
	_slot="build" if axis=="establish" else "target"
	_rebuild_sources();panel.show();_invalidate()
func _rebuild_sources() -> void:
	for child: Node in source_box.get_children():source_box.remove_child(child);child.queue_free()
	source_buttons.clear()
	if mode.selected==0:return
	for group: String in ["facility","actor"]:
		var picker: OptionButton=facility if group=="facility" else actor
		var heading:=Label.new();heading.text="点选热沉来源" if group=="facility" else "点选行动单位";source_box.add_child(heading)
		var list:=GridContainer.new();list.columns=2;source_box.add_child(list)
		for i in range(1,picker.item_count):
			var b:=_button(list,picker.get_item_text(i),_pick_source.bind(group,i))
			b.add_theme_font_size_override("font_size",12);b.toggle_mode=true;b.set_meta("group",group);b.set_meta("uid",picker.get_item_metadata(i));source_buttons.append(b)
		if picker.item_count<=1:
			var empty:=Label.new();empty.text="没有来源；需按原玩法准备，原型不补单位或设施。";empty.add_theme_font_size_override("font_size",12);source_box.add_child(empty)
func _pick_source(group: String,index: int) -> void:
	var s: Variant=_scene.get_ref()
	if s.axis155.running:return
	var picker: OptionButton=facility if group=="facility" else actor
	picker.select(index);picker.item_selected.emit(index)
func _pick_cell(cell: Vector2i) -> void:
	var s: Variant=_scene.get_ref()
	if s.axis155.running:return
	var picker: OptionButton=build_cell if _slot=="build" else (unit_cell if _slot=="unit" else target)
	for i in range(picker.item_count):
		if picker.get_item_metadata(i)==cell:
			picker.select(i)
			if _slot=="build":_slot="unit"
			picker.item_selected.emit(i);return
func _cell_text(picker: OptionButton) -> String:
	var cell: Vector2i=picker.get_selected_metadata()
	return "未选" if cell.x<0 else "%d列%d行"%[cell.x+1,cell.y+1]
func _refresh_marks() -> void:
	if not _quick_ready:return
	var cold: bool=mode.selected==1
	build_slot.visible=not cold;unit_slot.visible=not cold;target_slot.visible=cold
	build_slot.text="建筑："+_cell_text(build_cell);unit_slot.text="学徒："+_cell_text(unit_cell)
	target_slot.text=("攻击目标：" if verb.selected==1 else "移动落点：")+_cell_text(target)
	build_slot.modulate=Color(1,0.8,0.45) if _slot=="build" else Color.WHITE
	unit_slot.modulate=Color(1,0.8,0.45) if _slot=="unit" else Color.WHITE
	for cell: Vector2i in cell_buttons:
		var selected: bool=cell==target.get_selected_metadata() if cold else cell in [build_cell.get_selected_metadata(),unit_cell.get_selected_metadata()]
		cell_buttons[cell].modulate=Color(0.4,1,0.95) if selected else Color.WHITE
	for b: Button in source_buttons:
		var picker: OptionButton=facility if b.get_meta("group")=="facility" else actor
		b.button_pressed=int(b.get_meta("uid"))==int(picker.get_selected_metadata())
func _invalidate() -> void:
	if _quick_ready and not quote.is_empty():
		var s: Variant=_scene.get_ref()
		if is_instance_valid(s) and not s.axis155.running:s.axis155.stop("方案已调整")
	super._invalidate()
	for picker: OptionButton in [mode,build_cell,unit_cell,facility,actor,verb,target]:picker.hide()
	preview_button.hide()
	if not _quick_ready:return
	_refresh_marks();_revision+=1;_preview_selected.call_deferred(_revision)
func _preview_selected(revision: int) -> void:
	var s: Variant=_scene.get_ref()
	if not is_instance_valid(s) or s.axis155.running or revision!=_revision or not panel.visible:return
	var complete: bool=build_cell.selected>0 and unit_cell.selected>0 if mode.selected==0 else facility.selected>0 and actor.selected>0 and target.selected>0
	if complete:super._preview()
func _execute() -> void:
	var s: Variant=_scene.get_ref()
	var old_hand: Array=s.context.player.hand.map(func(c):return c.get_instance_id())
	progress_text.text="0/2步 · 执行已确认的小轴\n完成当前动作后可停止；不自动结束回合。"
	confirm_button.disabled=true
	var result: Dictionary=await s.axis155.execute(quote)
	quote={};_refresh_sources();_sync()
	var heat:=0;var points:=0
	for receipt: Dictionary in result.get("receipts",[]):heat+=int(receipt.heat_delta);points+=int(receipt.command_spent)
	progress_text.text="%s · %d/2步\n热量%+d / 指令%d / Depth %d；%s"%["小轴完成，交回控制" if result.get("ok",false) else "小轴已停",result.get("receipts",[]).size(),heat,points,s.context.depth_pressure,result.get("reason","")]
	var new_cards: Array=[]
	for c: CardData in s.context.player.hand:
		if c.get_instance_id() not in old_hand:new_cards.append(c.get_display_name())
	if not new_cards.is_empty():progress_text.text+="\n新牌："+"、".join(new_cards)+"（由你决定是否使用）"
	panel.hide();progress.show();_sync()
func _sync() -> void:
	super._sync()
	if not _quick_ready:return
	var s: Variant=_scene.get_ref();var busy: bool=s.axis155.running
	toggle.hide();preview_button.hide();entry_bar.visible=not busy
	for picker: OptionButton in [mode,build_cell,unit_cell,facility,actor,verb,target]:picker.hide()
	for b: Button in source_buttons:b.disabled=busy
	for b: Button in cell_buttons.values():b.disabled=busy
	build_slot.disabled=busy;unit_slot.disabled=busy;progress_stop.disabled=not busy;progress_close.disabled=busy
	if busy:panel.hide();progress.show()
