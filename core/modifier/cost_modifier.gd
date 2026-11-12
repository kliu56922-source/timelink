class_name CostModifier
extends IModifier

func can_modify(context: RefCounted) -> bool:
	return context is PipelineContext
