extends RefCounted
## GB3H: opt-in composition over the structure/garrison authorities.
var _ref: WeakRef
var established: Dictionary = {}
var guard_used: Dictionary = {}
var breach_used: Dictionary = {}
var escort: Dictionary = {}
const BUILD_EDGES: Array[StringName] = [&"north", &"east", &"south", &"west"]
const BUILD_OFFSETS: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
var rotation_enabled := false
var build_edge: StringName = &"north"

func rotate_build_edge() -> void:
	if rotation_enabled: build_edge = BUILD_EDGES[(BUILD_EDGES.find(build_edge) + 1) % 4]

func build_offset(edge: StringName) -> Vector2i:
	var index := BUILD_EDGES.find(edge)
	return BUILD_OFFSETS[index] if index >= 0 else Vector2i.ZERO

func rotate_module_edge(edge: StringName, forward: StringName) -> StringName:
	return BUILD_EDGES[(BUILD_EDGES.find(edge) + BUILD_EDGES.find(forward)) % 4]

func _init(bt: Node) -> void:
	_ref = weakref(bt)
	bt.unit_cell_changed.connect(_unit_moved)

func _unit_moved(card: CardData, _side: StringName, from: Vector2i, to: Vector2i, _source: StringName) -> void:
	if from != to: established.erase(card.get_instance_id())

func begin_turn(side: String) -> void:
	breach_used.erase(side)
	if side == "boss": guard_used.clear()
	if side == "player":
		breach_used.clear()
		escort.clear()
		established.clear()
		var bt = _ref.get_ref()
		for card in bt.context.player.field:
			established[card.get_instance_id()] = bt.get_unit_cell(card)

func can_build_forward(cell: Vector2i) -> bool:
	var bt = _ref.get_ref()
	for enemy in bt.context.enemy.field:
		if _distance(bt.get_unit_cell(enemy), cell) <= 1: return false
	for card in bt.context.player.field:
		var state = bt._state_for_card(card)
		if state == null or state.is_dead(): continue
		var origin: Vector2i = bt.get_unit_cell(card)
		if established.get(card.get_instance_id(), Vector2i(-9, -9)) == origin and _distance(origin, cell) == 1:
			return true
	return false

func _distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)

func guard_for(target: CardData) -> Dictionary:
	var bt = _ref.get_ref()
	if not target in bt.context.player.field: return {}
	for guard in bt.context.player.field:
		var state = bt._state_for_card(guard)
		if state == null or state.is_dead(): continue
		var assignment: Dictionary = bt.get_garrison_state_for_unit(guard)
		if not bt._garrison_assignment_support_intact(assignment): continue
		var id: StringName = assignment.structure_id
		if guard_used.has(id): continue
		if _distance(bt.get_unit_cell(guard), bt.get_unit_cell(target)) <= 1:
			return {"structure_id": id, "guard": guard.get_display_name(), "reduction": 1}
	return {}

func grant_escort(target: CardData, enhanced: bool) -> void:
	grant_escort_amount(target,3 if enhanced else 2)

func grant_escort_amount(target: CardData, amount: int) -> void:
	if target == null: return
	escort[target.get_instance_id()] = maxi(int(escort.get(target.get_instance_id(), 0)),maxi(0,amount))

func escort_amount(target: CardData) -> int:
	return int(escort.get(target.get_instance_id(), 0)) if target != null else 0

func reduce_damage(target: CardData, amount: int, source: String) -> int:
	if amount <= 0 or source not in ["simultaneous", "simultaneous_retaliation"]: return amount
	var bt = _ref.get_ref()
	var prepared := escort_amount(target)
	var protection := mini(amount, prepared)
	if protection > 0:
		escort.erase(target.get_instance_id())
		amount -= protection
		if bt.reaction_trial != null:
			bt.reaction_trial.history.append({"kind": "escort", "prevented": protection})
	# E02's one-point supply occupies this hit's protection; cover is an
	# alternative of the same strength, not another subtraction. Preserve
	# unused garrison cover for a later hit and the existing 2/3 escort path.
	if protection > 0 and prepared == 1: return amount
	if amount <= 0 or source != "simultaneous": return amount
	if not bt.get_command_economy_snapshot("boss").get("turn_open", false): return amount
	var cover := guard_for(target)
	if cover.is_empty(): return amount
	guard_used[cover.structure_id] = true
	if bt.reaction_trial != null:
		bt.reaction_trial.history.append({"kind": "garrison", "prevented": mini(1, amount), "guard": cover.guard})
	return maxi(0, amount - 1)

func breach_amount(attacker: CardData) -> int:
	var bt = _ref.get_ref()
	var blade := 2 if not bt._get_bishop_enchant(attacker).is_empty() else 0
	var assignment: Dictionary = bt.get_garrison_state_for_unit(attacker)
	if not bt._garrison_assignment_support_intact(assignment): return blade
	var side: String = str(assignment.owner_side)
	if breach_used.has(side): return blade
	var cell: Vector2i = bt.get_unit_cell(attacker)
	if (side == "player" and cell.y > 1) or (side == "boss" and cell.y < 3): return blade
	return 2

func commit_breach(attacker: CardData) -> int:
	var bt = _ref.get_ref()
	var bonus := breach_amount(attacker)
	if bonus == 0: return 0
	var side: String = str(bt._state_for_card(attacker).owner_side)
	var shield: int = bt.context.enemy.boss_shield if side == "player" else bt.context.player.shield
	var removed := mini(bonus, shield)
	if removed <= 0: return 0
	if side == "player": bt.context.enemy.boss_shield -= removed
	else: bt.context.player.shield -= removed
	breach_used[side] = true
	return removed
