extends "res://ui/key_recipe_panel.gd"
var sources: HBoxContainer
var modes: HBoxContainer
var source_uid:=0
var mode:=""
func setup(owner: Node) -> void:
	scene_ref=weakref(owner);name="MaintenancePanel166C";layer=71
	entry=owner.recipe_panel166.entry;entry_hint=owner.recipe_panel166.entry_hint
	panel=PanelContainer.new();add_child(panel)
	var style:=StyleBoxFlat.new();style.bg_color=Color("091724");style.border_color=Color("79f4de");style.set_border_width_all(1);style.set_content_margin_all(8);panel.add_theme_stylebox_override("panel",style)
	var body:=VBoxContainer.new();panel.add_child(body)
	title=label(body,"连续维护")
	sources=HBoxContainer.new();body.add_child(sources)
	for id: String in ["P02","P05"]:
		button(sources,"燃芯使魔" if id=="P02" else "炉基座",func():
			var c: CardData=s().battle.recipe166_key(id)
			choose_source(c.get_instance_id() if c!=null else 0))
	modes=HBoxContainer.new();body.add_child(modes)
	button(modes,"修复友军",func():choose_mode("repair"));button(modes,"补回学徒",func():choose_mode("replace"))
	summary_scroll=ScrollContainer.new();summary_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;summary_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;body.add_child(summary_scroll)
	summary=label(summary_scroll,"");summary.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	confirm=button(body,"确认维护 · 全额结算",submit)
	var playback:=HBoxContainer.new();body.add_child(playback)
	fast=button(playback,"×4 加速",func():s().support166c.accelerate());skip_button=button(playback,"跳过演出",func():s().support166c.skip())
	close_button=button(body,"取消预览 / 收起",dismiss)
	panel.hide();sync()
func _process(_delta: float) -> void:
	var owner: Variant=s()
	if not is_instance_valid(owner):return
	panel.position=owner.focus_dock_rect().position;panel.size=owner.focus_dock_rect().size
	entry.disabled=owner.support166c.running or owner.recipe166.running or owner.battle_ended
	var used: bool=owner.battle.recipe166_snapshot().used>0
	var maintenance: bool=used and not owner.battle.preparation_active166b()
	entry.text="连续操作 · 维护已有场面" if maintenance else "连续展开 · 本场已完成" if used else "连续展开 · 炉心阵地"
	entry.tooltip_text="交战维护：消耗燃芯使魔或炉基座任意一张手牌，选择修复或补位与目标，再预览费用并确认。" if maintenance else "本场已展开；部署完成进入交战后，这里可维护已有场面。" if used else "手持燃芯使魔＋炉基座时，从这里一次展开整套阵地；也可在面板选择维护已有单位。"
	if maintenance:
		var quota: Dictionary=owner.battle.support166_snapshot()
		entry_hint.text="已有场面作战：点棋子选要害与路线。\n需要恢复？点上方维护→素材→用途→落点→确认。\n本场维护%d/2 · 补学徒%d/1；每回合最多一次。"%[quota.used,quota.replacements]
	entry_hint.visible=not panel.visible and not owner.recipe_panel166.panel.visible and not owner.advance_panel165.panel.visible
	if panel.visible:
		owner.advance_panel165.source_bar.hide()
		var old: Node=owner.get_node_or_null("CurrentActionPanel")
		if old!=null:old.hide()
func open() -> void:
	var owner: Variant=s()
	if owner.support166c.running:return
	owner.recipe_panel166.dismiss();owner.advance_panel165.dismiss();owner._close_monster_command_menu()
	quote={};source_uid=0;mode="";selecting=false;last_anchor=Vector2i(-1,-1);owner.support166c.invalidate();owner.support_fx166c.clear_preview()
	panel.show();title.text="连续维护 1/4 · 选素材"
	summary.text="消耗手中燃芯使魔或炉基座，选择一种维护。\n修复：已有受伤友军最多+2HP，不刷新行动。\n补位：原学徒离场后补回一个1/2学徒；本回合休整。\n每次1指令、热+2、负荷+1，无检索/抽牌。每回合一次、本场两次，补位最多一次。"
	if owner.battle.preparation_active166b():summary.text="首回合先部署；维护在交战后启用。\n可取消返回展开，或部署完成进入交战。"
	refresh_sources166c();sync()
