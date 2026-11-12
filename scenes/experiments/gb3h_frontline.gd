extends "res://scenes/experiments/gb3g_reaction_trial.gd"

const FRONTLINE_ENTRY := "res://scenes/experiments/gb3h_frontline.tscn"
var _frontline_overlay: Control
var _frontline_build_preview: Dictionary = {}

func _setup_game() -> void:
	super._setup_game()
	battle.frontline_trial = preload("res://core/battle/frontline_trial.gd").new(battle)
	battle.frontline_trial.begin_turn("player")
	_gb1_cards_by_id["P08"].description += "\n前线规则：占据本格与前方平台，平台可通行。驻军守护自身及相邻友军，每敌方回合首次单体攻击减伤1。敌场驻军合法攻城额外破盾2，每己方回合一次。"
	_gb1_cards_by_id["P05"].description += "\n前线建设：可建在上一己方回合已建立且未移动的友军相邻格；附近有敌军时不可前推。地基与烽堡每局各可建造至少2次，仍需相应卡牌。"
	_gb1_cards_by_id["P01"].description += "\n护送：锚点选友军时，下一次交战受伤减2（强化3），下次己方回合开始过期。同来源不叠加。"
	_gb1_cards_by_id["P01"].short_description = "选友军护送：下一次交战减伤2"
	_gb1_cards_by_id["P06"].description += "\n攻城赋刃：下次合法核心攻击额外破盾2，与驻防破盾取较高值、不叠加；成功攻击或回合结束消耗赋刃。"
	_gb1_cards_by_id["P06"].short_description = "赋刃：下一次攻城额外破盾2"
	_frontline_overlay = Control.new()
	_frontline_overlay.name = "FrontlineRulesOverlay"
	_frontline_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_frontline_overlay)
	_frontline_overlay.draw.connect(_draw_frontline)

func _process(delta: float) -> void:
	super._process(delta)
	if is_instance_valid(_frontline_overlay): _frontline_overlay.queue_redraw()

