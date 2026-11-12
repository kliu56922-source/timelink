extends Node
## Small, current-turn intent queue. Native battle/scene remain the only rule owners.
signal step_finished(index: int,receipt: Dictionary)
signal changed
var _scene: WeakRef
var running := false
var stopped := false
var stop_reason := ""
var last_result: Dictionary={}
var _quotes: Dictionary={}
var _serial := 0
func setup(scene: Node) -> void:_scene=weakref(scene)
func owner_scene() -> Variant:
	var s: Variant=_scene.get_ref() if _scene!=null else null
	return s if is_instance_valid(s) and s.is_inside_tree() else null
func fingerprint() -> Dictionary:
	var s: Variant=owner_scene()
	if s==null:return {}
	var runtime: Dictionary={}
	for z: String in ["hand","field","traps"]:runtime[z]=s.context.player.get(z).map(func(c):return c.get_instance_id())
	runtime.deck=s.context.player.deck.map(func(c):return c.get_instance_id())
	runtime.structures=s.context.tactical_structure_board_state.get_revision()
	runtime.facilities=s.context.player.traps.map(func(c):return s.battle.get_building_state(c).duplicate(true))
	for side: String in ["player","enemy"]:
		for c: CardData in s.context.get(side).field:
			var state: Variant=s.battle._state_for_card(c)
			runtime[str(c.get_instance_id())]=state.snapshot() if state!=null else {}
	var econ: Dictionary=s.battle.get_command_economy_snapshot("player")
	return {"scene":s.get_instance_id(),"runtime":runtime,"turn":s.context.turn_count,"hp":s.context.player.hp,"boss":s.context.enemy.hp,"shield":s.context.player.shield,"boss_shield":s.context.enemy.boss_shield,"heat":s.context.od_mode.current_od,"load":s.context.od_mode.load,"played":s.context.cards_played_this_turn,"engine":s.context.od_mode.get_engine_layer(),"points":s.context.od_mode.engine_total_points,"depth":s.context.depth_pressure,"pending":s.context.pending_depth_reduction,"command":econ.get("current_points",0),"gross":econ.get("gross_spent",0),"route":s.context.chain_system.current_route_id,"step":s.context.chain_system.current_step,"route_history":s.context.chain_system.route_history.duplicate(),"tactical_chain":s.context.chain_system.get_tactical_chain_snapshot().duplicate(true)}
func resolve(uid: int,zone: String) -> CardData:
	var s: Variant=owner_scene()
	if s==null:return null
	var collection: Array=s.context.enemy.field if zone=="enemy" else s.context.player.get(zone)
	for c: CardData in collection:
		if is_instance_valid(c) and c.get_instance_id()==uid:return c
	return null
func _guard() -> String:
	var s: Variant=owner_scene()
	if s==null:return "场次已销毁"
	if s.battle_ended or s.context.player.hp<=0 or s.context.enemy.hp<=0:return "战斗已结束"
	if not s.axis155_native_ready():return "等待原动作完成或己方行动窗口"
	if s._is_monster_summon_interaction_active() or s._is_piece_selection_active() or s._is_lane_selection_active():return "请先完成或取消当前手动选取"
	return ""
func _hand(id: String) -> CardData:
	var s: Variant=owner_scene()
	if s!=null:
		for c: CardData in s.context.player.hand:
			if c.card_id==id:return c
	return null
func _status(step: Dictionary) -> Dictionary:
	var s: Variant=owner_scene()
	if s==null:return {"ok":false,"reason":"旧场次不可用"}
	var c: CardData=resolve(step.uid,step.zone)
	if c==null:return {"ok":false,"reason":"原来源已离场或不在手牌"}
	match step.kind:
		"build":return s.battle.get_card_piece_status(c,&"play",{"type":&"cell","cell":step.cell},null,{})
		"summon":return s.battle.get_monster_summon_cell_status(c,step.cell,&"player")
		"facility":return s.timing_advisor.inspect_facility(c,int(step.next_cost))
		"move":
			var status: Dictionary=s.battle.get_unit_command_status(c,"move",step.cell)
			if step.cell not in status.get("legal_cells",[]):return {"ok":false,"reason":"所选移动格不可达"}
			return _command_projection(status)
		"attack":
			var target: CardData=resolve(step.target_uid,"enemy")
			if target==null or s.battle.get_unit_cell(target)!=step.cell:return {"ok":false,"reason":"原目标已消失或移位"}
			var command: Dictionary=s.battle.get_unit_command_status(c,"attack",target)
			if not command.get("siege_plan",{}).is_empty():return {"ok":false,"reason":"受围护目标需要手动确认攻城；小轴仅支持普通攻击"}
			if not s.battle.can_monster_attack_target(c,target).get("ok",false):return {"ok":false,"reason":"原目标不可攻击"}
			return _command_projection(command)
	return {"ok":false,"reason":"小轴不支持该动作"}
func _command_projection(status: Dictionary) -> Dictionary:
	# Same read-only threshold forecast as the existing construction timing advisor.
	var s: Variant=owner_scene()
	var economy: Dictionary=s.battle.get_command_economy_snapshot("player")
	var gain:=0
	for threshold: int in s.battle.tactical_command_economy_rules.get_depth_thresholds():
		if threshold>int(economy.gross_spent) and threshold<=int(economy.gross_spent)+int(status.get("cost",0)) and threshold not in economy.crossed_thresholds:gain+=s.battle.tactical_command_economy_rules.get_depth_per_threshold()
	status.depth_after=s.context.depth_pressure+maxi(0,gain-s.context.pending_depth_reduction)
	return status