func refresh_sources166c() -> void:
	var index:=0
	for id: String in ["P02","P05"]:
		var count:=0
		for c: CardData in s().context.player.hand:
			if c.card_id==id:count+=1
		var b: Button=sources.get_child(index);b.text=("燃芯使魔" if id=="P02" else "炉基座")+" ×%d"%count;b.disabled=count==0 or s().battle.preparation_active166b();index+=1
func choose_source(uid: int) -> void:
	if s().support166c.running:return
	source_uid=uid;invalidate166c();title.text="连续维护 2/4 · 选用途";summary.text="素材已经选定。点「修复友军」或「补回学徒」。\n素材将转为维护效果，不额外登场、建造或检索。";sync()
func choose_mode(value: String) -> void:
	if s().support166c.running:return
	mode=value;selecting=true;invalidate166c();title.text="连续维护 3/4 · 选目标";summary.text="点棋盘上的受伤友方单位，最多修复2HP；不修复建筑/核心。" if value=="repair" else "点己方第4/5行空格。仅在原衍生学徒离场后补回一个，保留休整。"
	var legal: Array[Vector2i]=[]
	for cell: Vector2i in s().battle.tactical_grid_rules.get_all_cells():
		if s().support166c.preview(mode,source_uid,cell).get("ok",false):legal.append(cell)
	s().support_fx166c.show_anchors(legal)
	if legal.is_empty():
		var status: Dictionary=s().support166c.preview(mode,source_uid,Vector2i(0,4))
		summary.text+="\n当前没有合法目标："+str(status.get("reason","请检查目标"))
	sync()
func invalidate166c() -> void:
	quote={};s().support166c.invalidate();s().support_fx166c.clear_preview()
func choose_target(cell: Vector2i) -> void:
	if s().support166c.running or mode.is_empty():return
	last_anchor=cell;quote=s().support166c.prepare(mode,source_uid,cell)
	var q: Dictionary=quote.get("quote",quote);s().support_fx166c.preview(q)
	if not quote.get("ok",false):title.text="连续维护 · 调整选择";summary.text=str(quote.get("reason","目标不可用"))+"\n未支付，可换素材、用途、落点或取消。";sync();return
	title.text="连续维护 4/4 · 检查并确认"
	summary.text="素材：%s ×1\n目标：%s · %d列%d行\n%s\n指令-1 · 负荷+1 · 热%d→%d · Depth→%d\n维护本场%d/2，每回合一次；补位另限1/1。\n无额外检索、抽牌、引擎或行动刷新。\n确认后完整结算，×4/跳过只影响演出。"%[q.source_name,q.layout[0].name,cell.x+1,cell.y+1,"修复+%dHP，不提高上限"%q.heal if q.mode=="repair" else "生成一个1/2学徒，本回合休整",q.heat_before,q.heat_after,q.depth_after,q.used_after]
	summary_scroll.scroll_vertical=0;sync()
func pointer(point: Vector2) -> void:
	if not selecting:return
	var chosen:=Vector2i(-1,-1);var distance:=INF
	for cell: Vector2i in s().battle.tactical_grid_rules.get_all_cells():
		var p: Vector2=s()._project_tactical_cell_to_screen(cell)
		if p.is_finite() and p.distance_to(point)<distance:distance=p.distance_to(point);chosen=cell
	if distance<55:choose_target(chosen)
func submit() -> void:
	if s().support166c.running or not quote.get("ok",false):return
	var approved:=quote.duplicate(true);quote={};selecting=false;title.text="连续维护 · 已支付，正在执行";sync()
	var result: Dictionary=await s().support166c.execute(approved)
	if not is_instance_valid(s()):return
	title.text="连续维护 · 完成" if result.get("ok",false) else "连续维护 · 未提交"
	summary.text=("修复完成：+%dHP，保留原行动消耗。"%result.healed if result.get("mode")=="repair" else "补位完成：一个1/2学徒，本回合休整；下回合再进攻。")+"\n已消耗素材×1、1指令、热+2、负荷+1。\n收起后点棋子，使用现有场面继续战斗。" if result.get("ok",false) else str(result.get("reason","未提交"))
	refresh_sources166c();sync()
func sync() -> void:
	var busy: bool=s().support166c.running
	confirm.disabled=busy or not quote.get("ok",false);confirm.visible=not busy;sources.visible=not busy;modes.visible=not busy
	fast.visible=busy;skip_button.visible=busy;close_button.disabled=busy
func dismiss() -> void:
	if s().support166c.running:return
	selecting=false;invalidate166c();panel.hide()
