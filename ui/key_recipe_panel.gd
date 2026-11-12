extends CanvasLayer
var scene_ref: WeakRef
var entry: Button
var entry_hint: Label
var _hint_elapsed:=0.0
var panel: PanelContainer
var title: Label
var summary: Label
var summary_scroll: ScrollContainer
var select_row: HBoxContainer
var confirm: Button
var fast: Button
var skip_button: Button
var close_button: Button
var direction:=""
var quote: Dictionary={}
var selecting:=false
var last_anchor:=Vector2i(-1,-1)
func s() -> Variant:return scene_ref.get_ref() if scene_ref!=null else null
func button(parent: Node,text: String,fn: Callable) -> Button:
	var b:=Button.new();b.text=text;b.add_theme_font_size_override("font_size",13);b.custom_minimum_size.y=30;b.pressed.connect(fn);parent.add_child(b);return b
func label(parent: Node,text: String) -> Label:
	var l:=Label.new();l.text=text;l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;l.add_theme_font_size_override("font_size",13);parent.add_child(l);return l
func setup(owner: Node) -> void:
	scene_ref=weakref(owner);name="KeyRecipePanel166A";layer=70
	entry=button(self,"连续展开 · 炉心阵地",open);entry.position=Vector2(16,198);entry.size=Vector2(248,30)
	entry.tooltip_text="手持燃芯使魔＋炉基座时，从这里一次展开整套阵地。"
	entry_hint=label(self,"");entry_hint.position=Vector2(16,234);entry_hint.size=Vector2(248,0)
	entry_hint.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var hint_style:=StyleBoxFlat.new();hint_style.bg_color=Color(0.025,0.045,0.07,0.92);hint_style.set_content_margin_all(5)
	entry_hint.add_theme_stylebox_override("normal",hint_style)
	panel=PanelContainer.new();add_child(panel)
	var style:=StyleBoxFlat.new();style.bg_color=Color("091724");style.border_color=Color("79f4de");style.set_border_width_all(1);style.set_content_margin_all(8);panel.add_theme_stylebox_override("panel",style)
	var box:=VBoxContainer.new();box.add_theme_constant_override("separation",6);panel.add_child(box)
	title=label(box,"炉心阵地 · 166A")
	select_row=HBoxContainer.new();box.add_child(select_row)
	button(select_row,"护臂侧",choose_direction.bind("arm"));button(select_row,"阀门侧",choose_direction.bind("valve"))
	summary_scroll=ScrollContainer.new();summary_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;summary_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;box.add_child(summary_scroll)
	summary=label(summary_scroll,"选择阵型→点棋盘主锚点→确认。");summary.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	confirm=button(box,"确认整套展开",submit)
	var actions:=HBoxContainer.new();box.add_child(actions)
	fast=button(actions,"加速×4",func():s().recipe166.accelerate())
	skip_button=button(actions,"跳过演出",func():s().recipe166.skip())
	var nav:=HBoxContainer.new();box.add_child(nav)
	button(nav,"返回首页",func():s().axis155_navigate("home"));button(nav,"重开",func():s().axis155_navigate("restart"))
	close_button=button(box,"取消预览 / 收起",dismiss)
	owner.recipe166.changed.connect(sync)
	owner.recipe166.committed.connect(func(r):summary.text="两张关键牌与整套费用已提交。\n热量%d→%d · 1指令 · 盾+3\n正在现场成阵；加速或跳过不撤销结果。"%[r.heat_before,r.heat_after])
	panel.hide();confirm.disabled=true;sync();refresh_hint()
