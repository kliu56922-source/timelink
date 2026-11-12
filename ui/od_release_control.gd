extends PanelContainer
## Compact Phase 27J OD ENGINE release entry. BattleSystem remains authoritative.

signal release_requested
signal final_requested
signal ritual_requested(path: String, overcharge: bool)
signal cancel_requested

var _button: Button
var _final_button: Button
var _status_label: Label
var _snapshot: Dictionary = {}
var _ritual_menu: PopupMenu
var _ritual_choices: Array[Dictionary] = []
var _mission_box: VBoxContainer
var _mission_label: Label
var _progress_seen := false
var _progress_tween: Tween
var _reward_dialog: AcceptDialog


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.035, 0.065, 0.96)
	style.border_color = Color(0.18, 0.72, 0.82, 0.9)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.name = "ReleaseRow"
	row.add_theme_constant_override("separation", 6)
	add_child(row)
	_status_label = Label.new()
	_status_label.name = "StatusLabel"
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_label.add_theme_font_size_override("font_size", 10)
	_status_label.add_theme_color_override("font_color", Color(0.72, 0.9, 1.0))
	row.add_child(_status_label)
	_button = Button.new()
	_button.name = "ReleaseButton"
	_button.text = "释放"
	_button.custom_minimum_size = Vector2(58, 24)
	_button.add_theme_font_size_override("font_size", 11)
	_button.pressed.connect(_on_pressed)
	row.add_child(_button)
	_final_button = Button.new()
	_final_button.name = "FinalButton"
	_final_button.text = "终局汇流"
	_final_button.tooltip_text = "以已完成的战术 Chain 汇聚引擎与棋型力量"
	_final_button.custom_minimum_size = Vector2(76, 24)
	_final_button.add_theme_font_size_override("font_size", 10)
	_final_button.pressed.connect(_on_final_pressed)
	row.add_child(_final_button)
	_ritual_menu = PopupMenu.new()
	_ritual_menu.name = "RitualModeMenu"
	_ritual_menu.id_pressed.connect(_on_ritual_mode_pressed)
	add_child(_ritual_menu)
	_mission_box = VBoxContainer.new()
	_mission_box.name = "RitualPreparation"
	_mission_box.position = Vector2(114, -161)
	_mission_box.size = Vector2(150, 150)
	_mission_box.add_theme_constant_override("separation", 3)
	var mission_host := Control.new()
	mission_host.name = "PreparationHost"
	mission_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(mission_host)
	mission_host.add_child(_mission_box)
	_mission_label = Label.new()
	_mission_label.name = "PreparationLabel"
	_mission_label.add_theme_font_size_override("font_size", 11)
	_mission_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mission_box.add_child(_mission_label)
	var rewards := Button.new()
	rewards.name = "ViewRewards"
	rewards.text = "查看奖励与规则"
	rewards.add_theme_font_size_override("font_size", 11)
	rewards.pressed.connect(_show_rewards)
	_mission_box.add_child(rewards)
	_reward_dialog = AcceptDialog.new()
	_reward_dialog.name = "RitualRewards"
	_reward_dialog.title = "炉心仪式 · 两条准备路径"
	_reward_dialog.ok_button_text = "返回对局"
	add_child(_reward_dialog)
	refresh({})

