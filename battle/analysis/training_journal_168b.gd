extends "res://battle/analysis/training_journal_168a.gd"
func snapshot168a() -> Dictionary:
 var result: Dictionary=super.snapshot168a()
 if result.is_empty():return result
 result.mode="168B_single_guard"
 result.scope="fixed19 real player rules; one initial native3/4 guard at column2 row2; no active enemy turns, entry effects or respawn; passive retaliation retained; not human winrate"
 return result
