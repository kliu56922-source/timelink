extends "res://battle/analysis/retained_knight_ascension_window.gd"
## Only captures the actual post-settle query boundary; no action/timing change.
var audit_ref: WeakRef
func inspect(battle: Variant) -> Dictionary:
	var audit: Variant=audit_ref.get_ref() if audit_ref!=null else null
	if audit==null:return super.inspect(battle)
	audit._source_sample("before_a01_window")
	var index: int=audit.source_samples.size()-1
	var before: Dictionary=audit.snapshot();var q: Dictionary=super.inspect(battle);var cells: Array[Dictionary]=[]
	for source: CardData in battle.context.player.field:
		if source.card_id=="P02":cells.append({"runtime_id":source.get_instance_id(),"cell_query":battle.get_core_attack_cell_status(source).duplicate(true)})
	var after: Dictionary=audit.snapshot();audit._source_sample("after_a01_window")
	audit.ascension_boundaries.append({"index":audit.ascension_boundaries.size(),"turn":before.turn,"sample_before":index,"sample_after":audit.source_samples.size()-1,"before":before,"after":after,"readonly":before==after,"cells":cells})
	return q
