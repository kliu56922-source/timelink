extends RefCounted
## Phase 27A-R1: 战术网格表现配置的不可变快照
## 构造后字段只读。非法/缺失表回退到安全默认值并记录错误。
## NOTE: 不使用 class_name 以避免脚本内部自引用编译错误。

var _grid_line_color := Color("#39D9FF")
var _grid_line_alpha := 0.26
var _surface_offset := 0.018
var _cell_inset_ratio := 0.76
var _summon_marker_color := Color("#42E9F5")
var _summon_radius_ratio := 0.21
var _summon_fill_alpha := 0.30
var _summon_ring_alpha := 0.86
var _hover_scale := 1.12
var _confirm_flash_seconds := 0.08
var _overlay_fade_seconds := 0.18
var _reject_pulse_seconds := 0.14
# Phase 27B-R1: camera framing
var _board_width_ratio := 0.82
var _board_height_ratio := 0.56
var _fit_padding := 1.10
var _safe_top_ratio := 0.12
var _safe_bottom_ratio := 0.23
# Phase 27B-R1: token footprint
var _normal_cell_ratio := 0.55
var _ascended_cell_ratio := 0.62
var _art_fill_ratio := 0.75
# Phase B: elevated terrain view profile. These values are presentation-only.
var _terrain_level_step_ratio := 0.22
var _terrain_footprint_ratio := 0.78
var _terrain_cap_thickness_ratio := 0.035
var _terrain_body_color := Color("#263746")
var _terrain_cap_color := Color("#405867")
var _terrain_edge_color := Color("#9DEBFF")
var _terrain_height_band_color := Color("#6FCDE2")
var _terrain_feedback := {&"legal": Color("#42E9F5"), &"pending": Color("#F4C95D"), &"invalid": Color("#B84A52"), &"label": Color("#E9F8FF")}
var _terrain_raise_seconds := 0.28
var _terrain_lower_seconds := 0.24
var _terrain_feedback_seconds := 0.12
var _elevated_base_pitch := 60.0
var _top_pitch := 82.0
var _terrain_focus_pitch := 68.0
var _height_fit_padding := 1.20
var _cutaway_alpha_scissor_threshold := 0.50
var _cutaway_checker_size := 4
var _surface_glyphs := {&"flat": &"single_border", &"foundation": &"corner_brackets", &"high_platform": &"double_border", &"stable": &"corner_clamps", &"overheated": &"heat_hatch", &"ruins": &"broken_border", &"undermined": &"dashed_notch"}
var _used_fallback := false
var _validation_errors: Array[String] = []

func _init(table: Dictionary = {}, fallback_used := false, errors: Array[String] = []) -> void:
	_used_fallback = fallback_used
	_validation_errors = errors.duplicate()
	if table.is_empty():
		return
	var grid: Dictionary = table.get("grid", {})
	var marker: Dictionary = table.get("summon_marker", {})
	var timing: Dictionary = table.get("timing", {})
	_grid_line_color = Color(str(grid.get("line_color", "#39D9FF")))
	_grid_line_alpha = clampf(float(grid.get("line_alpha", 0.26)), 0.0, 1.0)
	_surface_offset = clampf(float(grid.get("surface_offset", 0.018)), 0.001, 0.08)
	_cell_inset_ratio = clampf(float(grid.get("cell_inset_ratio", 0.76)), 0.55, 0.90)
	_summon_marker_color = Color(str(marker.get("color", "#42E9F5")))
	_summon_radius_ratio = clampf(float(marker.get("radius_ratio", 0.21)), 0.08, 0.45)
	_summon_fill_alpha = clampf(float(marker.get("fill_alpha", 0.30)), 0.0, 1.0)
	_summon_ring_alpha = clampf(float(marker.get("ring_alpha", 0.86)), 0.0, 1.0)
	_hover_scale = clampf(float(marker.get("hover_scale", 1.12)), 1.0, 1.4)
	_confirm_flash_seconds = clampf(float(timing.get("confirm_flash_seconds", 0.08)), 0.02, 0.5)
	_overlay_fade_seconds = clampf(float(timing.get("overlay_fade_seconds", 0.18)), 0.02, 0.8)
	_reject_pulse_seconds = clampf(float(timing.get("reject_pulse_seconds", 0.14)), 0.02, 0.5)
	# Phase 27B-R1: camera framing
	var framing: Dictionary = table.get("camera_framing", {})
	if not framing.is_empty():
		_board_width_ratio = clampf(float(framing.get("board_width_ratio", 0.82)), 0.70, 0.90)
		_board_height_ratio = clampf(float(framing.get("board_height_ratio", 0.56)), 0.45, 0.68)
		_fit_padding = clampf(float(framing.get("fit_padding", 1.10)), 1.00, 1.30)
		_safe_top_ratio = clampf(float(framing.get("safe_top_ratio", 0.12)), 0.05, 0.35)
		_safe_bottom_ratio = clampf(float(framing.get("safe_bottom_ratio", 0.23)), 0.05, 0.35)
	# Phase 27B-R1: token footprint
	var footprint: Dictionary = table.get("token_footprint", {})
	if not footprint.is_empty():
		_normal_cell_ratio = clampf(float(footprint.get("normal_cell_ratio", 0.55)), 0.40, 0.70)
		_ascended_cell_ratio = clampf(float(footprint.get("ascended_cell_ratio", 0.62)), _normal_cell_ratio, 0.75)
		_art_fill_ratio = clampf(float(footprint.get("art_fill_ratio", 0.75)), 0.60, 0.90)
	_load_terrain_fields(table)

