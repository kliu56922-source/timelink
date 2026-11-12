extends "res://scenes/experiments/gb3f_ritual_finisher.gd"

const ReactionTrial := preload("res://core/battle/reaction_trial.gd")
const REACTION_ENTRY := "res://scenes/experiments/gb3g_reaction_trial.tscn"
var _reaction_layer: CanvasLayer
var _reaction_panel: PanelContainer
var _reaction_text: Label
var _reaction_error: Label
var _reaction_enhanced: Button
var _reaction_history_seen := 0

func _gb1_prepare_startup() -> void:
	super._gb1_prepare_startup()
	if not _gb1_startup_ok: return
	var trip: CardData = _gb1_cards_by_id["P04"]
	var emergency := CardData.clone_card_entity(trip)
	emergency.card_id = "R01"
	emergency.card_name = "Emergency Deflection"
	emergency.display_name = "应急偏转"
	emergency.english_name = "Emergency Deflection"
	emergency.archetype_role = CardData.ArchetypeRole.DEFENSE
	emergency.route_id = ""
	emergency.art = null
	emergency.art_path = ""
	emergency.thumb_path = ""
	emergency.detail_path = ""
	emergency.short_description = "预设减伤3／手发OD−1减伤2"
	emergency.description = "预设：敌方回合，监视格内友军首次受到单体攻击时减伤3，随后消耗。手发：OD−1，本次减伤2；可透支Depth+1改为减伤3。每敌方回合手发一次。"
	for card in [trip, emergency]:
		# These are freshly loaded/cloned local cards; retiring their old effects does not resolve them.
		for effect in card.effects:
			if is_instance_valid(effect) and effect is Node and effect.get_parent() == null:
				effect.free()
		card.effects = []
		card.keywords.clear()
		card.require_od = 0
		card.route_id = ""
		card.od_cost = 0
		card.archetype_role = CardData.ArchetypeRole.DEFENSE
		card.od_interface_text = ""
		card.activation_condition_text = ""
		card.risk_text = ""
		card.calm_text = ""
		card.heated_text = ""
		card.overdrive_text = ""
		card.combo_reward_text = ""
	trip.card_name = "Tripwire Intercept"
	trip.short_description = "敌军进入监视格：阻止本次移动"
	trip.description = "预先布置。敌方从监视范围外移入时阻止本次移动，随后消耗。未触发则保留。敌方仍支付本次行动费用。"
	_gb1_owned_cards.append(emergency)
	_gb1_cards_by_id["R01"] = emergency
	_gb1_selected_cards.clear()
	for id in ["P01", "P02", "P04", "R01", "P05", "P07", "P08", "P23", "P06", "P22", "P03", "P09", "P10", "P11", "P14", "P13"]:
		_gb1_selected_cards.append(_gb1_cards_by_id[id])

func _setup_game() -> void:
	super._setup_game()
	battle.reaction_trial = ReactionTrial.new(battle)

func _show_piece_anchor_hint() -> void:
	super._show_piece_anchor_hint()
	var card: CardData = _piece_context.get("card")
	if card != null and card.card_id == "R01" and is_instance_valid(_piece_anchor_hint_label):
		_piece_anchor_hint_label.text = "应急偏转：选择布置格，预览前方监视区域；留在手中可应急反制"

func _refresh_tables() -> void:
	super._refresh_tables()
	if player_table == null or player_table._hand_layout_external == null: return
	for child in player_table._hand_layout_external.get_children():
		if not child is CardUI or child.card_data == null or child.card_data.card_id != "R01": continue
		if child.get_node_or_null("ReactionCardText") != null: continue
		var label := Label.new()
		label.name = "ReactionCardText"
		label.text = "应急偏转\n\n预设：减伤 3\n手发：OD−1 减伤2\n敌方攻击时响应"
		label.position = Vector2(10, 48)
		label.size = Vector2(120, 115)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 12)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		child.add_child(label)

