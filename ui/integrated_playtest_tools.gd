extends CanvasLayer
## Functional navigation only. Original buttons retain their native handlers.
var scene_ref: WeakRef
var panel: PanelContainer
var toggle: Button
var guide: Button
var core: Button
var facilities: Button
var guide_window: AcceptDialog
var vitals: Label
var status: Label

func setup(scene: Variant) -> void:
	scene_ref=weakref(scene);name="IntegratedPlaytestTools";layer=40
	var bar:=HBoxContainer.new();bar.position=Vector2(12,48);add_child(bar)
	toggle=Button.new();toggle.text="战术工具 ▾";bar.add_child(toggle)
	guide=Button.new();guide.text="玩法与目标";bar.add_child(guide)
	vitals=Label.new();vitals.add_theme_font_size_override("font_size",16);bar.add_child(vitals)
	panel=PanelContainer.new();panel.position=Vector2(12,88);panel.custom_minimum_size=Vector2(320,0);panel.visible=false;add_child(panel)
	var scroll:=ScrollContainer.new();scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;panel.add_child(scroll)
	var box:=VBoxContainer.new();box.size_flags_horizontal=Control.SIZE_EXPAND_FILL;box.add_theme_constant_override("separation",8);scroll.add_child(box)
	for node: Control in [scene._growth_button,scene._growth_amount,scene._engineering_button]:move_control(node,box)
	core=Button.new();core.text="炉心指令 · 再部署 / 排压";box.add_child(core);core.pressed.connect(scene._on_core_command_button_pressed)
	facilities=Button.new();facilities.text="完工设施 · 查看 / 使用";box.add_child(facilities);facilities.pressed.connect(scene._open_facilities)
	for node: Control in [scene._fort_button,scene._rotate_build_button,scene._gb1_restart_button,scene._integrated_return]:move_control(node,box)
	move_control(scene._expansion_guide._button,box)
	status=Label.new();status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;status.custom_minimum_size.x=292;box.add_child(status)
	if is_instance_valid(scene._siege_label):move_control(scene._siege_label,box);scene._siege_label.custom_minimum_size.x=292
	if is_instance_valid(scene._edge_intent_label):move_control(scene._edge_intent_label,box);scene._edge_intent_label.custom_minimum_size=Vector2(292,72)
	if is_instance_valid(scene._siege_panel):scene._siege_panel.hide()
	if is_instance_valid(scene._range_legend):scene._range_legend.hide()
	guide_window=AcceptDialog.new();guide_window.title="阵地与过热 · 玩法与目标";guide_window.min_size=Vector2i(620,440);scene.add_child(guide_window)
	guide_window.dialog_text="目标：击败熔炉守卫。观察Boss预告，安排出牌、单位行动和回合结束。\n\n热量：普通OD需7热，8热仪式还需要真实的场上准备；两者不同。\n指令：移动、攻击、施工、精炼共同使用，连续投入会增加Depth。\n连锁：只有原规则认可的成功出牌和行动推进，查看或施工不额外送连锁。\n\n工程册：稳筑花2指令，下个己方回合尝试完工；急筑另花热量。\n冷却设施可选1×1、1×2、2×2，占地和旋转在付款前确定。\n冷却设施本体耐久随尺寸为2 / 3 / 4；费用与冷却能力保持原样。\n完整占地也会挡住己方退守格，确认时请保留单位机动空间。\n城墙、城门沿格边建设；门为友军通行，方向影响保护。\n完工设施从战术工具直接进入，先看来源、费用和下条指令再确认。\n炉心精炼需要活着的适格升格单位，花热与指令换长期点。\n\n取消只撤销预览，不付款。处理中的动作请等待后再重试或返回。\n当前灰盒版仍在调整平衡，尚未完成正式美术与最终验收。"
	toggle.pressed.connect(toggle_panel)
	guide.pressed.connect(func():guide_window.popup_centered())
	resize_panel();refresh_vitals();get_viewport().size_changed.connect(resize_panel)
	set_process(true)

func move_control(node: Control,box: VBoxContainer) -> void:
	node.reparent(box,false);node.position=Vector2.ZERO;node.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	node.custom_minimum_size.x=0

func resize_panel() -> void:
	if not is_instance_valid(panel):return
	panel.size=Vector2(320,clampf(get_viewport().get_visible_rect().size.y-180,240,780))

func _process(_delta: float) -> void:
	var scene: Variant=scene_ref.get_ref() if scene_ref!=null else null
	if scene==null or scene.context==null:return
	refresh_vitals()
	if is_instance_valid(scene._core_command_button):
		core.disabled=scene._core_command_button.disabled
		core.tooltip_text=scene._core_command_button.tooltip_text
	status.text="城防：己方%d / 敌方%d\n同一份指令用于施工与单位行动。\n占地可能堵住己方退守；先预览再支付。"%[scene.context.player.shield,scene.context.enemy.boss_shield]

func toggle_panel() -> void:
	panel.visible=not panel.visible
	var scene: Variant=scene_ref.get_ref()
	if scene==null:return
	# These suggestions occupy the same left lane; restore them when closing.
	for coach: Control in [scene._relation_coach_panel]:
		if is_instance_valid(coach):coach.visible=not panel.visible

func refresh_vitals() -> void:
	var scene: Variant=scene_ref.get_ref() if scene_ref!=null else null
	if scene!=null and scene.context!=null and is_instance_valid(vitals):
		vitals.text="核心生命：%d  护盾：%d"%[scene.context.player.hp,scene.context.player.shield]