func refresh(snapshot: Dictionary) -> void:
	var old_counts: Array = [_snapshot.get("attack_count", 0), _snapshot.get("garrison_count", 0), _snapshot.get("control_count", 0)]
	var new_counts: Array = [snapshot.get("attack_count", 0), snapshot.get("garrison_count", 0), snapshot.get("control_count", 0)]
	var ready_before := bool(_snapshot.get("final_ready", false)) and (bool(_snapshot.get("attack_ready", false)) or bool(_snapshot.get("guard_ready", false)))
	var ready_now := bool(snapshot.get("final_ready", false)) and (bool(snapshot.get("attack_ready", false)) or bool(snapshot.get("guard_ready", false)))
	var changed := _progress_seen and (old_counts != new_counts or (ready_now and not ready_before)) and bool(snapshot.get("ritual_trial", false))
	_snapshot = snapshot.duplicate(true)
	_progress_seen = bool(snapshot.get("ritual_trial", false))
	if _button == null or _final_button == null or _status_label == null:
		return
	_refresh_preparation(snapshot)
	if changed:
		if _progress_tween != null and _progress_tween.is_valid(): _progress_tween.kill()
		_mission_label.modulate = Color(1.0, 0.78, 0.25)
		_progress_tween = create_tween()
		_progress_tween.tween_property(_mission_label, "modulate", Color.WHITE, 0.5)
	var heat := int(snapshot.get("heat", snapshot.get("current_heat", 0)))
	var threshold := int(snapshot.get("readiness_threshold", 8))
	var ready := bool(snapshot.get("ok", false))
	var stage := StringName(snapshot.get("selection_stage", &""))
	if stage != &"":
		_status_label.text = "OD ENGINE  %s" % ("选择棋子" if stage == &"source" else "选择目标")
		_button.text = "取消"
		_button.disabled = false
		_final_button.visible = false
		return
	_status_label.text = "OD %d/%d" % [heat, threshold] if bool(snapshot.get("ritual_trial", false)) else "热量 %d/%d" % [heat, threshold]
	_button.text = "普通OD" if bool(snapshot.get("ritual_trial", false)) else "释放"
	_button.tooltip_text = "普通棋子战术释放，不要求仪式准备完成。选择棋子后查看实际指令与热量费用。成功释放消耗热量，准备记录保留；领取准备奖励时仍需蓄至%d热。" % threshold
	# PHASE62_BEGIN_RITUAL_TOOLTIP
	_button.tooltip_text=_button.tooltip_text.replace("蓄至%d热" % threshold,"蓄至%d热" % _ritual_threshold(snapshot))
	# PHASE62_END_RITUAL_TOOLTIP
	_button.disabled = not ready
	_final_button.visible = bool(snapshot.get("ritual_trial", false)) or bool(snapshot.get("final_ready", false))
	_final_button.disabled = not bool(snapshot.get("final_ready", false))
	var prepared := bool(snapshot.get("attack_ready", false)) or bool(snapshot.get("guard_ready", false))
	_final_button.text = ("已领取" if bool(snapshot.get("used", false)) else "领取奖励" if prepared else "应急汇流") if bool(snapshot.get("ritual_trial", false)) else "终局汇流"
	_final_button.tooltip_text = ("本局仪式已领取；继续普通OD与出牌攻城。" if bool(snapshot.get("used", false)) else "准备完成，可选择准备奖励或较弱的应急模式；每局只领取一次。" if prepared else "准备未完成：应急模式收益较弱，也会消耗本局的一次仪式；普通OD可另行选择，准备记录保留。") if bool(snapshot.get("ritual_trial", false)) else "以已完成的战术 Chain 汇聚引擎与棋型力量"

func set_busy(busy: bool, text: String = "") -> void:
	if _button != null:
		_button.disabled = busy or not bool(_snapshot.get("ok", false))
	if _final_button != null:
		_final_button.disabled = busy or not bool(_snapshot.get("final_ready", false))
	if busy and _status_label != null:
		_status_label.text = text if not text.is_empty() else "OD 结算中"

func _on_pressed() -> void:
	if StringName(_snapshot.get("selection_stage", &"")) != &"":
		cancel_requested.emit()
	else:
		release_requested.emit()

func _on_final_pressed() -> void:
	if not bool(_snapshot.get("ritual_trial", false)):
		final_requested.emit()
		return
	_ritual_choices.clear()
	_ritual_menu.clear()
	var effects: Dictionary = _snapshot.get("path_effects", {})
	var previews: Dictionary = _snapshot.get("path_previews", {})
	for path in _snapshot.get("available_paths", []):
		var effect: Dictionary = effects.get(path, {})
		var path_preview: Dictionary = previews.get(path, {})
		_add_ritual_choice(str(path), false, effect, path_preview.get("normal", {}))
		if bool(_snapshot.get("overcharge_available", false)):
			_add_ritual_choice(str(path), true, effect, path_preview.get("overcharge", {}))
	if _ritual_choices.is_empty():
		return
	var menu_width := 690
	var view_width := get_viewport_rect().size.x
	var left := clampi(roundi(_final_button.global_position.x), 0, maxi(0, roundi(view_width) - menu_width))
	var top := maxi(0, roundi(_final_button.global_position.y - mini(220, _ritual_choices.size() * 28)))
	_ritual_menu.popup(Rect2i(Vector2i(left, top), Vector2i(menu_width, 0)))

