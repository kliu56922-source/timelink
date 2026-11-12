class_name DamageModifier
extends IModifier

func can_modify(context: RefCounted) -> bool:
	return context is EffectContext and "damage" in (context as EffectContext).tags
