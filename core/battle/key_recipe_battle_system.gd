extends "res://core/battle/advance_weakpoint_battle_system.gd"
## A closed, alternative root effect. Ordinary single-card play stays inherited.
const RECIPE166_PATH="res://data/experiments/phase166_combo_recipes.json"
var recipe166_definition: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(RECIPE166_PATH))
var _recipe166_used:=0
var _recipe166_generated:=0
var _recipe166_committing:=false
var _recipe166_build_material: CardData
var _recipe166_derived: Dictionary={}
func recipe166_snapshot() -> Dictionary:
	return {"used":_recipe166_used,"generated_total":_recipe166_generated,"live":_recipe166_derived.keys().duplicate(),"battle":get_instance_id()}
func recipe166_key(id: String) -> CardData:
	for c: CardData in context.player.hand:
		if c.card_id==id:return c
	return null
func _recipe166_refusal(reason: String,layout: Array=[]) -> Dictionary:
	return {"ok":false,"reason":reason,"layout":layout}
func recipe166_preview(direction: String,anchor: Vector2i) -> Dictionary:
	if context==null or _is_battle_terminal():return _recipe166_refusal("战斗已结束")
	if _recipe166_committing:return _recipe166_refusal("配方正在结算")
	if not get_command_economy_snapshot("player").get("turn_open",false):return _recipe166_refusal("等待己方行动窗口")
	if context.is_abyss_locked():return _recipe166_refusal("Depth制动锁定；先排压")
	if _recipe166_used>=int(recipe166_definition.per_battle_limit):return _recipe166_refusal("炉心阵地本场已发动；离场不返还名额")
	if not recipe166_definition.formations.has(direction):return _recipe166_refusal("请选择护臂侧或阀门侧阵型")
	var familiar:=recipe166_key("P02");var foundation:=recipe166_key("P05")
	if familiar==null or foundation==null:return _recipe166_refusal("需同时手持燃芯使魔P02与炉基座P05；可单独使用已有牌")
	var form: Dictionary=recipe166_definition.formations[direction]
	var build_cell: Vector2i=anchor+Vector2i(int(form.foundation_offset[0]),int(form.foundation_offset[1]))
	var leaf_cell: Vector2i=anchor+Vector2i(int(form.apprentice_offset[0]),int(form.apprentice_offset[1]))
	var layout: Array=[{"id":"P02","name":"燃芯使魔","cell":anchor},{"id":"P05","name":"炉基座","cell":build_cell},{"id":"D166_S01","name":"锅炉学徒·衍生","cell":leaf_cell}]
	for item: Dictionary in layout:
		if not tactical_grid_rules.get_all_cells().has(item.cell):return _recipe166_refusal("%s会落在棋盘外。请把主锚点向棋盘中间移动，两侧各留一格。"%item.name,layout)
	var limit: int=context.od_mode.get_front_slot_limit()
	if context.player.field.size()+2>limit:return _recipe166_refusal("需空余2个前场名额（当前%d/%d）；不会替换单位"%[context.player.field.size(),limit],layout)
	for key: CardData in [familiar,foundation]:
		var playable: Dictionary=get_card_play_status(key)
		if not playable.get("ok",false):return _recipe166_refusal(str(playable.get("reason","关键牌条件不满足")),layout)
	if not can_pay_command_cost("player",int(recipe166_definition.command_cost)):return _recipe166_refusal("整套需1指令；指令不足，未支付",layout)
	for cell: Vector2i in [anchor,leaf_cell]:
		var legal:=get_monster_summon_cell_status(familiar,cell,&"player")
		if not legal.get("ok",false):return _recipe166_refusal("使魔或学徒落点不可用〔%d列%d行〕：需己方第4/5行空格，且满足部署与占地条件。"%[cell.x+1,cell.y+1],layout)
	var native_build:=get_card_piece_status(foundation,&"play",{"type":&"cell","cell":build_cell},null,{})
	if not native_build.get("ok",false):return _recipe166_refusal("炉基座落点不可用：需己方空格、建筑空位及合法占地；请调整主锚点。",layout)
	var econ:=get_command_economy_snapshot("player")
	var pending: int=context.pending_depth_reduction;var depth: int=context.depth_pressure
	var crossed: Array=[]
	for th: int in tactical_command_economy_rules.get_depth_thresholds():
		if th>int(econ.gross_spent) and th<=int(econ.gross_spent)+int(recipe166_definition.command_cost) and th not in econ.crossed_thresholds:
			crossed.append(th)
			var gain: int=tactical_command_economy_rules.get_depth_per_threshold();var reduction:=mini(pending,gain)
			pending-=reduction;depth=mini(context.get_depth_max_value(),depth+gain-reduction)
	if depth>=context.get_depth_max_value() and context.depth_pressure<context.get_depth_max_value():return _recipe166_refusal("整套会触发新的Depth制动；请先排压再展开",layout)
	return {"ok":true,"recipe_id":recipe166_definition.id,"direction":direction,"anchor":anchor,"layout":layout,"key_ids":["P02","P05"],"key_uids":[familiar.get_instance_id(),foundation.get_instance_id()],"derived_count":1,"command_cost":int(recipe166_definition.command_cost),"load_cost":int(recipe166_definition.load_cost),"heat_before":context.od_mode.current_od,"heat_after":mini(context.od_mode.max_value,context.od_mode.current_od+int(recipe166_definition.heat_gain)),"shield_gain":int(recipe166_definition.shield_gain),"front_after":context.player.field.size()+2,"front_limit":limit,"buildings_after":context.count_active_buildings()+1,"depth_after":depth,"pending_after":pending,"thresholds":crossed,"battle":get_instance_id()}