func _add_ritual_choice(path: String, overcharge: bool, effect: Dictionary, preview: Dictionary) -> void:
	var title := "应急释放（较弱收益）" if path == "early" else "锋线点火" if path == "attack" else "阵地导流"
	var damage := int(effect.get("damage", 4)) + (2 if overcharge else 0)
	var label := "%s · OD -5 · %d 伤" % [title, damage]
	if preview.has("actual_hp_loss"):
		label += " · 预计 HP -%d" % int(preview.actual_hp_loss)
	if bool(preview.get("bypass_boss_shield", false)):
		label += " · 准备穿盾"
	label += " · 清盾 %d · 尝试抽 %d" % [int(preview.get("boss_shield_removed_total", 0)), int(preview.get("draw_requested", effect.get("draw", 0)))]
	if int(effect.get("unit_damage", 0)) > 0:
		label += " · 敌棋 %d 名各受 %d 伤" % [int(preview.get("enemy_unit_count", 0)), int(effect.unit_damage)]
	if int(preview.get("phase_lock", 0)) > 0:
		label += " · 阶段锁 %d" % int(preview.phase_lock)
	if int(effect.get("shield", 0)) > 0:
		label += " · 护盾 +%d" % int(effect.shield)
	if int(effect.get("boss_od_reduce", 0)) > 0:
		label += " · Boss OD -%d" % int(effect.boss_od_reduce)
	if overcharge:
		label += " · Depth +2"
		if bool(preview.get("backlash", false)):
			label += "（反噬）"
	var index := _ritual_choices.size()
	_ritual_choices.append({"path": path, "overcharge": overcharge})
	_ritual_menu.add_item(label, index)

func _on_ritual_mode_pressed(id: int) -> void:
	if id < 0 or id >= _ritual_choices.size():
		return
	var choice: Dictionary = _ritual_choices[id]
	_ritual_menu.hide()
	ritual_requested.emit(str(choice.path), bool(choice.overcharge))

func _refresh_preparation(snapshot: Dictionary) -> void:
	_mission_box.visible = bool(snapshot.get("ritual_trial", false))
	if not _mission_box.visible:
		return
	_mission_label.tooltip_text = ""
	var heat := int(snapshot.get("heat", 0))
	var threshold := int(snapshot.get("readiness_threshold", 8))
	# PHASE62_BEGIN_RITUAL_PREPARATION
	threshold=_ritual_threshold(snapshot)
	# PHASE62_END_RITUAL_PREPARATION
	var prepared := bool(snapshot.get("attack_ready", false)) or bool(snapshot.get("guard_ready", false))
	var next_step := "再用另一名棋子攻击" if int(snapshot.get("attack_count", 0)) == 1 else "两名不同棋子成功攻击"
	if int(snapshot.get("garrison_count", 0)) > 0 and int(snapshot.get("control_count", 0)) == 0:
		next_step = "成功打出一张控制卡"
	elif int(snapshot.get("control_count", 0)) > 0 and int(snapshot.get("garrison_count", 0)) == 0:
		next_step = "让一名棋子成功驻军"
	if prepared:
		next_step = "准备完成，还差%d热量" % maxi(0, threshold - heat) if heat < threshold else "准备完成 · 可领取仪式"
	if bool(snapshot.get("used", false)):
		next_step = "已领取 · 继续出牌攻城"
	elif prepared and heat >= threshold and not bool(snapshot.get("final_ready", false)):
		next_step = "准备完成 · 等己方可行动"
	_mission_label.text = "炉心仪式 · %s\n锋线点火 · 攻击 %d/2\n阵地：驻军 %d/1 · 控制 %d/1\n热量 %d/%d · Depth %d/%d\n%s\n%s" % [
		"已领取" if bool(snapshot.get("used", false)) else "未领取", mini(2, int(snapshot.get("attack_count", 0))),
		mini(1, int(snapshot.get("garrison_count", 0))), mini(1, int(snapshot.get("control_count", 0))), heat, threshold,
		int(snapshot.get("depth", 0)), int(snapshot.get("depth_max", 6)), next_step, _ordinary_readiness_text(snapshot)]
	_mission_label.tooltip_text = "攻击来源：%s\n驻军来源：%s\n控制来源：%s\n" % ["、".join(snapshot.get("attack_sources", [])), "、".join(snapshot.get("guard_sources", [])), "、".join(snapshot.get("control_sources", []))]
	_mission_label.tooltip_text += "完成任一路径＋热量8，可领取一次仪式。\n仅成功行动计数；重复攻击同一棋子不增加人数。\n准备记录保留，阵亡或撤离不会清空。\n当前存活攻击者：%d；当前驻军：%d。" % [
		(snapshot.get("living_attack_participants", []) as Array).size(), (snapshot.get("living_guard_participants", []) as Array).size()]
	_mission_label.tooltip_text += "\n普通OD不要求仪式准备完成；实际消耗热量但不清空准备记录，奖励热量不足时需继续蓄势。"