func _safe_number(value: Variant, default_value: float, minimum: float, maximum: float) -> float:
	if not (value is int or value is float):
		return default_value
	var number := float(value)
	return number if number >= minimum and number <= maximum else default_value

func _safe_int(value: Variant, default_value: int, minimum: int, maximum: int) -> int:
	if not (value is int or value is float) or not is_equal_approx(float(value), roundf(float(value))):
		return default_value
	return int(value) if int(value) >= minimum and int(value) <= maximum else default_value

func _safe_color(value: Variant, default_value: Color) -> Color:
	if not (value is String) or str(value).length() != 7 or not str(value).begins_with("#") or not Color.html_is_valid(str(value)):
		return default_value
	return Color(str(value))

func _load_terrain_fields(table: Dictionary) -> void:
	var terrain: Dictionary = table.get("terrain", {})
	_terrain_level_step_ratio = _safe_number(terrain.get("level_step_ratio"), 0.22, 0.05, 0.50)
	_terrain_footprint_ratio = _safe_number(terrain.get("footprint_ratio"), 0.78, 0.50, 0.95)
	_terrain_cap_thickness_ratio = _safe_number(terrain.get("cap_thickness_ratio"), 0.035, 0.01, 0.10)
	_terrain_body_color = _safe_color(terrain.get("body_color"), Color("#263746"))
	_terrain_cap_color = _safe_color(terrain.get("cap_color"), Color("#405867"))
	_terrain_edge_color = _safe_color(terrain.get("edge_color"), Color("#9DEBFF"))
	_terrain_height_band_color = _safe_color(terrain.get("height_band_color"), Color("#6FCDE2"))
	var feedback: Dictionary = table.get("terrain_feedback", {})
	for key in [&"legal", &"pending", &"invalid", &"label"]:
		_terrain_feedback[key] = _safe_color(feedback.get("%s_color" % key), _terrain_feedback[key])
	var timing: Dictionary = table.get("terrain_timing", {})
	_terrain_raise_seconds = _safe_number(timing.get("raise_seconds"), 0.28, 0.02, 1.0)
	_terrain_lower_seconds = _safe_number(timing.get("lower_seconds"), 0.24, 0.02, 1.0)
	_terrain_feedback_seconds = _safe_number(timing.get("feedback_seconds"), 0.12, 0.02, 1.0)
	var camera: Dictionary = table.get("terrain_camera", {})
	_elevated_base_pitch = _safe_number(camera.get("elevated_base_pitch"), 60.0, 1.0, 89.0)
	_top_pitch = _safe_number(camera.get("top_pitch"), 82.0, 1.0, 89.0)
	_terrain_focus_pitch = _safe_number(camera.get("focus_pitch"), 68.0, 1.0, 89.0)
	_height_fit_padding = _safe_number(camera.get("height_fit_padding"), 1.20, 1.0, 2.0)
	var occlusion: Dictionary = table.get("terrain_occlusion", {})
	_cutaway_alpha_scissor_threshold = _safe_number(occlusion.get("alpha_scissor_threshold"), 0.50, 0.0, 1.0)
	_cutaway_checker_size = _safe_int(occlusion.get("checker_size"), 4, 1, 16)
	var glyphs: Dictionary = table.get("surface_glyphs", {})
	for key in _surface_glyphs:
		if glyphs.get(key) == str(_surface_glyphs[key]):
			_surface_glyphs[key] = StringName(glyphs[key])

