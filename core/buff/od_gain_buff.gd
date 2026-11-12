extends "res://core/buff/buff.gd"

var _heat_occurrence_serial: int = 0

func _init() -> void:
	duration = 3

func on_card_played(context: BattleContext, card: CardData) -> void:
	_heat_occurrence_serial += 1
	var runtime_id := card.get_instance_id() if card != null else 0
	var tx := StringName("buff_od_gain:%d:%d:%d" % [context.turn_count, runtime_id, _heat_occurrence_serial])
	var source_id := &"buff:od_gain"
	context.add_heat(1, source_id, tx, {
		"source_descriptor": context.get_heat_source_descriptor(&"buff", source_id),
		"occurrence_id": StringName("%d" % _heat_occurrence_serial),
		"card_id": str(card.card_id) if card != null else "",
	})
	print("[BUFF] OdGain: +1 OD")
