extends "res://scenes/experiments/gb3h_frontline.gd"

const CORE_SIEGE_ENTRY := "res://scenes/experiments/gb3i_core_siege.tscn"
var _siege_panel: PanelContainer
var _siege_label: Label
var _siege_fortresses: Array[Node3D] = []

func _setup_game() -> void:
	super._setup_game()
	battle.core_siege_trial = preload("res://core/battle/core_siege_trial.gd").new(battle)
	_gb1_cards_by_id["P04"].description += "\n城防压制：实际拦截后，该列首次合法攻城可穿盾一次，直到下个己方回合结束；仍受护甲和阶段保护。同列不叠加。"
	_gb1_cards_by_id["P04"].short_description = "伏线拦截；该列获得一次穿盾窗口"
	_siege_panel = PanelContainer.new()
	_siege_panel.name = "CoreSiegePreview"
	_siege_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_siege_panel.position = Vector2(18, 520)
	_siege_panel.custom_minimum_size = Vector2(310, 150)
	add_child(_siege_panel)
	_siege_label = Label.new()
	_siege_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_siege_label.add_theme_font_size_override("font_size", 14)
	_siege_label.add_theme_constant_override("line_spacing", 0)
	_siege_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_siege_label.custom_minimum_size.x = 302
	_siege_panel.add_child(_siege_label)
	call_deferred("_build_core_fortresses")

func _build_core_fortresses() -> void:
	if not is_inside_tree(): return
	_ensure_grid_cell_anchors()
	var player_core := _ensure_player_core_piece_anchor()
	var boss_core := _get_3d_slot_anchor("BOSS_CORE")
	if player_core != null: _add_fortress(player_core, Color(0.12, 0.48, 0.56), "PlayerFortress")
	if boss_core != null: _add_fortress(boss_core, Color(0.6, 0.24, 0.1), "BossFortress")

func _add_fortress(core: Node3D, color: Color, title: String) -> void:
	var fort := Node3D.new()
	fort.name = title
	core.add_child(fort)
	# Board sockets may carry rotated/scaled GLB transforms. Build in grid axes.
	var row := 0 if title == "BossFortress" else 4
	var middle: Node3D = _grid_cell_anchors.get(Vector2i(2, row))
	var side: Node3D = _grid_cell_anchors.get(Vector2i(3, row))
	var inner: Node3D = _grid_cell_anchors.get(Vector2i(2, 1 if row == 0 else 3))
	if middle != null and side != null and inner != null:
		fort.top_level = true
		var right := (side.global_position - middle.global_position).normalized()
		var back := right.cross(Vector3.UP).normalized()
		var distance := 1.0 if title == "BossFortress" else 0.7
		fort.global_transform = Transform3D(Basis(right, Vector3.UP, back), middle.global_position + (middle.global_position - inner.global_position) * distance)
	if title == "BossFortress":
		_ensure_boss_core_click_area(fort)
		var shape := fort.get_node("BossCoreClickArea/ClickShape") as CollisionShape3D
		var box := BoxShape3D.new()
		box.size = Vector3(1.05, 0.5, 0.45)
		shape.shape = box
	_siege_fortresses.append(fort)
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.45
	for x in [-0.4, 0.0, 0.4]:
		var mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.27, 0.32 if x != 0.0 else 0.16, 0.32)
		mesh.mesh = box
		mesh.material_override = material
		mesh.position = Vector3(x, box.size.y * 0.5, 0)
		fort.add_child(mesh)

func _get_boss_screen_pos() -> Vector2:
	for fort in _siege_fortresses:
		if is_instance_valid(fort) and fort.name == "BossFortress":
			return _project_world_position_to_screen(fort.global_position + Vector3.UP * 0.2)
	return super._get_boss_screen_pos()

func _open_monster_command_menu(card: CardData) -> void:
	super._open_monster_command_menu(card)
	if is_instance_valid(_monster_command_menu):
		_monster_command_menu.position.x = maxf(355, _monster_command_menu.position.x)

