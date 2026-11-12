class_name BattleViewCameraState
extends RefCounted
## Phase 23A-V1-R: Camera presentation state holder.
## Pure state and clamp/resistance math — no scene nodes, no gameplay access.
##
## Owns: yaw, pitch, distance, h_offset, v_offset, pan_offset, active_preset.
## Preset application resets pan to Vector3.ZERO.
## Non-zero pan delta changes active_preset to FREE.

# ── Preset enum ──
enum Preset { FREE, BASE, TOP }

# ── Preset constants (source of truth per design spec §6) ──
const BASE_PRESET := {
	"yaw": 90.0,
	"pitch": 56.0,
	"distance": 12.5,
	"h_offset": 0.65,
	"v_offset": -0.35,
}

const TOP_PRESET := {
	"yaw": 90.0,
	"pitch": 82.0,
	"distance": 13.5,
	"h_offset": 0.45,
	"v_offset": -0.20,
}

# ── Pan bounds (design spec §8) ──
const PAN_X_LIMIT := 1.1
const PAN_Z_LIMIT := 2.0
const SOFT_RESISTANCE_RATIO := 0.85

# ── Instance state ──
var yaw: float
var pitch: float
var distance: float
var h_offset: float
var v_offset: float
var pan_offset: Vector3
var active_preset: int


func _init() -> void:
	# Default to BASE on creation
	_apply_preset_values(BASE_PRESET)
	active_preset = Preset.BASE


## Apply a named preset, resetting pan to zero.
## Returns a snapshot Dictionary of the new state.
func apply_preset(preset_name: StringName) -> Dictionary:
	match preset_name:
		"base", "BASE", "Base":
			_apply_preset_values(BASE_PRESET)
			active_preset = Preset.BASE
		"top", "TOP", "Top":
			_apply_preset_values(TOP_PRESET)
			active_preset = Preset.TOP
		_:
			push_warning("[BattleViewCameraState] Unknown preset: %s" % preset_name)
			return snapshot()
	pan_offset = Vector3.ZERO
	return snapshot()


## Mark the current state as manually modified (FREE).
func mark_manual() -> void:
	active_preset = Preset.FREE


## Apply a pan delta in world XZ coordinates.
## Non-zero delta automatically marks the preset FREE.
## Returns the actual delta applied after soft resistance and hard clamping.
func apply_pan_world_delta(delta: Vector3) -> Vector3:
	if delta.x != 0.0 or delta.z != 0.0:
		mark_manual()

	var effective_x := _soft_clamp_axis(pan_offset.x, delta.x, PAN_X_LIMIT)
	var effective_z := _soft_clamp_axis(pan_offset.z, delta.z, PAN_Z_LIMIT)

	pan_offset.x += effective_x
	pan_offset.z += effective_z

	return Vector3(effective_x, 0.0, effective_z)


