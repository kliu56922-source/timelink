extends Node
## A battle-local, single-use plan. No screen macros or state mutation in previews.
signal changed
signal step_committed(index: int,receipt: Dictionary)
var scene_ref: WeakRef
var running:=false
var stopped:=false
var stop_reason:=""
var last_result: Dictionary={}
var _serial:=0
var _quotes: Dictionary={}
func setup(s: Node) -> void:scene_ref=weakref(s)
func scene() -> Variant:
	var s: Variant=scene_ref.get_ref() if scene_ref!=null else null
	return s if is_instance_valid(s) and s.is_inside_tree() else null
func fingerprint() -> Dictionary:
	var s: Variant=scene()
	if s==null:return {}
	var result: Dictionary=s.axis155.fingerprint()
	result.parts=s.battle.get_weakpoint_snapshots().duplicate(true)
	result.terrain=s.context.tactical_board_state.get_all_cell_states().duplicate(true)
	result.economy=s.battle.get_command_economy_snapshot("player").duplicate(true)
	result.core_open=s.battle._core_command_player_turn_open
	result.terminal=s.battle_ended
	result.modifiers={}
	for side: Variant in [s.context.player,s.context.enemy]:
		for card: CardData in side.field:
			var st: Variant=s.battle._state_for_card(card)
			if st!=null:result.modifiers[card.get_instance_id()]=[st.get_command_cost_modifier(),st.has_free_action(),card.unit_power,card.unit_defense]
	return result
func resolve(uid: int) -> CardData:
	var s: Variant=scene()
	if s!=null:
		for card: CardData in s.context.player.field:
			if is_instance_valid(card) and card.get_instance_id()==uid:return card
	return null
func _gate() -> String:
	var s: Variant=scene()
	if s==null:return "场次已销毁"
	if s._gb1_restarting or s.battle_ended or s.context.player.hp<=0 or s.context.enemy.hp<=0:return "战斗已结束或正在离开"
	var selection:=input_hint()
	if not selection.is_empty():return selection
	if s.axis155.running or not s.axis155_native_ready():return "等待当前原动作完成"
	if s._is_piece_selection_active() or s._is_lane_selection_active() or s._is_monster_summon_interaction_active() or s._od_release_context.get("active",false):return "请先完成或取消当前选取"
	if not s.battle._core_command_player_turn_open:return "等待己方行动窗口"
	return ""
func input_hint() -> String:
	var s: Variant=scene()
	if s==null:return ""
	if s._is_lane_selection_active():
		return "正在选择移动落点：点棋盘青色格；Esc或右键取消。" if s._lane_selection_mode in [s.LANE_SELECT_MOVE,s.LANE_SELECT_REDEPLOY] else "正在选择棋盘目标：点高亮格；Esc或右键取消。"
	if s._is_piece_selection_active():return "正在选择卡牌目标：点高亮对象；Esc或右键取消。"
	if s._is_monster_summon_interaction_active():return "正在部署单位：点己方高亮格并确认；Esc取消。"
	if s._od_release_context.get("active",false):return "正在选择OD目标：点高亮对象；Esc取消。"
	return ""
func actor_guidance(actor: CardData) -> String:
	var s: Variant=scene()
	if s==null:return "场次已离开"
	if s.battle.has_method("preparation_active166b") and s.battle.preparation_active166b():return s.battle.opening166b.REASON
	var selection:=input_hint()
	if not selection.is_empty():return selection
	var attack: Dictionary=s.battle.can_monster_attack(actor)
	if str(attack.get("reason","")).contains("刚登场"):return "新单位本回合休整，不能移动/攻击。可继续其他操作，或点「结束回合」（有余点需再确认）；等Boss行动后，下回合再点单位。"
	return ""
