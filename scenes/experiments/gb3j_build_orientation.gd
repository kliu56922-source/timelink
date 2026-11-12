extends "res://scenes/experiments/gb3i_core_siege.gd"

const ORIENTATION_ENTRY := "res://scenes/experiments/gb3j_build_orientation.tscn"
const EDGE_NAMES := {&"north": "北·敌方", &"east": "东", &"south": "南·己方", &"west": "西"}
var _rotate_build_button: Button
var _range_legend: PanelContainer
var _range_text: Label
var _expansion_guide: Control

func _setup_game() -> void:
	super._setup_game()
	context.od_mode.legacy_load_penalty_enabled = false
	battle.frontline_trial.rotation_enabled = true
	battle.on_play_tutors_enabled = true
	for card: CardData in _gb1_selected_cards:
		if card.tutor_enabled and not card.tutor_text_cn.is_empty() and not card.description.contains(card.tutor_text_cn):
			card.description += "\n展开检索：" + card.tutor_text_cn
	_gb1_cards_by_id["P08"].description = _gb1_cards_by_id["P08"].description.replace("本格与前方平台", "塔身与所选方向的平台")
	_gb1_cards_by_id["P08"].description += "\n建造前按R或方向按钮旋转：门楼朝向平台。付款起锁定，重新选位可修改；建成后固定。"
	_rotate_build_button = Button.new()
	_rotate_build_button.name = "RotateBuilding"
	_rotate_build_button.position = Vector2(18, 255)
	_rotate_build_button.size = Vector2(280, 30)
	_rotate_build_button.pressed.connect(_rotate_build)
	add_child(_rotate_build_button)
	_range_legend = PanelContainer.new()
	_range_legend.name = "RangeLegend"
	_range_legend.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_range_legend.custom_minimum_size = Vector2(255, 142)
	add_child(_range_legend)
	_range_text = Label.new()
	_range_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_range_text.add_theme_font_size_override("font_size", 14)
	_range_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_range_text.custom_minimum_size.x = 245
	_range_text.text = "范围图例（方向以棋盘为准）\n黄框：建造双格；箭头：门楼→平台\n橙圈：选中棋子的攻击范围\n红实点：当前可攻击的敌军\n绿圈：驻军警戒，敌回合首伤减1\n紫菱形：伏线监视，移入时拦截\n橙虚线：该列的一次城防穿透"
	_range_legend.add_child(_range_text)

func _can_rotate_build() -> bool:
	if battle == null or battle_ended or _card_being_played: return false
	if not battle.get_command_economy_snapshot("player").get("turn_open", false): return false
	if _is_monster_summon_interaction_active():
		var card: CardData = _monster_drag_session.get("card")
		return card != null and card.card_id == "P08" and _monster_summon_state() in [MONSTER_SUMMON_DRAGGING, MONSTER_SUMMON_RESELECTING]
	if _is_piece_selection_active():
		var card: CardData = _piece_context.get("card")
		return card != null and card.card_id == "P08" and _piece_context.get("stage") == &"anchor"
	if _has_non_presentation_end_turn_busy() or _presentation_end_turn_blocked: return false
	for card: CardData in context.player.hand:
		if card.card_id == "P08": return true
	return false

func _rotate_build() -> void:
	if not _can_rotate_build(): return
	battle.frontline_trial.rotate_build_edge()
	if _is_structure_build_drag_active():
		var card: CardData = _monster_drag_session.get("card")
		var cells := _structure_build_candidate_cells(card)
		_monster_drag_session["legal_cells"] = cells
		if _tactical_presenter != null:
			_tactical_presenter.show_cell_selection(&"build", &"player", MONSTER_DRAG_INVALID_CELL, cells, battle.get_occupied_cells(), {})
		var cell: Vector2i = _monster_drag_session.get("hover_cell", MONSTER_DRAG_INVALID_CELL)
		if cell != MONSTER_DRAG_INVALID_CELL:
			_update_structure_drag_hover_hit({"ok": true, "target_kind": &"tactical_cell", "board_cell": cell})
	elif _is_piece_selection_active():
		var card: CardData = _piece_context.get("card")
		var cells: Array[Vector2i] = battle.get_legal_structure_build_cells(card)
		if _tactical_presenter != null:
			_tactical_presenter.show_piece_selection(&"anchor", &"play", MONSTER_DRAG_INVALID_CELL, cells, _typed_v2i_array([]), _typed_v2i_array([]), {})
		_show_piece_anchor_hint()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R and _can_rotate_build():
		_rotate_build()
		get_viewport().set_input_as_handled()
		return
	# The foreground direction button owns its click, even over the board.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and is_instance_valid(_rotate_build_button) and _rotate_build_button.get_global_rect().has_point(event.position): return
	super._input(event)