func _process(delta: float) -> void:
	super._process(delta)
	if not is_instance_valid(_siege_label) or battle == null: return
	_siege_panel.position.y = minf(520, get_viewport_rect().size.y - 195)
	var lines: Array[String] = ["城防突破 · P04伏线"]
	var columns: Array = battle.core_siege_trial.columns.keys()
	columns.sort()
	var names := PackedStringArray()
	for column in columns: names.append(str(int(column) + 1))
	lines.append("无压制窗口 · 伏线拦截后开启" if columns.is_empty() else "第%s列可穿盾1次" % "、".join(names))
	if not columns.is_empty():
		lines.append("本回合结束时消失；橙色虚线列" if battle.get_command_economy_snapshot("player").get("turn_open", false) else "到下个己方回合结束；橙色虚线列")
	var actor: CardData = null
	if _lane_selection_mode == LANE_SELECT_ATTACK and is_instance_valid(_lane_selection_card):
		actor = _lane_selection_card
	elif is_instance_valid(_monster_command_menu) and _monster_command_menu.visible:
		actor = _monster_command_menu._card
	elif _is_piece_selection_active() and _piece_context.get("action_id") == &"attack":
		actor = _piece_context.get("card")
	if is_instance_valid(actor) and actor in context.player.field:
		var target: CardData = null
		if _lane_selection_mode == LANE_SELECT_ATTACK:
			var hit := _raycast_3d_click(get_viewport().get_mouse_position())
			var hit_card: CardData = hit.get("card")
			if is_instance_valid(hit_card) and hit_card in context.enemy.field: target = hit_card
			var cell: Vector2i = hit.get("board_cell", Vector2i(-99, -99))
			for enemy: CardData in context.enemy.field:
				if battle.get_unit_cell(enemy) == cell: target = enemy
		if target != null:
			lines.append_array(_unit_preview_lines(actor, target))
		else:
			lines.append_array(_core_preview_lines(actor))
	else:
		lines.append_array(_siege_window_guidance())
	if _is_piece_selection_active():
		var selected: CardData = _piece_context.get("card")
		if is_instance_valid(selected) and selected.card_id == "P04":
			lines = _wire_placement_guidance(_piece_context.get("anchor"))
	_siege_label.text = "\n".join(lines)


## Read-only advice from the same validators used by the actual attack.
func _siege_window_guidance() -> Array[String]:
	var lines: Array[String] = []
	if battle.core_siege_trial.columns.is_empty():
		return ["选中伏线查看布置与触发条件", "选中己方棋子查看攻城结果"]
	var points: int = battle.get_command_economy_snapshot("player").get("current_points", 0)
	lines.append("指令%d · 攻城需3（移动另计）" % points)
	if context.enemy.boss_shield <= 0: lines.append("Boss无盾：当前无需穿盾")
	var candidates: Array[CardData] = []
	for unit: CardData in context.player.field:
		if battle.core_siege_trial.columns.has(battle.get_unit_cell(unit).x): candidates.append(unit)
	candidates.sort_custom(func(a, b): return battle.get_unit_cell(a).y < battle.get_unit_cell(b).y)
	if candidates.is_empty(): lines.append("压制列暂无己方棋子，先同列推进")
	for unit in candidates.slice(0, 2):
		var preview: Dictionary = battle.core_siege_trial.preview_core(unit)
		var detail := "可攻城" if preview.get("ok", false) else ""
		if detail.is_empty():
			var reasons := _core_rejection_lines(unit, preview)
			detail = reasons[1] if reasons.size() > 1 else "暂不可攻城"
			match str(preview.get("reason", preview.get("reason_code", ""))):
				"not_breach_rank": detail = "先撤离并推进" if not battle.get_garrison_state_for_unit(unit).is_empty() else "未到敌方底排"
				"guard_intercepted": detail = "先清除守卫"
				"front_arc_blocked": detail = "先清除拦路敌军"
				"facing_away_from_core": detail = "先转向核心"
				"insufficient_command_points": detail = "指令不足"
				"garrison_entered_this_turn": detail = "刚驻军，下回合再攻"
		var label: String = unit.get_display_name()
		if label.length() > 7: label = label.left(6) + "…"
		lines.append("%s：%s" % [label, detail])

	return lines

