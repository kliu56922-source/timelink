extends "res://battle/analysis/training_journal_168b.gd"
func snapshot168a() -> Dictionary:
 var result: Dictionary=super.snapshot168a()
 if result.is_empty():return result
 result.mode="168B2_maintenance_training"
 result.scope="real19card rules; native guard retaliation causes chosen injury/loss; readonly maintenance observations; no injected damage/cards/resources; no ordinary winrate"
 return result
