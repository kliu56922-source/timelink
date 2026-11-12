extends "res://battle/analysis/card_relation_advisor.gd"
## Opt-in visible relationship only; never prescribes or executes action order.
const CoolingWindowInspector := preload("res://battle/analysis/cooling_od_window.gd")
var window_inspector := CoolingWindowInspector.new()
func _relation(s: Variant, a: CardData, b: CardData) -> Dictionary:
	var original := super._relation(s, a, b)
	var cooling: CardData
	var knight: CardData
	if a.card_id == "P11" and b.piece_type == &"knight": cooling = a; knight = b
	elif b.card_id == "P11" and a.piece_type == &"knight": cooling = b; knight = a
	else: return original
	if knight not in s.context.player.field: return original
	var q: Dictionary = window_inspector.inspect(s.battle, cooling)
	if not q.check_before_cooling: return original
	var relevant: Array = q.known_hits.filter(func(hit): return hit.source_runtime_id == knight.get_instance_id())
	if relevant.is_empty(): return original
	var targets: Array[String] = []
	for hit: Dictionary in relevant:
		for target: CardData in s.context.enemy.field:
			if is_instance_valid(target) and target.get_instance_id() == hit.target_runtime_id and target.get_display_name() not in targets:
				targets.append(target.get_display_name())
	var release: Dictionary = s.battle.get_od_release_source_status(knight)
	var effect := "当前OD对象：%s；费用%d热/%d指令。" % ["、".join(targets), release.get("od_cost", 0), release.get("command_cost", 0)]
	effect += " 冷却：" + cooling.short_description
	var reason := "冷却基础热量%d→%d（含当前重复）；比较转热与恢复。完整效果以确认结算为准。" % [q.heat, q.base_heat_after]
	return _row(b, &"declared", &"present", reason, effect, _zone(s,b), -1)
