extends RefCounted
class_name TacticalGridRuleSnapshot

## Phase 27A: 不可变 5x5 战术网格规则快照
## 由 GameConfig 在 battle start 一次性创建，注入 BattleSystem。
## 拥有纯查询方法：边界、召唤区域、朝向、兼容性移动/攻击掩码。

const INVALID_CELL := Vector2i(-1, -1)

var columns: int = 5
var ranks: int = 5
var center_rank: int = 2
var player_summon_ranks: Array[int] = [3, 4]
var boss_summon_ranks: Array[int] = [0, 1]
var player_facing_delta: int = -1
var boss_facing_delta: int = 1
var movement_id: StringName = &"phase27a_vanguard_step"
var attack_id: StringName = &"phase27a_front_arc_3"
var movement_offsets: Array[Vector2i] = [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1)]
var attack_offsets: Array[Vector2i] = [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1)]
var summon_column_order: Array[int] = [2, 1, 3, 0, 4]
var used_fallback := false
var validation_errors: Array[String] = []

func _init(values: Dictionary = {}, fallback_used := false, errors: Array[String] = []) -> void:
	used_fallback = fallback_used
	validation_errors = errors.duplicate()
	if values.is_empty():
		return
	columns = int(values.get("columns", 5))
	ranks = int(values.get("ranks", 5))
	center_rank = int(values.get("center_rank", 2))
	player_summon_ranks = _to_int_array(values.get("summon_ranks", {}).get("player", [3, 4]))
	boss_summon_ranks = _to_int_array(values.get("summon_ranks", {}).get("boss", [0, 1]))
	player_facing_delta = int(values.get("facing_rank_delta", {}).get("player", -1))
	boss_facing_delta = int(values.get("facing_rank_delta", {}).get("boss", 1))
	var patterns: Dictionary = values.get("compatibility_patterns", {})
	movement_id = StringName(str(patterns.get("movement_id", movement_id)))
	attack_id = StringName(str(patterns.get("attack_id", attack_id)))
	movement_offsets = _to_cell_array(patterns.get("movement_offsets", []), movement_offsets)
	attack_offsets = _to_cell_array(patterns.get("attack_offsets", []), attack_offsets)
	summon_column_order = _to_int_array(values.get("summon_column_order", [2, 1, 3, 0, 4]))

static func default_snapshot(errors: Array[String] = []) -> Variant:
	var inst := new()
	inst.used_fallback = true
	inst.validation_errors = errors.duplicate()
	return inst

func _normalize_side(owner_side: StringName) -> StringName:
	return &"boss" if owner_side in [&"boss", &"enemy"] else &"player"

func is_cell_in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < columns and cell.y >= 0 and cell.y < ranks

func get_all_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for rank in range(ranks):
		for column in range(columns):
			result.append(Vector2i(column, rank))
	return result

func get_summon_ranks(owner_side: StringName) -> Array[int]:
	return boss_summon_ranks.duplicate() if _normalize_side(owner_side) == &"boss" else player_summon_ranks.duplicate()

func is_normal_summon_cell(owner_side: StringName, cell: Vector2i) -> bool:
	return is_cell_in_bounds(cell) and cell.y in get_summon_ranks(owner_side)

func orient_offset(owner_side: StringName, offset: Vector2i) -> Vector2i:
	return Vector2i(offset.x, -offset.y) if _normalize_side(owner_side) == &"boss" else offset

func get_pattern_cells(origin: Vector2i, owner_side: StringName, offsets: Array[Vector2i]) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for raw_offset in offsets:
		var cell := origin + orient_offset(owner_side, raw_offset)
		if is_cell_in_bounds(cell):
			result.append(cell)
	return result

func get_compatibility_move_cells(origin: Vector2i, owner_side: StringName, occupied: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell in get_pattern_cells(origin, owner_side, movement_offsets):
		if not occupied.has(cell):
			result.append(cell)
	return result

func get_compatibility_attack_cells(origin: Vector2i, owner_side: StringName) -> Array[Vector2i]:
	return get_pattern_cells(origin, owner_side, attack_offsets)

## Phase 27B: 判断 cell 是否在敌方领地
## 玩家领地: rank 3-4, Boss 领地: rank 0-1
func is_enemy_territory_cell(owner_side: StringName, cell: Vector2i) -> bool:
	if not is_cell_in_bounds(cell):
		return false
	if _normalize_side(owner_side) == &"boss":
		return cell.y >= 3
	return cell.y <= 1

## Phase 27I-R0: 虚拟核心锚点格（棋盘外，供棋型投影使用）
## boss 侧在 rank=-1，player 侧在 rank=ranks。列取中列。
func get_virtual_core_anchor_cell(owner_side: StringName) -> Vector2i:
	var x: int = floori(float(columns) / 2.0)
	return Vector2i(x, -1) if _normalize_side(owner_side) == &"boss" else Vector2i(x, ranks)

func get_ordered_summon_cells(owner_side: StringName) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var ordered_ranks: Array[int] = get_summon_ranks(owner_side)
	if _normalize_side(owner_side) == &"boss":
		ordered_ranks.reverse()
	for rank in ordered_ranks:
		for column in summon_column_order:
			result.append(Vector2i(column, rank))
	return result

func _to_int_array(raw: Variant) -> Array[int]:
	var result: Array[int] = []
	if raw is Array:
		for value in raw:
			result.append(int(value))
	return result

func _to_cell_array(raw: Variant, fallback: Array[Vector2i]) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if raw is Array:
		for pair in raw:
			if pair is Array and pair.size() == 2:
				result.append(Vector2i(int(pair[0]), int(pair[1])))
	return result if not result.is_empty() else fallback.duplicate()
