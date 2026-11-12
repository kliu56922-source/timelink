extends RefCounted
## Read-only wording. Native battle queries continue to own legality and payment.
static func attack_hint(unit: Dictionary,core: Dictionary,geometry: Dictionary) -> Dictionary:
	var unit_cost:=str(unit.get("cost","?"));var core_cost:=str(core.get("cost","?"))
	var detail:="攻击单位：%s指令\n攻击核心：%s指令\n"%[unit_cost,core_cost]
	var reason:=str(geometry.get("reason","")) if not geometry.get("ok",false) else str(core.get("reason_code",""))
	if core.get("ok",false):detail+="核心可攻击：选择攻击后点Boss生命区。"
	else:
		match reason:
			"guard_intercepted":detail+="核心受守卫拦截。可清除守卫，或从战术工具检查再部署；需充能与合法空格。"
			"front_arc_blocked":detail+="前方敌棋挡住核心通路。先清敌，或检查再部署到其他合法列。"
			"not_breach_rank":detail+="尚未到敌侧突破行。先检查合法移动或再部署。"
			"facing_away_from_core":detail+="当前朝向背离Boss核心，请先检查回防／朝向。"
			"summoning_sickness":detail+="召唤病：本回合不能攻击，等待下一己方回合。"
			"insufficient_command_points":detail+="核心攻击指令不足：需要%s指令；攻击单位费用不同。"%core_cost
			_:detail+="当前不能攻击核心，查看单位状态与合法目标。"
	return {"text":"单位%s / 核心%s"%[unit_cost,core_cost],"detail":detail}
static func od_help() -> String:
	return "普通OD：达到7热门槛，还需合法来源、目标和足够指令；实际费用看所选行动预览。\n仪式奖励：8热＋场上准备，本局仅一次；应急模式也消耗这一次。普通OD不消耗仪式次数。"