func _draw_frontline() -> void:
	if battle == null or context == null: return
	var font := ThemeDB.fallback_font
	if not _frontline_build_preview.is_empty():
		for cell in _frontline_build_preview.get("core", {}).get("footprint_cells", []):
			var point := _project_tactical_cell_to_screen(cell)
			if point.is_finite():
				_frontline_overlay.draw_rect(Rect2(point - Vector2(48, 25), Vector2(96, 50)), Color(1, 0.85, 0.25), false, 3)
	for structure: Dictionary in battle.get_structure_snapshot().get("structures", {}).values():
		var cells: Array = structure.get("footprint_cells", [])
		if cells.size() != 2: continue
		var core := _project_tactical_cell_to_screen(cells[0])
		var platform := _project_tactical_cell_to_screen(cells[1])
		if not core.is_finite() or not platform.is_finite(): continue
		_frontline_overlay.draw_line(core, platform, Color(0.1, 0.7, 0.8, 0.75), 5)
		var rect := Rect2(platform - Vector2(44, 20), Vector2(88, 40))
		_frontline_overlay.draw_rect(rect, Color(0.03, 0.22, 0.25, 0.55))
		_frontline_overlay.draw_rect(rect, Color.CYAN, false, 2)
		_frontline_overlay.draw_string(font, platform + Vector2(-40, 5), "驻防平台 %d/%d" % [structure.integrity_current, structure.integrity_max], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
		var assigned: Dictionary = context.tactical_structure_board_state.get_garrison_for_slot(structure.structure_id, &"garrison_0")
		if assigned.get("state", &"") != &"active": continue
		for offset in [Vector2i.ZERO, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var cell: Vector2i = cells[1] + offset
			if not battle.tactical_grid_rules.is_cell_in_bounds(cell): continue
			var point := _project_tactical_cell_to_screen(cell)
			if point.is_finite(): _frontline_overlay.draw_arc(point, 24, 0, TAU, 24, Color(0.2, 1, 0.6, 0.7), 2)
	var text := "敌方堡垒 · 城防 %d\n己方堡垒 · 城防 %d\n城防使用现有护盾，破开后伤害进入核心。\n前线驻军：合法攻城额外破盾2。" % [context.enemy.boss_shield, context.player.shield]
	var area := Rect2(18, 290, 280, 92)
	_frontline_overlay.draw_rect(area, Color(0.02, 0.04, 0.07, 0.94))
	var y := area.position.y + 20
	for line in text.split("\n"):
		_frontline_overlay.draw_string(font, Vector2(26, y), line, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.8, 0.94, 1))
		y += 20
	if is_instance_valid(_monster_command_menu) and _monster_command_menu.visible:
		var unit: CardData = _monster_command_menu._card
		if unit != null and unit in context.player.field:
			for cell in battle.get_legal_attack_cells(unit):
				var point := _project_tactical_cell_to_screen(cell)
				if point.is_finite(): _frontline_overlay.draw_arc(point, 31, 0, TAU, 24, Color(1, 0.55, 0.15), 2)
			var status: Dictionary = battle.can_monster_attack_boss(unit)
			var state = battle._state_for_card(unit)
			var lines: Array[String] = [
				unit.get_display_name(),
				"攻击 %d · 生命 %d/%d" % [battle.get_effective_unit_attack(unit), state.current_hp, state.max_hp],
				"橙圈：攻击范围；绿圈：驻防警戒。",
				"攻城可用 · 额外破盾 %d" % battle.frontline_trial.breach_amount(unit) if status.get("ok", false) else "攻城：" + _map_attack_reason_text(StringName(status.get("reason", "")), status),
				"护送减伤 %d · 赋刃 %s" % [battle.frontline_trial.escort_amount(unit), "已就绪" if not battle._get_bishop_enchant(unit).is_empty() else "无"]
			]
			_frontline_overlay.draw_rect(Rect2(18, 390, 330, 118), Color(0.02, 0.04, 0.07, 0.94))
			for i in range(lines.size()):
				_frontline_overlay.draw_string(font, Vector2(26, 410 + i * 21), lines[i], HORIZONTAL_ALIGNMENT_LEFT, 310, 14, Color.WHITE)

func _show_structure_build_preview(status: Dictionary, visual_state: StringName) -> void:
	super._show_structure_build_preview(status, visual_state)
	_frontline_build_preview = status.duplicate(true)

func _clear_structure_build_preview() -> void:
	super._clear_structure_build_preview()
	_frontline_build_preview.clear()

func _show_piece_anchor_hint() -> void:
	super._show_piece_anchor_hint()
	var card: CardData = _piece_context.get("card")
	if card != null and card.card_id == "P08" and is_instance_valid(_piece_anchor_hint_label):
		_piece_anchor_hint_label.text = "烽堡占两格：本格为塔身、前方为平台。两格均需空闲，平台高度差不超过1。"
	if card != null and card.card_id == "P01" and is_instance_valid(_piece_anchor_hint_label):
		_piece_anchor_hint_label.text = "选择友军可额外护送：下一次交战减伤2（强化3），持续到下次己方回合。"
	if card != null and card.card_id == "P06" and is_instance_valid(_piece_anchor_hint_label):
		_piece_anchor_hint_label.text = "选择友军赋刃：本回合下一次合法攻城额外破盾2，与前线驻军收益不叠加。"

func _garrison_guidance_text(status: Dictionary, mode: StringName) -> String:
	var text := super._garrison_guidance_text(status, mode)
	if mode == &"enter" and status.get("ok", false):
		text += "\n驻军警戒自身及相邻格：每敌方回合首次单体攻击减伤1；绿圈表示警戒。"
	return text

func restart_gb1_battle() -> void:
	if _gb1_restarting: return
	_gb1_restarting = true
	if battle != null and battle.reaction_trial != null: battle.reaction_trial.finish_event()
	var err := get_tree().change_scene_to_file(FRONTLINE_ENTRY)
	if err != OK:
		_gb1_restarting = false
		push_error("Frontline restart failed: %d" % err)