func availability(actor: CardData) -> Dictionary:
	# Read-only route inspection, never prepares a quote or commits an action.
	var s: Variant=scene();var help:=actor_guidance(actor)
	if not help.is_empty():return {"ok":false,"label":"部署中" if help.contains("部署阶段") else "休整" if help.contains("休整") else "选取中","reason":help}
	var status: Dictionary=s.battle.advance_actor_status(actor)
	if not status.get("ok",false):return {"ok":false,"label":"查看限制","reason":str(status.get("reason","暂不能行动"))}
	var reasons: Array[String]=[];var reachable: Array[String]=[]
	for part: Dictionary in s.battle.get_weakpoint_snapshots():
		if part.broken or not part.exposed:continue
		var option:=routes(actor,part.id)
		if option.ok:reachable.append(part.name)
		else:reasons.append(part.name+"："+str(option.reason))
	if not reachable.is_empty():return {"ok":true,"label":"可连续","reason":"当前可连续进攻："+"、".join(reachable)+"。点单位→要害→路线→执行；整段费用见预览。"}
	return {"ok":false,"label":"需准备","reason":"\n".join(reasons) if not reasons.is_empty() else "当前无可攻击要害。"}
func routes(actor: CardData,id: String) -> Dictionary:
	var gate:=_gate()
	if running or not gate.is_empty():return {"ok":false,"reason":gate if not gate.is_empty() else "行动段执行中"}
	var s: Variant=scene();var actor_status: Dictionary=s.battle.advance_actor_status(actor)
	if not actor_status.ok:return actor_status
	var part: Dictionary=s.battle.get_weakpoint_snapshot(id)
	if part.is_empty() or part.get("broken",true) or not part.get("exposed",false):return {"ok":false,"reason":"该要害已破坏" if part.get("broken",false) else "先破坏两处外围要害"}
	var origin: Vector2i=s.battle.get_unit_cell(actor)
	var queue: Array=[{"cell":origin,"cells":[]}];var result: Array=[];var reason:="两次移动内没有可进攻路线，本回合无法一段完成。可改选单位；也可手动先调整位置、下回合重新预览。手动多移一步不保证本回合能攻击，后续费用未支付。"
	var cheapest: Dictionary={}
	while not queue.is_empty():
		var path: Dictionary=queue.pop_front()
		var status: Dictionary=s.battle.project_advance_part(actor,id,path.cell)
		if status.ok:
			var budget: Dictionary=s.battle.project_advance_budget(actor,path.cells.size())
			if budget.ok:result.append({"cells":path.cells.duplicate(),"budget":budget})
			elif cheapest.is_empty() or int(budget.get("required_cost",999))<int(cheapest.get("required_cost",999)):cheapest=budget
		elif str(status.reason).contains("守卫") or str(status.reason).contains("阻挡"):reason=status.reason
		if path.cells.size()==2:continue
		for cell: Vector2i in s.battle.project_advance_moves(actor,path.cell):
			if cell==origin or cell in path.cells:continue
			queue.append({"cell":cell,"cells":path.cells+[cell]})
	if result.is_empty() and not cheapest.is_empty():
		var refusal:=cheapest.duplicate(true);refusal.routes=[];return refusal
	return {"ok":not result.is_empty(),"routes":result,"reason":"" if not result.is_empty() else reason}
func prepare(actor: CardData,id: String,cells: Array) -> Dictionary:
	var gate:=_gate()
	if running or not gate.is_empty():return {"ok":false,"reason":gate if not gate.is_empty() else "行动段执行中"}
	if cells.size()>2:return {"ok":false,"reason":"本段最多两次移动"}
	var s: Variant=scene();var status: Dictionary=s.battle.advance_actor_status(actor)
	if not status.ok:return status
	var origin: Vector2i=s.battle.get_unit_cell(actor);var visited: Array=[origin]
	for cell: Variant in cells:
		if not cell is Vector2i or cell in visited or cell not in s.battle.project_advance_moves(actor,origin):return {"ok":false,"reason":"所选路线已不可达"}
		visited.append(cell);origin=cell
	status=s.battle.project_advance_part(actor,id,origin)
	if not status.ok:return status
	var budget: Dictionary=s.battle.project_advance_budget(actor,cells.size())
	if not budget.ok:return budget
	_serial+=1
	if _quotes.size()>=16:_quotes.clear()
	var quote: Dictionary=budget.duplicate(true)
	quote.merge({"serial":_serial,"actor_uid":actor.get_instance_id(),"part_id":id,"cells":cells.duplicate(),"signature":fingerprint()})
	_quotes[_serial]=quote.duplicate(true)
	return quote
