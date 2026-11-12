extends "res://battle/analysis/charged_cannon_window.gd"
## Audit strategy only. Original current stack/cost/core legality always remains authoritative.
## A past sampled cannon is not a gameplay once-per-battle restriction.
func inspect(battle: Variant,_used: bool) -> Dictionary:
	return super.inspect(battle,false)
