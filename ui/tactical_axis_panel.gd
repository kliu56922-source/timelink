extends CanvasLayer
## Greybox: one explicit preview/authorization; no default target is silently submitted.
var _scene: WeakRef
var panel: PanelContainer
var toggle: Button
var shield: Control
var mode: OptionButton
var build_cell: OptionButton
var unit_cell: OptionButton
var facility: OptionButton
var actor: OptionButton
var verb: OptionButton
var target: OptionButton
var preview_button: Button
var confirm_button: Button
var stop_button: Button
var text: Label
var quote: Dictionary={}
func setup(scene: Node) -> void:
	_scene=weakref(scene);layer=120
	shield=Control.new();shield.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);shield.mouse_filter=Control.MOUSE_FILTER_STOP;add_child(shield);shield.hide()
	toggle=Button.new();toggle.text="小轴155 · 选择与预览";toggle.position=Vector2(16,160);add_child(toggle)
	panel=PanelContainer.new();panel.position=Vector2(22,195);panel.custom_minimum_size=Vector2(440,0);add_child(panel)
	var backdrop:=StyleBoxFlat.new();backdrop.bg_color=Color(0.035,0.045,0.055,0.95);panel.add_theme_stylebox_override("panel",backdrop)
	var col:=VBoxContainer.new();panel.add_child(col)
	var heading:=Label.new();heading.text="小轴灰盒 · 目标由你决定，原费用不变\n仅155测试牌序：炉基座提前入起手，总牌数不变";col.add_child(heading)
	mode=_picker(col);mode.add_item("建立阵地：炉基座 → 锅炉学徒");mode.add_item("冷却后行动：完工热沉 → 单位行动")
	build_cell=_cells(col,"建筑落点");unit_cell=_cells(col,"学徒落点")
	facility=_picker(col);actor=_picker(col);verb=_picker(col);verb.add_item("移动");verb.add_item("普通攻击棋子")
	target=_cells(col,"行动目标格")
	text=Label.new();text.custom_minimum_size=Vector2(430,100);text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;col.add_child(text)
	var actions:=HBoxContainer.new();col.add_child(actions)
	preview_button=_button(actions,"预览",_preview);confirm_button=_button(actions,"确认执行",_execute);stop_button=_button(actions,"停止后续",func():scene.axis155.stop())
	_button(actions,"关闭",func():panel.hide())
	var nav:=HBoxContainer.new();col.add_child(nav);_button(nav,"返回首页",func():scene.axis155_navigate("home"));_button(nav,"重开本局",func():scene.axis155_navigate("restart"))
	toggle.pressed.connect(func():panel.visible=not panel.visible;if panel.visible:_refresh_sources();_invalidate())
	for picker: OptionButton in [mode,build_cell,unit_cell,facility,actor,verb,target]:picker.item_selected.connect(func(_i):_invalidate())
	scene.axis155.changed.connect(_sync);scene.axis155.step_finished.connect(func(i,r):text.text="第%d步%s：热量%+d / 指令%d / Depth %d→%d。\n已提交的动作不回滚。"%[i+1,"完成" if r.ok else "未执行",r.heat_delta,r.command_spent,r.depth_before,r.depth_after])
	panel.hide();_refresh_sources();_invalidate()
func _picker(parent: Node) -> OptionButton:
	var p:=OptionButton.new();parent.add_child(p);return p
func _cells(parent: Node,label_text: String) -> OptionButton:
	var p:=_picker(parent);p.add_item(label_text+"：请选择");p.set_item_metadata(0,Vector2i(-1,-1))
	for y in range(5):
		for x in range(5):p.add_item("%s：第%d列 第%d行"%[label_text,x+1,y+1]);p.set_item_metadata(p.item_count-1,Vector2i(x,y))
	return p
func _button(parent: Node,label_text: String,callback: Callable) -> Button:
	var b:=Button.new();b.text=label_text;parent.add_child(b);b.pressed.connect(callback);return b
