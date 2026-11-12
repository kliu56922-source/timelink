extends RefCounted
class_name TacticalBoardState

signal transaction_committed(transaction: Dictionary)

const TacticalCellStateClass := preload("res://core/battle/tactical_cell_state.gd")

const SURFACE_FLAT: StringName = &"flat"
const SURFACE_FOUNDATION: StringName = &"foundation"
const SURFACE_HIGH_PLATFORM: StringName = &"high_platform"
const SURFACE_STABLE: StringName = &"stable"
const SURFACE_OVERHEATED: StringName = &"overheated"
const SURFACE_RUINS: StringName = &"ruins"
const SURFACE_UNDERMINED: StringName = &"undermined"

const VALID_SURFACES: Array[StringName] = [
	SURFACE_FLAT,
	SURFACE_FOUNDATION,
	SURFACE_HIGH_PLATFORM,
	SURFACE_STABLE,
	SURFACE_OVERHEATED,
	SURFACE_RUINS,
	SURFACE_UNDERMINED,
]

const REASON_OK: StringName = &"ok"
const REASON_EMPTY_CHANGE_SET: StringName = &"empty_change_set"
const REASON_CELL_OUT_OF_BOUNDS: StringName = &"cell_out_of_bounds"
const REASON_DUPLICATE_CELL: StringName = &"duplicate_cell"
const REASON_STALE_CELL_STATE: StringName = &"stale_cell_state"
const REASON_HEIGHT_OUT_OF_BOUNDS: StringName = &"height_out_of_bounds"
const REASON_HEIGHT_STEP_EXCEEDED: StringName = &"height_step_exceeded"
const REASON_INVALID_SURFACE: StringName = &"invalid_surface"

var _cells: Dictionary = {}


func configure_cells(cells: Array[Vector2i]) -> void:
	var configured: Dictionary = {}
	for cell in cells:
		if configured.has(cell):
			return
		configured[cell] = TacticalCellStateClass.new(cell)
	if configured.size() != 25:
		return
	_cells = configured


func get_cell_state(cell: Vector2i) -> Dictionary:
	var state: Variant = _cells.get(cell, null)
	return state.snapshot() if state != null else {}


func get_all_cell_states() -> Dictionary:
	var result: Dictionary = {}
	for cell in _cells:
		var state: Variant = _cells[cell]
		result[cell] = state.snapshot()
	return result


func get_change_status(changes: Array[Dictionary]) -> Dictionary:
	if changes.is_empty():
		return _invalid(REASON_EMPTY_CHANGE_SET)
	var requested_cells: Dictionary = {}
	for index in range(changes.size()):
		var change: Dictionary = changes[index]
		var cell_value: Variant = change.get("cell", null)
		if not cell_value is Vector2i or not _cells.has(cell_value):
			return _invalid(REASON_CELL_OUT_OF_BOUNDS, index)
		var cell: Vector2i = cell_value
		if requested_cells.has(cell):
			return _invalid(REASON_DUPLICATE_CELL, index)
		requested_cells[cell] = true

		var current: Variant = _cells[cell]
		if not change.has("expected_height") or not change.has("expected_revision"):
			return _invalid(REASON_STALE_CELL_STATE, index)
		if int(change.get("expected_height", -99)) != current.height \
		or int(change.get("expected_revision", -99)) != current.revision:
			return _invalid(REASON_STALE_CELL_STATE, index)

		if not change.has("target_height"):
			return _invalid(REASON_HEIGHT_OUT_OF_BOUNDS, index)
		var target_height: int = int(change.get("target_height", -99))
		if target_height < 0 or target_height > 2:
			return _invalid(REASON_HEIGHT_OUT_OF_BOUNDS, index)
		if absi(target_height - current.height) > 1:
			return _invalid(REASON_HEIGHT_STEP_EXCEEDED, index)

		if not change.has("target_surface"):
			return _invalid(REASON_INVALID_SURFACE, index)
		var target_surface := StringName(str(change.get("target_surface", &"")))
		if target_surface not in VALID_SURFACES:
			return _invalid(REASON_INVALID_SURFACE, index)
	return {"ok": true, "reason_code": REASON_OK}


func commit_changes(changes: Array[Dictionary], source: StringName, options: Dictionary = {}) -> Dictionary:
	var status: Dictionary = get_change_status(changes)
	if not bool(status.get("ok", false)):
		return status

	var replacements: Dictionary = _cells.duplicate()
	var committed_changes: Array[Dictionary] = []
	for change in changes:
		var cell: Vector2i = change["cell"]
		var current: Variant = _cells[cell]
		var replacement: Variant = current.copy_with(
			int(change["target_height"]),
			StringName(str(change["target_surface"]))
		)
		replacements[cell] = replacement
		committed_changes.append({
			"cell": cell,
			"before": current.snapshot(),
			"after": replacement.snapshot(),
		})

	_cells = replacements
	var result := {
		"ok": true,
		"reason_code": REASON_OK,
		"source": source,
		"changes": committed_changes,
	}
	if not bool(options.get("defer_signal", false)):
		publish_changes_fact(result)
	return result.duplicate(true)


## Reverse an unpublished synchronous transaction only while every affected cell
## still matches its receipt. Validate the complete set before changing any cell.
func rollback_changes(fact: Dictionary) -> void:
	if not bool(fact.get("ok", false)):
		return
	var changes: Array = fact.get("changes", [])
	if changes.is_empty():
		return
	var replacements: Dictionary = _cells.duplicate()
	var seen: Dictionary = {}
	for value: Variant in changes:
		if not value is Dictionary:
			return
		var change: Dictionary = value
		var cell: Variant = change.get("cell")
		var before: Dictionary = change.get("before", {})
		var after: Dictionary = change.get("after", {})
		if not cell is Vector2i or not _cells.has(cell) or seen.has(cell):
			return
		if get_cell_state(cell) != after or before.get("cell") != cell:
			return
		if int(before.get("revision", -2)) + 1 != int(after.get("revision", -1)):
			return
		seen[cell] = true
		replacements[cell] = TacticalCellStateClass.new(cell, int(before.height), StringName(before.surface), int(before.revision))
	_cells = replacements


## Publication only; transaction callers retain the committed fact until completion.
func publish_changes_fact(fact: Dictionary) -> void:
	if bool(fact.get("ok", false)):
		transaction_committed.emit(fact.duplicate(true))


func _invalid(reason_code: StringName, failed_index: int = -1) -> Dictionary:
	var result := {"ok": false, "reason_code": reason_code}
	if failed_index >= 0:
		result["failed_index"] = failed_index
	return result
