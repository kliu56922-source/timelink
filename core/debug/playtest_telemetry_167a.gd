extends "res://core/debug/playtest_telemetry.gd"
## Native committed-card counters are complete; legacy UI detail events are not.
## Observe before turn reset and finish_run. Never mutate the battle/context.
var _context167a: WeakRef
var _card_counts167a: Dictionary={}
func adopt167a(previous: PlaytestTelemetry,ctx: BattleContext) -> void:
	for property: Dictionary in previous.get_property_list():
		if int(property.usage)&PROPERTY_USAGE_SCRIPT_VARIABLE:set(property.name,previous.get(property.name))
	_context167a=weakref(ctx)
	observe_cards167a()
func observe_cards167a() -> void:
	var ctx: Variant=_context167a.get_ref() if _context167a!=null else null
	if ctx==null:return
	var turn: int=ctx.turn_count
	_card_counts167a[turn]=maxi(int(_card_counts167a.get(turn,0)),int(ctx.cards_played_this_turn))
	total_cards_played=0
	for count: int in _card_counts167a.values():total_cards_played+=count
func record_event(event_name: String,data: Dictionary={}) -> void:
	super.record_event(event_name,data)
	if event_name=="card_played":observe_cards167a()
func record_turn_snapshot(side: String,ctx,battle) -> void:
	observe_cards167a()
	super.record_turn_snapshot(side,ctx,battle)
func finish_run(outcome: String,ctx,battle) -> void:
	observe_cards167a()
	super.finish_run(outcome,ctx,battle)
func build_summary() -> Dictionary:
	var result167a:=super.build_summary()
	result167a.card_count_source="BattleContext committed cards_played_this_turn, accumulated by native player turn; legacy detail events are not complete"
	result167a.card_count_by_native_turn=_card_counts167a.duplicate(true)
	return result167a