func _refresh_sources() -> void:
	var s: Variant=_scene.get_ref();facility.clear();actor.clear();facility.add_item("请选择完工热沉");facility.set_item_metadata(0,0);actor.add_item("请选择已有单位");actor.set_item_metadata(0,0)
	for c: CardData in s.context.player.traps:
		if c.card_id=="P13":
			var body: Dictionary=s.context.tactical_structure_board_state.get_foundation_status(s.context.tactical_structure_board_state.get_source_structure_id(c.get_instance_id()))
			var cell: Vector2i=body.get("cell",Vector2i(-1,-1))
			facility.add_item("%s · 第%d列 第%d行"%[c.get_display_name(),cell.x+1,cell.y+1]);facility.set_item_metadata(facility.item_count-1,c.get_instance_id())
	for c: CardData in s.context.player.field:
		var cell: Vector2i=s.battle.get_unit_cell(c)
		actor.add_item("%s · 第%d列 第%d行"%[c.get_display_name(),cell.x+1,cell.y+1]);actor.set_item_metadata(actor.item_count-1,c.get_instance_id())
func _invalidate() -> void:
	quote={};confirm_button.disabled=true;text.text="先选择位置/来源，再预览。尚未支付。\n普通OD、升格、合体和新检索牌仍由你手动决定。"
	var cold:=mode.selected==1
	build_cell.visible=not cold;unit_cell.visible=not cold
	for p: Control in [facility,actor,verb,target]:p.visible=cold
func _preview() -> void:
	var s: Variant=_scene.get_ref()
	if s.axis155.running:return
	if mode.selected==0:quote=s.axis155.prepare_establish(build_cell.get_selected_metadata(),unit_cell.get_selected_metadata())
	else:quote=s.axis155.prepare_cooling(s.axis155.resolve(int(facility.get_selected_metadata()),"traps"),s.axis155.resolve(int(actor.get_selected_metadata()),"field"),"move" if verb.selected==0 else "attack",target.get_selected_metadata())
	confirm_button.disabled=not quote.get("ok",false)
	if not quote.get("ok",false):text.text=str(quote.get("reason","请选择完整参数"));return
	text.text=quote.title+"：仅两步，按原费用逐步执行。\n"
	if mode.selected==0:text.text+="炉基座按原普通支付 → 学徒登场。检索后停，刚登场不能免费行动。"
	else:text.text+="热沉：%s；随后指令%d点，未冷却报价Depth %d→%d（实际重验，减免按原规则）。"%[quote.quotes[0].native.cost,quote.max_command,quote.signature.depth,quote.max_depth]
	text.text+="\n目标不改选；局面变化将停下，不自动结束回合。"
func _execute() -> void:
	var s: Variant=_scene.get_ref();confirm_button.disabled=true
	var result: Dictionary=await s.axis155.execute(quote)
	text.text="%s；已完成%d步。%s"%["小轴完成，交回控制" if result.get("ok",false) else "已停止",result.get("receipts",[]).size(),result.get("reason","")]
	var names: Dictionary={"build":"建造","summon":"登场","facility":"热沉","move":"移动","attack":"攻击"}
	for receipt: Dictionary in result.get("receipts",[]):text.text+="\n%s：热量%+d / 指令%d / Depth %d→%d"%[names.get(receipt.kind,"动作"),receipt.heat_delta,receipt.command_spent,receipt.depth_before,receipt.depth_after]
	quote={};_refresh_sources();_sync()
func _sync() -> void:
	var s: Variant=_scene.get_ref()
	if not is_instance_valid(s):return
	var busy: bool=s.axis155.running;shield.visible=busy;stop_button.disabled=not busy;preview_button.disabled=busy;toggle.disabled=busy
	if busy:panel.show()
	for p: OptionButton in [mode,build_cell,unit_cell,facility,actor,verb,target]:p.disabled=busy
