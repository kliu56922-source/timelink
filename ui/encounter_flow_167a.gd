extends "res://ui/encounter_flow_readout.gd"
const Clarity=preload("res://battle/analysis/operation_clarity_167a.gd")
func refresh() -> void:
	super.refresh()
	var s: Variant=scene()
	if s==null:return
	s.phase_label166b.text=s.phase_label166b.text.replace("166D","167A")
	var state:=snapshot()
	if state.preparation and s.battle.recipe166_snapshot().used>0:
		s.recipe_panel166.entry_hint.text="已成阵；炉基座强化为可选操作。\n点建筑先预览费用/效果，确认才付款。\n准备好后点「部署完成」，余点不结转。"
	var body: bool=state.broken==3
	# This label belongs to the choices group, separate from the route scroll.
	for child: Node in s.advance_panel165.title.get_parent().get_children():
		if child is Label and child.text.begins_with("选择路线"):child.visible=not body
	s.advance_panel165.route_scroll.visible=not body
	if not body:return
	var actor: CardData=s.advance165.resolve(s.advance_panel165.actor_uid)
	var q:=Clarity.body_status(s,actor)
	body_button.disabled=not q.ok
	body_button.tooltip_text="确认后使用原生攻核规则。"+("" if q.ok else "\n"+q.reason)
	if s.advance_panel165.panel.visible and s.advance_panel165.config.visible:
		s.advance_panel165.summary.text="三要害已破，不需要选择路线。\n"+("当前单位可攻击Boss本体 · %d指令。"%q.cost if q.ok else "当前不能攻本体："+q.reason)
	for i in range(mini(s.advance_panel165.source_buttons.size(),s.context.player.field.size())):
		var c: CardData=s.context.player.field[i];var status:=Clarity.body_status(s,c)
		var cell: Vector2i=s.battle.get_unit_cell(c)
		s.advance_panel165.source_buttons[i].text="%s %d列%d行 · %s"%[c.get_display_name(),cell.x+1,cell.y+1,status.label]
		s.advance_panel165.source_buttons[i].tooltip_text="点单位后查看本体攻击；预览不付款。" if status.ok else status.reason
