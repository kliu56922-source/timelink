class_name IModifier
extends RefCounted

var priority: int = 0
var is_active: bool = true

func can_modify(context: RefCounted) -> bool:
	return true

func modify(context: RefCounted) -> void:
	pass
