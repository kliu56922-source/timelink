extends "res://battle/analysis/retained_ascension_audit_boundary.gd"
## Audit policy: original native ascension, not immediate core-attack eligibility.
var admission_policy: StringName=&"native-preview"
func inspect(battle: Variant) -> Dictionary:
	var original: Dictionary=super.inspect(battle)
	var native_previews: Array[Dictionary]=[]
	if battle!=null and battle.context!=null and battle.context.player!=null:
		for card: CardData in battle.context.player.field:
			if card.card_id!="P02":continue
			var preview: Dictionary=battle.get_ascension_preview_status(card,battle.context.player)
			var target: CardData=preview.get("target")
			native_previews.append({"runtime_id":card.get_instance_id(),"source_id":card.card_id,"ok":preview.get("ok",false),"reason":str(preview.get("reason","")),"target_id":target.card_id if is_instance_valid(target) else "","hp_cost":int(preview.get("hp_cost",0)),"hp_before":int(preview.get("hp_before",0)),"hp_after":int(preview.get("hp_after",0))})
	var audit: Variant=audit_ref.get_ref() if audit_ref!=null else null
	if is_instance_valid(audit) and not audit.ascension_boundaries.is_empty():audit.ascension_boundaries.back()["native_ascension_previews"]=native_previews
	if admission_policy==&"original":return original
	var q := {"eligible":false,"reason":&"no_current_source","scope":&"current_a01_end_turn_only"}
	if battle!=null and battle.context!=null and battle.context.player!=null and battle.context.enemy!=null:
		var ctx: Variant=battle.context
		if battle._od_release_resolving or battle._siege_command_in_progress or not battle.get_core_command_state().get("player_turn_open",false):q.reason=&"busy_or_closed"
		elif ctx.player.hp<=0 or ctx.enemy.hp<=0:q.reason=&"battle_ended"
		else:
			var ritual: Dictionary=battle.get_final_convergence_status("player")
			if not ritual.get("used",false) or ritual.get("last_receipt",{}).is_empty():q.reason=&"ritual_not_claimed"
			else:
				for source: CardData in ctx.player.field:
					if not is_instance_valid(source) or source.card_id!="P02":continue
					var preview: Dictionary=battle.get_ascension_preview_status(source,ctx.player)
					var target: CardData=preview.get("target")
					if not preview.get("ok",false) or not is_instance_valid(target) or target.card_id!="A01":continue
					if int(preview.get("hp_after",0))<=0:q.reason=&"lethal_hp_payment";continue
					q.merge({"eligible":true,"reason":&"live_a01_after_ritual","source":source,"target":target,"source_runtime_id":source.get_instance_id(),"target_runtime_id":target.get_instance_id(),"source_id":source.card_id,"target_id":target.card_id,"cell":battle.get_unit_cell(source),"facing":battle.get_unit_facing(source),"hp_cost":preview.hp_cost,"hp_before":preview.hp_before,"hp_after":preview.hp_after,"engine_layer":ctx.od_mode.get_engine_layer(),"heat":ctx.od_mode.current_od,"depth":ctx.depth_pressure},true)
					break
	var base: Dictionary=q.duplicate(true);base.erase("source");base.erase("target")
	var ready := false
	for receipt: Dictionary in releases:
		if receipt.source_runtime_id==q.get("source_runtime_id",0):ready=true;break
	q["base_query"]=base;q["retention_policy"]=policy;q["retention_state"]=snapshot();q["post_ritual_conversion_ready"]=ready
	if policy=="retain-after-conversion" and q.eligible and not ready:q.eligible=false;q.reason=&"waiting_same_source_conversion"
	return q