## Phase 27B-R1: compute camera state from grid frame + viewport + profile.
## Pure function — no scene nodes, no battle state.
## Returns a snapshot Dictionary with computed yaw/pitch/distance/offset.
func apply_grid_fit(frame: Dictionary, viewport_size: Vector2, profile: RefCounted, preset_name: StringName = &"base") -> Dictionary:
	if not bool(frame.get("ok", false)):
		return snapshot()
	if active_preset == Preset.FREE:
		return snapshot()
	var center: Vector3 = frame.get("center_world", Vector3.ZERO)
	var width: float = frame.get("width_world", frame.get("width", 1.0))
	var depth: float = frame.get("depth_world", frame.get("depth", 1.0))
	var height_span: float = maxf(float(frame.get("height_span_world", 0.0)), 0.0)
	var min_surface_y: float = float(frame.get("min_surface_y_world", center.y))
	var max_surface_y: float = float(frame.get("max_surface_y_world", center.y + height_span))
	var bw_ratio := 0.82
	var bh_ratio := 0.56
	var padding := 1.10
	var safe_top := 0.12
	var safe_bottom := 0.23
	var height_padding := 1.20
	if profile != null:
		if profile.has_method("get_board_width_ratio"): bw_ratio = profile.get_board_width_ratio()
		if profile.has_method("get_board_height_ratio"): bh_ratio = profile.get_board_height_ratio()
		if profile.has_method("get_fit_padding"): padding = profile.get_fit_padding()
		if profile.has_method("get_safe_top_ratio"): safe_top = profile.get_safe_top_ratio()
		if profile.has_method("get_safe_bottom_ratio"): safe_bottom = profile.get_safe_bottom_ratio()
		if profile.has_method("get_height_fit_padding"): height_padding = profile.get_height_fit_padding()
	if height_span <= 0.0:
		return apply_preset(preset_name)
	var padded_width := width * padding
	var padded_depth := depth * padding
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		_apply_preset_values(BASE_PRESET)
		active_preset = Preset.BASE
		pan_offset = Vector3.ZERO
		return snapshot()
	var aspect := viewport_size.x / viewport_size.y
	var distance_from_width: float = (padded_width * 0.5) / maxf(bw_ratio * aspect * 0.5, 0.001)
	var distance_from_height: float = (padded_depth * 0.5) / maxf(bh_ratio * 0.5, 0.001)
	var distance_from_terrain: float = (height_span * height_padding) / maxf(bh_ratio * 0.5, 0.001)
	var computed_distance: float
	match preset_name:
		"top", "TOP", "Top":
			computed_distance = maxf(maxf(distance_from_width, distance_from_height), distance_from_terrain) * 1.05
			var top_pitch: float = float(profile.get_top_pitch()) if profile != null and profile.has_method("get_top_pitch") else 82.0
			var vertical_midpoint := (min_surface_y + max_surface_y) * 0.5
			var vertical_bias := clampf((vertical_midpoint - center.y) * height_padding / maxf(computed_distance, 0.001), -safe_bottom, safe_top)
			_apply_preset_values({"yaw": 90.0, "pitch": top_pitch, "distance": computed_distance, "h_offset": 0.0, "v_offset": -safe_bottom + safe_top * 0.5 + vertical_bias})
			active_preset = Preset.TOP
		_:
			computed_distance = maxf(maxf(maxf(distance_from_width, distance_from_height), distance_from_terrain), float(BASE_PRESET.distance))
			var elevated_pitch: float = float(profile.get_elevated_base_pitch()) if profile != null and profile.has_method("get_elevated_base_pitch") else 60.0
			var vertical_midpoint := (min_surface_y + max_surface_y) * 0.5
			var vertical_bias := clampf((vertical_midpoint - center.y) * height_padding / maxf(computed_distance, 0.001), -safe_bottom, safe_top)
			_apply_preset_values({"yaw": 90.0, "pitch": elevated_pitch, "distance": computed_distance, "h_offset": BASE_PRESET.h_offset, "v_offset": BASE_PRESET.v_offset + vertical_bias})
			active_preset = Preset.BASE
	pan_offset = Vector3.ZERO
	return snapshot()

## Reset pan offset to zero.
func reset_pan() -> void:
	pan_offset = Vector3.ZERO


## Return a full snapshot of the current camera state (8 keys).
func snapshot() -> Dictionary:
	return {
		"yaw": yaw,
		"pitch": pitch,
		"distance": distance,
		"h_offset": h_offset,
		"v_offset": v_offset,
		"pan_offset": pan_offset,
		"active_preset": active_preset,
		"preset_name": _preset_name(),
	}


# ── Private ──

func _apply_preset_values(preset: Dictionary) -> void:
	yaw = float(preset.get("yaw", 90.0))
	pitch = float(preset.get("pitch", 56.0))
	distance = float(preset.get("distance", 12.5))
	h_offset = float(preset.get("h_offset", 0.0))
	v_offset = float(preset.get("v_offset", 0.0))


