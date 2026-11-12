extends RefCounted
class_name ODCoreCommandRuleSnapshot

## Phase 26C: OD Core Command immutable per-battle rule snapshot.
## Deep-copies the JSON table at construction so later mutations
## to the source dictionary cannot affect battle logic.

const SURGE: StringName = &"surge"
const VENT: StringName = &"vent"
const REDEPLOY: StringName = &"redeploy"

var _uses_per_player_turn: int = 1
var _commands: Dictionary = {}

func _init(table: Dictionary = {}) -> void:
	_uses_per_player_turn = int(table.get("uses_per_player_turn", 1))
	for raw in table.get("commands", []):
		if raw is Dictionary:
			var command: Dictionary = (raw as Dictionary).duplicate(true)
			_commands[StringName(str(command.get("id", "")))] = command

func get_uses_per_player_turn() -> int:
	return _uses_per_player_turn

func has_command(command_id: StringName) -> bool:
	return _commands.has(command_id)

func get_command(command_id: StringName) -> Dictionary:
	return (_commands.get(command_id, {}) as Dictionary).duplicate(true)

func get_charge_cost(command_id: StringName) -> int:
	return int((_commands.get(command_id, {}) as Dictionary).get("charge_cost", 0))

func get_effect(command_id: StringName) -> Dictionary:
	return ((_commands.get(command_id, {}) as Dictionary).get("effect", {}) as Dictionary).duplicate(true)

func is_usable_during_backlash(command_id: StringName) -> bool:
	return bool((_commands.get(command_id, {}) as Dictionary).get("usable_during_backlash", false))