func _wire_placement_guidance(anchor: Variant) -> Array[String]:
	var lines: Array[String] = ["伏线布置 · 先拦截，再同列攻城", "敌军从监视区外移入时触发"]
	if anchor is Dictionary and anchor.get("cell") is Vector2i:
		var cells: Array = battle.project_piece_cells(&"piece_pawn", anchor.cell, &"player", &"attack", 0)
		var names := PackedStringArray()
		for cell in cells: names.append("%d列%d排" % [cell.x + 1, cell.y + 1])
		lines.append("监视：" + ("无有效格，建议重新选位" if cells.is_empty() else "、".join(names)))
	else:
		lines.append("先选落点，再查看具体监视格")
	lines.append("成功拦截后，敌军目标列穿盾1次")
	lines.append("提前推进；留3指令；先清守卫")
	lines.append("窗口到下个己方回合结束")
	return lines

func _core_preview_lines(actor: CardData) -> Array[String]:
	var preview: Dictionary = battle.core_siege_trial.preview_core(actor)
	if not preview.get("ok", false):
		return _core_rejection_lines(actor, preview)
	var lines: Array[String] = ["攻城 · 指令%d · %s" % [preview.cost, "穿盾" if preview.suppressed else "正常破防"], "城防 %d → %d / 核心 %d → %d" % [preview.shield_before, preview.shield_after, preview.hp_before, preview.hp_after], "额外破盾%d · 护盾吸收%d" % [preview.breach, preview.absorbed], "护甲减免%d · 保护减免%d" % [preview.armor_prevented, preview.phase_prevented]]
	var aftermath := PackedStringArray()
	if preview.phase_lock > 0: aftermath.append("阶段%d保护" % preview.phase_lock)
	if preview.od_after != preview.od_before: aftermath.append("Boss OD %d→%d" % [preview.od_before, preview.od_after])
	if not aftermath.is_empty(): lines.append(" · ".join(aftermath))
	return lines

## Explain existing authority without inventing reach or bypassing blockers.
func _core_rejection_lines(actor: CardData, preview: Dictionary) -> Array[String]:
	var reason := str(preview.get("reason", preview.get("reason_code", "")))
	var lines: Array[String] = ["攻城暂不可用"]
	match reason:
		"not_breach_rank":
			lines.append("先推进到最靠近 Boss 的一排")
			if not battle.get_garrison_state_for_unit(actor).is_empty():
				lines.append("当前驻军：选择「撤离」后再推进")
			else:
				lines.append("到达后仍需朝向核心并清除拦截")
		"facing_away_from_core": lines.append("朝向背离 Boss：先转向，再检查攻城")
		"guard_intercepted": lines.append("守卫正在拦截：先清除守卫")
		"front_arc_blocked": lines.append("攻击范围内有敌军：先清除拦路敌军")
		"insufficient_command_points":
			lines.append("需要指令%d，当前%d" % [int(preview.get("cost", 0)), int(preview.get("current_points", 0))])
			lines.append("保留攻城指令，或下回合再行动")
		"garrison_entered_this_turn": lines.append("本回合刚驻军：下回合才能攻击")
		_:
			lines.append(reason if not reason.is_empty() and not reason.contains("_") else _map_attack_reason_text(StringName(reason), preview))
	return lines

func _unit_preview_lines(actor: CardData, target: CardData) -> Array[String]:
	var preview: Dictionary = battle.core_siege_trial.preview_unit(actor, target)
	if not preview.get("ok", false): return [str(preview.get("reason", _map_attack_reason_text(StringName(preview.get("reason_code", "")), preview)))]
	return ["交战 · 指令%d · 双方同时受伤" % preview.cost, "%s %d → %d" % [actor.get_display_name(), preview.actor_hp_before, preview.actor_hp_after], "%s %d → %d" % [target.get_display_name(), preview.target_hp_before, preview.target_hp_after]]

func _draw_frontline() -> void:
	super._draw_frontline()
	if battle == null or battle.core_siege_trial == null: return
	for column in battle.core_siege_trial.columns:
		for row in range(5):
			var point := _project_tactical_cell_to_screen(Vector2i(column, row))
			if point.is_finite(): _frontline_overlay.draw_line(point - Vector2(0, 13), point + Vector2(0, 13), Color(1, 0.5, 0.1, 0.85), 3)

func restart_gb1_battle() -> void:
	if _gb1_restarting: return
	_gb1_restarting = true
	if battle != null and battle.reaction_trial != null: battle.reaction_trial.finish_event()
	var err := get_tree().change_scene_to_file(CORE_SIEGE_ENTRY)
	if err != OK:
		_gb1_restarting = false
		push_error("Core siege restart failed: %d" % err)