func _confirm_piece_anchor(anchor: Variant) -> void:
	var card: CardData = _piece_context.get("card")
	if card != null and card.card_id == "P08" and _piece_context.get("stage") == &"anchor":
		var preview: Dictionary = _piece_context.get("construction_preview_fact", {}).duplicate(true)
		preview["footprint_edge"] = battle.frontline_trial.build_edge
		_piece_context["construction_preview_fact"] = preview
	super._confirm_piece_anchor(anchor)

func _show_piece_anchor_hint() -> void:
	super._show_piece_anchor_hint()
	var card: CardData = _piece_context.get("card")
	if card != null and card.card_id == "P08" and is_instance_valid(_piece_anchor_hint_label):
		_piece_anchor_hint_label.text = "烽堡：塔身＋%s侧平台。按R旋转；平台需空闲、两格高度差不超过1。" % EDGE_NAMES[battle.frontline_trial.build_edge]

func _cleanup_structure_presentation_lifecycle(reason: StringName = &"cleanup") -> void:
	super._cleanup_structure_presentation_lifecycle(reason)
	_frontline_build_preview.clear()

func _process(delta: float) -> void:
	super._process(delta)
	if not is_instance_valid(_rotate_build_button): return
	_rotate_build_button.disabled = not _can_rotate_build()
	_rotate_build_button.text = "平台朝向 %s · 旋转 [R]" % EDGE_NAMES[battle.frontline_trial.build_edge]
	if _rotate_build_button.disabled and _monster_drag_session.get("intent") == &"structure_build":
		_rotate_build_button.text = "方向已锁定：%s（重选可改）" % EDGE_NAMES[battle.frontline_trial.build_edge]
	_rotate_build_button.tooltip_text = "选位前/选位中可旋转；付款及确认时锁定，重新选位后可调整。"
	_range_legend.position = Vector2(get_viewport_rect().size.x - 390, 295)
	_layout_build_refusal()

func _update_structure_drag_hover_hit(hit: Dictionary, pointer_screen_position: Vector2 = Vector2.INF) -> Dictionary:
	var result := super._update_structure_drag_hover_hit(hit, pointer_screen_position)
	_layout_build_refusal()
	return result

func _layout_build_refusal() -> void:
	if is_instance_valid(_structure_interaction_presenter):
		var refusal: Label = _structure_interaction_presenter._build_reason_label
		if is_instance_valid(refusal) and refusal.visible:
			refusal.global_position = Vector2(18, 392)
			refusal.size = Vector2(280, 92)
			refusal.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			refusal.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT

