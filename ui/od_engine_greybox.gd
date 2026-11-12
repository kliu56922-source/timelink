extends PanelContainer
class_name ODEngineGreybox
## Phase 27K-R0: OD ENGINE 中世纪魔导灰盒控件。
## 纯表现层：读取权威状态快照，展示 Heat/Charge/Layer/Zone/Release 五类信息。
## 绝不写入战斗数据，不参与任何合法性/费用判定。
## 保留 CoreStatusPanel 作为单一 HUD 锚点：本控件作为其子节点叠加渲染，
## 不新建第二个 Depth HUD，不改变 ODReleaseControl 的点击与执行调用链。

const PresentationSnapshotClass := preload("res://core/config/od_presentation_snapshot.gd")

## 表现配置快照（null 时内部降级为 default_snapshot，战斗不受影响）。
var _config: RefCounted = null

## UI 节点
var _title_label: Label = null
var _heat_segments: Array[ColorRect] = []
var _heat_label: Label = null
var _zone_emblem: Label = null
var _zone_label: Label = null
var _charge_label: Label = null
var _layer_labels: Array[Label] = []
var _release_label: Label = null
var _depth_label: Label = null

var _built := false
var _current_layer: int = 1
var _filled_segments: int = 0
var _pulse_tween: Tween = null
var _feedback_pulse_tween: Tween = null
var _feedback_pulse_node: Control = null


func _exit_tree() -> void:
	cancel_feedback_pulse()
	_safe_kill_pulse()


## 注入表现配置。传入 null 表示缺失配置 → 使用内置安全默认值，不阻断战斗。
func configure(snapshot: RefCounted) -> void:
	_config = snapshot if snapshot != null else PresentationSnapshotClass.default_snapshot([])
	if _built:
		_apply_config_to_existing()


func refresh(state: Dictionary) -> void:
	if not _built:
		_ensure_nodes()
	var heat: int = clampi(int(state.get("heat", 0)), 0, get_heat_max_segments())
	var heat_max: int = int(state.get("heat_max", get_heat_max_segments()))
	var zone_id: String = str(state.get("zone", "Calm"))
	var charge: int = int(state.get("charge", 0))
	var capacity: int = int(state.get("capacity", 0))
	var layer: int = clampi(int(state.get("layer", 1)), 1, get_layer_count())
	var depth: int = int(state.get("depth", 0))
	var depth_max: int = int(state.get("depth_max", 6))
	var depth_zone: String = str(state.get("depth_zone", "Stable"))

	_filled_segments = heat
	_current_layer = layer

	# ── Heat：10 段可数刻度 + 文字 ──
	var zone_palette: Dictionary = _config.get_zone_palette(zone_id)
	for i in range(_heat_segments.size()):
		var seg: ColorRect = _heat_segments[i]
		if not is_instance_valid(seg):
			continue
		if i < heat:
			seg.color = zone_palette["color"]
			seg.modulate = Color(1, 1, 1, 1)
		else:
			seg.color = Color(0.07, 0.09, 0.13, 0.85)
			seg.modulate = Color(1, 1, 1, 0.55)
	if _heat_label != null:
		_heat_label.text = "热量 %d/%d" % [heat, heat_max]

	# ── Zone：颜色 + 纹章 + 文字 三重标识 ──
	if _zone_emblem != null:
		_zone_emblem.text = str(zone_palette.get("token_text", "○"))
		_zone_emblem.add_theme_color_override("font_color", zone_palette["color"])
	if _zone_label != null:
		_zone_label.text = "%s · %s" % [str(zone_palette.get("label_zh", zone_id)), str(zone_palette.get("label_en", zone_id))]
		_zone_label.add_theme_color_override("font_color", zone_palette["color"])

	# ── Charge：与 Heat 明确分离 ──
	if _charge_label != null:
		var fmt: String = str(_config.get_charge_format())
		fmt = fmt.replace("{value}", str(charge)).replace("{capacity}", str(capacity))
		_charge_label.text = "%s %s" % [str(_config.get_charge_label_zh()), fmt]

	# ── Layer：固定 I–V，当前层点亮 ──
	_safe_kill_pulse()
	for i in range(_layer_labels.size()):
		var lbl: Label = _layer_labels[i]
		if not is_instance_valid(lbl):
			continue
		var layer_idx := i + 1
		if layer_idx == layer:
			lbl.add_theme_color_override("font_color", Color(0.95, 0.82, 0.55, 1))
			lbl.add_theme_font_size_override("font_size", 12)
		elif layer_idx < layer:
			lbl.add_theme_color_override("font_color", Color(0.18, 0.35, 0.25, 0.7))
			lbl.add_theme_font_size_override("font_size", 10)
		else:
			lbl.add_theme_color_override("font_color", Color(0.22, 0.22, 0.28, 0.55))
			lbl.add_theme_font_size_override("font_size", 10)
	if layer >= 1 and layer <= _layer_labels.size():
		var active: Label = _layer_labels[layer - 1]
		if is_instance_valid(active) and not _config.is_reduced_motion():
			_pulse_tween = create_tween()
			_pulse_tween.set_loops()
			_pulse_tween.tween_property(active, "modulate:a", 0.55, 0.7).set_trans(Tween.TRANS_SINE)
			_pulse_tween.tween_property(active, "modulate:a", 1.0, 0.7).set_trans(Tween.TRANS_SINE)

	# ── Release：权威状态文字（可释放 / 原因 / 选择中 / 处理中） ──
	if _release_label != null:
		_release_label.text = get_release_status_text(state)
		if state.get("release_ok", false) == true:
			_release_label.add_theme_color_override("font_color", Color(0.45, 0.9, 1.0, 1))
		else:
			_release_label.add_theme_color_override("font_color", Color(0.85, 0.7, 0.5, 1))

	# ── Depth：保留权威显示，不制造第二个 Depth HUD ──
	if _depth_label != null:
		var dp := _depth_color(depth_zone)
		_depth_label.text = "Depth %d/%d %s" % [depth, depth_max, depth_zone]
		_depth_label.add_theme_color_override("font_color", dp)


