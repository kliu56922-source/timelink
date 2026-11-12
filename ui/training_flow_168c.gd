extends "res://ui/training_flow_168b2.gd"
func refresh() -> void:
 super.refresh()
 var owner: Variant=scene()
 if owner==null or not owner.get("ready168c"):return
 owner.phase_label166b.text=owner.phase_label166b.text.replace("168B2训练","168C训练")