func play_card(card: CardData,requested_lane: int=-1,requested_cell: Vector2i=INVALID_GRID_CELL,cast_options: Dictionary={}) -> Dictionary:
	if _recipe166_committing:
		# The native structure coordinator uses this exact material once. Its
		# ordinary enter/tutor/heat effects are replaced by the root receipt.
		if card!=_recipe166_build_material or card not in context.player.hand:return {"ok":false,"reason":"配方结算中"}
		context.player.hand.erase(card);context.player.traps.append(card)
		_recipe166_build_material=null
		return {"ok":true,"card":card,"source_kind":&"recipe166_material"}
	return super.play_card(card,requested_lane,requested_cell,cast_options)
func recipe166_commit(approved: Dictionary) -> Dictionary:
	var q:=recipe166_preview(str(approved.get("direction","")),approved.get("anchor",INVALID_GRID_CELL))
	if not q.get("ok",false):return q
	if q!=approved:return _recipe166_refusal("局面或账单已改变，请重新预览")
	var familiar:=recipe166_key("P02");var foundation:=recipe166_key("P05")
	_recipe166_committing=true;_recipe166_build_material=foundation
	# All spatial conditions are preflighted, distinct and committed without
	# yielding. Build first: failure at its guarded boundary consumes no unit/key.
	var built:=execute_card_piece_action(foundation,&"play",{"type":&"cell","cell":q.layout[1].cell},null,{})
	_recipe166_build_material=null
	if not built.get("ok",false):
		_recipe166_committing=false;return _recipe166_refusal("建造未提交；请重新预览")
	var leaf:=_recipe166_make_leaf()
	var deferred_before:=_defer_unit_registration_notifications
	_defer_unit_registration_notifications=true
	for item: Dictionary in [{"card":familiar,"cell":q.layout[0].cell},{"card":leaf,"cell":q.layout[2].cell}]:
		var c: CardData=item.card
		context.player.field.append(c);field_system.add_unit_to_player(c)
		register_unit(c,&"player",true,-1,item.cell)
	context.player.hand.erase(familiar)
	_defer_unit_registration_notifications=deferred_before
	_recipe166_used+=1;_recipe166_generated+=1
	_recipe166_derived[leaf.get_instance_id()]=weakref(leaf)
	var tx:=StringName("recipe166:%d:%d"%[get_instance_id(),_recipe166_used])
	leaf.set_meta("recipe166_source",recipe166_definition.id);leaf.set_meta("recipe166_transaction",tx)
	var econ:=_economy_for_side("player")
	econ.current_points-=int(q.command_cost);econ.gross_spent+=int(q.command_cost)
	var depth_notifications: Array[Dictionary]=[]
	for th: int in q.thresholds:
		econ.crossed_thresholds.append(th)
		depth_notifications.append_array(context.add_depth_pressure(tactical_command_economy_rules.get_depth_per_threshold(),"command_gross_%d"%th,true))
	context.od_mode.load+=int(q.load_cost);context.player.shield+=int(q.shield_gain)
	var heat:=context.add_heat(int(recipe166_definition.heat_gain),&"recipe166:root",tx,{"defer_signal":true,"source_descriptor":context.get_heat_source_descriptor(&"card_effect",&"recipe166:root","P02")})
	var card_notifications: Array[Dictionary]=[]
	for key: CardData in [familiar,foundation]:card_notifications.append_array(context.on_card_played(key,{"defer_signal":true}))
	var result: Dictionary={"ok":true,"transaction":tx,"layout":q.layout.duplicate(true),"key_ids":q.key_ids.duplicate(),"derived_id":leaf.card_id,"derived_uid":leaf.get_instance_id(),"generated":1,"cost":int(q.command_cost),"load_cost":int(q.load_cost),"heat_before":q.heat_before,"heat_after":context.od_mode.current_od,"shield_gain":int(q.shield_gain),"depth_after":context.depth_pressure,"used":_recipe166_used,"events":["root_paid","formation_materialized","conduits_settled"],"structure_fact":built.get("structure_build_fact",{}).duplicate(true)}
	result.key_sources=[{"card_id":familiar.card_id,"card":familiar.card_name,"is_monster":true,"board_cell":q.layout[0].cell},{"card_id":foundation.card_id,"card":foundation.card_name,"is_monster":false,"board_cell":q.layout[1].cell}]
	# Publish only after the complete root effect. A callback cannot re-enter it.
	_emit_unit_state(familiar);_emit_unit_state(leaf)
	context.od_mode.publish_card_notifications(heat.get("notifications",[]))
	context.publish_card_notifications(card_notifications)
	context.publish_depth_notifications(depth_notifications)
	_recipe166_committing=false
	return result