func _preset_name() -> String:
	match active_preset:
		Preset.BASE:
			return "base"
		Preset.TOP:
			return "top"
		_:
			return "free"


## Segmented soft resistance + hard clamp on a single axis.
##
## The movement path is split into two segments:
##   1. [0 … soft_start] — full speed, no resistance.
##   2. [soft_start … limit] — linear resistance: scale(x) = 1 − (x−soft_start)/(limit−soft_start).
##
## For the resistance segment, the effective travel is the integral of scale(x):
##   ∫ scale(x) dx = (q−p) − ((q−s)² − (p−s)²) / (2·(L−s))
##   where s = soft_start, L = limit, [p,q] is the resistance portion of the path.
##
## Rules:
## - Inward movement (toward center) is always full speed.
## - At |current| ≥ limit: outward blocked (returns 0), inward full speed.
## - Final position is hard-clamped to ±limit.
func _soft_clamp_axis(current: float, delta: float, limit: float) -> float:
	if delta == 0.0:
		return 0.0

	var soft_start: float = limit * SOFT_RESISTANCE_RATIO
	var proposed: float = current + delta
	var abs_cur: float = abs(current)
	var abs_prop: float = abs(proposed)
	var sig: float = sign(delta)

	# ── Inward movement (|position| decreasing) → full speed ──
	var moving_inward: bool = (current > 0.0 and delta < 0.0) or (current < 0.0 and delta > 0.0)
	if moving_inward:
		# Respect the far-side hard limit
		if abs_prop > limit:
			return (-limit * sign(current)) - current
		return delta

	# ── At or past hard limit, outward blocked ──
	if abs_cur >= limit:
		return 0.0

	# ── Clamp proposed to hard limit; if raw proposal exceeds limit,
	#     treat as hard-clamp intent: go directly to the limit boundary. ──
	var raw_abs_prop: float = abs_prop
	var hit_hard_limit: bool = raw_abs_prop > limit
	if hit_hard_limit:
		abs_prop = limit
		proposed = limit * sig

	# ── Entire movement before soft_start → full speed ──
	if abs_prop <= soft_start:
		return delta

	# ── Hard-clamp intent: return exactly the distance to the limit,
	#     bypassing the integral (applies when user clearly wants to reach/pass limit). ──
	if hit_hard_limit:
		return sig * (limit - abs_cur)

	# ── Segment the path ──
	# full_speed_portion: from abs_cur up to soft_start (may be zero)
	var full_speed_portion: float = 0.0
	var resist_start: float = abs_cur  # absolute position where resistance begins

	if abs_cur < soft_start:
		full_speed_portion = soft_start - abs_cur
		resist_start = soft_start

	# resisted_raw: raw distance traveled inside [soft_start, limit]
	var resisted_raw: float = abs_prop - resist_start
	if resisted_raw <= 0.0:
		return sig * full_speed_portion

	# ── Integral of scale(x) over [resist_start, abs_prop] ──
	# scale(x) = 1 − (x − soft_start) / (limit − soft_start)
	# ∫ scale(x) dx from p to q = (q−p) − ((q−s)² − (p−s)²) / (2·(L−s))
	var L_minus_s: float = limit - soft_start
	var p: float = resist_start
	var q: float = abs_prop

	var q_minus_s: float = q - soft_start
	var p_minus_s: float = p - soft_start

	var integral: float = (q - p) - (q_minus_s * q_minus_s - p_minus_s * p_minus_s) / (2.0 * L_minus_s)
	# Guard against tiny floating-point negatives
	integral = max(integral, 0.0)

	var total_effective: float = full_speed_portion + integral

	# Final hard-clamp safety (should not be needed but protects against fp error)
	var final_abs: float = abs_cur + total_effective
	if final_abs > limit:
		total_effective = limit - abs_cur
	total_effective = max(total_effective, 0.0)

	return sig * total_effective
