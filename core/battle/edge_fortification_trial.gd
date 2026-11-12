extends RefCounted
## Opt-in102. Shared-edge entities do not occupy a cell or use hand-card identity.
const DIRECTIONS := {&"north":Vector2i(0,-1),&"east":Vector2i(1,0),&"south":Vector2i(0,1),&"west":Vector2i(-1,0)}
var _battle: WeakRef
var _engineering: RefCounted
var _edges: Dictionary={}
var _revision:=0
var _begun_turn:=-1
var _passages: Array[Dictionary]=[]
var _intent: Dictionary={}
var _authorized_uid:=0

func _init(battle: Variant, engineering: RefCounted) -> void:
	_battle=weakref(battle);_engineering=engineering
	battle.edge_fortification_trial=self

func _key(cell: Vector2i, edge: StringName) -> StringName:
	return _battle.get_ref().context.tactical_structure_board_state.canonical_edge_key(cell,edge)

func snapshot() -> Dictionary:
	return {"edges":_edges.duplicate(true),"revision":_revision,"passages":_passages.duplicate(true),"intent":_intent.duplicate(true)}

func get_edge(cell: Vector2i, edge: StringName) -> Dictionary:
	return (_edges.get(_key(cell,edge),{}) as Dictionary).duplicate(true)

func inspect(cell: Vector2i, edge: StringName, kind: StringName) -> Dictionary:
	var reason: String=_engineering._guard()
	if reason!="":return {"ok":false,"reason_code":reason}
	var b: Variant=_battle.get_ref()
	if not DIRECTIONS.has(edge) or kind not in [&"wall",&"gate"]:return {"ok":false,"reason_code":"invalid_edge_kind"}
	var other: Vector2i=cell+DIRECTIONS[edge]
	if not b.tactical_grid_rules.is_cell_in_bounds(cell) or not b.tactical_grid_rules.is_cell_in_bounds(other):return {"ok":false,"reason_code":"edge_out_of_bounds"}
	if not b.tactical_grid_rules.is_normal_summon_cell(&"player",cell) and not b.tactical_grid_rules.is_normal_summon_cell(&"player",other):return {"ok":false,"reason_code":"edge_outside_build_territory"}
	if b.building_footprint_trial!=null:
		var left: Dictionary=b.get_structure_at_cell(cell)
		var right: Dictionary=b.get_structure_at_cell(other)
		if not left.is_empty() and not right.is_empty() and left.structure_id==right.structure_id and b.building_footprint_trial.owns_solid_source(int(left.source_runtime_id)):return {"ok":false,"reason_code":"edge_inside_solid_footprint"}
	if _engineering._used_turn==b.context.turn_count:return {"ok":false,"reason_code":"already_built_this_turn"}
	if _engineering._admission_count()>=_engineering.TOTAL_CAP:return {"ok":false,"reason_code":"engineering_total_cap"}
	var native: Dictionary=b.context.tactical_structure_board_state.get_module_at_edge(cell,edge)
	if int(native.get("integrity_current",0))>0:return {"ok":false,"reason_code":"native_edge_occupied"}
	var current:=get_edge(cell,edge)
	var conversion: bool=not current.is_empty() and int(current.hp)>0
	if conversion and (current.kind==kind or current.stage!="complete"):return {"ok":false,"reason_code":"edge_already_occupied"}
	var cost:=1 if conversion else (3 if kind==&"gate" else 2)
	if not b.can_pay_command_cost("player",cost):return {"ok":false,"reason_code":"insufficient_command_points"}
	var economy: Dictionary=b.get_command_economy_snapshot("player")
	var crossed: Array[int]=[]
	for threshold: int in b.tactical_command_economy_rules.get_depth_thresholds():
		if threshold>int(economy.gross_spent) and threshold<=int(economy.gross_spent)+cost and threshold not in economy.crossed_thresholds:crossed.append(threshold)
	var gain: int=crossed.size()*b.tactical_command_economy_rules.get_depth_per_threshold()
	if b.context.depth_pressure+maxi(0,gain-int(b.context.pending_depth_reduction))>=b.context.get_depth_max_value():return {"ok":false,"reason_code":"payment_backlash_boundary"}
	return {"ok":true,"reason_code":"ok","cell":cell,"other":other,"edge":edge,"key":_key(cell,edge),"kind":kind,"conversion":conversion,"command_cost":cost,"turn":b.context.turn_count,"points_before":economy.current_points,"gross_before":economy.gross_spent,"depth_before":b.context.depth_pressure,"crossed":crossed,"revision":_revision,"before":current}

