extends RefCounted
## Pure public projections. The existing runner remains the only plan authority.
static func board_input_owner(s: Variant) -> String:
	if s.recipe_panel166.panel.visible and s.recipe_panel166.selecting:return "正在选择连续展开主锚点"
	if s.support_panel166c.panel.visible and s.support_panel166c.selecting:return "正在选择维护目标"
	if s._garrison_context.get("active",false):return "正在选择驻防位置"
	if s._core_surge_selecting:return "正在选择增压目标"
	if s._skill_context.get("active",false):return "正在选择技能目标"
	if s._building_replace_select_active:return "正在选择替换建筑"
	if is_instance_valid(s._selected_attacker):return "正在选择攻击目标"
	return s.advance165.input_hint()
static func gate(s: Variant) -> String:
	if s.battle_ended or s._gb1_restarting:return "本局已结束或正在离开"
	if s._exit_modal_active:return "先完成或取消返回确认"
	var owner:=board_input_owner(s)
	if not owner.is_empty():return owner
	for window: Window in [s._engineering_window,s._facility_window,s._fort_window]:
		if window.visible:return "先完成或关闭当前窗口"
	if s.get_node("IntegratedPlaytestTools").panel.visible:return "先关闭战术工具"
	return s.recipe166._gate()
static func predict(s: Variant,id: String,actor: CardData) -> Dictionary:
	var part: Dictionary=s.battle.get_weakpoint_snapshot(id)
	if part.is_empty() or actor==null:return {}
	var attack: int=maxi(0,s.battle.get_effective_unit_attack(actor)+s.battle.get_normal_attack_bonus(actor))
	var after: int=maxi(0,int(part.integrity)-attack)
	var hp: int=s.context.enemy.hp
	var rupture: int=int(part.rupture_damage) if not part.broken and part.exposed and after==0 else 0
	return {"attack":attack,"part_before":part.integrity,"part_after":after,"boss_before":hp,"boss_after":maxi(0,hp-rupture),"text":"按当前场面预计：耐久%d→%d；本体%d→%d。\n途中变化会停下重验；本次仅伤部位，击破才伤本体。"%[part.integrity,after,hp,maxi(0,hp-rupture)]}
static func inspect(s: Variant,id: String) -> Dictionary:
	var part: Dictionary=s.battle.get_weakpoint_snapshot(id)
	if part.is_empty():return {}
	var state: String="已破坏" if part.broken else "锁定：先破两处外围" if not part.exposed else "暴露 · 可选择单位"
	var lane: String="任一合法攻核列（不是仅中列）" if int(part.column)<0 else "关联第%d列突破通路"%(int(part.column)+1)
	var detail: String="%s · %s\n耐久%d/%d · 击破本体−%d\n%s"%[part.name,state,part.integrity,part.max_integrity,part.rupture_damage,lane]
	if id=="core_ring":detail+="\n核心击破还会清空Boss护盾。"
	if part.broken:detail+="\n残骸保留，不再扣费或重复奖励。"
	elif not part.exposed:detail+="\n外围可任选顺序；先破护臂与阀门，再来选择核心。"
	else:detail+="\n选单位→有分支时选路线→确认；当前只查看，不付款。"
	var candidates: Array=[]
	if not part.broken and part.exposed:
		for actor: CardData in s.context.player.field:
			var routes: Dictionary=s.advance165.routes(actor,id)
			var costs: Array=[]
			for route: Dictionary in routes.get("routes",[]):costs.append(int(route.budget.total_cost))
			costs.sort()
			var cost_text: String=("%d指令"%costs[0] if costs[0]==costs[-1] else "%d—%d指令"%[costs[0],costs[-1]]) if not costs.is_empty() else "不能一段完成"
			var p:=predict(s,id,actor)
			candidates.append({"uid":actor.get_instance_id(),"name":actor.get_display_name(),"ok":routes.get("ok",false),"cost_text":cost_text,"reason":routes.get("reason",""),"prediction":p})
	if candidates.is_empty() and not part.broken and part.exposed:detail+="\n还没有可选单位：先用左侧连续展开布局，下回合再进攻。"
	var blockers: Array=[];var seen: Array=[]
	for actor: CardData in s.context.player.field:
		if not s.battle.advance_actor_status(actor).get("ok",false):continue
		for enemy: CardData in s.context.enemy.field:
			if enemy.get_instance_id() in seen:continue
			var cell: Vector2i=s.battle.get_unit_cell(enemy)
			var columns: Array=[0,1,2,3,4] if int(part.column)<0 else [int(part.column)]
			for col: int in columns:
				var origin:=Vector2i(col,s.battle.tactical_core_facing_rules.get_breach_rank(&"player"))
				var q: Dictionary=s.battle.project_advance_part(actor,id,origin)
				var reason: String=str(q.get("reason",""))
				var guard: bool=enemy.is_guard_card and cell.x==col and reason.contains("守卫") and reason.contains(enemy.get_display_name())
				var obstacle: bool=reason.contains("前方敌棋") and cell in s.battle._get_pattern_attack_cells(actor,origin,&"player")
				if not guard and not obstacle:continue
				seen.append(enemy.get_instance_id());blockers.append({"uid":enemy.get_instance_id(),"cell":cell,"name":enemy.get_display_name(),"kind":"守卫" if guard else "阻挡棋子"});break
	return {"part":part,"state":state,"lane":lane,"detail":detail,"candidates":candidates,"blockers":blockers}
