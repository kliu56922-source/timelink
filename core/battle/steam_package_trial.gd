extends RefCounted
## GB3K: queries are read-only; only BattleSystem's successful card commit pays/searches.
var battle
var used_turn_by_id: Dictionary = {}

func _init(owner) -> void:
	battle = owner

func criteria(card: CardData) -> Dictionary:
	return {"series_id":"steam_monster", "card_family":"monster",
		"tags_any":["extender"] if card.card_id == "S01" else ["starter","extender"],
		"exclude_ids":["A06"], "normal_monsters":true, "exclude_names":[card.card_name]}

func used(card: CardData) -> bool:
	return used_turn_by_id.get(card.card_id,-1) == battle.context.turn_count

func has_steam_unit() -> bool:
	for card: CardData in battle.context.player.field:
		if not is_instance_valid(card): continue
		var state = battle._state_for_card(card)
		if state != null and not state.is_dead() and (card.series_id == "steam_monster" or "steam_monster" in card.secondary_series_ids): return true
	return false

func has_building() -> bool:
	for st: Dictionary in battle.get_structure_snapshot().get("structures",{}).values():
		if st.get("owner_side") != &"player" or st.get("status") != &"intact" or int(st.get("integrity_current",0)) <= 0: continue
		for card: CardData in battle.context.player.traps:
			if card.get_instance_id() == int(st.get("source_runtime_id",-1)) and card.is_building_card() and card.series_id in ["core_cathedral","steam_monster"]: return true
	return false

func recovery_candidates() -> Array[CardData]:
	var p = battle.context.player
	var found: Array[CardData] = []
	for card: CardData in p.graveyard:
		if not is_instance_valid(card) or card.card_id in ["A06","S03"] or card.is_arsenal_card or card.card_family != "monster": continue
		if card.series_id != "steam_monster": continue
		if card in p.hand or card in p.deck or card in p.field or card in p.traps or card in p.discard: continue
		if battle.get_unit_cell(card) != battle.INVALID_GRID_CELL: continue
		if card not in found: found.append(card)
	return found

func search_status(card: CardData, after_play: bool = false) -> Dictionary:
	if used(card): return {"ok":false,"reason":"同名效果本回合已使用"}
	if card.card_id == "S01" and not has_building(): return {"ok":false,"reason":"没有完好己方炉心/蒸汽建筑；登场仍留下1/2棋子"}
	var p = battle.context.player
	var resulting_size: int = p.hand.size() - (1 if not after_play and card in p.hand else 0)
	if resulting_size >= p.MAX_HAND_SIZE: return {"ok":false,"reason":"手牌已满，不能检索"}
	var matches: Array = recovery_candidates() if card.card_id == "S03" else battle.find_cards_in_deck(criteria(card))
	if matches.is_empty(): return {"ok":false,"reason":"墓地没有可回收的蒸汽普通怪兽" if card.card_id == "S03" else "牌库没有符合条件的蒸汽普通怪兽"}
	return {"ok":true,"reason":"","target":matches[0],"preview":("回收：" if card.card_id == "S03" else "检索：") + matches[0].get_display_name() + ("（按墓地顺序）" if card.card_id == "S03" else "（按牌库顺序）")}

func get_play_status(card: CardData) -> Dictionary:
	if not battle.get_command_economy_snapshot("player").get("turn_open",false): return {"ok":false,"reason":"请在己方回合使用"}
	if battle.context.player.hp <= 0 or battle.context.enemy.hp <= 0: return {"ok":false,"reason":"对局已结束"}
	if card.card_id == "S01": return {"ok":true,"reason":"","entry_search":search_status(card)}
	if used(card): return {"ok":false,"reason":card.get_display_name()+"本回合同名已使用"}
	if card.card_id == "S02" and not has_steam_unit(): return {"ok":false,"reason":"先让一名蒸汽棋子登场"}
	if battle.context.od_mode.current_od < 1: return {"ok":false,"reason":"需要支付热量1；当前热量不足"}
	return search_status(card)

func commit(card: CardData, transaction_id: StringName) -> Dictionary:
	var status := search_status(card,true)
	if not status.get("ok",false):
		battle.tutor_failed.emit(card.get_display_name(),str(status.reason))
		return status
	# No await or presentation callback between preflight and this committed step.
	used_turn_by_id[card.card_id] = battle.context.turn_count
	var payment: Dictionary = {}
	if card.card_id in ["S02","S03"]:
		var source := &"steam_recovery:payment" if card.card_id == "S03" else &"steam_dispatch:payment"
		payment = battle.context.add_heat(-1,source,transaction_id,{"source_descriptor":battle.build_heat_source_descriptor(&"payment",source,card)})
	var receipt: Dictionary = {}
	if card.card_id == "S03":
		var found: CardData = status.target
		var p = battle.context.player
		while found in p.graveyard: p.graveyard.erase(found)
		if battle.graveyard_system != null:
			while found in battle.graveyard_system.player_graveyard: battle.graveyard_system.remove_from_player_graveyard(found)
		p.hand.append(found)
		receipt = {"ok":true,"card":found,"message":"回收：%s → %s（加入手牌，需正常登场）" % [card.get_display_name(),found.get_display_name()]}
	else:
		receipt = battle.tutor_first_matching_card(criteria(card),card.get_display_name())
	receipt["heat_paid"] = -int(payment.get("applied",0))
	if receipt.get("ok",false): battle.card_tutored.emit(card.get_display_name(),receipt.card,str(receipt.message))
	else: battle.tutor_failed.emit(card.get_display_name(),str(receipt.message))
	return receipt