func stop(reason: String="已停止后续行动") -> void:
	stopped=true;stop_reason=reason;_quotes.clear();changed.emit()
func invalidate() -> void:_quotes.clear()
func execute(q: Dictionary) -> Dictionary:
	if running:return {"ok":false,"reason":"本段已经在执行"}
	if not q.get("ok",false) or not _quotes.has(q.get("serial")) or _quotes[q.serial]!=q:return {"ok":false,"reason":"预览失效、被改动或已提交"}
	var gate:=_gate()
	if not gate.is_empty():return {"ok":false,"reason":gate}
	if fingerprint()!=q.signature:return {"ok":false,"reason":"局面已变化，请重新选择路线"}
	_quotes.clear();running=true;stopped=false;stop_reason="";last_result={};changed.emit()
	var receipts: Array=[];var actual_cost:=0
	for i in range(q.cells.size()+1):
		if stopped:break
		gate=_gate()
		if not gate.is_empty():stop(gate);break
		var s: Variant=scene();var actor:=resolve(q.actor_uid)
		if actor==null:stop("原单位已离场");break
		var step: Dictionary={"actor_uid":q.actor_uid,"kind":"move" if i<q.cells.size() else "part","cell":q.cells[i] if i<q.cells.size() else s.battle.get_unit_cell(actor),"part_id":q.part_id}
		var status: Dictionary=s.battle.get_unit_command_status(actor,"move",step.cell) if step.kind=="move" else s.battle.get_weakpoint_attack_status(actor,q.part_id)
		if not status.get("ok",false) or (step.kind=="move" and not s.battle.get_unit_move_cell_status(actor,step.cell,s.battle.MOVE_SELF).get("ok",false)):stop("原生通路、守卫或行动条件已变化");break
		if int(status.cost)>int(q.costs[i]) or actual_cost+int(status.cost)>int(q.total_cost):stop("本次费用超过授权上限");break
		var budget: Dictionary=s.battle.project_advance_budget(actor,q.cells.size()-i)
		if not budget.ok or int(budget.depth_cap)>int(q.depth_cap):stop("压力或后续费用超出授权，请重新决定");break
		var receipt: Dictionary=s.advance165_commit(step)
		if not receipt.get("ok",false):stop("原动作未提交："+str(receipt.get("reason",receipt.get("reason_code","拒绝"))));break
		actual_cost+=int(receipt.cost);receipts.append(receipt.duplicate(true))
		var committed_state:=fingerprint()
		step_committed.emit(i,receipt);changed.emit()
		await s.advance165_present(step,receipt)
		if scene()==null:stop_reason="旧场次已销毁";stopped=true;break
		await get_tree().process_frame
		if scene()==null:stop_reason="旧场次已销毁";stopped=true;break
		if not stopped and fingerprint()!=committed_state:stop("演出期间局面已变化，后续未执行")
	last_result={"ok":not stopped and receipts.size()==q.cells.size()+1,"reason":stop_reason,"receipts":receipts,"actual_cost":actual_cost}
	running=false;changed.emit()
	var s: Variant=scene()
	if s!=null:s.advance165_finished.call_deferred()
	return last_result
func _exit_tree() -> void:
	stopped=true;stop_reason="旧场次已销毁";_quotes.clear()
