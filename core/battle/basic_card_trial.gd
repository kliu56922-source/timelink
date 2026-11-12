extends RefCounted
## First public-card batch: resource decisions, no new currency or hidden draw.
var _ref: WeakRef
var used_turn_by_id: Dictionary = {}
const TARGET_IDS := ["B01", "B02", "B03"]
const IDS := ["B01", "B02", "B03", "B04", "B05"]
var blades: Dictionary = {}
var history: Array[Dictionary] = []
func _init(owner: Node) -> void: _ref=weakref(owner)
func status(card: CardData) -> Dictionary:
	var b=_ref.get_ref()
	if not b.get_command_economy_snapshot("player").get("turn_open",false): return {"ok":false,"reason":"请在己方回合使用"}
	if b.context.player.hp<=0 or b.context.enemy.hp<=0: return {"ok":false,"reason":"对局已结束"}
	if used_turn_by_id.get(card.card_id,-1)==b.context.turn_count: return {"ok":false,"reason":"同名本回合已使用"}
	var heat: int=b.context.od_mode.current_od
	if card.card_id in TARGET_IDS:
		if heat<1: return {"ok":false,"reason":"需要支付热量1"}
		var field: Array=b.context.enemy.field if card.card_id=="B01" else b.context.player.field
		for target in field:
			if target_status(card,target,false).get("ok",false): return {"ok":true,"reason":""}
		return {"ok":false,"reason":"没有可用的敌方棋子" if card.card_id=="B01" else "没有可用的己方棋子"}
	if card.card_id=="B04":
		if heat>=10: return {"ok":false,"reason":"热量已满，无需蓄火"}
		return {"ok":true,"reason":"","preview":"热量 %d→%d" % [heat,mini(10,heat+2)]}
	if b.context.depth_pressure<=0: return {"ok":false,"reason":"Depth为0，无需排压"}
	if heat<1: return {"ok":false,"reason":"需要支付热量1"}
	return {"ok":true,"reason":"","preview":"热%d→%d；Depth %d→%d" % [heat,heat-1,b.context.depth_pressure,maxi(0,b.context.depth_pressure-2)]}
func target_status(card: CardData, target: Variant, check_resources: bool = true) -> Dictionary:
	var b=_ref.get_ref()
	if check_resources:
		var base := status(card)
		if not base.get("ok",false): return base
	if not target is CardData or not is_instance_valid(target): return {"ok":false,"reason":"请选择普通棋子"}
	var field: Array=b.context.enemy.field if card.card_id=="B01" else b.context.player.field
	var state=b._state_for_card(target)
	# Boss cards retain a different family label; registered front-row unit
	# identity is the authority for both sides, buildings are never unit targets.
	var unit_identity: bool=target.is_front_row_card() and (target.card_family=="monster" or target.display_type==CardData.DisplayType.UNIT) and not target.is_building_card()
	if target not in field or not unit_identity or state==null or state.is_dead():
		return {"ok":false,"reason":"请选择敌方普通棋子" if card.card_id=="B01" else "请选择己方普通棋子"}
	if card.card_id=="B01" and b._garrison_assignment_support_intact(b.get_garrison_state_for_unit(target)):
		return {"ok":false,"reason":"驻军受建筑掩护，请先处理城墙"}
	if card.card_id=="B02" and blade_amount(target)>0: return {"ok":false,"reason":"已有未使用的基础赋刃"}
	if card.card_id=="B03" and (b.frontline_trial==null or b.frontline_trial.escort_amount(target)>=2):
		return {"ok":false,"reason":"已有同等护送，或此入口未启用护卫"}
	var hp: int=state.current_hp
	var preview := "生命 %d→%d" % [hp,maxi(0,hp-2)] if card.card_id=="B01" else "下次普通攻击伤害 +2（本回合）" if card.card_id=="B02" else "下次棋子交战减伤2（至下次己方回合）"
	return {"ok":true,"reason":"","preview":preview,"target_runtime_id":target.get_instance_id(),"cell":b.get_unit_cell(target),"hp_before":hp,"hp_after":maxi(0,hp-2) if card.card_id=="B01" else hp,"attack":b.get_effective_unit_attack(target),"blade":blade_amount(target),"escort":b.frontline_trial.escort_amount(target) if b.frontline_trial!=null else 0,"heat":b.context.od_mode.current_od,"turn":b.context.turn_count}

func blade_amount(target: CardData) -> int:
	if target==null: return 0
	var b=_ref.get_ref()
	return 2 if blades.get(target.get_instance_id(),-1)==b.context.turn_count else 0
func consume_blade(target: CardData) -> void:
	if blade_amount(target)>0:
		history.append({"kind":"blade_consumed","target_runtime_id":target.get_instance_id(),"bonus":2})
		blades.erase(target.get_instance_id())
func clear_blades() -> void: blades.clear()

func commit(card: CardData, transaction_id: StringName, target: CardData = null) -> Dictionary:
	var b=_ref.get_ref()
	used_turn_by_id[card.card_id]=b.context.turn_count
	var heat_before: int=b.context.od_mode.current_od
	var depth_before: int=b.context.depth_pressure
	var source: StringName=&"basic_supply:fuel" if card.card_id=="B04" else &"basic_supply:vent" if card.card_id=="B05" else &"basic_supply:target"
	var kind: StringName=&"bonus" if card.card_id=="B04" else &"payment"
	b.context.add_heat(2 if card.card_id=="B04" else -1,source,transaction_id,{"source_descriptor":b.build_heat_source_descriptor(kind,source,card)})
	if card.card_id=="B05": b.context.modify_depth(-2,card.get_display_name())
	var result := {"ok":true,"heat_before":heat_before,"heat_after":b.context.od_mode.current_od,"depth_before":depth_before,"depth_after":b.context.depth_pressure}
	if card.card_id=="B01":
		result.damage=b._apply_unit_damage_gateway(target,2,"basic_strike")
		if b._state_for_card(target).is_dead(): b.destroy_unit(target,"basic_strike")
	elif card.card_id=="B02": blades[target.get_instance_id()]=b.context.turn_count
	elif card.card_id=="B03": b.frontline_trial.grant_escort(target,false)
	if target!=null: result.target_runtime_id=target.get_instance_id()
	history.append(result.duplicate(true))
	return result