func _recipe166_make_leaf() -> CardData:
	var c:=CardData.new();add_child(c)
	var d: Dictionary=recipe166_definition.derived
	c.card_id=d.id;c.card_name="Recipe166 Apprentice";c.display_name=d.name;c.english_name="Derived Boiler Apprentice"
	c.card_family="monster";c.card_type=CardData.CardType.UNIT;c.board_zone=CardData.BoardZone.FRONT_ROW;c.display_type=CardData.DisplayType.UNIT
	c.unit_power=int(d.power);c.unit_defense=int(d.health);c.engine_gain=0;c.load_cost=0
	c.short_description="衍生1/2；离场移除，不再检索";c.description="炉心阵地生成。计入容量，保留召唤病。无额外热量、抽牌、检索或引擎收益；离场移除，不回收，不返还本场生成次数。"
	# Existing pawn thumbnail is a labelled greybox stand-in, not new formal art.
	c.thumb_path="res://assets/cards/thumbs/card_p03_spark_vanguard.png"
	for zone: String in ["hand","deck","field","graveyard"]:
		for original: CardData in context.player.get(zone):
			if original.card_id=="S01":
				c.art=original.art;c.art_path=original.art_path;c.detail_path=original.detail_path
				if not original.thumb_path.is_empty():c.thumb_path=original.thumb_path
	return c
func get_unit_tactical_pattern(card: CardData) -> StringName:
	if is_instance_valid(card) and card.card_id=="D166_S01":return tactical_pattern_snapshot.get_pattern_id(&"S01")
	return super.get_unit_tactical_pattern(card)
func get_unit_movement_pattern(card: CardData) -> StringName:
	if is_instance_valid(card) and card.card_id=="D166_S01":return monster_combat_rules.get_movement_pattern(&"S01")
	return super.get_unit_movement_pattern(card)
func recipe166_prune() -> void:
	if _recipe166_committing or context==null:return
	for uid: int in _recipe166_derived.keys():
		var c: CardData=_recipe166_derived[uid].get_ref()
		if not is_instance_valid(c):_recipe166_derived.erase(uid);continue
		if c in context.player.field and get_unit_current_hp(c)>0:continue
		for zone: String in ["hand","deck","discard","graveyard","field","traps"]:context.player.get(zone).erase(c)
		graveyard_system.player_graveyard.erase(c);field_system.player_field.erase(c);unregister_unit(c)
		_recipe166_derived.erase(uid);c.queue_free()
func move_card_to_graveyard_once(card: CardData) -> Dictionary:
	if is_instance_valid(card) and card.card_id=="D166_S01":
		# Keep a reference until the scene's post-action prune safely retires it.
		context.player.field.erase(card);field_system.player_field.erase(card);unregister_unit(card)
		return {"ok":true,"moved":true,"removed_derived":true}
	return super.move_card_to_graveyard_once(card)
