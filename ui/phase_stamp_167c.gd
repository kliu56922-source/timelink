extends Node
var owner_ref: WeakRef
func _process(_delta: float) -> void:
 var s: Variant=owner_ref.get_ref() if owner_ref!=null else null
 if is_instance_valid(s):s.phase_label166b.text=s.phase_label166b.text.replace("167B","167C")
