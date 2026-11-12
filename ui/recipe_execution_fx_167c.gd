extends "res://ui/key_recipe_board_fx.gd"
const Mask=preload("res://ui/recipe_visibility_mask_167c.gd")
const Events=preload("res://battle/analysis/recipe_execution_events_167c.gd")
var mask167c=Mask.new()
var duration167c:=Events.DURATION
var plan167c: Dictionary={}
var source_points167c: Dictionary={}
var faces167c: Dictionary={}
var pool167c: Label
var viewed167c: Array=[]
var prepared167c:=false
func setup(owner: Node) -> void:
	super.setup(owner)
	pool167c=Label.new();pool167c.text="独立衍生池\n本次已生成学徒1\n不是抽牌/检索";pool167c.add_theme_font_size_override("font_size",14)
	pool167c.add_theme_color_override("font_color",Color("80e9ed"));pool167c.mouse_filter=Control.MOUSE_FILTER_IGNORE;pool167c.hide();add_child(pool167c)
func arm167c(ids: Array,points: Dictionary) -> void:
	source_points167c=points.duplicate();active=true;previewing=false;prepared167c=false;viewed167c=[]
	mask167c.arm(s(),ids)
func begin(receipt: Dictionary) -> void:
	plan167c=receipt.get("execution167c",{}).duplicate(true);layout=receipt.layout.duplicate(true);legal_anchors=[];valid=true;t=0.0
	prepared167c=plan167c.get("events",[]).size()==5
	if not prepared167c:return
	mask167c.include_ids(plan167c.sources.map(func(source):return int(source.uid)))
	for source: Dictionary in plan167c.sources:faces167c[int(source.uid)]=_face167c(source)
	mask167c.enforce();present(0.0)
func _card167c(uid: int) -> CardData:
	var owner: Variant=s()
	if not is_instance_valid(owner):return null
	for cards: Array in [owner.context.player.field,owner.context.player.traps]:
		for card: CardData in cards:
			if card.get_instance_id()==uid:return card
	return null
func _face167c(source: Dictionary) -> PanelContainer:
	var face:=PanelContainer.new();face.mouse_filter=Control.MOUSE_FILTER_IGNORE;face.size=Vector2(104,144);face.pivot_offset=face.size*0.5;face.clip_contents=true
	var style:=StyleBoxFlat.new();style.bg_color=Color("10202f");style.border_color=Color("7edce6");style.set_border_width_all(2);style.set_content_margin_all(5);face.add_theme_stylebox_override("panel",style)
	var box:=VBoxContainer.new();box.mouse_filter=Control.MOUSE_FILTER_IGNORE;face.add_child(box)
	var name_label:=Label.new();name_label.text=source.name;name_label.add_theme_font_size_override("font_size",12);name_label.clip_text=true;name_label.mouse_filter=Control.MOUSE_FILTER_IGNORE;box.add_child(name_label)
	var art:=TextureRect.new();art.custom_minimum_size=Vector2(88,82);art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;art.mouse_filter=Control.MOUSE_FILTER_IGNORE;box.add_child(art)
	var card:=_card167c(int(source.uid))
	if card!=null:
		if not card.thumb_path.is_empty() and ResourceLoader.exists(card.thumb_path):art.texture=load(card.thumb_path)
		elif card.art is Texture2D:art.texture=card.art
	var origin:=Label.new();origin.text="独立池 · 衍生" if source.from_zone=="independent_pool" else "手牌 → 建筑" if source.to_zone=="traps" else "手牌 → 单位"
	origin.add_theme_font_size_override("font_size",12);origin.mouse_filter=Control.MOUSE_FILTER_IGNORE;box.add_child(origin)
	add_child(face);return face
