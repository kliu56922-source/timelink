extends RefCounted
## Opt-in experiment, first qualified paid core release once per battle, even if capped.
var profile := "original"
var used := false
var resolving := false
var attempts := 0
var last_receipt: Dictionary={}
func _init(value: String="original") -> void:profile=value
func snapshot() -> Dictionary:
	return {"profile":profile,"used":used,"resolving":resolving,"attempts":attempts,"last_receipt":last_receipt.duplicate(true)}
func reserve(battle: Variant,card: CardData,skill: StringName,target: Variant,paid: Dictionary) -> Dictionary:
	var ctx: Variant=battle.context
	var ritual: Dictionary=battle.get_final_convergence_status("player")
	var eligible: bool=card!=null and card.card_id=="P07" and skill==&"stream_cannon" and target==null and paid.get("ok",false) and int(paid.get("stacks_consumed",0))==3 and ctx.arsenal_mid_used and ritual.get("used",false) and not ritual.get("last_receipt",{}).is_empty() and ctx.player.hp>0 and ctx.enemy.hp>0
	var requested := 0
	var reason := "not_qualified"
	var was_used := used
	if eligible:
		if profile=="original":reason="profile_original"
		elif used:reason="already_attempted"
		else:
			used=true;attempts+=1;requested=1;reason="first_full_paid_core"
	return {"profile":profile,"eligible":eligible,"requested":requested,"granted":0,"reason":reason,"used_before":was_used,"used_after":used,"attempts":attempts,"actor_id":card.card_id if card!=null else "","actor_runtime_id":card.get_instance_id() if card!=null else 0,"turn":ctx.turn_count}
func finish(receipt: Dictionary,grant: Dictionary) -> Dictionary:
	var r := receipt.duplicate(true)
	if r.requested>0:
		r.granted=int(grant.get("granted",0));r["grant_reason"]=str(grant.get("reason_code","not_requested"))
	else:r["grant_reason"]="not_requested"
	last_receipt=r.duplicate(true)
	return r
