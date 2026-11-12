extends SubViewportContainer
class_name MonsterSummonDragPreview

## Native drag image for monster cards. It is intentionally visual-only.

const PawnClass := preload("res://scenes/presentation/monster_summon_hologram_pawn.gd")

var _pawn: Node3D = null
var _configured := false


func setup(card: CardData, reduced_motion: bool) -> void:
	custom_minimum_size = Vector2(132, 132)
	size = Vector2(132, 132)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_meta("preview_kind", &"hologram_pawn")
	set_meta("card_id", card.card_id if card != null else "")
	if _configured:
		if _pawn != null and is_instance_valid(_pawn):
			_pawn.configure(card, &"drag", reduced_motion)
		return
	_configured = true
	var viewport := SubViewport.new()
	viewport.size = Vector2i(132, 132)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var world_root := Node3D.new()
	viewport.add_child(world_root)
	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 0.42, 1.45)
	camera.look_at_from_position(camera.position, Vector3(0.0, 0.24, 0.0))
	world_root.add_child(camera)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45.0, -30.0, 0.0)
	light.light_energy = 0.65
	world_root.add_child(light)
	_pawn = PawnClass.new()
	_pawn.name = "HologramPawn"
	_pawn.configure(card, &"drag", reduced_motion)
	world_root.add_child(_pawn)


func get_debug_snapshot() -> Dictionary:
	var pawn_snapshot: Dictionary = _pawn.get_debug_snapshot() if _pawn != null and is_instance_valid(_pawn) else {}
	return {
		"preview_kind": get_meta("preview_kind", &""),
		"card_id": get_meta("card_id", ""),
		"active_tweens": int(pawn_snapshot.get("active_tweens", 0)),
		"motion_processing": bool(pawn_snapshot.get("motion_processing", false)),
		"mesh_count": int(pawn_snapshot.get("mesh_count", 0)),
	}
