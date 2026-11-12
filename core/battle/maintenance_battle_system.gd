extends "res://core/battle/deployment_combat_battle_system.gd"
## A small alternative use of real key cards. No native enter/tutor effects.
var _support_used:=0
var _support_replacements:=0
var _support_round:=-1
var _support_committing:=false
func support166_snapshot() -> Dictionary:
	return {"used":_support_used,"replacements":_support_replacements,"last_round":_support_round,"battle":get_instance_id()}
func support166_source(uid: int) -> CardData:
	for c: CardData in context.player.hand:
		if c.get_instance_id()==uid and c.card_id in ["P02","P05"]:return c
	return null
func _support_refuse(reason: String) -> Dictionary:return {"ok":false,"reason":reason}
func support166_signature() -> Dictionary:
	var units: Array=[]
	for c: CardData in context.player.field+context.enemy.field:
		var state: Variant=_state_for_card(c)
		units.append({"uid":c.get_instance_id(),"state":state.snapshot() if state!=null else {}})
	var hand: Array=[]
	for c: CardData in context.player.hand:hand.append(c.get_instance_id())
	return {"hand":hand,"units":units,"economy":get_command_economy_snapshot("player"),"phase":opening166b.snapshot(),"support":support166_snapshot(),"recipe":recipe166_snapshot(),"heat":context.od_mode.current_od,"load":context.od_mode.load,"depth":context.depth_pressure,"pending":context.pending_depth_reduction,"player_hp":context.player.hp,"shield":context.player.shield,"boss_hp":context.enemy.hp,"structures":context.tactical_structure_board_state.get_snapshot()}
func support166_preview(mode: String,source_uid: int,target: Vector2i) -> Dictionary:
	if context==null or _is_battle_terminal():return _support_refuse("战斗已结束")
	if _support_committing or _recipe166_committing:return _support_refuse("效果正在结算")
	if preparation_active166b():return _support_refuse("首回合先部署；维护在交战后启用")
	if not get_command_economy_snapshot("player").get("turn_open",false):return _support_refuse("等待己方行动窗口")
	if context.is_abyss_locked():return _support_refuse("Depth制动锁定；先排压")
	if _support_used>=2:return _support_refuse("维护本场已用2/2；离场不返还额度")
	if _support_round==opening166b.player_round:return _support_refuse("本回合已维护；下回合再用，本场最多两次")
	var source:=support166_source(source_uid)
	if source==null:return _support_refuse("选择手中的燃芯使魔或炉基座作为维护素材")
	if not can_pay_command_cost("player",1):return _support_refuse("维护需1指令；指令不足，未支付")
	if context.od_mode.would_overload(1):return _support_refuse("维护负荷+1会超过当前负荷上限")
	if mode not in ["repair","replace"]:return _support_refuse("选择修复友军或补回学徒")
	var target_uid:=0;var amount:=0;var generated:=0;var name:="锅炉学徒·衍生"
	if mode=="repair":
		var unit:=get_unit_at_cell(target);var state: Variant=_state_for_card(unit)
		if unit==null or unit not in context.player.field or state==null or state.current_hp<=0:return _support_refuse("修复要选择场上存活友方单位；不修复核心或建筑")
		amount=mini(2,state.max_hp-state.current_hp)
		if amount<=0:return _support_refuse("该单位已满血；不会消耗维护素材")
		target_uid=unit.get_instance_id();name=unit.get_display_name()
	else:
		if _recipe166_used==0:return _support_refuse("先建立炉心阵地；补位只恢复曾生成的学徒")
		if _support_replacements>=1:return _support_refuse("学徒补位本场已用1/1；再次离场也不返还")
		for unit: CardData in context.player.field:
			if unit.card_id=="D166_S01" and get_unit_current_hp(unit)>0:return _support_refuse("衍生学徒仍在场；不能追加第二个")
		if context.player.field.size()>=context.od_mode.get_front_slot_limit():return _support_refuse("前场容量已满；不会替换现有单位")
		# Use a unit-shaped source for the native cell query; a P05 material is a building.
		var probe:=CardData.new();probe.card_type=CardData.CardType.UNIT;probe.card_family="monster";probe.board_zone=CardData.BoardZone.FRONT_ROW
		var legal:=get_monster_summon_cell_status(probe,target,&"player");probe.free()
		if not legal.get("ok",false):return _support_refuse("补位需己方第4/5行合法空格；检查占地、地形与部署限制")
		generated=1
	var econ:=get_command_economy_snapshot("player");var crossed: Array=[]
	var depth: int=context.depth_pressure;var pending: int=context.pending_depth_reduction
	for threshold: int in tactical_command_economy_rules.get_depth_thresholds():
		if threshold>int(econ.gross_spent) and threshold<=int(econ.gross_spent)+1 and threshold not in econ.crossed_thresholds:
			crossed.append(threshold)
			var gain: int=tactical_command_economy_rules.get_depth_per_threshold();var reduction:=mini(pending,gain)
			pending-=reduction;depth=mini(context.get_depth_max_value(),depth+gain-reduction)
	if depth>=context.get_depth_max_value():return _support_refuse("本次维护会触发Depth制动；先排压")
	return {"ok":true,"mode":mode,"source_uid":source_uid,"source_name":source.get_display_name(),"target":target,"target_uid":target_uid,"heal":amount,"generated":generated,"command_cost":1,"heat_before":context.od_mode.current_od,"heat_after":mini(context.od_mode.max_value,context.od_mode.current_od+2),"load_cost":1,"depth_after":depth,"thresholds":crossed,"used_after":_support_used+1,"layout":[{"name":name,"cell":target}],"signature":support166_signature()}
