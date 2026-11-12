extends SceneTree

## Phase 18H-1: Check table art assets in cloudgate_v2/ directory
## Run: Godot --headless --path . --script res://tools/check_table_cloudgate_assets.gd
##
## Fallback order: cloudgate_v2 -> final -> placeholder -> skip
## Missing cloudgate_v2 assets are NOT errors — they fall through to final/placeholder.

const CLOUDGATE_DIR := "res://assets/table/cloudgate_v2"
const FINAL_DIR := "res://assets/table/final"
const PLACEHOLDER_DIR := "res://assets/table/placeholder"

# Phase 18H-1 CloudGate v2 Expected Assets
# Format: [name, width, height, tier (0=P0, 1=P1, 2=P2)]
const CLOUDGATE_MANIFEST: Array = [
	# --- P0: Core Table & Gauge ---
	["table_base_cloudgate", 1600, 900, 0],
	["table_frame_cloudgate", 1600, 900, 0],
	["od_gauge_housing", 420, 120, 0],
	["od_layer_current", 300, 22, 0],
	["od_layer_complete", 180, 12, 0],
	["od_layer_locked", 180, 12, 0],
	["boss_core_device", 220, 100, 0],
	["depth_crack_overlay", 1600, 900, 0],

	# --- P1: Slot Devices ---
	["player_front_slot_active", 150, 112, 1],
	["player_front_slot_locked", 150, 112, 1],
	["player_back_slot_build", 140, 90, 1],
	["player_back_slot_counter", 140, 90, 1],
	["boss_front_slot_online", 150, 112, 1],
	["boss_back_slot_online", 140, 90, 1],
	["slot_unlock_ring", 170, 130, 1],
	["slot_seal_plate", 150, 112, 1],

	# --- P2: Edge Devices ---
	["deck_box_player", 88, 112, 2],
	["deck_box_boss", 88, 112, 2],
	["graveyard_box_player", 88, 58, 2],
	["graveyard_box_boss", 88, 58, 2],
	["arsenal_dock", 220, 56, 2],
	["turn_button_frame", 150, 58, 2],
]

func _pad_right(s: String, width: int) -> String:
	var result := s
	while result.length() < width:
		result += " "
	return result

func _init() -> void:
	var sep := "================================================================"
	print(sep)
	print("[CloudGateAssetCheck] Phase 18H-1 -- Asset Manifest Audit")
	print("  cloudgate_v2: %s" % CLOUDGATE_DIR)
	print("  final:        %s" % FINAL_DIR)
	print("  placeholder:  %s" % PLACEHOLDER_DIR)
	print("  Fallback: cloudgate_v2 -> final -> placeholder -> skip")
	print(sep)

	var stats := {
		"cloudgate_ok": 0, "cloudgate_missing": 0, "cloudgate_size_err": 0,
		"final_ok": 0, "final_missing": 0,
		"placeholder_ok": 0, "placeholder_missing": 0,
	}
	var tier_counts: Dictionary = {0: 0, 1: 0, 2: 0}
	var tier_available: Dictionary = {0: 0, 1: 0, 2: 0}

	for entry in CLOUDGATE_MANIFEST:
		var asset_name: String = entry[0]
		var exp_w: int = entry[1]
		var exp_h: int = entry[2]
		var tier: int = entry[3]
		tier_counts[tier] = tier_counts.get(tier, 0) + 1

		var cg_path := "%s/%s.png" % [CLOUDGATE_DIR, asset_name]
		var final_path := "%s/%s.png" % [FINAL_DIR, asset_name]
		var ph_path := "%s/%s.png" % [PLACEHOLDER_DIR, asset_name]

		# Check cloudgate_v2
		var found_in := ""
		if ResourceLoader.exists(cg_path):
			var tex: Texture2D = ResourceLoader.load(cg_path, "Texture2D", ResourceLoader.CACHE_MODE_IGNORE)
			if tex:
				var w: int = tex.get_width()
				var h: int = tex.get_height()
				if w == exp_w and h == exp_h:
					stats["cloudgate_ok"] += 1
					tier_available[tier] = tier_available.get(tier, 0) + 1
					found_in = "cloudgate_v2 [OK]"
				else:
					stats["cloudgate_size_err"] += 1
					push_warning("[CloudGate] SIZE: %s -- %dx%d expected %dx%d" % [asset_name, w, h, exp_w, exp_h])
			else:
				stats["cloudgate_missing"] += 1
		else:
			stats["cloudgate_missing"] += 1

		# Fallback check: final
		if found_in == "" and ResourceLoader.exists(final_path):
			stats["final_ok"] += 1
			found_in = "final [fallback]"

		# Fallback check: placeholder
		if found_in == "" and ResourceLoader.exists(ph_path):
			stats["placeholder_ok"] += 1
			found_in = "placeholder [fallback]"

		if found_in == "":
			stats["placeholder_missing"] += 1
			found_in = "MISSING [no fallback]"

		var tier_label := ""
		match tier:
			0: tier_label = "P0"
			1: tier_label = "P1"
			2: tier_label = "P2"
		var padded_name := _pad_right(asset_name, 36)
		print("  [%s] %s %s" % [tier_label, padded_name, found_in])

	# Summary
	print("")
	print("--- CloudGate v2 Directory ---")
	print("  OK:          %d" % stats["cloudgate_ok"])
	print("  Size Err:    %d" % stats["cloudgate_size_err"])
	print("  Missing:     %d (fall to final/placeholder)" % stats["cloudgate_missing"])
	print("  Total:       %d" % CLOUDGATE_MANIFEST.size())
	print("")
	print("--- Fallback Coverage ---")
	print("  final OK:       %d" % stats["final_ok"])
	print("  placeholder OK: %d" % stats["placeholder_ok"])
	print("  Unavailable:    %d" % stats["placeholder_missing"])
	print("")
	print("--- Tier Readiness ---")
	for tier in [0, 1, 2]:
		var avail: int = tier_available.get(tier, 0)
		var total: int = tier_counts.get(tier, 0)
		var pct: float = float(avail) / float(total) * 100.0 if total > 0 else 0.0
		var tier_label := ""
		match tier:
			0: tier_label = "P0 (Core Table & Gauge)"
			1: tier_label = "P1 (Slot Devices)"
			2: tier_label = "P2 (Edge Devices)"
		print("  %s: %d/%d cloudgate_v2 (%.0f%%)" % [tier_label, avail, total, pct])

	print("")
	print("[CloudGateAssetCheck] Done -- missing assets safely fall through to final/placeholder.")
	quit()