func _process(delta: float) -> void:
	var owner: Variant=s()
	if not is_instance_valid(owner):return
	panel.position=owner.focus_dock_rect().position;panel.size=owner.focus_dock_rect().size
	entry.disabled=owner.recipe166.running or owner.battle_ended
	entry_hint.visible=not panel.visible and not owner.advance_panel165.panel.visible
	_hint_elapsed+=delta
	if _hint_elapsed>=0.25:_hint_elapsed=0.0;refresh_hint()
	if panel.visible:
		var old: Node=owner.get_node_or_null("CurrentActionPanel")
		if old!=null:old.hide()
		owner.advance_panel165.source_bar.hide()
	else:owner.advance_panel165.source_bar.show()
func refresh_hint() -> void:
	var owner: Variant=s()
	if not is_instance_valid(owner):return
	if owner.battle_ended:entry_hint.text="战斗结束，可返回首页或重开。";return
	if owner.battle.has_method("preparation_active166b") and owner.battle.preparation_active166b() and owner.battle.recipe166_snapshot().used>0:
		entry_hint.text="本场已展开 · 当前为部署回合\n可补充建造 / 防护 / 控压。\n点「部署完成 · 进入交战」，Boss先蓄压，之后再点单位进攻。";return
	var gate: String=owner.recipe166._gate()
	if not gate.is_empty():entry_hint.text="连续操作："+gate;return
	if owner.battle.recipe166_snapshot().used>0:
		var ready:=false
		var resting:=false
		for actor: CardData in owner.context.player.field:
			if owner.battle.advance_actor_status(actor).get("ok",false):ready=true
			if str(owner.battle.can_monster_attack(actor).get("reason","")).contains("刚登场"):resting=true
		entry_hint.text="本场已展开 · 每场一次\n"+("连续进攻：点棋子或上方单位按钮\n再选要害→路线→执行。" if ready else "新单位休整时不能进攻。\n结束回合，等下回合再点单位。" if resting else "点上方单位查看当前限制。\n无单位时，可先补充部署。")
		return
	var missing: Array[String]=[]
	if owner.battle.recipe166_key("P02")==null:missing.append("燃芯使魔")
	if owner.battle.recipe166_key("P05")==null:missing.append("炉基座")
	if not missing.is_empty():entry_hint.text="连续展开：缺少手牌「%s」\n凑齐燃芯使魔＋炉基座再点上方。"%"＋".join(missing);return
	entry_hint.text="手持燃芯使魔＋炉基座，可连续展开\n点上方→选阵型→点己方格→确认\n确认前预览整套布局与费用。"
func open() -> void:
	var owner: Variant=s();var reason: String=owner.recipe166._gate()
	if owner.recipe166.running:return
	owner.advance_panel165.dismiss();owner._close_monster_command_menu()
	panel.show();selecting=false;direction="";quote={};last_anchor=Vector2i(-1,-1)
	owner.recipe166.invalidate();owner.recipe_fx166.clear_preview()
	title.text="连续展开 1/3 · 选阵型"
	if owner.battle.recipe166_snapshot().used>0:
		title.text="连续展开 · 本场已完成"
		summary.text="本场已完成展开。每场一次，名额离场不退。点「完成 / 收起」，再点单位开始连续进攻。"
	elif not reason.is_empty():summary.text=reason
	else:summary.text="点上方「护臂侧」或「阀门侧」。\n决定炉基座与学徒在使魔的哪一侧。\n需手持两张关键牌：燃芯使魔＋炉基座；学徒自动生成，不需抽取。"
	summary_scroll.scroll_vertical=0
	sync()
func choose_direction(value: String) -> void:
	if s().recipe166.running:return
	direction=value;selecting=true;quote={};s().recipe166.invalidate();s().recipe_fx166.clear_preview()
	title.text="连续展开 2/3 · 点棋盘落点"
	summary.text="点己方第4或5行主锚点（建议3列4行）。\n三件构件各占一格；两侧各需一格空位。\n阵型决定建筑和学徒左右位置，仍由你选落点。"
	summary.text+="\n棋盘已标列/行；绿色圆点是当前合法主锚点（视角左右与列号相反，以格子标注为准）。"
	var anchors: Array[Vector2i]=[]
	for cell: Vector2i in s().battle.tactical_grid_rules.get_all_cells():
		if s().recipe166.preview(direction,cell).get("ok",false):anchors.append(cell)
	s().recipe_fx166.show_anchors(anchors)
	summary_scroll.scroll_vertical=0
	sync()
