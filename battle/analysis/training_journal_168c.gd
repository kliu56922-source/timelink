extends "res://battle/analysis/training_journal_168b2.gd"
func snapshot168a() -> Dictionary:
 var result: Dictionary=super.snapshot168a()
 if result.is_empty():return result
 result.mode="168C_compact_actions"
 result.scope="real19card rules; explicit source+purpose combined, single ordinary attack via native authority; original quotes/fees/UIDs/rest preserved; not human winrate"
 return result
