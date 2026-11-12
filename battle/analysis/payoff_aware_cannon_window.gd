extends "res://battle/analysis/repeated_charged_cannon_window.gd"
const Preview := preload("res://battle/analysis/current_core_payoff_preview.gd")
var profile := "cannon-first"
var _preview := Preview.new()
func _init(value: String="cannon-first") -> void:profile=value
func inspect(battle: Variant,used: bool) -> Dictionary:
	var q: Dictionary=super.inspect(battle,used)
	q["native_eligible"]=q.eligible;q["deferred"]=false;q["payoff_policy"]=profile
	q["current_cannon"]={};q["comparison"]={};q["preferred_normal"]={}
	if not q.eligible:return q
	q.current_cannon=_preview.inspect(battle,q.actor,&"stream_cannon")
	q.comparison=_preview.compare(battle)
	if profile!="current-payoff" or not q.current_cannon.comparable or not q.current_cannon.refund_qualification_used or q.current_cannon.refund!=0:return q
	for candidate: Dictionary in q.comparison.candidates:
		if candidate.command!="attack_core" or not candidate.comparable or candidate.hp_loss<=q.current_cannon.hp_loss:continue
		if q.preferred_normal.is_empty() or candidate.hp_loss>q.preferred_normal.hp_loss:q.preferred_normal=candidate.duplicate(true)
	if not q.preferred_normal.is_empty():q.deferred=true;q.eligible=false;q.reason=&"current_normal_core_higher_hp"
	return q