func choose_anchor(cell: Vector2i) -> void:
	if direction.is_empty() or s().recipe166.running:return
	last_anchor=cell
	summary_scroll.scroll_vertical=0
	quote=s().recipe166.prepare(direction,cell)
	var preview: Dictionary=quote.get("quote",quote)
	s().recipe_fx166.preview(preview)
	if not quote.get("ok",false):title.text="连续展开 2/3 · 调整落点";summary.text=str(quote.get("reason","落点不可用"))+"\n未支付；可改落点、换阵型或取消。";sync();return
	title.text="连续展开 3/3 · 检查后确认"
	var lines: Array[String]=[]
	for item: Dictionary in preview.layout:lines.append("%s：%d列%d行"%["衍生学徒1/2" if item.id=="D166_S01" else item.name,item.cell.x+1,item.cell.y+1])
	summary.text="\n".join(lines)+"\n消耗：关键牌×2＋1指令；负荷+2\n热%d→%d · 盾+3 · Depth→%d\n前场%d/%d · 建筑%d/2 · 本场1次\n替代单牌登场；不额外检索。\n新单位本回合不能移动/攻击。\n连线无额外数值，名额离场不退。"%[preview.heat_before,preview.heat_after,preview.depth_after,preview.front_after,preview.front_limit,preview.buildings_after]
	sync()
func pointer(point: Vector2) -> void:
	if not selecting:return
	var owner: Variant=s();var chosen:=Vector2i(-1,-1);var distance:=INF
	for cell: Vector2i in owner.battle.tactical_grid_rules.get_all_cells():
		var p: Vector2=owner._project_tactical_cell_to_screen(cell)
		if p.is_finite() and p.distance_to(point)<distance:distance=p.distance_to(point);chosen=cell
	if distance<55:choose_anchor(chosen)
func submit() -> void:
	if s().recipe166.running or quote.is_empty() or not quote.get("ok",false):return
	var q:=quote.duplicate(true);quote={};selecting=false;confirm.disabled=true;title.text="连续展开 · 正在成阵"
	var r: Dictionary=await s().recipe166.execute(q)
	if not is_instance_valid(s()):return
	title.text="连续展开 · 完成" if r.get("ok",false) else "连续展开 · 未完成"
	summary.text=("成阵完成：两个单位、一个炉基座。\n已付两张关键牌＋1指令，生成1/1。\n新单位本回合休整，不能移动/攻击。\n可继续其他操作，或点「结束回合」。\n下回合点棋子/左上单位按钮→选要害→选路线→执行，开始连续进攻。\n建筑主动仍需手动使用。" if r.get("ok",false) else str(r.get("reason","未提交")))
	if s().battle.has_method("preparation_active166b") and s().battle.preparation_active166b():summary.text=summary.text.replace("结束回合","部署完成 · 进入交战")
	sync()
func sync() -> void:
	var busy: bool=s().recipe166.running
	var used: bool=s().battle.recipe166_snapshot().used>0
	confirm.disabled=busy or quote.is_empty() or not quote.get("ok",false)
	select_row.visible=not busy and not used;confirm.visible=not busy and not used
	close_button.text="完成 / 收起" if used and not busy else "取消预览 / 收起"
	fast.visible=busy;skip_button.visible=busy;close_button.disabled=busy
func dismiss() -> void:
	if s().recipe166.running:return
	selecting=false;quote={};s().recipe166.invalidate();s().recipe_fx166.clear_preview();panel.hide()
func owns_pointer(p: Vector2) -> bool:return entry.get_global_rect().has_point(p) or (panel.visible and panel.get_global_rect().has_point(p))
