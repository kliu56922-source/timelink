extends "res://core/battle/maintenance_battle_system.gd"
## One observation at the real execution boundary, before possible lethal damage.
signal boss_card_committed167a(card: CardData)
var _observed_boss167a: CardData
var _reported_boss167a:=false
func boss_play_card(card: CardData) -> void:
	if card==null or context==null:return
	_observed_boss167a=card;_reported_boss167a=false
	var was_preparation: bool=preparation_active166b()
	var was_prepared: bool=opening166b.boss_prepared
	var back_valid: bool=card.is_back_row_card() and context.enemy.traps.size()<MAX_TRAP_SIZE
	super.boss_play_card(card)
	if was_preparation:
		if not was_prepared and opening166b.boss_prepared:_report_boss167a(card)
	elif back_valid and card in context.enemy.traps:_report_boss167a(card)
	_observed_boss167a=null
func _boss_execute_effects(card: CardData,enemy_obj: Enemy) -> void:
	if card==_observed_boss167a:_report_boss167a(card)
	super._boss_execute_effects(card,enemy_obj)
func _report_boss167a(card: CardData) -> void:
	if _reported_boss167a:return
	_reported_boss167a=true
	boss_card_committed167a.emit(card)