## 权威释放状态 → 可读文字。state 支持：
##   release_ok / reason_code / readiness_threshold / selection_active / selection_stage
func get_release_status_text(state: Dictionary) -> String:
	if bool(state.get("selection_active", false)):
		var stage := StringName(str(state.get("selection_stage", "")))
		if stage == &"source":
			return str(_config.get_release_label(&"source_selection"))
		if stage == &"target":
			return str(_config.get_release_label(&"target_selection"))
	var code := StringName(str(state.get("reason_code", "")))
	var ok := bool(state.get("release_ok", state.get("ok", false)))
	if ok or code == &"ok":
		return str(_config.get_release_label(&"ready"))
	if code == &"release_busy":
		return str(_config.get_release_label(&"release_busy"))
	var raw: String = str(_config.get_release_label(code if code != &"" else &"unknown"))
	if raw.contains("{threshold}"):
		raw = raw.replace("{threshold}", str(int(state.get("readiness_threshold", 8))))
	return raw


func get_filled_segment_count() -> int:
	return _filled_segments


func get_current_layer() -> int:
	return _current_layer


func get_active_tween_count() -> int:
	var count := 0
	for tween in [_pulse_tween, _feedback_pulse_tween]:
		if tween != null and tween.is_valid():
			count += 1
	return count


## 战斗结束时停止常驻 Tween（被 queue_free 后不再访问节点）。
func stop_idle_animations() -> void:
	_safe_kill_pulse()
	cancel_feedback_pulse()