static func default_profile(errors: Array[String] = []) -> RefCounted:
	var scr = load("res://core/config/tactical_grid_presentation_profile.gd")
	var p = scr.new()
	p._grid_line_color = Color("#39D9FF")
	p._grid_line_alpha = 0.26
	p._surface_offset = 0.018
	p._cell_inset_ratio = 0.76
	p._summon_marker_color = Color("#42E9F5")
	p._summon_radius_ratio = 0.21
	p._summon_fill_alpha = 0.30
	p._summon_ring_alpha = 0.86
	p._hover_scale = 1.12
	p._confirm_flash_seconds = 0.08
	p._overlay_fade_seconds = 0.18
	p._reject_pulse_seconds = 0.14
	p._board_width_ratio = 0.82
	p._board_height_ratio = 0.56
	p._fit_padding = 1.10
	p._safe_top_ratio = 0.12
	p._safe_bottom_ratio = 0.23
	p._normal_cell_ratio = 0.55
	p._ascended_cell_ratio = 0.62
	p._art_fill_ratio = 0.75
	p._used_fallback = true
	p._validation_errors = errors.duplicate()
	return p

func get_grid_line_color() -> Color: return _grid_line_color
func get_grid_line_alpha() -> float: return _grid_line_alpha
func get_surface_offset() -> float: return _surface_offset
func get_cell_inset_ratio() -> float: return _cell_inset_ratio
func get_summon_marker_color() -> Color: return _summon_marker_color
func get_summon_radius_ratio() -> float: return _summon_radius_ratio
func get_summon_fill_alpha() -> float: return _summon_fill_alpha
func get_summon_ring_alpha() -> float: return _summon_ring_alpha
func get_hover_scale() -> float: return _hover_scale
func get_confirm_flash_seconds() -> float: return _confirm_flash_seconds
func get_overlay_fade_seconds() -> float: return _overlay_fade_seconds
func get_reject_pulse_seconds() -> float: return _reject_pulse_seconds
# Phase 27B-R1: camera framing getters
func get_board_width_ratio() -> float: return _board_width_ratio
func get_board_height_ratio() -> float: return _board_height_ratio
func get_fit_padding() -> float: return _fit_padding
func get_safe_top_ratio() -> float: return _safe_top_ratio
func get_safe_bottom_ratio() -> float: return _safe_bottom_ratio
# Phase 27B-R1: token footprint getters
func get_normal_token_cell_ratio() -> float: return _normal_cell_ratio
func get_ascended_cell_ratio() -> float: return _ascended_cell_ratio
func get_art_fill_ratio() -> float: return _art_fill_ratio
func get_terrain_level_step_ratio() -> float: return _terrain_level_step_ratio
func get_terrain_footprint_ratio() -> float: return _terrain_footprint_ratio
func get_terrain_cap_thickness_ratio() -> float: return _terrain_cap_thickness_ratio
func get_terrain_body_color() -> Color: return _terrain_body_color
func get_terrain_cap_color() -> Color: return _terrain_cap_color
func get_terrain_edge_color() -> Color: return _terrain_edge_color
func get_terrain_height_band_color() -> Color: return _terrain_height_band_color
func get_terrain_feedback_color(state: StringName) -> Color: return _terrain_feedback.get(state, _terrain_feedback[&"invalid"])
func get_terrain_raise_seconds() -> float: return _terrain_raise_seconds
func get_terrain_lower_seconds() -> float: return _terrain_lower_seconds
func get_terrain_feedback_seconds() -> float: return _terrain_feedback_seconds
func get_elevated_base_pitch() -> float: return _elevated_base_pitch
func get_top_pitch() -> float: return _top_pitch
func get_terrain_focus_pitch() -> float: return _terrain_focus_pitch
func get_height_fit_padding() -> float: return _height_fit_padding
func get_cutaway_alpha_scissor_threshold() -> float: return _cutaway_alpha_scissor_threshold
func get_cutaway_checker_size() -> int: return _cutaway_checker_size
func get_surface_glyph(surface: StringName) -> StringName: return _surface_glyphs.get(surface, &"")
func used_fallback() -> bool: return _used_fallback
func get_validation_errors() -> Array[String]: return _validation_errors.duplicate()
