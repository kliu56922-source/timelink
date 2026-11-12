extends Node
## Presentation-only view of the current encounter. No commands/RNG/target choices.
var scene_ref: WeakRef
var body_button: Button
var _terminal: Dictionary={}
func setup(owner: Node) -> void:
	scene_ref=weakref(owner)
	body_button=Button.new();body_button.text="攻击Boss本体";body_button.custom_minimum_size.y=36
	owner.advance_panel165.config.add_child(body_button);owner.advance_panel165.config.move_child(body_button,1)
	body_button.pressed.connect(func():
		var s: Variant=scene()
		if s!=null:await s.finish_body166d(s.advance_panel165.actor_uid))
	refresh()
func scene() -> Variant:
	var s: Variant=scene_ref.get_ref() if scene_ref!=null else null
	return s if is_instance_valid(s) and s.is_inside_tree() else null
func snapshot() -> Dictionary:
	if not _terminal.is_empty():return _terminal.duplicate(true)
	var s: Variant=scene()
	if s==null:return {}
	var parts: Array=s.battle.get_weakpoint_snapshots();var broken:=0
	for part: Dictionary in parts:
		if part.broken:broken+=1
	var economy: Dictionary=s.battle.get_command_economy_snapshot("player")
	var result: Dictionary={"player_round":s.battle.opening166b.player_round,"preparation":s.battle.preparation_active166b(),"player_open":economy.get("turn_open",false),"transition":s.transition166d,"points":economy.get("current_points",0),"max_points":economy.get("turn_max_points",0),"broken":broken,"support":s.battle.support166_snapshot(),"hp":s.context.player.hp,"boss_hp":s.context.enemy.hp,"terminal":s.battle_ended}
	if s.battle_ended:_terminal=result.duplicate(true)
	return result
func _process(_delta: float) -> void:refresh()
func refresh() -> void:
	var s: Variant=scene()
	if s==null:return
	var state:=snapshot();var preparing: bool=state.preparation
	var phase:="结算" if state.terminal else "Boss行动" if state.transition else "部署" if preparing else "交战"
	s.phase_label166b.text="166D · 第%d回合 · %s\n指令%d/%d · 维护%d/2"%[state.player_round,phase,state.points,state.max_points,state.support.used]
	var original: String=s.context.enemy.intent_text
	var shown: String=s._boss_status_hud._sanitize_visible_text(original,"当前动作未公开")
	var intent: String=("首轮已公开：" if preparing and not state.transition else "正在执行：" if state.transition else "上次：")+shown
	s._boss_status_hud.get_node("IntentRow/IntentText").text=intent
	var opportunities: Node=s.get_node_or_null("CurrentActionPanel")
	if opportunities!=null:
		opportunities.threat.text=intent if preparing or state.transition else "上次：%s\n下一具体动作未公开，Boss行动开始时揭示。"%shown
		opportunities.threat.tooltip_text=opportunities.threat.text
	if preparing and s.battle.recipe166_snapshot().used>0:
		s.recipe_panel166.entry_hint.text="已成阵；炉基座可选强化已有主力。\n建筑效果需单独支付，点击可查看。\n准备好后点「部署完成」，余点不结转。"
	elif state.broken==3:
		s.recipe_panel166.entry_hint.text="三要害已破，开始本体收尾。\n点仍在合法攻核位置的单位→攻击Boss本体。\n守卫/前方敌棋仍会拦截，费用照常。"
	var actor: CardData=s.advance165.resolve(s.advance_panel165.actor_uid)
	var q: Dictionary=s.battle.get_unit_command_status(actor,"attack_core") if actor!=null else {"ok":false}
	var selection_gate: String=s.recipe166._gate()
	body_button.visible=state.broken==3
	body_button.disabled=not q.get("ok",false) or not s.axis155_native_ready() or s._exit_modal_active or not selection_gate.is_empty()
	var cost: int=s.battle.get_action_command_cost(actor,"attack_core") if actor!=null else 3
	body_button.text="攻击Boss本体 · %d指令"%cost
	body_button.tooltip_text="使用已选单位原生攻击本体；仍受位置、朝向、守卫、休整和费用限制。"+("" if q.get("ok",false) else " 当前条件不满足，可手动查看具体限制。")
	if not selection_gate.is_empty():body_button.tooltip_text=selection_gate+"；先完成或取消当前选取。"
	if state.broken==3 and s.advance_panel165.panel.visible and s.advance_panel165.config.visible:
		s.advance_panel165.title.text=(actor.get_display_name() if actor!=null else "选择单位")+" · 本体收尾"
		s.advance_panel165.summary.text="三要害已破，不需要再选要害。\n"+("确认使用当前单位攻击Boss本体；费用与原生攻击相同。" if q.get("ok",false) else "当前单位不能直接攻本体。检查通路/守卫/休整/指令；可点手动操作查看限制，或改选单位。")
		if not selection_gate.is_empty():s.advance_panel165.summary.text="三要害已破。\n"+selection_gate+"\n先完成或取消当前选择，再攻击本体。"
	for part: Dictionary in s.battle.get_weakpoint_snapshots():s.advance_panel165.part_buttons[part.id].visible=state.broken<3
	s.advance_panel165.confirm_button.visible=state.broken<3
	if state.broken==3:
		for i in range(s.advance_panel165.source_buttons.size()):
			if i>=s.context.player.field.size():break
			var c: CardData=s.context.player.field[i];var status: Dictionary=s.battle.get_unit_command_status(c,"attack_core")
			var cell: Vector2i=s.battle.get_unit_cell(c)
			s.advance_panel165.source_buttons[i].text="%s %d列%d行 · %s"%[c.get_display_name(),cell.x+1,cell.y+1,"可攻本体" if status.get("ok",false) and selection_gate.is_empty() else "查看限制"]
			s.advance_panel165.source_buttons[i].tooltip_text=selection_gate if not selection_gate.is_empty() else "三要害已破，点单位后选择攻击Boss本体；原费用和守卫限制保留。"