## Phase 27K-R1-B: show committed before/after OD facts without querying rules.
func play_feedback_pulse(facts: Dictionary, cue_phase: StringName, duration_scale: float = 1.0) -> void:
	cancel_feedback_pulse()
	var panel := PanelContainer.new()
	panel.name = "PresentationFeedbackPulse"
	panel.z_index = 180
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_left = 5
	panel.offset_right = -5
	panel.offset_top = -31
	panel.offset_bottom = -5
	panel.set_meta("cue_phase", cue_phase)
	for key in facts.keys():
		panel.set_meta(str(key), facts[key])
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.055, 0.11, 0.97)
	style.border_color = Color(0.25, 0.85, 1.0, 0.95)
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	panel.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	var heat_before := int(facts.get("heat_before", facts.get("before", 0)))
	var heat_after := int(facts.get("heat_after", facts.get("after", heat_before)))
	label.text = "热量 %d → %d" % [heat_before, heat_after]
	if facts.has("layer_before") and facts.has("layer_after") and int(facts.get("layer_before", 0)) != int(facts.get("layer_after", 0)):
		label.text += "   L%d → L%d" % [int(facts.get("layer_before", 0)), int(facts.get("layer_after", 0))]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color(0.78, 0.94, 1.0, 1.0))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(label)
	add_child(panel)
	_feedback_pulse_node = panel
	var duration := maxf(0.08, 0.7 * clampf(duration_scale, 0.2, 2.0))
	_feedback_pulse_tween = create_tween()
	_feedback_pulse_tween.tween_property(panel, "modulate", Color(1.35, 1.35, 1.35, 1.0), duration * 0.2)
	_feedback_pulse_tween.tween_property(panel, "modulate", Color(1.0, 1.0, 1.0, 1.0), duration * 0.25)
	_feedback_pulse_tween.tween_interval(duration * 0.25)
	_feedback_pulse_tween.tween_property(panel, "modulate:a", 0.0, duration * 0.3)
	_feedback_pulse_tween.tween_callback(cancel_feedback_pulse)


func cancel_feedback_pulse() -> void:
	if _feedback_pulse_tween != null and _feedback_pulse_tween.is_valid():
		_feedback_pulse_tween.kill()
	_feedback_pulse_tween = null
	if _feedback_pulse_node != null and is_instance_valid(_feedback_pulse_node):
		if _feedback_pulse_node.get_parent() == self:
			remove_child(_feedback_pulse_node)
		_feedback_pulse_node.queue_free()
	_feedback_pulse_node = null


func get_heat_max_segments() -> int:
	return int(_config.get_heat_max_segments()) if _config != null else 10


func get_layer_count() -> int:
	return int(_config.get_layer_count()) if _config != null else 5


func _depth_color(depth_zone: String) -> Color:
	match depth_zone:
		"Warning":
			return Color(0.95, 0.4, 0.05, 1)
		"Backlash":
			return Color(0.95, 0.05, 0.2, 1)
		_:
			return Color(0.3, 0.6, 1, 1)


# ── 构建（幂等：重复 refresh 不重复创建子节点） ──

