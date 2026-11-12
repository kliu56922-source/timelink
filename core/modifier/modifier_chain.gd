class_name ModifierChain
extends RefCounted

var _modifiers: Array[IModifier] = []

func add_modifier(modifier: IModifier) -> void:
	_modifiers.append(modifier)
	_sort()

func remove_modifier(modifier: IModifier) -> void:
	_modifiers.erase(modifier)

func apply(context: RefCounted) -> void:
	for modifier in _modifiers:
		if modifier.is_active and modifier.can_modify(context):
			modifier.modify(context)

func _sort() -> void:
	_modifiers.sort_custom(func(a: IModifier, b: IModifier) -> bool:
		return a.priority > b.priority
	)