func _draw_frontline() -> void:
	super._draw_frontline()
	if battle == null or battle.frontline_trial == null: return
	var font := ThemeDB.fallback_font
	for structure: Dictionary in battle.get_structure_snapshot().get("structures", {}).values():
		var cells: Array = structure.get("footprint_cells", [])
		if cells.size() == 2: _draw_gate_arrow(cells, Color(0.1, 0.85, 0.9))
	if not _frontline_build_preview.is_empty():
		var cells: Array = _frontline_build_preview.get("preview_footprint_cells", _frontline_build_preview.get("core", {}).get("footprint_cells", []))
		var valid: bool = _frontline_build_preview.get("ok", false)
		var color := Color(1, 0.85, 0.2) if valid else Color(1, 0.25, 0.25)
		if cells.size() == 2:
			_draw_gate_arrow(cells, color)
			for i in range(cells.size()):
				if not battle.tactical_grid_rules.is_cell_in_bounds(cells[i]): continue
				var point := _project_tactical_cell_to_screen(cells[i])
				if point.is_finite():
					_frontline_overlay.draw_rect(Rect2(point - Vector2(45, 25), Vector2(90, 50)), color, false, 3)
					_frontline_overlay.draw_string(font, point + Vector2(-25, -28), "塔身" if i == 0 else "平台", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, color)
	for card: CardData in context.player.traps:
		if card.card_id != "P04": continue
		for cell: Vector2i in battle.reaction_trial.watch_cells(card):
			var point := _project_tactical_cell_to_screen(cell) + Vector2(24, -12)
			if not point.is_finite(): continue
			_frontline_overlay.draw_polyline(PackedVector2Array([point + Vector2(0,-7), point + Vector2(7,0), point + Vector2(0,7), point + Vector2(-7,0), point + Vector2(0,-7)]), Color(0.85, 0.45, 1), 2)
	var actor: CardData = _lane_selection_card if _lane_selection_mode == LANE_SELECT_ATTACK else null
	if actor == null and is_instance_valid(_monster_command_menu) and _monster_command_menu.visible: actor = _monster_command_menu._card
	if actor == null and _is_piece_selection_active() and _piece_context.get("action_id") == &"attack":
		actor = _piece_context.get("card")
		if is_instance_valid(actor):
			for cell in battle.get_legal_attack_cells(actor):
				var point := _project_tactical_cell_to_screen(cell)
				if point.is_finite(): _frontline_overlay.draw_arc(point, 31, 0, TAU, 24, Color(1, 0.55, 0.15), 2)
	if actor != null and actor in context.player.field:
		for target: CardData in context.enemy.field:
			if not battle.get_unit_command_status(actor, "attack", target).get("ok", false): continue
			var point := _project_tactical_cell_to_screen(battle.get_unit_cell(target))
			if point.is_finite(): _frontline_overlay.draw_circle(point + Vector2(0, -25), 6, Color(1, 0.25, 0.2))

func _draw_gate_arrow(cells: Array, color: Color) -> void:
	if not battle.tactical_grid_rules.is_cell_in_bounds(cells[0]) or not battle.tactical_grid_rules.is_cell_in_bounds(cells[1]): return
	var a := _project_tactical_cell_to_screen(cells[0])
	var b := _project_tactical_cell_to_screen(cells[1])
	if not a.is_finite() or not b.is_finite(): return
	var start := a.lerp(b, 0.35)
	var end := a.lerp(b, 0.75)
	var direction := (end - start).normalized()
	_frontline_overlay.draw_line(start, end, color, 3)
	_frontline_overlay.draw_line(end, end - direction.rotated(0.55) * 11, color, 3)
	_frontline_overlay.draw_line(end, end - direction.rotated(-0.55) * 11, color, 3)

func restart_gb1_battle() -> void:
	if _gb1_restarting: return
	_gb1_restarting = true
	if battle != null and battle.reaction_trial != null: battle.reaction_trial.finish_event()
	var err := get_tree().change_scene_to_file(ORIENTATION_ENTRY)
	if err != OK:
		_gb1_restarting = false
		push_error("Orientation restart failed: %d" % err)

func _ready() -> void:
	await super._ready()
	_expansion_guide = preload("res://ui/expansion_route_guide.gd").new()
	_expansion_guide.name = "ExpansionRouteGuide"
	_expansion_guide.provider = _build_expansion_route_view
	add_child(_expansion_guide)
	var feed_lane := get_node_or_null("BattleFX/ActionFeedSafeLane") as Control
	if feed_lane != null:
		# Reserve the right side in order: engine, legend, end turn, then events.
		feed_lane.offset_left = -390
		feed_lane.offset_right = -20
		feed_lane.offset_top = 550
		feed_lane.offset_bottom = 650
		feed_lane.custom_minimum_size = Vector2(370,100)