func execute(cell: Vector2i, edge: StringName, kind: StringName, expected: Dictionary={}) -> Dictionary:
	var quote:=inspect(cell,edge,kind)
	if not quote.ok:return quote
	if not expected.is_empty() and quote!=expected:return {"ok":false,"reason_code":"edge_quote_stale"}
	var b: Variant=_battle.get_ref()
	_engineering._lock(true);_engineering._used_turn=b.context.turn_count;_engineering._serial+=1
	var economy: Dictionary=b._economy_for_side("player")
	economy.current_points-=int(quote.command_cost);economy.gross_spent+=int(quote.command_cost)
	for threshold: int in quote.crossed:economy.crossed_thresholds.append(threshold)
	_revision+=1
	var body: Dictionary=quote.before.duplicate(true)
	if not quote.conversion:
		body={"id":"edge:%d:%d"%[get_instance_id(),_engineering._serial],"key":quote.key,"a":cell,"b":quote.other,"owner":&"player","hp":1,"max_hp":1,"stage":"construction","due_turn":b.context.turn_count+1}
	body.kind=kind;body.revision=_revision;_edges[quote.key]=body
	for threshold: int in quote.crossed:b.context.add_depth_pressure(b.tactical_command_economy_rules.get_depth_per_threshold(),"command_gross_%d"%threshold)
	var receipt:={"ok":true,"reason_code":"edge_paid","transaction_id":body.id+":order:%d"%_engineering._serial,"command_cost":quote.command_cost,"edge":body.duplicate(true),"conversion":quote.conversion,"points_after":economy.current_points,"depth_after":b.context.depth_pressure}
	_engineering._receipts.append(receipt.duplicate(true));_engineering._lock(false)
	return receipt

func begin_player_turn() -> void:
	if _engineering._guard()!="":return
	var b: Variant=_battle.get_ref()
	if _begun_turn==b.context.turn_count:return
	_begun_turn=b.context.turn_count
	for body: Dictionary in _edges.values():
		if body.stage=="construction" and int(body.hp)>0 and int(body.due_turn)<=_begun_turn:
			body.hp=3;body.max_hp=3;body.stage="complete";_revision+=1;body.revision=_revision
	prepare_boss_intent()

func _between(a: Vector2i, b: Vector2i) -> Dictionary:
	for edge: StringName in DIRECTIONS:
		if a+DIRECTIONS[edge]==b:return get_edge(a,edge)
	return {}

func _passable(a: Vector2i, b: Vector2i, side: StringName) -> bool:
	var body:=_between(a,b)
	return body.is_empty() or int(body.hp)<=0 or (body.kind==&"gate" and body.owner==side)

func can_traverse(origin: Vector2i, target: Vector2i, side: StringName) -> bool:
	return not _ground_path(origin,target,side).is_empty()

func _ground_path(origin: Vector2i, target: Vector2i, side: StringName) -> Array[Vector2i]:
	# Monotonic cardinal paths prevent diagonal corner clipping without changing offsets.
	var frontier: Array[Vector2i]=[origin]
	var seen: Dictionary={origin:true}
	var previous: Dictionary={}
	while not frontier.is_empty():
		var cell: Vector2i=frontier.pop_front()
		if cell==target:
			var path: Array[Vector2i]=[target]
			while path[0]!=origin:path.push_front(previous[path[0]])
			return path
		var steps: Array[Vector2i]=[]
		if cell.x!=target.x:steps.append(cell+Vector2i(signi(target.x-cell.x),0))
		if cell.y!=target.y:steps.append(cell+Vector2i(0,signi(target.y-cell.y)))
		for next: Vector2i in steps:
			if not seen.has(next) and _passable(cell,next,side):seen[next]=true;previous[next]=cell;frontier.append(next)
	return []

func blocks_close_attack(origin: Vector2i, target: Vector2i) -> bool:
	var body:=_between(origin,target)
	return not body.is_empty() and int(body.hp)>0

func cover_reduction(attacker: CardData, target: CardData, amount: int, family: StringName=&"ordinary") -> int:
	if family!=&"ordinary" or amount<=0 or attacker==null or target==null:return 0
	var b: Variant=_battle.get_ref()
	var target_state: Variant=b._state_for_card(target)
	if target_state==null:return 0
	var origin: Vector2i=b.get_unit_cell(attacker)
	var cell: Vector2i=b.get_unit_cell(target)
	var delta: Vector2i=origin-cell
	if absi(delta.x)+absi(delta.y)<=1:return 0
	for body: Dictionary in _edges.values():
		if int(body.hp)<=0 or body.owner!=target_state.owner_side or cell not in [body.a,body.b]:continue
		var normal: Vector2i=(body.b if cell==body.a else body.a)-cell
		var forward: int=delta.x*normal.x+delta.y*normal.y
		var lateral: int=absi(delta.x*normal.y-delta.y*normal.x)
		if forward>0 and lateral<=forward:return mini(1,amount)
	return 0