func _ensure_nodes() -> void:
	if _built:
		return
	if _config == null:
		_config = PresentationSnapshotClass.default_snapshot([])

	# 深铁色哥特灰盒底（中世纪魔导方向：暗铁底 + 旧金描边）
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.018, 0.024, 0.05, 0.99)
	style.border_color = Color(0.36, 0.3, 0.18, 1)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	add_theme_stylebox_override("panel", style)

	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var root := MarginContainer.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("margin_left", 6)
	root.add_theme_constant_override("margin_right", 6)
	root.add_theme_constant_override("margin_top", 2)
	root.add_theme_constant_override("margin_bottom", 2)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var layout := VBoxContainer.new()
	layout.name = "Layout"
	layout.add_theme_constant_override("separation", 3)
	layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(layout)

	# 标题
	_title_label = Label.new()
	_title_label.name = "TitleLabel"
	_title_label.text = "OD ENGINE"
	_title_label.add_theme_font_size_override("font_size", 12)
	_title_label.add_theme_color_override("font_color", Color(0.72, 0.9, 1.0, 1))
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_child(_title_label)

	# Heat 行：10 段刻度 + 文字
	var heat_row := HBoxContainer.new()
	heat_row.name = "HeatRow"
	heat_row.add_theme_constant_override("separation", 4)
	heat_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_child(heat_row)

	var seg_box := HBoxContainer.new()
	seg_box.name = "HeatSegments"
	seg_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	seg_box.add_theme_constant_override("separation", 2)
	seg_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	heat_row.add_child(seg_box)

	var heat_max := int(_config.get_heat_max_segments())
	for i in range(heat_max):
		var seg := ColorRect.new()
		seg.name = "Seg%d" % i
		seg.color = Color(0.07, 0.09, 0.13, 0.85)
		seg.custom_minimum_size = Vector2(0, 12)
		seg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		seg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		seg_box.add_child(seg)
		_heat_segments.append(seg)

	_heat_label = Label.new()
	_heat_label.name = "HeatLabel"
	_heat_label.text = "热量 0/%d" % heat_max
	_heat_label.add_theme_font_size_override("font_size", 10)
	_heat_label.add_theme_color_override("font_color", Color(0.75, 0.85, 0.95, 1))
	_heat_label.custom_minimum_size = Vector2(64, 0)
	_heat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_heat_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	heat_row.add_child(_heat_label)

	# Zone 行：纹章 + 文字（不依赖颜色）
	var zone_row := HBoxContainer.new()
	zone_row.name = "ZoneRow"
	zone_row.add_theme_constant_override("separation", 4)
	zone_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_child(zone_row)

	_zone_emblem = Label.new()
	_zone_emblem.name = "ZoneEmblem"
	_zone_emblem.text = "○"
	_zone_emblem.add_theme_font_size_override("font_size", 12)
	_zone_emblem.custom_minimum_size = Vector2(18, 0)
	_zone_emblem.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_zone_emblem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	zone_row.add_child(_zone_emblem)

	_zone_label = Label.new()
	_zone_label.name = "ZoneLabel"
	_zone_label.text = "平稳 · Calm"
	_zone_label.add_theme_font_size_override("font_size", 10)
	_zone_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_zone_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	zone_row.add_child(_zone_label)

	var sep := HSeparator.new()
	sep.name = "HeatChargeSep"
	sep.modulate = Color(1, 1, 1, 0.25)
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_child(sep)

	# Charge：当前值 / 当前层容量
	_charge_label = Label.new()
	_charge_label.name = "ChargeLabel"
	_charge_label.text = "充能 0/0"
	_charge_label.add_theme_font_size_override("font_size", 10)
	_charge_label.add_theme_color_override("font_color", Color(0.55, 0.85, 0.6, 1))
	_charge_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_child(_charge_label)

	# Layer：I–V
	var layer_row := HBoxContainer.new()
	layer_row.name = "LayerRow"
	layer_row.add_theme_constant_override("separation", 4)
	layer_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_child(layer_row)

	var layer_tokens: Array = _config.get_layer_tokens()
	for i in range(int(_config.get_layer_count())):
		var lbl := Label.new()
		lbl.name = "Layer%s" % _roman_index(i + 1)
		lbl.text = str(layer_tokens[i]) if i < layer_tokens.size() else str(i + 1)
		lbl.add_theme_font_size_override("font_size", 10)
		lbl.add_theme_color_override("font_color", Color(0.22, 0.22, 0.28, 0.55))
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer_row.add_child(lbl)
		_layer_labels.append(lbl)

	# Release：状态行
	_release_label = Label.new()
	_release_label.name = "ReleaseLabel"
	_release_label.text = "状态未知"
	_release_label.add_theme_font_size_override("font_size", 10)
	_release_label.add_theme_color_override("font_color", Color(0.85, 0.7, 0.5, 1))
	_release_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_child(_release_label)

	# Depth：单一权威显示
	_depth_label = Label.new()
	_depth_label.name = "DepthLabel"
	_depth_label.text = "Depth 0/6 Stable"
	_depth_label.add_theme_font_size_override("font_size", 9)
	_depth_label.add_theme_color_override("font_color", Color(0.3, 0.6, 1, 1))
	_depth_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_child(_depth_label)

	_built = true


func _apply_config_to_existing() -> void:
	if _heat_label != null:
		_heat_label.text = "热量 0/%d" % int(_config.get_heat_max_segments())


func _roman_index(n: int) -> String:
	return ["I", "II", "III", "IV", "V"][n - 1] if n >= 1 and n <= 5 else str(n)


func _safe_kill_pulse() -> void:
	if _pulse_tween and _pulse_tween.is_valid():
		_pulse_tween.kill()
	_pulse_tween = null
