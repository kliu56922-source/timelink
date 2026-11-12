extends "res://core/battle/boss_weakpoint_battle_system.gd"
const TripleState=preload("res://core/battle/triple_weakpoint_state.gd")
func _create_weakpoint_state() -> RefCounted:
	return TripleState.new()
func get_weakpoint_snapshot(id: String="") -> Dictionary:
	if context==null or context.boss_weakpoint_state==null:return {}
	return context.boss_weakpoint_state.snapshot("pressure_arm" if id.is_empty() else id)
func get_weakpoint_snapshots() -> Array[Dictionary]:
	if context==null or context.boss_weakpoint_state==null:return []
	return context.boss_weakpoint_state.snapshots()
func _commit_weakpoint_hit(amount: int) -> Dictionary:
	return context.boss_weakpoint_state._commit_hit(_active_weakpoint_id,amount)
