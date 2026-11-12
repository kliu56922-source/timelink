extends RefCounted
## Current ordinary player/enemy simultaneous combat only. Never consumes defenses.
static func inspect(b: Variant,actor: CardData,target: CardData) -> Dictionary:
 if actor==null or target==null or actor not in b.context.player.field or target not in b.context.enemy.field:return {"ok":false}
 if b.monster_combat_rules.resolution_mode!="simultaneous_hp":return {"ok":false}
 var a: Variant=b._state_for_card(actor);var t: Variant=b._state_for_card(target)
 if a==null or t==null or a.is_dead() or t.is_dead():return {"ok":false}
 # A prepared enemy response is outside this single ordinary-action forecast.
 if b.reaction_trial!=null and not b.reaction_trial.event.is_empty():return {"ok":false}
 var outgoing: int=maxi(0,b.get_effective_unit_attack(actor)+b.get_normal_attack_bonus(actor))
 var incoming: int=maxi(0,target.unit_power)
 if b.edge_fortification_trial!=null:
  outgoing=maxi(0,outgoing-b.edge_fortification_trial.cover_reduction(actor,target,outgoing))
  incoming=maxi(0,incoming-b.edge_fortification_trial.cover_reduction(target,actor,incoming))
 var p05: int=b._apply_p05_mitigation(actor,incoming,false)
 incoming=maxi(0,incoming-p05)
 var escort: int=mini(incoming,b.frontline_trial.escort_amount(actor)) if b.frontline_trial!=null else 0
 incoming=maxi(0,incoming-escort)
 # Native retaliation never applies garrison cover; simultaneous target damage
 # can consume an explicit escort on that enemy. No defensive slot is spent here.
 if b.frontline_trial!=null:
  var prepared: int=b.frontline_trial.escort_amount(target)
  var prevention: int=mini(outgoing,prepared);outgoing=maxi(0,outgoing-prevention)
  if outgoing>0 and not (prevention>0 and prepared==1) and b.get_command_economy_snapshot("boss").get("turn_open",false):outgoing=maxi(0,outgoing-int(b.frontline_trial.guard_for(target).get("reduction",0)))
 return {"ok":true,"actor_before":a.current_hp,"actor_after":maxi(0,a.current_hp-incoming),"target_before":t.current_hp,"target_after":maxi(0,t.current_hp-outgoing),"retaliation":incoming,"escort":escort,"p05":p05}
static func describe(q: Dictionary) -> String:
 if not q.get("ok",false):return "本次特殊场面无法可靠预估生命变化；仍按原规则结算。"
 return "当前场面预计：己方生命%d→%d%s；敌棋生命%d→%d%s。\n还击伤害%d · 护卫减伤%d · 炉基座减伤%d。\n双方同时造成伤害，击破敌棋也会受到还击；仅估计本次普通交战。"%[q.actor_before,q.actor_after,"（会阵亡）" if q.actor_after==0 else "（存活）",q.target_before,q.target_after,"（会阵亡）" if q.target_after==0 else "",q.retaliation,q.escort,q.p05]