func _ensure_reaction_panel() -> void:
	if is_instance_valid(_reaction_layer): return
	_reaction_layer = CanvasLayer.new()
	_reaction_layer.name = "ReactionWindow"
	_reaction_layer.layer = 180
	add_child(_reaction_layer)
	var blocker := Control.new()
	blocker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	_reaction_layer.add_child(blocker)
	_reaction_panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.065, 0.085, 1.0)
	style.border_color = Color(0.35, 0.8, 0.88)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	_reaction_panel.add_theme_stylebox_override("panel", style)
	_reaction_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_reaction_panel.offset_left = -295
	_reaction_panel.offset_right = 295
	_reaction_panel.offset_top = 130
	_reaction_panel.offset_bottom = 350
	blocker.add_child(_reaction_panel)
	var margin := MarginContainer.new()
	for edge in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + edge, 14)
	_reaction_panel.add_child(margin)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	margin.add_child(body)
	_reaction_text = Label.new()
	_reaction_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_reaction_text.custom_minimum_size.x = 540
	_reaction_text.add_theme_font_size_override("font_size", 17)
	body.add_child(_reaction_text)
	var row := HBoxContainer.new()
	body.add_child(row)
	for item in [["base", "发动 · OD−1"], ["enhanced", "透支 · OD−1 / Depth+1"], ["pass", "放过这次"], ["skip", "本回合不再询问"]]:
		var button := Button.new()
		button.name = "Reaction_" + item[0]
		button.text = item[1]
		button.pressed.connect(_choose_reaction.bind(item[0]))
		row.add_child(button)
		if item[0] == "enhanced": _reaction_enhanced = button
	_reaction_error = Label.new()
	body.add_child(_reaction_error)
	_reaction_layer.hide()

func _choose_reaction(mode: String) -> void:
	var service = battle.reaction_trial
	var result: Dictionary = service.choose(service.event.get("event_id", -1), mode)
	if not result.get("ok", false):
		_reaction_error.text = result.get("reason", "无法发动")
	else:
		_reaction_layer.hide()

func _input(event: InputEvent) -> void:
	if battle != null and battle.reaction_trial != null and battle.reaction_trial.waiting:
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			_choose_reaction("pass")
			get_viewport().set_input_as_handled()
		return
	super._input(event)

func _before_boss_tactical_candidate(candidate: Dictionary) -> void:
	var service = battle.reaction_trial
	var preview: Dictionary = service.begin_event(candidate)
	if not service.waiting: return
	_ensure_reaction_panel()
	var damage: int = preview.damage_after_prepared
	var heat: int = context.od_mode.current_od
	var depth: int = context.depth_pressure
	_reaction_text.text = "敌方行动 · 可以反制\n%s → %s\n预计伤害 %d；应急后 %d，透支后 %d\nOD %d → %d　Depth %d → %d（仅透支）%s" % [preview.actor_name, preview.target_name, damage, maxi(0, damage - 2), maxi(0, damage - 3), heat, heat - 1, depth, depth + 1, "\n支付后 OD 低于 8，暂不能终结。" if heat == 8 else ""]
	_reaction_enhanced.disabled = depth >= 5
	_reaction_enhanced.tooltip_text = "Depth 达到 5，不能透支" if depth >= 5 else "本次减伤改为 3"
	_reaction_error.text = "只减轻此次伤害，交战仍会发生。每回合手发一次；Esc 放过。"
	if not preview.get("garrison_cover", {}).is_empty():
		_reaction_error.text = "预计伤害已计入驻防掩护−1。" + _reaction_error.text
	if int(preview.get("escort_prevention", 0)) > 0:
		_reaction_error.text = "已计入护送保护−%d。" % preview.escort_prevention + _reaction_error.text
	_reaction_layer.show()
	while service.waiting and not battle_ended and is_inside_tree():
		await get_tree().process_frame
	if is_instance_valid(_reaction_layer): _reaction_layer.hide()
	if battle_ended: service.finish_event()

func _present_boss_tactical_action(choice: Dictionary, result: Dictionary) -> void:
	var service = battle.reaction_trial
	while _reaction_history_seen < service.history.size():
		var fact: Dictionary = service.history[_reaction_history_seen]
		_reaction_history_seen += 1
		if action_feed:
			var message := "断频伏线：阻止移动" if fact.kind == "tripwire" else "应急偏转：本次减伤 %d" % fact.prevented
			if fact.kind == "garrison": message = "驻防掩护：%s 保护友军，减伤 %d" % [fact.guard, fact.prevented]
			if fact.kind == "escort": message = "预热护送：本次减伤 %d" % fact.prevented
			action_feed.push_message(message, Color(0.4, 0.9, 1.0), "", 3.0)
	if result.get("intercepted", false):
		_refresh_tables()
		await get_tree().create_timer(0.3).timeout
		return
	await super._present_boss_tactical_action(choice, result)

func restart_gb1_battle() -> void:
	if _gb1_restarting: return
	_gb1_restarting = true
	if battle.reaction_trial != null: battle.reaction_trial.finish_event()
	var error := get_tree().change_scene_to_file(REACTION_ENTRY)
	if error != OK:
		_gb1_restarting = false
		push_error("Reaction trial restart failed: %d" % error)
