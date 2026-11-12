extends "res://battle/analysis/od_cooling_relation_advisor.gd"
## A current board fact alongside card relations, never an automatic order.
const CurrentTradeoff := preload("res://battle/analysis/empty_knight_od_tradeoff.gd")

func get_relations(s: Variant, focus: CardData) -> Dictionary:
	var result := super.get_relations(s,focus)
	if result.focus == null or result.suppressed: return result
	var q: Dictionary = CurrentTradeoff.new().inspect(s.battle)
	if q.reason != "known_hit": return result
	var source: CardData
	for card: CardData in s.context.player.field:
		if is_instance_valid(card) and card.get_instance_id() == q.source_runtime_id: source = card;break
	if source == null: return result
	var hit: Dictionary = q.cells[-1]
	var target: CardData
	for card: CardData in s.context.enemy.field:
		if is_instance_valid(card) and card.get_instance_id() == hit.target_runtime_id: target = card;break
	if target == null: return result
	var cell := Vector2i(hit.cell[0],hit.cell[1])
	var status: Dictionary = s.battle.get_od_release_target_status(source,cell)
	if not status.get("ok",false): return result
	var heat: int = s.context.od_mode.current_od
	var converted: int = int(status.get("converted_heat",0))
	var location := "%s%d" % [String.chr(65+cell.x),cell.y+1]
	var text := "当前棋盘 · OD窗口\n%s → %s；落点%s。\n费用%d热 / %d指令；基础转热%d→%d。\n%d热转入引擎充能，层级以结算为准；Depth不因此恢复。\n可用右侧普通OD选择来源与落点并确认；行动后重查。" % [source.get_display_name(),target.get_display_name(),location,int(status.od_cost),int(status.command_cost),heat,heat-converted,converted]
	result.od_window = {"source_runtime_id":source.get_instance_id(),"target_runtime_id":target.get_instance_id(),
		"cell":hit.cell.duplicate(),"od_cost":int(status.od_cost),"command_cost":int(status.command_cost),
		"converted_heat":converted,"heat_before":heat,"base_heat_after":heat-converted,"text":text}
	return result
