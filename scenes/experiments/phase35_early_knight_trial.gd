extends "res://scenes/experiments/gb3m_basic_combinations.gd"
## Opt-in source timing candidate. No battle-state or number overrides.
const PHASE35_ENTRY := "res://scenes/experiments/phase35_early_knight_trial.tscn"

func reorder_source_cards(cards: Array) -> Array:
	if cards.size() < 3: return []
	var source_index := -1
	for index in cards.size():
		var card: Variant = cards[index]
		if not is_instance_valid(card) or not card is CardData: return []
		if card.card_id == "P02":
			if source_index >= 0: return []
			source_index = index
	if source_index < 0: return []
	var order := cards.duplicate()
	var source: CardData = order.pop_at(source_index)
	order.insert(2, source)
	return order

func _gb1_prepare_startup() -> void:
	super._gb1_prepare_startup()
	if not _gb1_startup_ok: return
	var order := reorder_source_cards(_gb1_selected_cards)
	if order.is_empty():
		_gb1_startup_ok = false
		_gb1_startup_problems.append("马型牌序候选无唯一合法来源")
		return
	_gb1_selected_cards = order

func _ready() -> void:
	set_meta("player_trial", true)
	await super._ready()

func restart_gb1_battle() -> void:
	if _gb1_restarting: return
	_gb1_restarting = true
	if battle != null and battle.reaction_trial != null: battle.reaction_trial.finish_event()
	var error := get_tree().change_scene_to_file(PHASE35_ENTRY)
	if error != OK:
		_gb1_restarting = false
		push_error("Early source trial restart failed: %d" % error)
