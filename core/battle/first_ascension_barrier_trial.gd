extends RefCounted
## Opt-in A01 payoff. Called only by the staged native material/payment commit.
const SHIELD_GAIN := 4
var profile := "original"
var used := false
var attempts := 0
var last_receipt: Dictionary={}
func _init(value: String="original") -> void:profile=value
func snapshot() -> Dictionary:
	return {"profile":profile,"used":used,"attempts":attempts,"last_receipt":last_receipt.duplicate(true)}
func commit(battle: Variant,source: CardData,target: CardData,paid: Dictionary) -> Dictionary:
	var ctx: Variant=battle.context
	var before: int=ctx.player.shield
	var was_used := used
	var qualified: bool=target.card_id=="A01" and paid.get("ok",false) and ctx.arsenal_mid_used and target in ctx.player.field and source not in ctx.player.field and source in ctx.player.graveyard and battle.get_unit_at_cell(paid.source_cell)==target
	var granted := 0;var reason := "not_qualified"
	if qualified:
		if profile=="original":reason="profile_original"
		elif used:reason="already_attempted"
		else:
			# Reserve before any presentation signal; terminal/Backlash rejection
			# consumes this successful ascension's one opportunity as well.
			used=true;attempts+=1
			if ctx.player.hp<=0 or ctx.enemy==null or ctx.enemy.hp<=0:reason="battle_ended"
			elif ctx.is_abyss_locked():reason="backlash_restricted"
			else:granted=SHIELD_GAIN;reason="first_paid_a01";ctx.player.shield+=granted
	last_receipt={"event_key":"ascension_barrier","profile":profile,"qualified":qualified,"reason":reason,"requested":SHIELD_GAIN if qualified and profile=="first-barrier" and not was_used else 0,"granted":granted,"shield_before":before,"shield_after":ctx.player.shield,"used_before":was_used,"used_after":used,"attempts":attempts,"turn":ctx.turn_count,"source_id":source.card_id,"source_runtime_id":source.get_instance_id(),"target_id":target.card_id,"target_runtime_id":target.get_instance_id(),"hp_cost":paid.hp_cost,"hp_before":paid.hp_before,"hp_after":ctx.player.hp,"engine_layer":ctx.od_mode.get_engine_layer(),"depth":ctx.depth_pressure,"backlash":ctx.is_abyss_locked()}
	return last_receipt.duplicate(true)
