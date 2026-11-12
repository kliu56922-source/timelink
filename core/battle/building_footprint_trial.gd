extends "res://core/battle/construction_site_trial.gd"
## Opt-in103 geometry lab. Sizes do not invent new facility effects or card plays.
var selected_size:=Vector2i.ONE
var selected_rotation:=0
var _layouts: Dictionary={}

func _init(battle: Variant, selected: Array[String]=["P13","P16"]) -> void:
	super._init(battle,selected)
	battle.building_footprint_trial=self

func select_footprint(size: Vector2i, quarter: int) -> Dictionary:
	if size not in [Vector2i.ONE,Vector2i(1,2),Vector2i(2,2)] or quarter<0 or quarter>3:return {"ok":false,"reason_code":"invalid_footprint"}
	selected_size=size;selected_rotation=quarter
	return {"ok":true}

func offsets(card: CardData) -> Array[Vector2i]:
	if _layouts.has(card.get_instance_id()):return _layouts[card.get_instance_id()].duplicate()
	var result: Array[Vector2i]=[Vector2i.ZERO]
	if card!=_plan or card.card_id!="P13":return result
	for y: int in range(selected_size.y):
		for x: int in range(selected_size.x):
			if x==0 and y==0:continue
			var off:=Vector2i(x,-y)
			for i: int in range(selected_rotation):off=Vector2i(-off.y,off.x)
			result.append(off)
	return result

func owns_solid_source(runtime_id: int) -> bool:
	return _layouts.has(runtime_id)

func augment_layout(card: CardData, cell: Vector2i, plan: Dictionary, terrain: Array[Dictionary], result: Dictionary) -> Dictionary:
	if card.card_id!="P13":return {"ok":true}
	var b: Variant=_battle.get_ref()
	var cells: Array[Vector2i]=[]
	for off: Vector2i in offsets(card):cells.append(cell+off)
	var height: int=b.get_cell_height(cell)
	var target_height: int=terrain[0].target_height
	var existing: Dictionary=b.get_structure_at_cell(cell)
	var own_site: bool=not existing.is_empty() and int(existing.source_runtime_id)==card.get_instance_id()
	var changes: Array[Dictionary]=[]
	for occupied: Vector2i in cells:
		if not b.tactical_grid_rules.is_cell_in_bounds(occupied):return {"ok":false,"reason_code":"footprint_out_of_bounds"}
		var current: Dictionary=b.get_structure_at_cell(occupied)
		if b.get_unit_at_cell(occupied)!=null or (not current.is_empty() and int(current.source_runtime_id)!=card.get_instance_id()) or b._is_cell_used_by_anchor(occupied,card.get_instance_id()):return {"ok":false,"reason_code":"footprint_occupied"}
		var tile: Dictionary=b.get_cell_state(occupied)
		if int(tile.height)!=height or tile.surface not in [&"flat",&"foundation"]:return {"ok":false,"reason_code":"footprint_foundation_mismatch"}
		if own_site and (int(tile.height)!=target_height or tile.surface!=&"foundation"):return {"ok":false,"reason_code":"site_foundation_changed"}
		changes.append({"cell":occupied,"expected_height":int(tile.height),"expected_revision":int(tile.revision),"target_height":target_height,"target_surface":&"foundation"})
		for direction: StringName in [&"north",&"east",&"south",&"west"]:
			var adjacent: Vector2i=occupied+{&"north":Vector2i.UP,&"east":Vector2i.RIGHT,&"south":Vector2i.DOWN,&"west":Vector2i.LEFT}[direction]
			if adjacent not in cells:continue
			var native: Dictionary=b.context.tactical_structure_board_state.get_module_at_edge(occupied,direction)
			if int(native.get("integrity_current",0))>0:return {"ok":false,"reason_code":"footprint_internal_wall"}
			if b.edge_fortification_trial!=null and int(b.edge_fortification_trial.get_edge(occupied,direction).get("hp",0))>0:return {"ok":false,"reason_code":"footprint_internal_wall"}
	plan.structure.footprint_cells=cells
	terrain.assign(changes);result.preview_footprint_cells=cells.duplicate()
	return {"ok":true}

func _on_order_paid(order: Dictionary, quote: Dictionary) -> void:
	if order.card.card_id=="P13":
		var frozen: Array[Vector2i]=[]
		for occupied: Vector2i in quote.layout._structure_plan.structure.footprint_cells:frozen.append(occupied-order.cell)
		_layouts[order.card.get_instance_id()]=frozen
	super._on_order_paid(order,quote)
