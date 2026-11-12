extends RefCounted
## Only presentation/click attributes. No card, unit, resource or zone mutation.
var owner_ref: WeakRef
var tree: SceneTree
var active:=false
var uids: Array=[]
var revealed: Array=[]
var records: Dictionary={}
var _dirty:=true
var prior_terrain167c: Dictionary={}
func arm(owner: Node,ids: Array) -> void:
	finish();owner_ref=weakref(owner);tree=owner.get_tree();uids=ids.duplicate();revealed=[];active=true;_dirty=true
	prior_terrain167c=owner._tactical_terrain_presenter._cell_states.duplicate(true)
	if not tree.node_added.is_connected(_node_added):tree.node_added.connect(_node_added)
	if not RenderingServer.frame_pre_draw.is_connected(enforce):RenderingServer.frame_pre_draw.connect(enforce)
func _node_added(_node: Node) -> void:_dirty=true
func include_ids(ids: Array) -> void:
	for uid in ids:
		if uid not in uids:uids.append(uid)
	_dirty=true
func enforce() -> void:
	if not active:return
	var owner: Variant=owner_ref.get_ref() if owner_ref!=null else null
	if not is_instance_valid(owner):return
	if _dirty:
		var structures: Dictionary={}
		for uid: int in uids:
			var id: StringName=owner.context.tactical_structure_board_state.get_source_structure_id(uid)
			if id!=&"":structures[str(id)]=uid
		_collect(owner,0,owner,structures)
		# The raised terrain is a separate view, without a source-card tag. Only
		# mask cells whose height this paid recipe actually changed.
		var terrain: Variant=owner._tactical_terrain_presenter
		for uid: int in uids:
			var sid: StringName=owner.context.tactical_structure_board_state.get_source_structure_id(uid)
			if sid==&"":continue
			var cell: Vector2i=owner.context.tactical_structure_board_state.get_foundation_status(sid).get("cell",Vector2i(-1,-1))
			if not terrain._cell_roots.has(cell):continue
			if terrain._cell_states.get(cell,{}).get("height",0)==prior_terrain167c.get(cell,{}).get("height",0):continue
			_collect(terrain._cell_roots[cell],uid,owner,structures)
		_dirty=false
	for record: Dictionary in records.values():
		var node: Variant=record.ref.get_ref()
		if not is_instance_valid(node) or node.is_queued_for_deletion() or record.uid in revealed:continue
		if record.has("visible"):node.visible=false
		if record.has("mouse_filter"):node.mouse_filter=Control.MOUSE_FILTER_IGNORE
		if record.has("layer"):node.collision_layer=0;node.collision_mask=0;node.input_ray_pickable=false
func _collect(node: Node,inherited_uid: int,owner: Node,structures: Dictionary) -> void:
	var uid:=inherited_uid
	var card: CardData=node.get_meta("card") as CardData if node.has_meta("card") else null
	if node is CardUI:card=node.card_data
	if is_instance_valid(card) and card.get_instance_id() in uids and card not in owner.context.player.hand:uid=card.get_instance_id()
	var sid: String=str(node.get_meta("structure_id",""))
	var target: Variant=node.get_meta("target_ref",{})
	if target is Dictionary and not str(target.get("structure_id","")).is_empty():sid=str(target.structure_id)
	if structures.has(sid):uid=int(structures[sid])
	if uid in uids:
		var key: int=node.get_instance_id()
		if not records.has(key):
			var record: Dictionary={"ref":weakref(node),"uid":uid}
			if node is CanvasItem or node is Node3D:record.visible=node.visible
			if node is Control:record.mouse_filter=node.mouse_filter
			if node is CollisionObject3D:record.layer=node.collision_layer;record.mask=node.collision_mask;record.pickable=node.input_ray_pickable
			records[key]=record
	for child: Node in node.get_children():_collect(child,uid,owner,structures)
func is_hidden167c(uid: int) -> bool:return active and uid in uids and uid not in revealed
func reveal(uid: int) -> void:
	if uid in revealed:return
	revealed.append(uid)
	for record: Dictionary in records.values():
		if record.uid==uid:_restore(record)
func _restore(record: Dictionary) -> void:
	var node: Variant=record.ref.get_ref()
	if not is_instance_valid(node) or node.is_queued_for_deletion():return
	if record.has("visible"):node.visible=record.visible
	if record.has("mouse_filter"):node.mouse_filter=record.mouse_filter
	if record.has("layer"):node.collision_layer=record.layer;node.collision_mask=record.mask;node.input_ray_pickable=record.pickable
func snapshot() -> Dictionary:
	var hidden: Array=[];var collision_count:=0
	for uid: int in uids:
		if uid not in revealed:hidden.append(uid)
	for record: Dictionary in records.values():
		if record.has("layer") and record.uid not in revealed:collision_count+=1
	return {"hidden_uids":hidden,"visible_uids":revealed.duplicate(),"records":records.size(),"blocked_colliders":collision_count}
func finish() -> void:
	if RenderingServer.frame_pre_draw.is_connected(enforce):RenderingServer.frame_pre_draw.disconnect(enforce)
	if is_instance_valid(tree) and tree.node_added.is_connected(_node_added):tree.node_added.disconnect(_node_added)
	for record: Dictionary in records.values():_restore(record)
	records.clear();prior_terrain167c.clear();uids=[];revealed=[];active=false;_dirty=true