func present(seconds: float) -> void:
	if not active or not prepared167c:return
	t=clampf(seconds,0.0,duration167c)
	var owner: Variant=s()
	if not is_instance_valid(owner):return
	var viewport: Vector2=owner.get_viewport_rect().size
	var stage: Array=[Vector2(viewport.x*0.44,viewport.y*0.64),Vector2(viewport.x*0.56,viewport.y*0.64)]
	var pool:=Vector2(viewport.x*0.14,viewport.y*0.42);pool167c.position=pool-Vector2(62,142);pool167c.visible=t>=3.05 and t<4.25
	for event: Dictionary in plan167c.events:
		if t>=float(event.end) and not viewed167c.any(func(item):return item.sequence==event.sequence):
			viewed167c.append({"sequence":event.sequence,"kind":event.kind,"transaction":event.transaction})
			if event.kind in ["foundation_arrives","familiar_arrives","derived_arrives"]:mask167c.reveal(int(event.uids[0]))
	for i in range(plan167c.sources.size()):
		var source: Dictionary=plan167c.sources[i];var uid: int=source.uid;var face: PanelContainer=faces167c[uid]
		var target: Vector2=owner._project_tactical_cell_to_screen(source.cell)+Vector2(0,-26)
		var from: Vector2=source_points167c.get(uid,stage[mini(i,1)])
		face.scale=Vector2.ONE
		if i<2 and t<0.65:face.show();_fly167c(face,from,stage[i],t/0.65)
		elif i==1 and t<1.85:face.show();_fly167c(face,stage[1],target,(t-0.65)/1.2);face.scale.x=maxf(0.12,absf(cos((t-0.65)/1.2*PI)))
		elif i==0 and t<1.85:face.show();_fly167c(face,stage[0],stage[0],1.0)
		elif i==0 and t<3.05:face.show();_fly167c(face,stage[0],target,(t-1.85)/1.2)
		elif i==2 and t>=3.05 and t<4.25:face.show();_fly167c(face,pool,target,(t-3.05)/1.2)
		else:face.hide()
	var current: Dictionary=plan167c.events[-1]
	for event: Dictionary in plan167c.events:
		if t<float(event.end):current=event;break
	var bill: Dictionary=plan167c.bill
	owner.recipe_panel166.title.text="整套已结算 · 正在显示第%d/5段"%(int(current.sequence)+1)
	owner.recipe_panel166.summary.text="已付两张key、%d指令、负荷+%d\n热%d→%d · 盾+%d · 已生成学徒%d\n\n%s\n\n空格/×4加速；Esc/跳过只结束观看，不能撤销已结算效果。"%[bill.command,bill.load,bill.heat_before,bill.heat_after,bill.shield_gain,bill.generated,current.title]
	owner.recipe_panel166.entry_hint.text="整套已支付一次，正在逐张到位。\n可加速或跳过观看；不会额外生成。"
	mask167c.enforce();queue_redraw()
func _fly167c(face: Control,from: Vector2,to: Vector2,amount: float) -> void:
	var u:=clampf(amount,0.0,1.0);var eased:=u*u*(3.0-2.0*u)
	face.position=from.lerp(to,eased)+Vector2(0,-sin(u*PI)*38.0)-face.size*0.5
func snapshot167c() -> Dictionary:
	var snapshot: Dictionary=mask167c.snapshot()
	snapshot.merge({"active":active,"committed":plan167c.get("committed",false),"time":t,"planned_events":plan167c.get("events",[]).duplicate(true),"viewed_events":viewed167c.duplicate(true),"proxy_count":faces167c.size()},true);return snapshot
func finish() -> void:
	mask167c.finish()
	for face: Node in faces167c.values():
		if is_instance_valid(face):remove_child(face);face.queue_free()
	faces167c.clear()
	if is_instance_valid(pool167c):pool167c.hide()
	prepared167c=false;super.finish()
func _process(_delta: float) -> void:
	if active:mask167c.enforce();queue_redraw()
	elif previewing:queue_redraw()
func _draw() -> void:
	if not active:super._draw();return
	if not prepared167c or t<4.25:return
	var owner: Variant=s()
	if not is_instance_valid(owner):return
	var a: Vector2=owner._project_tactical_cell_to_screen(layout[1].cell)
	for i: int in [0,2]:
		var b: Vector2=owner._project_tactical_cell_to_screen(layout[i].cell)
		var u:=clampf((t-4.25)/(duration167c-4.25),0.0,1.0)
		draw_line(a,a.lerp(b,u),Color("f3ca71"),3.0,true);draw_circle(a.lerp(b,u),5,Color("f3ca71"))
