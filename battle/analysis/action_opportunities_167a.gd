extends "res://battle/analysis/current_action_opportunities.gd"
const Clarity=preload("res://battle/analysis/operation_clarity_167a.gd")
func inspect(s: Variant) -> Dictionary:
	var result:=super.inspect(s)
	if s==null or s.battle==null or not Clarity.body_mode(s):return result
	for row: Dictionary in result.rows:
		if row.kind!="unit":continue
		var actor:=source(s,row)
		var q:=Clarity.body_status(s,actor)
		row.text="%s · %s\n点单位→攻击Boss本体 · %d指令"%[actor.get_display_name(),q.label,q.cost]
	return result
