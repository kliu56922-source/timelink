extends "res://core/battle/operation_clarity_battle_167a.gd"
const Events=preload("res://battle/analysis/recipe_execution_events_167c.gd")
func recipe166_commit(approved: Dictionary) -> Dictionary:
	var sources: Array=[]
	for id: String in ["P02","P05"]:
		var card: CardData=recipe166_key(id)
		if card!=null:sources.append({"uid":card.get_instance_id(),"card_id":card.card_id,"name":card.get_display_name()})
	var receipt: Dictionary=super.recipe166_commit(approved)
	if receipt.get("ok",false):receipt.execution167c=Events.build(receipt,sources)
	return receipt
