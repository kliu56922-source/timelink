extends RefCounted
## Audit-only current facts; callers choose whether to commit through the real handler.
func inspect(battle: Variant) -> Dictionary:
	var result := {"eligible":false,"reason":&"no_current_source","scope":&"current_a01_end_turn_only"}
	if battle==null or battle.context==null or battle.context.player==null or battle.context.enemy==null:return result
	if battle._od_release_resolving or battle._siege_command_in_progress or not battle.get_core_command_state().get("player_turn_open",false):
		result.reason=&"busy_or_closed";return result
	if battle.context.player.hp<=0 or battle.context.enemy.hp<=0:
		result.reason=&"battle_ended";return result
	var ritual: Dictionary=battle.get_final_convergence_status("player")
	if not ritual.get("used",false) or ritual.get("last_receipt",{}).is_empty():
		result.reason=&"ritual_not_claimed";return result
	for source: CardData in battle.context.player.field:
		if not is_instance_valid(source) or source.card_id!="P02":continue
		var preview: Dictionary=battle.get_ascension_preview_status(source,battle.context.player)
		if not preview.get("ok",false) or preview.get("target")==null or preview.target.card_id!="A01":continue
		if not battle.get_core_attack_cell_status(source).get("ok",false):continue
		if int(preview.get("hp_after",0))<=0:
			result.reason=&"lethal_hp_payment";continue
		result.merge({"eligible":true,"reason":&"live_a01_after_ritual","source":source,"target":preview.target,"source_runtime_id":source.get_instance_id(),"target_runtime_id":preview.target.get_instance_id(),"source_id":source.card_id,"target_id":preview.target.card_id,"cell":battle.get_unit_cell(source),"facing":battle.get_unit_facing(source),"hp_cost":preview.hp_cost,"hp_before":preview.hp_before,"hp_after":preview.hp_after,"engine_layer":battle.context.od_mode.get_engine_layer(),"heat":battle.context.od_mode.current_od,"depth":battle.context.depth_pressure},true)
		return result
	return result