func _get_structure_reserved_ui_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = super._get_structure_reserved_ui_rects()
	# Left instructions are drawn overlays, so add their occupied zone explicitly.
	rects.append(Rect2(18,255,300,460))
	if is_instance_valid(_range_legend): rects.append(_range_legend.get_global_rect().grow(6))
	if is_instance_valid(_expansion_guide): rects.append(_expansion_guide.get_global_rect().grow(6))
	var feed_lane := get_node_or_null("BattleFX/ActionFeedSafeLane") as Control
	if feed_lane != null: rects.append(feed_lane.get_global_rect())
	return rects


func _build_expansion_route_view() -> Dictionary:
	if battle == null or context == null: return {"text":"对局尚未开始。"}
	var fort_found := false
	for st: Dictionary in battle.get_structure_snapshot().get("structures",{}).values():
		if st.get("owner_side") == &"player" and st.get("source_card_id") == &"P08" and int(st.get("integrity_current",0))>0:
			fort_found = true
	var field_names: Array[String] = []
	for card: CardData in context.player.field: field_names.append(card.get_display_name())
	var hand_names: Array[String] = []
	for card: CardData in context.player.hand: hand_names.append(card.get_display_name())
	var current := "当前：前场%d名；双格烽堡%s；热量%d（仪式需8）；Depth%d/6。" % [field_names.size(),"在场" if fort_found else "未建成",context.od_mode.current_od,context.depth_pressure]
	var next := "先打燃芯使魔，找建筑；有炉基座也可以先建。"
	var foundation: CardData = null
	for card: CardData in context.player.traps:
		if card.card_id == "P05": foundation = card
	if fort_found and field_names.size()>=2:
		next = "已有初步场面：保留外场进攻者，择机驻军＋控制，或让两名不同棋子完成攻击准备。"
		for card: CardData in context.player.field:
			var garrison: Dictionary = _get_garrison_command_status(card)
			if garrison.get("mode") == &"enter":
				next += "\n" + card.get_display_name() + "驻军：" + str(garrison.get("guidance_text",garrison.get("reason","")))
				break
	elif foundation != null:
		var status: Dictionary = battle.get_building_interface_status(foundation,context.player)
		next = "炉基座接口：" + (str(status.get("cost",""))+" → "+str(status.get("preview","")) if status.get("ok",false) else str(status.get("reason","暂不可用")))
		next += "\n热流导体登场找连锁导体；留空烽堡所选方向的平台格，再升级。"
	else:
		for card: CardData in context.player.hand:
			if card.card_id == "P08":
				next = "烽堡已在手：可先建炉基座准备强化/检索，再同格升级；平台需空闲，按R选方向。"
				break
	var text := "目标：用普通牌建立两名棋子＋双格堡垒，留下反制与续展手牌。\n\n"
	text += "① 燃芯使魔 → 检索炉心建筑（仅从真实牌库找牌）。\n"
	text += "② 炉基座 → 预热仪式充能 → 付费强化并检索赋刃/超频。\n"
	text += "③ 热流导体 → 检索连锁导体，补下一段兵力与魔法。\n"
	text += "④ 铁誓烽堡升级 → 合法驻军；保留应急偏转或布置伏线。\n"
	text += "⑤ 驻军＋控制 / 两名不同棋子攻击 → 热量8时完整仪式。\n"
	text += "⑥ 清守卫、推进、朝向核心；按当前预览预留攻城指令。\n\n"
	text += "普通OD：不要求仪式准备完成；看当前合法棋子、目标和费用，比较本回合攻城后再选择。成功释放消耗热量，准备记录保留；领取奖励仍需重新蓄至8热。可用时也可暂缓，取消不付费。\n"
	text += "仪式按钮：完整准备后显示「领取奖励」；未完成时是「应急汇流」，收益较弱且同样消耗本局的一次仪式。领取后继续普通牌与普通OD攻城。\n\n"
	text += current + "\n下一步：" + next + "\n\n"
	text += "场上：" + ("、".join(field_names) if not field_names.is_empty() else "无") + "\n"
	text += "手中：" + ("、".join(hand_names) if not hand_names.is_empty() else "无") + "\n"
	text += "路线可穿插或改走；被拆场时已记录准备保留，当前建筑/棋子收益以存活场面为准。"
	return {"text":text,"field_count":field_names.size(),"fort_present":fort_found}