func support166_commit(approved: Dictionary) -> Dictionary:
	var q:=support166_preview(str(approved.get("mode","")),int(approved.get("source_uid",0)),approved.get("target",INVALID_GRID_CELL))
	if not q.get("ok",false):return q
	if q!=approved:return _support_refuse("局面或账单已改变，请重新预览")
	var source:=support166_source(q.source_uid);var affected: CardData=get_unit_at_cell(q.target)
	_support_committing=true
	context.player.hand.erase(source)
	# Material never entered the board; no building destruction/enter callbacks.
	context.player.graveyard.append(source);graveyard_system.player_graveyard.append(source)
	_support_used+=1;_support_round=opening166b.player_round
	var tx:=StringName("recipe166:maintenance:%d:%d"%[get_instance_id(),_support_used])
	if q.mode=="replace":
		affected=_recipe166_make_leaf();context.player.field.append(affected);field_system.add_unit_to_player(affected)
		var deferred_before:=_defer_unit_registration_notifications;_defer_unit_registration_notifications=true
		register_unit(affected,&"player",true,-1,q.target);_defer_unit_registration_notifications=deferred_before
		_support_replacements+=1;_recipe166_generated+=1;_recipe166_derived[affected.get_instance_id()]=weakref(affected)
		affected.set_meta("recipe166_source","maintenance166c");affected.set_meta("recipe166_transaction",tx)
	else:_state_for_card(affected).heal(int(q.heal))
	var economy:=_economy_for_side("player");economy.current_points-=1;economy.gross_spent+=1
	var notifications: Array[Dictionary]=[]
	for threshold: int in q.thresholds:
		economy.crossed_thresholds.append(threshold)
		notifications.append_array(context.add_depth_pressure(tactical_command_economy_rules.get_depth_per_threshold(),"command_gross_%d"%threshold,true))
	context.od_mode.load+=1
	var heat:=context.add_heat(2,&"maintenance166c:root",tx,{"defer_signal":true,"source_descriptor":context.get_heat_source_descriptor(&"card_effect",&"maintenance166c:root",source.card_id)})
	var card_notifications:=context.on_card_played(source,{"defer_signal":true})
	var receipt: Dictionary={"ok":true,"transaction":tx,"mode":q.mode,"source_uid":q.source_uid,"source_id":source.card_id,"source_name":q.source_name,"target_uid":affected.get_instance_id(),"layout":q.layout.duplicate(true),"healed":q.heal,"generated":q.generated,"cost":1,"load_cost":1,"heat_before":q.heat_before,"heat_after":context.od_mode.current_od,"depth_after":context.depth_pressure,"used":_support_used,"events":["material_paid","repair_settled" if q.mode=="repair" else "replacement_settled"]}
	_emit_unit_state(affected)
	context.od_mode.publish_card_notifications(heat.get("notifications",[]));context.publish_card_notifications(card_notifications);context.publish_depth_notifications(notifications)
	_support_committing=false
	return receipt
func recipe166_preview(direction: String,anchor: Vector2i) -> Dictionary:
	if _support_committing:return _support_refuse("维护正在结算")
	return super.recipe166_preview(direction,anchor)
