extends Node
var target_ref: WeakRef
func _input(event: InputEvent) -> void:
 var target: Variant=target_ref.get_ref() if target_ref!=null else null
 if is_instance_valid(target):target.observe167d(event)