func record_passage(card: CardData, origin: Vector2i, target: Vector2i) -> void:
	var b: Variant=_battle.get_ref()
	var side: StringName=b._state_for_card(card).owner_side
	# Record only actual crossed gates on a valid path; no open persistent state.
	var path:=_ground_path(origin,target,side)
	for i: int in range(1,path.size()):
		var body:=_between(path[i-1],path[i])
		if not body.is_empty() and int(body.hp)>0 and body.kind==&"gate":_passages.append({"edge_id":body.id,"actor_runtime_id":card.get_instance_id(),"from":path[i-1],"to":path[i],"opened_for_owner":side==body.owner,"closed_after_commit":true})

func attack_status(actor: CardData, target: Dictionary, announcement: bool=false) -> Dictionary:
	var b: Variant=_battle.get_ref()
	var denied:={"ok":false,"reason_code":&"edge_attack_unavailable"}
	if actor==null or b.context.player.hp<=0 or b.context.enemy.hp<=0:return denied
	var state: Variant=b._state_for_card(actor)
	if state==null or state.is_dead() or (not announcement and state.summoned_this_turn):return denied
	var body: Dictionary=_edges.get(target.get("key",&""),{})
	if body.is_empty() or int(body.hp)<=0 or body.id!=target.get("edge_id") or int(body.revision)!=int(target.get("revision",-1)):return {"ok":false,"reason_code":&"edge_target_stale"}
	if state.owner_side==body.owner:return {"ok":false,"reason_code":&"edge_friendly_target"}
	if state.owner_side==&"boss" and not announcement and _authorized_uid!=actor.get_instance_id():return {"ok":false,"reason_code":&"boss_siege_requires_intent"}
	if b.get_unit_cell(actor) not in [body.a,body.b]:return denied
	# Announce the coming boss window; last window's actions reset later natively.
	if not announcement and (not b.can_monster_attack(actor).get("ok",false) or b.get_monster_attacks_remaining(actor)<=0 or not b.get_unit_combat_state(actor).get("action_available",false)):return denied
	return {"ok":true,"reason_code":&"ok","edge_fortification":true,"requested_target":target.duplicate(true),"resolved_target":target.duplicate(true),"actor_runtime_id":actor.get_instance_id(),"turn":b.context.turn_count,"edge_before":body.duplicate(true)}

func resolve_attack(actor: CardData, plan: Dictionary) -> Dictionary:
	var b: Variant=_battle.get_ref()
	var ref: Dictionary=plan.resolved_target
	var body: Dictionary=_edges.get(ref.key,{})
	if body.is_empty() or body.id!=ref.edge_id or int(body.revision)!=int(ref.revision) or int(body.hp)<=0 or int(plan.actor_runtime_id)!=actor.get_instance_id() or int(plan.turn)!=b.context.turn_count:return {"ok":false,"reason_code":&"edge_target_stale"}
	body.hp-=1;_revision+=1;body.revision=_revision
	if int(body.hp)<=0:body.stage="destroyed"
	b.mark_monster_attacked(actor,true)
	return {"ok":true,"result":"edge_hit","structure_steps":1,"edge_before":plan.edge_before.duplicate(true),"edge_after":body.duplicate(true),"unit_damage":0,"transaction_id":"edge_hit:%s:%d"%[body.id,_revision]}

func targets_for(actor: CardData, announcement: bool=false) -> Array[Dictionary]:
	var targets: Array[Dictionary]=[]
	for body: Dictionary in _edges.values():
		var ref:={"target_kind":&"edge_fortification","key":body.key,"edge_id":body.id,"revision":body.revision}
		if attack_status(actor,ref,announcement).ok:targets.append(ref)
	return targets

func prepare_boss_intent() -> void:
	var b: Variant=_battle.get_ref();_intent={}
	for actor: CardData in b.context.enemy.field:
		if actor.card_id!="B-07":continue
		var targets:=targets_for(actor,true)
		if not targets.is_empty():_intent={"turn":b.context.turn_count,"actor_runtime_id":actor.get_instance_id(),"target":targets[0]};return

func resolve_boss_intent() -> Dictionary:
	var b: Variant=_battle.get_ref()
	if _intent.is_empty() or _intent.get("resolved",false) or b.get_command_economy_snapshot("player").get("turn_open",false) or int(_intent.turn)!=b.context.turn_count or b.context._boss_siege_tactical_window_turn!=b.context.turn_count:return {"ok":false,"reason_code":"edge_no_complete_intent_window"}
	_intent.resolved=true
	for actor: CardData in b.context.enemy.field:
		if actor.get_instance_id()!=int(_intent.actor_runtime_id):continue
		_authorized_uid=actor.get_instance_id()
		var result: Dictionary=b.execute_unit_command(actor,"attack",_intent.target)
		_authorized_uid=0;return result
	return {"ok":false,"reason_code":"edge_intent_actor_missing"}