func _ordinary_readiness_text(snapshot: Dictionary) -> String:
	if StringName(snapshot.get("selection_stage", &"")) != &"": return "普通OD选择中 · 可取消"
	if bool(snapshot.get("ok", false)): return "普通OD可用 · 准备保留"
	match StringName(snapshot.get("reason_code", &"")):
		&"insufficient_heat": return "普通OD差%d热" % maxi(0, int(snapshot.get("readiness_threshold", 8)) - int(snapshot.get("heat", 0)))
		&"no_legal_source": return "普通OD缺合法行动"
		&"not_player_turn": return "普通OD等己方回合"
		&"release_busy": return "普通OD结算中"
	return "普通OD暂不可用"

func _exit_tree() -> void:
	if _progress_tween != null and _progress_tween.is_valid(): _progress_tween.kill()

func _show_rewards() -> void:
	var effects: Dictionary = _snapshot.get("path_effects", {})
	var lines: Array[String] = ["完成任一路径＋热量8 → 选择一种模式；每局只领取一次。", "成功记录保留；阵亡、撤离不撤销准备。\n"]
	for path in ["attack", "guard", "early"]:
		var effect: Dictionary = effects.get(path, {})
		var title := "锋线点火：两名不同棋子成功攻击" if path == "attack" else "阵地导流：成功驻军＋成功打出控制卡" if path == "guard" else "应急释放：未完成准备的较弱收益"
		lines.append(title)
		var names: Array = _snapshot.get("attack_sources" if path == "attack" else "guard_sources", [])
		if path != "early" and not names.is_empty(): lines.append("已完成来源：" + "、".join(names))
		if path == "guard" and not (_snapshot.get("control_sources", []) as Array).is_empty(): lines.append("已结算控制卡：" + "、".join(_snapshot.get("control_sources", [])))
		lines.append("消耗5热量 · Boss基础伤害%d · 尝试抽%d张" % [int(effect.get("damage", 0)), int(effect.get("draw", 0))])
		if bool(effect.get("bypass_boss_shield", false)):
			lines.append("准备完成：伤害穿过Boss护盾；炉甲与阶段保护仍生效。")
		if int(effect.get("unit_damage", 0)) > 0:
			lines.append("敌方棋子各受%d伤害" % int(effect.unit_damage))
		if int(effect.get("shield", 0)) > 0:
			lines.append("己方护盾 +%d · Boss OD -%d" % [int(effect.shield), int(effect.get("boss_od_reduce", 0))])
		lines.append("")
	var last: Dictionary = _snapshot.get("last_receipt", {})
	if not last.is_empty():
		lines.append("本局已领取：破盾%d、Boss HP -%d、实际抽牌%d/%d、护盾+%d。" % [int(last.get("ritual_boss_shield_removed_total",0)), int(last.get("final_actual_hp_loss",0)), int(last.get("ritual_cards_drawn",0)), int(last.get("ritual_draw_requested",0)), int(last.get("ritual_shield_gained",0))])
		if last.has("ritual_shield_bypassed"):
			lines.append("本次准备穿盾：护盾吸收0伤。" if bool(last.ritual_shield_bypassed) else "本次护盾吸收%d伤。" % int(last.get("ritual_shield_absorbed",0)))
	var protection := "应急模式受护盾吸收；准备模式穿盾。炉甲与阶段保护仍影响实际伤害。" if bool((effects.get("attack",{}) as Dictionary).get("bypass_boss_shield",false)) else "护盾、护甲、阶段保护影响实际伤害。"
	lines.append(protection + "手牌上限影响实际抽牌。\n释放时可查看实时结算预览。透支：Depth +2、基础伤害+2；超出上限不可选。\n普通OD不要求完成准备；成功释放消耗热量但准备记录保留，领取奖励仍需蓄至%d热。准备完成不解除Depth限制。" % int(_snapshot.get("readiness_threshold", 8)))
	# PHASE62_BEGIN_RITUAL_REWARD_TEXT
	if not lines.is_empty():lines[-1]=str(lines[-1]).replace("蓄至%d热" % int(_snapshot.get("readiness_threshold",8)),"蓄至%d热" % _ritual_threshold(_snapshot))
	# PHASE62_END_RITUAL_REWARD_TEXT
	_reward_dialog.dialog_text = "\n".join(lines)
	_reward_dialog.popup_centered(Vector2i(600, 430))
# PHASE62_BEGIN_RITUAL_UI_HELPER
func _ritual_threshold(snapshot: Dictionary) -> int:
	return int(snapshot.get("ritual_readiness_threshold",snapshot.get("readiness_threshold",8)))
# PHASE62_END_RITUAL_UI_HELPER