func _quote(title: String,steps: Array) -> Dictionary:
	var reason:=_guard()
	if running or not reason.is_empty():return {"ok":false,"reason":reason if not reason.is_empty() else "小轴执行中"}
	var quotes: Array=[]
	for step: Dictionary in steps:
		var q:=_status(step)
		if not q.get("ok",false):return {"ok":false,"reason":str(q.get("reason",q.get("reason_code","当前条件不满足")))}
		quotes.append(q.duplicate(true))
	_serial+=1
	if _quotes.size()>=8:_quotes.clear()
	var q: Dictionary={"ok":true,"id":_serial,"title":title,"signature":fingerprint(),"steps":steps.duplicate(true),"quotes":quotes,"max_command":int(quotes[-1].get("cost",0)),"max_depth":int(quotes[-1].get("depth_after",owner_scene().context.depth_pressure))}
	_quotes[_serial]=q.duplicate(true)
	return q
func prepare_establish(build_cell: Vector2i,unit_cell: Vector2i) -> Dictionary:
	var b:=_hand("P05");var u:=_hand("S01")
	if b==null or u==null:return {"ok":false,"reason":"需手持炉基座P05与锅炉学徒S01；不补牌"}
	if build_cell==unit_cell:return {"ok":false,"reason":"建筑与学徒必须选择不同格"}
	return _quote("建立阵地",[{"kind":"build","uid":b.get_instance_id(),"zone":"hand","cell":build_cell},{"kind":"summon","uid":u.get_instance_id(),"zone":"hand","cell":unit_cell}])
func prepare_cooling(facility: CardData,actor: CardData,verb: String,cell: Vector2i) -> Dictionary:
	if not is_instance_valid(facility) or facility.card_id!="P13" or not is_instance_valid(actor) or verb not in ["move","attack"]:return {"ok":false,"reason":"选择完工热沉、已有单位与移动/普通攻击"}
	var s: Variant=owner_scene()
	if s==null:return {"ok":false,"reason":"场次已离开"}
	var step: Dictionary={"kind":verb,"uid":actor.get_instance_id(),"zone":"field","cell":cell}
	if verb=="attack":
		var target: CardData=s.battle.get_unit_at_cell(cell)
		if target==null or target not in s.context.enemy.field:return {"ok":false,"reason":"需明确选择敌方棋子；不自动换目标或攻击核心"}
		step.target_uid=target.get_instance_id()
	var command:=_status(step)
	if not command.get("ok",false):return {"ok":false,"reason":str(command.get("reason",command.get("reason_code","单位行动不可用")))}
	return _quote("冷却后行动",[{"kind":"facility","uid":facility.get_instance_id(),"zone":"traps","next_cost":int(command.cost)},step])
func begin_check(q: Dictionary) -> Dictionary:
	if running:return {"ok":false,"reason":"已有小轴执行中"}
	if not q.get("ok",false) or not _quotes.has(q.get("id")) or _quotes[q.id]!=q:return {"ok":false,"reason":"预览已失效或已提交，请重新选择"}
	var reason:=_guard()
	if not reason.is_empty():return {"ok":false,"reason":reason}
	if q.signature!=fingerprint():return {"ok":false,"reason":"局面已变化，请重做预览"}
	return {"ok":true}
func stop(reason: String="manual_stop") -> void:
	stopped=true;stop_reason=reason;_quotes.clear();changed.emit()
func execute(q: Dictionary) -> Dictionary:
	var gate:=begin_check(q)
	if not gate.ok:return gate
	_quotes.erase(q.id);running=true;stopped=false;stop_reason="";changed.emit()
	var receipts: Array=[]
	for i in range(q.steps.size()):
		if stopped:break
		var reason:=_guard()
		if not reason.is_empty():stop(reason);break
		if fingerprint().turn!=q.signature.turn:stop("回合已变化");break
		var step: Dictionary=q.steps[i];var status:=_status(step)
		if not status.get("ok",false):stop(str(status.get("reason",status.get("reason_code","条件已失效"))));break
		if step.kind in ["move","attack"]:
			var live: Dictionary=fingerprint().runtime
			if live.get(str(step.uid))!=q.signature.runtime.get(str(step.uid)) or (step.kind=="attack" and live.get(str(step.target_uid))!=q.signature.runtime.get(str(step.target_uid))):stop("原单位或目标状态已改变");break
		if step.kind in ["move","attack"] and (int(status.get("cost",0))>q.max_command or int(status.get("depth_after",0))>q.max_depth):stop("费用或Depth风险超出本次授权");break
		var s: Variant=owner_scene()
		var before: Dictionary=fingerprint()
		var r: Dictionary=await s.axis155_commit(step)
		var after: Dictionary=fingerprint()
		receipts.append({"kind":step.kind,"ok":r.get("ok",false),"reason":str(r.get("reason",r.get("reason_code",""))),"heat_delta":after.get("heat",0)-before.get("heat",0),"command_spent":after.get("gross",0)-before.get("gross",0),"depth_before":before.get("depth",0),"depth_after":after.get("depth",0),"pending_before":before.get("pending",0),"pending_after":after.get("pending",0)})
		if not r.get("ok",false):stop("原动作未提交");break
		step_finished.emit(i,receipts[-1]);changed.emit()
		# A stable boundary for stop/navigation; never roll back earlier committed actions.
		await get_tree().process_frame
	last_result={"ok":not stopped and receipts.size()==q.steps.size(),"reason":stop_reason,"receipts":receipts};running=false;changed.emit()
	var s: Variant=owner_scene()
	if s!=null:s.axis155_sequence_finished.call_deferred()
	return last_result
func _exit_tree() -> void:
	stopped=true;stop_reason="scene_disposed";_quotes.clear()
